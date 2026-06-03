package windows_reactor.winui

import windows_reactor.core.{Prop, PropValue}
import windows_core.{HString}
import windows_interface.{IInspectable}
import windows_reference.{IReference, hStringReference, boolReference}
import windows_common.Microsoft.UI.Xaml.Controls.{
    Control, ContentControl, TextBlock, ToggleSwitch, Slider, NumberBox,
    ProgressBar, ProgressRing, RadioButton, RadioButtons, RatingControl
}
import windows_common.Microsoft.UI.Xaml.Controls.Primitives.{ToggleButton, RangeBase}
import windows_common.impl.{
    Microsoft_UI_Xaml_Controls_Orientation_Vertical,
    Microsoft_UI_Xaml_Controls_Orientation_Horizontal,
    Windows_Foundation_IReference_1
}

// Per-family property setters for value / toggle input controls (CheckBox,
// RadioButton, RadioButtons, ToggleSwitch, Slider, NumberBox, ProgressBar,
// ProgressRing, RatingControl). Returns true when the prop was consumed.
//
// ABI forms (spec §8.1): leaf properties living on the control's own default
// interface are set through the high-level projection `mut prop` setters
// (NumberBox.Value, ToggleSwitch.IsOn, RatingControl.MaxRating, …). Properties
// living on a base interface that is not the variant's default interface are
// reached by QI'ing to the base projection class and using its high-level
// surface (Primitives.RangeBase.Value for Slider/ProgressBar; Control.IsEnabled
// for the generic enabled toggle) or, when nullable, the raw interface method
// (Primitives.IToggleButton.SetIsChecked accepts a boxed IReference<Bool> or a
// null pointer for the indeterminate state).
func applyInputProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        // ── IsChecked (CheckBox, RadioButton) — nullable bool via IToggleButton ──
        case IsChecked => match ((handle, value)) {
            case (CheckBoxH(_), BoolV(v)) =>
                setToggleChecked(handle.asRaw(), Some(v)); true
            case (CheckBoxH(_), Unset) =>
                setToggleChecked(handle.asRaw(), None); true
            case (RadioButtonH(_), BoolV(v)) =>
                setToggleChecked(handle.asRaw(), Some(v)); true
            case (RadioButtonH(_), Unset) =>
                setToggleChecked(handle.asRaw(), None); true
            case _ => false
        }
        // ── CheckBoxLabel (CheckBox content) ─────────────────────────────────
        case CheckBoxLabel => match ((handle, value)) {
            case (CheckBoxH(_), Str(s)) =>
                setContentControlText(handle.asRaw(), s); true
            case (CheckBoxH(_), Unset) =>
                clearContentControl(handle.asRaw()); true
            case _ => false
        }
        // ── RadioLabel (RadioButton content) ─────────────────────────────────
        case RadioLabel => match ((handle, value)) {
            case (RadioButtonH(_), Str(s)) =>
                setContentControlText(handle.asRaw(), s); true
            case (RadioButtonH(_), Unset) =>
                clearContentControl(handle.asRaw()); true
            case _ => false
        }
        // ── GroupName (RadioButton) ──────────────────────────────────────────
        case GroupName => match ((handle, value)) {
            case (RadioButtonH(r), Str(s)) =>
                r.GroupName = HString(s); true
            case (RadioButtonH(r), Unset) =>
                r.GroupName = HString(""); true
            case _ => false
        }
        // ── ToggleSwitch ─────────────────────────────────────────────────────
        case IsOn => match ((handle, value)) {
            case (ToggleSwitchH(ts), BoolV(v)) =>
                ts.IsOn = v; true
            case _ => false
        }
        case OnContent => match ((handle, value)) {
            case (ToggleSwitchH(ts), Str(s)) =>
                withTextBlockInspectable(s, { insp => ts.OnContent = insp }); true
            case (ToggleSwitchH(ts), Unset) =>
                ts.OnContent = nullInspectable(); true
            case _ => false
        }
        case OffContent => match ((handle, value)) {
            case (ToggleSwitchH(ts), Str(s)) =>
                withTextBlockInspectable(s, { insp => ts.OffContent = insp }); true
            case (ToggleSwitchH(ts), Unset) =>
                ts.OffContent = nullInspectable(); true
            case _ => false
        }
        // ── NumericValue (Slider / ProgressBar via RangeBase; NumberBox /
        //    ProgressRing / RatingControl directly) ────────────────────────────
        case NumericValue => match ((handle, value)) {
            case (SliderH(_), F64(v)) =>
                setRangeValue(handle.asRaw(), v); true
            case (ProgressBarH(_), F64(v)) =>
                setRangeValue(handle.asRaw(), v); true
            case (NumberBoxH(n), F64(v)) =>
                n.Value = v; true
            case (ProgressRingH(p), F64(v)) =>
                p.Value = v; true
            case (RatingControlH(r), F64(v)) =>
                r.Value = v; true
            case _ => false
        }
        // ── Minimum ──────────────────────────────────────────────────────────
        case Minimum => match ((handle, value)) {
            case (SliderH(_), F64(v)) =>
                setRangeMinimum(handle.asRaw(), v); true
            case (ProgressBarH(_), F64(v)) =>
                setRangeMinimum(handle.asRaw(), v); true
            case (NumberBoxH(n), F64(v)) =>
                n.Minimum = v; true
            case (ProgressRingH(p), F64(v)) =>
                p.Minimum = v; true
            case _ => false
        }
        // ── Maximum ──────────────────────────────────────────────────────────
        case Maximum => match ((handle, value)) {
            case (SliderH(_), F64(v)) =>
                setRangeMaximum(handle.asRaw(), v); true
            case (ProgressBarH(_), F64(v)) =>
                setRangeMaximum(handle.asRaw(), v); true
            case (NumberBoxH(n), F64(v)) =>
                n.Maximum = v; true
            case (ProgressRingH(p), F64(v)) =>
                p.Maximum = v; true
            case _ => false
        }
        // ── Step (Slider: StepFrequency + RangeBase.SmallChange) ─────────────
        case Step => match ((handle, value)) {
            case (SliderH(s), F64(v)) =>
                s.StepFrequency = v
                setRangeSmallChange(handle.asRaw(), v)
                true
            case (SliderH(s), Unset) =>
                s.StepFrequency = 1.0
                setRangeSmallChange(handle.asRaw(), 1.0)
                true
            case _ => false
        }
        // ── Header (Slider / NumberBox / RadioButtons) ───────────────────────
        case Header => match ((handle, value)) {
            case (SliderH(s), Str(label)) =>
                withTextBlockInspectable(label, { insp => s.Header = insp }); true
            case (SliderH(s), Unset) =>
                s.Header = nullInspectable(); true
            case (NumberBoxH(n), Str(label)) =>
                withTextBlockInspectable(label, { insp => n.Header = insp }); true
            case (NumberBoxH(n), Unset) =>
                n.Header = nullInspectable(); true
            case (RadioButtonsH(r), Str(label)) =>
                withTextBlockInspectable(label, { insp => r.Header = insp }); true
            case (RadioButtonsH(r), Unset) =>
                r.Header = nullInspectable(); true
            case (ToggleSwitchH(ts), Str(label)) =>
                withTextBlockInspectable(label, { insp => ts.Header = insp }); true
            case (ToggleSwitchH(ts), Unset) =>
                ts.Header = nullInspectable(); true
            case _ => false
        }
        // ── Orientation (Slider) ─────────────────────────────────────────────
        case Orientation => match ((handle, value)) {
            case (SliderH(s), Vertical(vert)) =>
                s.Orientation = if (vert) {
                    Microsoft_UI_Xaml_Controls_Orientation_Vertical
                } else {
                    Microsoft_UI_Xaml_Controls_Orientation_Horizontal
                }
                true
            case _ => false
        }
        // ── IsIndeterminate (ProgressBar / ProgressRing) ─────────────────────
        case IsIndeterminate => match ((handle, value)) {
            case (ProgressBarH(p), BoolV(v)) =>
                p.IsIndeterminate = v; true
            case (ProgressRingH(p), BoolV(v)) =>
                p.IsIndeterminate = v; true
            case _ => false
        }
        // ── IsActive (ProgressRing) ──────────────────────────────────────────
        case IsActive => match ((handle, value)) {
            case (ProgressRingH(p), BoolV(v)) =>
                p.IsActive = v; true
            case _ => false
        }
        // ── RatingControl ────────────────────────────────────────────────────
        case MaxRating => match ((handle, value)) {
            case (RatingControlH(r), I32(v)) =>
                r.MaxRating = v; true
            case _ => false
        }
        case RatingCaption => match ((handle, value)) {
            case (RatingControlH(r), Str(s)) =>
                r.Caption = HString(s); true
            case (RatingControlH(r), Unset) =>
                r.Caption = HString(""); true
            case _ => false
        }
        case PlaceholderValue => match ((handle, value)) {
            case (RatingControlH(r), F64(v)) =>
                r.PlaceholderValue = v; true
            case _ => false
        }
        case IsReadOnly => match ((handle, value)) {
            case (RatingControlH(r), BoolV(v)) =>
                r.IsReadOnly = v; true
            case _ => false
        }
        // ── RadioButtons collection / selection ──────────────────────────────
        case RadioButtonsItems => match ((handle, value)) {
            case (RadioButtonsH(r), StrList(items)) =>
                // r.Items is the generic Windows.Foundation IVector<IInspectable>;
                // its projection exposes only the raw HRESULT ABI methods, so
                // Clear / Append go through unsafe + checkHRESULT. Each string is
                // boxed into an IReference<HString> (IInspectable) and appended;
                // Append takes its own ref so the box is released afterwards.
                let vec = r.Items
                try {
                    checkHRESULT(unsafe { vec.Clear() }, "RadioButtons.Items.Clear")
                    for (s in items) {
                        let box = hStringReference(s)
                        try {
                            checkHRESULT(unsafe { vec.Append(box.asRaw()) }, "RadioButtons.Items.Append")
                        } finally {
                            box.close()
                        }
                    }
                } finally {
                    vec.close()
                }
                true
            case _ => false
        }
        case SelectedIndex => match ((handle, value)) {
            case (RadioButtonsH(r), I32(v)) =>
                r.SelectedIndex = v; true
            case _ => false
        }
        case RadioButtonsMaxColumns => match ((handle, value)) {
            case (RadioButtonsH(r), I32(v)) =>
                r.MaxColumns = v; true
            case _ => false
        }
        // ── IsEnabled (all input controls via Control.IsEnabled) ─────────────
        case IsEnabled => match (value) {
            case BoolV(v) =>
                setInputControlEnabled(handle.asRaw(), v); true
            case Unset =>
                setInputControlEnabled(handle.asRaw(), true); true
            case _ => false
        }
        case _ => false
    }
}

