package windows_reactor

public enum PasswordRevealMode <: Equatable<PasswordRevealMode> {
    | Peek | Hidden | Visible

    public func code(): Int64 {
        match (this) {
            case Peek => 0
            case Hidden => 1
            case Visible => 2
        }
    }

    public operator func ==(other: PasswordRevealMode): Bool {
        code() == other.code()
    }

    public operator func !=(other: PasswordRevealMode): Bool {
        !(this == other)
    }
}

func passwordRevealModeText(value: PasswordRevealMode): String {
    match (value) {
        case PasswordRevealMode.Peek => "Peek"
        case PasswordRevealMode.Hidden => "Hidden"
        case PasswordRevealMode.Visible => "Visible"
    }
}

public class PasswordBox <: Widget {
    public var revealMode: PasswordRevealMode = PasswordRevealMode.Peek
    public var isEnabled: Bool = true
    public var modifiers: Modifiers = Modifiers()

    public init() {}

    public static func new(): PasswordBox {
        PasswordBox()
    }

    public func controlKind(): ControlKind { ControlKind.PasswordBox }
    public func toElement(): Element { Element.passwordBox(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        "<PasswordBox" + attr("PasswordRevealMode", passwordRevealModeText(revealMode)) +
            boolAttr("IsEnabled", isEnabled) + frameworkAttrs(modifiers) + " />"
    }

    public func name(value: String): PasswordBox {
        modifiers.xName = Some(value)
        this
    }
}

public func password_box(): PasswordBox { PasswordBox.new() }
