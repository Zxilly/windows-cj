package windows_reactor_minimal

import std.convert.*
import std.collection.ArrayList
import windows_reactor.core.*

// ============================================================================
// Group: input
//
// Examples owned by this group (filled into routeInput):
//   check_box, radio_button, radio_buttons, toggle_switch, slider,
//   number_box, rating_control, color_picker
//
// Contract (see main.cj):
//   routeInput(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesInput()     -> the example names this group owns, for the banner.
//
// Each example body is a `func <name>Example(cx: RenderCx): Element` mirroring
// the reference `fn app(cx) -> Element`; every reference `main()` uses
// `App::new().title("Sample")`, so the registry title is "Sample" everywhere.
// ============================================================================

// ── Local helpers ────────────────────────────────────────────────────────────

// Round a Float64 to the nearest integer and render with no decimals (the
// reference uses `{:.0}` for slider/number-box value labels).
func fmtInt(value: Float64): String {
    let scaled = value + (if (value >= 0.0) { 0.5 } else { -0.5 })
    Int64(scaled).toString()
}

// Render a Float64 with exactly one decimal place (reference `{:.1}` for the
// rating-control value label).
func fmtOneDecimal(value: Float64): String {
    let scaled = Int64(value * 10.0 + (if (value >= 0.0) { 0.5 } else { -0.5 }))
    let neg = scaled < 0
    let abs = if (neg) { -scaled } else { scaled }
    let whole = abs / 10
    let frac = abs % 10
    let sign = if (neg) { "-" } else { "" }
    "${sign}${whole}.${frac}"
}

// Build an ArrayList<String> from a fixed string array (radio_buttons takes a
// list; the reference passes a string array literal).
func strListOf(items: Array<String>): ArrayList<String> {
    let out = ArrayList<String>()
    for (s in items) {
        out.add(s)
    }
    out
}

// Lookup the i-th element of a string array, or a fallback when out of range
// (matches the reference `.get(idx).copied().unwrap_or("(none)")`).
func nthOr(items: Array<String>, index: Int64, fallback: String): String {
    if (index >= 0 && index < items.size) {
        items[index]
    } else {
        fallback
    }
}

// ── Equatable wrapper for the color-picker ARGB tuple state ──────────────────
// useState<T> requires T <: Equatable<T>. The reference keeps an (a, r, g, b)
// tuple in state; we wrap it so it can back a state slot, preserving ARGB order.
struct ArgbState <: Equatable<ArgbState> {
    let a: UInt8
    let r: UInt8
    let g: UInt8
    let b: UInt8

    init(a: UInt8, r: UInt8, g: UInt8, b: UInt8) {
        this.a = a
        this.r = r
        this.g = g
        this.b = b
    }

    public operator func ==(other: ArgbState): Bool {
        a == other.a && r == other.r && g == other.g && b == other.b
    }
    public operator func !=(other: ArgbState): Bool { !(this == other) }
}

