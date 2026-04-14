package windows

import std.collection.HashMap
import std.sync.Mutex
import windows_core.*
import windows_result.Win32Exception
import windows_sys.win32.foundation.{ERROR_SUCCESS}
import windows_sys.win32.ui.windows_and_messaging.{CREATESTRUCTW, WM_NCCREATE, WM_NCDESTROY}

// =============================================================================
// Generic callback registry
// =============================================================================
// Maps integer keys to Cangjie closures for Win32 callback trampolines.
// Win32 callbacks (EnumWindows, etc.) pass an lParam/context value that we use
// as a key to look up the registered closure.

var callbackMutex = Mutex()
var callbackNextKey: IntNative = IntNative(1)
var callbackRegistry = HashMap<IntNative, Object>()

// Allocate a unique registry key (thread-safe)
public func nextCallbackKey(): IntNative {
    callbackMutex.lock()
    let key = callbackNextKey
    callbackNextKey = callbackNextKey + IntNative(1)
    callbackMutex.unlock()
    key
}

// Register a closure in the callback registry
public func registerCallback(key: IntNative, handler: Object): Unit {
    callbackMutex.lock()
    callbackRegistry.add(key, handler)
    callbackMutex.unlock()
}

// Remove a closure from the callback registry
public func unregisterCallback(key: IntNative): Unit {
    callbackMutex.lock()
    callbackRegistry.remove(key)
    callbackMutex.unlock()
}

// Look up a closure in the callback registry
public func lookupCallback(key: IntNative): Option<Object> {
    callbackMutex.lock()
    let result = callbackRegistry.get(key)
    callbackMutex.unlock()
    result
}

// =============================================================================
// EnumWindows callback pattern
// =============================================================================
// Wrapper class for EnumWindows handler closure.
// Needed because function types cannot be downcast via type pattern matching.
public class EnumWindowsHandler {
    public let handler: (CPointer<Unit>) -> Bool
    public var stopped: Bool = false

    public init(handler: (CPointer<Unit>) -> Bool) {
        this.handler = handler
    }
}

// @C thunk for WNDENUMPROC: BOOL CALLBACK EnumWindowsProc(HWND, LPARAM)
@C
public func enumWindowsThunk(hwnd: CPointer<Unit>, lParam: IntNative): Int32 {
    match (lookupCallback(lParam)) {
        case Some(obj) =>
            match (obj) {
                case wrapper: EnumWindowsHandler =>
                    if (wrapper.handler(hwnd)) {
                        1
                    } else {
                        wrapper.stopped = true
                        0
                    }
                case _ => 0
            }
        case None => 0
    }
}

// High-level wrapper: enumerate windows using a Cangjie closure.
// Example:
//   enumWindows { hwnd => println("Window: ${hwnd}"); true }
// Note: caller must import windows_sys and link user32.dll
// The actual EnumWindows FFI call is in windows_sys; this provides
// the thunk + registry integration.
func withWndEnumProcCallback<R>(
    handler: (CPointer<Unit>) -> Bool,
    body: (EnumWindowsHandler, CFunc<(CPointer<Unit>, IntNative) -> Int32>, IntNative) -> R
): R {
    let key = nextCallbackKey()
    let wrapper = EnumWindowsHandler(handler)
    registerCallback(key, wrapper)
    try {
        return body(wrapper, enumWindowsThunk, key)
    } finally {
        unregisterCallback(key)
    }
}

public func withEnumWindowsCallback(
    handler: (CPointer<Unit>) -> Bool,
    body: (CFunc<(CPointer<Unit>, IntNative) -> Int32>, IntNative) -> Unit
): Unit {
    withWndEnumProcCallback(handler) { _: EnumWindowsHandler, thunk: CFunc<(CPointer<Unit>, IntNative) -> Int32>, key: IntNative =>
        body(thunk, key)
    }
}

public func enumWindows(handler: (CPointer<Unit>) -> Bool): Unit {
    withWndEnumProcCallback(handler) { wrapper: EnumWindowsHandler, thunk: CFunc<(CPointer<Unit>, IntNative) -> Int32>, key: IntNative =>
        let result = ffiEnumWindows(thunk, key)
        if (result == 0 && !wrapper.stopped) {
            throw Win32Exception(ffiGetLastError())
        }
    }
}

