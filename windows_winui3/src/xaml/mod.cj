package windows_winui3.xaml

import std.collection.ArrayList
import windows_common.Foundation.{EventRegistrationToken}
import windows_common.Microsoft.UI.Xaml.{
    Application,
    IFrameworkElement,
    IFrameworkElementVtbl,
    IApplicationStatics,
    IApplicationStaticsVtbl,
    IUIElement,
    IWindowFactory,
    IWindowFactoryVtbl,
    UIElement,
    Window
}
import windows_common.Microsoft.UI.Xaml.Controls.{ContentControl}
import windows_common.Microsoft.UI.Xaml.Markup.{IXamlReaderStatics, IXamlReaderStaticsVtbl, XamlReader}
import windows_core.{
    E_FAIL,
    E_NOINTERFACE,
    E_NOTIMPL,
    E_POINTER,
    GUID,
    HString,
    HRESULT,
    IInspectableVtbl,
    IUnknownVtbl,
    IID_IUNKNOWN,
    IUnknown,
    Result,
    S_OK,
    WindowsException,
    coTaskMemAlloc,
    coTaskMemFree,
    loadFactoryByName,
    queryInterfaceRaw,
    winrtBorrowGenericIn
}

let IID_APPLICATION_INITIALIZATION_CALLBACK = GUID.from_values(3639538121u32, 4660u16, 22257u16, 153u8, 99u8, 69u8, 221u8, 156u8, 128u8, 166u8, 97u8)
let IID_BUTTON_BASE = GUID.from_values(1701921385u32, 9331u16, 21287u16, 166u8, 82u8, 14u8, 166u8, 188u8, 231u8, 244u8, 3u8)
let IID_ROUTED_EVENT_HANDLER = GUID.from_values(3672259973u32, 27082u16, 23519u16, 128u8, 91u8, 97u8, 97u8, 163u8, 162u8, 21u8, 204u8)

@C
struct ApplicationInitializationCallbackVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

@C
struct ApplicationInitializationCallbackObject {
    public var vtbl: CPointer<ApplicationInitializationCallbackVtbl> = CPointer<ApplicationInitializationCallbackVtbl>()
    public var refCount: UInt32 = 1u32
    public var slot: Int64 = -1
    public init() {}
}

@C
struct ButtonBaseVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var ClickMode: CPointer<Unit> = CPointer<Unit>()
    public var SetClickMode: CPointer<Unit> = CPointer<Unit>()
    public var IsPointerOver: CPointer<Unit> = CPointer<Unit>()
    public var IsPressed: CPointer<Unit> = CPointer<Unit>()
    public var Command: CPointer<Unit> = CPointer<Unit>()
    public var SetCommand: CPointer<Unit> = CPointer<Unit>()
    public var CommandParameter: CPointer<Unit> = CPointer<Unit>()
    public var SetCommandParameter: CPointer<Unit> = CPointer<Unit>()
    public var AddClick: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<EventRegistrationToken>) -> Int32> = { _, _, result =>
        if (result.isNotNull()) {
            unsafe { result.write(0) }
        }
        E_NOTIMPL.value
    }
    public var RemoveClick: CFunc<(CPointer<Unit>, EventRegistrationToken) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

