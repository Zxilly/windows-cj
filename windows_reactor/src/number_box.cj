package windows_reactor

public class NumberBox <: Widget {
    public var value: Float64
    public var minimum: Option<Float64> = None
    public var maximum: Option<Float64> = None
    public var headerText: Option<String> = None
    public var isEnabled: Bool = true
    public var onValueChanged: Option<Callback<Float64>> = None
    public var modifiers: Modifiers = Modifiers()

    public init(value: Float64) {
        this.value = value
    }

    public static func new(value: Float64): NumberBox {
        NumberBox(value)
    }

    public func controlKind(): ControlKind { ControlKind.NumberBox }
    public func toElement(): Element { Element.numberBox(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = floatAttr("Value", value) + boolAttr("IsEnabled", isEnabled) + frameworkAttrs(modifiers)
        match (minimum) {
            case Some(minimum) => attrs += floatAttr("Minimum", minimum)
            case None => ()
        }
        match (maximum) {
            case Some(maximum) => attrs += floatAttr("Maximum", maximum)
            case None => ()
        }
        match (headerText) {
            case Some(text) => attrs += attr("Header", text)
            case None => ()
        }
        "<NumberBox" + attrs + " />"
    }

    public func range(min: Float64, max: Float64): NumberBox {
        minimum = Some(min)
        maximum = Some(max)
        this
    }

    public func header(value: String): NumberBox {
        headerText = Some(value)
        this
    }

    public func enabled(value: Bool): NumberBox {
        isEnabled = value
        this
    }

    public func on_value_changed(handler: (Float64) -> Unit): NumberBox {
        onValueChanged = Some(Callback<Float64>(handler))
        this
    }

    public func name(value: String): NumberBox {
        modifiers.xName = Some(value)
        this
    }
}

public func number_box(value: Float64): NumberBox { NumberBox.new(value) }
