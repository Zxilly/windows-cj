package windows_sample_xaml_app

import std.collection.ArrayList
import windows_sample_xaml_app_bindings.UI.Xaml.{Application, Window}
import windows_sample_xaml_app_bindings.UI.Xaml.{UIElement}
import windows_sample_xaml_app_bindings.UI.Xaml.Controls.{TextBox}
import windows_sample_xaml_app_bindings.ApplicationModel.Package
import windows_sample_xaml_app_bindings.Win32.System.Com.Apis as ComApis
import windows_sample_xaml_app_bindings.Win32.UI.WindowsAndMessaging.Apis as WamApis
import windows_sample_xaml_app_bindings.Win32.Foundation.HWND
import windows_sample_xaml_app_bindings.impl.{
    Windows_UI_Xaml_IApplicationFactory,
    Windows_UI_Xaml_IApplicationOverrides,
    Windows_UI_Xaml_ApplicationInitializationCallback,
    Windows_Win32_System_Com_COINIT_COINIT_MULTITHREADED,
    Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_OK,
    Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_ICONSTOP
}
import windows_core.{
    E_FAIL,
    E_NOINTERFACE,
    E_NOTIMPL,
    E_POINTER,
    GUID,
    HString,
    HRESULT,
    IGenericFactory,
    Result,
    S_OK,
    WindowsException,
    coTaskMemAlloc,
    coTaskMemFree,
    loadFactoryByName,
    winrtBorrowGenericIn
}
import windows_interface.{
    IInspectable,
    IInspectableVtbl,
    IUnknownVtbl,
    IID_IUNKNOWN,
    IID_IINSPECTABLE,
    queryInterfaceRaw
}
import windows_strings.encodeUtf16WithNull

// ============================================================================
// xaml_app — behaviour-equivalent port of the reference sample.
//
// Hosts a Windows.UI.Xaml Application by AGGREGATING it. Windows.UI.Xaml's
// Application is a COMPOSABLE WinRT runtime class: to derive from it you build a
// COM-callable wrapper (CCW) for IApplicationOverrides — the "outer" /
// controlling identity — and hand it to the Application activation factory's
// CreateInstance(outer, &inner, &result). The factory returns the derived
// Application plus a non-delegating "inner" IInspectable (the base XAML
// Application). The outer CCW's QueryInterface answers IApplicationOverrides
// itself and forwards every other interface to the inner — the standard WinRT
// aggregation pattern. The runtime then calls our IApplicationOverrides.OnLaunched
// on the UI thread, where we set a TextBox as the Window content and Activate().
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference uses an #[implement(IApplicationOverrides)] attribute macro
//     plus a built-in Application::compose() helper. Cangjie's generated bindings
//     expose the consumer projection (Application.Start / the raw
//     IApplicationFactory.CreateInstance ABI) but no turnkey "compose a base
//     runtime class" helper, because aggregation needs a custom QueryInterface
//     that routes unknown IIDs to the inner identity. We therefore hand-roll the
//     overrides CCW and the aggregation exactly as the WinRT ABI requires — the
//     same machinery the reference's macro generates, written out explicitly.
//     This is a language-paradigm difference (no compile-time #[implement]
//     macro for composable classes), not a behavioural one: the produced
//     Win32/WinRT ABI is identical.
//   • The overrides object is a @C struct laid out as a classic COM object: the
//     COM interface pointer points at the `vtbl` field, so the runtime reaches
//     the object by subtracting one pointer from the interface pointer. The vtbl
//     is an IInspectable base (QueryInterface/AddRef/Release + GetIids/
//     GetRuntimeClassName/GetTrustLevel) followed by the nine IApplicationOverrides
//     slots. Refcounting is manual (UInt32 in the struct); a managed object
//     cannot live inside a @C struct, so the per-instance closure state lives in a
//     side registry keyed by an Int64 slot stored in the struct.
//   • Application.Start takes an ApplicationInitializationCallback delegate; the
//     generated binding builds one from a Cangjie closure via .new(closure)
//     (a CCW with an Invoke thunk — the same shape as a TypedEventHandler). The
//     XAML runtime establishes its dispatcher/UI thread and calls this callback
//     ON it; the Application composition MUST be created inside the callback, on
//     that thread.
//   • The reference's high-level calls (Window::Current, TextBox::new,
//     SetText/SetContent/Activate) return Result and use `?`; the Cangjie
//     projections .check() the HRESULT internally and throw a WindowsException —
//     the analogue of `?`. OnLaunched catches the throw and returns the failing
//     HRESULT through the vtbl thunk, matching the reference's `-> Result<()>`.
//   • COINIT_MULTITHREADED and the MB_* styles are plain metadata constants; the
//     generated value-level lets carry the same numeric ABI values.
// ============================================================================

