package windows_reactor.core

import std.collection.*

// Grid placement fast-path (avoids a type-erased attached-prop bag for the
// most common attached property).
public struct GridPlacement <: Equatable<GridPlacement> {
    public let row: Int32
    public let column: Int32
    public let rowSpan: Int32
    public let columnSpan: Int32

    public init(row: Int32, column: Int32, rowSpan: Int32, columnSpan: Int32) {
        this.row = row
        this.column = column
        this.rowSpan = rowSpan
        this.columnSpan = columnSpan
    }
    public static func default(): GridPlacement { GridPlacement(0, 0, 1, 1) }

    public operator func ==(other: GridPlacement): Bool {
        row == other.row && column == other.column &&
        rowSpan == other.rowSpan && columnSpan == other.columnSpan
    }
    public operator func !=(other: GridPlacement): Bool { !(this == other) }
}

// Canvas placement attached props (Canvas.Left / Canvas.Top / Canvas.ZIndex).
// Downgraded from the reference type-erased AttachedProps bag to a named field.
public struct CanvasPosition <: Equatable<CanvasPosition> {
    public let left: Float64
    public let top: Float64
    public let zIndex: Int32
    public init(left: Float64, top: Float64, zIndex: Int32) {
        this.left = left
        this.top = top
        this.zIndex = zIndex
    }
    public static func default(): CanvasPosition { CanvasPosition(0.0, 0.0, 0) }
    public operator func ==(other: CanvasPosition): Bool {
        left == other.left && top == other.top && zIndex == other.zIndex
    }
    public operator func !=(other: CanvasPosition): Bool { !(this == other) }
}

// RelativePanel alignment attached props. Likewise a named field instead of
// the type-erased bag.
public struct RelativePanelAlignment <: Equatable<RelativePanelAlignment> {
    public let alignLeftWithPanel: Bool
    public let alignRightWithPanel: Bool
    public let alignTopWithPanel: Bool
    public let alignBottomWithPanel: Bool
    public let alignHCenterWithPanel: Bool
    public let alignVCenterWithPanel: Bool

    public init(l: Bool, r: Bool, t: Bool, b: Bool, h: Bool, v: Bool) {
        this.alignLeftWithPanel = l
        this.alignRightWithPanel = r
        this.alignTopWithPanel = t
        this.alignBottomWithPanel = b
        this.alignHCenterWithPanel = h
        this.alignVCenterWithPanel = v
    }
    public static func default(): RelativePanelAlignment {
        RelativePanelAlignment(false, false, false, false, false, false)
    }
    public operator func ==(other: RelativePanelAlignment): Bool {
        alignLeftWithPanel == other.alignLeftWithPanel &&
        alignRightWithPanel == other.alignRightWithPanel &&
        alignTopWithPanel == other.alignTopWithPanel &&
        alignBottomWithPanel == other.alignBottomWithPanel &&
        alignHCenterWithPanel == other.alignHCenterWithPanel &&
        alignVCenterWithPanel == other.alignVCenterWithPanel
    }
    public operator func !=(other: RelativePanelAlignment): Bool { !(this == other) }
}

// ============================================================================
// Modifiers — visual / layout / attached props shared by every widget.
// Class (mutable, possibly shared across builder chains). All fields Option;
// the extension bag fields are plain Option references (GC, no Box). The
// attached-prop bag is downgraded to named canvasPosition / relativeAlign
// fields. equivalent() does value comparison (no derive(PartialEq)).
// ============================================================================

public class Modifiers {
    public var margin: ?Thickness = None
    public var padding: ?Thickness = None
    public var width: ?Float64 = None
    public var height: ?Float64 = None
    public var minWidth: ?Float64 = None
    public var maxWidth: ?Float64 = None
    public var minHeight: ?Float64 = None
    public var maxHeight: ?Float64 = None
    public var horizontalAlignment: ?HorizontalAlignment = None
    public var verticalAlignment: ?VerticalAlignment = None
    public var opacity: ?Float64 = None
    public var background: ?Brush = None
    public var foreground: ?Brush = None
    public var fontFamily: ?String = None
    public var fontSize: ?Float64 = None
    // Extension bag (GC references, no Box).
    public var themeBindings: ?HashMap<Prop, ThemeRef> = None
    public var animations: ?AnimationModifiers = None
    public var accessibility: ?AccessibilityModifiers = None
    public var keyboardAccelerators: ?ArrayList<KeyboardAccelerator> = None
    public var tooltip: ?Tooltip = None
    public var pointerHandlers: ?PointerHandlers = None
    public var resources: ?HashMap<String, String> = None
    // Attached-prop fast-paths / named fields.
    public var grid: ?GridPlacement = None
    public var canvasPosition: ?CanvasPosition = None
    public var relativeAlign: ?RelativePanelAlignment = None

    public init() {}

