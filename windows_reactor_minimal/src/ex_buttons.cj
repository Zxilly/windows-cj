package windows_reactor_minimal

import windows_reactor.core.*

// ============================================================================
// Group: buttons
//
// Examples owned by this group (filled into routeButtons):
//   button, button_icon, button_icon_dynamic, button_icon_glyph_change,
//   drop_down_button, split_button, repeat_button, hyperlink_button,
//   toggle_button
//
// Contract (see main.cj):
//   routeButtons(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesButtons()     -> the example names this group owns, for the banner.
//
// Each example is a `func <name>Example(cx: RenderCx): Element` matching the
// reference `fn app(cx) -> Element`; the registry title comes from each
// reference `main`'s App::new().title(..).
// ============================================================================

// ── button ──────────────────────────────────────────────────────────────────
// Reference state is u32 clicks; we use Int64 (Equatable) with identical
// arithmetic. `.on_click(bump)` -> `.onClick({ => ... })`, `.accent()` matches.
func buttonExample(cx: RenderCx): Element {
    let (clicks, setClicks) = cx.useState<Int64>(0)

    let bump = { => setClicks.call(clicks + 1) }

    vstack([
        button("Clicked ${clicks} times").onClick(bump).toElement(),
        button("Disabled").enabled(false).toElement(),
        button("Accent (Primary Action)").accent().toElement()
    ]).spacing(8.0).toElement()
}

// ── button_icon ───────────────────────────────────────────────────────────────
// Rust `.icon(SymbolGlyph::X)` lowers to the Cangjie builder `.withIcon(..)`.
// `count.saturating_sub(1)` is reproduced by clamping at 0.
func buttonIconExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)

    let dec = if (count > 0) { count - 1 } else { 0 }

    vstack([
        button("Plain Button").onClick({ => setCount.call(count + 1) }).toElement(),
        button("Add Item").withIcon(SymbolGlyph.Add).onClick({ => setCount.call(count + 1) }).toElement(),
        button("Delete").withIcon(SymbolGlyph.Delete).onClick({ => setCount.call(dec) }).toElement(),
        button("Save").withIcon(SymbolGlyph.Save).accent().toElement(),
        text_block("Count: ${count}").toElement()
    ]).spacing(8.0).toElement()
}

// ── button_icon_dynamic ───────────────────────────────────────────────────────
// Icon preserved while the label changes dynamically across renders.
func buttonIconDynamicExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)
    let label = "Clicked ${count} times"
    let saveLabel = if (count == 0) { "Save" } else { "Saved!" }

    vstack([
        button(label).withIcon(SymbolGlyph.Favorite).onClick({ => setCount.call(count + 1) }).toElement(),
        button(saveLabel).withIcon(SymbolGlyph.Save).accent().onClick({ => setCount.call(count + 1) }).toElement(),
        text_block("Click the buttons — the icons should remain visible.").opacity(0.6).toElement()
    ]).spacing(12.0).toElement()
}

// ── button_icon_glyph_change ──────────────────────────────────────────────────
// Text label preserved while the icon glyph toggles dynamically.
func buttonIconGlyphChangeExample(cx: RenderCx): Element {
    let (toggled, setToggled) = cx.useState<Bool>(false)
    let icon = if (toggled) { SymbolGlyph.Save } else { SymbolGlyph.Favorite }
    let status = if (toggled) { "Save" } else { "Favorite" }

    vstack([
        button("Toggle Icon").withIcon(icon).onClick({ => setToggled.call(!toggled) }).toElement(),
        text_block("Current icon: ${status}").opacity(0.6).toElement(),
        text_block("Click the button — the icon should change but the label stays.").opacity(0.4).toElement()
    ]).spacing(12.0).toElement()
}

// ── drop_down_button ──────────────────────────────────────────────────────────
func dropDownButtonExample(cx: RenderCx): Element {
    let (clicks, setClicks) = cx.useState<Int64>(0)

    let bump = { => setClicks.call(clicks + 1) }

    vstack([
        drop_down_button("Options").onClick(bump).toElement(),
        text_block("Clicked ${clicks} time(s)").toElement()
    ]).spacing(8.0).toElement()
}

