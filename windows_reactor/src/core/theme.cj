package windows_reactor.core

// Color scheme + symbolic theme resource references. ThemeRef resolves to a
// XAML theme-resource key at apply time so bindings track light/dark switches.

public enum ColorScheme <: Equatable<ColorScheme> {
    | Light | Dark

    public func tag(): Int64 {
        match (this) {
            case Light => 0
            case Dark => 1
        }
    }

    public operator func ==(other: ColorScheme): Bool { tag() == other.tag() }
    public operator func !=(other: ColorScheme): Bool { tag() != other.tag() }
}

// Per-UI-thread current color scheme. WinUI is STA single-threaded, so a
// module-level cell is the behaviour-equivalent of the reference thread-local.
class ColorSchemeCell {
    var value: ColorScheme = ColorScheme.Light
}
let currentColorSchemeCell = ColorSchemeCell()

public func currentColorScheme(): ColorScheme {
    currentColorSchemeCell.value
}

public func setCurrentColorScheme(scheme: ColorScheme): Unit {
    currentColorSchemeCell.value = scheme
}

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

    public operator func ==(other: ThemeRef): Bool {
        resourceKey() == other.resourceKey()
    }

    public operator func !=(other: ThemeRef): Bool {
        !(this == other)
    }
}

// Brush slot that can be either a literal Brush or a symbolic ThemeRef; used
// for background / foreground modifiers.
public enum BrushBinding <: Equatable<BrushBinding> {
    | Direct(Brush)
    | Theme(ThemeRef)

    public static func ofBrush(b: Brush): BrushBinding { BrushBinding.Direct(b) }
    public static func ofColor(c: Color): BrushBinding { BrushBinding.Direct(Brush.Solid(c)) }
    public static func ofTheme(t: ThemeRef): BrushBinding { BrushBinding.Theme(t) }

    public operator func ==(other: BrushBinding): Bool {
        match ((this, other)) {
            case (Direct(a), Direct(b)) => a == b
            case (Theme(a), Theme(b)) => a == b
            case _ => false
        }
    }

    public operator func !=(other: BrushBinding): Bool { !(this == other) }
}