    public func isEmpty(): Bool {
        let tbEmpty = match (themeBindings) {
            case Some(m) => m.size == 0
            case None => true
        }
        let animEmpty = match (animations) {
            case Some(a) => a.isEmpty()
            case None => true
        }
        let a11yEmpty = match (accessibility) {
            case Some(a) => a.isEmpty()
            case None => true
        }
        let kaEmpty = match (keyboardAccelerators) {
            case Some(k) => k.size == 0
            case None => true
        }
        let ptrEmpty = match (pointerHandlers) {
            case Some(p) => p.isEmpty()
            case None => true
        }
        let resEmpty = match (resources) {
            case Some(r) => r.size == 0
            case None => true
        }
        margin.isNone() && padding.isNone() && width.isNone() && height.isNone() &&
        minWidth.isNone() && maxWidth.isNone() && minHeight.isNone() && maxHeight.isNone() &&
        horizontalAlignment.isNone() && verticalAlignment.isNone() && opacity.isNone() &&
        background.isNone() && foreground.isNone() && fontFamily.isNone() && fontSize.isNone() &&
        tbEmpty && animEmpty && a11yEmpty && kaEmpty && tooltip.isNone() && ptrEmpty &&
        grid.isNone() && canvasPosition.isNone() && relativeAlign.isNone() && resEmpty
    }

    // Whether any non-empty theme binding is present — gates can_skip_update.
    public func hasThemeBindings(): Bool {
        match (themeBindings) {
            case Some(m) => m.size > 0
            case None => false
        }
    }

    public func equivalent(other: Modifiers): Bool {
        optEq<Thickness>(margin, other.margin) &&
        optEq<Thickness>(padding, other.padding) &&
        optF64Eq(width, other.width) && optF64Eq(height, other.height) &&
        optF64Eq(minWidth, other.minWidth) && optF64Eq(maxWidth, other.maxWidth) &&
        optF64Eq(minHeight, other.minHeight) && optF64Eq(maxHeight, other.maxHeight) &&
        optEq<HorizontalAlignment>(horizontalAlignment, other.horizontalAlignment) &&
        optEq<VerticalAlignment>(verticalAlignment, other.verticalAlignment) &&
        optF64Eq(opacity, other.opacity) &&
        optEq<Brush>(background, other.background) &&
        optEq<Brush>(foreground, other.foreground) &&
        optStrEq(fontFamily, other.fontFamily) && optF64Eq(fontSize, other.fontSize) &&
        themeBindingsEq(themeBindings, other.themeBindings) &&
        animsEq(animations, other.animations) &&
        a11yEq(accessibility, other.accessibility) &&
        accelsEq(keyboardAccelerators, other.keyboardAccelerators) &&
        tooltipEq(tooltip, other.tooltip) &&
        pointersEq(pointerHandlers, other.pointerHandlers) &&
        optEq<GridPlacement>(grid, other.grid) &&
        optEq<CanvasPosition>(canvasPosition, other.canvasPosition) &&
        optEq<RelativePanelAlignment>(relativeAlign, other.relativeAlign) &&
        resourcesOptEq(resources, other.resources)
    }
}

func themeBindingsEq(a: ?HashMap<Prop, ThemeRef>, b: ?HashMap<Prop, ThemeRef>): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) =>
            if (x.size != y.size) { return false }
            for ((k, v) in x) {
                match (y.get(k)) {
                    case Some(yv) => if (yv != v) { return false }
                    case None => return false
                }
            }
            true
        case (None, None) => true
        case (Some(x), None) => x.size == 0
        case (None, Some(y)) => y.size == 0
    }
}

func resourcesOptEq(a: ?HashMap<String, String>, b: ?HashMap<String, String>): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => resourcesEq(x, y)
        case (None, None) => true
        case (Some(x), None) => x.size == 0
        case (None, Some(y)) => y.size == 0
    }
}

func animsEq(a: ?AnimationModifiers, b: ?AnimationModifiers): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => animModEq(x, y)
        case (None, None) => true
        case (Some(x), None) => x.isEmpty()
        case (None, Some(y)) => y.isEmpty()
    }
}

func animModEq(x: AnimationModifiers, y: AnimationModifiers): Bool {
    let itEq = match ((x.implicitTransitions, y.implicitTransitions)) {
        case (Some(a), Some(b)) => a.equals(b)
        case (None, None) => true
        case _ => false
    }
    let laEq = match ((x.layoutAnimation, y.layoutAnimation)) {
        case (Some(a), Some(b)) => a.equals(b)
        case (None, None) => true
        case _ => false
    }
    let paEq = match ((x.propertyAnimation, y.propertyAnimation)) {
        case (Some(a), Some(b)) => a.equals(b)
        case (None, None) => true
        case _ => false
    }
    let etEq = match ((x.enterTransition, y.enterTransition)) {
        case (Some(a), Some(b)) => a.equals(b)
        case (None, None) => true
        case _ => false
    }
    let xtEq = match ((x.exitTransition, y.exitTransition)) {
        case (Some(a), Some(b)) => a.equals(b)
        case (None, None) => true
        case _ => false
    }
    itEq && laEq && paEq && etEq && xtEq
}

func a11yEq(a: ?AccessibilityModifiers, b: ?AccessibilityModifiers): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case (Some(x), None) => x.isEmpty()
        case (None, Some(y)) => y.isEmpty()
    }
}

func accelsEq(a: ?ArrayList<KeyboardAccelerator>, b: ?ArrayList<KeyboardAccelerator>): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) =>
            if (x.size != y.size) { return false }
            var i = 0
            while (i < x.size) {
                if (!x[i].equals(y[i])) { return false }
                i++
            }
            true
        case (None, None) => true
        case (Some(x), None) => x.size == 0
        case (None, Some(y)) => y.size == 0
    }
}

func tooltipEq(a: ?Tooltip, b: ?Tooltip): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case _ => false
    }
}

func pointersEq(a: ?PointerHandlers, b: ?PointerHandlers): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case (Some(x), None) => x.isEmpty()
        case (None, Some(y)) => y.isEmpty()
    }
}
