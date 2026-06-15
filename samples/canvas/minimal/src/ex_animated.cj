package windows_canvas_minimal

import std.math.{sin, cos}
import windows_canvas.{
    DrawContext, ColorF, Rect, Ellipse, StrokeStyle, StrokeStyleBuilder,
    CapStyle, Matrix3x2
}
import windows_numerics.{
    Vector2, vector2, zeroVector2, multiply, rotationMatrix3x2, translationMatrix3x2
}

// ============================================================================
// transform, clock — the two animated examples. Both need per-run mutable
// render state; the reference uses thread_local Cell/OnceCell. Here each
// make<Name>Draw() allocates a fresh heap holder captured by `let` in the
// returned closure (a captured class reference may escape into a stored closure
// and its var fields stay mutable — unlike a captured var local).
// ============================================================================

// Mutable frame counter shared into the transform draw closure.
class FrameCounter {
    var value: UInt64 = 0
}

// transform — six rotating squares, animated by a per-frame counter.
func makeTransformDraw(): (DrawContext) -> Unit {
    let frame = FrameCounter()
    { ctx: DrawContext =>
        frame.value = frame.value + 1
        let t = Float32(frame.value) * 0.01

        ctx.clear(ColorF.black())
        let brush = ctx.createSolidBrush(ColorF.cornflowerBlue())

        let cx = ctx.width / 2.0
        let cy = ctx.height / 2.0
        let size = minAnim(cx, cy) * 0.25
        let pi: Float32 = 3.14159265358979f32

        for (i in 0..6) {
            let angle = t + Float32(i) * pi / 3.0
            let s = sin(angle)
            let c = cos(angle)
            // Rotation about (cx, cy), built directly (matches the reference
            // explicit Matrix3x2 with the rotate-about-point translation terms).
            var transform = Matrix3x2()
            transform.M11 = c
            transform.M12 = s
            transform.M21 = -s
            transform.M22 = c
            transform.M31 = cx * (1.0 - c) + cy * s
            transform.M32 = cy * (1.0 - c) - cx * s

            let frac = Float32(i) / 6.0
            brush.setColor(ColorF(0.3 + frac * 0.7, 0.5, 1.0 - frac * 0.5, 0.8))

            ctx.withTransform(transform, { =>
                ctx.fillRect(Rect(cx - size, cy - size, cx + size, cy + size), brush)
            })
        }
    }
}

func minAnim(a: Float32, b: Float32): Float32 {
    if (a < b) { a } else { b }
}

// ── clock ──────────────────────────────────────────────────────────────────

// SYSTEMTIME (Win32) — only the fields the clock reads matter; the layout must
// match so GetLocalTime fills them at the right offsets.
@C
struct SYSTEMTIME {
    public var wYear: UInt16 = 0
    public var wMonth: UInt16 = 0
    public var wDayOfWeek: UInt16 = 0
    public var wDay: UInt16 = 0
    public var wHour: UInt16 = 0
    public var wMinute: UInt16 = 0
    public var wSecond: UInt16 = 0
    public var wMilliseconds: UInt16 = 0
    public init() {}
}

// GetLocalTime writes the local wall-clock time into the supplied SYSTEMTIME.
// On x86_64 there is a single calling convention, so no @CallingConv is needed
// (STDCALL is a no-op on x64; default CDECL maps to the Microsoft x64 ABI).
foreign func GetLocalTime(lpSystemTime: CPointer<SYSTEMTIME>): Unit

// Holds the stroke style created once on the first frame (the reference caches
// it in a thread_local OnceCell). Created lazily because it needs the live
// GpuDevice, which only exists from the first draw call on.
class HandStyleCache {
    var value: ?StrokeStyle = None
}

// clock — analog clock with hour / minute / second hands, animated from the
// system clock. Matches the reference clock.rs math and stroke styling.
func makeClockDraw(): (DrawContext) -> Unit {
    let cache = HandStyleCache()
    { ctx: DrawContext =>
        ctx.clear(ColorF.white())

        let sizeX = ctx.width
        let sizeY = ctx.height
        let radius = maxClock(minAnim(sizeX, sizeY), 200.0) / 2.0 - 50.0

        // Single brush — orange/terracotta at 80% opacity (matching the
        // direct2d clock sample).
        let brush = ctx.createSolidBrush(ColorF(0.92, 0.38, 0.208, 0.8))

        // Create the hand stroke style once (round start, triangle end).
        let style = match (cache.value) {
            case Some(s) => s
            case None =>
                let built = ctx.device().createStrokeStyle(
                    StrokeStyleBuilder()
                        .startCap(CapStyle.Round)
                        .endCap(CapStyle.Triangle)
                )
                cache.value = Some(built)
                built
        }

        let translation = translationMatrix3x2(sizeX / 2.0, sizeY / 2.0)

        // Clock face — circle centered at origin, translated to the center.
        ctx.withTransform(translation, { =>
            ctx.drawEllipse(
                Ellipse.circle(zeroVector2(), radius),
                brush,
                radius / 20.0
            )
        })

        // Current local time -> hand angles in degrees (same math as the
        // reference / the direct2d sample).
        var st = SYSTEMTIME()
        unsafe {
            GetLocalTime(CPointer<SYSTEMTIME>(inout st))
        }
        let secondDeg = (Float32(st.wSecond) + Float32(st.wMilliseconds) / 1000.0) * 6.0
        let minuteDeg = Float32(st.wMinute) * 6.0 + secondDeg / 60.0
        let hourDeg = Float32(st.wHour % 12) * 30.0 + minuteDeg / 12.0

        // Second hand. The reference composes `rotation(deg) * translation`;
        // multiply(left, right) here applies `left` then `right` (row-vector
        // convention), so rotation-then-translate is multiply(rotation, translation).
        ctx.withTransform(multiply(rotationMatrix3x2(secondDeg), translation), { =>
            ctx.drawLineStyled(
                zeroVector2(),
                vector2(0.0, -(radius * 0.75)),
                brush,
                radius / 25.0,
                style
            )
        })

        // Minute hand.
        ctx.withTransform(multiply(rotationMatrix3x2(minuteDeg), translation), { =>
            ctx.drawLineStyled(
                zeroVector2(),
                vector2(0.0, -(radius * 0.75)),
                brush,
                radius / 15.0,
                style
            )
        })

        // Hour hand.
        ctx.withTransform(multiply(rotationMatrix3x2(hourDeg), translation), { =>
            ctx.drawLineStyled(
                zeroVector2(),
                vector2(0.0, -(radius * 0.5)),
                brush,
                radius / 10.0,
                style
            )
        })
    }
}

func maxClock(a: Float32, b: Float32): Float32 {
    if (a > b) { a } else { b }
}
