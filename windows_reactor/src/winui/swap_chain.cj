package windows_reactor.winui

import windows_reactor.core.{NativeElement, Callback}
import windows_core.{
    GUID,
    HRESULT,
    E_NOINTERFACE,
    E_NOTIMPL,
    E_POINTER,
    IInspectableVtbl,
    IUnknownVtbl,
    IGenericFactory,
    Result,
    WindowsException,
    loadFactoryByName,
    queryInterfaceRaw
}
import windows_interface.{IInspectable}
import windows_common.Microsoft.UI.Xaml.{IUIElement, IFrameworkElement, FrameworkElement, SizeChangedEventHandler}
import windows_common.Foundation.{TypedEventHandler}

// ============================================================================
// SwapChainPanel subsystem (phase B of the canvas port).
//
// Hosts native Direct3D / Direct2D rendering inside the WinUI XAML tree by
// projecting `Microsoft.UI.Xaml.Controls.SwapChainPanel` and its two interop
// interfaces. Mirrors the reference SwapChainPanelWidget + SwapChainPanelHandle
// (core/widgets/swap_chain_panel.rs) and the ISwapChainPanelNative /
// ISwapChainPanel interop bindings.
//
// PROJECTION STRATEGY — LOCAL VTBL FALLBACK (not a windows_common regen):
//   `SwapChainPanel`, `ISwapChainPanelNative`, `ISwapChainPanel` and
//   `Microsoft.UI.Xaml.Media.CompositionTarget` are NOT in the curated
//   windows_common projection (its codegen-manifest.json requested_features do
//   not list them). The intended "correct" path is to add those features and
//   regenerate windows_common with windows_bindgen. That regen was NOT taken
//   here for two reasons:
//     1. windows_common is a very large generated package guarded by a strict
//        byte-for-byte manifest hash gate (scripts/windows_common_manifest.py);
//        regenerating it to add three features rewrites + re-hashes the whole
//        tree and is OOM-prone (must run with cjHeapSize=32GB) and high-risk for
//        an isolated phase-B change.
//     2. The reactor already establishes this exact precedent: the concrete
//        backdrop runtime classes (MicaBackdrop / DesktopAcrylicBackdrop) are
//        likewise "not surfaced by the curated projection" and are driven via
//        hand-described @C vtbls + name-based activation in winui/host.cj.
//   So this file describes the needed vtbls by hand (same shape + IIDs as the
//   reference bindings) and activates SwapChainPanel by runtime-class name.
//   EXPECTED CORRECT IMPLEMENTATION: add the three features to
//   windows_common/codegen-manifest.json requested_features and regen
//   windows_common; then this local vtbl block can be deleted and the handle can
//   QI to generated projection classes. (Same "workaround + expected correct
//   implementation" style as docs/cj-aggregate-return-com-abi-bug.md.)
//
// ABI-BUG NOTE: none of the methods used here return an aggregate by value, so
// the sret/RAX miscompilation in docs/cj-aggregate-return-com-abi-bug.md does
// not apply. SetSwapChain takes a pointer and returns HRESULT;
// get_CompositionScaleX/Y return a scalar f32 out-param; the event add/remove
// methods return HRESULT.
// ============================================================================

// ── IIDs (from the reference interop bindings) ──────────────────────────────
//   ISwapChainPanelNative   = 63aad0b8-7c24-40ff-85a8-640d944cc325
//   ISwapChainPanel         = 08844f85-aa1b-540d-bef2-b2bb7b257f8c
//   ISwapChainPanelFactory  = 38d00b69-5759-5f37-9e1c-3ae0d4288b26
//   ICompositionTargetStatics = 12a4be6f-6db1-5165-b622-d57ab782745b
let IID_ISWAPCHAINPANEL_NATIVE = GUID.from_values(
    0x63aad0b8u32, 0x7c24u16, 0x40ffu16, 0x85u8, 0xa8u8, 0x64u8, 0x0du8, 0x94u8, 0x4cu8, 0xc3u8, 0x25u8)
let IID_ISWAPCHAINPANEL = GUID.from_values(
    0x08844f85u32, 0xaa1bu16, 0x540du16, 0xbeu8, 0xf2u8, 0xb2u8, 0xbbu8, 0x7bu8, 0x25u8, 0x7fu8, 0x8cu8)
let IID_ISWAPCHAINPANEL_FACTORY = GUID.from_values(
    0x38d00b69u32, 0x5759u16, 0x5f37u16, 0x9eu8, 0x1cu8, 0x3au8, 0xe0u8, 0xd4u8, 0x28u8, 0x8bu8, 0x26u8)
