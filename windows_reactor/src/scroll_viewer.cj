package windows_reactor

func scrollBarVisibilityText(value: ScrollBarVisibility): String {
    match (value) {
        case ScrollBarVisibility.Disabled => "Disabled"
        case ScrollBarVisibility.Auto => "Auto"
        case ScrollBarVisibility.Hidden => "Hidden"
        case ScrollBarVisibility.Visible => "Visible"
    }
}

public class ScrollViewer <: Widget {
    public var child: Element
    public var horizontalScrollBarVisibility: ScrollBarVisibility = ScrollBarVisibility.Disabled
    public var verticalScrollBarVisibility: ScrollBarVisibility = ScrollBarVisibility.Auto
    public var modifiers: Modifiers = Modifiers()

    public init(child: Element) {
        this.child = child
    }

    public static func new(child: Element): ScrollViewer {
        ScrollViewer(child)
    }

    public func controlKind(): ControlKind { ControlKind.ScrollViewer }
    public func toElement(): Element { Element.scrollViewer(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        "<ScrollViewer" + attr("HorizontalScrollBarVisibility", scrollBarVisibilityText(horizontalScrollBarVisibility)) +
            attr("VerticalScrollBarVisibility", scrollBarVisibilityText(verticalScrollBarVisibility)) +
            frameworkAttrs(modifiers) + ">\n" + renderXamlFragment(child) + "\n</ScrollViewer>"
    }

    public func horizontal_scroll_bar_visibility(value: ScrollBarVisibility): ScrollViewer {
        horizontalScrollBarVisibility = value
        this
    }

    public func vertical_scroll_bar_visibility(value: ScrollBarVisibility): ScrollViewer {
        verticalScrollBarVisibility = value
        this
    }

    public func name(value: String): ScrollViewer {
        modifiers.xName = Some(value)
        this
    }
}

public func scroll_viewer(child: Element): ScrollViewer { ScrollViewer.new(child) }
