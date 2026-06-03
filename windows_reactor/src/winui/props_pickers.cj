package windows_reactor.winui

import windows_reactor.core.{Prop, PropValue}
import windows_core.HString
import windows_interface.IInspectable
import windows_common.Microsoft.UI.Xaml.Controls.{
    ColorPicker, DatePicker, TimePicker, CalendarDatePicker, CalendarView,
    TextBlock
}
import windows_common.UI.Color as XamlColor

// ============================================================================
// Per-family property setters for date / time / colour pickers (DatePicker,
// TimePicker, CalendarDatePicker, CalendarView, ColorPicker). Returns true when
// the prop was consumed; false otherwise (the prop falls through unhandled).
//
// Property ABI (spec §8.1): every prop these controls take is a high-level
// `mut prop` on the bound projection class, so the variant-bound object is
// written directly (cp.Color = …, dp.DayVisible = …). The one exception is
// IsEnabled, which lives on the base Control surface (Rust casts to IControl);
// it is applied here by QI-ing the handle to the high-level Control projection.
//
// Header (DatePicker / TimePicker / CalendarDatePicker) takes an IInspectable;
// the reference wraps the string in a TextBlock (string_as_textblock) and an
// Unset clears it (Rust passes None). headerInspectable mirrors that.
// ============================================================================
func applyPickerProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        // ── ColorPicker (W8) ──────────────────────────────────────────────
        case ColorValue =>
            match ((handle, value)) {
                case (ColorPickerH(cp), ColorV(a, r, g, b)) =>
                    var color = XamlColor()
                    color.A = a
                    color.R = r
                    color.G = g
                    color.B = b
                    cp.Color = color
                    true
                case _ => false
            }
        case IsAlphaEnabled =>
            match ((handle, value)) {
                case (ColorPickerH(cp), BoolV(v)) => cp.IsAlphaEnabled = v; true
                case _ => false
            }
        case IsHexInputVisible =>
            match ((handle, value)) {
                case (ColorPickerH(cp), BoolV(v)) => cp.IsHexInputVisible = v; true
                case _ => false
            }
        case IsColorSliderVisible =>
            match ((handle, value)) {
                case (ColorPickerH(cp), BoolV(v)) => cp.IsColorSliderVisible = v; true
                case _ => false
            }
        case IsColorChannelTextInputVisible =>
            match ((handle, value)) {
                case (ColorPickerH(cp), BoolV(v)) => cp.IsColorChannelTextInputVisible = v; true
                case _ => false
            }

        // ── DatePicker (W9) ───────────────────────────────────────────────
        case DayVisible =>
            match ((handle, value)) {
                case (DatePickerH(dp), BoolV(v)) => dp.DayVisible = v; true
                case _ => false
            }
        case MonthVisible =>
            match ((handle, value)) {
                case (DatePickerH(dp), BoolV(v)) => dp.MonthVisible = v; true
                case _ => false
            }
        case YearVisible =>
            match ((handle, value)) {
                case (DatePickerH(dp), BoolV(v)) => dp.YearVisible = v; true
                case _ => false
            }

        // ── TimePicker (W10) ──────────────────────────────────────────────
        case ClockIdentifier =>
            match ((handle, value)) {
                case (TimePickerH(tp), Str(s)) =>
                    let hs = HString(s)
                    try { tp.ClockIdentifier = hs } finally { hs.close() }
                    true
                case _ => false
            }
        case MinuteIncrement =>
            match ((handle, value)) {
                case (TimePickerH(tp), I32(v)) => tp.MinuteIncrement = v; true
                case _ => false
            }

        // ── CalendarDatePicker (W11) ──────────────────────────────────────
        case Placeholder =>
            match ((handle, value)) {
                case (CalendarDatePickerH(cdp), Str(s)) =>
                    let hs = HString(s)
                    try { cdp.PlaceholderText = hs } finally { hs.close() }
                    true
                case (CalendarDatePickerH(cdp), Unset) =>
                    let hs = HString("")
                    try { cdp.PlaceholderText = hs } finally { hs.close() }
                    true
                case _ => false
            }
        case IsCalendarOpen =>
            match ((handle, value)) {
                case (CalendarDatePickerH(cdp), BoolV(v)) => cdp.IsCalendarOpen = v; true
                case _ => false
            }

        // ── shared across pickers ─────────────────────────────────────────
        // Header: TextBlock-wrapped string on DatePicker / TimePicker /
        // CalendarDatePicker; Unset clears it (None in the reference).
        case Header =>
            match (handle) {
                case DatePickerH(dp) =>
                    match (value) {
                        case Str(s) => dp.Header = headerInspectable(s); true
                        case Unset => dp.Header = nullInspectable(); true
                        case _ => false
                    }
                case TimePickerH(tp) =>
                    match (value) {
                        case Str(s) => tp.Header = headerInspectable(s); true
                        case Unset => tp.Header = nullInspectable(); true
                        case _ => false
                    }
                case CalendarDatePickerH(cdp) =>
                    match (value) {
                        case Str(s) => cdp.Header = headerInspectable(s); true
                        case Unset => cdp.Header = nullInspectable(); true
                        case _ => false
                    }
                case _ => false
            }
        // IsTodayHighlighted: CalendarDatePicker and CalendarView.
        case IsTodayHighlighted =>
            match ((handle, value)) {
                case (CalendarDatePickerH(cdp), BoolV(v)) => cdp.IsTodayHighlighted = v; true
                case (CalendarViewH(cv), BoolV(v)) => cv.IsTodayHighlighted = v; true
                case _ => false
            }
        // IsGroupLabelVisible: CalendarView (W12).
        case IsGroupLabelVisible =>
            match ((handle, value)) {
                case (CalendarViewH(cv), BoolV(v)) => cv.IsGroupLabelVisible = v; true
                case _ => false
            }
        // IsEnabled lives on the base Control surface for every picker; QI to
        // the high-level Control projection and write its IsEnabled prop
        // (mirrors the reference `cast::<IControl>()?.put_IsEnabled`).
        case IsEnabled =>
            match (handle) {
                case DatePickerH(_) | TimePickerH(_) | CalendarDatePickerH(_) | CalendarViewH(_) =>
                    match (value) {
                        case BoolV(v) => setControlEnabled(handle.asRaw(), v); true
                        case _ => false
                    }
                case _ => false
            }

        case _ => false
    }
}

// Wrap a string in a TextBlock and surface its IInspectable identity for the
// IInspectable-typed Header setters (mirrors string_as_textblock + put_Header).
func headerInspectable(s: String): IInspectable {
    let tb = TextBlock.new()
    let hs = HString(s)
    try {
        tb.Text = hs
    } finally {
        hs.close()
    }
    tb.asIInspectable()
}
// nullInspectable() (Header clear) and setControlEnabled(raw, enabled) are
// shared in-package helpers (defined alongside the editable-text-input family);
// reused here for Header Unset and the picker IsEnabled / Control surface.
