package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Expander ───────────────────────────────────────────────────────────────────

let expanderPageToken = newComponentTypeToken()

func expanderPage(cx: RenderCx): Element {
    let (isExpanded, setExpanded) = cx.useState<Bool>(true)

    let stateText = if (isExpanded) { "expanded" } else { "collapsed" }

    page_content(
        "Expander",
        "Expands and collapses to show or hide content.",
        [
            sample_card(
                "Controlled Expander",
                vstack([
                    expander(
                        vstack([
                            text_block("This content can be shown or hidden.").toElement(),
                            text_block("It supports any child element.").opacity(0.6).toElement()
                        ])
                            .spacing(4.0)
                            .toElement()
                    )
                        .header("Click to expand/collapse")
                        .expanded(isExpanded)
                        .onExpanded({ v: Bool => setExpanded.call(v) })
                        .toElement(),
                    text_block("State: ${stateText}").opacity(0.6).toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "expander(content).header(\"...\").expanded(state).onExpanded(handler)"
            ),
            sample_card(
                "Collapsed by Default",
                expander(text_block("Hidden by default — click header to reveal.").toElement())
                    .header("More info")
                    .expanded(false)
                    .toElement(),
                "expander(content).header(\"More info\").expanded(false)"
            )
        ]
    )
}
