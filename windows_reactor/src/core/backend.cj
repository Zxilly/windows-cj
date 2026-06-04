package windows_reactor.core

import std.collection.*

// ============================================================================
// ControlId — opaque non-zero handle the backend assigns to every live
// control. Class (reference identity + type safety) implementing
// Hashable & Equatable so it can be a HashMap key, mirroring the reference
// NonZeroU32 newtype.
// ============================================================================

public class ControlId <: Hashable & Equatable<ControlId> & ToString {
    public let raw: UInt32

    public init(raw: UInt32) {
        if (raw == 0) {
            throw IllegalArgumentException("ControlId must be non-zero")
        }
        this.raw = raw
    }

    public func get(): UInt32 { raw }

    public func hashCode(): Int64 { Int64(raw) }

    public operator func ==(other: ControlId): Bool { raw == other.raw }
    public operator func !=(other: ControlId): Bool { raw != other.raw }

    public func toString(): String { "#${raw}" }
}

// ============================================================================
// Callback<T> — cheap-to-share wrapper around a closure with an identity id.
// Two Callbacks compare equal only when they share the same monotonic id,
// letting the reconciler skip rebinding when the same handler re-renders
// (behaviour-equivalent to the reference Rc pointer equality).
// ============================================================================

class CallbackIdCounter {
    var next: UInt64 = 1
    func allocate(): UInt64 {
        let id = next
        next = next + 1
        id
    }
}
let callbackIdCounter = CallbackIdCounter()

public class Callback<T> {
    let inner: (T) -> Unit
    public let id: UInt64

    public init(inner: (T) -> Unit) {
        this.inner = inner
        this.id = callbackIdCounter.allocate()
    }

    public func invoke(arg: T): Unit { inner(arg) }

    // Identity equality used by reconciler event-rebind skipping.
    public func sameAs(other: Callback<T>): Bool { id == other.id }
}

// ============================================================================
// ControlKind — one variant per backend-creatable control (62).
// Hashable & Equatable via tag() so it can key id_kinds maps.
// ============================================================================

public enum ControlKind <: Hashable & Equatable<ControlKind> {
    | TextBlock | Button | StackPanel | Border | CheckBox | TextBox | Grid
    | ScrollViewer | ToggleSwitch | Slider | RadioButton | NumberBox
    | ProgressBar | ProgressRing | Expander | HyperlinkButton | InfoBar
    | InfoBadge | PersonPicture | Image | TabView | TabViewItem
    | NavigationView | TitleBar | Pivot | PivotItem | BreadcrumbBar
    | PasswordBox | RadioButtons | ComboBox | Canvas | Rectangle | Ellipse
    | Line | RichTextBlock | ListView | GridView | FlipView | ContentDialog
    | Viewbox | RepeatButton | RatingControl | ColorPicker | DatePicker
    | TimePicker | CalendarDatePicker | CalendarView | ListBox | DropDownButton
    | SplitButton | AutoSuggestBox | SplitView | MenuBar | ScrollView
    | TreeView | CommandBar | TeachingTip | SelectorBar | RichEditBox
    | RelativePanel | ToggleButton | SwapChainPanel

    public func tag(): Int64 {
        match (this) {
            case TextBlock => 0
            case Button => 1
            case StackPanel => 2
            case Border => 3
            case CheckBox => 4
            case TextBox => 5
            case Grid => 6
            case ScrollViewer => 7
            case ToggleSwitch => 8
            case Slider => 9
            case RadioButton => 10
            case NumberBox => 11
            case ProgressBar => 12
            case ProgressRing => 13
            case Expander => 14
            case HyperlinkButton => 15
            case InfoBar => 16
            case InfoBadge => 17
            case PersonPicture => 18
            case Image => 19
            case TabView => 20
            case TabViewItem => 21
            case NavigationView => 22
            case TitleBar => 23
            case Pivot => 24
            case PivotItem => 25
            case BreadcrumbBar => 26
            case PasswordBox => 27
            case RadioButtons => 28
            case ComboBox => 29
            case Canvas => 30
            case Rectangle => 31
            case Ellipse => 32
            case Line => 33
            case RichTextBlock => 34
            case ListView => 35
            case GridView => 36
            case FlipView => 37
            case ContentDialog => 38
            case Viewbox => 39
            case RepeatButton => 40
            case RatingControl => 41
            case ColorPicker => 42
            case DatePicker => 43
            case TimePicker => 44
            case CalendarDatePicker => 45
            case CalendarView => 46
            case ListBox => 47
            case DropDownButton => 48
            case SplitButton => 49
            case AutoSuggestBox => 50
            case SplitView => 51
            case MenuBar => 52
            case ScrollView => 53
            case TreeView => 54
            case CommandBar => 55
            case TeachingTip => 56
            case SelectorBar => 57
            case RichEditBox => 58
            case RelativePanel => 59
            case ToggleButton => 60
            case SwapChainPanel => 62
            case PivotItem => 61
        }
    }

