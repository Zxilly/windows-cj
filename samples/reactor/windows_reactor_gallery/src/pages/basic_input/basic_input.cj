package windows_reactor_gallery.pages.basic_input

import std.collection.*
import std.math.round
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Basic Input category pages.
//
// routeBasicInput maps each Basic Input control tag to its page component.
// Each page fn is `func <name>Page(cx: RenderCx): Element`, wrapped via
// pageComponent(token, body) so it owns an independent hook scope; one
// module-scope token per page is minted via newComponentTypeToken().
//
// Each control now lives in its own file under this package
// (button.cj, check_box.cj, color_picker.cj, ...). This file keeps only the
// cross-control formatting helpers and the dispatch routing.
//
//   tag                  page fn               file
//   ------------------   --------------------- ----------------------
//   button               buttonPage            button.cj
//   check-box            checkBoxPage          check_box.cj
//   color-picker         colorPickerPage       color_picker.cj
//   combo-box            comboBoxPage          combo_box.cj
//   drop-down-button     dropDownButtonPage    drop_down_button.cj
//   hyperlink-button     hyperlinkButtonPage   hyperlink_button.cj
//   number-box           numberBoxPage         number_box.cj
//   password-box         passwordBoxPage       password_box.cj
//   radio-button         radioButtonPage       radio_button.cj
//   rating-control       ratingControlPage     rating_control.cj
//   repeat-button        repeatButtonPage      repeat_button.cj
//   slider               sliderPage            slider.cj
//   split-button         splitButtonPage       split_button.cj
//   text-box             textBoxPage           text_box.cj
//   toggle-button        toggleButtonPage      toggle_button.cj
//   toggle-switch        toggleSwitchPage      toggle_switch.cj
// ============================================================================

// ── Shared formatting helpers ───────────────────────────────────────────────
// Cangjie has no Rust-style `{:.N}` interpolation, so we render fixed-decimal
// floats by hand to keep the value labels behaviourally identical. These are
// used by more than one control page, so they stay in the category mod file.

// Round to an integer and render with no decimals (matches `{:.0}`).
func fmt0(value: Float64): String {
    Int64(round(value)).toString()
}

// Round to one decimal place and render with exactly one digit (matches `{:.1}`).
func fmt1(value: Float64): String {
    let scaled = Int64(round(value * 10.0))
    let neg = scaled < 0
    let abs = if (neg) { -scaled } else { scaled }
    let whole = abs / 10
    let frac = abs % 10
    let sign = if (neg) { "-" } else { "" }
    "${sign}${whole}.${frac}"
}

// Lookup the i-th element of a String list, or "?" when out of range.
func nth(items: Array<String>, index: Int64): String {
    if (index >= 0 && index < items.size) {
        items[index]
    } else {
        "?"
    }
}

func toList(items: Array<String>): ArrayList<String> {
    let out = ArrayList<String>()
    for (s in items) {
        out.add(s)
    }
    out
}

// ============================================================================
// Dispatch
// ============================================================================
public func routeBasicInput(tag: String): ?Element {
    match (tag) {
        case "button" => Some(pageComponent(buttonPageToken, buttonPage))
        case "check-box" => Some(pageComponent(checkBoxPageToken, checkBoxPage))
        case "color-picker" => Some(pageComponent(colorPickerPageToken, colorPickerPage))
        case "combo-box" => Some(pageComponent(comboBoxPageToken, comboBoxPage))
        case "drop-down-button" => Some(pageComponent(dropDownButtonPageToken, dropDownButtonPage))
        case "hyperlink-button" => Some(pageComponent(hyperlinkButtonPageToken, hyperlinkButtonPage))
        case "number-box" => Some(pageComponent(numberBoxPageToken, numberBoxPage))
        case "password-box" => Some(pageComponent(passwordBoxPageToken, passwordBoxPage))
        case "radio-button" => Some(pageComponent(radioButtonPageToken, radioButtonPage))
        case "rating-control" => Some(pageComponent(ratingControlPageToken, ratingControlPage))
        case "repeat-button" => Some(pageComponent(repeatButtonPageToken, repeatButtonPage))
        case "slider" => Some(pageComponent(sliderPageToken, sliderPage))
        case "split-button" => Some(pageComponent(splitButtonPageToken, splitButtonPage))
        case "text-box" => Some(pageComponent(textBoxPageToken, textBoxPage))
        case "toggle-button" => Some(pageComponent(toggleButtonPageToken, toggleButtonPage))
        case "toggle-switch" => Some(pageComponent(toggleSwitchPageToken, toggleSwitchPage))
        case _ => None
    }
}
