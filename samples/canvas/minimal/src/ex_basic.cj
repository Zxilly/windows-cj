package windows_canvas_minimal

import windows_canvas.{DrawContext, ColorF, Rect, Ellipse, RoundedRect}
import windows_numerics.vector2

// ============================================================================
// Basic shape / color / line examples: hello, color, lines, shapes, brush.
// Each `make<Name>Draw()` returns the example's per-frame draw closure (none of
// these need per-run mutable state, so the factory just returns the closure).
// ============================================================================

// hello — a single filled circle centered in the client area.
func makeHelloDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.darkSlateBlue())
        let brush = ctx.createSolidBrush(ColorF.cornflowerBlue())
        let r = minF32(ctx.width, ctx.height) * 0.3
        ctx.fillEllipse(
            Ellipse.circle(vector2(ctx.width / 2.0, ctx.height / 2.0), r),
            brush
        )
    }
}

// color — four stacked bars demonstrating the ColorF constructors.
func makeColorDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.darkSlateBlue())
        let brush = ctx.createSolidBrush(ColorF.cornflowerBlue())

        let w = ctx.width / 2.0
        let h = ctx.height / 4.0

        // Named constant.
        ctx.fillRect(Rect(10.0, 10.0, w, h - 5.0), brush)
        // From RGB floats.
        brush.setColor(ColorF.rgb(0.9, 0.5, 0.1))
        ctx.fillRect(Rect(10.0, h + 5.0, w, h * 2.0 - 5.0), brush)
        // From u8 values.
        brush.setColor(ColorF.fromRgb8(128, 0, 255))
        ctx.fillRect(Rect(10.0, h * 2.0 + 5.0, w, h * 3.0 - 5.0), brush)
        // With alpha.
        brush.setColor(ColorF(1.0, 1.0, 1.0, 0.5))
        ctx.fillRect(Rect(10.0, h * 3.0 + 5.0, w, ctx.height - 10.0), brush)
    }
}

// lines — eight horizontal lines of increasing width and shifting color.
func makeLinesDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.black())
        let brush = ctx.createSolidBrush(ColorF.white())

        let margin = 30.0f32
        let count = 8
        let spacing = (ctx.height - margin * 2.0) / Float32(count)

        for (i in 0..count) {
            let y = margin + Float32(i) * spacing + spacing / 2.0
            let width = Float32(i + 1)

            let t = Float32(i) / Float32(count - 1)
            brush.setColor(ColorF(1.0 - t * 0.7, 1.0 - t * 0.5, 1.0, 1.0))

            ctx.drawLine(
                vector2(margin, y),
                vector2(ctx.width - margin, y),
                brush,
                width
            )
        }
    }
}

// shapes — a filled and an outlined rounded rectangle.
func makeShapesDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.darkSlateBlue())
        let brush = ctx.createSolidBrush(ColorF.cornflowerBlue())

        let cx = ctx.width / 2.0
        let cy = ctx.height / 2.0
        let size = minF32(cx, cy) * 0.6

        // Filled rounded rect.
        ctx.fillRoundedRect(
            RoundedRect.uniform(Rect(cx - size, cy - size, cx, cy), 15.0),
            brush
        )
        // Outlined rounded rect.
        brush.setColor(ColorF.white())
        ctx.drawRoundedRect(
            RoundedRect.uniform(Rect(cx, cy, cx + size, cy + size), 25.0),
            brush,
            3.0
        )
    }
}

// brush — four vertical stripes reusing one brush via setColor.
func makeBrushDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.black())
        let brush = ctx.createSolidBrush(ColorF.red())

        let colors: Array<ColorF> = [ColorF.red(), ColorF.green(), ColorF.blue(), ColorF.white()]
        let stripeWidth = ctx.width / Float32(colors.size)

        for (i in 0..colors.size) {
            brush.setColor(colors[i])
            ctx.fillRect(
                Rect(
                    Float32(i) * stripeWidth,
                    0.0,
                    Float32(i + 1) * stripeWidth,
                    ctx.height
                ),
                brush
            )
        }
    }
}

// Float32 min helper (std.math.min is generic but spelling it out keeps the
// draw code unambiguous about the f32 width).
func minF32(a: Float32, b: Float32): Float32 {
    if (a < b) { a } else { b }
}