    public func hashCode(): Int64 { tag() }
    public operator func ==(other: ControlKind): Bool { tag() == other.tag() }
    public operator func !=(other: ControlKind): Bool { tag() != other.tag() }
}

// ============================================================================
// Prop — closed enum of every property a control accepts (~180). tag()-keyed.
// ============================================================================

public enum Prop <: Hashable & Equatable<Prop> {
    | Text | FontSize | FontWeight | FontFamily | ButtonContent | IsEnabled
    | Orientation | Spacing | Margin | Padding | Width | Height | MinWidth
    | MaxWidth | MinHeight | MaxHeight | HorizontalAlignment | VerticalAlignment
    | Opacity | Background | Foreground | IsChecked | CheckBoxLabel
    | TextBoxValue | Placeholder | Header | GridRows | GridColumns
    | GridRowSpacing | GridColumnSpacing | AttachedGridRow | AttachedGridColumn
    | AttachedGridRowSpan | AttachedGridColumnSpan | HorizontalScrollBarVisibility
    | VerticalScrollBarVisibility | IsOn | OnContent | OffContent | NumericValue
    | Minimum | Maximum | Step | GroupName | RadioLabel | IsIndeterminate
    | IsActive | IsExpanded | InfoBarTitle | InfoBarMessage | InfoBarSeverity
    | InfoBarIsOpen | IsClosable | InfoBadgeValue | PersonDisplayName
    | PersonInitials | Fill | Stroke | StrokeThickness | CornerRadius
    | BorderBrush | BorderThickness | LineEndpoints | ImageSource | ImageStretch
    | SelectedIndex | TabHeader | TabItemKey | TabContent | CanReorderTabs
    | NavigateUri | NavMenuItems | NavSelectedTag | NavAutoSuggestBox
    | NavAutoSuggestPlaceholder | NavAutoSuggestItems | IsPaneOpen
    | PaneDisplayMode | IsBackEnabled | IsSettingsVisible | PaneTitle
    | NavHeaderString | TitleBarTitle | TitleBarSubtitle | TitleBarTall
    | IsBackButtonVisible | IsPaneToggleButtonVisible | PivotTitle
    | PivotItemHeader | BreadcrumbItems | IsTextSelectionEnabled | TextWrappingWrap
    | AcceptsReturn | PasswordValue | PasswordRevealMode
    | IsPasswordRevealButtonEnabled | RadioButtonsItems | RadioButtonsMaxColumns
    | ComboBoxItems | ListBoxItems | IsEditable | AttachedCanvasLeft
    | AttachedCanvasTop | AttachedCanvasZIndex | ContentDialogTitle
    | ContentDialogBody | ContentDialogPrimaryText | ContentDialogSecondaryText
    | ContentDialogCloseText | ContentDialogPrimaryEnabled
    | ContentDialogSecondaryEnabled | ContentDialogIsOpen | ButtonStyleVariant
    | RepeatDelay | RepeatInterval | MaxRating | RatingCaption | IsReadOnly
    | PlaceholderValue | ColorValue | IsAlphaEnabled | IsHexInputVisible
    | IsColorSliderVisible | IsColorChannelTextInputVisible | DayVisible
    | MonthVisible | YearVisible | ClockIdentifier | MinuteIncrement
    | IsTodayHighlighted | IsCalendarOpen | IsGroupLabelVisible | AutoSuggestItems
    | AutoSuggestText | SplitViewDisplayMode | SplitViewIsPaneOpen
    | SplitViewOpenPaneLength | SplitViewCompactPaneLength | MenuBarItems
    | MenuFlyoutItems | TreeViewNodes | TreeViewSelectionMode
    | CommandBarPrimaryCommands | CommandBarSecondaryCommands
    | CommandBarDefaultLabelPosition | CommandBarFlyoutCommands | TeachingTipTitle
    | TeachingTipSubtitle | TeachingTipIsOpen | TeachingTipIsLightDismiss
    | TeachingTipPlacement | TeachingTipActionButton | TeachingTipCloseButton
    | SelectorBarItems | ButtonIcon | RichEditBoxText | RichEditBoxIsReadOnly
    | FlyoutContent | FlyoutPlacement | RelativePanelAlignLeftWithPanel
    | RelativePanelAlignRightWithPanel | RelativePanelAlignTopWithPanel
    | RelativePanelAlignBottomWithPanel | RelativePanelAlignHCenterWithPanel
    | RelativePanelAlignVCenterWithPanel | Resources
    // Controls the visibility of the TabView's built-in add-tab button.
    | IsAddTabButtonVisible

