package windows_reactor.winui

import std.collection.ArrayList
import std.math.round
import windows_sys.Microsoft.UI.Xaml.{
    Application,
    IApplicationFactory,
    IApplicationFactoryVtbl,
    IApplicationOverrides,
    IApplicationStatics,
    IApplicationStaticsVtbl,
    IUIElement,
    IWindowFactory,
    IWindowFactoryVtbl,
    UIElement,
    Window
}
import windows_sys.Microsoft.UI.Xaml.{ResourceDictionary}
import windows_sys.Microsoft.UI.Xaml.{ResourceManagerRequestedEventArgs}
import windows_sys.Microsoft.Windows.ApplicationModel.Resources.{ResourceManager}
import windows_sys.Foundation.{TypedEventHandler}
// Window-sizing path: IWindow2 exposes AppWindow; AppWindow.Resize takes a SizeInt32.
// Title-bar height path: AppWindow.TitleBar (an AppWindowTitleBar) QI'd to
// IAppWindowTitleBar2 carries PreferredHeightOption (Tall / Standard).
import windows_sys.Microsoft.UI.Windowing.{AppWindow, TitleBarHeightOption}
import windows_sys.Graphics.{SizeInt32}
import windows_sys.impl.Microsoft_UI_Windowing.{Microsoft_UI_Windowing_TitleBarHeightOption_Tall, Microsoft_UI_Windowing_TitleBarHeightOption_Standard}
import windows_sys.impl.Windows_UI_Xaml_Interop.{Windows_UI_Xaml_Interop_TypeName}
import windows_core.{
    E_FAIL,
    E_NOINTERFACE,
    E_NOTIMPL,
    E_POINTER,
    GUID,
    HString,
    HRESULT,
    IGenericFactory,
    IInspectableVtbl,
    IUnknownVtbl,
    IID_IUNKNOWN,
    OutSlot,
    Result,
    S_OK,
    WindowsException,
    coTaskMemAlloc,
    coTaskMemFree,
    loadFactoryByName,
    queryInterfaceRaw
}
import windows_interface.{IInspectable, IID_IINSPECTABLE}

// ============================================================================
// WinUI host: composed Application (IApplicationOverrides + IXamlMetadataProvider
// aggregation), ApplicationCallback, Window creation, and XAML controls
// resource install. Behaviour-equivalent to the proven runtime-only host;
// the imperative backend instantiates controls via projection classes so the
// XAML-loading helpers are not carried over.
// ============================================================================

let IID_APPLICATION_INITIALIZATION_CALLBACK = GUID.from_values(3639538121u32, 4660u16, 22257u16, 153u8, 99u8, 69u8, 221u8, 156u8, 128u8, 166u8, 97u8)
let IID_XAML_METADATA_PROVIDER = GUID.from_values(0xA96251F0u32, 0x2214u16, 0x5D53u16, 0x87u8, 0x46u8, 0xCEu8, 0x99u8, 0xA2u8, 0x59u8, 0x3Cu8, 0xD7u8)

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
struct ApplicationOverridesVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var OnLaunched: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

@C
struct XamlMetadataProviderVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var GetXamlType: CFunc<(CPointer<Unit>, Windows_UI_Xaml_Interop_TypeName, CPointer<CPointer<Unit>>) -> Int32> = { _, _, result =>
        if (result.isNotNull()) {
            unsafe { result.write(CPointer<Unit>()) }
        }
        E_NOTIMPL.value
    }
    public var GetXamlTypeByFullName: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, result =>
        if (result.isNotNull()) {
            unsafe { result.write(CPointer<Unit>()) }
        }
        E_NOTIMPL.value
    }
    public var GetXmlnsDefinitions: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<Unit>>) -> Int32> = { _, size, values =>
        if (size.isNotNull()) {
            unsafe { size.write(0u32) }
        }
        if (values.isNotNull()) {
            unsafe { values.write(CPointer<Unit>()) }
        }
        E_NOTIMPL.value
    }
    public init() {}
}

@C
struct ApplicationOverridesObject {
    public var baseRaw: CPointer<Unit> = CPointer<Unit>()
    public var vtbl: CPointer<ApplicationOverridesVtbl> = CPointer<ApplicationOverridesVtbl>()
    public var refCount: UInt32 = 1u32
    public var slot: Int64 = -1
    public init() {}
}

@C
struct XamlMetadataProviderObject {
    public var vtbl: CPointer<XamlMetadataProviderVtbl> = CPointer<XamlMetadataProviderVtbl>()
    public var refCount: UInt32 = 1u32
    public var slot: Int64 = -1
    public init() {}
}

class ApplicationCompositionState {
    public var onLaunched: Option<() -> Unit>
    public var overridesRaw: CPointer<Unit> = CPointer<Unit>()
    public var metadataRaw: CPointer<Unit> = CPointer<Unit>()
    public var appRaw: CPointer<Unit> = CPointer<Unit>()
    public var innerRaw: CPointer<Unit> = CPointer<Unit>()
    public var controlsProviderRaw: CPointer<Unit> = CPointer<Unit>()
    public var resourceManagerRequestedHandler: Option<TypedEventHandler<IInspectable, ResourceManagerRequestedEventArgs>> = None
    public var resourceManagerRequestedToken: Int64 = 0
    public var xamlResourceManager: Option<ResourceManager> = None

    public init(onLaunched: () -> Unit) {
        this.onLaunched = Some(onLaunched)
    }
}

var applicationInitializationCallbackVtblStorage: CPointer<ApplicationInitializationCallbackVtbl> = CPointer<ApplicationInitializationCallbackVtbl>()
var applicationInitializationCallbackSlots: ArrayList<Option<() -> Unit>> = ArrayList<Option<() -> Unit>>()
var applicationOverridesVtblStorage: CPointer<ApplicationOverridesVtbl> = CPointer<ApplicationOverridesVtbl>()
var xamlMetadataProviderVtblStorage: CPointer<XamlMetadataProviderVtbl> = CPointer<XamlMetadataProviderVtbl>()
var applicationCompositionSlots: ArrayList<Option<ApplicationCompositionState>> = ArrayList<Option<ApplicationCompositionState>>()

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

