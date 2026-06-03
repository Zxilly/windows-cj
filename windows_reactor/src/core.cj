package windows_reactor

import std.collection.*
import windows_time.{DateTime, TimeSpan}

public type ReactorDateTime = DateTime
public type ReactorTimeSpan = TimeSpan

// ============================================================================
// Geometry / color primitives
// ============================================================================

public struct Thickness <: Equatable<Thickness> {
    public var left: Float64 = 0.0
    public var top: Float64 = 0.0
    public var right: Float64 = 0.0
    public var bottom: Float64 = 0.0

    public init() {}

    public init(left: Float64, top: Float64, right: Float64, bottom: Float64) {
        this.left = left
        this.top = top
        this.right = right
        this.bottom = bottom
    }

    public static func uniform(value: Float64): Thickness {
        Thickness(value, value, value, value)
    }

    public static func vertical_horizontal(vertical: Float64, horizontal: Float64): Thickness {
        Thickness(horizontal, vertical, horizontal, vertical)
    }

    public operator func ==(other: Thickness): Bool {
        left == other.left && top == other.top && right == other.right && bottom == other.bottom
    }

    public operator func !=(other: Thickness): Bool {
        !(this == other)
    }
}

public struct Color <: Equatable<Color> {
    public let a: UInt8
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(a: UInt8, r: UInt8, g: UInt8, b: UInt8) {
        this.a = a
        this.r = r
        this.g = g
        this.b = b
    }

    public static func argb(a: UInt8, r: UInt8, g: UInt8, b: UInt8): Color {
        Color(a, r, g, b)
    }

    public static func rgb(r: UInt8, g: UInt8, b: UInt8): Color {
        Color(255u8, r, g, b)
    }

    public operator func ==(other: Color): Bool {
        a == other.a && r == other.r && g == other.g && b == other.b
    }

    public operator func !=(other: Color): Bool {
        !(this == other)
    }
}

public enum Brush {
    | Solid(Color)
    | Resource(String)
}

// ============================================================================
// Theme references (resolved into {ThemeResource ...})
// ============================================================================

public enum ThemeRef <: Equatable<ThemeRef> {
    | Accent
    | AccentSecondary
    | AccentTertiary
    | AccentDisabled
    | PrimaryText
    | SecondaryText
    | TertiaryText
    | DisabledText
    | AccentText
    | SolidBackground
    | CardBackground
    | SmokeFill
    | SubtleFill
    | LayerFill
    | ControlFill
    | ControlFillSecondary
    | ControlFillTertiary
    | ControlFillDisabled
    | ControlFillInputActive
    | CardStroke
    | SurfaceStroke
    | DividerStroke
    | ControlStroke
    | ControlStrokeSecondary
    | SystemAttention
    | SystemSuccess
    | SystemCaution
    | SystemCritical
    | SystemNeutral
    | SystemSolidNeutral
    | SystemAttentionBackground
    | SystemSuccessBackground
    | SystemCautionBackground
    | SystemCriticalBackground
    | SystemNeutralBackground
    | SystemSolidAttention
    | Custom(String)

    public static func custom(key: String): ThemeRef { ThemeRef.Custom(key) }

