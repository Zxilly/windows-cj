package windows_reactor_minimal

import std.collection.*
import windows_reactor.core.*

// ============================================================================
// Group: text_edit
//
// Examples owned by this group (filled into routeTextEdit):
//   text_box, password_box, rich_edit_box, rich_text, auto_suggest_box,
//   tooltip, tooltip_placement, tooltip_rich
//
// Contract (see main.cj):
//   routeTextEdit(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesTextEdit()     -> the example names this group owns, for the banner.
//
// Each example below is the `app` body of the standalone reference sample,
// expressed as `func <name>Example(cx: RenderCx): Element`. main() wraps the
// returned (title, body) with App.new().title(title).render(body).
// ============================================================================

// ── text_box ────────────────────────────────────────────────────────────────
// A bound display-name field, a live greeting, a multiline notes field, and a
// disabled read-only box.
func textBoxExample(cx: RenderCx): Element {
    let (name, setName) = cx.useState<String>("")
    let (notes, setNotes) = cx.useState<String>("")

    let greetee = if (name.isEmpty()) { "stranger" } else { name }

    vstack([
        text_box(name)
            .header("Display name")
            .placeholder("Type your name\u{2026}")
            .onChanged({ v: String => setName.call(v) })
            .toElement(),
        text_block("Hello, ${greetee}!").toElement(),
        text_box(notes)
            .header("Notes")
            .placeholder("Write something longer\u{2026}")
            .multiline()
            .height(100.0)
            .onChanged({ v: String => setNotes.call(v) })
            .toElement(),
        text_box("read-only").header("Disabled").enabled(false).toElement()
    ]).spacing(8.0).toElement()
}

// ── password_box ──────────────────────────────────────────────────────────────
// A bound password field reporting its captured length, a no-reveal variant,
// and a disabled box. Width-capped column.
func passwordBoxExample(cx: RenderCx): Element {
    let (password, setPassword) = cx.useState<String>("")

    vstack([
        password_box()
            .valueOf(password)
            .header("Password")
            .placeholder("Type a password\u{2026}")
            .onChanged({ v: String => setPassword.call(v) })
            .toElement(),
        text_block("captured length = ${charCount(password)}").toElement(),
        password_box()
            .header("No reveal button")
            .placeholder("Reveal hidden")
            .revealModeOf(PasswordRevealMode.Hidden)
            .toElement(),
        password_box().header("Disabled").enabled(false).toElement()
    ]).spacing(8.0).maxWidth(320.0).toElement()
}

// ── rich_edit_box ─────────────────────────────────────────────────────────────
// An editable rich-text field whose plain-text content is mirrored in a status
// line, plus a read-only field.
func richEditBoxExample(cx: RenderCx): Element {
    let (text, setText) = cx.useState<String>("")

    vstack([
        rich_edit_box("")
            .header("Rich Editor")
            .placeholderOf("Type rich text here\u{2026}")
            .onChanged({ v: String => setText.call(v) })
            .height(200.0)
            .toElement(),
        text_block("Plain text: ${text}").toElement(),
        rich_edit_box("Read-only content.")
            .header("Read Only")
            .readOnly()
            .height(100.0)
            .toElement()
    ]).spacing(8.0).toElement()
}

// ── rich_text ─────────────────────────────────────────────────────────────────
// A single paragraph mixing plain/bold/italic runs, a hyperlink, and a soft
// line break, plus a structured multi-paragraph block.
func richTextExample(cx: RenderCx): Element {
    let _ = cx
    let mixed = RichTextBlock.singleParagraph([
        RichTextInline.Run(RichTextRun.plain("Plain, ")),
        RichTextInline.Run(RichTextRun("bold", true, false, false, None, None)),
        RichTextInline.Run(RichTextRun.plain(", ")),
        RichTextInline.Run(RichTextRun("italic", false, true, false, None, None)),
        RichTextInline.Run(RichTextRun.plain(", and a ")),
        RichTextInline.Hyperlink(RichTextHyperlink("link", "https://github.com/microsoft/windows-rs")),
        RichTextInline.Run(RichTextRun.plain(" all in one paragraph.")),
        // Soft break — same paragraph, new visual line.
        RichTextInline.LineBreak,
        RichTextInline.Run(RichTextRun.plain(
            "This continuation lives in the same paragraph but on a new visual line."))
    ]).fontSize(14.0).selectable().wrap()

    let multi = RichTextBlock()
    multi.paragraphs = [
        RichTextParagraph([RichTextInline.Run(RichTextRun.plain("First paragraph."))]),
        RichTextParagraph([RichTextInline.Run(RichTextRun.plain("Second paragraph."))])
    ]

    vstack([
        text_block("Single paragraph with mixed inlines:").toElement(),
        mixed.toElement(),
        text_block("Multi-paragraph block:").toElement(),
        multi.toElement()
    ]).spacing(8.0).toElement()
}

