package windows_reactor.core

import std.collection.*

// Scalar enums and container "def" payloads referenced by PropValue. These
// describe declarative item trees (menus, nav items, commands, tree nodes)
// that widgets flatten into a single set_prop call. Modelled as
// value-comparable types so PropValue.equals() can diff them.

// ── Scalar style/mode enums ──────────────────────────────────────────────

public enum ButtonStyle <: Equatable<ButtonStyle> {
    | Default | Accent | Subtle | TextLink
    public func tag(): Int64 {
        match (this) { case Default => 0; case Accent => 1; case Subtle => 2; case TextLink => 3 }
    }
    public operator func ==(other: ButtonStyle): Bool { tag() == other.tag() }
    public operator func !=(other: ButtonStyle): Bool { tag() != other.tag() }
}

public enum FlyoutPlacement <: Equatable<FlyoutPlacement> {
    | Top | Bottom | Left | Right | Full
    | TopEdgeAlignedLeft | TopEdgeAlignedRight | BottomEdgeAlignedLeft | BottomEdgeAlignedRight
    | LeftEdgeAlignedTop | LeftEdgeAlignedBottom | RightEdgeAlignedTop | RightEdgeAlignedBottom
    | Auto
    public func tag(): Int64 {
        match (this) {
            case Top => 0
            case Bottom => 1
            case Left => 2
            case Right => 3
            case Full => 4
            case TopEdgeAlignedLeft => 5
            case TopEdgeAlignedRight => 6
            case BottomEdgeAlignedLeft => 7
            case BottomEdgeAlignedRight => 8
            case LeftEdgeAlignedTop => 9
            case LeftEdgeAlignedBottom => 10
            case RightEdgeAlignedTop => 11
            case RightEdgeAlignedBottom => 12
            case Auto => 13
        }
    }
    public operator func ==(other: FlyoutPlacement): Bool { tag() == other.tag() }
    public operator func !=(other: FlyoutPlacement): Bool { tag() != other.tag() }
}

public enum InfoBarSeverity <: Equatable<InfoBarSeverity> {
    | Informational | Success | Warning | Error
    public func tag(): Int64 {
        match (this) { case Informational => 0; case Success => 1; case Warning => 2; case Error => 3 }
    }
    public operator func ==(other: InfoBarSeverity): Bool { tag() == other.tag() }
    public operator func !=(other: InfoBarSeverity): Bool { tag() != other.tag() }
}

public enum PasswordRevealMode <: Equatable<PasswordRevealMode> {
    | Peek | Hidden | Visible
    public func tag(): Int64 {
        match (this) { case Peek => 0; case Hidden => 1; case Visible => 2 }
    }
    public operator func ==(other: PasswordRevealMode): Bool { tag() == other.tag() }
    public operator func !=(other: PasswordRevealMode): Bool { tag() != other.tag() }
}

public enum ScrollViewScrollBarVisibility <: Equatable<ScrollViewScrollBarVisibility> {
    | Auto | Visible | Hidden
    public func tag(): Int64 {
        match (this) { case Auto => 0; case Visible => 1; case Hidden => 2 }
    }
    public operator func ==(other: ScrollViewScrollBarVisibility): Bool { tag() == other.tag() }
    public operator func !=(other: ScrollViewScrollBarVisibility): Bool { tag() != other.tag() }
}

public enum NavViewPaneDisplayMode <: Equatable<NavViewPaneDisplayMode> {
    | Auto | Left | Top | LeftCompact | LeftMinimal
    public func tag(): Int64 {
        match (this) {
            case Auto => 0; case Left => 1; case Top => 2; case LeftCompact => 3; case LeftMinimal => 4
        }
    }
    public operator func ==(other: NavViewPaneDisplayMode): Bool { tag() == other.tag() }
    public operator func !=(other: NavViewPaneDisplayMode): Bool { tag() != other.tag() }
}

