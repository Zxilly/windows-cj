package windows_canvas

import windows_numerics.Vector2

import windows_canvas_bindings.Win32.Graphics.Direct2D.{
    ID2D1SolidColorBrush,
    ID2D1LinearGradientBrush,
    ID2D1RadialGradientBrush,
    ID2D1StrokeStyle1,
    ID2D1SolidColorBrushVtbl,
    D2D1_ELLIPSE,
    D2D1_ROUNDED_RECT,
    D2D1_STROKE_STYLE_PROPERTIES1
}
import windows_canvas_bindings.Win32.Graphics.Direct2D.Common.{
    D2D_RECT_F,
    D2D1_GRADIENT_STOP,
    D2D1_COLOR_F
}

import windows_core.HRESULT

// A rectangle defined by its edges.
public struct Rect {
    public let left: Float32
    public let top: Float32
    public let right: Float32
    public let bottom: Float32

    // Create a rectangle from edge coordinates.
    public init(left: Float32, top: Float32, right: Float32, bottom: Float32) {
        this.left = left
        this.top = top
        this.right = right
        this.bottom = bottom
    }

    // Create a rectangle from position and size.
    public static func fromXywh(x: Float32, y: Float32, width: Float32, height: Float32): Rect {
        return Rect(x, y, x + width, y + height)
    }

    // Width of the rectangle.
    public func width(): Float32 {
        return this.right - this.left
    }

    // Height of the rectangle.
    public func height(): Float32 {
        return this.bottom - this.top
    }

    func toAbi(): D2D_RECT_F {
        var r = D2D_RECT_F()
        r.left = this.left
        r.top = this.top
        r.right = this.right
        r.bottom = this.bottom
        return r
    }
}

// An ellipse defined by center point and radii.
public struct Ellipse {
    public let center: Vector2
    public let radiusX: Float32
    public let radiusY: Float32

    // Create an ellipse from center and radii.
    public init(center: Vector2, radiusX: Float32, radiusY: Float32) {
        this.center = center
        this.radiusX = radiusX
        this.radiusY = radiusY
    }

    // Create a circle from center and radius.
    public static func circle(center: Vector2, radius: Float32): Ellipse {
        return Ellipse(center, radius, radius)
    }

    func toAbi(): D2D1_ELLIPSE {
        var e = D2D1_ELLIPSE()
        e.point = toProjectedVector2(this.center)
        e.radiusX = this.radiusX
        e.radiusY = this.radiusY
        return e
    }
}

// A rectangle with rounded corners.
public struct RoundedRect {
    public let rect: Rect
    public let radiusX: Float32
    public let radiusY: Float32

    // Create a rounded rectangle.
    public init(rect: Rect, radiusX: Float32, radiusY: Float32) {
        this.rect = rect
        this.radiusX = radiusX
        this.radiusY = radiusY
    }

    // Create a rounded rectangle with uniform corner radius.
    public static func uniform(rect: Rect, radius: Float32): RoundedRect {
        return RoundedRect(rect, radius, radius)
    }

    func toAbi(): D2D1_ROUNDED_RECT {
        var rr = D2D1_ROUNDED_RECT()
        rr.rect = this.rect.toAbi()
        rr.radiusX = this.radiusX
        rr.radiusY = this.radiusY
        return rr
    }
}

// --- Brush types ---

// Interface for types that can be used as brushes in draw calls.
//
// Implemented by `Brush`, `LinearGradient`, and `RadialGradient`.
//
// Cangjie paradigm note (equivalent): the reference uses a sealed trait whose
// hidden method hands out a borrowed `&ID2D1Brush`. Every concrete D2D brush
// shares the `ID2D1Brush` COM base layout (binary-identical vtable prefix), so
// here `asRawBrush()` simply returns the raw brush pointer reinterpreted as an
// `ID2D1Brush*`. No QueryInterface is performed (it is unnecessary and would
// only add a needless AddRef/Release round-trip).
public interface Paint {
    func asRawBrush(): CPointer<Unit>
}

// A solid color brush.
//
// Cheap to create per-frame, or cache and reuse across frames by changing the
// color with `setColor`.
public class Brush <: Paint {
    let inner: ID2D1SolidColorBrush

    init(inner: ID2D1SolidColorBrush) {
        this.inner = inner
    }

    // Change the brush color (zero-cost - no reallocation).
    public func setColor(color: ColorF): Unit {
        var c = color.toAbi()
        let raw = this.inner.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1SolidColorBrushVtbl>>(raw).read().read()
            vtbl.SetColor(raw, CPointer<Unit>(CPointer<D2D1_COLOR_F>(inout c)))
        }
    }

    public func asRawBrush(): CPointer<Unit> {
        return this.inner.asRaw()
    }
}

// A linear gradient brush with a start point, end point, and color stops.
public class LinearGradient <: Paint {
    let inner: ID2D1LinearGradientBrush

    init(inner: ID2D1LinearGradientBrush) {
        this.inner = inner
    }

    public func asRawBrush(): CPointer<Unit> {
        return this.inner.asRaw()
    }
}

