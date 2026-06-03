package windows_reactor_gallery.pages.media

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let imagePageToken = newComponentTypeToken()

// ── Image ────────────────────────────────────────────────────────────────────
//
// Demonstrates the four Stretch modes. A row of buttons sets the active stretch
// index in state; the previewed image (and the "Current:" label) re-render to
// match. The image source is a remote URI rendered inside a thin bordered box.
func imagePage(cx: RenderCx): Element {
    let (stretchIdx, setStretch) = cx.useState<Int64>(0)

    let stretch = match (stretchIdx) {
        case 1 => ImageStretch.UniformToFill
        case 2 => ImageStretch.Fill
        case 3 => ImageStretch.NoneStretch
        case _ => ImageStretch.Uniform
    }
    let stretchName = match (stretchIdx) {
        case 1 => "UniformToFill"
        case 2 => "Fill"
        case 3 => "None"
        case _ => "Uniform"
    }

    // The preview box AR (300x220 ≈ 1.36:1) is INTENTIONALLY different from the
    // source image AR (400x200 = 2:1). When the box and source share the same AR,
    // Uniform / UniformToFill / Fill produce pixel-identical results; a mismatched
    // box makes the modes visibly distinguishable — Uniform letterboxes,
    // UniformToFill crops, Fill distorts. This is a demo-only divergence; the
    // Stretch mapping itself is unchanged.
    let preview = border(
        image("https://picsum.photos/id/237/400/200")
            .stretchOf(stretch)
            .width(300.0)
            .height(220.0)
            .toElement()
    )
        .borderBrush(BrushBinding.ofColor(Color.rgb(200u8, 200u8, 200u8)))
        .borderThickness(Thickness.uniform(1.0))
        .toElement()

    let buttons = hstack([
        button("Uniform").onClick({ => setStretch.call(0) }).toElement(),
        button("UniformToFill").onClick({ => setStretch.call(1) }).toElement(),
        button("Fill").onClick({ => setStretch.call(2) }).toElement(),
        button("None").onClick({ => setStretch.call(3) }).toElement()
    ])
        .spacing(4.0)
        .toElement()

    let body = vstack([
        preview,
        buttons,
        text_block("Current: ${stretchName}").opacity(0.6).toElement()
    ])
        .spacing(8.0)
        .toElement()

    page_content(
        "Image",
        "Displays an image from a file or URI.",
        [sample_card(
            "Stretch Modes",
            body,
            #"image(uri).stretchOf(ImageStretch.Uniform).width(300.0).height(220.0)"#
        )]
    )
}
