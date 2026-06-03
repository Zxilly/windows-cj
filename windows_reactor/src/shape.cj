package windows_reactor

public enum ShapeKind <: Equatable<ShapeKind> {
    | Rectangle | Ellipse | Line

    public func code(): Int64 {
        match (this) {
            case Rectangle => 0
            case Ellipse => 1
            case Line => 2
        }
    }

    public operator func ==(other: ShapeKind): Bool { code() == other.code() }
    public operator func !=(other: ShapeKind): Bool { !(this == other) }
}

public struct LineEndpoints <: Equatable<LineEndpoints> {
    public var x1: Float64 = 0.0
    public var y1: Float64 = 0.0
    public var x2: Float64 = 0.0
    public var y2: Float64 = 0.0

    public init() {}

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

func shapeAttrs(shape: Shape): String {
    var attrs = frameworkAttrs(shape.modifiers)
    match (shape.fillValue) {
        case Some(brush) => attrs += attr("Fill", brushText(brush))
        case None => ()
    }
    match (shape.strokeValue) {
        case Some(brush) => attrs += attr("Stroke", brushText(brush))
        case None => ()
    }
    match (shape.strokeThickness) {
        case Some(thickness) => attrs += floatAttr("StrokeThickness", thickness)
        case None => ()
    }
    attrs
}

public class Shape <: Widget {
    public var kind: ShapeKind = ShapeKind.Rectangle
    public var fillValue: Option<Brush> = None
    public var strokeValue: Option<Brush> = None
    public var strokeThickness: Option<Float64> = None
    public var cornerRadius: Option<Float64> = None
    public var lineValue: LineEndpoints = LineEndpoints()
    public var modifiers: Modifiers = Modifiers()

    public init() {}

    public static func rectangle(): Shape {
        let shape = Shape()
        shape.kind = ShapeKind.Rectangle
        shape
    }

    public static func ellipse(): Shape {
        let shape = Shape()
        shape.kind = ShapeKind.Ellipse
        shape
    }

    public static func line(x1: Float64, y1: Float64, x2: Float64, y2: Float64): Shape {
        let shape = Shape()
        shape.kind = ShapeKind.Line
        shape.lineValue = LineEndpoints(x1, y1, x2, y2)
        shape
    }

    public func controlKind(): ControlKind {
        match (kind) {
            case ShapeKind.Rectangle => ControlKind.Rectangle
            case ShapeKind.Ellipse => ControlKind.Ellipse
            case ShapeKind.Line => ControlKind.Line
        }
    }

    public func toElement(): Element { Element.shape(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        match (kind) {
            case ShapeKind.Rectangle =>
                var attrs = shapeAttrs(this)
                match (cornerRadius) {
                    case Some(radius) =>
                        attrs += floatAttr("RadiusX", radius)
                        attrs += floatAttr("RadiusY", radius)
                    case None => ()
                }
                "<Rectangle" + attrs + " />"
            case ShapeKind.Ellipse => "<Ellipse" + shapeAttrs(this) + " />"
            case ShapeKind.Line =>
                "<Line" + shapeAttrs(this) +
                    floatAttr("X1", lineValue.x1) + floatAttr("Y1", lineValue.y1) +
                    floatAttr("X2", lineValue.x2) + floatAttr("Y2", lineValue.y2) + " />"
        }
    }

    public func fill(value: Brush): Shape {
        fillValue = Some(value)
        this
    }

    public func fill_rgb(r: UInt8, g: UInt8, b: UInt8): Shape {
        fillValue = Some(Brush.Solid(Color.rgb(r, g, b)))
        this
    }

    public func stroke(value: Brush): Shape {
        strokeValue = Some(value)
        this
    }

    public func stroke_thickness(value: Float64): Shape {
        strokeThickness = Some(value)
        this
    }

    public func corner_radius(value: Float64): Shape {
        cornerRadius = Some(value)
        this
    }

    public func name(value: String): Shape {
        modifiers.xName = Some(value)
        this
    }
}

public func rectangle(): Shape { Shape.rectangle() }
public func ellipse(): Shape { Shape.ellipse() }
public func line(x1: Float64, y1: Float64, x2: Float64, y2: Float64): Shape { Shape.line(x1, y1, x2, y2) }
