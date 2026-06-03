package windows_reactor_gallery.pages.collections

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let flipViewPageToken = newComponentTypeToken()

// ── FlipView ─────────────────────────────────────────────────────────────────
// Presents one item at a time with flipping navigation. Tracks the active slide
// in a state cell and echoes it below the flip view.
func flipViewPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int64>(0)
    let items: Array<String> = ["Welcome", "Features", "Getting Started", "Resources"]

    let flip = flipView<String>(items, { item: String, idx: Int64 =>
        border(
            vstack([
                text_block(item).fontSize(24.0).bold().toElement(),
                text_block("Slide ${idx + 1} of 4").opacity(0.6).toElement()
            ]).spacing(8.0).toElement()
        )
            .padding(Thickness.uniform(24.0))
            .cornerRadius(8.0)
            .toElement()
    })
        .onSelectionChanged({ idx: Int32 => setSelected.call(Int64(idx)) })
        .height(200.0)
        .build()

    let sample = vstack([
        flip,
        text_block("Current slide: ${selected + 1}").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    page_content(
        "FlipView",
        "Presents one item at a time with flipping navigation.",
        [sample_card(
            "Interactive FlipView",
            sample,
            "flip_view(items, |item, idx| ...).on_selection_changed(move |idx| set.call(idx))"
        )]
    )
}