@C
struct WindowVtbl {
    public var QueryInterface: CPointer<Unit> = CPointer<Unit>()
    public var AddRef: CPointer<Unit> = CPointer<Unit>()
    public var Release: CPointer<Unit> = CPointer<Unit>()
    public var GetIids: CPointer<Unit> = CPointer<Unit>()
    public var GetRuntimeClassName: CPointer<Unit> = CPointer<Unit>()
    public var GetTrustLevel: CPointer<Unit> = CPointer<Unit>()
    public var Bounds: CPointer<Unit> = CPointer<Unit>()
    public var Visible: CPointer<Unit> = CPointer<Unit>()
    public var Content: CPointer<Unit> = CPointer<Unit>()
    public var SetContent: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var get_CoreWindow: CPointer<Unit> = CPointer<Unit>()
    public var get_Compositor: CPointer<Unit> = CPointer<Unit>()
    public var Dispatcher: CPointer<Unit> = CPointer<Unit>()
    public var get_DispatcherQueue: CPointer<Unit> = CPointer<Unit>()
    public var Title: CPointer<Unit> = CPointer<Unit>()
    public var SetTitle: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var ExtendsContentIntoTitleBar: CPointer<Unit> = CPointer<Unit>()
    public var SetExtendsContentIntoTitleBar: CPointer<Unit> = CPointer<Unit>()
    public var Activated: CPointer<Unit> = CPointer<Unit>()
    public var RemoveActivated: CPointer<Unit> = CPointer<Unit>()
    public var Closed: CPointer<Unit> = CPointer<Unit>()
    public var RemoveClosed: CPointer<Unit> = CPointer<Unit>()
    public var SizeChanged: CPointer<Unit> = CPointer<Unit>()
    public var RemoveSizeChanged: CPointer<Unit> = CPointer<Unit>()
    public var VisibilityChanged: CPointer<Unit> = CPointer<Unit>()
    public var RemoveVisibilityChanged: CPointer<Unit> = CPointer<Unit>()
    public var Activate: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public var Close: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public var SetTitleBar: CPointer<Unit> = CPointer<Unit>()
    public init() {}
}

@C
struct RoutedEventHandlerVtbl {
    public var QueryInterface: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, result =>
        if (result.isNotNull()) {
            unsafe { result.write(CPointer<Unit>()) }
        }
        E_NOTIMPL.value
    }
    public var AddRef: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 1u32 }
    public var Release: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 1u32 }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@C
struct RoutedEventHandlerObject {
    public var vtbl: CPointer<RoutedEventHandlerVtbl> = CPointer<RoutedEventHandlerVtbl>()
    public var refCount: UInt32 = 1u32
    public var slot: Int64 = -1
    public init() {}
}

var applicationInitializationCallbackVtblStorage: CPointer<ApplicationInitializationCallbackVtbl> = CPointer<ApplicationInitializationCallbackVtbl>()
var applicationInitializationCallbackSlots: ArrayList<Option<() -> Unit>> = ArrayList<Option<() -> Unit>>()
var routedEventHandlerVtblStorage: CPointer<RoutedEventHandlerVtbl> = CPointer<RoutedEventHandlerVtbl>()
var routedEventHandlerSlots: ArrayList<Option<() -> Unit>> = ArrayList<Option<() -> Unit>>()

func closeApplicationCallbackStateNoThrow(
    rawObject: CPointer<Unit>,
    slot: Int64,
    closed: Bool
): (CPointer<Unit>, Int64, Bool) {
    if (!closed) {
        let raw = rawObject
        if (slot >= 0) {
            try {
                clearApplicationInitializationCallbackSlot(slot)
            } catch (_: Exception) {
                ()
            }
        }
        if (raw.isNotNull()) {
            try {
                deactivateApplicationInitializationCallbackObject(raw)
                let _ = unsafe { applicationInitializationCallbackRelease(raw) }
            } catch (_: Exception) {
                ()
            }
        }
    }
    return (CPointer<Unit>(), -1, true)
}

// GC finalizers only detach local managed state; explicit close owns native cleanup.
func finalizeApplicationCallbackStateNoThrow(): (CPointer<Unit>, Int64, Bool) {
    return (CPointer<Unit>(), -1, true)
}

func closeWinuiRawStateNoThrow(raw: CPointer<Unit>, closed: Bool): (CPointer<Unit>, Bool) {
    if (!closed && raw.isNotNull()) {
        try {
            releaseRaw(raw)
        } catch (_: Exception) {
            ()
        }
    }
    return (CPointer<Unit>(), true)
}

func finalizeWinuiRawStateNoThrow(): (CPointer<Unit>, Bool) {
    return (CPointer<Unit>(), true)
}

