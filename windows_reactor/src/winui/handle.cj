package windows_reactor.winui

import windows_reactor.core.{ControlKind}
import windows_core.{OutSlot}
import windows_interface.{IInspectable}
import windows_common.Microsoft.UI.Xaml.Controls.{
    TextBlock, Button, StackPanel, Border, CheckBox, TextBox, Grid, ScrollViewer,
    ToggleSwitch, Slider, RadioButton, NumberBox, ProgressBar, ProgressRing, Expander,
    HyperlinkButton, InfoBar, InfoBadge, PersonPicture, Image, TabView, TabViewItem,
    NavigationView, TitleBar, Pivot, PivotItem, BreadcrumbBar, PasswordBox, RadioButtons,
    ComboBox, Canvas, RichTextBlock, ListView, GridView, FlipView, ContentDialog, Viewbox,
    RatingControl, ColorPicker, DatePicker, TimePicker, CalendarDatePicker, CalendarView,
    ListBox, DropDownButton, SplitButton, AutoSuggestBox, SplitView, MenuBar, ScrollView,
    TreeView, CommandBar, TeachingTip, SelectorBar, RichEditBox, RelativePanel
}
import windows_common.Microsoft.UI.Xaml.Controls.Primitives.{RepeatButton, ToggleButton}
import windows_common.Microsoft.UI.Xaml.Shapes.{Rectangle, Ellipse, Line}
import windows_common.Microsoft.UI.Xaml.{IFrameworkElement, IUIElement}

// ============================================================================
// Handle — one variant per backend-creatable ControlKind (61), each holding its
// backing projection class. The projection is a GC-managed reference that owns
// one COM ref; GC + close() manage its lifetime (no manual AddRef/Release).
//
// Instantiation ABI (spec §8.1, verified against windows_common projections):
//   - default-activatable leaves expose `static new()`:
//       TextBlock, Border, ScrollViewer, ToggleSwitch, Image, PasswordBox,
//       RichTextBlock, Viewbox, AutoSuggestBox, RepeatButton (Primitives),
//       Rectangle / Ellipse / Line (Shapes).
//   - all other composable controls expose the composable factory
//       `CreateInstance(baseInterface, out inner)` and are instantiated with a
//       null aggregation base.
// The judgement was made by reading each projection class: a `static new()`
// means default-activatable; only `CreateInstance` means composable.
// ============================================================================

public enum Handle {
    | TextBlockH(TextBlock)
    | ButtonH(Button)
    | StackPanelH(StackPanel)
    | BorderH(Border)
    | CheckBoxH(CheckBox)
    | TextBoxH(TextBox)
    | GridH(Grid)
    | ScrollViewerH(ScrollViewer)
    | ToggleSwitchH(ToggleSwitch)
    | SliderH(Slider)
    | RadioButtonH(RadioButton)
    | NumberBoxH(NumberBox)
    | ProgressBarH(ProgressBar)
    | ProgressRingH(ProgressRing)
    | ExpanderH(Expander)
    | HyperlinkButtonH(HyperlinkButton)
    | InfoBarH(InfoBar)
    | InfoBadgeH(InfoBadge)
    | PersonPictureH(PersonPicture)
    | ImageH(Image)
    | TabViewH(TabView)
    | TabViewItemH(TabViewItem)
    | NavigationViewH(NavigationView)
    | TitleBarH(TitleBar)
    | PivotH(Pivot)
    | PivotItemH(PivotItem)
    | BreadcrumbBarH(BreadcrumbBar)
    | PasswordBoxH(PasswordBox)
    | RadioButtonsH(RadioButtons)
    | ComboBoxH(ComboBox)
    | CanvasH(Canvas)
    | RectangleH(Rectangle)
    | EllipseH(Ellipse)
    | LineH(Line)
    | RichTextBlockH(RichTextBlock)
    | ListViewH(ListView)
    | GridViewH(GridView)
    | FlipViewH(FlipView)
    | ContentDialogH(ContentDialog)
    | ViewboxH(Viewbox)
    | RepeatButtonH(RepeatButton)
    | RatingControlH(RatingControl)
    | ColorPickerH(ColorPicker)
    | DatePickerH(DatePicker)
    | TimePickerH(TimePicker)
    | CalendarDatePickerH(CalendarDatePicker)
    | CalendarViewH(CalendarView)
    | ListBoxH(ListBox)
    | DropDownButtonH(DropDownButton)
    | SplitButtonH(SplitButton)
    | AutoSuggestBoxH(AutoSuggestBox)
    | SplitViewH(SplitView)
    | MenuBarH(MenuBar)
    | ScrollViewH(ScrollView)
    | TreeViewH(TreeView)
    | CommandBarH(CommandBar)
    | TeachingTipH(TeachingTip)
    | SelectorBarH(SelectorBar)
    | RichEditBoxH(RichEditBox)
    | RelativePanelH(RelativePanel)
    | ToggleButtonH(ToggleButton)
    // SwapChainPanel's backing object is SwapChainPanelControl (see
    // winui/swap_chain.cj), a thin wrapper over the generated windows_common
    // SwapChainPanel projection (it adds the canvas-specific interop surface).
    | SwapChainPanelH(SwapChainPanelControl)

