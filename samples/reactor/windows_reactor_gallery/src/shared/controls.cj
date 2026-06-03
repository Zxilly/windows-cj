package windows_reactor_gallery.shared

import std.collection.*
import std.fs.{exists, canonicalize}
import std.env.getCommand
import windows_reactor.core.*

// ============================================================================
// Reusable UI building blocks for gallery pages: the CardItem record and the
// card_grid tile grid that drives navigation when a tile is selected.
// ============================================================================

// Data for a single tile in a card_grid.
public class CardItem {
    public let title: String
    public let subtitle: String
    public let imageFile: String
    public let key: String

    public init(title: String, subtitle: String, imageFile: String, key: String) {
        this.title = title
        this.subtitle = subtitle
        this.imageFile = imageFile
        this.key = key
    }
}

// Resolve an asset file name to a file:/// URI, trying the asset locations the
// gallery may run from. Empty string if the file is missing (the tile then
// shows no image).
//
// The reference anchors assets to a compile-time absolute path
// (CARGO_MANIFEST_DIR/assets), so they resolve regardless of the working
// directory. Cangjie has no compile-time const path, so we instead anchor the
// HIGHEST-PRIORITY candidate to the running executable's own directory:
// `<exeDir>\assets\<file>`. The deployed/self-contained layout places the exe
// and its `assets/` folder side by side (and the UI-stack re-exec launches the
// child with the absolute exe path, so `getCommand()` reports it), making this
// candidate working-directory-independent. The original CWD-relative candidates
// are kept as lower-priority fallbacks so `cjpm run` from the package root still
// works during development.
func assetUri(file: String): String {
    if (file.isEmpty()) {
        return ""
    }
    let candidates = ArrayList<String>()
    let exeDir = executableDirectory()
    if (!exeDir.isEmpty()) {
        candidates.add(exeDir + "\\assets\\" + file)
    }
    candidates.add("assets\\" + file)
    candidates.add("windows_reactor_gallery\\assets\\" + file)
    candidates.add("..\\windows_reactor_gallery\\assets\\" + file)
    for (path in candidates) {
        if (exists(path)) {
            return pathToFileUri(canonicalize(path).toString())
        }
    }
    ""
}

// Directory of the running executable, or "" if it cannot be determined.
//
// `getCommand()` returns the process command (argv[0]); when the gallery runs
// deployed it is the absolute exe path, so its parent directory is the folder
// the exe was deployed into. Separators are single-byte ASCII ('\\' or '/'),
// which cannot occur inside a multi-byte UTF-8 sequence, so a byte scan for the
// last separator is correct. Returns "" when the command has no directory
// component or cannot be read, leaving the relative fallbacks to handle it.
func executableDirectory(): String {
    var command = ""
    try {
        command = getCommand()
    } catch (_: Exception) {
        return ""
    }
    let bytes = command.toArray()
    var lastSeparator = -1
    var index = 0
    while (index < bytes.size) {
        if (bytes[index] == b'\\' || bytes[index] == b'/') {
            lastSeparator = index
        }
        index += 1
    }
    if (lastSeparator <= 0) {
        return ""
    }
    command[0..lastSeparator]
}

func pathToFileUri(path: String): String {
    var out = "file:///"
    for (byte in path.toArray()) {
        if (byte == b'\\') {
            out += "/"
        } else {
            out += String.fromUtf8([byte])
        }
    }
    out
}

// Render a virtualized grid of icon + text tiles, one per CardItem. `onNavigate`
// receives the `key` of the tapped tile.
public func card_grid(items: ArrayList<CardItem>, onNavigate: (String) -> Unit): Element {
    let itemsArr = items.toArray()
    let itemsForHandler = itemsArr

    gridView<CardItem>(itemsArr, { item: CardItem, _idx: Int64 =>
        // Match the reference: the Image widget skips its source binding when the
        // file is missing (empty uri), rendering an empty 32x32 placeholder — no
        // synthetic initial-letter badge.
        let imageUri = assetUri(item.imageFile)
        let leading: Element = image(imageUri)
            .width(32.0)
            .height(32.0)
            .hAlign(HorizontalAlignment.Left)
            .vAlign(VerticalAlignment.Top)
            .toElement()
        border(
            hstack([
                leading,
                vstack([
                    text_block(item.title).fontSize(14.0).semibold().toElement(),
                    text_block(item.subtitle).opacity(0.6).toElement()
                ]).spacing(4.0).toElement()
            ]).spacing(12.0).toElement()
        )
            .backgroundTheme(ThemeRef.CardBackground)
            .borderBrush(BrushBinding.ofColor(Color(15u8, 0u8, 0u8, 0u8)))
            .borderThickness(Thickness.uniform(1.0))
            .padding(Thickness.uniform(16.0))
            .cornerRadius(8.0)
            .width(300.0)
            .height(80.0)
            .toElement()
    })
        .selectionMode(SelectionMode.Single)
        .onSelectionChanged({ idx: Int32 =>
            if (idx >= 0 && Int64(idx) < itemsForHandler.size) {
                onNavigate(itemsForHandler[Int64(idx)].key)
            }
        })
        .withKeySelector({ item: CardItem => item.key })
        .build()
}

