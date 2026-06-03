package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── RelativePanel attached-prop helper ─────────────────────────────────────────
//
// RelativePanel alignment is an attached property stored on the child's shared
// Modifiers. The widget builders don't expose it directly, so (like controls.cj's
// atGridRow) we mutate the lowered element's Modifiers in place. Returns the same
// Element for fluent chaining inside a children array.

func withRelativeAlign(
    el: Element,
    l: Bool, r: Bool, t: Bool, b: Bool, h: Bool, v: Bool
): Element {
    match (el.modifiers()) {
        case Some(m) => m.relativeAlign = Some(RelativePanelAlignment(l, r, t, b, h, v))
        case None => ()
    }
    el
}

// ── RelativePanel ────────────────────────────────────────────────────────────

let relativePanelPageToken = newComponentTypeToken()

func relativePanelPage(cx: RenderCx): Element {
    let (showAltLayout, setShowAltLayout) = cx.useState<Bool>(false)

    let dynamicItems: Array<Element> = if (showAltLayout) {
        [
            withRelativeAlign(text_block("Bottom Left").toElement(), true, false, false, true, false, false),
            withRelativeAlign(text_block("Bottom Right").toElement(), false, true, false, true, false, false),
            withRelativeAlign(text_block("Center").toElement(), false, false, false, false, true, true)
        ]
    } else {
        [
            text_block("Top Left").toElement(),
            withRelativeAlign(text_block("Top Right").toElement(), false, true, true, false, false, false),
            withRelativeAlign(text_block("Center").toElement(), false, false, false, false, true, true)
        ]
    }

    page_content(
        "RelativePanel",
        "Positions children relative to each other.",
        [
            sample_card(
                "Switch Layouts",
                vstack([
                    toggle_switch(showAltLayout)
                        .header("Show bottom corners")
                        .onChanged({ value: Bool => setShowAltLayout.call(value) })
                        .toElement(),
                    border(relative_panel(dynamicItems).height(200.0).toElement())
                        .padding(Thickness.uniform(16.0))
                        .toElement()
                ])
                    .spacing(12.0)
                    .toElement(),
                "relative_panel(items).height(200.0) // items swap based on state"
            ),
            sample_card(
                "Basic RelativePanel",
                relative_panel([
                    text_block("Top Left").toElement(),
                    withRelativeAlign(text_block("Top Right").toElement(), false, true, true, false, false, false),
                    withRelativeAlign(text_block("Center").toElement(), false, false, false, false, true, true)
                ])
                    .height(200.0)
                    .toElement(),
                "relative_panel([el (alignRight), ...]).height(200.0)"
            )
        ]
    )
}