// ── split_button ──────────────────────────────────────────────────────────────
func splitButtonExample(cx: RenderCx): Element {
    let (clicks, setClicks) = cx.useState<Int64>(0)

    let bump = { => setClicks.call(clicks + 1) }

    vstack([
        split_button("Primary action (${clicks})").onClick(bump).toElement(),
        split_button("Disabled").enabled(false).toElement()
    ]).spacing(8.0).toElement()
}

// ── repeat_button ─────────────────────────────────────────────────────────────
// `.delay(300)` / `.interval(50)` take Int32 in the Cangjie builder.
func repeatButtonExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)

    let increment = { => setCount.call(count + 1) }
    let decrement = { => setCount.call(count - 1) }

    vstack([
        text_block("Count: ${count}").toElement(),
        repeat_button("+1 (hold to repeat)")
            .onClick(increment)
            .delay(300)
            .interval(50)
            .toElement(),
        repeat_button("-1 (hold to repeat)")
            .onClick(decrement)
            .delay(300)
            .interval(50)
            .toElement(),
        repeat_button("Disabled").enabled(false).toElement()
    ]).spacing(8.0).toElement()
}

// ── hyperlink_button ──────────────────────────────────────────────────────────
func hyperlinkButtonExample(cx: RenderCx): Element {
    let (clicks, setClicks) = cx.useState<Int64>(0)

    let bump = { => setClicks.call(clicks + 1) }

    vstack([
        hyperlink_button("Open Microsoft Docs")
            .navigateUri("https://learn.microsoft.com/windows/apps/")
            .toElement(),
        hyperlink_button("Clicked ${clicks} times").onClick(bump).toElement(),
        hyperlink_button("Disabled")
            .navigateUri("https://example.com/")
            .enabled(false)
            .toElement()
    ]).spacing(8.0).toElement()
}

// ── toggle_button ─────────────────────────────────────────────────────────────
// `toggle_button(label, isChecked)`; Rust `.on_changed(|v: bool|..)` ->
// `.onChanged({ v: Bool => .. })`.
func toggleButtonExample(cx: RenderCx): Element {
    let (isBold, setBold) = cx.useState<Bool>(false)
    let (isItalic, setItalic) = cx.useState<Bool>(false)

    let styleLabel = if (isBold && isItalic) {
        "Bold + Italic"
    } else if (isBold) {
        "Bold"
    } else if (isItalic) {
        "Italic"
    } else {
        "Normal"
    }

    vstack([
        toggle_button("Bold", isBold).onChanged({ v: Bool => setBold.call(v) }).toElement(),
        toggle_button("Italic", isItalic).onChanged({ v: Bool => setItalic.call(v) }).toElement(),
        text_block("Style: ${styleLabel}").toElement()
    ]).spacing(8.0).toElement()
}

// ── Dispatch ──────────────────────────────────────────────────────────────────
func routeButtons(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "button" => Some(("Sample", buttonExample))
        case "button_icon" => Some(("Button Icon Sample", buttonIconExample))
        case "button_icon_dynamic" => Some(("Button Icon — Dynamic Label", buttonIconDynamicExample))
        case "button_icon_glyph_change" => Some(("Button Icon — Dynamic Glyph", buttonIconGlyphChangeExample))
        case "drop_down_button" => Some(("Sample", dropDownButtonExample))
        case "split_button" => Some(("SplitButton Sample", splitButtonExample))
        case "repeat_button" => Some(("Sample", repeatButtonExample))
        case "hyperlink_button" => Some(("Sample", hyperlinkButtonExample))
        case "toggle_button" => Some(("Sample", toggleButtonExample))
        case _ => None
    }
}

func namesButtons(): Array<String> {
    [
        "button",
        "button_icon",
        "button_icon_dynamic",
        "button_icon_glyph_change",
        "drop_down_button",
        "split_button",
        "repeat_button",
        "hyperlink_button",
        "toggle_button"
    ]
}