func closeRoutedEventHandlerStateNoThrow(
    rawObject: CPointer<Unit>,
    slot: Int64,
    closed: Bool
): (CPointer<Unit>, Int64, Bool) {
    if (!closed) {
        if (slot >= 0) {
            try {
                clearRoutedEventHandlerSlot(slot)
            } catch (_: Exception) {
                ()
            }
        }
        if (rawObject.isNotNull()) {
            try {
                deactivateRoutedEventHandlerObject(rawObject)
                let _ = unsafe { routedEventHandlerRelease(rawObject) }
            } catch (_: Exception) {
                ()
            }
        }
    }
    return (CPointer<Unit>(), -1, true)
}

func finalizeRoutedEventHandlerStateNoThrow(): (CPointer<Unit>, Int64, Bool) {
    return (CPointer<Unit>(), -1, true)
}

public class ApplicationCallback <: Resource {
    private var rawObject: CPointer<Unit> = CPointer<Unit>()
    private var slot: Int64 = -1
    private var closed: Bool = false

    public init(handler: () -> Unit) {
        slot = addApplicationInitializationCallbackSlot(handler)
        let raw = coTaskMemAlloc(sizeOf<ApplicationInitializationCallbackObject>())
        if (raw.isNull()) {
            clearApplicationInitializationCallbackSlot(slot)
            throw Exception("failed to allocate ApplicationInitializationCallback object")
        }
        var object = ApplicationInitializationCallbackObject()
        object.vtbl = applicationInitializationCallbackVtbl()
        object.refCount = 1u32
        object.slot = slot
        let typed = CPointer<ApplicationInitializationCallbackObject>(raw)
        unsafe { typed.write(object) }
        rawObject = raw
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        rawObject
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        let (nextRawObject, nextSlot, nextClosed) = closeApplicationCallbackStateNoThrow(rawObject, slot, closed)
        rawObject = nextRawObject
        slot = nextSlot
        closed = nextClosed
    }

    ~init() {
        let (nextRawObject, nextSlot, nextClosed) = finalizeApplicationCallbackStateNoThrow()
        rawObject = nextRawObject
        slot = nextSlot
        closed = nextClosed
    }
}

public class WindowHandle <: Resource {
    private var raw: CPointer<Unit> = CPointer<Unit>()
    private var valueObject: Option<Window> = None
    private var closed: Bool = false

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            throw Exception("Window pointer is null")
        }
        this.raw = raw
        valueObject = Some(Window(raw))
    }

    public static func create(): WindowHandle {
        let factory = expectFactory(
            loadFactoryByName(Window.runtimeName(), IWindowFactory.descriptor()),
            "IWindowFactory activation"
        )
        try {
            let table = readWinuiVtbl<IWindowFactoryVtbl>(factory.asRaw())
            var inner = CPointer<Unit>()
            var result = CPointer<Unit>()
            let hr = HRESULT(unsafe {
                table.CreateInstance(
                    factory.asRaw(),
                    CPointer<Unit>(),
                    CPointer<CPointer<Unit>>(inout inner),
                    CPointer<CPointer<Unit>>(inout result)
                )
            })
            if (hr.failed()) {
                releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout inner))
                releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout result))
            }
            checkHRESULT(hr, "IWindowFactory.CreateInstance")
            if (inner.isNotNull()) {
                releaseRaw(inner)
            }
            if (result.isNull()) {
                throw Exception("IWindowFactory.CreateInstance returned null")
            }
            return WindowHandle(result)
        } finally {
            factory.close()
        }
    }

    public func value(): Window {
        match (valueObject) {
            case Some(value) => return value
            case None => throw Exception("Window is closed")
        }
    }

    public func setTitle(value: String): Unit {
        let title = HString(value)
        try {
            let table = readWinuiVtbl<WindowVtbl>(raw)
            try (borrow = winrtBorrowGenericIn<HString>(title)) {
                checkHRESULT(HRESULT(unsafe { table.SetTitle(raw, borrow.asRaw()) }), "IWindow.put_Title")
            }
        } finally {
            title.close()
        }
    }

    public func setContent(content: UIElementHandle): Unit {
        let table = readWinuiVtbl<WindowVtbl>(raw)
        checkHRESULT(HRESULT(unsafe { table.SetContent(raw, content.value().asRaw()) }), "IWindow.put_Content")
    }

    public func activate(): Unit {
        let table = readWinuiVtbl<WindowVtbl>(raw)
        checkHRESULT(HRESULT(unsafe { table.Activate(raw) }), "IWindow.Activate")
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        valueObject = None
        let (nextRaw, nextClosed) = closeWinuiRawStateNoThrow(raw, closed)
        raw = nextRaw
        closed = nextClosed
    }

    ~init() {
        valueObject = None
        let (nextRaw, nextClosed) = finalizeWinuiRawStateNoThrow()
        raw = nextRaw
        closed = nextClosed
    }
}

