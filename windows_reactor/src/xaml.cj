package windows_reactor

import std.collection.*

// ============================================================================
// Public entry points
// ============================================================================

public func escapeXaml(value: String): String {
    var out = ""
    for (byte in value.toArray()) {
        if (byte == b'&') {
            out += "&amp;"
        } else if (byte == b'<') {
            out += "&lt;"
        } else if (byte == b'>') {
            out += "&gt;"
        } else if (byte == b'"') {
            out += "&quot;"
        } else {
            out += String.fromUtf8([byte])
        }
    }
    out
}

public func renderXaml(element: Element): String {
    return "<Grid xmlns=\"http://schemas.microsoft.com/winfx/2006/xaml/presentation\" xmlns:x=\"http://schemas.microsoft.com/winfx/2006/xaml\">\n" +
        renderXamlFragment(element) +
        "\n</Grid>\n"
}

// Single dispatch: each widget renders itself via `renderXaml()`. Concrete
// variants forward to the widget instance; the generic WidgetElement carrier
// uses one unified case so newly added widgets need no change here.
public func renderXamlFragment(element: Element): String {
    match (element) {
        case Empty => "<Grid />"
        case TextBlockElement(value) => value.renderXaml()
        case ButtonElement(value) => value.renderXaml()
        case StackPanelElement(value) => value.renderXaml()
        case BorderElement(value) => value.renderXaml()
        case CheckBoxElement(value) => value.renderXaml()
        case GridElement(value) => value.renderXaml()
        case ScrollViewerElement(value) => value.renderXaml()
        case ToggleSwitchElement(value) => value.renderXaml()
        case SliderElement(value) => value.renderXaml()
        case RadioButtonElement(value) => value.renderXaml()
        case NumberBoxElement(value) => value.renderXaml()
        case ProgressBarElement(value) => value.renderXaml()
        case ProgressRingElement(value) => value.renderXaml()
        case ExpanderElement(value) => value.renderXaml()
        case ImageElement(value) => value.renderXaml()
        case ShapeElement(value) => value.renderXaml()
        case CanvasElement(value) => value.renderXaml()
        case TextBoxElement(value) => value.renderXaml()
        case PasswordBoxElement(value) => value.renderXaml()
        case ComboBoxElement(value) => value.renderXaml()
        case RadioButtonsElement(value) => value.renderXaml()
        case PersonPictureElement(value) => value.renderXaml()
        case CustomControlElement(value) => value.renderXaml()
        case WidgetElement(w) => w.renderXaml()
    }
}

// ============================================================================
// Shared rendering helpers (used by every widget's renderXaml()).
// `internal` visibility = visible to all files of this package.
// ============================================================================

func boolText(value: Bool): String {
    if (value) { "True" } else { "False" }
}

func horizontalText(value: HorizontalAlignment): String {
    match (value) {
        case HorizontalAlignment.Left => "Left"
        case HorizontalAlignment.Center => "Center"
        case HorizontalAlignment.Right => "Right"
        case HorizontalAlignment.Stretch => "Stretch"
    }
}

func verticalText(value: VerticalAlignment): String {
    match (value) {
        case VerticalAlignment.Top => "Top"
        case VerticalAlignment.Center => "Center"
        case VerticalAlignment.Bottom => "Bottom"
        case VerticalAlignment.Stretch => "Stretch"
    }
}

func thicknessText(value: Thickness): String {
    value.left.toString() + "," + value.top.toString() + "," + value.right.toString() + "," + value.bottom.toString()
}

func attr(name: String, value: String): String {
    " " + name + "=\"" + escapeXaml(value) + "\""
}

func rawAttr(name: String, value: String): String {
    " " + name + "=\"" + value + "\""
}

func floatAttr(name: String, value: Float64): String {
    rawAttr(name, value.toString())
}

func intAttr(name: String, value: Int64): String {
    rawAttr(name, value.toString())
}

func boolAttr(name: String, value: Bool): String {
    rawAttr(name, boolText(value))
}

func hexDigit(value: UInt8): String {
    let digits = "0123456789ABCDEF".toArray()
    String.fromUtf8([digits[Int64(value)]])
}

func hexByte(value: UInt8): String {
    hexDigit((value >> 4) & 0x0Fu8) + hexDigit(value & 0x0Fu8)
}

func colorText(color: Color): String {
    "#" + hexByte(color.a) + hexByte(color.r) + hexByte(color.g) + hexByte(color.b)
}

func brushText(value: Brush): String {
    match (value) {
        case Brush.Solid(color) => colorText(color)
        case Brush.Resource(name) => "{ThemeResource " + name + "}"
    }
}

func themeResourceText(value: ThemeRef): String {
    "{ThemeResource " + value.resourceKey() + "}"
}