    public func tag(): Int64 {
        match (this) {
            case Text => 0
            case FontSize => 1
            case FontWeight => 2
            case FontFamily => 3
            case ButtonContent => 4
            case IsEnabled => 5
            case Orientation => 6
            case Spacing => 7
            case Margin => 8
            case Padding => 9
            case Width => 10
            case Height => 11
            case MinWidth => 12
            case MaxWidth => 13
            case MinHeight => 14
            case MaxHeight => 15
            case HorizontalAlignment => 16
            case VerticalAlignment => 17
            case Opacity => 18
            case Background => 19
            case Foreground => 20
            case IsChecked => 21
            case CheckBoxLabel => 22
            case TextBoxValue => 23
            case Placeholder => 24
            case Header => 25
            case GridRows => 26
            case GridColumns => 27
            case GridRowSpacing => 28
            case GridColumnSpacing => 29
            case AttachedGridRow => 30
            case AttachedGridColumn => 31
            case AttachedGridRowSpan => 32
            case AttachedGridColumnSpan => 33
            case HorizontalScrollBarVisibility => 34
            case VerticalScrollBarVisibility => 35
            case IsOn => 36
            case OnContent => 37
            case OffContent => 38
            case NumericValue => 39
            case Minimum => 40
            case Maximum => 41
            case Step => 42
            case GroupName => 43
            case RadioLabel => 44
            case IsIndeterminate => 45
            case IsActive => 46
            case IsExpanded => 47
            case InfoBarTitle => 48
            case InfoBarMessage => 49
            case InfoBarSeverity => 50
            case InfoBarIsOpen => 51
            case IsClosable => 52
            case InfoBadgeValue => 53
            case PersonDisplayName => 54
            case PersonInitials => 55
            case Fill => 56
            case Stroke => 57
            case StrokeThickness => 58
            case CornerRadius => 59
            case BorderBrush => 60
            case BorderThickness => 61
            case LineEndpoints => 62
            case ImageSource => 63
            case ImageStretch => 64
            case SelectedIndex => 65
            case TabHeader => 66
            case TabItemKey => 67
            case TabContent => 68
            case CanReorderTabs => 69
            case NavigateUri => 70
            case NavMenuItems => 71
            case NavSelectedTag => 72
            case NavAutoSuggestBox => 73
            case NavAutoSuggestPlaceholder => 74
            case NavAutoSuggestItems => 75
            case IsPaneOpen => 76
            case PaneDisplayMode => 77
            case IsBackEnabled => 78
            case IsSettingsVisible => 79
            case PaneTitle => 80
            case NavHeaderString => 81
            case TitleBarTitle => 82
            case TitleBarSubtitle => 83
            case TitleBarTall => 84
            case IsBackButtonVisible => 85
            case IsPaneToggleButtonVisible => 86
            case PivotTitle => 87
            case PivotItemHeader => 88
            case BreadcrumbItems => 89
            case IsTextSelectionEnabled => 90
            case TextWrappingWrap => 91
            case AcceptsReturn => 92
            case PasswordValue => 93
            case PasswordRevealMode => 94
            case IsPasswordRevealButtonEnabled => 95
            case RadioButtonsItems => 96
            case RadioButtonsMaxColumns => 97
            case ComboBoxItems => 98
            case ListBoxItems => 99
            case IsEditable => 100
            case AttachedCanvasLeft => 101
            case AttachedCanvasTop => 102
            case AttachedCanvasZIndex => 103
            case ContentDialogTitle => 104
            case ContentDialogBody => 105
            case ContentDialogPrimaryText => 106
            case ContentDialogSecondaryText => 107
            case ContentDialogCloseText => 108
            case ContentDialogPrimaryEnabled => 109
            case ContentDialogSecondaryEnabled => 110
            case ContentDialogIsOpen => 111
            case ButtonStyleVariant => 112
            case RepeatDelay => 113
            case RepeatInterval => 114
            case MaxRating => 115
            case RatingCaption => 116
            case IsReadOnly => 117
            case PlaceholderValue => 118
            case ColorValue => 119
            case IsAlphaEnabled => 120
            case IsHexInputVisible => 121
            case IsColorSliderVisible => 122
            case IsColorChannelTextInputVisible => 123
            case DayVisible => 124
            case MonthVisible => 125
            case YearVisible => 126
            case ClockIdentifier => 127
            case MinuteIncrement => 128
            case IsTodayHighlighted => 129
            case IsCalendarOpen => 130
            case IsGroupLabelVisible => 131
            case AutoSuggestItems => 132
            case AutoSuggestText => 133
            case SplitViewDisplayMode => 134
            case SplitViewIsPaneOpen => 135
            case SplitViewOpenPaneLength => 136
            case SplitViewCompactPaneLength => 137
            case MenuBarItems => 138
            case MenuFlyoutItems => 139
            case TreeViewNodes => 140
            case TreeViewSelectionMode => 141
            case CommandBarPrimaryCommands => 142
            case CommandBarSecondaryCommands => 143
            case CommandBarDefaultLabelPosition => 144
            case CommandBarFlyoutCommands => 145
            case TeachingTipTitle => 146
            case TeachingTipSubtitle => 147
            case TeachingTipIsOpen => 148
            case TeachingTipIsLightDismiss => 149
            case TeachingTipPlacement => 150
            case TeachingTipActionButton => 151
            case TeachingTipCloseButton => 152
            case SelectorBarItems => 153
            case ButtonIcon => 154
            case RichEditBoxText => 155
            case RichEditBoxIsReadOnly => 156
            case FlyoutContent => 157
            case FlyoutPlacement => 158
            case RelativePanelAlignLeftWithPanel => 159
            case RelativePanelAlignRightWithPanel => 160
            case RelativePanelAlignTopWithPanel => 161
            case RelativePanelAlignBottomWithPanel => 162
            case RelativePanelAlignHCenterWithPanel => 163
            case RelativePanelAlignVCenterWithPanel => 164
            case Resources => 165
            case IsAddTabButtonVisible => 166
        }
    }

