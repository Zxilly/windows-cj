package windows_reactor

public class CheckBox <: Widget {
    public var isChecked: Bool
    public var labelValue: Option<String> = None
    public var isEnabled: Bool = true
    public var onChanged: Option<Callback<Bool>> = None
    public var modifiers: Modifiers = Modifiers()

    public init(isChecked: Bool) {
        this.isChecked = isChecked
    }

    public static func new(isChecked: Bool): CheckBox {
        CheckBox(isChecked)
    }

    public func controlKind(): ControlKind { ControlKind.CheckBox }
    public func toElement(): Element { Element.checkBox(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = boolAttr("IsChecked", isChecked) + boolAttr("IsEnabled", isEnabled) +
            frameworkAttrs(modifiers) + paddingAttr(modifiers)
        match (labelValue) {
            case Some(label) => attrs += attr("Content", label)
            case None => ()
        }
        "<CheckBox" + attrs + " />"
    }

    public func on_changed(handler: (Bool) -> Unit): CheckBox {
        onChanged = Some(Callback<Bool>(handler))
        this
    }

    public func label(value: String): CheckBox {
        labelValue = Some(value)
        this
    }

    public func enabled(value: Bool): CheckBox {
        isEnabled = value
        this
    }

    public func name(value: String): CheckBox {
        modifiers.xName = Some(value)
        this
    }
}

public func check_box(isChecked: Bool): CheckBox { CheckBox.new(isChecked) }
