package windows_reactor.core

// Per-element pointer / tap callbacks carried on Modifiers.pointerHandlers.
// Mirrors the universal UIElement pointer events.

public struct PointerEventInfo <: Equatable<PointerEventInfo> {
    public let isLeftButtonPressed: Bool
    public let isRightButtonPressed: Bool
    public let isMiddleButtonPressed: Bool

    public init(left: Bool, right: Bool, middle: Bool) {
        this.isLeftButtonPressed = left
        this.isRightButtonPressed = right
        this.isMiddleButtonPressed = middle
    }
    public init() {
        this.isLeftButtonPressed = false
        this.isRightButtonPressed = false
        this.isMiddleButtonPressed = false
    }

    public operator func ==(other: PointerEventInfo): Bool {
        isLeftButtonPressed == other.isLeftButtonPressed &&
        isRightButtonPressed == other.isRightButtonPressed &&
        isMiddleButtonPressed == other.isMiddleButtonPressed
    }
    public operator func !=(other: PointerEventInfo): Bool { !(this == other) }
}

// Bundle of per-element pointer / tap callbacks; each slot is individually
// optional. Class so it can be carried on Modifiers and mutated by the builder.
public class PointerHandlers {
    public var onTapped: ?Callback<Unit> = None
    public var onRightTapped: ?Callback<Unit> = None
    public var onPointerPressed: ?Callback<PointerEventInfo> = None
    public var onPointerReleased: ?Callback<PointerEventInfo> = None
    public var onPointerExited: ?Callback<Unit> = None

    public init() {}

    public func isEmpty(): Bool {
        onTapped.isNone() && onRightTapped.isNone() && onPointerPressed.isNone() &&
        onPointerReleased.isNone() && onPointerExited.isNone()
    }

    public func equals(other: PointerHandlers): Bool {
        cbUnitEq(onTapped, other.onTapped) &&
        cbUnitEq(onRightTapped, other.onRightTapped) &&
        cbInfoEq(onPointerPressed, other.onPointerPressed) &&
        cbInfoEq(onPointerReleased, other.onPointerReleased) &&
        cbUnitEq(onPointerExited, other.onPointerExited)
    }

    public func clone(): PointerHandlers {
        let c = PointerHandlers()
        c.onTapped = onTapped
        c.onRightTapped = onRightTapped
        c.onPointerPressed = onPointerPressed
        c.onPointerReleased = onPointerReleased
        c.onPointerExited = onPointerExited
        c
    }
}

func cbUnitEq(a: ?Callback<Unit>, b: ?Callback<Unit>): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.sameAs(y)
        case (None, None) => true
        case _ => false
    }
}

func cbInfoEq(a: ?Callback<PointerEventInfo>, b: ?Callback<PointerEventInfo>): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.sameAs(y)
        case (None, None) => true
        case _ => false
    }
}
