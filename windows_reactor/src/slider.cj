package windows_reactor

public class Slider <: Widget {
    public var value: Float64
    public var minimum: Float64 = 0.0
    public var maximum: Float64 = 100.0
    public var stepValue: Option<Float64> = None
    public var headerText: Option<String> = None
    public var verticalValue: Bool = false
    public var isEnabled: Bool = true
    public var onChanged: Option<Callback<Float64>> = None
    public var modifiers: Modifiers = Modifiers()

    public init(value: Float64) {
        this.value = value
    }

    public static func new(value: Float64): Slider {
        Slider(value)
    }

    public func controlKind(): ControlKind { ControlKind.Slider }
    public func toElement(): Element { Element.slider(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = floatAttr("Value", value) + floatAttr("Minimum", minimum) +
            floatAttr("Maximum", maximum) + boolAttr("IsEnabled", isEnabled) + frameworkAttrs(modifiers)
        match (stepValue) {
            case Some(step) => attrs += floatAttr("StepFrequency", step)
            case None => ()
        }
        match (headerText) {
            case Some(text) => attrs += attr("Header", text)
            case None => ()
        }
        if (verticalValue) {
            attrs += attr("Orientation", "Vertical")
        }
        "<Slider" + attrs + " />"
    }

    public func range(min: Float64, max: Float64): Slider {
        minimum = min
        maximum = max
        this
    }

    public func step(value: Float64): Slider {
        stepValue = Some(value)
        this
    }

    public func header(value: String): Slider {
        headerText = Some(value)
        this
    }

    public func vertical(): Slider {
        verticalValue = true
        this
    }

    public func horizontal(): Slider {
        verticalValue = false
        this
    }

    public func enabled(value: Bool): Slider {
        isEnabled = value
        this
    }

    public func on_changed(handler: (Float64) -> Unit): Slider {
        onChanged = Some(Callback<Float64>(handler))
        this
    }

    public func name(value: String): Slider {
        modifiers.xName = Some(value)
        this
    }
}

public func slider(value: Float64): Slider { Slider.new(value) }