public func enumChildWindows(parent: CPointer<Unit>, handler: (CPointer<Unit>) -> Bool): Unit {
    withWndEnumProcCallback(handler) { wrapper: EnumWindowsHandler, thunk: CFunc<(CPointer<Unit>, IntNative) -> Int32>, key: IntNative =>
        let result = ffiEnumChildWindows(parent, thunk, key)
        if (result == 0 && !wrapper.stopped) {
            let error = ffiGetLastError()
            if (error != ERROR_SUCCESS) {
                throw Win32Exception(error)
            }
        }
    }
}

// =============================================================================
// WndProc callback pattern
// =============================================================================
// WndProc is special: it persists across messages (not just one API call).
// We use a separate registry keyed by HWND.

var wndProcMutex = Mutex()
var wndProcRegistry = HashMap<UIntNative, Object>()
var pendingWndProcMutex = Mutex()
var pendingWndProcRegistry = HashMap<UIntNative, Object>()
var timerProcMutex = Mutex()
var timerProcRegistry = HashMap<UIntNative, Object>()

// Wrapper class for WndProc handler closure
public class WndProcHandler {
    public let handler: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative
    public init(handler: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative) {
        this.handler = handler
    }
}

// Register a WndProc handler for a window handle
public func registerWndProc(hwnd: CPointer<Unit>, handler: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative): Unit {
    let key = hwnd.toUIntNative()
    wndProcMutex.lock()
    wndProcRegistry.add(key, WndProcHandler(handler))
    wndProcMutex.unlock()
}

// Register a pending WndProc handler keyed by the opaque lpCreateParams context
// passed into CreateWindowExW. The thunk will attach it to the HWND on WM_NCCREATE.
public func registerPendingWndProc(
    key: UIntNative,
    handler: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative
): CPointer<Unit> {
    pendingWndProcMutex.lock()
    if (pendingWndProcRegistry.contains(key)) {
        releasePendingWndProcEntry(pendingWndProcRegistry.get(key))
        pendingWndProcRegistry.remove(key)
    }
    let entry = PendingWndProcEntry(key, handler)
    pendingWndProcRegistry.add(key, entry)
    pendingWndProcMutex.unlock()
    entry.contextParam()
}

public func unregisterPendingWndProc(key: UIntNative): Unit {
    pendingWndProcMutex.lock()
    releasePendingWndProcEntry(pendingWndProcRegistry.get(key))
    pendingWndProcRegistry.remove(key)
    pendingWndProcMutex.unlock()
}

// Unregister a WndProc handler
public func unregisterWndProc(hwnd: CPointer<Unit>): Unit {
    let key = hwnd.toUIntNative()
    wndProcMutex.lock()
    wndProcRegistry.remove(key)
    wndProcMutex.unlock()
}

// Look up a WndProc handler by HWND
func lookupWndProc(hwnd: CPointer<Unit>): Option<Object> {
    let key = hwnd.toUIntNative()
    wndProcMutex.lock()
    let result = wndProcRegistry.get(key)
    wndProcMutex.unlock()
    result
}

func takePendingWndProcByKey(key: UIntNative): Option<WndProcHandler> {
    pendingWndProcMutex.lock()
    let result = pendingWndProcRegistry.get(key)
    if (result.isSome()) {
        pendingWndProcRegistry.remove(key)
    }
    pendingWndProcMutex.unlock()
    match (result) {
        case Some(obj) =>
            match (obj) {
                case entry: PendingWndProcEntry =>
                    let wrapper = entry.wrapper
                    releasePendingWndProcEntry(Some(entry))
                    Some(wrapper)
                case _ => None
            }
        case None => None
    }
}

func releasePendingWndProcEntry(entry: Option<Object>): Unit {
    match (entry) {
        case Some(obj) =>
            match (obj) {
                case pending: PendingWndProcEntry =>
                    unsafe { releaseArrayRawData(pending.contextHandle) }
                case _ => ()
            }
        case None => ()
    }
}

public class TimerProcHandler {
    public let handler: (CPointer<Unit>, UInt32, UIntNative, UInt32) -> Unit