public enum TreeSelectionMode <: Equatable<TreeSelectionMode> {
    | NoneSel | Single | Multiple
    public func tag(): Int64 {
        match (this) { case NoneSel => 0; case Single => 1; case Multiple => 2 }
    }
    public operator func ==(other: TreeSelectionMode): Bool { tag() == other.tag() }
    public operator func !=(other: TreeSelectionMode): Bool { tag() != other.tag() }
}

public enum CommandBarLabelPos <: Equatable<CommandBarLabelPos> {
    | Bottom | Right | Collapsed
    public func tag(): Int64 {
        match (this) { case Bottom => 0; case Right => 1; case Collapsed => 2 }
    }
    public operator func ==(other: CommandBarLabelPos): Bool { tag() == other.tag() }
    public operator func !=(other: CommandBarLabelPos): Bool { tag() != other.tag() }
}

public enum TeachingTipPlacement <: Equatable<TeachingTipPlacement> {
    | Auto | Top | Bottom | Left | Right
    | TopRight | TopLeft | BottomRight | BottomLeft
    | LeftTop | LeftBottom | RightTop | RightBottom | Center
    public func tag(): Int64 {
        match (this) {
            case Auto => 0
            case Top => 1
            case Bottom => 2
            case Left => 3
            case Right => 4
            case TopRight => 5
            case TopLeft => 6
            case BottomRight => 7
            case BottomLeft => 8
            case LeftTop => 9
            case LeftBottom => 10
            case RightTop => 11
            case RightBottom => 12
            case Center => 13
        }
    }
    public operator func ==(other: TeachingTipPlacement): Bool { tag() == other.tag() }
    public operator func !=(other: TeachingTipPlacement): Bool { tag() != other.tag() }
}

// SelectionMode for templated lists (ListView, GridView).
public enum SelectionMode <: Equatable<SelectionMode> {
    | NoneSel | Single | Multiple | Extended
    public func tag(): Int64 {
        match (this) { case NoneSel => 0; case Single => 1; case Multiple => 2; case Extended => 3 }
    }
    public operator func ==(other: SelectionMode): Bool { tag() == other.tag() }
    public operator func !=(other: SelectionMode): Bool { tag() != other.tag() }
}

public enum TemplatedKind <: Equatable<TemplatedKind> {
    | ListView | GridView | FlipView
    public func tag(): Int64 {
        match (this) { case ListView => 0; case GridView => 1; case FlipView => 2 }
    }
    public func controlKind(): ControlKind {
        match (this) {
            case ListView => ControlKind.ListView
            case GridView => ControlKind.GridView
            case FlipView => ControlKind.FlipView
        }
    }
    public operator func ==(other: TemplatedKind): Bool { tag() == other.tag() }
    public operator func !=(other: TemplatedKind): Bool { tag() != other.tag() }
}

// ── Container item defs (recursive trees flattened into a single set_prop) ──

public class NavViewItem {
    public var content: String
    public var tag: ?String = None
    public var icon: ?SymbolGlyph = None
    public var isHeader: Bool = false
    public var children: ArrayList<NavViewItem> = ArrayList<NavViewItem>()

    public init(content: String) { this.content = content }

    public static func header(content: String): NavViewItem {
        let n = NavViewItem(content)
        n.isHeader = true
        n
    }

    // Fluent builders so item trees can be assembled inline (mirrors the
    // declarative NavViewItem::new("..").tag("..").icon(..).child(..) shape).
    public func tagOf(t: String): This { this.tag = Some(t); this }
    public func iconOf(g: SymbolGlyph): This { this.icon = Some(g); this }
    public func child(c: NavViewItem): This { this.children.add(c); this }

    public func equals(other: NavViewItem): Bool {
        if (!(content == other.content && optStrEq(tag, other.tag) &&
              optEq<SymbolGlyph>(icon, other.icon) && isHeader == other.isHeader)) {
            return false
        }
        if (children.size != other.children.size) { return false }
        var i = 0
        while (i < children.size) {
            if (!children[i].equals(other.children[i])) { return false }
            i++
        }
        true
    }
}

