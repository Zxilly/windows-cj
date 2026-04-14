package windows

import std.collection.HashMap
import std.sync.Mutex
import windows_core.*
import windows_result.Win32Exception
import windows_sys.win32.foundation.*
import windows_sys.win32.ui.windows_and_messaging.*

func windowWithWideString<R>(s: String, action: (CPointer<UInt16>) -> R): R {
    let ws = CWideString(s)
    try {
        return unsafe { ws.withPtr(action) }
    } finally {
        ws.close()
    }
}

// registerClassEx — registers a window class, throwing on failure.
public func registerClassEx(wc: WNDCLASSEXW): UInt16 {
    var wcCopy = wc
    let atom = ffiRegisterClassExW(CPointer<WNDCLASSEXW>(inout wcCopy))
    if (atom == 0u16) {
        throw Win32Exception(ffiGetLastError())
    }
    atom
}

func registerWindowClassWithName(
    className: CPointer<UInt16>,
    hInstance: HINSTANCE
): UInt16 {
    var wc = WNDCLASSEXW()
    wc.cbSize = UInt32(80) // sizeof(WNDCLASSEXW) on x64
    wc.lpfnWndProc = wndProcThunk
    wc.hInstance = hInstance
    wc.lpszClassName = className
    ffiRegisterClassExW(CPointer<WNDCLASSEXW>(inout wc))
}

// createWindowEx — creates a window, throwing if the returned HWND is null.
public func createWindowEx(
    exStyle: WINDOW_EX_STYLE,
    className: CPointer<UInt16>,
    windowName: String,
    style: WINDOW_STYLE,
    x: Int32,
    y: Int32,
    width: Int32,
    height: Int32,
    parent: HWND,
    menu: HMENU,
    instance: HINSTANCE,
    param: CPointer<Unit>
): HWND {
    let hwnd = windowWithWideString(windowName) { pName: CPointer<UInt16> =>
        ffiCreateWindowExW(
            exStyle,
            className,
            pName,
            style,
            x, y, width, height,
            parent, menu, instance, param
        )
    }
    if (hwnd.isNull()) {
        throw Win32Exception(ffiGetLastError())
    }
    hwnd
}

// showWindow — sets the specified window's show state.
public func showWindow(hwnd: HWND, cmdShow: SHOW_WINDOW_CMD): Bool {
    let result = ffiShowWindow(hwnd, cmdShow)
    result != 0
}

// updateWindow — sends WM_PAINT directly, throwing on failure.
public func updateWindow(hwnd: HWND): Unit {
    let result = ffiUpdateWindow(hwnd)
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
}

// destroyWindow — destroys the specified window, throwing on failure.
public func destroyWindow(hwnd: HWND): Unit {
    let result = ffiDestroyWindow(hwnd)
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
}

// =============================================================================
// Window Class Handler Registry (Class-level, not instance-level)
// =============================================================================
// This registry stores WndProc handlers by window class name, separate from
// the instance-level wndProcRegistry in callbacks.cj. A single class can have
// multiple windows, so the handler is class-scoped.
// Note: Class handlers must be registered before creating windows of that class.
// Unregistration is caller's responsibility (typically when app exits).

var windowClassHandlerMutex = Mutex()
var windowClassHandlerRegistry = HashMap<String, Object>()

func rememberWindowClassHandler(
    className: String,
    handler: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative
): Unit {
    windowClassHandlerMutex.lock()
    if (windowClassHandlerRegistry.contains(className)) {
        windowClassHandlerRegistry.remove(className)
    }
    windowClassHandlerRegistry.add(className, WndProcHandler(handler))
    windowClassHandlerMutex.unlock()
}

func lookupWindowClassHandler(className: String): Option<WndProcHandler> {
    windowClassHandlerMutex.lock()
    let result = windowClassHandlerRegistry.get(className)
    windowClassHandlerMutex.unlock()
    match (result) {
        case Some(obj) =>
            match (obj) {
                case wrapper: WndProcHandler => Some(wrapper)
                case _ => None
            }
        case None => None
    }
}

// unregisterWindowClass — removes the WndProc handler for a class.
// Must be called when the class is no longer in use.
public func unregisterWindowClass(className: String): Unit {
    windowClassHandlerMutex.lock()
    windowClassHandlerRegistry.remove(className)
    windowClassHandlerMutex.unlock()
}