    public func resourceKey(): String {
        match (this) {
            case Accent => "AccentFillColorDefaultBrush"
            case AccentSecondary => "AccentFillColorSecondaryBrush"
            case AccentTertiary => "AccentFillColorTertiaryBrush"
            case AccentDisabled => "AccentFillColorDisabledBrush"
            case PrimaryText => "TextFillColorPrimaryBrush"
            case SecondaryText => "TextFillColorSecondaryBrush"
            case TertiaryText => "TextFillColorTertiaryBrush"
            case DisabledText => "TextFillColorDisabledBrush"
            case AccentText => "AccentTextFillColorPrimaryBrush"
            case SolidBackground => "SolidBackgroundFillColorBaseBrush"
            case CardBackground => "CardBackgroundFillColorDefaultBrush"
            case SmokeFill => "SmokeFillColorDefaultBrush"
            case SubtleFill => "SubtleFillColorSecondaryBrush"
            case LayerFill => "LayerFillColorDefaultBrush"
            case ControlFill => "ControlFillColorDefaultBrush"
            case ControlFillSecondary => "ControlFillColorSecondaryBrush"
            case ControlFillTertiary => "ControlFillColorTertiaryBrush"
            case ControlFillDisabled => "ControlFillColorDisabledBrush"
            case ControlFillInputActive => "ControlFillColorInputActiveBrush"
            case CardStroke => "CardStrokeColorDefaultBrush"
            case SurfaceStroke => "SurfaceStrokeColorDefaultBrush"
            case DividerStroke => "DividerStrokeColorDefaultBrush"
            case ControlStroke => "ControlStrokeColorDefaultBrush"
            case ControlStrokeSecondary => "ControlStrokeColorSecondaryBrush"
            case SystemAttention => "SystemFillColorAttentionBrush"
            case SystemSuccess => "SystemFillColorSuccessBrush"
            case SystemCaution => "SystemFillColorCautionBrush"
            case SystemCritical => "SystemFillColorCriticalBrush"
            case SystemNeutral => "SystemFillColorNeutralBrush"
            case SystemSolidNeutral => "SystemFillColorSolidNeutralBrush"
            case SystemAttentionBackground => "SystemFillColorAttentionBackgroundBrush"
            case SystemSuccessBackground => "SystemFillColorSuccessBackgroundBrush"
            case SystemCautionBackground => "SystemFillColorCautionBackgroundBrush"
            case SystemCriticalBackground => "SystemFillColorCriticalBackgroundBrush"
            case SystemNeutralBackground => "SystemFillColorNeutralBackgroundBrush"
            case SystemSolidAttention => "SystemFillColorSolidAttentionBackgroundBrush"
            case Custom(s) => s
        }
    }

    public func code(): String { resourceKey() }

    public operator func ==(other: ThemeRef): Bool {
        resourceKey() == other.resourceKey()
    }

    public operator func !=(other: ThemeRef): Bool {
        !(this == other)
    }
}

// ============================================================================
// Alignment / layout enums
// ============================================================================

public enum HorizontalAlignment <: Equatable<HorizontalAlignment> {
    | Left | Center | Right | Stretch

    public func code(): Int64 {
        match (this) {
            case Left => 0
            case Center => 1
            case Right => 2
            case Stretch => 3
        }
    }

    public operator func ==(other: HorizontalAlignment): Bool {
        code() == other.code()
    }

    public operator func !=(other: HorizontalAlignment): Bool {
        !(this == other)
    }
}

public enum VerticalAlignment <: Equatable<VerticalAlignment> {
    | Top | Center | Bottom | Stretch

    public func code(): Int64 {
        match (this) {
            case Top => 0
            case Center => 1
            case Bottom => 2
            case Stretch => 3
        }
    }

    public operator func ==(other: VerticalAlignment): Bool {
        code() == other.code()
    }

    public operator func !=(other: VerticalAlignment): Bool {
        !(this == other)
    }
}

public enum GridLength {
    | Auto
    | Star(Float64)
    | Pixel(Float64)

    public static func star(value: Float64): GridLength { GridLength.Star(value) }
    public static func pixel(value: Float64): GridLength { GridLength.Pixel(value) }
}

public enum ScrollBarVisibility <: Equatable<ScrollBarVisibility> {
    | Disabled | Auto | Hidden | Visible

    public func code(): Int64 {
        match (this) {
            case Disabled => 0
            case Auto => 1
            case Hidden => 2
            case Visible => 3
        }
    }

    public operator func ==(other: ScrollBarVisibility): Bool {
        code() == other.code()
    }

    public operator func !=(other: ScrollBarVisibility): Bool {
        !(this == other)
    }
}

// ============================================================================
// Modifiers (shared visual / layout / attached props on every widget)
// ============================================================================

public struct Modifiers <: Equatable<Modifiers> {
    public var key: Option<String> = None
    public var width: Option<Float64> = None
    public var height: Option<Float64> = None
    public var minWidth: Option<Float64> = None
    public var minHeight: Option<Float64> = None
    public var maxWidth: Option<Float64> = None
    public var maxHeight: Option<Float64> = None
    public var margin: Option<Thickness> = None
    public var padding: Option<Thickness> = None
    public var horizontalAlignment: Option<HorizontalAlignment> = None
    public var verticalAlignment: Option<VerticalAlignment> = None
    public var tooltip: Option<String> = None
    public var automationName: Option<String> = None
    // visual brushes / opacity / typography
    public var foreground: Option<Brush> = None
    public var background: Option<Brush> = None
    public var foregroundTheme: Option<ThemeRef> = None
    public var backgroundTheme: Option<ThemeRef> = None
    public var opacity: Option<Float64> = None
    public var fontFamily: Option<String> = None
    public var fontSize: Option<Float64> = None
    public var cornerRadius: Option<Float64> = None
    public var borderBrush: Option<Brush> = None
    public var borderBrushTheme: Option<ThemeRef> = None
    public var borderThickness: Option<Thickness> = None
    // attached: Grid placement
    public var gridRow: Option<Int64> = None
    public var gridColumn: Option<Int64> = None
    public var gridRowSpan: Option<Int64> = None
    public var gridColumnSpan: Option<Int64> = None
    // attached: Canvas placement
    public var canvasLeft: Option<Float64> = None
    public var canvasTop: Option<Float64> = None
    public var canvasZIndex: Option<Int64> = None
    // named element (x:Name) for event binding via UIElementHandle lookup
    public var xName: Option<String> = None