// The two messages the reference puts in the TextBox.
let TEXT_BOX_TEXT = "Hello world"
let TEXT_BOX_PLACEHOLDER = "What are you going to build today?"

// IApplicationOverrides IID (used by the outer CCW's QueryInterface).
let IID_APPLICATION_OVERRIDES = Windows_UI_Xaml_IApplicationOverrides.iid()

// ── overrides CCW: @C ABI surface ───────────────────────────────────────────

// IApplicationOverrides raw vtable: IInspectable base + the nine override slots.
// Each slot takes (this, argsAbi) and returns an HRESULT. OnLaunched does the
// work; the other eight return S_OK (mirroring the reference, which returns
// Ok(()) from all but OnLaunched).
@C
struct ApplicationOverridesVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var OnActivated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnLaunched: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnFileActivated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnSearchActivated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnShareTargetActivated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnFileOpenPickerActivated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnFileSavePickerActivated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnCachedFileUpdaterActivated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var OnWindowCreated: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

// The overrides object. Classic COM layout: the COM interface pointer the
// runtime sees points at the `vtbl` field, so given an interface pointer the
// object start is `interfacePtr - 1 pointer`. `innerRaw` is the base XAML
// Application's non-delegating IInspectable, populated after CreateInstance;
// QueryInterface forwards unknown IIDs to it. `slot` indexes the side registry
// holding the managed launch closure.
@C
struct ApplicationOverridesObject {
    public var vtbl: CPointer<ApplicationOverridesVtbl> = CPointer<ApplicationOverridesVtbl>()
    public var innerRaw: CPointer<Unit> = CPointer<Unit>()
    public var refCount: UInt32 = 1u32
    public var slot: Int64 = -1
    public init() {}
}

// Per-composition managed state (cannot live inside the @C struct). The launch
// closure builds the Window + TextBox; it is consumed on the first OnLaunched.
class ApplicationCompositionState {
    public var onLaunched: Option<() -> Unit>
    public init(onLaunched: () -> Unit) {
        this.onLaunched = Some(onLaunched)
    }
}

// ── module-level singletons ─────────────────────────────────────────────────
var applicationOverridesVtblStorage: CPointer<ApplicationOverridesVtbl> = CPointer<ApplicationOverridesVtbl>()
var applicationCompositionSlots: ArrayList<Option<ApplicationCompositionState>> = ArrayList<Option<ApplicationCompositionState>>()

func addApplicationCompositionSlot(handler: () -> Unit): Int64 {
    let index = applicationCompositionSlots.size
    applicationCompositionSlots.add(Some(ApplicationCompositionState(handler)))
    return index
}

func clearApplicationCompositionSlot(slot: Int64): Unit {
    if (slot >= 0 && slot < applicationCompositionSlots.size) {
        applicationCompositionSlots[slot] = None
    }
}

func applicationCompositionState(slot: Int64): Option<ApplicationCompositionState> {
    if (slot >= 0 && slot < applicationCompositionSlots.size) {
        return applicationCompositionSlots[slot]
    }
    None
}

// ── object <-> interface pointer arithmetic ─────────────────────────────────

// The interface pointer points at the object's `vtbl` field (offset 0 of the
// @C struct), so here the interface pointer IS the object start.
func applicationOverridesObjectRaw(interfaceRaw: CPointer<Unit>): CPointer<ApplicationOverridesObject> {
    CPointer<ApplicationOverridesObject>(interfaceRaw)
}

func applicationCompositionStateFromOverrides(raw: CPointer<Unit>): Option<ApplicationCompositionState> {
    if (raw.isNull()) {
        return None
    }
    let object = unsafe { applicationOverridesObjectRaw(raw).read() }
    applicationCompositionState(object.slot)
}

