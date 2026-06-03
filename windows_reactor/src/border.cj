package windows_reactor

public class Border <: Widget {
    public var child: Element
    public var modifiers: Modifiers = Modifiers()

    public init(child: Element) {
        this.child = child
    }

    public static func new(child: Element): Border {
        Border(child)
    }

    public func controlKind(): ControlKind { ControlKind.Border }
    public func toElement(): Element { Element.border(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        "<Border" + frameworkAttrs(modifiers) + paddingAttr(modifiers) + ">\n" +
            renderXamlFragment(child) + "\n</Border>"
    }

    public func name(value: String): Border {
        modifiers.xName = Some(value)
        this
    }
}

public func border(child: Element): Border { Border.new(child) }
