package windows_canvas_minimal

import std.math.{sin, cos}
import windows_canvas.{
    DrawContext, ColorF, Rect, Ellipse, RoundedRect, Path, PathBuilder,
    TextFormat, TextAlignment, ParagraphAlignment, GradientStop
}
import windows_numerics.{Vector2, vector2}

// ============================================================================
// path, text, gradient examples.
// ============================================================================

// path — a 10-point star built with the PathBuilder, then filled.
func makePathDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.darkSlateBlue())

        let cx = ctx.width / 2.0
        let cy = ctx.height / 2.0
        let r = minPT(cx, cy) * 0.8

        // Build the star path. A COM failure (rare) throws; on error skip the
        // frame, mirroring the reference's `let Ok(path) = ... else return`.
        let path: Path
        try {
            var builder = PathBuilder.create(ctx.device()).begin(starPoint(cx, cy, r, 0))
            for (i in 1..10) {
                let radius = if (i % 2 == 0) { r } else { r * 0.5 }
                builder = builder.lineTo(starPoint(cx, cy, radius, UInt32(i)))
            }
            path = builder.close().build()
        } catch (_: Exception) {
            return
        }

        let brush = ctx.createSolidBrush(ColorF(1.0, 0.8, 0.0, 1.0))
        ctx.fillPath(path, brush)
    }
}

// One vertex of the star at index i (i=0 is the topmost point).
func starPoint(cx: Float32, cy: Float32, r: Float32, i: UInt32): Vector2 {
    // PI/5 * i - PI/2, matching the reference angle progression.
    let pi: Float32 = 3.14159265358979f32
    let angle = pi / 5.0 * Float32(i) - pi / 2.0
    vector2(cx + r * cos(angle), cy + r * sin(angle))
}

// text — a centered "Hello, Canvas!" string.
func makeTextDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.black())

        let format: TextFormat
        try {
            format = TextFormat.create("Segoe UI", 32.0)
                .withAlignment(TextAlignment.Center)
                .withParagraphAlignment(ParagraphAlignment.ParagraphCenter)
        } catch (_: Exception) {
            return
        }

        let brush = ctx.createSolidBrush(ColorF.white())
        let rect = Rect(0.0, 0.0, ctx.width, ctx.height)
        ctx.drawText("Hello, Canvas!", format, rect, brush)
    }
}

// gradient — a linear-gradient rounded rect on top, a radial-gradient circle
// on the bottom.
func makeGradientDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF.black())

        let margin = 40.0f32
        let half = ctx.height / 2.0

        // Linear gradient: blue to orange across the full width.
        let linear = ctx.createLinearGradient(
            vector2(margin, 0.0),
            vector2(ctx.width - margin, 0.0),
            [
                GradientStop(0.0, ColorF.cornflowerBlue()),
                GradientStop(1.0, ColorF(1.0, 0.5, 0.0, 1.0))
            ]
        )
        ctx.fillRoundedRect(
            RoundedRect.uniform(
                Rect(margin, margin, ctx.width - margin, half - 10.0),
                20.0
            ),
            linear
        )

        // Radial gradient: white center fading out.
        let cx = ctx.width / 2.0
        let cy = half + (ctx.height - half) / 2.0
        let r = minPT(ctx.width - margin * 2.0, ctx.height - half - margin) / 2.0

        let radial = ctx.createRadialGradient(
            vector2(cx, cy),
            r,
            r,
            [
                GradientStop(0.0, ColorF.white()),
                GradientStop(0.6, ColorF.cornflowerBlue()),
                GradientStop(1.0, ColorF.black())
            ]
        )
        ctx.fillEllipse(Ellipse.circle(vector2(cx, cy), r), radial)
    }
}

func minPT(a: Float32, b: Float32): Float32 {
    if (a < b) { a } else { b }
}