    public init(handler: (CPointer<Unit>, UInt32, UIntNative, UInt32) -> Unit) {
        this.handler = handler
    }
}

public func registerTimerProc(
    idEvent: UIntNative,
    handler: (CPointer<Unit>, UInt32, UIntNative, UInt32) -> Unit
): Unit {
    timerProcMutex.lock()
    if (timerProcRegistry.contains(idEvent)) {
        timerProcRegistry.remove(idEvent)
    }
    timerProcRegistry.add(idEvent, TimerProcHandler(handler))
    timerProcMutex.unlock()
}

public func unregisterTimerProc(idEvent: UIntNative): Unit {
    timerProcMutex.lock()
    timerProcRegistry.remove(idEvent)
    timerProcMutex.unlock()
}

func moveTimerProcRegistration(from: UIntNative, to: UIntNative): Unit {
    if (from == to) {
        return
    }

    timerProcMutex.lock()
    let value = timerProcRegistry.get(from)
    if (value.isSome()) {
        timerProcRegistry.remove(from)
        match (value) {
            case Some(entry) => timerProcRegistry.add(to, entry)
            case None => ()
        }
    }
    timerProcMutex.unlock()
}

func lookupTimerProc(idEvent: UIntNative): Option<Object> {
    timerProcMutex.lock()
    let result = timerProcRegistry.get(idEvent)
    timerProcMutex.unlock()
    result
}

@C
public func timerProcThunk(
    hwnd: CPointer<Unit>,
    msg: UInt32,
    idEvent: UIntNative,
    elapsed: UInt32
): Unit {
    match (lookupTimerProc(idEvent)) {
        case Some(obj) =>
            match (obj) {
                case wrapper: TimerProcHandler => wrapper.handler(hwnd, msg, idEvent, elapsed)
                case _ => ()
            }
        case None => ()
    }
}

// Default WndProc. On current Windows x64 toolchains the ABI matches the
// default foreign call convention, so keep the declaration compiler-accepted.
foreign func DefWindowProcW(
    hwnd: CPointer<Unit>,
    msg: UInt32,
    wParam: UIntNative,
    lParam: IntNative
): IntNative

// @C thunk for WNDPROC: LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM)
@C
public func wndProcThunk(
    hwnd: CPointer<Unit>,
    msg: UInt32,
    wParam: UIntNative,
    lParamRaw: CPointer<Unit>
): IntNative {
    let lParam = IntNative(lParamRaw.toUIntNative())

    if (msg == WM_NCCREATE) {
        match (lookupWndProc(hwnd)) {
            case Some(_) => ()
            case None =>
                let contextKey = unsafe {
                    let createStruct = CPointer<CREATESTRUCTW>(lParamRaw).read()
                    if (createStruct.lpCreateParams.isNull()) {
                        UIntNative(0)
                    } else {
                        CPointer<UIntNative>(createStruct.lpCreateParams).read()
                    }
                }
                match (takePendingWndProcByKey(contextKey)) {
                    case Some(wrapper) => registerWndProc(hwnd, wrapper.handler)
                    case None => ()
                }
        }
    }

    let result = match (lookupWndProc(hwnd)) {
        case Some(obj) =>
            match (obj) {
                case wrapper: WndProcHandler =>
                    wrapper.handler(hwnd, msg, wParam, lParam)
                case _ =>
                    unsafe { DefWindowProcW(hwnd, msg, wParam, lParam) }
            }
        case None =>
            unsafe { DefWindowProcW(hwnd, msg, wParam, lParam) }
    }

    if (msg == WM_NCDESTROY) {
        unregisterWndProc(hwnd)
    }

    result
}

class PendingWndProcEntry {
    let key: UIntNative
    let wrapper: WndProcHandler
    let contextHandle: CPointerHandle<UIntNative>

    init(
        key: UIntNative,
        handler: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative
    ) {
        this.key = key
        this.wrapper = WndProcHandler(handler)
        this.contextHandle = unsafe { acquireArrayRawData(Array<UIntNative>(1, { _ => key })) }
    }

    func contextParam(): CPointer<Unit> {
        CPointer<Unit>(contextHandle.pointer)
    }
}
