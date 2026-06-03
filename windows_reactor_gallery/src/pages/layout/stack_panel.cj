package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── StackPanel ───────────────────────────────────────────────────────────────

let stackPanelPageToken = newComponentTypeToken()

func stackPanelPage(cx: RenderCx): Element {
    let (itemCount, setCount) = cx.useState<Int64>(3)

    let items = ArrayList<Element>()
    var index = 1
    while (index <= itemCount) {
        items.add(text_block("Item ${index}").toElement())
        index++
    }

    page_content(
        "StackPanel",
        "Arranges children in a single horizontal or vertical line.",
        [
            sample_card(
                "Dynamic Items",
                vstack([
                    hstack([
                        button("Add")
                            .withIcon(SymbolGlyph.Add)
                            .onClick({ => setCount.call(itemCount + 1) })
                            .toElement(),
                        button("Remove")
                            .withIcon(SymbolGlyph.Delete)
                            .enabled(itemCount > 0)
                            .onClick({ =>
                                let next = itemCount - 1
                                setCount.call(if (next < 0) { 0 } else { next })
                            })
                            .toElement(),
                        text_block("${itemCount} items").opacity(0.6).toElement()
                    ])
                        .spacing(8.0)
                        .toElement(),
                    vstack(items.toArray()).spacing(4.0).toElement()
                ])
                    .spacing(12.0)
                    .toElement(),
                "vstack(items).spacing(4.0) // items generated from state"
            ),
            sample_card(
                "Vertical Stack",
                vstack([
                    text_block("Item 1").toElement(),
                    text_block("Item 2").toElement(),
                    text_block("Item 3").toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "vstack((text_block(\"1\"), text_block(\"2\"), text_block(\"3\"))).spacing(8.0)"
            ),
            sample_card(
                "Horizontal Stack",
                hstack([
                    button("A").toElement(),
                    button("B").toElement(),
                    button("C").toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "hstack((button(\"A\"), button(\"B\"), button(\"C\"))).spacing(8.0)"
            )
        ]
    )
}