public class ApplicationHost <: Resource {
    private var overrides: Option<ApplicationOverridesHandle> = None
    private var appObject: Option<Application> = None
    private var closed: Bool = false

    public init(onLaunched: () -> Unit) {
        let overridesHandle = ApplicationOverridesHandle(onLaunched)
        try {
            let app = createComposedApplication(overridesHandle.asRaw(), overridesHandle.baseSlot())
            appObject = Some(app)
            overridesHandle.setApplicationRaw(app.asRaw())
            overridesHandle.setInnerRaw(overridesHandle.innerRaw())
            overridesHandle.registerResourceManagerRequested(app)
            overrides = Some(overridesHandle)
        } catch (error: Exception) {
            overridesHandle.close()
            throw error
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (!closed) {
            match (appObject) {
                case Some(app) => app.close()
                case None => ()
            }
            match (overrides) {
                case Some(handle) => handle.close()
                case None => ()
            }
            appObject = None
            overrides = None
            closed = true
        }
    }

    ~init() {
        appObject = None
        overrides = None
        closed = true
    }
}

class ApplicationOverridesHandle <: Resource {
    private var overridesRaw: CPointer<Unit> = CPointer<Unit>()
    private var metadataRaw: CPointer<Unit> = CPointer<Unit>()
    private var slot: Int64 = -1
    private var closed: Bool = false

    public init(onLaunched: () -> Unit) {
        slot = addApplicationCompositionSlot(onLaunched)
        let overridesObjectRaw = coTaskMemAlloc(sizeOf<ApplicationOverridesObject>())
        if (overridesObjectRaw.isNull()) {
            clearApplicationCompositionSlot(slot)
            throw Exception("failed to allocate Application overrides object")
        }
        let metadataObjectRaw = coTaskMemAlloc(sizeOf<XamlMetadataProviderObject>())
        if (metadataObjectRaw.isNull()) {
            coTaskMemFree(overridesObjectRaw)
            clearApplicationCompositionSlot(slot)
            throw Exception("failed to allocate XAML metadata provider object")
        }

        var overridesObject = ApplicationOverridesObject()
        overridesObject.baseRaw = CPointer<Unit>()
        overridesObject.vtbl = applicationOverridesVtbl()
        overridesObject.refCount = 1u32
        overridesObject.slot = slot
        unsafe { CPointer<ApplicationOverridesObject>(overridesObjectRaw).write(overridesObject) }

        var metadataObject = XamlMetadataProviderObject()
        metadataObject.vtbl = xamlMetadataProviderVtbl()
        metadataObject.refCount = 1u32
        metadataObject.slot = slot
        unsafe { CPointer<XamlMetadataProviderObject>(metadataObjectRaw).write(metadataObject) }

        overridesRaw = applicationOverridesInterfaceRaw(overridesObjectRaw)
        metadataRaw = metadataObjectRaw
        setApplicationCompositionRawObjects(slot, overridesRaw, metadataRaw)
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        overridesRaw
    }

    public func isClosed(): Bool {
        closed
    }

    public func setApplicationRaw(raw: CPointer<Unit>): Unit {
        setApplicationCompositionAppRaw(slot, raw)
    }

    public func setInnerRaw(raw: CPointer<Unit>): Unit {
        setApplicationCompositionInnerRaw(slot, raw)
    }

    public func registerResourceManagerRequested(app: Application): Unit {
        registerApplicationResourceManagerRequested(app, slot)
    }

    public func baseSlot(): CPointer<CPointer<Unit>> {
        if (closed) {
            return CPointer<CPointer<Unit>>()
        }
        applicationOverridesBaseSlot(overridesRaw)
    }

    public func innerRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        applicationOverridesBaseRaw(overridesRaw)
    }

    public func close(): Unit {
        if (!closed) {
            clearApplicationCompositionSlot(slot)
            if (overridesRaw.isNotNull()) {
                let _ = unsafe { applicationOverridesRelease(overridesRaw) }
            }
            if (metadataRaw.isNotNull()) {
                let _ = unsafe { xamlMetadataProviderRelease(metadataRaw) }
            }
            overridesRaw = CPointer<Unit>()
            metadataRaw = CPointer<Unit>()
            slot = -1
            closed = true
        }
    }

    ~init() {
        overridesRaw = CPointer<Unit>()
        metadataRaw = CPointer<Unit>()
        slot = -1
        closed = true
    }
}

func createComposedApplication(baseRaw: CPointer<Unit>, innerSlot: CPointer<CPointer<Unit>>): Application {
    if (baseRaw.isNull() || innerSlot.isNull()) {
        throw WindowsException(E_POINTER)
    }
    unsafe { innerSlot.write(CPointer<Unit>()) }
    let factory = expectFactory(
        loadFactoryByName(Application.runtimeName(), IApplicationFactory.descriptor()),
        "IApplicationFactory activation"
    )
    try {
        let table = readWinuiVtbl<IApplicationFactoryVtbl>(factory.asRaw())
        var result = CPointer<Unit>()
        let hr = HRESULT(unsafe {
            table.CreateInstance(
                factory.asRaw(),
                baseRaw,
                innerSlot,
                CPointer<CPointer<Unit>>(inout result)
            )
        })
        if (hr.failed()) {
            let innerRaw = unsafe { innerSlot.read() }
            if (innerRaw.isNotNull()) {
                releaseRaw(innerRaw)
                unsafe { innerSlot.write(CPointer<Unit>()) }
            }
            releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout result))
        }
        checkHRESULT(hr, "IApplicationFactory.CreateInstance")
        if (result.isNull()) {
            throw Exception("IApplicationFactory.CreateInstance returned null")
        }
        return Application.fromAbiTake(result)
    } finally {
        factory.close()
    }
}