// ── auto_suggest_box ──────────────────────────────────────────────────────────
// Filters a fixed fruit list against the current query and reports the chosen
// suggestion.
let AUTO_SUGGEST_FRUITS: Array<String> = [
    "Apple", "Apricot", "Banana", "Blueberry", "Cherry", "Grape", "Lemon",
    "Mango", "Orange", "Peach", "Pear", "Pineapple", "Strawberry", "Watermelon"
]

func autoSuggestBoxExample(cx: RenderCx): Element {
    let (query, setQuery) = cx.useState<String>("")
    let (chosen, setChosen) = cx.useState<String>("")

    // Filter suggestions based on current text.
    let suggestions = ArrayList<String>()
    if (!query.isEmpty()) {
        let needle = lowerAscii(query)
        for (fruit in AUTO_SUGGEST_FRUITS) {
            if (lowerAscii(fruit).contains(needle)) {
                suggestions.add(fruit)
            }
        }
    }

    let status = if (chosen.isEmpty()) { "No selection" } else { "Chosen: ${chosen}" }

    vstack([
        auto_suggest_box(query)
            .itemsOf(suggestions)
            .placeholderOf("Search fruits\u{2026}")
            .onTextChanged({ v: String => setQuery.call(v) })
            .onSuggestionChosen({ v: String => setChosen.call(v) })
            .toElement(),
        text_block(status).toElement()
    ]).spacing(12.0).toElement()
}

// ── tooltip ───────────────────────────────────────────────────────────────────
// A button and a text block each carry a plain-text tooltip.
func tooltipExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        button("Hover me").tooltip("This is a tooltip").toElement(),
        text_block("Plain text also tips").tooltip("Even on TextBlock").toElement()
    ]).spacing(12.0).toElement()
}

// ── tooltip_placement ─────────────────────────────────────────────────────────
// Five buttons, one per tooltip placement. The framework exposes no
// `tooltipWith` builder, so the placed Tooltip is attached via the public
// `mods.tooltip` slot — behaviourally equivalent to the reference's
// `.tooltip_with(Tooltip::text(..).placement(..))`.
func tooltipPlacementExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        placedButton("Top", "Anchored above", TooltipPlacement.Top),
        placedButton("Bottom", "Anchored below", TooltipPlacement.Bottom),
        placedButton("Left", "Anchored to the left", TooltipPlacement.Left),
        placedButton("Right", "Anchored to the right", TooltipPlacement.Right),
        placedButton("Mouse", "Follows the cursor", TooltipPlacement.Mouse)
    ]).spacing(8.0).toElement()
}

// Build a button carrying a placement-qualified text tooltip.
func placedButton(label: String, tip: String, placement: TooltipPlacement): Element {
    let b = button(label)
    b.mods.tooltip = Some(Tooltip.text(tip).withPlacement(placement))
    b.toElement()
}

// ── tooltip_rich ──────────────────────────────────────────────────────────────
// A button with a templated (element) tooltip and a button with a plain one.
// The rich tooltip is attached via the public `mods.tooltip` slot, matching the
// reference's `.tooltip_with(Tooltip::rich(panel))`.
func tooltipRichExample(cx: RenderCx): Element {
    let _ = cx
    let richPanel = vstack([
        text_block("Action: Save").bold().toElement(),
        text_block("Writes the current document to disk.").toElement()
    ]).spacing(4.0).toElement()

    let save = button("Save")
    save.mods.tooltip = Some(Tooltip.rich(richPanel))

    vstack([
        save.toElement(),
        button("Open").tooltip("Opens a document").toElement()
    ]).spacing(8.0).toElement()
}

// ── Local helpers ─────────────────────────────────────────────────────────────

// ASCII lowercase fold (case-insensitive comparison for the suggestion filter).
func lowerAscii(value: String): String {
    var out = ""
    for (byte in value.toArray()) {
        if (byte >= b'A' && byte <= b'Z') {
            out += String.fromUtf8([byte + 32u8])
        } else {
            out += String.fromUtf8([byte])
        }
    }
    out
}

// Unicode scalar count (UTF-8 aware): one count per non-continuation byte.
func charCount(value: String): Int64 {
    var count = 0
    for (byte in value.toArray()) {
        if ((byte & 0xC0u8) != 0x80u8) {
            count++
        }
    }
    count
}

func routeTextEdit(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "text_box" => Some(("Sample", textBoxExample))
        case "password_box" => Some(("Sample", passwordBoxExample))
        case "rich_edit_box" => Some(("Sample", richEditBoxExample))
        case "rich_text" => Some(("Sample", richTextExample))
        case "auto_suggest_box" => Some(("AutoSuggestBox Sample", autoSuggestBoxExample))
        case "tooltip" => Some(("tooltip sample", tooltipExample))
        case "tooltip_placement" => Some(("tooltip_placement sample", tooltipPlacementExample))
        case "tooltip_rich" => Some(("tooltip_rich sample", tooltipRichExample))
        case _ => None
    }
}

func namesTextEdit(): Array<String> {
    ["text_box", "password_box", "rich_edit_box", "rich_text", "auto_suggest_box",
     "tooltip", "tooltip_placement", "tooltip_rich"]
}