    public func hashCode(): Int64 { tag() }
    public operator func ==(other: Prop): Bool { tag() == other.tag() }
    public operator func !=(other: Prop): Bool { tag() != other.tag() }
}

// ============================================================================
// Event — closed enum of every backend-observable input event (~50). tag()-keyed.
// ============================================================================

public enum Event <: Hashable & Equatable<Event> {
    | Click | CheckedChanged | TextChanged | Toggled | ValueChanged
    | RadioChecked | ExpandedChanged | InfoBarClosed | TabSelectionChanged
    | TabCloseRequested | NavSelectionChanged | NavBackRequested
    | NavSearchQuerySubmitted | NavSearchTextChanged | NavSearchSuggestionChosen
    | TitleBarBackRequested | TitleBarPaneToggle | PivotSelectionChanged
    | BreadcrumbItemClicked | PasswordChanged | RadioButtonsSelectionChanged
    | ComboSelectionChanged | ContentDialogClosed | RatingValueChanged
    | ColorChanged | DateSelected | TimeSelected | CalendarDateSelected
    | CalendarViewSelectionChanged | ListBoxSelectionChanged | SplitButtonClick
    | AutoSuggestTextChanged | AutoSuggestQuerySubmitted
    | AutoSuggestSuggestionChosen | SplitViewPaneClosed | MenuBarItemClicked
    | MenuFlyoutItemClicked | TreeViewItemInvoked | CommandBarClick
    | CommandBarFlyoutClick | TeachingTipClosed | TeachingTipActionClick
    | SelectorBarSelectionChanged | RichEditBoxTextChanged | FlyoutOpened
    | FlyoutClosed
    // TabView: the built-in "+" add-tab button was clicked.
    | AddTabButtonClick