// ============================================================================
// check_box
// ============================================================================
func checkBoxExample(cx: RenderCx): Element {
    let (checked, setChecked) = cx.useState<Bool>(false)

    let statusText = if (checked) { "Accepted \u{2713}" } else { "Not yet accepted" }

    vstack([
        check_box(checked)
            .label("I accept the terms")
            .onChanged({ v: Bool => setChecked.call(v) })
            .toElement(),
        text_block(statusText).toElement(),
        check_box(true).label("Disabled (always on)").enabled(false).toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// radio_button
//
// The reference uses an enum Size { Small, Medium (default), Large } tied to a
// single `RadioButton` per option via `.group("size")`. Cangjie state must be
// Equatable; we model the selection as Int64 (0=Small, 1=Medium, 2=Large) with
// the default of 1 (Medium), matching the enum's #[default] = Medium.
// ============================================================================
func radioButtonExample(cx: RenderCx): Element {
    let (size, setSize) = cx.useState<Int64>(1)

    let label = match (size) {
        case 0 => "Small"
        case 1 => "Medium"
        case 2 => "Large"
        case _ => "Medium"
    }

    vstack([
        radio_button("Small")
            .group("size")
            .checked(size == 0)
            .onChecked({ => setSize.call(0) })
            .toElement(),
        radio_button("Medium")
            .group("size")
            .checked(size == 1)
            .onChecked({ => setSize.call(1) })
            .toElement(),
        radio_button("Large")
            .group("size")
            .checked(size == 2)
            .onChecked({ => setSize.call(2) })
            .toElement(),
        text_block("size = ${label}").toElement(),
        radio_button("Disabled")
            .group("other")
            .checked(true)
            .enabled(false)
            .toElement()
    ]).spacing(4.0).toElement()
}

// ============================================================================
// radio_buttons
// ============================================================================
func radioButtonsExample(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int32>(0)

    let options = ["Email", "SMS", "None"]
    let label = nthOr(options, Int64(selected), "(none)")

    vstack([
        radio_buttons(strListOf(options))
            .header("Notifications")
            .selectedIndexOf(selected)
            .maxColumnsOf(3)
            .onSelectionChanged({ i: Int32 => setSelected.call(i) })
            .toElement(),
        text_block("selected_index = ${selected} (${label})").toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// toggle_switch
// ============================================================================
func toggleSwitchExample(cx: RenderCx): Element {
    let (on, setOn) = cx.useState<Bool>(true)

    let statusText = if (on) { "Notifications enabled" } else { "Notifications muted" }

    vstack([
        toggle_switch(on)
            .header("Notifications")
            .onContentText("On")
            .offContentText("Off")
            .onChanged({ v: Bool => setOn.call(v) })
            .toElement(),
        text_block(statusText).toElement(),
        toggle_switch(true)
            .header("Disabled (always on)")
            .enabled(false)
            .toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// slider
// ============================================================================
func sliderExample(cx: RenderCx): Element {
    let (volume, setVolume) = cx.useState<Float64>(35.0)

    vstack([
        slider(volume)
            .range(0.0, 100.0)
            .step(1.0)
            .header("Volume")
            .onChanged({ v: Float64 => setVolume.call(v) })
            .toElement(),
        text_block("Volume = ${fmtInt(volume)}").toElement(),
        slider(50.0)
            .range(0.0, 100.0)
            .header("Vertical")
            .vertical()
            .height(120.0)
            .toElement(),
        slider(50.0)
            .range(0.0, 100.0)
            .header("Disabled")
            .enabled(false)
            .toElement()
    ]).spacing(8.0).maxWidth(320.0).toElement()
}

// ============================================================================
// number_box
// ============================================================================
func numberBoxExample(cx: RenderCx): Element {
    let (quantity, setQuantity) = cx.useState<Float64>(3.0)

    vstack([
        number_box(quantity)
            .range(0.0, 10.0)
            .header("Quantity")
            .onValueChanged({ v: Float64 => setQuantity.call(v) })
            .toElement(),
        text_block("Quantity = ${fmtInt(quantity)}").toElement(),
        number_box(42.0).header("Disabled").enabled(false).toElement()
    ]).spacing(8.0).maxWidth(320.0).toElement()
}

// ============================================================================
// rating_control
// ============================================================================
func ratingControlExample(cx: RenderCx): Element {
    let (rating, setRating) = cx.useState<Float64>(3.0)

    vstack([
        rating_control(rating)
            .onChanged({ v: Float64 => setRating.call(v) })
            .toElement(),
        text_block("Rating: ${fmtOneDecimal(rating)} / 5").toElement(),
        rating_control(4.0).maxRatingOf(10).caption("Out of 10").toElement(),
        rating_control(2.5).readOnly().toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// color_picker
//
// The reference state is an (a, r, g, b) tuple; the color-changed callback also
// delivers ARGB order. We keep ARGB order end to end via ArgbState. Hex display
// uses zero-padded 2-width uppercase hex per channel (reference `{:02X}`).
// ============================================================================
func colorPickerExample(cx: RenderCx): Element {
    let (color, setColor) = cx.useState<ArgbState>(ArgbState(255u8, 0u8, 120u8, 215u8))

    let a = color.a
    let r = color.r
    let g = color.g
    let b = color.b

    let hex = "#${r.format("02X")}${g.format("02X")}${b.format("02X")}"

    vstack([
        color_picker(ColorArgb.withAlpha(a, r, g, b))
            .alphaEnabled(true)
            .onChanged({ argb: (UInt8, UInt8, UInt8, UInt8) =>
                setColor.call(ArgbState(argb[0], argb[1], argb[2], argb[3]))
            })
            .toElement(),
        text_block("ARGB: (${a}, ${r}, ${g}, ${b})").toElement(),
        text_block("Hex: ${hex}").toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// Dispatch
// ============================================================================
func routeInput(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "check_box" => Some(("Sample", checkBoxExample))
        case "radio_button" => Some(("Sample", radioButtonExample))
        case "radio_buttons" => Some(("Sample", radioButtonsExample))
        case "toggle_switch" => Some(("Sample", toggleSwitchExample))
        case "slider" => Some(("Sample", sliderExample))
        case "number_box" => Some(("Sample", numberBoxExample))
        case "rating_control" => Some(("Sample", ratingControlExample))
        case "color_picker" => Some(("Sample", colorPickerExample))
        case _ => None
    }
}

func namesInput(): Array<String> {
    ["check_box", "radio_button", "radio_buttons", "toggle_switch", "slider",
     "number_box", "rating_control", "color_picker"]
}
