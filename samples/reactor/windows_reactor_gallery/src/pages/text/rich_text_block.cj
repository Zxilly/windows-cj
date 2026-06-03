package windows_reactor_gallery.pages.text

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let richTextBlockPageToken = newComponentTypeToken()

// ── RichTextBlock ────────────────────────────────────────────────────────────
// Read-only formatted text: a font-size-bound single paragraph, a structured
// multi-paragraph block with inline styles, and a selectable wrapped block.
func richTextBlockPage(cx: RenderCx): Element {
    let (fontSize, setFontSize) = cx.useState<Float64>(14.0)

    // Basic: a single plain paragraph whose size is driven by the slider.
    let basicDemo = vstack([
        RichTextBlock.singleParagraph([
            RichTextInline.Run(RichTextRun.plain(
                "This is a simple rich text block displaying read-only content."))
        ]).fontSize(fontSize).toElement(),
        slider(fontSize)
            .range(10.0, 28.0)
            .header("Font Size")
            .onChanged({ v: Float64 => setFontSize.call(v) })
            .toElement()
    ]).spacing(12.0).toElement()

    // Structured: bold/italic inline runs across multiple paragraphs.
    let structured = RichTextBlock()
    structured.paragraphs = [
        RichTextParagraph([
            RichTextInline.Run(RichTextRun("Bold introduction. ", true, false, false, None, None)),
            RichTextInline.Run(RichTextRun.plain("Followed by normal text."))
        ]),
        RichTextParagraph([
            RichTextInline.Run(RichTextRun("Italic emphasis ", false, true, false, None, None)),
            RichTextInline.Run(RichTextRun.plain("mixed with ")),
            RichTextInline.Run(RichTextRun("bold", true, false, false, None, None)),
            RichTextInline.Run(RichTextRun.plain("."))
        ]),
        RichTextParagraph([
            RichTextInline.Run(RichTextRun.plain(
                "A third paragraph with different content to show block-level formatting."))
        ])
    ]

    // Selectable: highlightable, wrapping read-only text.
    let selectable = RichTextBlock.singleParagraph([
        RichTextInline.Run(RichTextRun.plain(
            "This text is selectable. Try highlighting it with your mouse."))
    ]).selectable().wrap().toElement()

    page_content(
        "RichTextBlock",
        "Displays formatted, read-only rich text with multiple paragraphs and inline styles.",
        [
            sample_card(
                "Basic RichTextBlock",
                basicDemo,
                "RichTextBlock.singleParagraph([\n" +
                "    RichTextInline.Run(RichTextRun.plain(\"Hello world\")),\n" +
                "]).fontSize(14.0)"
            ),
            sample_card(
                "Structured Rich Text",
                structured.toElement(),
                "let block = RichTextBlock()\n" +
                "block.paragraphs = [\n" +
                "    RichTextParagraph([\n" +
                "        RichTextInline.Run(RichTextRun(\"Bold\", true, false, false, None, None)),\n" +
                "        RichTextInline.Run(RichTextRun.plain(\"normal\")),\n" +
                "    ]),\n" +
                "]"
            ),
            sample_card(
                "Selectable Text",
                selectable,
                "RichTextBlock.singleParagraph([...])\n" +
                "    .selectable()\n" +
                "    .wrap()"
            )
        ]
    )
}
