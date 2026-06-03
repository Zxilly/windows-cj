package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let spacingPageToken = newComponentTypeToken()

// ── Spacing ───────────────────────────────────────────────────────────────────

func spacingRow(name: String, size: Float64): Element {
    let bar = border(Element.EmptyEl)
        .background(Brush.Solid(accentColor))
        .width(size)
        .height(24.0)
        .cornerRadius(4.0)
        .toElement()

    hstack([
        text_block("${name} (${intText(size)}px)")
            .width(180.0)
            .vAlign(VerticalAlignment.Center)
            .toElement(),
        bar
    ]).spacing(12.0).toElement()
}

func spacing_page(): Element {
    pageComponent(spacingPageToken, { _: RenderCx =>
        let samples = vstack([
            spacingRow("XXSmall", 2.0),
            spacingRow("XSmall", 4.0),
            spacingRow("Small", 8.0),
            spacingRow("Medium", 12.0),
            spacingRow("Large", 16.0),
            spacingRow("XLarge", 24.0),
            spacingRow("XXLarge", 32.0),
            spacingRow("XXXLarge", 48.0)
        ]).spacing(8.0).toElement()

        page_content(
            "Spacing",
            "Standard spacing values used to create consistent layouts in WinUI 3.",
            [samples]
        )
    })
}