    // Raw identity (defaultInterface) pointer for QI / vtable use. Non-owning.
    public func asRaw(): CPointer<Unit> {
        match (this) {
            case TextBlockH(v) => v.asRaw()
            case ButtonH(v) => v.asRaw()
            case StackPanelH(v) => v.asRaw()
            case BorderH(v) => v.asRaw()
            case CheckBoxH(v) => v.asRaw()
            case TextBoxH(v) => v.asRaw()
            case GridH(v) => v.asRaw()
            case ScrollViewerH(v) => v.asRaw()
            case ToggleSwitchH(v) => v.asRaw()
            case SliderH(v) => v.asRaw()
            case RadioButtonH(v) => v.asRaw()
            case NumberBoxH(v) => v.asRaw()
            case ProgressBarH(v) => v.asRaw()
            case ProgressRingH(v) => v.asRaw()
            case ExpanderH(v) => v.asRaw()
            case HyperlinkButtonH(v) => v.asRaw()
            case InfoBarH(v) => v.asRaw()
            case InfoBadgeH(v) => v.asRaw()
            case PersonPictureH(v) => v.asRaw()
            case ImageH(v) => v.asRaw()
            case TabViewH(v) => v.asRaw()
            case TabViewItemH(v) => v.asRaw()
            case NavigationViewH(v) => v.asRaw()
            case TitleBarH(v) => v.asRaw()
            case PivotH(v) => v.asRaw()
            case PivotItemH(v) => v.asRaw()
            case BreadcrumbBarH(v) => v.asRaw()
            case PasswordBoxH(v) => v.asRaw()
            case RadioButtonsH(v) => v.asRaw()
            case ComboBoxH(v) => v.asRaw()
            case CanvasH(v) => v.asRaw()
            case RectangleH(v) => v.asRaw()
            case EllipseH(v) => v.asRaw()
            case LineH(v) => v.asRaw()
            case RichTextBlockH(v) => v.asRaw()
            case ListViewH(v) => v.asRaw()
            case GridViewH(v) => v.asRaw()
            case FlipViewH(v) => v.asRaw()
            case ContentDialogH(v) => v.asRaw()
            case ViewboxH(v) => v.asRaw()
            case RepeatButtonH(v) => v.asRaw()
            case RatingControlH(v) => v.asRaw()
            case ColorPickerH(v) => v.asRaw()
            case DatePickerH(v) => v.asRaw()
            case TimePickerH(v) => v.asRaw()
            case CalendarDatePickerH(v) => v.asRaw()
            case CalendarViewH(v) => v.asRaw()
            case ListBoxH(v) => v.asRaw()
            case DropDownButtonH(v) => v.asRaw()
            case SplitButtonH(v) => v.asRaw()
            case AutoSuggestBoxH(v) => v.asRaw()
            case SplitViewH(v) => v.asRaw()
            case MenuBarH(v) => v.asRaw()
            case ScrollViewH(v) => v.asRaw()
            case TreeViewH(v) => v.asRaw()
            case CommandBarH(v) => v.asRaw()
            case TeachingTipH(v) => v.asRaw()
            case SelectorBarH(v) => v.asRaw()
            case RichEditBoxH(v) => v.asRaw()
            case RelativePanelH(v) => v.asRaw()
            case ToggleButtonH(v) => v.asRaw()
            case SwapChainPanelH(v) => v.asRaw()
        }
    }