// Composition-factory IIDs for the two concrete backdrop runtime classes. Each
// class is a composable XAML type (DependencyObject-derived); its activation
// factory implements a per-class composition factory whose CreateInstance(outer,
// inner, result) is the only working activation entry — the parameterless
// IActivationFactory.ActivateInstance is rejected by composable classes. These
// are declared before WindowHandle (which uses them in setSystemBackdrop) because
// Cangjie does not allow forward references to top-level `let` variables.
//   IMicaBackdropFactory            = 774379ce-74bd-59d4-849d-d99c4184d838
//   IDesktopAcrylicBackdropFactory  = 00922e6d-ae51-564a-bce2-1973d5e463dd
let IID_IMICA_BACKDROP_FACTORY = GUID.from_values(0x774379ceu32, 0x74bdu16, 0x59d4u16, 0x84u8, 0x9du8, 0xd9u8, 0x9cu8, 0x41u8, 0x84u8, 0xd8u8, 0x38u8)
let IID_IDESKTOP_ACRYLIC_BACKDROP_FACTORY = GUID.from_values(0x00922e6du32, 0xae51u16, 0x564au16, 0xbcu8, 0xe2u8, 0x19u8, 0x73u8, 0xd5u8, 0xe4u8, 0x63u8, 0xddu8)

