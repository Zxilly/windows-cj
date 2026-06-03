package windows_reactor_gallery.pages.layout

import std.collection.*
import std.math.round
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Viewbox ──────────────────────────────────────────────────────────────────

let viewboxPageToken = newComponentTypeToken()

func viewboxPage(cx: RenderCx): Element {
    let (contentSize, setContentSize) = cx.useState<Float64>(120.0)

    let sizeLabel = Int64(round(contentSize))
    let labelFontSize = if ((contentSize / 4.0) < 12.0) { 12.0 } else { contentSize / 4.0 }

    page_content(
        "Viewbox",
        "Scales its child to fill available space.",
        [
            sample_card(
                "Resizable Content",
                vstack([
                    viewbox(
                        border(
                            text_block("${sizeLabel} px")
                                .fontSize(labelFontSize)
                                .bold()
                                .toElement()
                        )
                            .width(contentSize)
                            .height(contentSize / 2.0)
                            .padding(Thickness.uniform(12.0))
                            .cornerRadius(8.0)
                            .toElement()
                    )
                        .width(200.0)
                        .height(100.0)
                        .toElement(),
                    slider(contentSize)
                        .range(60.0, 220.0)
                        .header("Content size")
                        .onChanged({ value: Float64 => setContentSize.call(value) })
                        .toElement(),
                    text_block("The Viewbox stays fixed while its child grows or shrinks.")
                        .opacity(0.6)
                        .toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "viewbox(content).width(200.0).height(100.0) // content size comes from state"
            )
        ]
    )
}
