package windows_reactor

import std.collection.*

public class RadioButtons <: Widget {
    public var items: ArrayList<String> = ArrayList<String>()
    public var selectedIndex: Int64 = -1
    public var modifiers: Modifiers = Modifiers()

    public init(items: Array<String>) {
        for (item in items) {
            this.items.add(item)
        }
    }

    public static func new(items: Array<String>): RadioButtons {
        RadioButtons(items)
    }

    public func controlKind(): ControlKind { ControlKind.RadioButtons }
    public func toElement(): Element { Element.radioButtons(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    // Rendered as a StackPanel of RadioButton children (one per item), with the
    // selected index checked. Mirrors the existing renderer output.
    public func renderXaml(): String {
        var children = ArrayList<Element>()
        var index: Int64 = 0
        for (item in items) {
            children.add(Element.radioButton(radio_button(item).checked(index == selectedIndex)))
            index += 1
        }
        let panel = StackPanel()
        panel.children = children
        panel.modifiers = modifiers
        panel.renderXaml()
    }

    public func selected_index(index: Int64): RadioButtons {
        selectedIndex = index
        this
    }

    public func name(value: String): RadioButtons {
        modifiers.xName = Some(value)
        this
    }
}

public func radio_buttons(items: Array<String>): RadioButtons { RadioButtons.new(items) }