public class WindowHandle <: Resource {
    private var raw: CPointer<Unit> = CPointer<Unit>()
    private var valueObject: Option<Window> = None
    private var closed: Bool = false

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            throw Exception("Window pointer is null")
        }
        this.raw = raw
        valueObject = Some(Window.viewOf(raw))
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

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        raw
    }

    public func setTitle(title: String): Unit {
        value().Title = HString(title)
    }

    // Set the window content from a raw UIElement pointer (owned by the backend's
    // Handle map). We view (non-owning) the element so the put_Content AddRefs it.
    public func setContent(elementRaw: CPointer<Unit>): Unit {
        if (elementRaw.isNull()) {
            return
        }
        value().Content = UIElement.viewOf(elementRaw)
    }

    // Opt the window into a custom-drawn title bar: the app content is extended
    // into the title-bar region so a mounted TitleBar control can take over the
    // caption + drag region (mirrors the reference put_ExtendsContentIntoTitleBar).
    // Both APIs live on the default IWindow interface of the projected Window.
    public func setExtendsContentIntoTitleBar(extends: Bool): Unit {
        value().ExtendsContentIntoTitleBar = extends
    }

    // Designate a UIElement (a live TitleBar control's IUIElement) as the window's
    // title bar / drag region. The element is viewed non-owning so the SetTitleBar
    // setter AddRefs it (same ownership shape as setContent). Mirrors the reference
    // window.SetTitleBar(tb.cast::<UIElement>()).
    public func setTitleBar(elementRaw: CPointer<Unit>): Unit {
        if (elementRaw.isNull()) {
            return
        }
        value().SetTitleBar(UIElement.viewOf(elementRaw))
    }

    // Resize the window to an initial client/window size in logical pixels.
    // Window has no direct sizing surface; the size lives on the AppWindow,
    // reached via IWindow2.AppWindow. AppWindow.Resize takes a SizeInt32 in
    // physical pixels — we round the requested logical size to the nearest
    // integer (behaviour-equivalent to App::inner_size at the default 1.0 scale;
    // per-monitor DPI scaling is applied by the windowing layer). Failures
    // (no AppWindow yet, resize rejected) are swallowed so a sizing hint never
    // aborts startup.
    public func setInitialSize(width: Float64, height: Float64): Unit {
        if (width <= 0.0 || height <= 0.0) {
            return
        }
        try {
            let window = value()
            // IWindow2.AppWindow(out) — query the per-window AppWindow.
            var appWindowRaw = CPointer<Unit>()
            try (w2 = window.asIWindow2()) {
                let hr = unsafe {
                    w2.AppWindow(CPointer<CPointer<Unit>>(inout appWindowRaw))
                }
                if (hr.failed() && appWindowRaw.isNotNull()) {
                    releaseRaw(appWindowRaw)
                    appWindowRaw = CPointer<Unit>()
                }
                checkHRESULT(hr, "IWindow2.AppWindow")
            }
            if (appWindowRaw.isNull()) {
                return
            }
            let appWindow = AppWindow.fromAbiTake(appWindowRaw)
            try {
                var size = SizeInt32()
                size.Width = Int32(round(width))
                size.Height = Int32(round(height))
                appWindow.Resize(size)
            } finally {
                appWindow.close()
            }
        } catch (_: Exception) {
            // No AppWindow available (or resize rejected) — leave the default size.
            ()
        }
    }

    // Apply a system backdrop material (Mica / Acrylic) to the window. The
    // concrete backdrop runtime classes (MicaBackdrop / DesktopAcrylicBackdrop)
    // are not surfaced by the curated projection, so the instance is activated by
    // runtime-class name (the same generic-factory activation path the host uses
    // for XamlControlsResources) and assigned through IWindow2.SetSystemBackdrop
    // (raw ABI). Backdrop.None_ clears any system backdrop. Activation failures
    // (class unavailable in the running runtime) degrade to no backdrop.
    public func setSystemBackdrop(backdrop: Backdrop): Unit {
        // Each concrete backdrop runtime class is a COMPOSABLE XAML class
        // (DependencyObject-derived) so it is activated through its per-class
        // composition factory's CreateInstance — NOT the parameterless
        // IActivationFactory.ActivateInstance (which composable classes reject).
        // Pair each runtime name with its composition factory IID.
        // GUID is an @C struct and cannot be a tuple member, so the option only
        // carries the runtime-class name; the consumer derives the factory IID
        // from the name.
        let activation = match (backdrop) {
            case Mica => Some("Microsoft.UI.Xaml.Media.MicaBackdrop")
            case MicaAlt => Some("Microsoft.UI.Xaml.Media.MicaBackdrop")
            case Acrylic => Some("Microsoft.UI.Xaml.Media.DesktopAcrylicBackdrop")
            case None_ => Option<String>.None
        }
        try {
            let window = value()
            match (activation) {
                case Some(name) =>
                    let factoryIid = if (name == "Microsoft.UI.Xaml.Media.DesktopAcrylicBackdrop") {
                        IID_IDESKTOP_ACRYLIC_BACKDROP_FACTORY
                    } else {
                        IID_IMICA_BACKDROP_FACTORY
                    }
                    let backdropRaw = activateBackdropByName(name, factoryIid)
                    if (backdropRaw.isNull()) {
                        return
                    }
                    // MicaAlt is MicaBackdrop with Kind = BaseAlt; set it via raw
                    // ABI before assigning (MicaBackdrop isn't in the projection).
                    match (backdrop) {
                        case MicaAlt => setMicaBackdropBaseAlt(backdropRaw)
                        case _ => ()
                    }
                    try {
                        try (w2 = window.asIWindow2()) {
                            checkHRESULT(
                                unsafe { w2.SetSystemBackdrop(backdropRaw) },
                                "IWindow2.SetSystemBackdrop"
                            )
                        }
                    } finally {
                        releaseRaw(backdropRaw)
                    }
                case None =>
                    // Clear any previously-applied system backdrop.
                    try (w2 = window.asIWindow2()) {
                        let _ = unsafe { w2.SetSystemBackdrop(CPointer<Unit>()) }
                    }
            }
        } catch (_: Exception) {
            // Backdrop class unavailable in this runtime — leave a plain surface.
            ()
        }
    }

    // Select the custom title bar height (Tall vs Standard) on the window's
    // AppWindow. Mirrors the reference host::set_titlebar_height: navigate
    // IWindow2.AppWindow → AppWindow.TitleBar, QI to IAppWindowTitleBar2, and
    // SetPreferredHeightOption(Tall|Standard). Best-effort: the option is
    // silently ignored by the platform unless the window has already opted into
    // a custom drawn title bar (Window.ExtendsContentIntoTitleBar = true); when
    // no AppWindow is available yet (or the title-bar interface is absent on the
    // running runtime) the request degrades to a no-op rather than aborting the
    // render. (Behaviour-equivalent to the reference's `.ok()` swallow; the
    // reference also queues a pending value for early calls, but here the active
    // window is registered before the first render so props always see it.)
    public func setTitlebarHeight(tall: Bool): Unit {
        let option = if (tall) {
            Microsoft_UI_Windowing_TitleBarHeightOption_Tall
        } else {
            Microsoft_UI_Windowing_TitleBarHeightOption_Standard
        }
        try {
            let window = value()
            // IWindow2.AppWindow(out) — query the per-window AppWindow (same path
            // as setInitialSize).
            var appWindowRaw = CPointer<Unit>()
            try (w2 = window.asIWindow2()) {
                let hr = unsafe {
                    w2.AppWindow(CPointer<CPointer<Unit>>(inout appWindowRaw))
                }
                if (hr.failed() && appWindowRaw.isNotNull()) {
                    releaseRaw(appWindowRaw)
                    appWindowRaw = CPointer<Unit>()
                }
                checkHRESULT(hr, "IWindow2.AppWindow")
            }
            if (appWindowRaw.isNull()) {
                return
            }
            let appWindow = AppWindow.fromAbiTake(appWindowRaw)
            try {
                // AppWindow.TitleBar (high-level prop) owns one ref to the
                // AppWindowTitleBar; QI it to IAppWindowTitleBar2 for the height
                // option and assign through the raw ABI setter.
                let titleBar = appWindow.TitleBar
                try {
                    try (tb2 = titleBar.asIAppWindowTitleBar2()) {
                        checkHRESULT(
                            unsafe { tb2.SetPreferredHeightOption(option.value) },
                            "IAppWindowTitleBar2.SetPreferredHeightOption"
                        )
                    }
                } finally {
                    titleBar.close()
                }
            } finally {
                appWindow.close()
            }
        } catch (_: Exception) {
            // No AppWindow / title-bar interface available — leave the default
            // (Standard) height.
            ()
        }
    }

    public func activate(): Unit {
        value().Activate()
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

public func installXamlControlsResources(): Unit {
    let app = Application.Current()
    try {
        installXamlControlsResourcesForApp(app)
    } finally {
        app.close()
    }
}

public func installXamlControlsResourcesForApp(app: Application): Unit {
    let controls = createXamlControlsResources()
    try {
        let resources = app.Resources
        try {
            let merged = resources.MergedDictionaries
            try {
                checkHRESULT(
                    unsafe { merged.Append(controls.asRaw()) },
                    "Application.Resources.MergedDictionaries.Append(XamlControlsResources)"
                )
            } finally {
                merged.close()
            }
        } finally {
            resources.close()
        }
    } finally {
        controls.close()
    }
}

// IMicaBackdrop IID (c156a404-3dac-593a-b1f3-7a33c289dc83) and its raw vtable:
// IInspectable base + get_Kind + put_Kind. The concrete MicaBackdrop runtime
// class is not in the curated projection, so its Kind is set through this
// hand-described vtable (mirrors the reference mica.cast::<IMicaBackdrop>()).
let IID_IMICA_BACKDROP = GUID.from_values(0xc156a404u32, 0x3dacu16, 0x593au16, 0xb1u8, 0xf3u8, 0x7au8, 0x33u8, 0xc2u8, 0x89u8, 0xdcu8, 0x83u8)

@C
struct IMicaBackdropVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var getKind: CPointer<Unit> = CPointer<Unit>()
    public var putKind: CFunc<(CPointer<Unit>, Int32) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

// Set a freshly-activated MicaBackdrop's Kind to BaseAlt (MicaKind.BaseAlt = 1)
// via raw ABI. Best-effort: if the instance does not answer IMicaBackdrop the
// call is skipped, leaving the default Base tint.
func setMicaBackdropBaseAlt(micaRaw: CPointer<Unit>): Unit {
    match (unsafe { queryInterfaceRaw(micaRaw, IID_IMICA_BACKDROP) }) {
        case Some(iface) =>
            try {
                let vtbl = readWinuiVtbl<IMicaBackdropVtbl>(iface)
                let _ = unsafe { vtbl.putKind(iface, 1) }
            } finally {
                releaseRaw(iface)
            }
        case None => ()
    }
}

// Hand-described composition-factory vtable: IInspectable base + CreateInstance.
// The ABI matches both IMicaBackdropFactory_Vtbl and
// IDesktopAcrylicBackdropFactory_Vtbl — CreateInstance(this, outer, innerOut,
// instanceOut). For a non-aggregated activation we pass a null `outer` and read
// the produced instance out of `instanceOut` (the `innerOut` slot receives the
// controlling-inner identity, which we release).
@C
struct IBackdropCompositionFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var CreateInstance: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public init() {}
}

