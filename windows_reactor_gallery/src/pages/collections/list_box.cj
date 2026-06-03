package windows_reactor_gallery.pages.collections

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let listBoxPageToken = newComponentTypeToken()

// ── ListBox ────────────────────────────────────────────────────────────────--
// A list of selectable items presented inline. The basic card echoes the
// selected fruit; the disabled card shows a read-only list_box.
func listBoxPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int64>(-1)

    let fruits: Array<String> = ["Apple", "Banana", "Cherry", "Date", "Elderberry"]
    let label = if (selected >= 0 && selected < fruits.size) {
        fruits[selected]
    } else {
        "(none)"
    }

    let basicItems = ArrayList<String>()
    for (f in fruits) { basicItems.add(f) }

    let basicList = list_box()
        .items(basicItems)
        .selectedIndex(Int32(selected))
        .onSelectionChanged({ idx: Int32 => setSelected.call(Int64(idx)) })
        .toElement()

    let basicSample = vstack([
        basicList,
        text_block("Selected: ${label}").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    let disabledItems = ArrayList<String>()
    for (s in ["Read", "Only", "Items"]) { disabledItems.add(s) }
    let disabledSample = list_box()
        .items(disabledItems)
        .selectedIndex(0)
        .enabled(false)
        .toElement()

    page_content(
        "ListBox",
        "A list of selectable items presented inline.",
        [
            sample_card(
                "Basic ListBox",
                basicSample,
                "list_box().items([\"Apple\", ...]).selected_index(idx).on_selection_changed(handler)"
            ),
            sample_card(
                "Disabled ListBox",
                disabledSample,
                "list_box().items(items).enabled(false)"
            )
        ]
    )
}