let IID_ICOMPOSITIONTARGET_STATICS = GUID.from_values(
    0x12a4be6fu32, 0x6db1u16, 0x5165u16, 0xb6u8, 0x22u8, 0xd5u8, 0x7au8, 0xb7u8, 0x82u8, 0x74u8, 0x5bu8)

let SWAP_CHAIN_PANEL_RUNTIME_NAME = "Microsoft.UI.Xaml.Controls.SwapChainPanel"
let COMPOSITION_TARGET_RUNTIME_NAME = "Microsoft.UI.Xaml.Media.CompositionTarget"

// ── Hand-described vtbls (match the reference interop bindings) ──────────────

// ISwapChainPanelNative : IUnknown { HRESULT SetSwapChain(IDXGISwapChain*); }
@C
struct ISwapChainPanelNativeVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var SetSwapChain: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

// ISwapChainPanel : IInspectable {
//   HRESULT get_CompositionScaleX(float*);
//   HRESULT get_CompositionScaleY(float*);
//   HRESULT add_CompositionScaleChanged(TypedEventHandler*, EventRegistrationToken*);
//   HRESULT remove_CompositionScaleChanged(EventRegistrationToken);
//   ... (CreateCoreIndependentInputSource — unused, omitted via padding) }
@C
struct ISwapChainPanelVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var get_CompositionScaleX: CFunc<(CPointer<Unit>, CPointer<Float32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var get_CompositionScaleY: CFunc<(CPointer<Unit>, CPointer<Float32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var add_CompositionScaleChanged: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Int64>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var remove_CompositionScaleChanged: CFunc<(CPointer<Unit>, Int64) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var CreateCoreIndependentInputSource: CPointer<Unit> = CPointer<Unit>()
    public init() {}
}

// ISwapChainPanelFactory : IInspectable {
//   HRESULT CreateInstance(IInspectable* outer, IInspectable** inner,
//                          ISwapChainPanel** instance); }
@C
struct ISwapChainPanelFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var CreateInstance: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public init() {}
}

// ICompositionTargetStatics : IInspectable {
//   HRESULT add_Rendering(TypedEventHandler*, EventRegistrationToken*);
//   HRESULT remove_Rendering(EventRegistrationToken);
//   ... (Rendered / SurfaceContentsLost / GetCompositorForCurrentThread —
//       unused, omitted via padding) }
@C
struct ICompositionTargetStaticsVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var add_Rendering: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Int64>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var remove_Rendering: CFunc<(CPointer<Unit>, Int64) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

// ============================================================================
// SwapChainPanelControl — the winui Handle's backing object for a created
// SwapChainPanel. Because the control class is not in windows_common, this
// holds the activated outer control as an owned IInspectable plus the QI'd
// IUIElement / IFrameworkElement views the backend needs for parenting /
// layout. GC + close() (with a `closed` guard) manage the COM refs; siblings of
// the other Handle variants (which wrap generated projection classes) behave
// the same way.
// ============================================================================

public class SwapChainPanelControl {
    // The activated outer control as an owned IInspectable. The IUIElement /
    // IFrameworkElement views are QI'd on demand (mirroring the generated
    // projection classes' asIUIElement / asIFrameworkElement, which QI per call
    // and rely on GC to release the produced interface wrapper); the backend uses
    // them transiently (e.g. .asRaw() immediately).
    private let inspectable: IInspectable
    private var closed: Bool = false

    private init(inspectable: IInspectable) {
        this.inspectable = inspectable
    }