    // QI to IFrameworkElement (Width/Height/Margin/Alignment surface).
    public func asFrameworkElement(): IFrameworkElement {
        match (this) {
            case TextBlockH(v) => v.asIFrameworkElement()
            case ButtonH(v) => v.asIFrameworkElement()
            case StackPanelH(v) => v.asIFrameworkElement()
            case BorderH(v) => v.asIFrameworkElement()
            case CheckBoxH(v) => v.asIFrameworkElement()
            case TextBoxH(v) => v.asIFrameworkElement()
            case GridH(v) => v.asIFrameworkElement()
            case ScrollViewerH(v) => v.asIFrameworkElement()
            case ToggleSwitchH(v) => v.asIFrameworkElement()
            case SliderH(v) => v.asIFrameworkElement()
            case RadioButtonH(v) => v.asIFrameworkElement()
            case NumberBoxH(v) => v.asIFrameworkElement()
            case ProgressBarH(v) => v.asIFrameworkElement()
            case ProgressRingH(v) => v.asIFrameworkElement()
            case ExpanderH(v) => v.asIFrameworkElement()
            case HyperlinkButtonH(v) => v.asIFrameworkElement()
            case InfoBarH(v) => v.asIFrameworkElement()
            case InfoBadgeH(v) => v.asIFrameworkElement()
            case PersonPictureH(v) => v.asIFrameworkElement()
            case ImageH(v) => v.asIFrameworkElement()
            case TabViewH(v) => v.asIFrameworkElement()
            case TabViewItemH(v) => v.asIFrameworkElement()
            case NavigationViewH(v) => v.asIFrameworkElement()
            case TitleBarH(v) => v.asIFrameworkElement()
            case PivotH(v) => v.asIFrameworkElement()
            case PivotItemH(v) => v.asIFrameworkElement()
            case BreadcrumbBarH(v) => v.asIFrameworkElement()
            case PasswordBoxH(v) => v.asIFrameworkElement()
            case RadioButtonsH(v) => v.asIFrameworkElement()
            case ComboBoxH(v) => v.asIFrameworkElement()
            case CanvasH(v) => v.asIFrameworkElement()
            case RectangleH(v) => v.asIFrameworkElement()
            case EllipseH(v) => v.asIFrameworkElement()
            case LineH(v) => v.asIFrameworkElement()
            case RichTextBlockH(v) => v.asIFrameworkElement()
            case ListViewH(v) => v.asIFrameworkElement()
            case GridViewH(v) => v.asIFrameworkElement()
            case FlipViewH(v) => v.asIFrameworkElement()
            case ContentDialogH(v) => v.asIFrameworkElement()
            case ViewboxH(v) => v.asIFrameworkElement()
            case RepeatButtonH(v) => v.asIFrameworkElement()
            case RatingControlH(v) => v.asIFrameworkElement()
            case ColorPickerH(v) => v.asIFrameworkElement()
            case DatePickerH(v) => v.asIFrameworkElement()
            case TimePickerH(v) => v.asIFrameworkElement()
            case CalendarDatePickerH(v) => v.asIFrameworkElement()
            case CalendarViewH(v) => v.asIFrameworkElement()
            case ListBoxH(v) => v.asIFrameworkElement()
            case DropDownButtonH(v) => v.asIFrameworkElement()
            case SplitButtonH(v) => v.asIFrameworkElement()
            case AutoSuggestBoxH(v) => v.asIFrameworkElement()
            case SplitViewH(v) => v.asIFrameworkElement()
            case MenuBarH(v) => v.asIFrameworkElement()
            case ScrollViewH(v) => v.asIFrameworkElement()
            case TreeViewH(v) => v.asIFrameworkElement()
            case CommandBarH(v) => v.asIFrameworkElement()
            case TeachingTipH(v) => v.asIFrameworkElement()
            case SelectorBarH(v) => v.asIFrameworkElement()
            case RichEditBoxH(v) => v.asIFrameworkElement()
            case RelativePanelH(v) => v.asIFrameworkElement()
            case ToggleButtonH(v) => v.asIFrameworkElement()
            case SwapChainPanelH(v) => v.asIFrameworkElement()
        }
    }