// Activate a composable WinUI backdrop runtime class by name through its
// per-class composition factory and return the new instance's raw IInspectable
// identity (caller owns one ref and must release it). Returns a null pointer
// when the class / composition factory is not available in the running runtime
// (the concrete backdrop classes are not in the curated projection, so the
// hand-described CreateInstance vtable is the only available path). The caller
// passes the returned identity to IWindow2.SetSystemBackdrop, which QIs it to
// ISystemBackdrop internally. Mirrors the reference MicaBackdrop::new() /
// DesktopAcrylicBackdrop::new(), which call the composition-factory CreateInstance
// with null outer/inner.
func activateBackdropByName(runtimeName: String, factoryIid: GUID): CPointer<Unit> {
    let factoryResult = loadFactoryByName(runtimeName, IGenericFactory.descriptor())
    let factory = match (factoryResult) {
        case Result<IGenericFactory>.Ok(value) => value
        case Result<IGenericFactory>.Err(_) => return CPointer<Unit>()
    }
    try {
        // QI the activation factory to its per-class composition factory; the
        // activation factory object implements both IActivationFactory and the
        // composition factory interface.
        let compositionFactory = match (unsafe { queryInterfaceRaw(factory.asRaw(), factoryIid) }) {
            case Some(iface) => iface
            case None => return CPointer<Unit>()
        }
        try {
            let table = readWinuiVtbl<IBackdropCompositionFactoryVtbl>(compositionFactory)
            var instance = CPointer<Unit>()
            // Non-aggregated activation: null outer AND null inner-out slot (we do
            // not want the controlling-inner identity back), only the instance out
            // slot — exactly mirroring the reference MicaBackdrop::new() /
            // DesktopAcrylicBackdrop::new() CreateInstance(null, null, &mut result).
            let hr = HRESULT(unsafe {
                table.CreateInstance(
                    compositionFactory,
                    CPointer<Unit>(),
                    CPointer<CPointer<Unit>>(),
                    CPointer<CPointer<Unit>>(inout instance)
                )
            })
            if (hr.failed()) {
                releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout instance))
                return CPointer<Unit>()
            }
            return instance
        } finally {
            releaseRaw(compositionFactory)
        }
    } finally {
        factory.close()
    }
}

func createXamlControlsResources(): ResourceDictionary {
    let factory = expectFactory(
        loadFactoryByName(
            "Microsoft.UI.Xaml.Controls.XamlControlsResources",
            IGenericFactory.descriptor()
        ),
        "XamlControlsResources activation"
    )
    try {
        var rawInspectable = CPointer<Unit>()
        let hr = unsafe { factory.activateInstanceRaw(CPointer<CPointer<Unit>>(inout rawInspectable)) }
        if (hr.failed()) {
            releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout rawInspectable))
        }
        checkHRESULT(hr, "XamlControlsResources.ActivateInstance")
        if (rawInspectable.isNull()) {
            throw Exception("XamlControlsResources.ActivateInstance returned null")
        }
        try {
            let rawDictionary = queryRequired(
                rawInspectable,
                ResourceDictionary.iid(),
                ResourceDictionary.runtimeName()
            )
            return ResourceDictionary.fromAbiTake(rawDictionary)
        } finally {
            releaseRaw(rawInspectable)
        }
    } finally {
        factory.close()
    }
}

// ── composition slot registry ──────────────────────────────────────────────

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

func addApplicationCompositionSlot(handler: () -> Unit): Int64 {
    let index = applicationCompositionSlots.size
    applicationCompositionSlots.add(Some(ApplicationCompositionState(handler)))
    return index
}

func setApplicationCompositionRawObjects(slot: Int64, overridesRaw: CPointer<Unit>, metadataRaw: CPointer<Unit>): Unit {
    if (slot >= 0 && slot < applicationCompositionSlots.size) {
        match (applicationCompositionSlots[slot]) {
            case Some(state) =>
                state.overridesRaw = overridesRaw
                state.metadataRaw = metadataRaw
            case None => ()
        }
    }
}

func setApplicationCompositionAppRaw(slot: Int64, appRaw: CPointer<Unit>): Unit {
    if (slot >= 0 && slot < applicationCompositionSlots.size) {
        match (applicationCompositionSlots[slot]) {
            case Some(state) => state.appRaw = appRaw
            case None => ()
        }
    }
}

func setApplicationCompositionInnerRaw(slot: Int64, innerRaw: CPointer<Unit>): Unit {
    if (slot >= 0 && slot < applicationCompositionSlots.size) {
        match (applicationCompositionSlots[slot]) {
            case Some(state) => state.innerRaw = innerRaw
            case None => ()
        }
    }
}

func clearApplicationCompositionSlot(slot: Int64): Unit {
    if (slot >= 0 && slot < applicationCompositionSlots.size) {
        match (applicationCompositionSlots[slot]) {
            case Some(state) =>
                if (state.controlsProviderRaw.isNotNull()) {
                    releaseRaw(state.controlsProviderRaw)
                    state.controlsProviderRaw = CPointer<Unit>()
                }
                match (state.resourceManagerRequestedHandler) {
                    case Some(handler) => handler.close()
                    case None => ()
                }
                match (state.xamlResourceManager) {
                    case Some(manager) => manager.close()
                    case None => ()
                }
            case None => ()
        }
        applicationCompositionSlots[slot] = None
    }
}

func applicationCompositionState(slot: Int64): Option<ApplicationCompositionState> {
    if (slot >= 0 && slot < applicationCompositionSlots.size) {
        return applicationCompositionSlots[slot]
    }
    None
}

func applicationOverridesObjectRaw(interfaceRaw: CPointer<Unit>): CPointer<ApplicationOverridesObject> {
    if (interfaceRaw.isNull()) {
        return CPointer<ApplicationOverridesObject>()
    }
    let identityField = CPointer<CPointer<Unit>>(interfaceRaw)
    CPointer<ApplicationOverridesObject>(unsafe { identityField + (-1) })
}