    // Activate a fresh SwapChainPanel. SwapChainPanel is a COMPOSABLE XAML class
    // (DependencyObject-derived), so it is activated through its per-class
    // composition factory's CreateInstance(outer=null, &inner, &instance) — the
    // parameterless IActivationFactory.ActivateInstance is rejected by composable
    // classes (same shape as the backdrop activation in host.cj). With a null
    // aggregation base the caller owns the inner non-delegating identity and must
    // release it, keeping only the outer instance — mirroring handle.cj
    // makeComposable for the generated controls.
    public static func create(): SwapChainPanelControl {
        let factory = expectFactory(
            loadFactoryByName(SWAP_CHAIN_PANEL_RUNTIME_NAME, IGenericFactory.descriptor()),
            "ISwapChainPanelFactory activation"
        )
        try {
            let compositionFactory = queryRequired(
                factory.asRaw(), IID_ISWAPCHAINPANEL_FACTORY, "ISwapChainPanelFactory")
            try {
                let table = readWinuiVtbl<ISwapChainPanelFactoryVtbl>(compositionFactory)
                var inner = CPointer<Unit>()
                var instance = CPointer<Unit>()
                let hr = HRESULT(unsafe {
                    table.CreateInstance(
                        compositionFactory,
                        CPointer<Unit>(),
                        CPointer<CPointer<Unit>>(inout inner),
                        CPointer<CPointer<Unit>>(inout instance)
                    )
                })
                if (hr.failed()) {
                    releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout inner))
                    releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout instance))
                }
                checkHRESULT(hr, "ISwapChainPanelFactory.CreateInstance")
                // Release the controlling-inner identity; keep the outer instance.
                if (inner.isNotNull()) {
                    releaseRaw(inner)
                }
                if (instance.isNull()) {
                    throw Exception("ISwapChainPanelFactory.CreateInstance returned null")
                }
                return SwapChainPanelControl(IInspectable.fromAbiTake(instance))
            } finally {
                releaseRaw(compositionFactory)
            }
        } finally {
            factory.close()
        }
    }

    // Default-interface identity pointer (for QI / parenting). Non-owning.
    public func asRaw(): CPointer<Unit> {
        if (closed) { return CPointer<Unit>() }
        inspectable.asRaw()
    }

    // QI to the IUIElement view (the type appended into a Panel's Children and the
    // universal element surface). Mirrors the generated projection classes'
    // asIUIElement: a fresh QI'd interface wrapper each call, released by GC.
    public func asIUIElement(): IUIElement {
        match (unsafe { inspectable.query<IUIElement>(IUIElement.descriptor()) }) {
            case Some(v) => v
            case None => throw WindowsException(E_NOINTERFACE)
        }
    }

    // QI to the IFrameworkElement view (Width / Height / Margin / Alignment).
    public func asIFrameworkElement(): IFrameworkElement {
        match (unsafe { inspectable.query<IFrameworkElement>(IFrameworkElement.descriptor()) }) {
            case Some(v) => v
            case None => throw WindowsException(E_NOINTERFACE)
        }
    }

    public func asIInspectable(): IInspectable { inspectable }

    public func close(): Unit {
        if (!closed) {
            closed = true
            inspectable.close()
        }
    }
}

// ============================================================================
// SwapChainPanelHandle — phase-C interop surface handed to user code through
// the SwapChainPanelWidget on_ready callback. It is constructed from the opaque
// NativeElement token the reconciler delivers (the live control's raw IUIElement
// pointer), and rebuilds the WinRT-typed interop views in this layer (keeping
// core backend-agnostic). Mirrors the reference SwapChainPanelHandle, whose
// methods (set_swap_chain / composition_scale / on_composition_scale_changed)
// operate on the wrapped IInspectable.
//
// LIFETIME: the wrapped raw pointer is NON-OWNING — the live control (kept alive
// by the backend's Handle map for as long as it is mounted) owns the COM ref.
// The handle therefore must only be used while the control is mounted (i.e.
// from within / after on_ready and before the panel is unmounted), exactly like
// the reference handle.
// ============================================================================

public class SwapChainPanelHandle {
    private let raw: CPointer<Unit>

    public init(native: NativeElement) {
        this.raw = pointerFromUIntNative(native.raw)
    }

    // Attach a DXGI swap chain (created with CreateSwapChainForComposition) to
    // the panel. `swapChainRaw` must be a valid IDXGISwapChain / IDXGISwapChain1
    // pointer (non-owning; the SetSwapChain call AddRefs it internally). QIs the
    // panel to ISwapChainPanelNative and calls SetSwapChain. Throws on QI /
    // SetSwapChain failure. Mirrors the reference set_swap_chain.
    public func setSwapChain(swapChainRaw: CPointer<Unit>): Unit {
        if (raw.isNull()) {
            throw Exception("SwapChainPanelHandle.setSwapChain: null panel")
        }
        let nativeRaw = queryRequired(raw, IID_ISWAPCHAINPANEL_NATIVE, "ISwapChainPanelNative")
        try {
            let table = readWinuiVtbl<ISwapChainPanelNativeVtbl>(nativeRaw)
            checkHRESULT(HRESULT(unsafe { table.SetSwapChain(nativeRaw, swapChainRaw) }),
                "ISwapChainPanelNative.SetSwapChain")
        } finally {
            releaseRaw(nativeRaw)
        }
    }