// Forward a QueryInterface to the inner (base XAML Application) identity.
func queryApplicationInner(innerRaw: CPointer<Unit>, iid: GUID, result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    if (innerRaw.isNull()) {
        unsafe { result.write(CPointer<Unit>()) }
        return E_NOINTERFACE.value
    }
    match (unsafe { queryInterfaceRaw(innerRaw, iid) }) {
        case Some(iface) =>
            unsafe { result.write(iface) }
            return S_OK.value
        case None =>
            unsafe { result.write(CPointer<Unit>()) }
            return E_NOINTERFACE.value
    }
}

// ── IInspectable + IApplicationOverrides vtbl thunks ────────────────────────

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
    // The outer/controlling identity answers IUnknown, IInspectable and the
    // overridden interface itself; everything else delegates to the inner.
    if (iid == IID_IUNKNOWN || iid == IID_IINSPECTABLE || iid == IID_APPLICATION_OVERRIDES) {
        unsafe { result.write(thisPtr) }
        let _ = unsafe { applicationOverridesAddRef(thisPtr) }
        return S_OK.value
    }
    let innerRaw = unsafe { applicationOverridesObjectRaw(thisPtr).read().innerRaw }
    if (innerRaw.isNotNull()) {
        return queryApplicationInner(innerRaw, iid, result)
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
        if (value.innerRaw.isNotNull()) {
            // Release the single reference we hold on the base (inner) XAML
            // Application identity that CreateInstance handed back.
            releaseRaw(value.innerRaw)
            value.innerRaw = CPointer<Unit>()
        }
        unsafe { obj.write(value) }
        coTaskMemFree(thisPtr)
        return 0u32
    }
    unsafe { obj.write(value) }
    return refCount
}

@C
func applicationOverridesGetIids(_: CPointer<Unit>, count: CPointer<UInt32>, iids: CPointer<CPointer<GUID>>): Int32 {
    if (count.isNotNull()) {
        unsafe { count.write(0u32) }
    }
    if (iids.isNotNull()) {
        unsafe { iids.write(CPointer<GUID>()) }
    }
    S_OK.value
}

@C
func applicationOverridesGetRuntimeClassName(_: CPointer<Unit>, result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    let name = HString("windows_sample_xaml_app.App")
    try {
        unsafe { result.write(name.toSystemHandleCopy()) }
        S_OK.value
    } finally {
        name.close()
    }
}

@C
func applicationOverridesGetTrustLevel(_: CPointer<Unit>, result: CPointer<Int32>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(0i32) }
    S_OK.value
}

// The eight no-op override slots: return S_OK, matching the reference, which
// returns Ok(()) from every override except OnLaunched.
@C
func applicationOverridesNoop(_: CPointer<Unit>, _: CPointer<Unit>): Int32 {
    S_OK.value
}