    // QI to IUIElement (Opacity / the universal element surface; also the type
    // appended into a Panel's Children vector).
    public func asUIElement(): IUIElement {
        match (this) {
            case TextBlockH(v) => v.asIUIElement()
            case ButtonH(v) => v.asIUIElement()
            case StackPanelH(v) => v.asIUIElement()
            case BorderH(v) => v.asIUIElement()
            case CheckBoxH(v) => v.asIUIElement()
            case TextBoxH(v) => v.asIUIElement()
            case GridH(v) => v.asIUIElement()
            case ScrollViewerH(v) => v.asIUIElement()
            case ToggleSwitchH(v) => v.asIUIElement()
            case SliderH(v) => v.asIUIElement()
            case RadioButtonH(v) => v.asIUIElement()
            case NumberBoxH(v) => v.asIUIElement()
            case ProgressBarH(v) => v.asIUIElement()
            case ProgressRingH(v) => v.asIUIElement()
            case ExpanderH(v) => v.asIUIElement()
            case HyperlinkButtonH(v) => v.asIUIElement()
            case InfoBarH(v) => v.asIUIElement()
            case InfoBadgeH(v) => v.asIUIElement()
            case PersonPictureH(v) => v.asIUIElement()
            case ImageH(v) => v.asIUIElement()
            case TabViewH(v) => v.asIUIElement()
            case TabViewItemH(v) => v.asIUIElement()
            case NavigationViewH(v) => v.asIUIElement()
            case TitleBarH(v) => v.asIUIElement()
            case PivotH(v) => v.asIUIElement()
            case PivotItemH(v) => v.asIUIElement()
            case BreadcrumbBarH(v) => v.asIUIElement()
            case PasswordBoxH(v) => v.asIUIElement()
            case RadioButtonsH(v) => v.asIUIElement()
            case ComboBoxH(v) => v.asIUIElement()
            case CanvasH(v) => v.asIUIElement()
            case RectangleH(v) => v.asIUIElement()
            case EllipseH(v) => v.asIUIElement()
            case LineH(v) => v.asIUIElement()
            case RichTextBlockH(v) => v.asIUIElement()
            case ListViewH(v) => v.asIUIElement()
            case GridViewH(v) => v.asIUIElement()
            case FlipViewH(v) => v.asIUIElement()
            case ContentDialogH(v) => v.asIUIElement()
            case ViewboxH(v) => v.asIUIElement()
            case RepeatButtonH(v) => v.asIUIElement()
            case RatingControlH(v) => v.asIUIElement()
            case ColorPickerH(v) => v.asIUIElement()
            case DatePickerH(v) => v.asIUIElement()
            case TimePickerH(v) => v.asIUIElement()
            case CalendarDatePickerH(v) => v.asIUIElement()
            case CalendarViewH(v) => v.asIUIElement()
            case ListBoxH(v) => v.asIUIElement()
            case DropDownButtonH(v) => v.asIUIElement()
            case SplitButtonH(v) => v.asIUIElement()
            case AutoSuggestBoxH(v) => v.asIUIElement()
            case SplitViewH(v) => v.asIUIElement()
            case MenuBarH(v) => v.asIUIElement()
            case ScrollViewH(v) => v.asIUIElement()
            case TreeViewH(v) => v.asIUIElement()
            case CommandBarH(v) => v.asIUIElement()
            case TeachingTipH(v) => v.asIUIElement()
            case SelectorBarH(v) => v.asIUIElement()
            case RichEditBoxH(v) => v.asIUIElement()
            case RelativePanelH(v) => v.asIUIElement()
            case ToggleButtonH(v) => v.asIUIElement()
            case SwapChainPanelH(v) => v.asIUIElement()
        }
    }