    // Current composition scale (DPI scale factor) as (scaleX, scaleY). Multiply
    // DIP dimensions by these to get the pixel dimensions for the swap chain.
    // Returns (1.0, 1.0) if the panel does not answer ISwapChainPanel (e.g. the
    // scale is not yet known before first layout). Mirrors the reference
    // composition_scale; both getters are scalar out-param calls (no aggregate
    // return — see the ABI-bug note above).
    public func compositionScale(): (Float32, Float32) {
        if (raw.isNull()) { return (1.0, 1.0) }
        match (unsafe { queryInterfaceRaw(raw, IID_ISWAPCHAINPANEL) }) {
            case Some(panelRaw) =>
                try {
                    let table = readWinuiVtbl<ISwapChainPanelVtbl>(panelRaw)
                    var x: Float32 = 1.0
                    var y: Float32 = 1.0
                    let hrx = HRESULT(unsafe { table.get_CompositionScaleX(panelRaw, CPointer<Float32>(inout x)) })
                    let hry = HRESULT(unsafe { table.get_CompositionScaleY(panelRaw, CPointer<Float32>(inout y)) })
                    if (hrx.failed() || hry.failed()) { return (1.0, 1.0) }
                    return (x, y)
                } finally {
                    releaseRaw(panelRaw)
                }
            case None => return (1.0, 1.0)
        }
    }

    // Subscribe to composition-scale changes (e.g. the window moves to a monitor
    // with a different DPI). The callback receives the new (scaleX, scaleY). The
    // returned EventRevoker owns the subscription + the COM delegate (which roots
    // the CCW for the subscription's lifetime, mirroring the EventRevoker pattern
    // in winui/event_*.cj) and unregisters + releases on close(). Mirrors the
    // reference on_composition_scale_changed.
    public func onCompositionScaleChanged(handler: (Float32, Float32) -> Unit): EventRevoker {
        if (raw.isNull()) {
            throw Exception("SwapChainPanelHandle.onCompositionScaleChanged: null panel")
        }
        // Own one ref to ISwapChainPanel for the subscription lifetime so the
        // remove call (in the revoker) is valid.
        let panelRaw = queryRequired(raw, IID_ISWAPCHAINPANEL, "ISwapChainPanel")
        let table = readWinuiVtbl<ISwapChainPanelVtbl>(panelRaw)
        let delegate = TypedEventHandler<IInspectable, IInspectable>.new({ senderRaw, _ =>
            try {
                let (x, y) = readCompositionScale(senderRaw)
                handler(x, y)
            } catch (_: Exception) {
                ()
            }
        })
        var token = 0i64
        let hr = HRESULT(unsafe {
            table.add_CompositionScaleChanged(panelRaw, delegate.asRaw(), CPointer<Int64>(inout token))
        })
        if (hr.failed()) {
            delegate.close()
            releaseRaw(panelRaw)
            throw WindowsException(hr)
        }
        // Freeze the registration token into an immutable copy: a Cangjie lambda
        // that captures a mutable (var) variable may only be called inline, never
        // stored, so the revoker closure must capture a `let`.
        let registeredToken = token
        EventRevoker({ =>
            let removeTable = readWinuiVtbl<ISwapChainPanelVtbl>(panelRaw)
            let _ = unsafe { removeTable.remove_CompositionScaleChanged(panelRaw, registeredToken) }
            delegate.close()
            releaseRaw(panelRaw)
        })
    }

