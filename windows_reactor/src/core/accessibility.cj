package windows_reactor.core

// UI Automation properties applied to every widget kind via
// Modifiers.accessibility. Class (not struct) so it can be shared/mutated by
// the element builder chain; equality is value-based via equals().
public class AccessibilityModifiers {
    public var automationName: ?String = None
    public var automationId: ?String = None
    public var helpText: ?String = None
    public var liveSetting: ?LiveSetting = None
    public var headingLevel: ?HeadingLevel = None

    public init() {}

    public func isEmpty(): Bool {
        automationName.isNone() && automationId.isNone() && helpText.isNone() &&
        liveSetting.isNone() && headingLevel.isNone()
    }

    public func equals(other: AccessibilityModifiers): Bool {
        optStrEq(automationName, other.automationName) &&
        optStrEq(automationId, other.automationId) &&
        optStrEq(helpText, other.helpText) &&
        optLiveEq(liveSetting, other.liveSetting) &&
        optHeadingEq(headingLevel, other.headingLevel)
    }

    public func clone(): AccessibilityModifiers {
        let c = AccessibilityModifiers()
        c.automationName = automationName
        c.automationId = automationId
        c.helpText = helpText
        c.liveSetting = liveSetting
        c.headingLevel = headingLevel
        c
    }
}

func optLiveEq(a: ?LiveSetting, b: ?LiveSetting): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

func optHeadingEq(a: ?HeadingLevel, b: ?HeadingLevel): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

public enum LiveSetting <: Equatable<LiveSetting> {
    | Off | Polite | Assertive

    public func tag(): Int64 {
        match (this) {
            case Off => 0
            case Polite => 1
            case Assertive => 2
        }
    }
    public operator func ==(other: LiveSetting): Bool { tag() == other.tag() }
    public operator func !=(other: LiveSetting): Bool { tag() != other.tag() }
}

public enum HeadingLevel <: Equatable<HeadingLevel> {
    | Level1 | Level2 | Level3 | Level4 | Level5 | Level6 | Level7 | Level8 | Level9

    public func tag(): Int64 {
        match (this) {
            case Level1 => 1
            case Level2 => 2
            case Level3 => 3
            case Level4 => 4
            case Level5 => 5
            case Level6 => 6
            case Level7 => 7
            case Level8 => 8
            case Level9 => 9
        }
    }
    public operator func ==(other: HeadingLevel): Bool { tag() == other.tag() }
    public operator func !=(other: HeadingLevel): Bool { tag() != other.tag() }
}
