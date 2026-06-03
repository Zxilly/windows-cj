package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// ToggleButton
// ============================================================================
let toggleButtonPageToken = newComponentTypeToken()

func toggleButtonPage(cx: RenderCx): Element {
    let (bold, setBold) = cx.useState<Bool>(false)
    let (italic, setItalic) = cx.useState<Bool>(false)

    let boldLabel = if (bold) { "ON" } else { "OFF" }
    let italicLabel = if (italic) { "ON" } else { "OFF" }

    page_content(
        "ToggleButton",
        "A button that toggles between two states.",
        [
            sample_card(
                "Text Formatting Toggles",
                vstack([
                    hstack([
                        toggle_button("Bold", bold).onChanged({ v: Bool => setBold.call(v) }).toElement(),
                        toggle_button("Italic", italic).onChanged({ v: Bool => setItalic.call(v) }).toElement()
                    ]).spacing(8.0).toElement(),
                    text_block("Bold: ${boldLabel}, Italic: ${italicLabel}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "toggle_button(\"Bold\", toggled).onChanged(handler)"
            ),
            sample_card(
                "Disabled ToggleButton",
                toggle_button("Locked", true).enabled(false).toElement(),
                "toggle_button(\"Locked\", true).enabled(false)"
            )
        ]
    )
}
