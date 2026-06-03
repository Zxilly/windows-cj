package windows_reactor

import std.collection.*

public class StackPanel <: Widget {
    public var vertical: Bool = true
    public var spacingValue: Option<Float64> = None
    public var children: ArrayList<Element> = ArrayList<Element>()
    public var modifiers: Modifiers = Modifiers()

    public init() {}

    public static func new(vertical: Bool, children: Array<Element>): StackPanel {
        let panel = StackPanel()
        panel.vertical = vertical
        for (child in children) {
            panel.children.add(child)
        }
        panel
    }

    public func controlKind(): ControlKind { ControlKind.StackPanel }
    public func toElement(): Element { Element.stackPanel(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = attr("Orientation", if (vertical) { "Vertical" } else { "Horizontal" }) + frameworkAttrs(modifiers)
        match (spacingValue) {
            case Some(spacing) => attrs += floatAttr("Spacing", spacing)
            case None => ()
        }
        "<StackPanel" + attrs + ">\n" + renderChildren(children) + "</StackPanel>"
    }

    public func spacing(value: Float64): StackPanel {
        spacingValue = Some(value)
        this
    }

    public func name(value: String): StackPanel {
        modifiers.xName = Some(value)
        this
    }
}
