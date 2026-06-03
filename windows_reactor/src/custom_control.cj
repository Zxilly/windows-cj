package windows_reactor

import std.collection.*

public struct CustomProperty <: Equatable<CustomProperty> {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }

    public operator func ==(other: CustomProperty): Bool {
        name == other.name && value == other.value
    }

    public operator func !=(other: CustomProperty): Bool {
        !(this == other)
    }
}

// Escape hatch: emits an arbitrary XAML element by type name, with raw
// property attributes and optional children. Used for controls without a
// first-class widget representation.
public class CustomControl <: Widget {
    public let typeName: String
    public var properties: ArrayList<CustomProperty> = ArrayList<CustomProperty>()
    public var childrenValue: ArrayList<Element> = ArrayList<Element>()
    public var modifiers: Modifiers = Modifiers()

    public init(typeName: String) {
        this.typeName = typeName
    }

    public static func new(typeName: String): CustomControl {
        CustomControl(typeName)
    }

    public func controlKind(): ControlKind { ControlKind.Custom }
    public func toElement(): Element { Element.custom(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = frameworkAttrs(modifiers) + paddingAttr(modifiers)
        for (property in properties) {
            attrs += attr(property.name, property.value)
        }
        if (childrenValue.size == 0) {
            return "<" + typeName + attrs + " />"
        }
        "<" + typeName + attrs + ">\n" + renderChildren(childrenValue) + "</" + typeName + ">"
    }

    public func property(name: String, value: String): CustomControl {
        properties.add(CustomProperty(name, value))
        this
    }

    public func child(value: Element): CustomControl {
        childrenValue.add(value)
        this
    }

    public func children(values: Array<Element>): CustomControl {
        for (value in values) {
            childrenValue.add(value)
        }
        this
    }

    public func name(value: String): CustomControl {
        modifiers.xName = Some(value)
        this
    }
}

public func custom_control(typeName: String): CustomControl { CustomControl.new(typeName) }
