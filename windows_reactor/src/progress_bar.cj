package windows_reactor

public class ProgressBar <: Widget {
    public var value: Float64 = 0.0
    public var minimum: Float64 = 0.0
    public var maximum: Float64 = 100.0
    public var isIndeterminate: Bool = false
    public var modifiers: Modifiers = Modifiers()

    public init(value: Float64) {
        this.value = value
    }

    public static func new(value: Float64): ProgressBar {
        ProgressBar(value)
    }

    public static func indeterminate(): ProgressBar {
        let bar = ProgressBar(0.0)
        bar.isIndeterminate = true
        bar
    }

    public func controlKind(): ControlKind { ControlKind.ProgressBar }
    public func toElement(): Element { Element.progressBar(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        "<ProgressBar" + floatAttr("Value", value) + floatAttr("Minimum", minimum) +
            floatAttr("Maximum", maximum) + boolAttr("IsIndeterminate", isIndeterminate) +
            frameworkAttrs(modifiers) + " />"
    }

    public func range(min: Float64, max: Float64): ProgressBar {
        minimum = min
        maximum = max
        this
    }

    public func name(value: String): ProgressBar {
        modifiers.xName = Some(value)
        this
    }
}

public func progress_bar(value: Float64): ProgressBar { ProgressBar.new(value) }
public func progress_bar_indeterminate(): ProgressBar { ProgressBar.indeterminate() }