    public init() {}

    public func is_empty(): Bool {
        key.isNone() &&
        width.isNone() &&
        height.isNone() &&
        minWidth.isNone() &&
        minHeight.isNone() &&
        maxWidth.isNone() &&
        maxHeight.isNone() &&
        margin.isNone() &&
        padding.isNone() &&
        horizontalAlignment.isNone() &&
        verticalAlignment.isNone() &&
        tooltip.isNone() &&
        automationName.isNone() &&
        foreground.isNone() &&
        background.isNone() &&
        foregroundTheme.isNone() &&
        backgroundTheme.isNone() &&
        opacity.isNone() &&
        fontFamily.isNone() &&
        fontSize.isNone() &&
        cornerRadius.isNone() &&
        borderBrush.isNone() &&
        borderBrushTheme.isNone() &&
        borderThickness.isNone() &&
        gridRow.isNone() &&
        gridColumn.isNone() &&
        gridRowSpan.isNone() &&
        gridColumnSpan.isNone() &&
        canvasLeft.isNone() &&
        canvasTop.isNone() &&
        canvasZIndex.isNone() &&
        xName.isNone()
    }

    public operator func ==(other: Modifiers): Bool {
        key == other.key &&
        width == other.width &&
        height == other.height &&
        minWidth == other.minWidth &&
        minHeight == other.minHeight &&
        maxWidth == other.maxWidth &&
        maxHeight == other.maxHeight &&
        margin == other.margin &&
        padding == other.padding &&
        horizontalAlignment == other.horizontalAlignment &&
        verticalAlignment == other.verticalAlignment &&
        tooltip == other.tooltip &&
        automationName == other.automationName &&
        opacity == other.opacity &&
        fontFamily == other.fontFamily &&
        fontSize == other.fontSize &&
        cornerRadius == other.cornerRadius &&
        borderThickness == other.borderThickness &&
        gridRow == other.gridRow &&
        gridColumn == other.gridColumn &&
        gridRowSpan == other.gridRowSpan &&
        gridColumnSpan == other.gridColumnSpan &&
        canvasLeft == other.canvasLeft &&
        canvasTop == other.canvasTop &&
        canvasZIndex == other.canvasZIndex &&
        xName == other.xName
    }

    public operator func !=(other: Modifiers): Bool {
        !(this == other)
    }
}

// ============================================================================
// Callback
// ============================================================================

public class Callback<T> {
    private let invoke_: (T) -> Unit

    public init(invoke: (T) -> Unit) {
        this.invoke_ = invoke
    }

    public func call(value: T): Unit {
        invoke_(value)
    }
}

// ============================================================================
// ControlKind
// ============================================================================

public enum ControlKind <: Equatable<ControlKind> {
    | Empty | TextBlock | Button | StackPanel | Border | CheckBox | TextBox | Grid | ScrollViewer | ToggleSwitch | Slider | RadioButton | NumberBox | ProgressBar | ProgressRing | Expander | Image | Rectangle | Ellipse | Line | PasswordBox | ComboBox | RadioButtons | PersonPicture | Canvas | Custom

    public func code(): Int64 {
        match (this) {
            case Empty => 0
            case TextBlock => 1
            case Button => 2
            case StackPanel => 3
            case Border => 4
            case CheckBox => 5
            case TextBox => 6
            case Grid => 7
            case ScrollViewer => 8
            case ToggleSwitch => 9
            case Slider => 10
            case RadioButton => 11
            case NumberBox => 12
            case ProgressBar => 13
            case ProgressRing => 14
            case Expander => 15
            case Image => 16
            case Rectangle => 17
            case Ellipse => 18
            case Line => 19
            case PasswordBox => 20
            case ComboBox => 21
            case RadioButtons => 22
            case PersonPicture => 23
            case Canvas => 24
            case Custom => 25
        }
    }