// ── private helpers ─────────────────────────────────────────────────────────

// Set ToggleButton.IsChecked to a tri-state nullable bool via the high-level
// IsChecked property (an IReference<Bool> on the IToggleButton surface).
// `Some(v)` boxes the bool through windows_reference.IReference<Bool> and hands
// its COM pointer to the property as the equivalent Windows.Foundation.IReference
// projection view; `None` assigns a null reference (the indeterminate state).
// Behaviourally identical to the reference `put_IsChecked(Some(v))` /
// `put_IsChecked(None)`. The high-level setter scopes (and releases) its own
// interface, so no interface ref leaks here.
func setToggleChecked(raw: CPointer<Unit>, value: ?Bool): Unit {
    let tb = ToggleButton.fromAbiTake(
        queryRequired(raw, ToggleButton.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IToggleButton")
    )
    try {
        match (value) {
            case Some(v) =>
                let box = boolReference(v)
                try {
                    tb.IsChecked = Windows_Foundation_IReference_1<Bool>.viewOf(box.asRaw())
                } finally {
                    box.close()
                }
            case None =>
                tb.IsChecked = Windows_Foundation_IReference_1<Bool>.viewOf(CPointer<Unit>())
        }
    } finally {
        tb.close()
    }
}

// Clear a ContentControl's content (set Content = null). Used by the Unset arms
// of CheckBoxLabel / RadioLabel.
func clearContentControl(raw: CPointer<Unit>): Unit {
    let cc = ContentControl.fromAbiTake(
        queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
    )
    try {
        cc.Content = nullInspectable()
    } finally {
        cc.close()
    }
}

// QI to the Primitives.RangeBase base surface and set Value/Minimum/Maximum/
// SmallChange — the value props live on IRangeBase, not on the Slider/ProgressBar
// default interface, so they are reached through this base projection.
func setRangeValue(raw: CPointer<Unit>, v: Float64): Unit {
    let rb = RangeBase.fromAbiTake(
        queryRequired(raw, RangeBase.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IRangeBase")
    )
    try {
        rb.Value = v
    } finally {
        rb.close()
    }
}

func setRangeMinimum(raw: CPointer<Unit>, v: Float64): Unit {
    let rb = RangeBase.fromAbiTake(
        queryRequired(raw, RangeBase.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IRangeBase")
    )
    try {
        rb.Minimum = v
    } finally {
        rb.close()
    }
}

func setRangeMaximum(raw: CPointer<Unit>, v: Float64): Unit {
    let rb = RangeBase.fromAbiTake(
        queryRequired(raw, RangeBase.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IRangeBase")
    )
    try {
        rb.Maximum = v
    } finally {
        rb.close()
    }
}

func setRangeSmallChange(raw: CPointer<Unit>, v: Float64): Unit {
    let rb = RangeBase.fromAbiTake(
        queryRequired(raw, RangeBase.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IRangeBase")
    )
    try {
        rb.SmallChange = v
    } finally {
        rb.close()
    }
}

// QI to the Control base surface and set IsEnabled (the generic enabled toggle
// lives on IControl, shared by every Control-derived input control). Named
// distinctly from the lists family's equivalent to avoid a package-level
// duplicate free-function definition.
func setInputControlEnabled(raw: CPointer<Unit>, v: Bool): Unit {
    let ctrl = Control.fromAbiTake(
        queryRequired(raw, Control.iid(), "Microsoft.UI.Xaml.Controls.IControl")
    )
    try {
        ctrl.IsEnabled = v
    } finally {
        ctrl.close()
    }
}

// Build a fresh TextBlock wrapping `text` and run `assign` with its IInspectable
// view while the TextBlock projection is still alive, then release it. The
// property setter (`assign`) takes its own ref on the underlying COM object
// during the call, so the object survives after this helper drops its ref. The
// assign-then-close ordering avoids handing out a view of an already-released
// (potentially freed) object — mirrors the proven setContentControlText path.
func withTextBlockInspectable(text: String, assign: (IInspectable) -> Unit): Unit {
    let tb = TextBlock.new()
    try {
        tb.Text = HString(text)
        assign(tb.asIInspectable())
    } finally {
        tb.close()
    }
}

// A null (non-owning) IInspectable used to clear an IInspectable-typed property.
func nullInspectable(): IInspectable {
    IInspectable.viewOf(CPointer<Unit>())
}