public class UIElementHandle <: Resource {
    private var raw: CPointer<Unit> = CPointer<Unit>()
    private var valueObject: Option<UIElement> = None
    private var closed: Bool = false

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            throw Exception("UIElement pointer is null")
        }
        this.raw = raw
        valueObject = Some(UIElement(raw))
    }

    public static func loadXaml(value: String): UIElementHandle {
        let xaml = HString(value)
        try {
            let rawInspectable = loadXamlInspectable(xaml)
            try {
                let rawElement = queryRequired(rawInspectable, IUIElement.iid(), IUIElement.runtimeName())
                return UIElementHandle(rawElement)
            } finally {
                releaseRaw(rawInspectable)
            }
        } finally {
            xaml.close()
        }
    }

    public func value(): UIElement {
        match (valueObject) {
            case Some(value) => return value
            case None => throw Exception("UIElement is closed")
        }
    }

    public func findName(name: String): XamlObjectHandle {
        let text = HString(name)
        try {
            let framework = queryRequired(raw, IFrameworkElement.iid(), IFrameworkElement.runtimeName())
            try {
                let table = readWinuiVtbl<IFrameworkElementVtbl>(framework)
                var result = CPointer<Unit>()
                var hr = E_POINTER
                try (borrow = winrtBorrowGenericIn<HString>(text)) {
                    hr = HRESULT(unsafe {
                        table.FindName(framework, borrow.asRaw(), CPointer<CPointer<Unit>>(inout result))
                    })
                }
                if (hr.failed()) {
                    releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout result))
                }
                checkHRESULT(hr, "IFrameworkElement.FindName(${name})")
                if (result.isNull()) {
                    throw Exception("IFrameworkElement.FindName(${name}) returned null")
                }
                return XamlObjectHandle(result)
            } finally {
                releaseRaw(framework)
            }
        } finally {
            text.close()
        }
    }

    public func buttonBase(name: String): ButtonBaseHandle {
        let element = findName(name)
        try {
            return element.buttonBase()
        } finally {
            element.close()
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        valueObject = None
        let (nextRaw, nextClosed) = closeWinuiRawStateNoThrow(raw, closed)
        raw = nextRaw
        closed = nextClosed
    }

    ~init() {
        valueObject = None
        let (nextRaw, nextClosed) = finalizeWinuiRawStateNoThrow()
        raw = nextRaw
        closed = nextClosed
    }
}

public class XamlObjectHandle <: Resource {
    private var raw: CPointer<Unit> = CPointer<Unit>()
    private var closed: Bool = false

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            throw Exception("XAML object pointer is null")
        }
        this.raw = raw
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        raw
    }

    public func buttonBase(): ButtonBaseHandle {
        ButtonBaseHandle(queryRequired(asRaw(), IID_BUTTON_BASE, "Microsoft.UI.Xaml.Controls.Primitives.IButtonBase"))
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        let (nextRaw, nextClosed) = closeWinuiRawStateNoThrow(raw, closed)
        raw = nextRaw
        closed = nextClosed
    }

    ~init() {
        let (nextRaw, nextClosed) = finalizeWinuiRawStateNoThrow()
        raw = nextRaw
        closed = nextClosed
    }
}