// Place an already-lowered Element at a grid row by mutating its shared
// Modifiers (Element is an enum; widgets carry a live Modifiers reference, so
// this is the lowered-element equivalent of a .gridRow(..) builder call).
public func atGridRow(el: Element, row: Int32): Element {
    match (el.modifiers()) {
        case Some(m) =>
            let prev = match (m.grid) { case Some(g) => g; case None => GridPlacement.default() }
            m.grid = Some(GridPlacement(row, prev.column, prev.rowSpan, prev.columnSpan))
        case None => ()
    }
    el
}

// ============================================================================
// Page-building helpers shared by every category page. page_header /
// sample_card / page_content compose the title + description + bordered sample
// cards layout each control sample page renders. pageComponent wraps a page
// body so each page gets an independent hook scope.
// ============================================================================

// Renders a page header with title and description (a bold 28pt title above a
// secondary-text description). Bottom margins separate it from the cards below.
public func page_header(title: String, description: String): Element {
    vstack([
        text_block(title).fontSize(28.0).bold().toElement(),
        text_block(description)
            .foregroundTheme(ThemeRef.SecondaryText)
            .hAlign(HorizontalAlignment.Left)
            .maxWidth(800.0)
            .margin(Thickness(0.0, 0.0, 0.0, 12.0))
            .toElement()
    ])
        .spacing(4.0)
        .margin(Thickness(0.0, 0.0, 0.0, 8.0))
        .toElement()
}

// Renders a sample card: a title above a bordered card. The card stacks the
// sample area (a rounded, padded, solid-background border around the live
// sample) on top of a "Source code" expander showing the source text.
public func sample_card(title: String, sample: Element, source: String): Element {
    let sampleArea = border(sample)
        .cornerRadius(8.0)
        .padding(Thickness.uniform(24.0))
        .backgroundTheme(ThemeRef.SolidBackground)
        .toElement()

    let sourceArea = expander(text_block(source).fontSize(13.0).toElement())
        .header("Source code")
        .hAlign(HorizontalAlignment.Stretch)
        .fontFamily("Consolas")
        .toElement()

    let inner = vstack([sampleArea, sourceArea]).spacing(0.0).toElement()
    let card = border(inner)
        .cornerRadius(8.0)
        .borderBrush(BrushBinding.ofTheme(ThemeRef.CardStroke))
        .borderThickness(Thickness.uniform(1.0))
        .backgroundTheme(ThemeRef.CardBackground)
        .toElement()

    vstack([
        text_block(title).fontSize(14.0).bold().margin(Thickness(0.0, 0.0, 0.0, 12.0)).toElement(),
        card
    ])
        .spacing(0.0)
        .toElement()
}

// Wraps page content in a scroll view with a header followed by the sample
// cards. The vstack stacks the header above all cards with 16pt spacing and the
// standard page margin (36 left/right, 24 top, 36 bottom).
public func page_content(title: String, description: String, cards: Array<Element>): Element {
    let items = ArrayList<Element>()
    items.add(page_header(title, description))
    for (c in cards) {
        items.add(c)
    }
    let content = vstack(items.toArray())
        .spacing(16.0)
        .margin(Thickness(36.0, 24.0, 36.0, 36.0))
        .hAlign(HorizontalAlignment.Stretch)
        .toElement()
    scroll_view(content).toElement()
}

// ── Page-component wrapping contract ─────────────────────────────────────────
//
// A page body `(RenderCx) -> Element` is wrapped into a child component so that
// each page owns an INDEPENDENT HOOK SCOPE. The reconciler drives each mounted
// ComponentObject with its own hook state, so a page's `cx.useState(..)` slots
// belong to that page alone and are preserved across re-renders (and discarded
// when the page unmounts) — exactly the per-page state isolation a category
// page needs.
//
// Mechanism: `component<NoProps>(body, NoProps(), token)` builds a
// ComponentElement carrying a ComponentCell<NoProps>. Unit props (NoProps) mean
// the wrapper never needlessly re-renders on prop change. The `token` is the
// per-type identity the reconciler uses for mount-vs-update: a page MUST mint
// ONE stable token (via newComponentTypeToken(), called once at module scope)
// and reuse it on every route call, so navigating away and back re-mounts the
// SAME component type rather than churning identity. Because each distinct page
// fn mints its own token, distinct pages are distinct component types with
// distinct hook scopes.
//
// `pageComponent` is the convenience each category page uses:
//     let buttonPageToken = newComponentTypeToken()   // once, module scope
//     func button_page(): Element {
//         pageComponent(buttonPageToken, { cx => ...page body... })
//     }
public func pageComponent(token: UInt64, body: (RenderCx) -> Element): Element {
    component<NoProps>({ _: NoProps, cx: RenderCx => body(cx) }, NoProps(), token)
}