    public operator func ==(other: ControlKind): Bool {
        code() == other.code()
    }

    public operator func !=(other: ControlKind): Bool {
        !(this == other)
    }
}

// ============================================================================
// Widget interface — self-rendering
// ============================================================================

// Every widget knows its ControlKind, can lower itself to an Element, and can
// render itself to a XAML fragment. `renderXaml()` is the single dispatch hook
// used by `renderXamlFragment` (see xaml.cj). `widgetKey()` exposes the
// element key (modifiers.key) uniformly.
public interface Widget {
    func controlKind(): ControlKind
    func toElement(): Element
    func renderXaml(): String
    func widgetKey(): Option<String>
}

// ============================================================================
// Element — tagged union over all widgets, plus a generic WidgetElement
// carrier so new widgets can flow through a single dispatch case without a
// dedicated variant. Existing concrete variants and Element.<factory>(...)
// constructors are preserved for API compatibility.
// ============================================================================

public enum Element {
    | Empty
    | TextBlockElement(TextBlock)
    | ButtonElement(Button)
    | StackPanelElement(StackPanel)
    | BorderElement(Border)
    | CheckBoxElement(CheckBox)
    | GridElement(Grid)
    | ScrollViewerElement(ScrollViewer)
    | ToggleSwitchElement(ToggleSwitch)
    | SliderElement(Slider)
    | RadioButtonElement(RadioButton)
    | NumberBoxElement(NumberBox)
    | ProgressBarElement(ProgressBar)
    | ProgressRingElement(ProgressRing)
    | ExpanderElement(Expander)
    | ImageElement(Image)
    | ShapeElement(Shape)
    | CanvasElement(Canvas)
    | TextBoxElement(TextBox)
    | PasswordBoxElement(PasswordBox)
    | ComboBoxElement(ComboBox)
    | RadioButtonsElement(RadioButtons)
    | PersonPictureElement(PersonPicture)
    | CustomControlElement(CustomControl)
    | WidgetElement(Widget)

    public static func textBlock(value: TextBlock): Element { Element.TextBlockElement(value) }
    public static func button(value: Button): Element { Element.ButtonElement(value) }
    public static func stackPanel(value: StackPanel): Element { Element.StackPanelElement(value) }
    public static func border(value: Border): Element { Element.BorderElement(value) }
    public static func checkBox(value: CheckBox): Element { Element.CheckBoxElement(value) }
    public static func grid(value: Grid): Element { Element.GridElement(value) }
    public static func scrollViewer(value: ScrollViewer): Element { Element.ScrollViewerElement(value) }
    public static func toggleSwitch(value: ToggleSwitch): Element { Element.ToggleSwitchElement(value) }
    public static func slider(value: Slider): Element { Element.SliderElement(value) }
    public static func radioButton(value: RadioButton): Element { Element.RadioButtonElement(value) }
    public static func numberBox(value: NumberBox): Element { Element.NumberBoxElement(value) }
    public static func progressBar(value: ProgressBar): Element { Element.ProgressBarElement(value) }
    public static func progressRing(value: ProgressRing): Element { Element.ProgressRingElement(value) }
    public static func expander(value: Expander): Element { Element.ExpanderElement(value) }
    public static func image(value: Image): Element { Element.ImageElement(value) }
    public static func shape(value: Shape): Element { Element.ShapeElement(value) }
    public static func canvas(value: Canvas): Element { Element.CanvasElement(value) }
    public static func textBox(value: TextBox): Element { Element.TextBoxElement(value) }
    public static func passwordBox(value: PasswordBox): Element { Element.PasswordBoxElement(value) }
    public static func comboBox(value: ComboBox): Element { Element.ComboBoxElement(value) }
    public static func radioButtons(value: RadioButtons): Element { Element.RadioButtonsElement(value) }
    public static func personPicture(value: PersonPicture): Element { Element.PersonPictureElement(value) }
    public static func custom(value: CustomControl): Element { Element.CustomControlElement(value) }
    // Generic carrier: lower any Widget into an Element without a dedicated variant.
    public static func widget(value: Widget): Element { Element.WidgetElement(value) }