public class ButtonBaseHandle <: Resource {
    private var raw: CPointer<Unit> = CPointer<Unit>()
    private var closed: Bool = false

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            throw Exception("ButtonBase pointer is null")
        }
        this.raw = raw
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        raw
    }

    public func onClick(handler: () -> Unit): ClickSubscription {
        let retainedTarget = ButtonBaseHandle(queryRequired(asRaw(), IID_BUTTON_BASE, "Microsoft.UI.Xaml.Controls.Primitives.IButtonBase"))
        ClickSubscription(retainedTarget, handler)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        let (nextRaw, nextClosed) = closeWinuiRawStateNoThrow(raw, closed)
        raw = nextRaw
        closed = nextClosed
    }

    ~init() {
        let (nextRaw, nextClosed) = finalizeWinuiRawStateNoThrow()
        raw = nextRaw
        closed = nextClosed
    }
}

class RoutedEventHandlerHandle <: Resource {
    private var rawObject: CPointer<Unit> = CPointer<Unit>()
    private var slot: Int64 = -1
    private var closed: Bool = false

    public init(handler: () -> Unit) {
        slot = addRoutedEventHandlerSlot(handler)
        let raw = coTaskMemAlloc(sizeOf<RoutedEventHandlerObject>())
        if (raw.isNull()) {
            clearRoutedEventHandlerSlot(slot)
            throw Exception("failed to allocate RoutedEventHandler object")
        }
        var object = RoutedEventHandlerObject()
        object.vtbl = routedEventHandlerVtbl()
        object.refCount = 1u32
        object.slot = slot
        let typed = CPointer<RoutedEventHandlerObject>(raw)
        unsafe { typed.write(object) }
        rawObject = raw
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        rawObject
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        let (nextRawObject, nextSlot, nextClosed) = closeRoutedEventHandlerStateNoThrow(rawObject, slot, closed)
        rawObject = nextRawObject
        slot = nextSlot
        closed = nextClosed
    }

    ~init() {
        let (nextRawObject, nextSlot, nextClosed) = finalizeRoutedEventHandlerStateNoThrow()
        rawObject = nextRawObject
        slot = nextSlot
        closed = nextClosed
    }
}

public class ClickSubscription <: Resource {
    private var target: Option<ButtonBaseHandle> = None
    private var handler: Option<RoutedEventHandlerHandle> = None
    private var token: EventRegistrationToken = 0
    private var closed: Bool = false

