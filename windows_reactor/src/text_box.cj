package windows_reactor

public class TextBox <: Widget {
    public var value: String
    public var placeholderText: Option<String> = None
    public var isEnabled: Bool = true
    public var modifiers: Modifiers = Modifiers()

    public init(value: String) {
        this.value = value
    }

    public static func new(value: String): TextBox {
        TextBox(value)
    }

    public func controlKind(): ControlKind { ControlKind.TextBox }
    public func toElement(): Element { Element.textBox(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = attr("Text", value) + boolAttr("IsEnabled", isEnabled) + frameworkAttrs(modifiers)
        match (placeholderText) {
            case Some(text) => attrs += attr("PlaceholderText", text)
            case None => ()
        }
        "<TextBox" + attrs + " />"
    }

    public func placeholder(value: String): TextBox {
        placeholderText = Some(value)
        this
    }

    public func enabled(value: Bool): TextBox {
        isEnabled = value
        this
    }

    public func name(value: String): TextBox {
        modifiers.xName = Some(value)
        this
    }
}

public func text_box(value: String): TextBox { TextBox.new(value) }
