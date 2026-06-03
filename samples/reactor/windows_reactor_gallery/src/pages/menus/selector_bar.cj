package windows_reactor_gallery.pages.menus

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── SelectorBar ──────────────────────────────────────────────────────────────
// Switch between different views or modes. The card tracks the selected tag.
func selector_bar_page(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<String>("Recent")

    let bar = selector_bar(ArrayList<SelectorBarItemDef>([
        SelectorBarItemDef("Recent"),
        SelectorBarItemDef("Shared"),
        SelectorBarItemDef("Favorites")
    ]))
        .onSelectionChanged({ tag: String => setSelected.call(tag) })

    let sample = vstack([
        bar.toElement(),
        text_block("Selected: ${selected}").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    page_content(
        "SelectorBar",
        "Switch between different views or modes.",
        [
            sample_card(
                "Basic SelectorBar",
                sample,
                #"selector_bar([SelectorBarItemDef("Recent"), ...]).onSelectionChanged(h)"#
            )
        ]
    )
}

let selectorBarPageToken = newComponentTypeToken()