// OnLaunched: the one override that does work. Run the registered launch
// closure (which creates the Window + TextBox and activates), then drop it so a
// second activation is a no-op. Translate a WindowsException into its HRESULT
// for the vtbl thunk, exactly like the reference's `-> Result<()>`.
@C
func applicationOverridesOnLaunched(thisPtr: CPointer<Unit>, _: CPointer<Unit>): Int32 {
    match (applicationCompositionStateFromOverrides(thisPtr)) {
        case Some(state) =>
            match (state.onLaunched) {
                case Some(handler) =>
                    state.onLaunched = None
                    try {
                        handler()
                        return S_OK.value
                    } catch (error: WindowsException) {
                        return error.code().value
                    } catch (_: Exception) {
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
    table.OnActivated = applicationOverridesNoop
    table.OnLaunched = applicationOverridesOnLaunched
    table.OnFileActivated = applicationOverridesNoop
    table.OnSearchActivated = applicationOverridesNoop
    table.OnShareTargetActivated = applicationOverridesNoop
    table.OnFileOpenPickerActivated = applicationOverridesNoop
    table.OnFileSavePickerActivated = applicationOverridesNoop
    table.OnCachedFileUpdaterActivated = applicationOverridesNoop
    table.OnWindowCreated = applicationOverridesNoop
    let typed = CPointer<ApplicationOverridesVtbl>(raw)
    unsafe { typed.write(table) }
    applicationOverridesVtblStorage = typed
    return typed
}

// ── helpers ─────────────────────────────────────────────────────────────────

// Release a raw COM pointer once (wrap-and-drop via the inner identity).
func releaseRaw(raw: CPointer<Unit>): Unit {
    if (raw.isNotNull()) {
        IInspectable.fromAbiTake(raw).close()
    }
}

// Allocate the outer overrides CCW, register its launch closure, and return the
// COM interface pointer (which points at the object's vtbl field). Caller owns
// the +1 reference.
func createApplicationOverrides(onLaunched: () -> Unit): CPointer<Unit> {
    let slot = addApplicationCompositionSlot(onLaunched)
    let raw = coTaskMemAlloc(sizeOf<ApplicationOverridesObject>())
    if (raw.isNull()) {
        clearApplicationCompositionSlot(slot)
        throw Exception("failed to allocate Application overrides object")
    }
    var object = ApplicationOverridesObject()
    object.vtbl = applicationOverridesVtbl()
    object.innerRaw = CPointer<Unit>()
    object.refCount = 1u32
    object.slot = slot
    let typed = CPointer<ApplicationOverridesObject>(raw)
    unsafe { typed.write(object) }
    // The interface pointer points at the vtbl field, which is offset 0 here.
    return raw
}

// Compose the derived Application: hand the outer overrides CCW to the
// IApplicationFactory's CreateInstance(outer, &inner, &result). Stores the inner
// (base) IInspectable into the overrides object for QueryInterface delegation
// and returns the derived Application wrapper. Mirrors the reference
// Application::compose(MyApp).
func composeApplication(overridesRaw: CPointer<Unit>): Application {
    if (overridesRaw.isNull()) {
        throw WindowsException(E_POINTER)
    }
    let factory = match (loadFactoryByName<Windows_UI_Xaml_IApplicationFactory>(
        Application.runtimeName(),
        Windows_UI_Xaml_IApplicationFactory.descriptor()
    )) {
        case Result<Windows_UI_Xaml_IApplicationFactory>.Ok(value) => value
        case Result<Windows_UI_Xaml_IApplicationFactory>.Err(error) =>
            throw Exception("IApplicationFactory activation failed: ${error}")
    }
    try {
        var inner = CPointer<Unit>()
        var result = CPointer<Unit>()
        // The @Interface projection renders CreateInstance as returning HRESULT
        // (the raw Int32 ABI is wrapped by the macro), so do not re-wrap.
        let hr = unsafe {
            factory.CreateInstance(
                overridesRaw,
                CPointer<CPointer<Unit>>(inout inner),
                CPointer<CPointer<Unit>>(inout result)
            )
        }
        if (hr.failed()) {
            if (inner.isNotNull()) {
                releaseRaw(inner)
                inner = CPointer<Unit>()
            }
            if (result.isNotNull()) {
                releaseRaw(result)
                result = CPointer<Unit>()
            }
        }
        hr.check()
        if (result.isNull()) {
            throw Exception("IApplicationFactory.CreateInstance returned null")
        }
        // Publish the inner identity into the overrides object so its
        // QueryInterface can delegate unknown IIDs to the base XAML Application.
        let obj = CPointer<ApplicationOverridesObject>(overridesRaw)
        var value = unsafe { obj.read() }
        value.innerRaw = inner
        unsafe { obj.write(value) }
        return Application.fromAbiTake(result)
    } finally {
        factory.close()
    }
}

// Activate a default-activatable WinRT runtime class by name and wrap the new
// instance as a TextBox (mirrors the reference TextBox::new()). The TextBox
// projection has no parameterless constructor of its own, so we go through the
// class's activation factory's ActivateInstance — the canonical path for an
// [Activatable] XAML control.
func newTextBox(): TextBox {
    let factory = match (loadFactoryByName<IGenericFactory>(
        TextBox.runtimeName(),
        IGenericFactory.descriptor()
    )) {
        case Result<IGenericFactory>.Ok(value) => value
        case Result<IGenericFactory>.Err(error) =>
            throw Exception("TextBox activation failed: ${error}")
    }
    try {
        match (unsafe { factory.ActivateInstance<TextBox>(TextBox.descriptor()) }) {
            case Result<TextBox>.Ok(textBox) => return textBox
            case Result<TextBox>.Err(error) =>
                throw Exception("TextBox.ActivateInstance failed: ${error}")
        }
    } finally {
        factory.close()
    }
}

// The launch body the runtime drives on the UI thread (the reference
// MyApp::OnLaunched): build the window + textbox, set content, activate.
func launch(): Unit {
    let window = Window.Current()
    let textBox = newTextBox()
    textBox.Text = HString(TEXT_BOX_TEXT)
    // PlaceholderText lives on the ITextBox2 facet, which the generated TextBox
    // class does not promote to a high-level prop. Call the raw setter through
    // ITextBox2, borrowing the HSTRING for the duration of the call (the borrow
    // mirrors the reference text_box.SetPlaceholderText(&self.placeholder)).
    let placeholder = HString(TEXT_BOX_PLACEHOLDER)
    try {
        try (textBox2 = textBox.asITextBox2()) {
            try (borrow = winrtBorrowGenericIn<HString>(placeholder)) {
                unsafe { textBox2.SetPlaceholderText(borrow.asRaw()) }.check()
            }
        }
    } finally {
        placeholder.close()
    }
    // Window.Content takes a UIElement. QI the TextBox to its IUIElement facet
    // (the put_Content slot's exact ABI type) and view that identity as a
    // UIElement (non-owning) for the put_Content AddRef. The IUIElement handle is
    // held alive across the assignment by the local binding.
    let uiElement = textBox.asIUIElement()
    try {
        window.Content = UIElement.viewOf(uiElement.asRaw())
    } finally {
        uiElement.close()
    }
    window.Activate()
}

main(): Int64 {
    // Initialise COM for this thread (multithreaded apartment), mirroring the
    // reference's CoInitializeEx(None, COINIT_MULTITHREADED).
    unsafe {
        ComApis.CoInitializeExChecked(
            CPointer<Unit>(),
            UInt32(Windows_Win32_System_Com_COINIT_COINIT_MULTITHREADED)
        )
    }

    // Registration gate: a XAML application must run from an installed app
    // package. Package.Current() throws when there is no package identity (e.g.
    // a plain console launch). The reference shows a blocking MessageBox and
    // returns the error; we do the same, then exit non-zero.
    try {
        Package.Current()
    } catch (error: WindowsException) {
        let text = encodeUtf16WithNull(
            "This sample must be registered (via register.cmd) and launched from Start."
        )
        let caption = encodeUtf16WithNull("Error")
        unsafe {
            let textHandle = acquireArrayRawData(text)
            let captionHandle = acquireArrayRawData(caption)
            try {
                let style = Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_ICONSTOP |
                    Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_OK
                WamApis.MessageBoxW(HWND(), textHandle.pointer, captionHandle.pointer, style.value)
            } finally {
                releaseArrayRawData(textHandle)
                releaseArrayRawData(captionHandle)
            }
        }
        return Int64(error.code().value)
    }

    // Application.Start drives the XAML application: it establishes the UI
    // thread/dispatcher and invokes our initialization callback ON it. Inside
    // the callback we compose the derived Application (the reference's
    // Application::compose(MyApp { ... })). The composed Application's lifetime is
    // owned by the XAML runtime for the duration of Start, which blocks running
    // the message loop until the app exits.
    let callback = Windows_UI_Xaml_ApplicationInitializationCallback.new({ _ =>
        let overridesRaw = createApplicationOverrides({ => launch() })
        try {
            let app = composeApplication(overridesRaw)
            // The composed Application is now owned by the running XAML runtime;
            // drop our wrapper handle (the runtime holds its own references via
            // the aggregation). Keeping the inner alive is handled by the
            // overrides object.
            app.close()
        } finally {
            // Release our caller +1 on the outer overrides CCW; the runtime
            // retains the references it needs through aggregation.
            let _ = unsafe { applicationOverridesRelease(overridesRaw) }
        }
    })
    Application.Start(callback)
    return 0
}