// FrameworkElement-level attributes shared by all widgets: sizing, margin,
// alignment, x:Name, opacity, typography, brushes (direct or theme), corner
// radius, border, tooltip, automation name, and the Grid/Canvas attached
// placement props.
func frameworkAttrs(modifiers: Modifiers): String {
    var out = ""
    match (modifiers.xName) {
        case Some(value) => out += attr("x:Name", value)
        case None => ()
    }
    match (modifiers.width) {
        case Some(value) => out += floatAttr("Width", value)
        case None => ()
    }
    match (modifiers.height) {
        case Some(value) => out += floatAttr("Height", value)
        case None => ()
    }
    match (modifiers.minWidth) {
        case Some(value) => out += floatAttr("MinWidth", value)
        case None => ()
    }
    match (modifiers.minHeight) {
        case Some(value) => out += floatAttr("MinHeight", value)
        case None => ()
    }
    match (modifiers.maxWidth) {
        case Some(value) => out += floatAttr("MaxWidth", value)
        case None => ()
    }
    match (modifiers.maxHeight) {
        case Some(value) => out += floatAttr("MaxHeight", value)
        case None => ()
    }
    match (modifiers.margin) {
        case Some(value) => out += attr("Margin", thicknessText(value))
        case None => ()
    }
    match (modifiers.horizontalAlignment) {
        case Some(value) => out += attr("HorizontalAlignment", horizontalText(value))
        case None => ()
    }
    match (modifiers.verticalAlignment) {
        case Some(value) => out += attr("VerticalAlignment", verticalText(value))
        case None => ()
    }
    match (modifiers.opacity) {
        case Some(value) => out += floatAttr("Opacity", value)
        case None => ()
    }
    match (modifiers.fontFamily) {
        case Some(value) => out += attr("FontFamily", value)
        case None => ()
    }
    match (modifiers.fontSize) {
        case Some(value) => out += floatAttr("FontSize", value)
        case None => ()
    }
    // Foreground: direct brush wins, otherwise theme binding.
    match (modifiers.foreground) {
        case Some(brush) => out += attr("Foreground", brushText(brush))
        case None =>
            match (modifiers.foregroundTheme) {
                case Some(t) => out += attr("Foreground", themeResourceText(t))
                case None => ()
            }
    }
    match (modifiers.background) {
        case Some(brush) => out += attr("Background", brushText(brush))
        case None =>
            match (modifiers.backgroundTheme) {
                case Some(t) => out += attr("Background", themeResourceText(t))
                case None => ()
            }
    }
    match (modifiers.borderBrush) {
        case Some(brush) => out += attr("BorderBrush", brushText(brush))
        case None =>
            match (modifiers.borderBrushTheme) {
                case Some(t) => out += attr("BorderBrush", themeResourceText(t))
                case None => ()
            }
    }
    match (modifiers.borderThickness) {
        case Some(value) => out += attr("BorderThickness", thicknessText(value))
        case None => ()
    }
    match (modifiers.cornerRadius) {
        case Some(value) => out += floatAttr("CornerRadius", value)
        case None => ()
    }
    match (modifiers.gridRow) {
        case Some(value) => out += intAttr("Grid.Row", value)
        case None => ()
    }
    match (modifiers.gridColumn) {
        case Some(value) => out += intAttr("Grid.Column", value)
        case None => ()
    }
    match (modifiers.gridRowSpan) {
        case Some(value) => out += intAttr("Grid.RowSpan", value)
        case None => ()
    }
    match (modifiers.gridColumnSpan) {
        case Some(value) => out += intAttr("Grid.ColumnSpan", value)
        case None => ()
    }
    match (modifiers.canvasLeft) {
        case Some(value) => out += floatAttr("Canvas.Left", value)
        case None => ()
    }
    match (modifiers.canvasTop) {
        case Some(value) => out += floatAttr("Canvas.Top", value)
        case None => ()
    }
    match (modifiers.canvasZIndex) {
        case Some(value) => out += intAttr("Canvas.ZIndex", value)
        case None => ()
    }
    match (modifiers.tooltip) {
        case Some(value) => out += attr("ToolTipService.ToolTip", value)
        case None => ()
    }
    match (modifiers.automationName) {
        case Some(value) => out += attr("AutomationProperties.Name", value)
        case None => ()
    }
    out
}

func paddingAttr(modifiers: Modifiers): String {
    match (modifiers.padding) {
        case Some(value) => attr("Padding", thicknessText(value))
        case None => ""
    }
}

func renderChildren(children: ArrayList<Element>): String {
    var out = ""
    for (child in children) {
        out += renderXamlFragment(child) + "\n"
    }
    out
}