// A radial gradient brush with a center, radii, and color stops.
public class RadialGradient <: Paint {
    let inner: ID2D1RadialGradientBrush

    init(inner: ID2D1RadialGradientBrush) {
        this.inner = inner
    }

    public func asRawBrush(): CPointer<Unit> {
        return this.inner.asRaw()
    }
}

// A color stop in a gradient (position 0.0-1.0 along the gradient axis).
public struct GradientStop {
    public let position: Float32
    public let color: ColorF

    public init(position: Float32, color: ColorF) {
        this.position = position
        this.color = color
    }

    func toAbi(): D2D1_GRADIENT_STOP {
        var s = D2D1_GRADIENT_STOP()
        s.position = this.position
        s.color = this.color.toAbi()
        return s
    }
}

// --- Stroke style ---

// Cap style applied to the start and end of stroked lines.
public enum CapStyle {
    | Flat
    | Square
    | Round
    | Triangle

    // D2D1_CAP_STYLE: Flat=0, Square=1, Round=2, Triangle=3.
    func toAbi(): Int32 {
        match (this) {
            case Flat => 0
            case Square => 1
            case Round => 2
            case Triangle => 3
        }
    }
}

// Line join style for connected segments.
public enum LineJoin {
    | Miter
    | Bevel
    | RoundJoin

    // D2D1_LINE_JOIN: Miter=0, Bevel=1, Round=2.
    func toAbi(): Int32 {
        match (this) {
            case Miter => 0
            case Bevel => 1
            case RoundJoin => 2
        }
    }
}

// Dash pattern for stroked lines.
public enum DashStyle {
    | Solid
    | Dash
    | Dot
    | DashDot

    // D2D1_DASH_STYLE: Solid=0, Dash=1, Dot=2, DashDot=3.
    func toAbi(): Int32 {
        match (this) {
            case Solid => 0
            case Dash => 1
            case Dot => 2
            case DashDot => 3
        }
    }
}

// Describes how to draw the stroke for lines, outlines, and paths.
//
// Create via `StrokeStyleBuilder` and `GpuDevice.createStrokeStyle`.
public class StrokeStyle {
    let inner: ID2D1StrokeStyle1

    init(inner: ID2D1StrokeStyle1) {
        this.inner = inner
    }

    func asRaw(): CPointer<Unit> {
        return this.inner.asRaw()
    }
}

// Builder for `StrokeStyle`.
//
// Cangjie paradigm note (equivalent): the reference's fluent builder takes
// `self` by value and returns it. A Cangjie value `struct` has the same
// move-and-return semantics, so the chaining API is identical.
public struct StrokeStyleBuilder {
    var startCapValue: CapStyle = CapStyle.Flat
    var endCapValue: CapStyle = CapStyle.Flat
    var dashCapValue: CapStyle = CapStyle.Flat
    var lineJoinValue: LineJoin = LineJoin.Miter
    var miterLimitValue: Float32 = 10.0
    var dashStyleValue: DashStyle = DashStyle.Solid
    var dashOffsetValue: Float32 = 0.0

    public init() {}

    // Set the cap style for the start of lines.
    public func startCap(cap: CapStyle): StrokeStyleBuilder {
        var b = this
        b.startCapValue = cap
        return b
    }

    // Set the cap style for the end of lines.
    public func endCap(cap: CapStyle): StrokeStyleBuilder {
        var b = this
        b.endCapValue = cap
        return b
    }

    // Set the cap style for both start and end.
    public func caps(cap: CapStyle): StrokeStyleBuilder {
        var b = this
        b.startCapValue = cap
        b.endCapValue = cap
        return b
    }

    // Set the cap style for dashes.
    public func dashCap(cap: CapStyle): StrokeStyleBuilder {
        var b = this
        b.dashCapValue = cap
        return b
    }

    // Set the line join style.
    public func lineJoin(join: LineJoin): StrokeStyleBuilder {
        var b = this
        b.lineJoinValue = join
        return b
    }

    // Set the miter limit (only applies to miter joins).
    public func miterLimit(limit: Float32): StrokeStyleBuilder {
        var b = this
        b.miterLimitValue = limit
        return b
    }

    // Set the dash style.
    public func dashStyle(style: DashStyle): StrokeStyleBuilder {
        var b = this
        b.dashStyleValue = style
        return b
    }

    // Set the dash offset.
    public func dashOffset(offset: Float32): StrokeStyleBuilder {
        var b = this
        b.dashOffsetValue = offset
        return b
    }

    func toAbi(): D2D1_STROKE_STYLE_PROPERTIES1 {
        var p = D2D1_STROKE_STYLE_PROPERTIES1()
        p.startCap = this.startCapValue.toAbi()
        p.endCap = this.endCapValue.toAbi()
        p.dashCap = this.dashCapValue.toAbi()
        p.lineJoin = this.lineJoinValue.toAbi()
        p.miterLimit = this.miterLimitValue
        p.dashStyle = this.dashStyleValue.toAbi()
        p.dashOffset = this.dashOffsetValue
        p.transformType = 0
        return p
    }
}
