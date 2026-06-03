package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Border ───────────────────────────────────────────────────────────────────

let borderPageToken = newComponentTypeToken()

func borderPage(cx: RenderCx): Element {
    let (radius, setRadius) = cx.useState<Float64>(8.0)
    let (thick, setThick) = cx.useState<Bool>(false)

    let thickness = if (thick) { 4.0 } else { 1.0 }

    page_content(
        "Border",
        "A container that draws a border around its child element.",
        [
            sample_card(
                "Dynamic Border",
                vstack([
                    border(text_block("Adjustable border").toElement())
                        .borderBrush(BrushBinding.ofColor(Color.rgb(60u8, 100u8, 180u8)))
                        .borderThickness(Thickness.uniform(thickness))
                        .padding(Thickness.uniform(16.0))
                        .cornerRadius(radius)
                        .toElement(),
                    slider(radius)
                        .range(0.0, 32.0)
                        .header("Corner radius")
                        .onChanged({ value: Float64 => setRadius.call(value) })
                        .toElement(),
                    toggle_switch(thick)
                        .header("Thick border")
                        .onChanged({ value: Bool => setThick.call(value) })
                        .toElement()
                ])
                    .spacing(12.0)
                    .toElement(),
                "border(content)\n    .cornerRadius(radius)\n    .borderThickness(Thickness.uniform(thickness))"
            ),
            sample_card(
                "Basic Border",
                border(text_block("Content inside a border").toElement())
                    .padding(Thickness.uniform(16.0))
                    .cornerRadius(8.0)
                    .toElement(),
                "border(content).padding(Thickness.uniform(16.0)).cornerRadius(8.0)"
            ),
            sample_card(
                "Colored Border",
                border(text_block("Styled border").toElement())
                    .background(Brush.Solid(Color.rgb(60u8, 100u8, 180u8)))
                    .padding(Thickness.uniform(16.0))
                    .cornerRadius(4.0)
                    .toElement(),
                "border(content).background(Brush.Solid(Color.rgb(...))).cornerRadius(4.0)"
            )
        ]
    )
}
