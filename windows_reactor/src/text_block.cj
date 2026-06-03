package windows_reactor

public class TextBlock <: Widget {
    public let content: String
    public var fontSize: Option<Float64> = None
    public var fontWeight: Option<Int64> = None
    public var wrapText: Bool = true
    public var modifiers: Modifiers = Modifiers()

    public init(content: String) {
        this.content = content
    }

    public static func new(content: String): TextBlock {
        TextBlock(content)
    }

    public func controlKind(): ControlKind { ControlKind.TextBlock }
    public func toElement(): Element { Element.textBlock(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = attr("Text", content) + frameworkAttrs(modifiers)
        match (fontSize) {
            case Some(size) => attrs += floatAttr("FontSize", size)
            case None => ()
        }
        match (fontWeight) {
            case Some(weight) =>
                if (weight >= 700) {
                    attrs += attr("FontWeight", "SemiBold")
                } else {
                    attrs += rawAttr("FontWeight", weight.toString())
                }
            case None => ()
        }
        if (wrapText) {
            "<TextBlock" + attrs + " TextWrapping=\"Wrap\" />"
        } else {
            "<TextBlock" + attrs + " />"
        }
    }

    public func font_size(value: Float64): TextBlock {
        fontSize = Some(value)
        this
    }

    public func bold(): TextBlock {
        fontWeight = Some(700)
        this
    }

    public func semibold(): TextBlock {
        fontWeight = Some(600)
        this
    }

    public func wrap(): TextBlock {
        wrapText = true
        this
    }

    public func no_wrap(): TextBlock {
        wrapText = false
        this
    }

    public func name(value: String): TextBlock {
        modifiers.xName = Some(value)
        this
    }
}

public func text_block(content: String): TextBlock { TextBlock.new(content) }
