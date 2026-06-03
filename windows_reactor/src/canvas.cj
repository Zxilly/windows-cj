package windows_reactor

import std.collection.*

public class Canvas <: Widget {
    public var children: ArrayList<Element> = ArrayList<Element>()
    public var modifiers: Modifiers = Modifiers()

    public init(children: Array<Element>) {
        for (child in children) {
            this.children.add(child)
        }
    }

    public static func new(children: Array<Element>): Canvas {
        Canvas(children)
    }

    public func controlKind(): ControlKind { ControlKind.Canvas }
    public func toElement(): Element { Element.canvas(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        "<Canvas" + frameworkAttrs(modifiers) + ">\n" + renderChildren(children) + "</Canvas>"
    }

    public func name(value: String): Canvas {
        modifiers.xName = Some(value)
        this
    }
}

public func canvas(children: Array<Element>): Canvas { Canvas.new(children) }
