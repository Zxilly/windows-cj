package windows_reactor.winui

import windows_reactor.core.{NativeElement}
import windows_core.{
    HRESULT,
    WindowsException,
    queryInterfaceRaw
}
import windows_interface.{IInspectable}
import windows_common.Microsoft.UI.Xaml.{IUIElement, IFrameworkElement, FrameworkElement, SizeChangedEventHandler}
import windows_common.Microsoft.UI.Xaml.Controls.{SwapChainPanel}
import windows_common.Microsoft.UI.Xaml.Media.{CompositionTarget}
import windows_common.Win32.System.WinRT.Xaml.{ISwapChainPanelNativeVtbl}
import windows_common.Foundation.{TypedEventHandler, EventHandler}

// ============================================================================
// SwapChainPanel subsystem (phase B of the canvas port).
//
// Hosts native Direct3D / Direct2D rendering inside the WinUI XAML tree by
// projecting `Microsoft.UI.Xaml.Controls.SwapChainPanel` and the
// `ISwapChainPanelNative` Win32 interop interface used to attach a DXGI swap
// chain. Drives the per-frame `Microsoft.UI.Xaml.Media.CompositionTarget`
// Rendering event for continuous redraw.
//
// PROJECTION STRATEGY — windows_common GENERATED PROJECTION:
//   `SwapChainPanel`, its `ISwapChainPanel` composition-scale interface and
//   factory, `Microsoft.UI.Xaml.Media.CompositionTarget` (the static Rendering
//   event), and the `Windows.Win32.System.WinRT.Xaml.ISwapChainPanelNative`
//   interop vtbl are all part of the curated windows_common projection (their
//   precise-type features are listed in
//   windows_common/codegen-manifest.json requested_features). This file uses
//   those generated projection types directly:
//     - SwapChainPanel.CreateInstance — composable (CreateInstance with null
//       aggregation base) activation, the same shape as every other composable
//       control in handle.cj.
//     - SwapChainPanel.CompositionScaleX / CompositionScaleY props (scalar
//       getters) and addCompositionScaleChanged / removeCompositionScaleChanged.
//     - CompositionTarget.Rendering / RemoveRendering static event accessors.
//     - ISwapChainPanelNativeVtbl.SetSwapChain, whose native COM ABI layout is
//       shared by the Windows.UI.Xaml and Microsoft.UI.Xaml interop interfaces.
//   The QI target IID is not taken from the generated Windows.Win32 interface:
//   that metadata describes the Windows.UI.Xaml/UWP family
//   (f92f19d2-3ade-45a6-a20c-f6f1ea90554b), while WinUI 3
//   Microsoft.UI.Xaml.Controls.SwapChainPanel answers the Microsoft.UI.Xaml
//   native IID (63aad0b8-7c24-40ff-85a8-640d944cc325). The WinUI 3 IID is
//   maintained in extras.cj; the vtbl layout is still generated.
//
// ABI-BUG NOTE: none of the methods used here return an aggregate by value, so
// the sret/RAX miscompilation in web/book/src/aggregate-return-abi-bug.md does
// not apply. SetSwapChain takes a pointer and returns HRESULT; the
// CompositionScaleX/Y props read a scalar f32 out-param; the event add/remove
// methods return / take an Int64 token.
// ============================================================================

// ============================================================================
// SwapChainPanelControl — the winui Handle's backing object for a created
// SwapChainPanel. Wraps the generated SwapChainPanel projection (just like the
// other Handle variants wrap their generated projection classes). GC + close()
// (with a `closed` guard) manage the COM ref.
// ============================================================================

public class SwapChainPanelControl {
    private let panel: SwapChainPanel
    private var closed: Bool = false

    private init(panel: SwapChainPanel) {
        this.panel = panel
    }

    // Activate a fresh SwapChainPanel. SwapChainPanel is a COMPOSABLE XAML class
    // (DependencyObject-derived), so it is activated through its composition
    // factory's CreateInstance(base=null, &inner, &outer) — the same composable
    // contract as every other control built via makeComposable in handle.cj. With
    // a null aggregation base the caller owns the inner non-delegating identity;
    // makeComposable releases it and keeps the outer instance.
    public static func create(): SwapChainPanelControl {
        SwapChainPanelControl(makeComposable(SwapChainPanel.CreateInstance))
    }

    // Default-interface identity pointer (for QI / parenting). Non-owning.
    public func asRaw(): CPointer<Unit> {
        if (closed) { return CPointer<Unit>() }
        panel.asRaw()
    }

    // QI to the IUIElement view (the type appended into a Panel's Children and the
    // universal element surface). Mirrors the other Handle variants' asIUIElement.
    public func asIUIElement(): IUIElement {
        panel.asIUIElement()
    }

    // QI to the IFrameworkElement view (Width / Height / Margin / Alignment).
    public func asIFrameworkElement(): IFrameworkElement {
        panel.asIFrameworkElement()
    }

    public func asIInspectable(): IInspectable { panel.asIInspectable() }

    public func close(): Unit {
        if (!closed) {
            closed = true
            panel.close()
        }
    }
}

// ============================================================================
// SwapChainPanelHandle — phase-C interop surface handed to user code through
// the SwapChainPanelWidget on_ready callback. It is constructed from the opaque
// NativeElement token the reconciler delivers (the live control's raw IUIElement
// pointer), and rebuilds the WinRT-typed interop views in this layer (keeping
// core backend-agnostic). Its methods (setSwapChain / compositionScale /
// onCompositionScaleChanged) operate on the wrapped SwapChainPanel.
//
// LIFETIME: the wrapped raw pointer is NON-OWNING — the live control (kept alive
// by the backend's Handle map for as long as it is mounted) owns the COM ref.
// The handle therefore must only be used while the control is mounted (i.e.
// from within / after on_ready and before the panel is unmounted).
// ============================================================================

