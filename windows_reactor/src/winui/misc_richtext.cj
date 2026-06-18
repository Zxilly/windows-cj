package windows_reactor.winui

import windows_reactor.core.{RichTextParagraph, RichTextRun, RichTextHyperlink}
import windows_core.HString
import windows_reactor.bindings.Microsoft.UI.Xaml.Documents.{
    Paragraph as XamlParagraph,
    Run as XamlRun,
    Inline as XamlInline,
    Block as XamlBlock,
    TextElement as XamlTextElement,
    InlineCollection
}
import windows_reactor.bindings.UI.Text.{FontWeight as Windows_UI_Text_FontWeight}

// ============================================================================
// RichTextBlock paragraph family — free-function implementation.
//
// priority: P6-critical. RichTextBlock content is built from the structured
// paragraph/inline model rather than a plain Text prop, and is exercised by the
// text gallery samples.
//
// Ported faithfully from the reference set_rich_text_paragraphs:
//   RichTextBlock.Blocks is an IVector<Block>; clear it, then for each paragraph
//   build a Paragraph, populate its Inlines (an IVector<Inline>) with Run
//   elements, and append the Paragraph (viewed as a Block) to Blocks.
//
// Projection ABI (verified against windows_sys):
//   - RichTextBlock.Blocks: get-only prop returning an owned BlockCollection
//     (an IVector<Block>); .Clear() / .Append(Block) mutate it.
//   - Paragraph.new() (default-activatable) → Paragraph; .Inlines() returns an
//     owned InlineCollection (an IVector<Inline>); .Append(Inline) mutates it.
//   - Run.new() (default-activatable) → Run; .SetText(HString) sets the text.
//   - Bold: QI the Run to the TextElement projection (ITextElement surface) and
//     SetFontWeight({ Weight: 700 }) — mirrors the reference cast to ITextElement.
//   - Run derives from Inline (IRun : IInline), and Paragraph derives from Block
//     (IParagraph : IBlock); the same COM identity is viewed as the base type via
//     Inline.viewOf / Block.viewOf for the Append calls (Append AddRefs through
//     the borrowed raw, so the non-owning views stay valid until close()).
//
// Reactor model nuances preserved from the reference: only `isBold` maps to a
// visual effect (FontWeight 700). The reactor RichTextRun additionally carries
// isItalic / isStrikethrough / fontFamily / fontSize, but the reference applies
// none of them, so they are intentionally not projected here (see report).
// LineBreak renders as a Run carrying a newline; Hyperlink renders as a plain
// Run carrying its display text (no navigation), exactly as the reference does.
// ============================================================================

// Rebuild the RichTextBlock.Blocks collection from the paragraph model.
func richTextApply(handle: Handle, paragraphs: Array<RichTextParagraph>): Unit {
    let rtb = match (handle) {
        case RichTextBlockH(v) => v
        case _ => return
    }
    let blocks = rtb.Blocks
    try {
        blocks.Clear()
        for (paraDef in paragraphs) {
            let para = XamlParagraph.new()
            try {
                let inlines = para.Inlines()
                try {
                    for (inline in paraDef.inlines) {
                        match (inline) {
                            case Run(r) => richTextAppendRun(inlines, r)
                            case LineBreak => richTextAppendText(inlines, "\n", false)
                            case Hyperlink(h) => richTextAppendHyperlink(inlines, h)
                        }
                    }
                } finally {
                    inlines.close()
                }
                // Append the paragraph (viewed as its Block base) to Blocks.
                blocks.Append(XamlBlock.viewOf(para.asRaw()))
            } finally {
                para.close()
            }
        }
    } finally {
        blocks.close()
    }
}

// ── private helpers ─────────────────────────────────────────────────────────

// Build a Run for a styled RichTextRun and append it to the inline collection.
// Mirrors the reference Run arm: put_Text, then (when bold) FontWeight 700 via
// the ITextElement surface.
func richTextAppendRun(inlines: InlineCollection, r: RichTextRun): Unit {
    richTextAppendText(inlines, r.text, r.isBold)
}

// Build a Run carrying `text`, optionally bold, and append it to `inlines`
// (viewed as its Inline base). Shared by the Run / LineBreak / Hyperlink arms.
func richTextAppendText(inlines: InlineCollection, text: String, bold: Bool): Unit {
    let run = XamlRun.new()
    try {
        let hs = HString(text)
        try {
            run.SetText(hs)
        } finally {
            hs.close()
        }
        if (bold) {
            let te = XamlTextElement.fromAbiTake(
                queryRequired(run.asRaw(), XamlTextElement.iid(),
                    "Microsoft.UI.Xaml.Documents.ITextElement")
            )
            try {
                // Bold == FontWeight { Weight: 700 } (matches the reference).
                var fw = Windows_UI_Text_FontWeight()
                fw.Weight = 700u16
                te.SetFontWeight(fw)
            } finally {
                te.close()
            }
        }
        inlines.Append(XamlInline.viewOf(run.asRaw()))
    } finally {
        run.close()
    }
}

// Hyperlink rendered as a plain (non-bold) text Run — no navigation support,
// matching the reference Hyperlink arm.
func richTextAppendHyperlink(inlines: InlineCollection, h: RichTextHyperlink): Unit {
    richTextAppendText(inlines, h.text, false)
}
