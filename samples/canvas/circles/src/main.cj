package windows_canvas_circles

import std.math.{sin, cos, abs}
import windows_canvas.{DrawContext, ColorF, Ellipse, Rect, TextFormat, TextAlignment, FontWeight, animatedCanvas}
import windows_numerics.vector2
import windows_reactor.core.{RenderCx, Element, grid, hstack, button, GridLength, GridPlacement, Thickness}
import windows_reactor.winui.{App, Backdrop, reexecWithUiStackIfNeeded}

// ============================================================================
// circles — animated orbiting circles drawn with windows_canvas, hosted inside
// a reactor UI. Add / Remove buttons change the live circle count.
//
// Mirrors the reference circles/main.rs. State is managed through reactor hooks:
//   * useState<Int64>(count)   — the reactive circle count (drives re-render +
//                                button labels).
//   * useRef<CirclesState>(..) — a stable heap cell carrying the per-frame
//                                animation counter AND the live circle count the
//                                draw closure reads. (The reference uses two
//                                use_ref cells; one heap object holds both here.)
//
// WHY THE SHARED CELL: animatedCanvas captures the draw closure ONCE, when the
// SwapChainPanel mounts (its onReady fires once). A reactor re-render does not
// re-run onReady, so the draw closure cannot observe a fresh useState value
// captured by copy. Instead the component writes the current count into the
// stable useRef cell every render, and the mount-time draw closure reads the
// cell live each frame — behaviour-equivalent to the reference circle_count ref.
// ============================================================================

// Stable per-app render state shared between the component and the draw closure.
class CirclesState {
    var frame: UInt64 = 0
    var count: Int64 = 5
}

func app(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(5)
    let state = cx.useRef<CirclesState>(CirclesState()).get()
    // Publish the current reactive count into the shared cell each render.
    state.count = count

    let add = { => setCount.call(count + 1) }
    let remove = { =>
        if (count > 0) {
            setCount.call(count - 1)
        }
    }

    let margin = 16.0

    // The draw closure reads `state` (a captured class reference; its var fields
    // stay live across renders) — never the by-copy `count`.
    let canvasEl = animatedCanvas({ ctx: DrawContext =>
        state.frame = state.frame + 1
        let t = Float32(state.frame) * 0.02
        let n = state.count
        let cxp = ctx.width / 2.0
        let cyp = ctx.height / 2.0
        let orbit = minC(cxp, cyp) * 0.5

        ctx.clear(ColorF.transparent())

        let brush = ctx.createSolidBrush(ColorF.cornflowerBlue())

        var i = 0
        while (i < n) {
            let phase = t + Float32(i) * 1.2
            let x = cxp + cos(phase) * orbit
            let y = cyp + sin(phase) * (orbit * 0.7)
            let radius = 20.0 + abs(sin(phase * 0.7)) * 30.0

            brush.setColor(ColorF(
                0.3 + abs(sin(phase * 0.3)) * 0.7,
                0.4 + abs(cos(phase * 0.5)) * 0.5,
                0.8,
                0.85
            ))
            ctx.fillEllipse(Ellipse.circle(vector2(x, y), radius), brush)
            i++
        }

        // Count label along the bottom.
        let format: TextFormat
        try {
            format = TextFormat.withWeight("Segoe UI", 20.0, FontWeight.bold())
                .withAlignment(TextAlignment.Center)
        } catch (_: Exception) {
            return
        }
        brush.setColor(ColorF.white())
        let rect = Rect(0.0, ctx.height - 40.0, ctx.width, ctx.height)
        ctx.drawText("${n} circles", format, rect, brush)
    })
        .margin(Thickness(margin, margin, margin, 0.0))
        .gridRow(0)
        .toElement()

    let controls = hstack([
        button("Add circle").onClick(add).toElement(),
        button("Remove circle").onClick(remove).toElement()
    ])
        .spacing(8.0)
        .margin(Thickness.uniform(margin))
        .toElement()

    // Place the controls in grid row 1 (vstack/hstack don't expose gridRow;
    // attach it through the lowered element's shared Modifiers, the same idiom
    // the reactor minimal sample uses for grid placement).
    atGridRow(controls, 1)

    grid([canvasEl, controls])
        .rowsOf([GridLength.Star(1.0), GridLength.Auto])
        .toElement()
}

func minC(a: Float32, b: Float32): Float32 {
    if (a < b) { a } else { b }
}

// Place a lowered element at a grid row via its shared Modifiers (hstack has no
// .gridRow builder).
func atGridRow(el: Element, row: Int32): Element {
    match (el.modifiers()) {
        case Some(m) =>
            let prev = match (m.grid) {
                case Some(g) => g
                case None => GridPlacement.default()
            }
            m.grid = Some(GridPlacement(row, prev.column, prev.rowSpan, prev.columnSpan))
        case None => ()
    }
    el
}

main(): Int64 {
    match (reexecWithUiStackIfNeeded()) {
        case Some(code) => return code
        case None => ()
    }
    App.new()
        .title("Canvas + Reactor")
        .backdrop(Backdrop.Mica)
        .render(app)
    0
}
