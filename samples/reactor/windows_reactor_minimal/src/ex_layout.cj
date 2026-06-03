package windows_reactor_minimal

import std.collection.ArrayList
import windows_reactor.core.*

// ============================================================================
// Group: layout
//
// Examples owned by this group (filled into routeLayout):
//   border, canvas, grid, relative_panel, scroll_view, scroll_viewer,
//   split_view, expander, shape
//
// Contract (see main.cj):
//   routeLayout(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesLayout()     -> the example names this group owns, for the banner.
//
// Each example is a `func <name>Example(cx: RenderCx): Element` that returns the
// root component body, mirroring the reference `fn app(cx) -> Element`.
// ============================================================================

// ── Attached-prop helpers ────────────────────────────────────────────────────
//
// Canvas.Left/Top and RelativePanel alignment are attached properties stored on
// the child's shared Modifiers. The widget builders don't expose them directly,
// so we mutate the lowered element's Modifiers in place (the proven gallery
// idiom). Each returns the same Element for fluent chaining inside a children
// array.

func withCanvasPos(el: Element, left: Float64, top: Float64): Element {
    match (el.modifiers()) {
        case Some(m) => m.canvasPosition = Some(CanvasPosition(left, top, 0))
        case None => ()
    }
    el
}

func withRelativeAlign(
    el: Element,
    l: Bool, r: Bool, t: Bool, b: Bool, h: Bool, v: Bool
): Element {
    match (el.modifiers()) {
        case Some(m) => m.relativeAlign = Some(RelativePanelAlignment(l, r, t, b, h, v))
        case None => ()
    }
    el
}

let white = Color.rgb(255u8, 255u8, 255u8)

// ── border ───────────────────────────────────────────────────────────────────

func borderExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        border(
            text_block("Boxed text").foreground(Brush.Solid(white)).toElement()
        )
            .background(Brush.Solid(Color.rgb(60u8, 100u8, 180u8)))
            .padding(Thickness.uniform(12.0))
            .toElement(),
        border(
            text_block("Margined + width-capped")
                .bold()
                .foreground(Brush.Solid(white))
                .toElement()
        )
            .background(Brush.Solid(Color.rgb(80u8, 140u8, 90u8)))
            .padding(Thickness.xy(16.0, 8.0))
            .margin(Thickness.uniform(4.0))
            .maxWidth(280.0)
            .toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── canvas ─────────────────────────────────────────────────────────────────────
//
// The reference positions Shape rectangles/ellipses at absolute coordinates. The
// `windows_reactor.core` widget set has no Shape builder (only Border/TextBlock),
// so the colored shapes are approximated with sized, filled `border` boxes — the
// same approximation the gallery's canvas page uses. The absolute positioning
// (canvas_left / canvas_top) is faithful via withCanvasPos.

func canvasExample(cx: RenderCx): Element {
    let _ = cx

    let children: Array<Element> = [
        // Outer frame (grey outline ~= stroke rectangle).
        withCanvasPos(
            border(text_block("").toElement())
                .borderBrush(BrushBinding.ofColor(Color.rgb(128u8, 128u8, 128u8)))
                .borderThickness(Thickness.uniform(1.0))
                .width(260.0)
                .height(120.0)
                .toElement(),
            0.0, 0.0
        ),
        // Filled blue rectangle.
        withCanvasPos(
            border(text_block("").toElement())
                .background(Brush.Solid(Color.rgb(40u8, 120u8, 200u8)))
                .width(80.0)
                .height(40.0)
                .toElement(),
            20.0, 20.0
        ),
        // Filled pink "ellipse" (rounded box approximation).
        withCanvasPos(
            border(text_block("").toElement())
                .background(Brush.Solid(Color.rgb(220u8, 80u8, 120u8)))
                .cornerRadius(20.0)
                .width(40.0)
                .height(40.0)
                .toElement(),
            180.0, 40.0
        )
    ]

    canvas(children)
        .width(260.0)
        .height(120.0)
        .toElement()
}

// ── grid ─────────────────────────────────────────────────────────────────────

