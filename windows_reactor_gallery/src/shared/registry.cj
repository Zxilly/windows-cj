package windows_reactor_gallery.shared

import std.collection.*

// ============================================================================
// Control metadata registry. Pure data: the categories list, the full control
// table, and lookup/search/category helpers consumed by the shell and router.
// ============================================================================

// Metadata for a single control in the gallery.
public class ControlInfo {
    public let title: String
    public let description: String
    public let category: String
    public let icon: String
    public let tag: String
    public let image: String

    public init(title: String, description: String, category: String, icon: String, tag: String, image: String) {
        this.title = title
        this.description = description
        this.category = category
        this.icon = icon
        this.tag = tag
        this.image = image
    }
}

// The category display names, in display order.
public let CATEGORIES: Array<String> = [
    "Basic Input",
    "Collections",
    "Date and Time",
    "Design Guidance",
    "Dialogs and Flyouts",
    "Layout",
    "Media",
    "Menus and Toolbars",
    "Navigation",
    "Status and Info",
    "Text"
]

// The complete control table. Built lazily once and cached.
class AllControlsCell {
    var value: ?Array<ControlInfo> = None
}
let allControlsCell = AllControlsCell()

public func ALL_CONTROLS(): Array<ControlInfo> {
    match (allControlsCell.value) {
        case Some(v) => return v
        case None => ()
    }
    let v = buildAllControls()
    allControlsCell.value = Some(v)
    v
}

