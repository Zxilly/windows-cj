package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Canvas attached-prop helper ────────────────────────────────────────────────
//
// Canvas.Left/Top is an attached property stored on the child's shared Modifiers.
// The widget builders don't expose it directly, so (like controls.cj's atGridRow)
// we mutate the lowered element's Modifiers in place. Returns the same Element for
// fluent chaining inside a children array.

func withCanvasPos(el: Element, left: Float64, top: Float64): Element {
    match (el.modifiers()) {
        case Some(m) => m.canvasPosition = Some(CanvasPosition(left, top, 0))
        case None => ()
    }
    el
}

// ── Canvas ───────────────────────────────────────────────────────────────────

let canvasPageToken = newComponentTypeToken()

func canvasPage(cx: RenderCx): Element {
    let (x, setX) = cx.useState<Float64>(100.0)
    let (y, setY) = cx.useState<Float64>(80.0)

    let children: Array<Element> = [
        withCanvasPos(text_block("Fixed").toElement(), 10.0, 10.0),
        withCanvasPos(
            border(text_block("Move me!").toElement())
                .backgroundTheme(ThemeRef.CardBackground)
                .padding(Thickness.uniform(8.0))
                .cornerRadius(4.0)
                .toElement(),
            x, y
        )
    ]

    page_content(
        "Canvas",
        "Absolute positioning of child elements.",
        [
            sample_card(
                "Draggable Position",
                vstack([
                    canvas(children).width(320.0).height(200.0).toElement(),
                    slider(x)
                        .range(0.0, 250.0)
                        .header("X position")
                        .onChanged({ v: Float64 => setX.call(v) })
                        .toElement(),
                    slider(y)
                        .range(0.0, 160.0)
                        .header("Y position")
                        .onChanged({ v: Float64 => setY.call(v) })
                        .toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "canvas([el (canvasLeft=x, canvasTop=y)]) // x, y from sliders"
            )
        ]
    )
}