    public func kindName(): String {
        match (this) {
            case TextBlockH(_) => "TextBlock"
            case ButtonH(_) => "Button"
            case StackPanelH(_) => "StackPanel"
            case BorderH(_) => "Border"
            case CheckBoxH(_) => "CheckBox"
            case TextBoxH(_) => "TextBox"
            case GridH(_) => "Grid"
            case ScrollViewerH(_) => "ScrollViewer"
            case ToggleSwitchH(_) => "ToggleSwitch"
            case SliderH(_) => "Slider"
            case RadioButtonH(_) => "RadioButton"
            case NumberBoxH(_) => "NumberBox"
            case ProgressBarH(_) => "ProgressBar"
            case ProgressRingH(_) => "ProgressRing"
            case ExpanderH(_) => "Expander"
            case HyperlinkButtonH(_) => "HyperlinkButton"
            case InfoBarH(_) => "InfoBar"
            case InfoBadgeH(_) => "InfoBadge"
            case PersonPictureH(_) => "PersonPicture"
            case ImageH(_) => "Image"
            case TabViewH(_) => "TabView"
            case TabViewItemH(_) => "TabViewItem"
            case NavigationViewH(_) => "NavigationView"
            case TitleBarH(_) => "TitleBar"
            case PivotH(_) => "Pivot"
            case PivotItemH(_) => "PivotItem"
            case BreadcrumbBarH(_) => "BreadcrumbBar"
            case PasswordBoxH(_) => "PasswordBox"
            case RadioButtonsH(_) => "RadioButtons"
            case ComboBoxH(_) => "ComboBox"
            case CanvasH(_) => "Canvas"
            case RectangleH(_) => "Rectangle"
            case EllipseH(_) => "Ellipse"
            case LineH(_) => "Line"
            case RichTextBlockH(_) => "RichTextBlock"
            case ListViewH(_) => "ListView"
            case GridViewH(_) => "GridView"
            case FlipViewH(_) => "FlipView"
            case ContentDialogH(_) => "ContentDialog"
            case ViewboxH(_) => "Viewbox"
            case RepeatButtonH(_) => "RepeatButton"
            case RatingControlH(_) => "RatingControl"
            case ColorPickerH(_) => "ColorPicker"
            case DatePickerH(_) => "DatePicker"
            case TimePickerH(_) => "TimePicker"
            case CalendarDatePickerH(_) => "CalendarDatePicker"
            case CalendarViewH(_) => "CalendarView"
            case ListBoxH(_) => "ListBox"
            case DropDownButtonH(_) => "DropDownButton"
            case SplitButtonH(_) => "SplitButton"
            case AutoSuggestBoxH(_) => "AutoSuggestBox"
            case SplitViewH(_) => "SplitView"
            case MenuBarH(_) => "MenuBar"
            case ScrollViewH(_) => "ScrollView"
            case TreeViewH(_) => "TreeView"
            case CommandBarH(_) => "CommandBar"
            case TeachingTipH(_) => "TeachingTip"
            case SelectorBarH(_) => "SelectorBar"
            case RichEditBoxH(_) => "RichEditBox"
            case RelativePanelH(_) => "RelativePanel"
            case ToggleButtonH(_) => "ToggleButton"
            case SwapChainPanelH(_) => "SwapChainPanel"
        }
    }