public class SwapChainPanelHandle {
    private let raw: CPointer<Unit>

    public init(native: NativeElement) {
        this.raw = pointerFromUIntNative(native.raw)
    }

    // Attach a DXGI swap chain (created with CreateSwapChainForComposition) to
    // the panel. `swapChainRaw` must be a valid IDXGISwapChain / IDXGISwapChain1
    // pointer (non-owning; the SetSwapChain call AddRefs it internally). QIs the
    // panel to ISwapChainPanelNative and calls SetSwapChain through the generated
    // ISwapChainPanelNativeVtbl. Throws on QI / SetSwapChain failure.
    public func setSwapChain(swapChainRaw: CPointer<Unit>): Unit {
        if (raw.isNull()) {
            throw Exception("SwapChainPanelHandle.setSwapChain: null panel")
        }
        let nativeRaw = queryRequired(raw, IID_WINUI3_ISWAPCHAINPANEL_NATIVE, "Microsoft.UI.Xaml.ISwapChainPanelNative")
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
    // panel pointer was lost). Reads the SwapChainPanel CompositionScaleX /
    // CompositionScaleY props (scalar out-param getters; no aggregate return —
    // see the ABI-bug note above).
    public func compositionScale(): (Float32, Float32) {
        if (raw.isNull()) { return (1.0, 1.0) }
        readCompositionScale(raw)
    }

    // Subscribe to composition-scale changes (e.g. the window moves to a monitor
    // with a different DPI). The callback receives the new (scaleX, scaleY). The
    // returned EventRevoker owns the subscription + the COM delegate (which roots
    // the CCW for the subscription's lifetime, mirroring the EventRevoker pattern
    // in winui/event_*.cj) and unregisters + releases on close().
    public func onCompositionScaleChanged(handler: (Float32, Float32) -> Unit): EventRevoker {
        if (raw.isNull()) {
            throw Exception("SwapChainPanelHandle.onCompositionScaleChanged: null panel")
        }
        // Own one ref to the SwapChainPanel for the subscription lifetime so the
        // remove call (in the revoker) is valid.
        let panel = SwapChainPanel.fromAbiTake(
            queryRequired(raw, SwapChainPanel.iid(), "Microsoft.UI.Xaml.Controls.ISwapChainPanel"))
        let delegate = TypedEventHandler<SwapChainPanel, IInspectable>.new({ senderRaw, _ =>
            try {
                let (x, y) = readCompositionScale(senderRaw)
                handler(x, y)
            } catch (_: Exception) {
                ()
            }
        })
        var token = 0i64
        try {
            token = panel.addCompositionScaleChanged(delegate)
        } catch (e: Exception) {
            delegate.close()
            panel.close()
            throw e
        }
        // Freeze the registration token into an immutable copy: a Cangjie lambda
        // that captures a mutable (var) variable may only be called inline, never
        // stored, so the revoker closure must capture a `let`.
        let registeredToken = token
        EventRevoker({ =>
            try {
                panel.removeCompositionScaleChanged(registeredToken)
            } catch (_: Exception) {
                ()
            }
            delegate.close()
            panel.close()
        })
    }

    // Subscribe to the panel's layout-size changes (width, height in DIPs). Use
    // this to resize the swap chain buffers. The returned EventRevoker owns the
    // subscription + delegate. Adds a SizeChanged handler on the FrameworkElement,
    // reading the new size from the panel's ActualWidth / ActualHeight (scalar
    // out-param getters; no aggregate return — see the ABI-bug note) so it does
    // not depend on decoding the SizeChangedEventArgs aggregate.
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
    // Microsoft.UI.Xaml.Media.CompositionTarget, reached through the generated
    // CompositionTarget.Rendering / RemoveRendering static accessors (which resolve
    // the ICompositionTargetStatics activation factory internally). Note Rendering
    // is a Windows.Foundation.EventHandler<Object>, not a TypedEventHandler.
    public func onRendering(handler: () -> Unit): EventRevoker {
        let delegate = EventHandler<IInspectable>.new({ _, _ =>
            try {
                handler()
            } catch (_: Exception) {
                ()
            }
        })
        var token = 0i64
        try {
            token = CompositionTarget.Rendering(delegate)
        } catch (e: Exception) {
            delegate.close()
            throw e
        }
        // Freeze the token into a `let` for capture (see note in
        // onCompositionScaleChanged): a lambda capturing a var cannot be stored.
        let registeredToken = token
        EventRevoker({ =>
            try {
                CompositionTarget.RemoveRendering(registeredToken)
            } catch (_: Exception) {
                ()
            }
            delegate.close()
        })
    }
}

// Read (scaleX, scaleY) off a raw ISwapChainPanel-bearing pointer (non-owning).
// Returns (1.0, 1.0) when the object does not answer ISwapChainPanel or a getter
// fails. Wraps the QI'd default interface in the generated SwapChainPanel
// projection and reads its CompositionScaleX / CompositionScaleY props.
func readCompositionScale(senderRaw: CPointer<Unit>): (Float32, Float32) {
    if (senderRaw.isNull()) { return (1.0, 1.0) }
    match (unsafe { queryInterfaceRaw(senderRaw, SwapChainPanel.iid()) }) {
        case Some(panelRaw) =>
            let panel = SwapChainPanel.fromAbiTake(panelRaw)
            try {
                return (panel.CompositionScaleX, panel.CompositionScaleY)
            } catch (_: Exception) {
                return (1.0, 1.0)
            } finally {
                panel.close()
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
