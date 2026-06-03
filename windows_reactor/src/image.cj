package windows_reactor

public enum ImageStretch <: Equatable<ImageStretch> {
    | Uniform | UniformToFill | Fill | None

    public func code(): Int64 {
        match (this) {
            case Uniform => 0
            case UniformToFill => 1
            case Fill => 2
            case None => 3
        }
    }

    public operator func ==(other: ImageStretch): Bool { code() == other.code() }
    public operator func !=(other: ImageStretch): Bool { !(this == other) }
}

func stretchText(value: ImageStretch): String {
    match (value) {
        case ImageStretch.Uniform => "Uniform"
        case ImageStretch.UniformToFill => "UniformToFill"
        case ImageStretch.Fill => "Fill"
        case ImageStretch.None => "None"
    }
}

public class Image <: Widget {
    public var source: String
    public var stretchValue: ImageStretch = ImageStretch.Uniform
    public var modifiers: Modifiers = Modifiers()

    public init(source: String) {
        this.source = source
    }

    public static func new(source: String): Image {
        Image(source)
    }

    public func controlKind(): ControlKind { ControlKind.Image }
    public func toElement(): Element { Element.image(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        "<Image" + attr("Source", source) + attr("Stretch", stretchText(stretchValue)) +
            frameworkAttrs(modifiers) + " />"
    }

    public func stretch(value: ImageStretch): Image {
        stretchValue = value
        this
    }

    public func name(value: String): Image {
        modifiers.xName = Some(value)
        this
    }
}

public func image(source: String): Image { Image.new(source) }