    // Release the backing projection (drops this object's COM ref). Idempotent
    // at the projection level (close() guards).
    public func close(): Unit {
        match (this) {
            case TextBlockH(v) => v.close()
            case ButtonH(v) => v.close()
            case StackPanelH(v) => v.close()
            case BorderH(v) => v.close()
            case CheckBoxH(v) => v.close()
            case TextBoxH(v) => v.close()
            case GridH(v) => v.close()
            case ScrollViewerH(v) => v.close()
            case ToggleSwitchH(v) => v.close()
            case SliderH(v) => v.close()
            case RadioButtonH(v) => v.close()
            case NumberBoxH(v) => v.close()
            case ProgressBarH(v) => v.close()
            case ProgressRingH(v) => v.close()
            case ExpanderH(v) => v.close()
            case HyperlinkButtonH(v) => v.close()
            case InfoBarH(v) => v.close()
            case InfoBadgeH(v) => v.close()
            case PersonPictureH(v) => v.close()
            case ImageH(v) => v.close()
            case TabViewH(v) => v.close()
            case TabViewItemH(v) => v.close()
            case NavigationViewH(v) => v.close()
            case TitleBarH(v) => v.close()
            case PivotH(v) => v.close()
            case PivotItemH(v) => v.close()
            case BreadcrumbBarH(v) => v.close()
            case PasswordBoxH(v) => v.close()
            case RadioButtonsH(v) => v.close()
            case ComboBoxH(v) => v.close()
            case CanvasH(v) => v.close()
            case RectangleH(v) => v.close()
            case EllipseH(v) => v.close()
            case LineH(v) => v.close()
            case RichTextBlockH(v) => v.close()
            case ListViewH(v) => v.close()
            case GridViewH(v) => v.close()
            case FlipViewH(v) => v.close()
            case ContentDialogH(v) => v.close()
            case ViewboxH(v) => v.close()
            case RepeatButtonH(v) => v.close()
            case RatingControlH(v) => v.close()
            case ColorPickerH(v) => v.close()
            case DatePickerH(v) => v.close()
            case TimePickerH(v) => v.close()
            case CalendarDatePickerH(v) => v.close()
            case CalendarViewH(v) => v.close()
            case ListBoxH(v) => v.close()
            case DropDownButtonH(v) => v.close()
            case SplitButtonH(v) => v.close()
            case AutoSuggestBoxH(v) => v.close()
            case SplitViewH(v) => v.close()
            case MenuBarH(v) => v.close()
            case ScrollViewH(v) => v.close()
            case TreeViewH(v) => v.close()
            case CommandBarH(v) => v.close()
            case TeachingTipH(v) => v.close()
            case SelectorBarH(v) => v.close()
            case RichEditBoxH(v) => v.close()
            case RelativePanelH(v) => v.close()
            case ToggleButtonH(v) => v.close()
            case SwapChainPanelH(v) => v.close()
        }
    }
}

// A fresh empty (null-raw, non-owning) IInspectable used as the aggregation base
// for non-aggregated composable instantiation.
func nullBaseInspectable(): IInspectable {
    IInspectable.viewOf(CPointer<Unit>())
}