    init(target: ButtonBaseHandle, handler: () -> Unit) {
        let routed = RoutedEventHandlerHandle(handler)
        let table = readWinuiVtbl<ButtonBaseVtbl>(target.asRaw())
        var registeredToken: EventRegistrationToken = 0
        try {
            checkHRESULT(
                HRESULT(unsafe {
                    table.AddClick(
                        target.asRaw(),
                        routed.asRaw(),
                        CPointer<EventRegistrationToken>(inout registeredToken)
                    )
                }),
                "IButtonBase.add_Click"
            )
            this.target = Some(target)
            this.handler = Some(routed)
            this.token = registeredToken
        } catch (err: Exception) {
            routed.close()
            target.close()
            throw err
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (!closed) {
            try {
                match (target) {
                    case Some(removeTarget) =>
                        if (removeTarget.asRaw().isNotNull()) {
                            let table = readWinuiVtbl<ButtonBaseVtbl>(removeTarget.asRaw())
                            checkHRESULT(HRESULT(unsafe { table.RemoveClick(removeTarget.asRaw(), token) }), "IButtonBase.remove_Click")
                        }
                    case None => ()
                }
            } finally {
                match (handler) {
                    case Some(routed) => routed.close()
                    case None => ()
                }
                match (target) {
                    case Some(ownedTarget) => ownedTarget.close()
                    case None => ()
                }
                target = None
                handler = None
                closed = true
            }
        }
    }

}

public func startApplication(callback: ApplicationCallback): Unit {
    let statics = expectFactory(
        loadFactoryByName(Application.runtimeName(), IApplicationStatics.descriptor()),
        "IApplicationStatics activation"
    )
    try {
        let table = readWinuiVtbl<IApplicationStaticsVtbl>(statics.asRaw())
        checkHRESULT(HRESULT(unsafe { table.Start(statics.asRaw(), callback.asRaw()) }), "IApplicationStatics.Start")
    } finally {
        statics.close()
    }
}

func loadXamlInspectable(xaml: HString): CPointer<Unit> {
    let statics = expectFactory(
        loadFactoryByName(XamlReader.runtimeName(), IXamlReaderStatics.descriptor()),
        "IXamlReaderStatics activation"
    )
    try {
        let table = readWinuiVtbl<IXamlReaderStaticsVtbl>(statics.asRaw())
        var result = CPointer<Unit>()
        var hr = E_POINTER
        try (borrow = winrtBorrowGenericIn<HString>(xaml)) {
            hr = HRESULT(unsafe {
                table.Load(statics.asRaw(), borrow.asRaw(), CPointer<CPointer<Unit>>(inout result))
            })
        }
        if (hr.failed()) {
            releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout result))
        }
        checkHRESULT(hr, "IXamlReaderStatics.Load")
        if (result.isNull()) {
            throw Exception("IXamlReaderStatics.Load returned null")
        }
        return result
    } finally {
        statics.close()
    }
}

func checkHRESULT(hr: HRESULT, operation: String): Unit {
    if (hr.failed()) {
        let _ = operation
        throw WindowsException(hr)
    }
}

func expectFactory<T>(result: Result<T>, operation: String): T {
    match (result) {
        case Result<T>.Ok(value) => value
        case Result<T>.Err(error) => throw Exception("${operation} failed: ${error}")
    }
}

func releaseRaw(raw: CPointer<Unit>): Unit {
    if (raw.isNotNull()) {
        IUnknown.fromAbiTake(raw).close()
    }
}

func releaseFailedWinuiOutSlot(slot: CPointer<CPointer<Unit>>): Unit {
    if (slot.isNull()) {
        return
    }
    let raw = unsafe { slot.read() }
    if (raw.isNotNull()) {
        unsafe { slot.write(CPointer<Unit>()) }
        releaseRaw(raw)
    }
}

func readWinuiVtbl<T>(raw: CPointer<Unit>): T where T <: CType {
    if (raw.isNull()) {
        throw Exception("WinRT object pointer is null")
    }
    let table = unsafe { CPointer<CPointer<T>>(raw).read() }
    if (table.isNull()) {
        throw Exception("WinRT vtable pointer is null")
    }
    return unsafe { table.read() }
}

func queryRequired(raw: CPointer<Unit>, iid: GUID, name: String): CPointer<Unit> {
    match (unsafe { queryInterfaceRaw(raw, iid) }) {
        case Some(value) => return value
        case None => throw Exception("QueryInterface failed for ${name}: ${E_NOINTERFACE}")
    }
}

func addApplicationInitializationCallbackSlot(handler: () -> Unit): Int64 {
    let index = applicationInitializationCallbackSlots.size
    applicationInitializationCallbackSlots.add(Some(handler))
    return index
}

func clearApplicationInitializationCallbackSlot(slot: Int64): Unit {
    if (slot >= 0 && slot < applicationInitializationCallbackSlots.size) {
        applicationInitializationCallbackSlots[slot] = None
    }
}

func invokeApplicationInitializationCallbackSlot(slot: Int64): Bool {
    if (slot >= 0 && slot < applicationInitializationCallbackSlots.size) {
        match (applicationInitializationCallbackSlots[slot]) {
            case Some(handler) =>
                handler()
                return true
            case None => return false
        }
    }
    false
}