    // Subscribe to the panel's layout-size changes (width, height in DIPs). Use
    // this to resize the swap chain buffers. The returned EventRevoker owns the
    // subscription + delegate. Mirrors the reference on_resize (which adds a
    // SizeChanged handler on the FrameworkElement). Reads the new size from the
    // panel's ActualWidth / ActualHeight (scalar out-param getters; no aggregate
    // return — see the ABI-bug note) so it does not depend on decoding the
    // SizeChangedEventArgs aggregate.
    public func onResize(handler: (Float64, Float64) -> Unit): EventRevoker {
        if (raw.isNull()) {
            throw Exception("SwapChainPanelHandle.onResize: null panel")
        }
        let fe = FrameworkElement.fromAbiTake(
            queryRequired(raw, FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement"))
        let delegate = SizeChangedEventHandler.new({ _, _ =>
            try {
                handler(fe.ActualWidth, fe.ActualHeight)
            } catch (_: Exception) {
                ()
            }
        })
        let token = fe.addSizeChanged(delegate)
        EventRevoker({ =>
            try {
                fe.removeSizeChanged(token)
            } catch (_: Exception) {
                ()
            }
            delegate.close()
            fe.close()
        })
    }

    // Subscribe to the per-frame CompositionTarget.Rendering event (drives custom
    // animation / continuous redraw). The callback fires once per composed frame.
    // The returned EventRevoker owns the subscription + delegate; it must be kept
    // alive for as long as per-frame callbacks are wanted and closed to stop them
    // (the delegate is a high-frequency CCW, so the revoker rooting it — and
    // releasing it on close — is what prevents a leak / use-after-free; same
    // discipline as the winui/event_*.cj revokers). Rendering is a STATIC event on
    // Microsoft.UI.Xaml.Media.CompositionTarget, reached through its activation
    // factory's ICompositionTargetStatics. Mirrors the reference CompositionTarget
    // Rendering wiring.
    public func onRendering(handler: () -> Unit): EventRevoker {
        let factory = expectFactory(
            loadFactoryByName(COMPOSITION_TARGET_RUNTIME_NAME, IGenericFactory.descriptor()),
            "ICompositionTargetStatics activation"
        )
        // Own one ref to ICompositionTargetStatics for the subscription lifetime.
        let staticsRaw = queryRequired(factory.asRaw(), IID_ICOMPOSITIONTARGET_STATICS, "ICompositionTargetStatics")
        factory.close()
        let table = readWinuiVtbl<ICompositionTargetStaticsVtbl>(staticsRaw)
        let delegate = TypedEventHandler<IInspectable, IInspectable>.new({ _, _ =>
            try {
                handler()
            } catch (_: Exception) {
                ()
            }
        })
        var token = 0i64
        let hr = HRESULT(unsafe {
            table.add_Rendering(staticsRaw, delegate.asRaw(), CPointer<Int64>(inout token))
        })
        if (hr.failed()) {
            delegate.close()
            releaseRaw(staticsRaw)
            throw WindowsException(hr)
        }
        // Freeze the token into a `let` for capture (see note in
        // onCompositionScaleChanged): a lambda capturing a var cannot be stored.
        let registeredToken = token
        EventRevoker({ =>
            let removeTable = readWinuiVtbl<ICompositionTargetStaticsVtbl>(staticsRaw)
            let _ = unsafe { removeTable.remove_Rendering(staticsRaw, registeredToken) }
            delegate.close()
            releaseRaw(staticsRaw)
        })
    }
}

// Read (scaleX, scaleY) off a raw ISwapChainPanel-bearing sender pointer
// (non-owning). Returns (1.0, 1.0) when the object does not answer
// ISwapChainPanel or a getter fails.
func readCompositionScale(senderRaw: CPointer<Unit>): (Float32, Float32) {
    if (senderRaw.isNull()) { return (1.0, 1.0) }
    match (unsafe { queryInterfaceRaw(senderRaw, IID_ISWAPCHAINPANEL) }) {
        case Some(panelRaw) =>
            try {
                let table = readWinuiVtbl<ISwapChainPanelVtbl>(panelRaw)
                var x: Float32 = 1.0
                var y: Float32 = 1.0
                let hrx = HRESULT(unsafe { table.get_CompositionScaleX(panelRaw, CPointer<Float32>(inout x)) })
                let hry = HRESULT(unsafe { table.get_CompositionScaleY(panelRaw, CPointer<Float32>(inout y)) })
                if (hrx.failed() || hry.failed()) { return (1.0, 1.0) }
                return (x, y)
            } finally {
                releaseRaw(panelRaw)
            }
        case None => return (1.0, 1.0)
    }
}

// Reconstruct a CPointer<Unit> from the UIntNative address carried in a
// NativeElement (the inverse of CPointer.toUIntNative). Cangjie has no direct
// integer→CPointer constructor, so this offsets a null base pointer by the
// address — the same technique as windows_polyfill.handlePointerFromInt, kept
// local to avoid adding a package dependency for one call.
func pointerFromUIntNative(value: UIntNative): CPointer<Unit> {
    if (value == 0) { return CPointer<Unit>() }
    let basePtr = CPointer<UInt8>()
    let offsetPtr: CPointer<UInt8> = unsafe { basePtr + Int64(value) }
    unsafe { CPointer<Unit>(offsetPtr) }
}

// Convenience constructor used from user on_ready callbacks:
//   swap_chain_panel().onReady { native => swapChainPanelHandle(native).setSwapChain(sc) }
public func swapChainPanelHandle(native: NativeElement): SwapChainPanelHandle {
    SwapChainPanelHandle(native)
}
