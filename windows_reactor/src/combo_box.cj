package windows_reactor

import std.collection.*

public class ComboBox <: Widget {
    public var items: ArrayList<String> = ArrayList<String>()
    public var selectedIndex: Int64 = -1
    public var modifiers: Modifiers = Modifiers()

    public init(items: Array<String>) {
        for (item in items) {
            this.items.add(item)
        }
    }

    public static func new(items: Array<String>): ComboBox {
        ComboBox(items)
    }

    public func controlKind(): ControlKind { ControlKind.ComboBox }
    public func toElement(): Element { Element.comboBox(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = frameworkAttrs(modifiers)
        if (selectedIndex >= 0) {
            attrs += rawAttr("SelectedIndex", selectedIndex.toString())
        }
        var itemsXaml = ""
        for (item in items) {
            itemsXaml += "<ComboBoxItem" + attr("Content", item) + " />\n"
        }
        "<ComboBox" + attrs + ">\n" + itemsXaml + "</ComboBox>"
    }

    public func selected_index(index: Int64): ComboBox {
        selectedIndex = index
        this
    }

    public func name(value: String): ComboBox {
        modifiers.xName = Some(value)
        this
    }
}

public func combo_box(items: Array<String>): ComboBox { ComboBox.new(items) }
