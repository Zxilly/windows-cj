package windows_reactor

public class RadioButton <: Widget {
    public var labelValue: Option<String> = None
    public var isChecked: Bool = false
    public var groupName: Option<String> = None
    public var isEnabled: Bool = true
    public var onChecked: Option<Callback<Unit>> = None
    public var modifiers: Modifiers = Modifiers()

    public init(label: String) {
        this.labelValue = Some(label)
    }

    public static func new(label: String): RadioButton {
        RadioButton(label)
    }

    public func controlKind(): ControlKind { ControlKind.RadioButton }
    public func toElement(): Element { Element.radioButton(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = boolAttr("IsChecked", isChecked) + boolAttr("IsEnabled", isEnabled) +
            frameworkAttrs(modifiers) + paddingAttr(modifiers)
        match (labelValue) {
            case Some(label) => attrs += attr("Content", label)
            case None => ()
        }
        match (groupName) {
            case Some(name) => attrs += attr("GroupName", name)
            case None => ()
        }
        "<RadioButton" + attrs + " />"
    }

    public func checked(value: Bool): RadioButton {
        isChecked = value
        this
    }

    public func on_checked(handler: () -> Unit): RadioButton {
        onChecked = Some(Callback<Unit>({ _: Unit => handler() }))
        this
    }

    public func group(value: String): RadioButton {
        groupName = Some(value)
        this
    }

    public func enabled(value: Bool): RadioButton {
        isEnabled = value
        this
    }

    public func name(value: String): RadioButton {
        modifiers.xName = Some(value)
        this
    }
}

public func radio_button(label: String): RadioButton { RadioButton.new(label) }
