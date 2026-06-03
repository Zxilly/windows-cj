package windows_reactor

import std.collection.*

func renderGridLength(value: GridLength): String {
    match (value) {
        case GridLength.Auto => "Auto"
        case GridLength.Star(weight) =>
            if (weight == 1.0) { "*" } else { weight.toString() + "*" }
        case GridLength.Pixel(px) => px.toString()
    }
}

func renderGridDefinitions(values: ArrayList<GridLength>, tagName: String): String {
    var out = ""
    for (value in values) {
        out += "<" + tagName + "Definition " + if (tagName == "Row") { "Height" } else { "Width" } +
            "=\"" + renderGridLength(value) + "\" />\n"
    }
    out
}

public class Grid <: Widget {
    public var rowsValue: ArrayList<GridLength> = ArrayList<GridLength>()
    public var columnsValue: ArrayList<GridLength> = ArrayList<GridLength>()
    public var rowSpacing: Option<Float64> = None
    public var columnSpacing: Option<Float64> = None
    public var children: ArrayList<Element> = ArrayList<Element>()
    public var modifiers: Modifiers = Modifiers()

    public init(children: Array<Element>) {
        for (child in children) {
            this.children.add(child)
        }
    }

    public static func new(children: Array<Element>): Grid {
        Grid(children)
    }

    public func controlKind(): ControlKind { ControlKind.Grid }
    public func toElement(): Element { Element.grid(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = frameworkAttrs(modifiers)
        match (rowSpacing) {
            case Some(spacing) => attrs += floatAttr("RowSpacing", spacing)
            case None => ()
        }
        match (columnSpacing) {
            case Some(spacing) => attrs += floatAttr("ColumnSpacing", spacing)
            case None => ()
        }
        var body = ""
        if (rowsValue.size > 0) {
            body += "<Grid.RowDefinitions>\n" + renderGridDefinitions(rowsValue, "Row") + "</Grid.RowDefinitions>\n"
        }
        if (columnsValue.size > 0) {
            body += "<Grid.ColumnDefinitions>\n" + renderGridDefinitions(columnsValue, "Column") + "</Grid.ColumnDefinitions>\n"
        }
        body += renderChildren(children)
        "<Grid" + attrs + ">\n" + body + "</Grid>"
    }

    public func rows(values: Array<GridLength>): Grid {
        rowsValue = ArrayList<GridLength>()
        for (value in values) {
            rowsValue.add(value)
        }
        this
    }

    public func columns(values: Array<GridLength>): Grid {
        columnsValue = ArrayList<GridLength>()
        for (value in values) {
            columnsValue.add(value)
        }
        this
    }

    public func row_spacing(value: Float64): Grid {
        rowSpacing = Some(value)
        this
    }

    public func column_spacing(value: Float64): Grid {
        columnSpacing = Some(value)
        this
    }

    public func name(value: String): Grid {
        modifiers.xName = Some(value)
        this
    }
}

public func grid(children: Array<Element>): Grid { Grid.new(children) }
