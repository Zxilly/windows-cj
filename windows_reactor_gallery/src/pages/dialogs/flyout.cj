package windows_reactor_gallery.pages.dialogs

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let flyoutPageToken = newComponentTypeToken()

// ── Flyout ───────────────────────────────────────────────────────────────────
// Each button attaches a lightweight Flyout that pops on click, carrying the
// contextual message. The Confirmation card's click-to-act state is preserved.
func flyoutPage(cx: RenderCx): Element {
    let (deleted, setDeleted) = cx.useState<Bool>(false)

    let confirmationCard = sample_card(
        "Confirmation Flyout",
        vstack([
            button("Delete item")
                .withIcon(SymbolGlyph.Delete)
                .flyout("Are you sure? This cannot be undone.")
                .onClick({ => setDeleted.call(true) })
                .toElement(),
            text_block(if (deleted) { "Item deleted!" } else { "No action taken" })
                .opacity(0.6)
                .toElement()
        ]).spacing(8.0).toElement(),
        "button(\"Delete\").flyout(\"Are you sure?\").on_click(|| set.call(true))"
    )

    let withFlyoutCard = sample_card(
        "Button with Flyout",
        button("Click for flyout").flyout("This is a flyout!").toElement(),
        "button(\"Click\").flyout(\"This is a flyout!\")"
    )

    let multipleCard = sample_card(
        "Multiple Flyout Buttons",
        hstack([
            button("Help").flyout("Press F1 for more help.").toElement(),
            button("Info")
                .withIcon(SymbolGlyph.Flag)
                .flyout("This operation cannot be undone.")
                .toElement()
        ]).spacing(8.0).toElement(),
        "button(\"Help\").flyout(\"message\"), button(\"Info\").flyout(\"...\")"
    )

    page_content(
        "Flyout",
        "A lightweight popup for contextual information.",
        [confirmationCard, withFlyoutCard, multipleCard]
    )
}