func buildAllControls(): Array<ControlInfo> {
    [
        // Basic Input
        ControlInfo("Button", "A button that responds to user clicks.", "Basic Input", "\u{E73A}", "button", "Button.png"),
        ControlInfo("CheckBox", "A control that a user can select or clear.", "Basic Input", "\u{E73A}", "check-box", "Checkbox.png"),
        ControlInfo("ColorPicker", "A control that lets a user pick a color.", "Basic Input", "\u{E73A}", "color-picker", "ColorPicker.png"),
        ControlInfo("ComboBox", "A drop-down list of items a user can select from.", "Basic Input", "\u{E73A}", "combo-box", "ComboBox.png"),
        ControlInfo("DropDownButton", "A button that displays a flyout of choices.", "Basic Input", "\u{E73A}", "drop-down-button", "DropDownButton.png"),
        ControlInfo("HyperlinkButton", "A button that appears as a hyperlink.", "Basic Input", "\u{E73A}", "hyperlink-button", "HyperlinkButton.png"),
        ControlInfo("NumberBox", "A text control for entering numeric values.", "Basic Input", "\u{E73A}", "number-box", "NumberBox.png"),
        ControlInfo("PasswordBox", "A text input that conceals typed characters.", "Basic Input", "\u{E73A}", "password-box", "PasswordBox.png"),
        ControlInfo("RadioButton", "Select one option from a group.", "Basic Input", "\u{E73A}", "radio-button", "RadioButton.png"),
        ControlInfo("RatingControl", "A control that lets users provide a star rating.", "Basic Input", "\u{E73A}", "rating-control", "RatingControl.png"),
        ControlInfo("RepeatButton", "A button that raises click events while pressed.", "Basic Input", "\u{E73A}", "repeat-button", "RepeatButton.png"),
        ControlInfo("Slider", "Select from a range of values by moving a thumb.", "Basic Input", "\u{E73A}", "slider", "Slider.png"),
        ControlInfo("SplitButton", "A button with a primary action and flyout menu.", "Basic Input", "\u{E73A}", "split-button", "SplitButton.png"),
        ControlInfo("TextBox", "A single-line or multi-line text input field.", "Basic Input", "\u{E73A}", "text-box", "TextBox.png"),
        ControlInfo("ToggleButton", "A button that toggles between two states.", "Basic Input", "\u{E73A}", "toggle-button", "ToggleButton.png"),
        ControlInfo("ToggleSwitch", "A switch between two mutually exclusive states.", "Basic Input", "\u{E73A}", "toggle-switch", "ToggleSwitch.png"),
        // Collections
        ControlInfo("FlipView", "Presents one item at a time with flipping navigation.", "Collections", "\u{E8A9}", "flip-view", "FlipView.png"),
        ControlInfo("GridView", "Displays items in a horizontally wrapping grid.", "Collections", "\u{E8A9}", "grid-view", "GridView.png"),
        ControlInfo("ListBox", "A list of selectable items presented inline.", "Collections", "\u{E8A9}", "list-box", "ListBox.png"),
        ControlInfo("ListView", "Displays items in a vertical scrolling list.", "Collections", "\u{E8A9}", "list-view", "ListView.png"),
        ControlInfo("TreeView", "A hierarchical list with expanding and collapsing nodes.", "Collections", "\u{E8A9}", "tree-view", "TreeView.png"),
        // Date and Time
        ControlInfo("CalendarDatePicker", "Pick a date from a calendar dropdown.", "Date and Time", "\u{E787}", "calendar-date-picker", "CalendarDatePicker.png"),
        ControlInfo("CalendarView", "A calendar display for selecting a date.", "Date and Time", "\u{E787}", "calendar-view", "CalendarView.png"),
        ControlInfo("DatePicker", "Pick a date using spinners.", "Date and Time", "\u{E787}", "date-picker", "DatePicker.png"),
        ControlInfo("TimePicker", "Pick a time using spinners.", "Date and Time", "\u{E787}", "time-picker", "TimePicker.png"),
        // Design Guidance
        ControlInfo("Typography", "The WinUI 3 type ramp and text styles.", "Design Guidance", "\u{E8D2}", "typography", "TextBlock.png"),
        ControlInfo("Color", "System accent and semantic color palette.", "Design Guidance", "\u{E790}", "color", "ColorPaletteResources.png"),
        ControlInfo("Spacing", "Standard spacing values for consistent layouts.", "Design Guidance", "\u{E8A1}", "spacing", ""),
        ControlInfo("Iconography", "Segoe Fluent Icons symbol set.", "Design Guidance", "\u{E734}", "iconography", ""),
        ControlInfo("Geometry", "Corner radius resources for consistent shape language.", "Design Guidance", "\u{E809}", "geometry", ""),
        ControlInfo("Theme", "Light, dark, and high-contrast theme guidance.", "Design Guidance", "\u{E771}", "theme", "ThemeTransition.png"),
        ControlInfo("Materials", "Window backdrop materials (Mica, Acrylic) for depth and hierarchy.", "Design Guidance", "\u{E81E}", "materials", "Acrylic.png"),
        // Dialogs and Flyouts
        ControlInfo("CommandBarFlyout", "A flyout that provides quick access to common commands.", "Dialogs and Flyouts", "\u{E8BD}", "command-bar-flyout", "CommandBarFlyout.png"),
        ControlInfo("ContentDialog", "A modal dialog box with content and actions.", "Dialogs and Flyouts", "\u{E8BD}", "content-dialog", "ContentDialog.png"),
        ControlInfo("Flyout", "A lightweight popup for contextual info.", "Dialogs and Flyouts", "\u{E8BD}", "flyout", "Flyout.png"),
        ControlInfo("TeachingTip", "A notification flyout for guiding users.", "Dialogs and Flyouts", "\u{E8BD}", "teaching-tip", "TeachingTip.png"),
        ControlInfo("MenuFlyout", "A flyout that displays a list of menu commands.", "Dialogs and Flyouts", "\u{E8DE}", "menu-flyout", "MenuFlyout.png"),
        // Layout
        ControlInfo("Border", "A container that draws a border around its child.", "Layout", "\u{E8A1}", "border", "Border.png"),
        ControlInfo("Canvas", "Absolute positioning of child elements.", "Layout", "\u{E8A1}", "canvas", "Canvas.png"),
        ControlInfo("Expander", "Expands and collapses to show or hide content.", "Layout", "\u{E8A1}", "expander", "Expander.png"),
        ControlInfo("Grid", "Arranges children in rows and columns.", "Layout", "\u{E8A1}", "grid", "Grid.png"),
        ControlInfo("RelativePanel", "Positions children relative to each other.", "Layout", "\u{E8A1}", "relative-panel", "RelativePanel.png"),
        ControlInfo("ScrollView", "A scrollable container for overflowing content.", "Layout", "\u{E8A1}", "scroll-view", "ScrollView.png"),
        ControlInfo("SplitView", "A collapsible pane and content area.", "Layout", "\u{E8A1}", "split-view", "SplitView.png"),
        ControlInfo("StackPanel", "Arranges children in a single line.", "Layout", "\u{E8A1}", "stack-panel", "StackPanel.png"),
        ControlInfo("Viewbox", "Scales its child to fill available space.", "Layout", "\u{E8A1}", "viewbox", "Viewbox.png"),
        // Media
        ControlInfo("Image", "Displays an image from a file or URI.", "Media", "\u{E8B9}", "image", "Image.png"),
        ControlInfo("PersonPicture", "A circular avatar for a person.", "Media", "\u{E8B9}", "person-picture", "PersonPicture.png"),
        // Menus and Toolbars
        ControlInfo("CommandBar", "A toolbar for app commands and actions.", "Menus and Toolbars", "\u{E700}", "command-bar", "CommandBar.png"),
        ControlInfo("MenuBar", "A horizontal bar hosting drop-down menus.", "Menus and Toolbars", "\u{E700}", "menu-bar", "MenuBar.png"),
        ControlInfo("SelectorBar", "Switch between different views or modes.", "Menus and Toolbars", "\u{E700}", "selector-bar", ""),
        // Navigation
        ControlInfo("BreadcrumbBar", "A trail showing the navigation path.", "Navigation", "\u{E8B0}", "breadcrumb-bar", "BreadcrumbBar.png"),
        ControlInfo("NavigationView", "A side or top navigation pane.", "Navigation", "\u{E8B0}", "navigation-view", "NavigationView.png"),
        ControlInfo("Pivot", "A tabbed interface for switching sections.", "Navigation", "\u{E8B0}", "pivot", "Pivot.png"),
        ControlInfo("TabView", "Closable, rearrangeable tabs.", "Navigation", "\u{E8B0}", "tab-view", "TabView.png"),
        ControlInfo("TitleBar", "A customizable application title bar.", "Navigation", "\u{E8B0}", "title-bar", "TitleBar.png"),
        // Status and Info
        ControlInfo("InfoBadge", "A small indicator conveying status.", "Status and Info", "\u{E946}", "info-badge", "InfoBadge.png"),
        ControlInfo("InfoBar", "A dismissible bar for app-level messages.", "Status and Info", "\u{E946}", "info-bar", "InfoBar.png"),
        ControlInfo("ProgressBar", "A horizontal bar showing progress.", "Status and Info", "\u{E946}", "progress-bar", "ProgressBar.png"),
        ControlInfo("ProgressRing", "A circular indicator of ongoing progress.", "Status and Info", "\u{E946}", "progress-ring", "ProgressRing.png"),
        ControlInfo("ToolTip", "A popup with helpful text on hover.", "Status and Info", "\u{E946}", "tool-tip", "ToolTip.png"),
        // Text
        ControlInfo("AutoSuggestBox", "Text input that shows suggestions as you type.", "Text", "\u{E8D2}", "auto-suggest-box", "AutoSuggestBox.png"),
        ControlInfo("RichEditBox", "A rich text editing control.", "Text", "\u{E8D2}", "rich-edit-box", "RichEditBox.png"),
        ControlInfo("RichTextBlock", "Displays formatted, read-only rich text.", "Text", "\u{E8D2}", "rich-text-block", "RichTextBlock.png"),
        ControlInfo("Type Ramp", "Named text factories for the WinUI 3 type ramp.", "Text", "\u{E8D2}", "type-ramp", "TextBlock.png")
    ]
}