func applicationOverridesInterfaceRaw(objectRaw: CPointer<Unit>): CPointer<Unit> {
    if (objectRaw.isNull()) {
        return CPointer<Unit>()
    }
    let objectFields = CPointer<CPointer<Unit>>(objectRaw)
    CPointer<Unit>(unsafe { objectFields + 1 })
}

func applicationOverridesBaseSlot(interfaceRaw: CPointer<Unit>): CPointer<CPointer<Unit>> {
    if (interfaceRaw.isNull()) {
        return CPointer<CPointer<Unit>>()
    }
    CPointer<CPointer<Unit>>(applicationOverridesObjectRaw(interfaceRaw))
}

func applicationOverridesBaseRaw(interfaceRaw: CPointer<Unit>): CPointer<Unit> {
    let objectRaw = applicationOverridesObjectRaw(interfaceRaw)
    if (objectRaw.isNull()) {
        return CPointer<Unit>()
    }
    unsafe { objectRaw.read().baseRaw }
}

func applicationCompositionStateFromOverrides(raw: CPointer<Unit>): Option<ApplicationCompositionState> {
    if (raw.isNull()) {
        return None
    }
    let object = unsafe { applicationOverridesObjectRaw(raw).read() }
    applicationCompositionState(object.slot)
}

func applicationCompositionStateFromMetadata(raw: CPointer<Unit>): Option<ApplicationCompositionState> {
    if (raw.isNull()) {
        return None
    }
    let object = unsafe { CPointer<XamlMetadataProviderObject>(raw).read() }
    applicationCompositionState(object.slot)
}

func controlsMetadataProviderRaw(state: ApplicationCompositionState): CPointer<Unit> {
    if (state.controlsProviderRaw.isNotNull()) {
        return state.controlsProviderRaw
    }
    let raw = createXamlControlsMetadataProviderRaw()
    state.controlsProviderRaw = raw
    return raw
}

func createXamlControlsMetadataProviderRaw(): CPointer<Unit> {
    let factory = expectFactory(
        loadFactoryByName(
            "Microsoft.UI.Xaml.XamlTypeInfo.XamlControlsXamlMetaDataProvider",
            IGenericFactory.descriptor()
        ),
        "XamlControlsXamlMetaDataProvider activation"
    )
    try {
        match (unsafe { factory.ActivateInstance<IInspectable>(IInspectable.descriptor()) }) {
            case Result<IInspectable>.Ok(inspectable) =>
                try {
                    return queryRequired(
                        inspectable.asRaw(),
                        IID_XAML_METADATA_PROVIDER,
                        "Microsoft.UI.Xaml.Markup.IXamlMetadataProvider"
                    )
                } finally {
                    inspectable.close()
                }
            case Result<IInspectable>.Err(error) =>
                throw Exception("XamlControlsXamlMetaDataProvider.ActivateInstance failed: ${error}")
        }
    } finally {
        factory.close()
    }
}

func registerApplicationResourceManagerRequested(app: Application, slot: Int64): Unit {
    match (applicationCompositionState(slot)) {
        case Some(state) =>
            match (state.resourceManagerRequestedHandler) {
                case Some(_) => return
                case None => ()
            }
            let handler = TypedEventHandler<IInspectable, ResourceManagerRequestedEventArgs>.new({ _, argsRaw =>
                handleResourceManagerRequested(state, argsRaw)
            })
            var token = 0i64
            try (app2 = app.asIApplication2()) {
                checkHRESULT(
                    unsafe {
                        app2.ResourceManagerRequested(handler.asRaw(), CPointer<Int64>(inout token))
                    },
                    "Application.ResourceManagerRequested"
                )
            }
            state.resourceManagerRequestedHandler = Some(handler)
            state.resourceManagerRequestedToken = token
        case None => throw WindowsException(E_POINTER)
    }
}

func handleResourceManagerRequested(state: ApplicationCompositionState, argsRaw: CPointer<Unit>): Unit {
    if (argsRaw.isNull()) {
        throw WindowsException(E_POINTER)
    }
    let args = ResourceManagerRequestedEventArgs.viewOf(argsRaw)
    let manager = xamlResourceManager(state)
    try (resourceManager = manager.asIResourceManager()) {
        args.CustomResourceManager = resourceManager
    }
}

func xamlResourceManager(state: ApplicationCompositionState): ResourceManager {
    match (state.xamlResourceManager) {
        case Some(manager) => return manager
        case None =>
            let manager = ResourceManager.CreateInstance(HString("resources.pri"))
            state.xamlResourceManager = Some(manager)
            return manager
    }
}

func writeApplicationCompositionIids(count: CPointer<UInt32>, iids: CPointer<CPointer<GUID>>): Int32 {
    if (count.isNull() || iids.isNull()) {
        if (count.isNotNull()) {
            unsafe { count.write(0u32) }
        }
        if (iids.isNotNull()) {
            unsafe { iids.write(CPointer<GUID>()) }
        }
        return E_POINTER.value
    }
    let raw = coTaskMemAlloc(sizeOf<GUID>() * 2)
    if (raw.isNull()) {
        unsafe {
            count.write(0u32)
            iids.write(CPointer<GUID>())
        }
        return E_FAIL.value
    }
    let values = CPointer<GUID>(raw)
    unsafe {
        values.write(IApplicationOverrides.iid())
        (values + 1).write(IID_XAML_METADATA_PROVIDER)
        count.write(2u32)
        iids.write(values)
    }
    S_OK.value
}

func writeApplicationRuntimeClassName(result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    let name = HString("windows_reactor.winui.ApplicationHost")
    try {
        unsafe { result.write(name.toSystemHandleCopy()) }
        S_OK.value
    } finally {
        name.close()
    }
}

