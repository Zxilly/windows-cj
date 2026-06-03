package windows_reactor.core

// Tooltip data model carried on Modifiers.tooltip and applied via WinUI
// ToolTipService (an attached property on FrameworkElement).

public enum TooltipPlacement <: Equatable<TooltipPlacement> {
    | Top | Bottom | Left | Right | Mouse

    public func tag(): Int64 {
        match (this) {
            case Top => 0
            case Bottom => 1
            case Left => 2
            case Right => 3
            case Mouse => 4
        }
    }
    public operator func ==(other: TooltipPlacement): Bool { tag() == other.tag() }
    public operator func !=(other: TooltipPlacement): Bool { tag() != other.tag() }
}

// Tooltip payload: a plain string or a templated child element. Element is a
// reference type so the Rich variant carries it directly (no Box).
public enum TooltipContent {
    | Text(String)
    | Rich(Element)

    public func equals(other: TooltipContent): Bool {
        match ((this, other)) {
            case (Text(a), Text(b)) => a == b
            case (Rich(a), Rich(b)) => elementEquivalent(a, b)
            case _ => false
        }
    }
}

public class Tooltip {
    public var content: TooltipContent
    public var placement: ?TooltipPlacement = None

    public init(content: TooltipContent) {
        this.content = content
    }

    public static func text(s: String): Tooltip {
        Tooltip(TooltipContent.Text(s))
    }

    public static func rich(element: Element): Tooltip {
        Tooltip(TooltipContent.Rich(element))
    }

    public func withPlacement(p: TooltipPlacement): Tooltip {
        this.placement = Some(p)
        this
    }

    public func equals(other: Tooltip): Bool {
        content.equals(other.content) && optEq<TooltipPlacement>(placement, other.placement)
    }

    public func clone(): Tooltip {
        let c = Tooltip(content)
        c.placement = placement
        c
    }
}