func gridCellBox(label: String, color: Color, row: Int32, col: Int32): Element {
    border(
        text_block(label)
            .bold()
            .foreground(Brush.Solid(white))
            .toElement()
    )
        .background(Brush.Solid(color))
        .padding(Thickness.uniform(12.0))
        .gridRow(row)
        .gridColumn(col)
        .toElement()
}

func gridExample(cx: RenderCx): Element {
    let _ = cx
    grid([
        gridCellBox("0,0", Color.rgb(60u8, 100u8, 180u8), 0, 0),
        gridCellBox("0,1", Color.rgb(80u8, 140u8, 90u8), 0, 1),
        gridCellBox("1,0", Color.rgb(180u8, 90u8, 100u8), 1, 0),
        gridCellBox("1,1", Color.rgb(140u8, 90u8, 180u8), 1, 1)
    ])
        .rowsOf([GridLength.Auto, GridLength.Auto])
        .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0)])
        .rowSpacing(6.0)
        .columnSpacing(6.0)
        .maxWidth(360.0)
        .toElement()
}

// ── relative_panel ───────────────────────────────────────────────────────────

func relativePanelExample(cx: RenderCx): Element {
    let _ = cx
    relative_panel([
        // Top-left (default position).
        text_block("Top Left").toElement(),
        // Top-right corner.
        withRelativeAlign(text_block("Top Right").toElement(), false, true, true, false, false, false),
        // Bottom-left corner.
        withRelativeAlign(text_block("Bottom Left").toElement(), true, false, false, true, false, false),
        // Bottom-right corner.
        withRelativeAlign(text_block("Bottom Right").toElement(), false, true, false, true, false, false),
        // Centered.
        withRelativeAlign(text_block("Center").toElement(), false, false, false, false, true, true)
    ])
        .width(300.0)
        .height(200.0)
        .toElement()
}

// ── scroll_view ──────────────────────────────────────────────────────────────

