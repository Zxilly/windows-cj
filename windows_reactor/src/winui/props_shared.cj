package windows_reactor.winui

import windows_interface.{IInspectable}
import windows_reactor.bindings.Microsoft.UI.Xaml.Controls.{Control}

// ============================================================================
// Cross-family shared helpers that several props_*.cj files reference but none
// defines on its own. The parallel per-family authoring left two coordination
// gaps: the pickers and editable-text-input families each assumed the OTHER
// family owned `setControlEnabled`, and the text-input family referenced
// `emptyInspectable`. Defining them once here, in the same package, closes the
// gap without editing the family files.
// ============================================================================

// Control.IsEnabled via QI to the high-level Control projection. Two overloads
// so both call conventions used across the family files resolve (raw identity
// pointer — props_pickers; or the Handle — props_textinput). Cangjie resolves
// these by first-parameter type (function overloading).
func setControlEnabled(raw: CPointer<Unit>, enabled: Bool): Unit {
    let ctrl = Control.fromAbiTake(
        queryRequired(raw, Control.iid(), "Microsoft.UI.Xaml.Controls.IControl")
    )
    try {
        ctrl.IsEnabled = enabled
    } finally {
        ctrl.close()
    }
}

func setControlEnabled(handle: Handle, enabled: Bool): Unit {
    setControlEnabled(handle.asRaw(), enabled)
}

// A null-raw, non-owning IInspectable used to clear IInspectable-typed props
// (e.g. FrameworkElement.Header) on Unset. Behaviourally identical to
// nullInspectable() in props_input.cj; referenced under this name by
// props_textinput.cj.
func emptyInspectable(): IInspectable {
    IInspectable.viewOf(CPointer<Unit>())
}