// Instantiate a composable control with a null aggregation base via its
// CreateInstance factory.
//
// CreateInstance(base, &inner, &outer): the composable contract returns the OUTER
// (delegating) control we keep, AND writes the INNER non-delegating IInspectable into
// the out-slot, AddRef'd. With a null aggregation base the caller owns that inner ref
// and MUST release it — keeping only the outer wrapper. Discarding the out-slot leaked
// the inner COM ref (a handle + the control's non-delegating identity) on EVERY
// composable control creation, so every page mount leaked ~one ref per control and the
// old page's controls were never freed on navigation (the per-navigation native leak).
func makeComposable<T>(create: (IInspectable, OutSlot<IInspectable>) -> T): T {
    let innerSlot = OutSlot<IInspectable>()
    let outer = create(nullBaseInspectable(), innerSlot)
    // CreateInstance projects the inner non-delegating IInspectable into the slot's VALUE
    // (an OWNED IInspectable wrapper). With a null aggregation base the caller owns that
    // inner ref; the OUTER (result) is the full control we keep. Releasing the inner here
    // is what lets the control be freed on teardown — NOT releasing it leaked one COM ref
    // plus the control's non-delegating identity per composable control per page mount, so
    // the OLD page's controls were never freed on navigation (the ~1.76 MB + ~3 handles
    // per-navigation native leak; the slot's `~init` does not release the value).
    match (innerSlot.take()) {
        case Some(inner) => inner.close()
        case None => ()
    }
    outer
}

