package windows_reactor_gallery.pages.collections

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let gridViewPageToken = newComponentTypeToken()

// ── GridView ─────────────────────────────────────────────────────────────────
// Displays items in a horizontally wrapping grid. Selection updates the label
// below; -1 means no selection.
func gridViewPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int64>(-1)
    let items = ArrayList<String>()
    var i = 1
    while (i <= 12) {
        items.add("Item ${i}")
        i++
    }
    let itemsArr = items.toArray()

    let gv = gridView<String>(itemsArr, { item: String, _idx: Int64 =>
        border(text_block(item).bold().toElement())
            .padding(Thickness.uniform(16.0))
            .cornerRadius(4.0)
            .toElement()
    })
        .onSelectionChanged({ idx: Int32 => setSelected.call(Int64(idx)) })
        .height(300.0)
        .build()

    let label = if (selected >= 0) {
        "Selected: Item ${selected + 1}"
    } else {
        "No selection"
    }

    let sample = vstack([
        gv,
        text_block(label).opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    page_content(
        "GridView",
        "Displays items in a horizontally wrapping grid.",
        [sample_card(
            "Selectable GridView",
            sample,
            "grid_view(items, |item, _| ...).on_selection_changed(move |idx| set.call(idx))"
        )]
    )
}
