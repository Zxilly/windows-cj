package windows_reactor

public class ProgressRing <: Widget {
    public var value: Float64 = 0.0
    public var minimum: Float64 = 0.0
    public var maximum: Float64 = 100.0
    public var isIndeterminate: Bool = true
    public var isActive: Bool = true
    public var modifiers: Modifiers = Modifiers()

    public init(value: Float64) {
        this.value = value
        this.isIndeterminate = false
    }

    public init() {}

    public static func new(value: Float64): ProgressRing {
        ProgressRing(value)
    }

    public static func indeterminate(): ProgressRing {
        ProgressRing()
    }

    public func controlKind(): ControlKind { ControlKind.ProgressRing }
    public func toElement(): Element { Element.progressRing(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        "<ProgressRing" + floatAttr("Value", value) + floatAttr("Minimum", minimum) +
            floatAttr("Maximum", maximum) + boolAttr("IsIndeterminate", isIndeterminate) +
            boolAttr("IsActive", isActive) + frameworkAttrs(modifiers) + " />"
    }

    public func name(value: String): ProgressRing {
        modifiers.xName = Some(value)
        this
    }
}

public func progress_ring(value: Float64): ProgressRing { ProgressRing.new(value) }
public func progress_ring_indeterminate(): ProgressRing { ProgressRing.indeterminate() }
