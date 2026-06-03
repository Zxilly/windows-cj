package windows_reactor_gallery.pages.text

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let richEditBoxPageToken = newComponentTypeToken()

// ── RichEditBox ──────────────────────────────────────────────────────────────
// Editable rich-text field; the status line reflects the live character count.
func richEditBoxPage(cx: RenderCx): Element {
    let (editorText, setEditorText) = cx.useState<String>("")

    let status = if (editorText.isEmpty()) {
        "No changes yet"
    } else {
        "Modified \u{2022} ${charCount(editorText)} characters"
    }

    let demo = vstack([
        rich_edit_box(editorText)
            .header("Document")
            .placeholderOf("Start typing...")
            .onChanged({ text: String => setEditorText.call(text) })
            .height(200.0)
            .toElement(),
        text_block(status).opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    page_content(
        "RichEditBox",
        "A rich text editing control with formatting support.",
        [
            sample_card(
                "Basic RichEditBox",
                demo,
                "rich_edit_box(editorText)\n" +
                "    .header(\"Document\")\n" +
                "    .placeholderOf(\"Start typing...\")\n" +
                "    .onChanged({ text => setEditorText.call(text) })"
            )
        ]
    )
}

// Unicode scalar count (UTF-8 aware) matching the reference's character count.
func charCount(value: String): Int64 {
    var count = 0
    for (byte in value.toArray()) {
        // Count a code point for every byte that is not a UTF-8 continuation
        // byte (0b10xxxxxx).
        if ((byte & 0xC0u8) != 0x80u8) {
            count++
        }
    }
    count
}