    public func tag(): Int64 {
        match (this) {
            case Click => 0
            case CheckedChanged => 1
            case TextChanged => 2
            case Toggled => 3
            case ValueChanged => 4
            case RadioChecked => 5
            case ExpandedChanged => 6
            case InfoBarClosed => 7
            case TabSelectionChanged => 8
            case TabCloseRequested => 9
            case NavSelectionChanged => 10
            case NavBackRequested => 11
            case NavSearchQuerySubmitted => 12
            case NavSearchTextChanged => 13
            case NavSearchSuggestionChosen => 14
            case TitleBarBackRequested => 15
            case TitleBarPaneToggle => 16
            case PivotSelectionChanged => 17
            case BreadcrumbItemClicked => 18
            case PasswordChanged => 19
            case RadioButtonsSelectionChanged => 20
            case ComboSelectionChanged => 21
            case ContentDialogClosed => 22
            case RatingValueChanged => 23
            case ColorChanged => 24
            case DateSelected => 25
            case TimeSelected => 26
            case CalendarDateSelected => 27
            case CalendarViewSelectionChanged => 28
            case ListBoxSelectionChanged => 29
            case SplitButtonClick => 30
            case AutoSuggestTextChanged => 31
            case AutoSuggestQuerySubmitted => 32
            case AutoSuggestSuggestionChosen => 33
            case SplitViewPaneClosed => 34
            case MenuBarItemClicked => 35
            case MenuFlyoutItemClicked => 36
            case TreeViewItemInvoked => 37
            case CommandBarClick => 38
            case CommandBarFlyoutClick => 39
            case TeachingTipClosed => 40
            case TeachingTipActionClick => 41
            case SelectorBarSelectionChanged => 42
            case RichEditBoxTextChanged => 43
            case FlyoutOpened => 44
            case FlyoutClosed => 45
            case AddTabButtonClick => 46
        }
    }

    public func hashCode(): Int64 { tag() }
    public operator func ==(other: Event): Bool { tag() == other.tag() }
    public operator func !=(other: Event): Bool { tag() != other.tag() }
}

// EventKey encodes (ControlId, Event) into a single hashable key for the
// handler registry (avoids needing tuple Hashable conformance).
public struct EventKey <: Hashable & Equatable<EventKey> {
    public let idRaw: UInt32
    public let eventTag: Int64
    public init(id: ControlId, event: Event) {
        this.idRaw = id.raw
        this.eventTag = event.tag()
    }
    public func hashCode(): Int64 { (Int64(idRaw) * 131) + eventTag }
    public operator func ==(other: EventKey): Bool {
        idRaw == other.idRaw && eventTag == other.eventTag
    }
    public operator func !=(other: EventKey): Bool { !(this == other) }
}

// ============================================================================
// PropValue — tagged union of every value type that can appear in set_prop.
// Unset clears a previously-applied value. equals() does the diff comparison
// (no derive(PartialEq) in Cangjie).
// ============================================================================

