package windows_reactor

// ============================================================================
// Button — CANONICAL WIDGET TEMPLATE.
//
// Every widget file follows this exact shape:
//   1. (optional) widget-specific enums/structs
//   2. the widget `class <Name> <: Widget`
//        - public fields (state) + `var modifiers: Modifiers = Modifiers()`
//        - `init(...)` + `static func new(...)`
//        - builder methods (snake_case, return `This` for chaining)
//        - the four Widget interface members:
//            controlKind() / toElement() / renderXaml() / widgetKey()
//   3. a top-level snake_case factory function
//
// renderXaml() reuses the shared helpers from xaml.cj (frameworkAttrs,
// paddingAttr, attr, boolAttr, renderChildren, ...). Keep output byte-for-byte
// consistent with the existing renderer.
// ============================================================================

// Visual style variants, aligned with the reference widget surface.
public enum ButtonStyle <: Equatable<ButtonStyle> {
    | Default | Accent | Subtle | TextLink

    public func code(): Int64 {
        match (this) {
            case Default => 0
            case Accent => 1
            case Subtle => 2
            case TextLink => 3
        }
    }

    public func styleResourceKey(): Option<String> {
        match (this) {
            case Default => None
            case Accent => Some("AccentButtonStyle")
            case Subtle => Some("SubtleButtonStyle")
            case TextLink => Some("TextBlockButtonStyle")
        }
    }

    public operator func ==(other: ButtonStyle): Bool { code() == other.code() }
    public operator func !=(other: ButtonStyle): Bool { !(this == other) }
}

public class Button <: Widget {
    public let content: String
    public var isEnabled: Bool = true
    public var style: ButtonStyle = ButtonStyle.Default
    public var onClick: Option<Callback<Unit>> = None
    public var modifiers: Modifiers = Modifiers()

    public init(content: String) {
        this.content = content
    }

    public static func new(content: String): Button {
        Button(content)
    }

    // ── Widget interface ────────────────────────────────────────────────────
    public func controlKind(): ControlKind { ControlKind.Button }
    public func toElement(): Element { Element.button(this) }
    public func widgetKey(): Option<String> { modifiers.key }

    public func renderXaml(): String {
        var attrs = attr("Content", content) + boolAttr("IsEnabled", isEnabled) +
            frameworkAttrs(modifiers) + paddingAttr(modifiers)
        match (style.styleResourceKey()) {
            case Some(key) => attrs += rawAttr("Style", "{StaticResource " + key + "}")
            case None => ()
        }
        "<Button" + attrs + " />"
    }

    // ── Builders ─────────────────────────────────────────────────────────────
    public func enabled(value: Bool): Button {
        isEnabled = value
        this
    }

    public func on_click(handler: () -> Unit): Button {
        onClick = Some(Callback<Unit>({ _: Unit => handler() }))
        this
    }

    public func accent(): Button {
        style = ButtonStyle.Accent
        this
    }

    public func subtle(): Button {
        style = ButtonStyle.Subtle
        this
    }

    public func text_link(): Button {
        style = ButtonStyle.TextLink
        this
    }

    // x:Name for post-load event binding via UIElementHandle lookup.
    public func name(value: String): Button {
        modifiers.xName = Some(value)
        this
    }
}

public func button(content: String): Button { Button.new(content) }
