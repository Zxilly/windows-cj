package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── ScrollView ───────────────────────────────────────────────────────────────

let scrollViewPageToken = newComponentTypeToken()

func scrollViewPage(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(30)

    let items = ArrayList<Element>()
    var i = 1
    while (i <= count) {
        items.add(text_block("Scrollable item ${i}").toElement())
        i++
    }

    page_content(
        "ScrollView",
        "A scrollable container for overflowing content.",
        [
            sample_card(
                "Dynamic ScrollView",
                vstack([
                    hstack([
                        button("More items")
                            .onClick({ => setCount.call(count + 10) })
                            .toElement(),
                        button("Fewer items")
                            .onClick({ =>
                                let next = count - 10
                                setCount.call(if (next < 5) { 5 } else { next })
                            })
                            .toElement(),
                        text_block("${count} items").opacity(0.6).toElement()
                    ])
                        .spacing(8.0)
                        .toElement(),
                    scroll_view(vstack(items.toArray()).spacing(4.0).toElement())
                        .height(200.0)
                        .toElement()
                ])
                    .spacing(12.0)
                    .toElement(),
                "scroll_view(vstack(items).spacing(4.0)).height(200.0)"
            )
        ]
    )
}