func addRoutedEventHandlerSlot(handler: () -> Unit): Int64 {
    let index = routedEventHandlerSlots.size
    routedEventHandlerSlots.add(Some(handler))
    return index
}

func clearRoutedEventHandlerSlot(slot: Int64): Unit {
    if (slot >= 0 && slot < routedEventHandlerSlots.size) {
        routedEventHandlerSlots[slot] = None
    }
}

func invokeRoutedEventHandlerSlot(slot: Int64): Bool {
    if (slot >= 0 && slot < routedEventHandlerSlots.size) {
        match (routedEventHandlerSlots[slot]) {
            case Some(handler) =>
                handler()
                return true
            case None => return false
        }
    }
    false
}

func deactivateApplicationInitializationCallbackObject(raw: CPointer<Unit>): Unit {
    if (raw.isNull()) {
        return
    }
    let obj = CPointer<ApplicationInitializationCallbackObject>(raw)
    var value = unsafe { obj.read() }
    if (value.slot >= 0) {
        clearApplicationInitializationCallbackSlot(value.slot)
        value.slot = -1
        unsafe { obj.write(value) }
    }
}

func deactivateRoutedEventHandlerObject(raw: CPointer<Unit>): Unit {
    if (raw.isNull()) {
        return
    }
    let obj = CPointer<RoutedEventHandlerObject>(raw)
    var value = unsafe { obj.read() }
    if (value.slot >= 0) {
        clearRoutedEventHandlerSlot(value.slot)
        value.slot = -1
        unsafe { obj.write(value) }
    }
}