func queryApplicationInner(
    innerRaw: CPointer<Unit>,
    iid: GUID,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    if (innerRaw.isNull()) {
        unsafe { result.write(CPointer<Unit>()) }
        return E_NOINTERFACE.value
    }

    var requested = iid
    let vtblPtr = unsafe { CPointer<CPointer<IUnknownVtbl>>(innerRaw).read() }
    if (vtblPtr.isNull()) {
        unsafe { result.write(CPointer<Unit>()) }
        return E_NOINTERFACE.value
    }

    unsafe { result.write(CPointer<Unit>()) }
    let hr = unsafe { vtblPtr.read().QueryInterface(innerRaw, CPointer<GUID>(inout requested), result) }
    if (hr != S_OK.value) {
        releaseFailedWinuiOutSlot(result)
    }
    return hr
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
func applicationOverridesQueryInterface(thisPtr: CPointer<Unit>, iidPtr: CPointer<GUID>, result: CPointer<CPointer<Unit>>): Int32 {
    if (thisPtr.isNull() || iidPtr.isNull() || result.isNull()) {
        if (result.isNotNull()) {
            unsafe { result.write(CPointer<Unit>()) }
        }
        return E_POINTER.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    let iid = unsafe { iidPtr.read() }
    if (iid == IID_IUNKNOWN || iid == IID_IINSPECTABLE || iid == IApplicationOverrides.iid()) {
        unsafe { result.write(thisPtr) }
        let _ = unsafe { applicationOverridesAddRef(thisPtr) }
        return S_OK.value
    }
    if (iid == IID_XAML_METADATA_PROVIDER) {
        match (applicationCompositionStateFromOverrides(thisPtr)) {
            case Some(state) =>
                if (state.metadataRaw.isNotNull()) {
                    unsafe { result.write(state.metadataRaw) }
                    let _ = unsafe { xamlMetadataProviderAddRef(state.metadataRaw) }
                    return S_OK.value
                }
            case None => ()
        }
    }
    match (applicationCompositionStateFromOverrides(thisPtr)) {
        case Some(state) =>
            if (state.innerRaw.isNotNull()) {
                let innerHr = queryApplicationInner(state.innerRaw, iid, result)
                return innerHr
            }
        case None => ()
    }
    E_NOINTERFACE.value
}

@C
func applicationOverridesAddRef(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = applicationOverridesObjectRaw(thisPtr)
    var value = unsafe { obj.read() }
    value.refCount += 1u32
    unsafe { obj.write(value) }
    return value.refCount
}

@C
func applicationOverridesRelease(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = applicationOverridesObjectRaw(thisPtr)
    var value = unsafe { obj.read() }
    if (value.refCount == 0u32) {
        return 0u32
    }
    value.refCount -= 1u32
    let refCount = value.refCount
    if (refCount == 0u32) {
        if (value.slot >= 0) {
            clearApplicationCompositionSlot(value.slot)
            value.slot = -1
        }
        if (value.baseRaw.isNotNull()) {
            releaseRaw(value.baseRaw)
            value.baseRaw = CPointer<Unit>()
        }
        value.slot = -1
        unsafe { obj.write(value) }
        coTaskMemFree(CPointer<Unit>(obj))
        return 0u32
    }
    unsafe { obj.write(value) }
    return refCount
}

@C
func applicationOverridesGetIids(_: CPointer<Unit>, count: CPointer<UInt32>, iids: CPointer<CPointer<GUID>>): Int32 {
    writeApplicationCompositionIids(count, iids)
}

@C
func applicationOverridesGetRuntimeClassName(_: CPointer<Unit>, result: CPointer<CPointer<Unit>>): Int32 {
    writeApplicationRuntimeClassName(result)
}

@C
func applicationOverridesGetTrustLevel(_: CPointer<Unit>, result: CPointer<Int32>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(0i32) }
    S_OK.value
}

@C
func applicationOverridesOnLaunched(thisPtr: CPointer<Unit>, _: CPointer<Unit>): Int32 {
    match (applicationCompositionStateFromOverrides(thisPtr)) {
        case Some(state) =>
            match (state.onLaunched) {
                case Some(handler) =>
                    state.onLaunched = None
                    try {
                        installXamlControlsResources()
                        handler()
                        return S_OK.value
                    } catch (error: WindowsException) {
                        return error.code().value
                    } catch (err: Exception) {
                        return E_FAIL.value
                    }
                case None => return S_OK.value
            }
        case None => return E_POINTER.value
    }
}

func applicationOverridesVtbl(): CPointer<ApplicationOverridesVtbl> {
    if (applicationOverridesVtblStorage.isNotNull()) {
        return applicationOverridesVtblStorage
    }
    let raw = coTaskMemAlloc(sizeOf<ApplicationOverridesVtbl>())
    if (raw.isNull()) {
        throw Exception("failed to allocate ApplicationOverrides vtable")
    }
    var table = ApplicationOverridesVtbl()
    table.base_.base_.QueryInterface = applicationOverridesQueryInterface
    table.base_.base_.AddRef = applicationOverridesAddRef
    table.base_.base_.Release = applicationOverridesRelease
    table.base_.GetIids = applicationOverridesGetIids
    table.base_.GetRuntimeClassName = applicationOverridesGetRuntimeClassName
    table.base_.GetTrustLevel = applicationOverridesGetTrustLevel
    table.OnLaunched = applicationOverridesOnLaunched
    let typed = CPointer<ApplicationOverridesVtbl>(raw)
    unsafe { typed.write(table) }
    applicationOverridesVtblStorage = typed
    return typed
}

@C
func xamlMetadataProviderQueryInterface(thisPtr: CPointer<Unit>, iidPtr: CPointer<GUID>, result: CPointer<CPointer<Unit>>): Int32 {
    if (thisPtr.isNull() || iidPtr.isNull() || result.isNull()) {
        if (result.isNotNull()) {
            unsafe { result.write(CPointer<Unit>()) }
        }
        return E_POINTER.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    let iid = unsafe { iidPtr.read() }
    if (iid == IID_IUNKNOWN || iid == IID_IINSPECTABLE) {
        match (applicationCompositionStateFromMetadata(thisPtr)) {
            case Some(state) =>
                if (state.overridesRaw.isNotNull()) {
                    unsafe { result.write(state.overridesRaw) }
                    let _ = unsafe { applicationOverridesAddRef(state.overridesRaw) }
                    return S_OK.value
                }
            case None => ()
        }
    }
    if (iid == IID_XAML_METADATA_PROVIDER) {
        unsafe { result.write(thisPtr) }
        let _ = unsafe { xamlMetadataProviderAddRef(thisPtr) }
        return S_OK.value
    }
    if (iid == IApplicationOverrides.iid()) {
        match (applicationCompositionStateFromMetadata(thisPtr)) {
            case Some(state) =>
                if (state.overridesRaw.isNotNull()) {
                    unsafe { result.write(state.overridesRaw) }
                    let _ = unsafe { applicationOverridesAddRef(state.overridesRaw) }
                    return S_OK.value
                }
            case None => ()
        }
    }
    E_NOINTERFACE.value
}

@C
func xamlMetadataProviderAddRef(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = CPointer<XamlMetadataProviderObject>(thisPtr)
    var value = unsafe { obj.read() }
    value.refCount += 1u32
    unsafe { obj.write(value) }
    return value.refCount
}

@C
func xamlMetadataProviderRelease(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    let obj = CPointer<XamlMetadataProviderObject>(thisPtr)
    var value = unsafe { obj.read() }
    if (value.refCount == 0u32) {
        return 0u32
    }
    value.refCount -= 1u32
    let refCount = value.refCount
    if (refCount == 0u32) {
        value.slot = -1
        unsafe { obj.write(value) }
        coTaskMemFree(thisPtr)
        return 0u32
    }
    unsafe { obj.write(value) }
    return refCount
}

@C
func xamlMetadataProviderGetIids(_: CPointer<Unit>, count: CPointer<UInt32>, iids: CPointer<CPointer<GUID>>): Int32 {
    writeApplicationCompositionIids(count, iids)
}

@C
func xamlMetadataProviderGetRuntimeClassName(_: CPointer<Unit>, result: CPointer<CPointer<Unit>>): Int32 {
    writeApplicationRuntimeClassName(result)
}

@C
func xamlMetadataProviderGetTrustLevel(_: CPointer<Unit>, result: CPointer<Int32>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(0i32) }
    S_OK.value
}

@C
func xamlMetadataProviderGetXamlType(thisPtr: CPointer<Unit>, typeName: Windows_UI_Xaml_Interop_TypeName, result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNotNull()) {
        unsafe { result.write(CPointer<Unit>()) }
    }
    match (applicationCompositionStateFromMetadata(thisPtr)) {
        case Some(state) =>
            try {
                let providerRaw = controlsMetadataProviderRaw(state)
                let table = readWinuiVtbl<XamlMetadataProviderVtbl>(providerRaw)
                let hr = unsafe { table.GetXamlType(providerRaw, typeName, result) }
                return hr
            } catch (error: WindowsException) {
                if (result.isNotNull()) {
                    releaseFailedWinuiOutSlot(result)
                }
                return error.code().value
            } catch (_: Exception) {
                if (result.isNotNull()) {
                    releaseFailedWinuiOutSlot(result)
                }
                return E_FAIL.value
            }
        case None => return E_POINTER.value
    }
}

