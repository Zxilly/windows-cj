package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── SplitView ────────────────────────────────────────────────────────────────

let splitViewPageToken = newComponentTypeToken()

func splitViewPage(cx: RenderCx): Element {
    let (open, setOpen) = cx.useState<Bool>(true)

    page_content(
        "SplitView",
        "A collapsible pane and content area.",
        [
            sample_card(
                "Basic SplitView",
                vstack([
                    toggle_switch(open)
                        .header("Pane open")
                        .onChanged({ v: Bool => setOpen.call(v) })
                        .toElement(),
                    split_view(text_block("Main content area").toElement())
                        .paneOf(text_block("Pane content").toElement())
                        .paneOpen(open)
                        .toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "split_view(content).paneOf(pane).paneOpen(open)"
            )
        ]
    )
}