public enum PropValue {
    | Str(String)
    | F64(Float64)
    | U16(UInt16)
    | BoolV(Bool)
    | I32(Int32)
    | ThicknessV(Thickness)
    | HAlign(HorizontalAlignment)
    | VAlign(VerticalAlignment)
    | Vertical(Bool)
    | BrushV(Brush)
    | GridLengths(Array<GridLength>)
    | ScrollVis(ScrollBarVisibility)
    | InfoBarSev(InfoBarSeverity)
    | ImageStretchV(ImageStretch)
    | LineEndpointsV(LineEndpoints)
    | NavMenuItems(ArrayList<NavViewItem>)
    | NavPaneDisplayMode(NavViewPaneDisplayMode)
    | StrList(ArrayList<String>)
    | PasswordRevealModeV(PasswordRevealMode)
    | ButtonStyleV(ButtonStyle)
    | ColorV(UInt8, UInt8, UInt8, UInt8)
    | MenuBarItemsV(ArrayList<MenuBarItemDef>)
    | MenuFlyoutItemsV(ArrayList<MenuItemDef>)
    | TreeViewNodesV(ArrayList<TreeNodeDef>)
    | TreeViewSelectionModeV(TreeSelectionMode)
    | ScrollViewScrollBarVisV(ScrollViewScrollBarVisibility)
    | CommandBarCommandsV(ArrayList<CommandBarCommandDef>)
    | CommandBarLabelPositionV(CommandBarLabelPos)
    | CommandBarFlyoutDefV(ArrayList<CommandBarCommandDef>, ArrayList<CommandBarCommandDef>)
    | TeachingTipPlacementV(TeachingTipPlacement)
    | SelectorBarItemsV(ArrayList<SelectorBarItemDef>)
    | SymbolIconV(SymbolGlyph)
    | FlyoutPlacementV(FlyoutPlacement)
    | ResourcesV(HashMap<String, String>)
    | Unset

    public func equals(other: PropValue): Bool {
        match ((this, other)) {
            case (Str(a), Str(b)) => a == b
            case (F64(a), F64(b)) => a == b
            case (U16(a), U16(b)) => a == b
            case (BoolV(a), BoolV(b)) => a == b
            case (I32(a), I32(b)) => a == b
            case (ThicknessV(a), ThicknessV(b)) => a == b
            case (HAlign(a), HAlign(b)) => a == b
            case (VAlign(a), VAlign(b)) => a == b
            case (Vertical(a), Vertical(b)) => a == b
            case (BrushV(a), BrushV(b)) => a == b
            case (GridLengths(a), GridLengths(b)) => arrayEq<GridLength>(a, b)
            case (ScrollVis(a), ScrollVis(b)) => a == b
            case (InfoBarSev(a), InfoBarSev(b)) => a == b
            case (ImageStretchV(a), ImageStretchV(b)) => a == b
            case (LineEndpointsV(a), LineEndpointsV(b)) => a == b
            case (NavMenuItems(a), NavMenuItems(b)) => navItemListEq(a, b)
            case (NavPaneDisplayMode(a), NavPaneDisplayMode(b)) => a == b
            case (StrList(a), StrList(b)) => strListEq(a, b)
            case (PasswordRevealModeV(a), PasswordRevealModeV(b)) => a == b
            case (ButtonStyleV(a), ButtonStyleV(b)) => a == b
            case (ColorV(a1, a2, a3, a4), ColorV(b1, b2, b3, b4)) =>
                a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4
            case (MenuBarItemsV(a), MenuBarItemsV(b)) => menuBarListEq(a, b)
            case (MenuFlyoutItemsV(a), MenuFlyoutItemsV(b)) => menuItemListEq(a, b)
            case (TreeViewNodesV(a), TreeViewNodesV(b)) => treeNodeListEq(a, b)
            case (TreeViewSelectionModeV(a), TreeViewSelectionModeV(b)) => a == b
            case (ScrollViewScrollBarVisV(a), ScrollViewScrollBarVisV(b)) => a == b
            case (CommandBarCommandsV(a), CommandBarCommandsV(b)) => cmdListEq(a, b)
            case (CommandBarLabelPositionV(a), CommandBarLabelPositionV(b)) => a == b
            case (CommandBarFlyoutDefV(ap, asec), CommandBarFlyoutDefV(bp, bsec)) =>
                cmdListEq(ap, bp) && cmdListEq(asec, bsec)
            case (TeachingTipPlacementV(a), TeachingTipPlacementV(b)) => a == b
            case (SelectorBarItemsV(a), SelectorBarItemsV(b)) => selectorListEq(a, b)
            case (SymbolIconV(a), SymbolIconV(b)) => a == b
            case (FlyoutPlacementV(a), FlyoutPlacementV(b)) => a == b
            case (ResourcesV(a), ResourcesV(b)) => resourcesEq(a, b)
            case (Unset, Unset) => true
            case _ => false
        }
    }
}

func resourcesEq(a: HashMap<String, String>, b: HashMap<String, String>): Bool {
    if (a.size != b.size) { return false }
    for ((k, v) in a) {
        match (b.get(k)) {
            case Some(bv) => if (bv != v) { return false }
            case None => return false
        }
    }
    true
}