// Instantiate the projection class for `kind`. Throws on activation failure
// (HRESULT surfaced by the projection). Exhaustive over all 61 ControlKind
// variants — the compiler flags any missing arm if ControlKind widens.
public func makeHandleForKind(kind: ControlKind): Handle {
    match (kind) {
        // ── default-activatable (static new()) ──────────────────────────────
        case TextBlock => Handle.TextBlockH(TextBlock.new())
        case Border => Handle.BorderH(Border.new())
        case ScrollViewer => Handle.ScrollViewerH(ScrollViewer.new())
        case ToggleSwitch => Handle.ToggleSwitchH(ToggleSwitch.new())
        case Image => Handle.ImageH(Image.new())
        case PasswordBox => Handle.PasswordBoxH(PasswordBox.new())
        case RichTextBlock => Handle.RichTextBlockH(RichTextBlock.new())
        case Viewbox => Handle.ViewboxH(Viewbox.new())
        case AutoSuggestBox => Handle.AutoSuggestBoxH(AutoSuggestBox.new())
        case RepeatButton => Handle.RepeatButtonH(RepeatButton.new())
        case Rectangle => Handle.RectangleH(Rectangle.new())
        case Ellipse => Handle.EllipseH(Ellipse.new())
        case Line => Handle.LineH(Line.new())

        // ── composable (CreateInstance with null base) ──────────────────────
        case Button => Handle.ButtonH(makeComposable(Button.CreateInstance))
        case StackPanel => Handle.StackPanelH(makeComposable(StackPanel.CreateInstance))
        case CheckBox => Handle.CheckBoxH(makeComposable(CheckBox.CreateInstance))
        case TextBox => Handle.TextBoxH(makeComposable(TextBox.CreateInstance))
        case Grid => Handle.GridH(makeComposable(Grid.CreateInstance))
        case Slider => Handle.SliderH(makeComposable(Slider.CreateInstance))
        case RadioButton => Handle.RadioButtonH(makeComposable(RadioButton.CreateInstance))
        case NumberBox => Handle.NumberBoxH(makeComposable(NumberBox.CreateInstance))
        case ProgressBar => Handle.ProgressBarH(makeComposable(ProgressBar.CreateInstance))
        case ProgressRing => Handle.ProgressRingH(makeComposable(ProgressRing.CreateInstance))
        case Expander => Handle.ExpanderH(makeComposable(Expander.CreateInstance))
        case HyperlinkButton => Handle.HyperlinkButtonH(makeComposable(HyperlinkButton.CreateInstance))
        case InfoBar => Handle.InfoBarH(makeComposable(InfoBar.CreateInstance))
        case InfoBadge => Handle.InfoBadgeH(makeComposable(InfoBadge.CreateInstance))
        case PersonPicture => Handle.PersonPictureH(makeComposable(PersonPicture.CreateInstance))
        case TabView => Handle.TabViewH(makeComposable(TabView.CreateInstance))
        case TabViewItem => Handle.TabViewItemH(makeComposable(TabViewItem.CreateInstance))
        case NavigationView => Handle.NavigationViewH(makeComposable(NavigationView.CreateInstance))
        case TitleBar => Handle.TitleBarH(makeComposable(TitleBar.CreateInstance))
        case Pivot => Handle.PivotH(makeComposable(Pivot.CreateInstance))
        case PivotItem => Handle.PivotItemH(makeComposable(PivotItem.CreateInstance))
        case BreadcrumbBar => Handle.BreadcrumbBarH(makeComposable(BreadcrumbBar.CreateInstance))
        case RadioButtons => Handle.RadioButtonsH(makeComposable(RadioButtons.CreateInstance))
        case ComboBox => Handle.ComboBoxH(makeComposable(ComboBox.CreateInstance))
        case Canvas => Handle.CanvasH(makeComposable(Canvas.CreateInstance))
        case ListView => Handle.ListViewH(makeComposable(ListView.CreateInstance))
        case GridView => Handle.GridViewH(makeComposable(GridView.CreateInstance))
        case FlipView => Handle.FlipViewH(makeComposable(FlipView.CreateInstance))
        case ContentDialog => Handle.ContentDialogH(makeComposable(ContentDialog.CreateInstance))
        case RatingControl => Handle.RatingControlH(makeComposable(RatingControl.CreateInstance))
        case ColorPicker => Handle.ColorPickerH(makeComposable(ColorPicker.CreateInstance))
        case DatePicker => Handle.DatePickerH(makeComposable(DatePicker.CreateInstance))
        case TimePicker => Handle.TimePickerH(makeComposable(TimePicker.CreateInstance))
        case CalendarDatePicker => Handle.CalendarDatePickerH(makeComposable(CalendarDatePicker.CreateInstance))
        case CalendarView => Handle.CalendarViewH(makeComposable(CalendarView.CreateInstance))
        case ListBox => Handle.ListBoxH(makeComposable(ListBox.CreateInstance))
        case DropDownButton => Handle.DropDownButtonH(makeComposable(DropDownButton.CreateInstance))
        case SplitButton => Handle.SplitButtonH(makeComposable(SplitButton.CreateInstance))
        case SplitView => Handle.SplitViewH(makeComposable(SplitView.CreateInstance))
        case MenuBar => Handle.MenuBarH(makeComposable(MenuBar.CreateInstance))
        case ScrollView => Handle.ScrollViewH(makeComposable(ScrollView.CreateInstance))
        case TreeView => Handle.TreeViewH(makeComposable(TreeView.CreateInstance))
        case CommandBar => Handle.CommandBarH(makeComposable(CommandBar.CreateInstance))
        case TeachingTip => Handle.TeachingTipH(makeComposable(TeachingTip.CreateInstance))
        case SelectorBar => Handle.SelectorBarH(makeComposable(SelectorBar.CreateInstance))
        case RichEditBox => Handle.RichEditBoxH(makeComposable(RichEditBox.CreateInstance))
        case RelativePanel => Handle.RelativePanelH(makeComposable(RelativePanel.CreateInstance))
        case ToggleButton => Handle.ToggleButtonH(makeComposable(ToggleButton.CreateInstance))

        // ── composable (CreateInstance with null base), via SwapChainPanelControl ─
        // SwapChainPanelControl.create() activates the generated windows_common
        // SwapChainPanel projection through its composition factory (makeComposable);
        // see winui/swap_chain.cj.
        case SwapChainPanel => Handle.SwapChainPanelH(SwapChainPanelControl.create())
    }
}
