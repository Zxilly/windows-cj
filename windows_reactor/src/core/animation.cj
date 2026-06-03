package windows_reactor.core

// Animation configuration carried on Modifiers.animations and applied via the
// backend's set_implicit_transitions / set_layout_animation /
// run_property_animation. Durations are expressed as Float64 milliseconds
// (behaviour-equivalent payloads; the WinUI backend converts to TimeSpan).

public struct ScalarTransition <: Equatable<ScalarTransition> {
    public let durationMs: Float64
    public init(durationMs: Float64) { this.durationMs = durationMs }
    public operator func ==(other: ScalarTransition): Bool { durationMs == other.durationMs }
    public operator func !=(other: ScalarTransition): Bool { durationMs != other.durationMs }
}

public enum Vector3Axes <: Equatable<Vector3Axes> {
    | X | Y | Z | Xy | All
    public func tag(): Int64 {
        match (this) {
            case X => 0
            case Y => 1
            case Z => 2
            case Xy => 3
            case All => 4
        }
    }
    public operator func ==(other: Vector3Axes): Bool { tag() == other.tag() }
    public operator func !=(other: Vector3Axes): Bool { tag() != other.tag() }
}

public struct Vector3Transition <: Equatable<Vector3Transition> {
    public let durationMs: Float64
    public let components: Vector3Axes
    public init(durationMs: Float64, components: Vector3Axes) {
        this.durationMs = durationMs
        this.components = components
    }
    public init(durationMs: Float64) {
        this.durationMs = durationMs
        this.components = Vector3Axes.All
    }
    public operator func ==(other: Vector3Transition): Bool {
        durationMs == other.durationMs && components == other.components
    }
    public operator func !=(other: Vector3Transition): Bool { !(this == other) }
}

public class ImplicitTransitions {
    public var opacity: ?ScalarTransition = None
    public var rotation: ?ScalarTransition = None
    public var scale: ?Vector3Transition = None
    public var translation: ?Vector3Transition = None
    public init() {}

    public func isEmpty(): Bool {
        opacity.isNone() && rotation.isNone() && scale.isNone() && translation.isNone()
    }

    public func equals(other: ImplicitTransitions): Bool {
        optEq<ScalarTransition>(opacity, other.opacity) &&
        optEq<ScalarTransition>(rotation, other.rotation) &&
        optEq<Vector3Transition>(scale, other.scale) &&
        optEq<Vector3Transition>(translation, other.translation)
    }
}

public enum Easing <: Equatable<Easing> {
    | Linear | EaseOut | EaseIn | EaseInOut
    public func tag(): Int64 {
        match (this) {
            case Linear => 0
            case EaseOut => 1
            case EaseIn => 2
            case EaseInOut => 3
        }
    }
    public operator func ==(other: Easing): Bool { tag() == other.tag() }
    public operator func !=(other: Easing): Bool { tag() != other.tag() }
}

public class LayoutAnimationConfig {
    public var durationMs: Float64 = 300.0
    public var useSpring: Bool = false
    public var dampingRatio: Float32 = 0.6
    public var period: Float32 = 0.08
    public var animateOffset: Bool = true
    public var animateSize: Bool = false
    public init() {}

    public func equals(other: LayoutAnimationConfig): Bool {
        durationMs == other.durationMs && useSpring == other.useSpring &&
        dampingRatio == other.dampingRatio && period == other.period &&
        animateOffset == other.animateOffset && animateSize == other.animateSize
    }
}

public class AnimationConfig {
    public var opacity: ?Float64 = None
    public var scale: ?Float64 = None
    public var durationMs: Float64 = 300.0
    public var easing: Easing = Easing.EaseOut
    public init() {}

    public func equals(other: AnimationConfig): Bool {
        optF64Eq(opacity, other.opacity) && optF64Eq(scale, other.scale) &&
        durationMs == other.durationMs && easing == other.easing
    }
}

public class AnimationModifiers {
    public var implicitTransitions: ?ImplicitTransitions = None
    public var layoutAnimation: ?LayoutAnimationConfig = None
    public var propertyAnimation: ?AnimationConfig = None
    public var enterTransition: ?AnimationConfig = None
    public var exitTransition: ?AnimationConfig = None
    public init() {}

    public func isEmpty(): Bool {
        let itEmpty = match (implicitTransitions) {
            case Some(t) => t.isEmpty()
            case None => true
        }
        itEmpty && layoutAnimation.isNone() && propertyAnimation.isNone() &&
        enterTransition.isNone() && exitTransition.isNone()
    }
}