// ============================================================================
// EventHandler — typed wrapper around a Callback for a specific Event payload
// shape. invoke* accessors throw on a mismatching variant (replaces Rust
// panic). equals() uses callback identity so reconciler can skip rebinding.
// ============================================================================

public class HandlerMismatchException <: Exception {
    public init(msg: String) { super(msg) }
}

public enum EventHandler {
    | ClickH(Callback<Unit>)
    | CheckedChangedH(Callback<Bool>)
    | TextChangedH(Callback<String>)
    | ValueChangedH(Callback<Float64>)
    | IndexChangedH(Callback<Int32>)
    | TabKeyH(Callback<String>)
    | ColorChangedH(Callback<(UInt8, UInt8, UInt8, UInt8)>)
    | DateTimeChangedH(Callback<ReactorDateTime>)
    | TimeChangedH(Callback<ReactorTimeSpan>)

    public func tag(): Int64 {
        match (this) {
            case ClickH(_) => 0
            case CheckedChangedH(_) => 1
            case TextChangedH(_) => 2
            case ValueChangedH(_) => 3
            case IndexChangedH(_) => 4
            case TabKeyH(_) => 5
            case ColorChangedH(_) => 6
            case DateTimeChangedH(_) => 7
            case TimeChangedH(_) => 8
        }
    }

    public func invoke(): Unit {
        match (this) {
            case ClickH(cb) => cb.invoke(())
            case _ => throw HandlerMismatchException("EventHandler.invoke() on non-Click handler")
        }
    }

    public func invokeBool(v: Bool): Unit {
        match (this) {
            case CheckedChangedH(cb) => cb.invoke(v)
            case _ => throw HandlerMismatchException("EventHandler.invokeBool() on mismatching handler")
        }
    }

    public func invokeString(s: String): Unit {
        match (this) {
            case TextChangedH(cb) => cb.invoke(s)
            case TabKeyH(cb) => cb.invoke(s)
            case _ => throw HandlerMismatchException("EventHandler.invokeString() on mismatching handler")
        }
    }

    public func invokeF64(v: Float64): Unit {
        match (this) {
            case ValueChangedH(cb) => cb.invoke(v)
            case _ => throw HandlerMismatchException("EventHandler.invokeF64() on mismatching handler")
        }
    }

    public func invokeI32(v: Int32): Unit {
        match (this) {
            case IndexChangedH(cb) => cb.invoke(v)
            case _ => throw HandlerMismatchException("EventHandler.invokeI32() on mismatching handler")
        }
    }

    public func invokeColor(a: UInt8, r: UInt8, g: UInt8, b: UInt8): Unit {
        match (this) {
            case ColorChangedH(cb) => cb.invoke((a, r, g, b))
            case _ => throw HandlerMismatchException("EventHandler.invokeColor() on mismatching handler")
        }
    }

    public func invokeDateTime(dt: ReactorDateTime): Unit {
        match (this) {
            case DateTimeChangedH(cb) => cb.invoke(dt)
            case _ => throw HandlerMismatchException("EventHandler.invokeDateTime() on mismatching handler")
        }
    }

    public func invokeTimeSpan(ts: ReactorTimeSpan): Unit {
        match (this) {
            case TimeChangedH(cb) => cb.invoke(ts)
            case _ => throw HandlerMismatchException("EventHandler.invokeTimeSpan() on mismatching handler")
        }
    }

    // Identity equality (callback id) so re-renders with the same handler
    // don't force a re-bind. Different variants are never equal.
    public func equals(other: EventHandler): Bool {
        match ((this, other)) {
            case (ClickH(a), ClickH(b)) => a.sameAs(b)
            case (CheckedChangedH(a), CheckedChangedH(b)) => a.sameAs(b)
            case (TextChangedH(a), TextChangedH(b)) => a.sameAs(b)
            case (ValueChangedH(a), ValueChangedH(b)) => a.sameAs(b)
            case (IndexChangedH(a), IndexChangedH(b)) => a.sameAs(b)
            case (TabKeyH(a), TabKeyH(b)) => a.sameAs(b)
            case (ColorChangedH(a), ColorChangedH(b)) => a.sameAs(b)
            case (DateTimeChangedH(a), DateTimeChangedH(b)) => a.sameAs(b)
            case (TimeChangedH(a), TimeChangedH(b)) => a.sameAs(b)
            case _ => false
        }
    }
}