@C
func applicationInitializationCallbackQueryInterface(thisPtr: CPointer<Unit>, iidPtr: CPointer<GUID>, result: CPointer<CPointer<Unit>>): Int32 {
    if (thisPtr.isNull() || iidPtr.isNull() || result.isNull()) {
        if (result.isNotNull()) {
            unsafe { result.write(CPointer<Unit>()) }
        }
        return E_POINTER.value
    }
    let iid = unsafe { iidPtr.read() }
    if (iid == IID_IUNKNOWN || iid == IID_APPLICATION_INITIALIZATION_CALLBACK) {
        unsafe { result.write(thisPtr) }
        unsafe { applicationInitializationCallbackAddRef(thisPtr) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    return E_NOINTERFACE.value
}

@C
func applicationInitializationCallbackAddRef(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = CPointer<ApplicationInitializationCallbackObject>(thisPtr)
    var value = unsafe { obj.read() }
    value.refCount += 1u32
    unsafe { obj.write(value) }
    return value.refCount
}

@C
func applicationInitializationCallbackRelease(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = CPointer<ApplicationInitializationCallbackObject>(thisPtr)
    var value = unsafe { obj.read() }
    if (value.refCount == 0u32) {
        return 0u32
    }
    value.refCount -= 1u32
    let refCount = value.refCount
    if (refCount == 0u32) {
        if (value.slot >= 0) {
            clearApplicationInitializationCallbackSlot(value.slot)
            value.slot = -1
        }
        unsafe { obj.write(value) }
        coTaskMemFree(thisPtr)
        return 0u32
    }
    unsafe { obj.write(value) }
    return refCount
}

@C
func applicationInitializationCallbackInvoke(thisPtr: CPointer<Unit>, _: CPointer<Unit>): Int32 {
    if (thisPtr.isNull()) {
        return E_POINTER.value
    }
    let obj = CPointer<ApplicationInitializationCallbackObject>(thisPtr)
    let value = unsafe { obj.read() }
    try {
        if (!invokeApplicationInitializationCallbackSlot(value.slot)) {
            return E_POINTER.value
        }
        return S_OK.value
    } catch (error: WindowsException) {
        return error.code().value
    } catch (err: Exception) {
        println("ApplicationInitializationCallback failed: ${err}")
        return E_FAIL.value
    }
}

func applicationInitializationCallbackVtbl(): CPointer<ApplicationInitializationCallbackVtbl> {
    if (applicationInitializationCallbackVtblStorage.isNotNull()) {
        return applicationInitializationCallbackVtblStorage
    }
    let raw = coTaskMemAlloc(sizeOf<ApplicationInitializationCallbackVtbl>())
    if (raw.isNull()) {
        throw Exception("failed to allocate ApplicationInitializationCallback vtable")
    }
    var table = ApplicationInitializationCallbackVtbl()
    table.base_.QueryInterface = applicationInitializationCallbackQueryInterface
    table.base_.AddRef = applicationInitializationCallbackAddRef
    table.base_.Release = applicationInitializationCallbackRelease
    table.Invoke = applicationInitializationCallbackInvoke
    let typed = CPointer<ApplicationInitializationCallbackVtbl>(raw)
    unsafe { typed.write(table) }
    applicationInitializationCallbackVtblStorage = typed
    return typed
}

@C
func routedEventHandlerQueryInterface(thisPtr: CPointer<Unit>, iidPtr: CPointer<GUID>, result: CPointer<CPointer<Unit>>): Int32 {
    if (thisPtr.isNull() || iidPtr.isNull() || result.isNull()) {
        if (result.isNotNull()) {
            unsafe { result.write(CPointer<Unit>()) }
        }
        return E_POINTER.value
    }
    let iid = unsafe { iidPtr.read() }
    if (iid == IID_IUNKNOWN || iid == IID_ROUTED_EVENT_HANDLER) {
        unsafe { result.write(thisPtr) }
        unsafe { routedEventHandlerAddRef(thisPtr) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    return E_NOINTERFACE.value
}

@C
func routedEventHandlerAddRef(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = CPointer<RoutedEventHandlerObject>(thisPtr)
    var value = unsafe { obj.read() }
    value.refCount += 1u32
    unsafe { obj.write(value) }
    return value.refCount
}

@C
func routedEventHandlerRelease(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = CPointer<RoutedEventHandlerObject>(thisPtr)
    var value = unsafe { obj.read() }
    if (value.refCount == 0u32) {
        return 0u32
    }
    value.refCount -= 1u32
    let refCount = value.refCount
    if (refCount == 0u32) {
        if (value.slot >= 0) {
            clearRoutedEventHandlerSlot(value.slot)
            value.slot = -1
        }
        unsafe { obj.write(value) }
        coTaskMemFree(thisPtr)
        return 0u32
    }
    unsafe { obj.write(value) }
    return refCount
}

@C
func routedEventHandlerInvoke(thisPtr: CPointer<Unit>, _: CPointer<Unit>, _: CPointer<Unit>): Int32 {
    if (thisPtr.isNull()) {
        return E_POINTER.value
    }
    let obj = CPointer<RoutedEventHandlerObject>(thisPtr)
    let value = unsafe { obj.read() }
    try {
        if (!invokeRoutedEventHandlerSlot(value.slot)) {
            return E_POINTER.value
        }
        return S_OK.value
    } catch (error: WindowsException) {
        return error.code().value
    } catch (err: Exception) {
        println("RoutedEventHandler failed: ${err}")
        return E_FAIL.value
    }
}

func routedEventHandlerVtbl(): CPointer<RoutedEventHandlerVtbl> {
    if (routedEventHandlerVtblStorage.isNotNull()) {
        return routedEventHandlerVtblStorage
    }
    let raw = coTaskMemAlloc(sizeOf<RoutedEventHandlerVtbl>())
    if (raw.isNull()) {
        throw Exception("failed to allocate RoutedEventHandler vtable")
    }
    var table = RoutedEventHandlerVtbl()
    table.QueryInterface = routedEventHandlerQueryInterface
    table.AddRef = routedEventHandlerAddRef
    table.Release = routedEventHandlerRelease
    table.Invoke = routedEventHandlerInvoke
    let typed = CPointer<RoutedEventHandlerVtbl>(raw)
    unsafe { typed.write(table) }
    routedEventHandlerVtblStorage = typed
    return typed
}
