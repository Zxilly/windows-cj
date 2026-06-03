package windows_reactor

public class ToggleSwitch <: Widget {
    public var isOn: Bool
    public var onContent: Option<String> = None
    public var offContent: Option<String> = None
    public var headerText: Option<String> = None
    public var isEnabled: Bool = true
    public var onChanged: Option<Callback<Bool>> = None
    public var modifiers: Modifiers = Modifiers()

    public init(isOn: Bool) {
        this.isOn = isOn
    }

    public static func new(isOn: Bool): ToggleSwitch {
        ToggleSwitch(isOn)
    }

    public func controlKind(): ControlKind { ControlKind.ToggleSwitch }
    public func toElement(): Element { Element.toggleSwitch(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = boolAttr("IsOn", isOn) + boolAttr("IsEnabled", isEnabled) + frameworkAttrs(modifiers)
        match (onContent) {
            case Some(text) => attrs += attr("OnContent", text)
            case None => ()
        }
        match (offContent) {
            case Some(text) => attrs += attr("OffContent", text)
            case None => ()
        }
        match (headerText) {
            case Some(text) => attrs += attr("Header", text)
            case None => ()
        }
        "<ToggleSwitch" + attrs + " />"
    }

    public func on_changed(handler: (Bool) -> Unit): ToggleSwitch {
        onChanged = Some(Callback<Bool>(handler))
        this
    }

    public func on_content(value: String): ToggleSwitch {
        onContent = Some(value)
        this
    }

    public func off_content(value: String): ToggleSwitch {
        offContent = Some(value)
        this
    }

    public func header(value: String): ToggleSwitch {
        headerText = Some(value)
        this
    }

    public func enabled(value: Bool): ToggleSwitch {
        isEnabled = value
        this
    }

    public func name(value: String): ToggleSwitch {
        modifiers.xName = Some(value)
        this
    }
}

public func toggle_switch(isOn: Bool): ToggleSwitch { ToggleSwitch.new(isOn) }