    public func kind_name(): String {
        match (this) {
            case Empty => "Empty"
            case TextBlockElement(_) => "TextBlock"
            case ButtonElement(_) => "Button"
            case StackPanelElement(_) => "StackPanel"
            case BorderElement(_) => "Border"
            case CheckBoxElement(_) => "CheckBox"
            case GridElement(_) => "Grid"
            case ScrollViewerElement(_) => "ScrollViewer"
            case ToggleSwitchElement(_) => "ToggleSwitch"
            case SliderElement(_) => "Slider"
            case RadioButtonElement(_) => "RadioButton"
            case NumberBoxElement(_) => "NumberBox"
            case ProgressBarElement(_) => "ProgressBar"
            case ProgressRingElement(_) => "ProgressRing"
            case ExpanderElement(_) => "Expander"
            case ImageElement(_) => "Image"
            case ShapeElement(_) => "Shape"
            case CanvasElement(_) => "Canvas"
            case TextBoxElement(_) => "TextBox"
            case PasswordBoxElement(_) => "PasswordBox"
            case ComboBoxElement(_) => "ComboBox"
            case RadioButtonsElement(_) => "RadioButtons"
            case PersonPictureElement(_) => "PersonPicture"
            case CustomControlElement(value) => value.typeName
            case WidgetElement(w) => widgetKindName(w)
        }
    }

    public func kind_matches(other: Element): Bool {
        kind_name() == other.kind_name()
    }

    public func key(): Option<String> {
        match (this) {
            case TextBlockElement(value) => value.modifiers.key
            case ButtonElement(value) => value.modifiers.key
            case StackPanelElement(value) => value.modifiers.key
            case BorderElement(value) => value.modifiers.key
            case CheckBoxElement(value) => value.modifiers.key
            case GridElement(value) => value.modifiers.key
            case ScrollViewerElement(value) => value.modifiers.key
            case ToggleSwitchElement(value) => value.modifiers.key
            case SliderElement(value) => value.modifiers.key
            case RadioButtonElement(value) => value.modifiers.key
            case NumberBoxElement(value) => value.modifiers.key
            case ProgressBarElement(value) => value.modifiers.key
            case ProgressRingElement(value) => value.modifiers.key
            case ExpanderElement(value) => value.modifiers.key
            case ImageElement(value) => value.modifiers.key
            case ShapeElement(value) => value.modifiers.key
            case CanvasElement(value) => value.modifiers.key
            case TextBoxElement(value) => value.modifiers.key
            case PasswordBoxElement(value) => value.modifiers.key
            case ComboBoxElement(value) => value.modifiers.key
            case RadioButtonsElement(value) => value.modifiers.key
            case PersonPictureElement(value) => value.modifiers.key
            case CustomControlElement(value) => value.modifiers.key
            case WidgetElement(w) => w.widgetKey()
            case Empty => None
        }
    }
}

// Resolve a kind name for a Widget carried generically. Custom controls report
// their typeName; all others report the ControlKind variant name.
func widgetKindName(w: Widget): String {
    match (w.controlKind()) {
        case ControlKind.Empty => "Empty"
        case ControlKind.TextBlock => "TextBlock"
        case ControlKind.Button => "Button"
        case ControlKind.StackPanel => "StackPanel"
        case ControlKind.Border => "Border"
        case ControlKind.CheckBox => "CheckBox"
        case ControlKind.TextBox => "TextBox"
        case ControlKind.Grid => "Grid"
        case ControlKind.ScrollViewer => "ScrollViewer"
        case ControlKind.ToggleSwitch => "ToggleSwitch"
        case ControlKind.Slider => "Slider"
        case ControlKind.RadioButton => "RadioButton"
        case ControlKind.NumberBox => "NumberBox"
        case ControlKind.ProgressBar => "ProgressBar"
        case ControlKind.ProgressRing => "ProgressRing"
        case ControlKind.Expander => "Expander"
        case ControlKind.Image => "Image"
        case ControlKind.Rectangle => "Rectangle"
        case ControlKind.Ellipse => "Ellipse"
        case ControlKind.Line => "Line"
        case ControlKind.PasswordBox => "PasswordBox"
        case ControlKind.ComboBox => "ComboBox"
        case ControlKind.RadioButtons => "RadioButtons"
        case ControlKind.PersonPicture => "PersonPicture"
        case ControlKind.Canvas => "Canvas"
        case ControlKind.Custom => "Custom"
    }
}

// ============================================================================
// Aggregate / convenience factories (cross-widget). Per-widget factories live
// in each widget's own file (button.cj, text_block.cj, ...).
// ============================================================================

public func vstack(children: Array<Element>): StackPanel {
    StackPanel.new(true, children)
}

public func hstack(children: Array<Element>): StackPanel {
    StackPanel.new(false, children)
}

public func intoElement(widget: Widget): Element {
    widget.toElement()
}