// All controls belonging to the named category, in table order.
public func controls_in_category(category: String): ArrayList<ControlInfo> {
    let result = ArrayList<ControlInfo>()
    for (c in ALL_CONTROLS()) {
        if (c.category == category) {
            result.add(c)
        }
    }
    result
}

// Case-insensitive title/description substring search.
public func search(query: String): ArrayList<ControlInfo> {
    let result = ArrayList<ControlInfo>()
    let q = asciiLower(query)
    for (c in ALL_CONTROLS()) {
        if (asciiLower(c.title).contains(q) || asciiLower(c.description).contains(q)) {
            result.add(c)
        }
    }
    result
}

// Stable tag for a category name (lowercase, spaces -> dashes).
public func category_tag(category: String): String {
    var out = ""
    for (byte in asciiLower(category).toArray()) {
        if (byte == b' ') {
            out += "-"
        } else {
            out += String.fromUtf8([byte])
        }
    }
    out
}

// Find the control whose title matches `title`, case-insensitively.
public func findControlByTitle(title: String): ?ControlInfo {
    for (c in ALL_CONTROLS()) {
        if (equalIgnoreAsciiCase(c.title, title)) {
            return Some(c)
        }
    }
    None
}

// ── ASCII case helpers ──────────────────────────────────────────────────────

// Public so sibling page sub-packages (e.g. pages.text's AutoSuggestBox filter)
// can reuse the same ASCII case fold across the package boundary.
public func asciiLower(value: String): String {
    var out = ""
    for (byte in value.toArray()) {
        if (byte >= b'A' && byte <= b'Z') {
            out += String.fromUtf8([byte + 32u8])
        } else {
            out += String.fromUtf8([byte])
        }
    }
    out
}

func equalIgnoreAsciiCase(left: String, right: String): Bool {
    asciiLower(left) == asciiLower(right)
}
