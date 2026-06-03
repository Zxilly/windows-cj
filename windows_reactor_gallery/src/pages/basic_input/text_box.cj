package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// TextBox
// ============================================================================
let textBoxPageToken = newComponentTypeToken()

func textBoxPage(cx: RenderCx): Element {
    let (text, setText) = cx.useState<String>("")
    let (multiText, setMulti) = cx.useState<String>("Hello\nWorld")

    page_content(
        "TextBox",
        "A single-line or multi-line text input field.",
        [
            sample_card(
                "Basic TextBox",
                vstack([
                    text_box(text)
                        .header("Name")
                        .placeholder("Type here...")
                        .onChanged({ s: String => setText.call(s) })
                        .toElement(),
                    text_block("Characters: ${text.size}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "text_box(text).header(\"Name\").placeholder(\"Type here...\").onChanged(handler)"
            ),
            sample_card(
                "Multi-line TextBox",
                text_box(multiText)
                    .header("Notes")
                    .multiline()
                    .onChanged({ s: String => setMulti.call(s) })
                    .height(120.0)
                    .toElement(),
                "text_box(text).header(\"Notes\").multiline()"
            ),
            sample_card(
                "Disabled TextBox",
                text_box("Read-only content")
                    .header("Status")
                    .enabled(false)
                    .toElement(),
                "text_box(\"content\").enabled(false)"
            )
        ]
    )
}