@C
func xamlMetadataProviderGetXamlTypeByFullName(thisPtr: CPointer<Unit>, fullName: CPointer<Unit>, result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNotNull()) {
        unsafe { result.write(CPointer<Unit>()) }
    }
    match (applicationCompositionStateFromMetadata(thisPtr)) {
        case Some(state) =>
            try {
                let providerRaw = controlsMetadataProviderRaw(state)
                let table = readWinuiVtbl<XamlMetadataProviderVtbl>(providerRaw)
                let hr = unsafe { table.GetXamlTypeByFullName(providerRaw, fullName, result) }
                return hr
            } catch (error: WindowsException) {
                if (result.isNotNull()) {
                    releaseFailedWinuiOutSlot(result)
                }
                return error.code().value
            } catch (_: Exception) {
                if (result.isNotNull()) {
                    releaseFailedWinuiOutSlot(result)
                }
                return E_FAIL.value
            }
        case None => return E_POINTER.value
    }
}

@C
func xamlMetadataProviderGetXmlnsDefinitions(thisPtr: CPointer<Unit>, size: CPointer<UInt32>, values: CPointer<CPointer<Unit>>): Int32 {
    if (size.isNotNull()) {
        unsafe { size.write(0u32) }
    }
    if (values.isNotNull()) {
        unsafe { values.write(CPointer<Unit>()) }
    }
    match (applicationCompositionStateFromMetadata(thisPtr)) {
        case Some(state) =>
            try {
                let providerRaw = controlsMetadataProviderRaw(state)
                let table = readWinuiVtbl<XamlMetadataProviderVtbl>(providerRaw)
                return unsafe { table.GetXmlnsDefinitions(providerRaw, size, values) }
            } catch (error: WindowsException) {
                return error.code().value
            } catch (_: Exception) {
                return E_FAIL.value
            }
        case None => return E_POINTER.value
    }
}

func xamlMetadataProviderVtbl(): CPointer<XamlMetadataProviderVtbl> {
    if (xamlMetadataProviderVtblStorage.isNotNull()) {
        return xamlMetadataProviderVtblStorage
    }
    let raw = coTaskMemAlloc(sizeOf<XamlMetadataProviderVtbl>())
    if (raw.isNull()) {
        throw Exception("failed to allocate IXamlMetadataProvider vtable")
    }
    var table = XamlMetadataProviderVtbl()
    table.base_.base_.QueryInterface = xamlMetadataProviderQueryInterface
    table.base_.base_.AddRef = xamlMetadataProviderAddRef
    table.base_.base_.Release = xamlMetadataProviderRelease
    table.base_.GetIids = xamlMetadataProviderGetIids
    table.base_.GetRuntimeClassName = xamlMetadataProviderGetRuntimeClassName
    table.base_.GetTrustLevel = xamlMetadataProviderGetTrustLevel
    table.GetXamlType = xamlMetadataProviderGetXamlType
    table.GetXamlTypeByFullName = xamlMetadataProviderGetXamlTypeByFullName
    table.GetXmlnsDefinitions = xamlMetadataProviderGetXmlnsDefinitions
    let typed = CPointer<XamlMetadataProviderVtbl>(raw)
    unsafe { typed.write(table) }
    xamlMetadataProviderVtblStorage = typed
    return typed
}
