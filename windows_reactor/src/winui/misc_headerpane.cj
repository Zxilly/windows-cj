package windows_reactor.winui

import windows_interface.{IInspectable}
import windows_reactor.bindings.{UIElement}
// ============================================================================
// Header / Pane element family — free-function setters.
//
// priority: P6-critical. NavigationView (PaneHeader / Pane), Expander, TitleBar
// and SplitView header/pane slots are used by the navigation gallery samples.
//
// The Backend methods carry `?ControlId`; the WinUIBackend resolves them to
// `?Handle` (None when the id is absent or unknown) before delegating here.
//
// Reference: winui/backend/mod.rs set_header_element / set_pane_element.
//
// Projection ABI (verified against windows_sys):
//   - Expander.Header is an IInspectable-typed `mut prop` (SetHeader). The
//     reference passes its UIElement; we QI the header handle to the high-level
//     UIElement and hand its IInspectable view to the setter.
//   - TitleBar.Content / TitleBar.RightHeader are UIElement-typed `mut prop`s
//     (SetContent / SetRightHeader).
//   - SplitView.Pane is a UIElement-typed `mut prop` (SetPane).
//   All UIElement setters route through winrtBorrowGenericIn, so a null-raw view
//   (`UIElement.viewOf(null)`) clears the slot — matching `put_X(None)`. The
//   IInspectable setter clears the same way with `IInspectable.viewOf(null)`.
// ============================================================================

// Set (or clear) the control's header element. `headerHandle` is None to clear.
//
// Mirrors set_header_element: Expander.put_Header (the header-bearing expander)
// and TitleBar.put_Content (the title bar's header content slot). Controls that
// do not expose a settable header element fall through to a no-op.
func headerSetElement(handle: Handle, headerHandle: ?Handle): Unit {
    match (handle) {
        case ExpanderH(e) =>
            match (headerHandle) {
                case Some(hH) =>
                    // Expander.Header takes an IInspectable; assign the resolved
                    // header UIElement's IInspectable view (the assignment AddRefs
                    // through the target, so the temporary view is closed after).
                    let ui = handleUIElement(hH)
                    try {
                        e.Header = ui.asIInspectable()
                    } finally {
                        ui.close()
                    }
                case None =>
                    e.Header = IInspectable.viewOf(CPointer<Unit>())
            }
        case TitleBarH(tb) =>
            match (headerHandle) {
                case Some(hH) =>
                    let ui = handleUIElement(hH)
                    try {
                        tb.Content = ui
                    } finally {
                        ui.close()
                    }
                case None =>
                    tb.Content = UIElement.viewOf(CPointer<Unit>())
            }
        case _ => ()
    }
}

// Set (or clear) the control's pane element (e.g. SplitView.Pane /
// TitleBar.RightHeader). `paneHandle` is None to clear.
//
// Mirrors set_pane_element: SplitView.put_Pane and TitleBar.put_RightHeader.
// Controls that do not expose a settable pane element fall through to a no-op.
func paneSetElement(handle: Handle, paneHandle: ?Handle): Unit {
    match (handle) {
        case SplitViewH(sv) =>
            match (paneHandle) {
                case Some(pH) =>
                    let ui = handleUIElement(pH)
                    try {
                        sv.Pane = ui
                    } finally {
                        ui.close()
                    }
                case None =>
                    sv.Pane = UIElement.viewOf(CPointer<Unit>())
            }
        case TitleBarH(tb) =>
            match (paneHandle) {
                case Some(pH) =>
                    let ui = handleUIElement(pH)
                    try {
                        tb.RightHeader = ui
                    } finally {
                        ui.close()
                    }
                case None =>
                    tb.RightHeader = UIElement.viewOf(CPointer<Unit>())
            }
        case _ => ()
    }
}

// ── private helpers ─────────────────────────────────────────────────────────

// QI a handle's identity to the high-level UIElement class (the type the
// Header/Content/Pane/RightHeader setters accept), mirroring the reference
// `Handle::as_ui_element()` → UIElement. Caller owns the returned wrapper
// (close()). Every backend-creatable control derives from UIElement, so the QI
// always succeeds.
func handleUIElement(h: Handle): UIElement {
    UIElement.fromAbiTake(
        queryRequired(h.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")
    )
}