public enum MenuItemDef {
    | Item(String)
    | Separator
    | SubItem(String, ArrayList<MenuItemDef>)

    public func equals(other: MenuItemDef): Bool {
        match ((this, other)) {
            case (Item(a), Item(b)) => a == b
            case (Separator, Separator) => true
            case (SubItem(at, ac), SubItem(bt, bc)) =>
                at == bt && menuItemListEq(ac, bc)
            case _ => false
        }
    }
}

func menuItemListEq(a: ArrayList<MenuItemDef>, b: ArrayList<MenuItemDef>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) {
        if (!a[i].equals(b[i])) { return false }
        i++
    }
    true
}

public class MenuBarItemDef {
    public var title: String
    public var items: ArrayList<MenuItemDef> = ArrayList<MenuItemDef>()
    public init(title: String) { this.title = title }

    public func equals(other: MenuBarItemDef): Bool {
        title == other.title && menuItemListEq(items, other.items)
    }
}

public class TreeNodeDef {
    public var text: String
    public var isExpanded: Bool = false
    public var children: ArrayList<TreeNodeDef> = ArrayList<TreeNodeDef>()
    public init(text: String) { this.text = text }

    public func equals(other: TreeNodeDef): Bool {
        if (!(text == other.text && isExpanded == other.isExpanded)) { return false }
        if (children.size != other.children.size) { return false }
        var i = 0
        while (i < children.size) {
            if (!children[i].equals(other.children[i])) { return false }
            i++
        }
        true
    }
}

public enum CommandBarCommandDef {
    | Button(String, ?SymbolGlyph)
    | Toggle(String, ?SymbolGlyph)
    | Separator

    public func equals(other: CommandBarCommandDef): Bool {
        match ((this, other)) {
            case (Button(al, ai), Button(bl, bi)) => al == bl && optEq<SymbolGlyph>(ai, bi)
            case (Toggle(al, ai), Toggle(bl, bi)) => al == bl && optEq<SymbolGlyph>(ai, bi)
            case (Separator, Separator) => true
            case _ => false
        }
    }
}

public class SelectorBarItemDef {
    public var text: String
    public var icon: ?SymbolGlyph = None
    public init(text: String) { this.text = text }

    public func equals(other: SelectorBarItemDef): Bool {
        text == other.text && optEq<SymbolGlyph>(icon, other.icon)
    }
}

public class FlyoutDef {
    public var text: String
    public var placement: FlyoutPlacement = FlyoutPlacement.Auto
    public init(text: String) { this.text = text }
    public init(text: String, placement: FlyoutPlacement) {
        this.text = text
        this.placement = placement
    }
}

// Elementwise equality helpers for ArrayList of def types (used by PropValue).
func navItemListEq(a: ArrayList<NavViewItem>, b: ArrayList<NavViewItem>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) { if (!a[i].equals(b[i])) { return false }; i++ }
    true
}

func cmdListEq(a: ArrayList<CommandBarCommandDef>, b: ArrayList<CommandBarCommandDef>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) { if (!a[i].equals(b[i])) { return false }; i++ }
    true
}

func menuBarListEq(a: ArrayList<MenuBarItemDef>, b: ArrayList<MenuBarItemDef>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) { if (!a[i].equals(b[i])) { return false }; i++ }
    true
}

func treeNodeListEq(a: ArrayList<TreeNodeDef>, b: ArrayList<TreeNodeDef>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) { if (!a[i].equals(b[i])) { return false }; i++ }
    true
}

func selectorListEq(a: ArrayList<SelectorBarItemDef>, b: ArrayList<SelectorBarItemDef>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) { if (!a[i].equals(b[i])) { return false }; i++ }
    true
}

func strListEq(a: ArrayList<String>, b: ArrayList<String>): Bool {
    if (a.size != b.size) { return false }
    var i = 0
    while (i < a.size) { if (a[i] != b[i]) { return false }; i++ }
    true
}