func scrollViewExample(cx: RenderCx): Element {
    let _ = cx

    let lines = ArrayList<Element>()
    var i = 1
    while (i <= 30) {
        lines.add(text_block("Line ${i}").fontSize(13.0).toElement())
        i++
    }
    let tallBody = vstack(lines.toArray()).spacing(4.0).toElement()

    let wideBody = text_block(
        "This line is intentionally long so the ScrollView scrolls horizontally to reveal the full content."
    )
        .fontSize(13.0)
        .toElement()

    vstack([
        text_block("Default (vertical-only, auto)").bold().toElement(),
        scroll_view(tallBody).maxHeight(120.0).toElement(),
        text_block("Both axes, always visible").bold().toElement(),
        scroll_view(wideBody)
            .horizontalScrollBarVisibilityOf(ScrollViewScrollBarVisibility.Visible)
            .verticalScrollBarVisibilityOf(ScrollViewScrollBarVisibility.Visible)
            .maxWidth(280.0)
            .maxHeight(80.0)
            .toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── scroll_viewer ──────────────────────────────────────────────────────────────

func scrollViewerExample(cx: RenderCx): Element {
    let _ = cx

    let lines = ArrayList<Element>()
    var i = 1
    while (i <= 30) {
        lines.add(text_block("Line ${i}").fontSize(13.0).toElement())
        i++
    }
    let tallBody = vstack(lines.toArray()).spacing(4.0).toElement()

    let wideBody = text_block(
        "This line is intentionally long so the ScrollViewer scrolls horizontally to reveal the full content."
    )
        .fontSize(13.0)
        .toElement()

    vstack([
        text_block("Default (vertical-only, auto)").bold().toElement(),
        scroll_viewer(tallBody).maxHeight(120.0).toElement(),
        text_block("Both axes, always visible").bold().toElement(),
        scroll_viewer(wideBody)
            .horizontalScrollBar(ScrollBarVisibility.Visible)
            .verticalScrollBar(ScrollBarVisibility.Visible)
            .maxWidth(280.0)
            .maxHeight(80.0)
            .toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── split_view ─────────────────────────────────────────────────────────────────

func splitViewExample(cx: RenderCx): Element {
    let (open, setOpen) = cx.useState<Bool>(true)

    let stateText = if (open) { "open" } else { "closed" }

    split_view(
        // Content area.
        vstack([
            text_block("Pane is ${stateText}").toElement(),
            button("Toggle Pane")
                .onClick({ => setOpen.call(!open) })
                .toElement()
        ])
            .spacing(12.0)
            .toElement()
    )
        .paneOf(
            vstack([
                text_block("Pane Content").toElement(),
                text_block("Item A").toElement(),
                text_block("Item B").toElement(),
                text_block("Item C").toElement()
            ])
                .spacing(8.0)
                .toElement()
        )
        .displayModeOf(SplitViewDisplayMode.Inline)
        .paneOpen(open)
        .openPaneLengthOf(200.0)
        .onPaneClosed({ => setOpen.call(false) })
        .toElement()
}

// ── expander ─────────────────────────────────────────────────────────────────

func expanderExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        expander(
            vstack([
                text_block("Hidden details live inside the expander.").toElement(),
                text_block("Click the chevron to collapse this panel.").opacity(0.7).toElement()
            ])
                .spacing(4.0)
                .toElement()
        )
            .header("Details")
            .expanded(true)
            .toElement(),
        expander(text_block("Collapsed by default.").toElement())
            .header("More")
            .expanded(false)
            .toElement(),
        // Complex header: an element tree instead of plain text.
        expander(text_block("Body content for the rich header expander.").toElement())
            .headerContent(
                hstack([
                    text_block("⚙").fontSize(18.0).toElement(),
                    text_block("Settings").bold().toElement()
                ])
                    .spacing(8.0)
                    .toElement()
            )
            .expanded(true)
            .toElement()
    ])
        .spacing(8.0)
        .maxWidth(400.0)
        .toElement()
}

// ── shape ──────────────────────────────────────────────────────────────────────
//
// The reference draws Rectangle / Ellipse / Line shapes (fill, stroke,
// stroke_thickness, corner_radius). `windows_reactor.core` ships no Shape widget
// builder, so each shape is approximated with a sized, filled/outlined `border`
// box. Behaviour is visually equivalent for fill + corner_radius + outline; the
// Line shape is rendered as a thin filled bar.

func shapeExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        text_block("Rectangle (fill + corner_radius)").toElement(),
        border(text_block("").toElement())
            .background(Brush.Solid(Color.rgb(40u8, 120u8, 200u8)))
            .cornerRadius(8.0)
            .width(160.0)
            .height(48.0)
            .toElement(),
        text_block("Ellipse (fill only)").toElement(),
        border(text_block("").toElement())
            .background(Brush.Solid(Color.rgb(220u8, 80u8, 120u8)))
            .cornerRadius(40.0)
            .width(80.0)
            .height(80.0)
            .toElement(),
        text_block("Line (stroke + stroke_thickness)").toElement(),
        border(text_block("").toElement())
            .background(Brush.Solid(Color.rgb(80u8, 80u8, 80u8)))
            .width(200.0)
            .height(3.0)
            .toElement(),
        text_block("Rectangle outline (stroke, no fill)").toElement(),
        border(text_block("").toElement())
            .borderBrush(BrushBinding.ofColor(Color.rgb(40u8, 120u8, 200u8)))
            .borderThickness(Thickness.uniform(2.0))
            .width(160.0)
            .height(48.0)
            .toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── Dispatch ─────────────────────────────────────────────────────────────────

func routeLayout(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "border" => Some(("Sample", borderExample))
        case "canvas" => Some(("Sample", canvasExample))
        case "grid" => Some(("Sample", gridExample))
        case "relative_panel" => Some(("Sample", relativePanelExample))
        case "scroll_view" => Some(("ScrollView Sample", scrollViewExample))
        case "scroll_viewer" => Some(("Sample", scrollViewerExample))
        case "split_view" => Some(("SplitView Sample", splitViewExample))
        case "expander" => Some(("Sample", expanderExample))
        case "shape" => Some(("Sample", shapeExample))
        case _ => None
    }
}

func namesLayout(): Array<String> {
    ["border", "canvas", "grid", "relative_panel", "scroll_view", "scroll_viewer",
     "split_view", "expander", "shape"]
}
