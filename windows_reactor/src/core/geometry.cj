package windows_reactor.core

// Geometry, color, alignment, and layout primitives shared by every widget.
// Behaviour-equivalent to the reference geometry module: value types are
// modelled as immutable structs implementing Equatable so they can flow
// through PropValue.equals() and Modifiers diffing.

public struct Thickness <: Equatable<Thickness> {
    public let left: Float64
    public let top: Float64
    public let right: Float64
    public let bottom: Float64

    public init(left: Float64, top: Float64, right: Float64, bottom: Float64) {
        this.left = left
        this.top = top
        this.right = right
        this.bottom = bottom
    }

    public static func uniform(v: Float64): Thickness {
        Thickness(v, v, v, v)
    }

    public static func xy(x: Float64, y: Float64): Thickness {
        Thickness(x, y, x, y)
    }

    public operator func ==(other: Thickness): Bool {
        left == other.left && top == other.top && right == other.right && bottom == other.bottom
    }

    public operator func !=(other: Thickness): Bool {
        !(this == other)
    }
}

public struct Color <: Equatable<Color> {
    public let a: UInt8
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(a: UInt8, r: UInt8, g: UInt8, b: UInt8) {
        this.a = a
        this.r = r
        this.g = g
        this.b = b
    }

    public static func rgb(r: UInt8, g: UInt8, b: UInt8): Color {
        Color(255u8, r, g, b)
    }

    public static func argb(a: UInt8, r: UInt8, g: UInt8, b: UInt8): Color {
        Color(a, r, g, b)
    }

    public operator func ==(other: Color): Bool {
        a == other.a && r == other.r && g == other.g && b == other.b
    }

    public operator func !=(other: Color): Bool {
        !(this == other)
    }
}

// A drawing brush. The reference type carries only a solid-color variant;
// theme-resource brushes are expressed separately via BrushBinding (theme.cj).
public enum Brush <: Equatable<Brush> {
    | Solid(Color)

    public static func solid(c: Color): Brush { Brush.Solid(c) }

    public operator func ==(other: Brush): Bool {
        match ((this, other)) {
            case (Solid(a), Solid(b)) => a == b
        }
    }

    public operator func !=(other: Brush): Bool {
        !(this == other)
    }
}

public enum HorizontalAlignment <: Equatable<HorizontalAlignment> {
    | Left | Center | Right | Stretch

    public func tag(): Int64 {
        match (this) {
            case Left => 0
            case Center => 1
            case Right => 2
            case Stretch => 3
        }
    }

    public operator func ==(other: HorizontalAlignment): Bool { tag() == other.tag() }
    public operator func !=(other: HorizontalAlignment): Bool { tag() != other.tag() }
}

public enum VerticalAlignment <: Equatable<VerticalAlignment> {
    | Top | Center | Bottom | Stretch

    public func tag(): Int64 {
        match (this) {
            case Top => 0
            case Center => 1
            case Bottom => 2
            case Stretch => 3
        }
    }

    public operator func ==(other: VerticalAlignment): Bool { tag() == other.tag() }
    public operator func !=(other: VerticalAlignment): Bool { tag() != other.tag() }
}

public enum GridLength <: Equatable<GridLength> {
    | Auto
    | Pixel(Float64)
    | Star(Float64)

    public static func star(v: Float64): GridLength { GridLength.Star(v) }
    public static func pixel(v: Float64): GridLength { GridLength.Pixel(v) }

    public operator func ==(other: GridLength): Bool {
        match ((this, other)) {
            case (Auto, Auto) => true
            case (Pixel(a), Pixel(b)) => a == b
            case (Star(a), Star(b)) => a == b
            case _ => false
        }
    }

    public operator func !=(other: GridLength): Bool { !(this == other) }
}

public enum ScrollBarVisibility <: Equatable<ScrollBarVisibility> {
    | Auto | Visible | Hidden | Disabled

    public func tag(): Int64 {
        match (this) {
            case Auto => 0
            case Visible => 1
            case Hidden => 2
            case Disabled => 3
        }
    }

    public operator func ==(other: ScrollBarVisibility): Bool { tag() == other.tag() }
    public operator func !=(other: ScrollBarVisibility): Bool { tag() != other.tag() }
}

// Shared by Image. Mirrors Microsoft.UI.Xaml.Media.Stretch.
public enum ImageStretch <: Equatable<ImageStretch> {
    | NoneStretch | Fill | Uniform | UniformToFill

    public func tag(): Int64 {
        match (this) {
            case NoneStretch => 0
            case Fill => 1
            case Uniform => 2
            case UniformToFill => 3
        }
    }

    public operator func ==(other: ImageStretch): Bool { tag() == other.tag() }
    public operator func !=(other: ImageStretch): Bool { tag() != other.tag() }
}

// Endpoints for a Line shape.
public struct LineEndpoints <: Equatable<LineEndpoints> {
    public let x1: Float64
    public let y1: Float64
    public let x2: Float64
    public let y2: Float64

    public init(x1: Float64, y1: Float64, x2: Float64, y2: Float64) {
        this.x1 = x1
        this.y1 = y1
        this.x2 = x2
        this.y2 = y2
    }

    public operator func ==(other: LineEndpoints): Bool {
        x1 == other.x1 && y1 == other.y1 && x2 == other.x2 && y2 == other.y2
    }

    public operator func !=(other: LineEndpoints): Bool { !(this == other) }
}

// Window-host geometry helpers (window.rs equivalents).
public struct Size <: Equatable<Size> {
    public let width: Float64
    public let height: Float64
    public init(width: Float64, height: Float64) {
        this.width = width
        this.height = height
    }
    public operator func ==(other: Size): Bool { width == other.width && height == other.height }
    public operator func !=(other: Size): Bool { !(this == other) }
}

public class InnerConstraints {
    public var minWidth: ?Float64 = None
    public var minHeight: ?Float64 = None
    public var maxWidth: ?Float64 = None
    public var maxHeight: ?Float64 = None
    public init() {}
}