// ============================================================================
// Backend — interface the reconciler drives. The eight core methods are
// abstract; everything else has a no-op default body so new backends keep
// compiling (interface default methods verified available in P2 probe).
// ============================================================================

public interface Backend {
    func create(kind: ControlKind): ControlId
    func setProp(id: ControlId, which: Prop, value: PropValue): Unit
    func appendChild(parent: ControlId, child: ControlId): Unit
    func insertChild(parent: ControlId, index: Int64, child: ControlId): Unit
    func removeChild(parent: ControlId, index: Int64): Unit
    func replaceChild(parent: ControlId, index: Int64, newChild: ControlId): Unit
    func moveChild(parent: ControlId, fromIndex: Int64, toIndex: Int64): Unit
    func destroy(id: ControlId): Unit
    func attachEvent(id: ControlId, event: Event, handler: EventHandler): Unit

    func detachEvent(id: ControlId, event: Event): Unit { let _ = id; let _ = event }
    func setTemplatedItemCount(id: ControlId, count: Int64): Unit { let _ = id; let _ = count }
    func setTemplatedRowContent(listId: ControlId, rowIdx: Int64, content: ?ControlId): Unit {
        let _ = listId; let _ = rowIdx; let _ = content
    }
    func setTemplatedSelectedIndex(id: ControlId, index: Int32): Unit { let _ = id; let _ = index }
    func setTemplatedSelectionMode(id: ControlId, mode: SelectionMode): Unit { let _ = id; let _ = mode }
    func scrollTemplatedToIndex(id: ControlId, index: Int32): Unit { let _ = id; let _ = index }
    func attachTemplatedSelectionChanged(id: ControlId, handler: Callback<Int32>): Unit {
        let _ = id; let _ = handler
    }
    func attachTemplatedRealization(id: ControlId, realize: (Int64) -> Unit, recycle: (Int64) -> Unit): Unit {
        let _ = id; let _ = realize; let _ = recycle
    }
    func setHeaderElement(id: ControlId, headerId: ?ControlId): Unit { let _ = id; let _ = headerId }
    func setPaneElement(id: ControlId, paneId: ?ControlId): Unit { let _ = id; let _ = paneId }
    func setThemeBindings(id: ControlId, kind: ControlKind, bindings: Array<(Prop, ThemeRef)>): Unit {
        let _ = id; let _ = kind; let _ = bindings
    }
    func onThemeChanged(): Unit {}
    func setImplicitTransitions(id: ControlId, transitions: ?ImplicitTransitions): Unit {
        let _ = id; let _ = transitions
    }
    func setLayoutAnimation(id: ControlId, config: ?LayoutAnimationConfig): Unit {
        let _ = id; let _ = config
    }
    func runPropertyAnimation(id: ControlId, config: ?AnimationConfig): Unit {
        let _ = id; let _ = config
    }
    func setRichTextParagraphs(id: ControlId, paragraphs: Array<RichTextParagraph>): Unit {
        let _ = id; let _ = paragraphs
    }
    func setAccessibility(id: ControlId, accessibility: AccessibilityModifiers): Unit {
        let _ = id; let _ = accessibility
    }
    func setKeyboardAccelerators(id: ControlId, accelerators: Array<KeyboardAccelerator>): Unit {
        let _ = id; let _ = accelerators
    }
    func setTooltip(id: ControlId, tooltip: ?Tooltip): Unit { let _ = id; let _ = tooltip }
    func setPointerHandlers(id: ControlId, handlers: ?PointerHandlers): Unit {
        let _ = id; let _ = handlers
    }

    // Retrieve the underlying platform element for `id` as a backend-neutral
    // NativeElement token (for interop, e.g. attaching a native swap chain to a
    // SwapChainPanel). Returns None on non-WinUI backends or for an unknown id.
    // Mirrors the reference Backend::get_native_element (which returns an
    // IInspectable); here the token is opaque so core stays backend-agnostic.
    func getNativeElement(id: ControlId): ?NativeElement { let _ = id; None }
}
