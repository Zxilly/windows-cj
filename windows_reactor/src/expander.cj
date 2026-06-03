package windows_reactor

public enum ExpanderHeader {
    | Text(String)
    | HeaderElement(Element)
}

public class Expander <: Widget {
    public var headerValue: Option<ExpanderHeader> = None
    public var child: Element
    public var isExpanded: Bool = false
    public var onExpanded: Option<Callback<Bool>> = None
    public var modifiers: Modifiers = Modifiers()

    public init(child: Element) {
        this.child = child
    }

    public static func new(child: Element): Expander {
        Expander(child)
    }

    public func controlKind(): ControlKind { ControlKind.Expander }
    public func toElement(): Element { Element.expander(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = boolAttr("IsExpanded", isExpanded) + frameworkAttrs(modifiers)
        var header = ""
        match (headerValue) {
            case Some(ExpanderHeader.Text(text)) => attrs += attr("Header", text)
            case Some(ExpanderHeader.HeaderElement(element)) =>
                header = "<Expander.Header>\n" + renderXamlFragment(element) + "\n</Expander.Header>\n"
            case None => ()
        }
        "<Expander" + attrs + ">\n" + header + renderXamlFragment(child) + "\n</Expander>"
    }

    public func header(value: String): Expander {
        headerValue = Some(ExpanderHeader.Text(value))
        this
    }

    public func header_content(value: Element): Expander {
        headerValue = Some(ExpanderHeader.HeaderElement(value))
        this
    }

    public func expanded(value: Bool): Expander {
        isExpanded = value
        this
    }

    public func on_expanded(handler: (Bool) -> Unit): Expander {
        onExpanded = Some(Callback<Bool>(handler))
        this
    }

    public func name(value: String): Expander {
        modifiers.xName = Some(value)
        this
    }
}

public func expander(child: Element): Expander { Expander.new(child) }