// registerWindowClass — convenience that registers a window class using wndProcThunk.
public func registerWindowClass(
    className: String,
    hInstance: HINSTANCE,
    handler: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative
): UInt16 {
    let atom = windowWithWideString(className) { pClassName: CPointer<UInt16> =>
        registerWindowClassWithName(pClassName, hInstance)
    }
    if (atom == 0u16) {
        throw Win32Exception(ffiGetLastError())
    }
    rememberWindowClassHandler(className, handler)
    atom
}

// createWindowWithHandler — creates a window and registers its WndProc handler.
public func createWindowWithHandler(
    exStyle: WINDOW_EX_STYLE,
    className: String,
    windowName: String,
    style: WINDOW_STYLE,
    x: Int32,
    y: Int32,
    width: Int32,
    height: Int32,
    parent: HWND,
    menu: HMENU,
    instance: HINSTANCE
): HWND {
    var pendingKey = UIntNative(0)
    let pendingParam = match (lookupWindowClassHandler(className)) {
        case Some(wrapper) =>
            let rawKey = nextCallbackKey()
            pendingKey = UIntNative(rawKey)
            registerPendingWndProc(pendingKey, wrapper.handler)
        case None => CPointer<Unit>()
    }
    let hwnd = windowWithWideString(className) { pClass: CPointer<UInt16> =>
        windowWithWideString(windowName) { pName: CPointer<UInt16> =>
            ffiCreateWindowExW(
                exStyle,
                pClass,
                pName,
                style,
                x, y, width, height,
                parent, menu, instance,
                pendingParam
            )
        }
    }
    if (hwnd.isNull()) {
        if (pendingKey != UIntNative(0)) {
            unregisterPendingWndProc(pendingKey)
        }
        throw Win32Exception(ffiGetLastError())
    }

    hwnd
}

// runMessageLoop — standard Win32 message loop (GetMessage/Translate/Dispatch).
public func runMessageLoop(): Int64 {
    var msg = MSG()
    while (true) {
        let ret = ffiGetMessageW(
            CPointer<MSG>(inout msg),
            CPointer<Unit>(),
            0u32,
            0u32
        )
        if (ret == -1) {
            throw Win32Exception(ffiGetLastError())
        }
        if (ret == 0) {
            break
        }
        ffiTranslateMessage(CPointer<MSG>(inout msg))
        ffiDispatchMessageW(CPointer<MSG>(inout msg))
    }
    Int64(msg.wParam)
}

// setTimer — sets a timer, throwing on failure.
public func setTimer(
    hwnd: HWND,
    idEvent: UIntNative,
    elapse: UInt32,
    timerFunc: CFunc<(HWND, UInt32, UIntNative, UInt32) -> Unit>
): UIntNative {
    let result = ffiSetTimer(hwnd, idEvent, elapse, timerFunc)
    if (result == UIntNative(0)) {
        throw Win32Exception(ffiGetLastError())
    }
    result
}

// killTimer — kills a timer, throwing on failure.
public func killTimer(hwnd: HWND, idEvent: UIntNative): Unit {
    let result = ffiKillTimer(hwnd, idEvent)
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
}

public func setTimerWithHandler(
    hwnd: HWND,
    idEvent: UIntNative,
    elapse: UInt32,
    handler: (CPointer<Unit>, UInt32, UIntNative, UInt32) -> Unit
): UIntNative {
    let requestedId = if (idEvent == UIntNative(0)) {
        UIntNative(nextCallbackKey())
    } else {
        idEvent
    }
    registerTimerProc(requestedId, handler)
    let result = ffiSetTimer(hwnd, requestedId, elapse, timerProcThunk)
    if (result == UIntNative(0)) {
        unregisterTimerProc(requestedId)
        throw Win32Exception(ffiGetLastError())
    }
    moveTimerProcRegistration(requestedId, result)
    result
}

public func killTimerWithHandler(hwnd: HWND, idEvent: UIntNative): Unit {
    killTimer(hwnd, idEvent)
    unregisterTimerProc(idEvent)
}

public func postQuitMessage(exitCode: Int32): Unit {
    ffiPostQuitMessage(exitCode)
}
