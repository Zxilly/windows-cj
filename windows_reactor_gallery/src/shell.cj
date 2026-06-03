package windows_reactor_gallery

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*
import windows_reactor_gallery.pages.{home_page, settings_page}
import windows_reactor.winui.{RequestedTheme, setRequestedTheme}

// ============================================================================
// gallery_shell — the top-level shell component. Holds navigation + pane +
// search state, builds the NavigationView tree from the registry, routes the
// content area by the selected tag, and wires the title bar (search box, back /
// pane-toggle buttons, theme switch).
// ============================================================================

// Navigation state: the selected tag plus the back-history stack. Equatable so
// it can back a useState slot (history compares element-wise).
public struct NavState <: Equatable<NavState> {
    public let tag: String
    public let history: Array<String>

    public init(tag: String, history: Array<String>) {
        this.tag = tag
        this.history = history
    }

    public operator func ==(other: NavState): Bool {
        if (tag != other.tag) { return false }
        if (history.size != other.history.size) { return false }
        var i = 0
        while (i < history.size) {
            if (history[i] != other.history[i]) { return false }
            i++
        }
        true
    }

    public operator func !=(other: NavState): Bool { !(this == other) }
}

func pushHistory(history: Array<String>, tag: String): Array<String> {
    let next = ArrayList<String>()
    for (h in history) { next.add(h) }
    next.add(tag)
    next.toArray()
}

func contains(arr: Array<String>, value: String): Bool {
    for (a in arr) {
        if (a == value) { return true }
    }
    false
}

func categoryIcon(category: String): SymbolGlyph {
    if (category == "Basic Input" || category == "Text") {
        return SymbolGlyph.Edit
    } else if (category == "Collections" || category == "Menus and Toolbars") {
        return SymbolGlyph.More
    } else if (category == "Date and Time") {
        return SymbolGlyph.Favorite
    } else if (category == "Design Guidance") {
        return SymbolGlyph.People
    } else if (category == "Dialogs and Flyouts") {
        return SymbolGlyph.Mail
    } else if (category == "Layout") {
        return SymbolGlyph.Find
    } else if (category == "Media") {
        return SymbolGlyph.Camera
    } else if (category == "Navigation") {
        return SymbolGlyph.World
    } else if (category == "Status and Info") {
        return SymbolGlyph.Flag
    }
    SymbolGlyph.Help
}

// Render a category landing page: header + control count + card grid.
func renderCategoryPage(category: String, onNavigate: (String) -> Unit): Element {
    let controls = controls_in_category(category)
    let items = ArrayList<CardItem>()
    for (c in controls) {
        items.add(CardItem(c.title, c.description, c.image, c.tag))
    }

    let root = grid([
        vstack([
            text_block(category).fontSize(28.0).bold().toElement(),
            text_block("${controls.size} controls").opacity(0.6).toElement()
        ]).spacing(4.0).gridRow(0).toElement(),
        atGridRow(card_grid(items, onNavigate), 1)
    ]).rowsOf([GridLength.Auto, GridLength.Star(1.0)])
        .columnsOf([GridLength.Star(1.0)])
        .rowSpacing(24.0)

    border(root.toElement())
        .padding(Thickness(36.0, 40.0, 36.0, 36.0))
        .toElement()
}

public func gallery_shell(cx: RenderCx): Element {
    let (nav, setNav) = cx.useState<NavState>(NavState("home", Array<String>()))
    let (isPaneOpen, setPaneOpen) = cx.useState<Bool>(true)
    let (searchText, setSearchText) = cx.useState<String>("")

    let selectedTag = nav.tag
    let history = nav.history
    let isDark = match (cx.useColorScheme()) {
        case Dark => true
        case Light => false
    }

    // Category tags (for branching the content area).
    let categoryTags = ArrayList<String>()
    for (c in CATEGORIES) {
        categoryTags.add(category_tag(c))
    }

    // Search suggestions from the live query.
    let suggestions = ArrayList<String>()
    if (!searchText.isEmpty()) {
        for (c in search(searchText)) {
            suggestions.add(c.title)
        }
    }

    // Build the NavigationView item tree: Home, then each category with its
    // controls as child items.
    let navItems = ArrayList<NavViewItem>()
    navItems.add(NavViewItem("Home").tagOf("home").iconOf(SymbolGlyph.Home))
    for (cat in CATEGORIES) {
        let item = NavViewItem(cat).tagOf(category_tag(cat)).iconOf(categoryIcon(cat))
        for (c in controls_in_category(cat)) {
            item.child(NavViewItem(c.title).tagOf(c.tag))
        }
        navItems.add(item)
    }

    // Content branch by selected tag.
    let content: Element = if (selectedTag == "home") {
        home_page({ key: String =>
            setNav.call(NavState(key, pushHistory(history, selectedTag)))
        })
    } else if (equalIgnoreCase(selectedTag, "settings")) {
        settings_page()
    } else if (containsList(categoryTags, selectedTag)) {
        var matched = ""
        for (c in CATEGORIES) {
            if (category_tag(c) == selectedTag) {
                matched = c
            }
        }
        renderCategoryPage(matched, { key: String =>
            setNav.call(NavState(key, pushHistory(history, selectedTag)))
        })
    } else {
        route(selectedTag)
    }

    // Search box in the title bar.
    let searchBox = auto_suggest_box(searchText)
        .placeholderOf("Search controls and samples...")
        .itemsOf(suggestions)
        .onTextChanged({ text: String => setSearchText.call(text) })
        .onQuerySubmitted({ query: String =>
            match (findControlByTitle(query)) {
                case Some(info) => setNav.call(NavState(info.tag, pushHistory(history, selectedTag)))
                case None => ()
            }
        })
        .onSuggestionChosen({ chosen: String =>
            match (findControlByTitle(chosen)) {
                case Some(info) => setNav.call(NavState(info.tag, pushHistory(history, selectedTag)))
                case None => ()
            }
        })
        .width(320.0)

    // Theme toggle glyph: sun in dark mode, moon in light mode.
    let glyph = if (isDark) { "\u{E706}" } else { "\u{E708}" }
    let themeButton = button(glyph)
        .onClick({ =>
            if (isDark) {
                setRequestedTheme(RequestedTheme.Light)
            } else {
                setRequestedTheme(RequestedTheme.Dark)
            }
        })
        .fontFamily("Segoe MDL2 Assets")
        .fontSize(14.0)
        .width(40.0)
        .height(36.0)
        .padding(Thickness.uniform(0.0))

    let titleBar = title_bar("Reactor WinUI Gallery")
        .paneToggleButtonVisible(true)
        .backButtonVisible(true)
        .backButtonEnabled(history.size > 0)
        .onBackRequested({ =>
            if (history.size > 0) {
                let h = ArrayList<String>()
                for (x in history) { h.add(x) }
                let prev = h.remove(at: h.size - 1)
                setNav.call(NavState(prev, h.toArray()))
            }
        })
        .onPaneToggleRequested({ => setPaneOpen.call(!isPaneOpen) })
        .content(searchBox.toElement())
        .footer(themeButton.toElement())
        .tall(true)
        .gridRow(0)

    let navView = navigation_view(navItems, content)
        .selectedTagOf(selectedTag)
        .onSelectionChanged({ newTag: String =>
            let effective = if (newTag.isEmpty() || equalIgnoreCase(newTag, "settings")) {
                "settings"
            } else {
                newTag
            }
            if (effective != selectedTag) {
                setNav.call(NavState(effective, pushHistory(history, selectedTag)))
            }
        })
        .paneDisplayModeOf(NavViewPaneDisplayMode.Left)
        .paneOpen(isPaneOpen)
        .paneToggleButtonVisible(false)
        .backButtonVisible(false)
        .fontFamily("Segoe UI Variable")
        .gridRow(1)

    grid([titleBar.toElement(), navView.toElement()])
        .rowsOf([GridLength.Auto, GridLength.Star(1.0)])
        .columnsOf([GridLength.Star(1.0)])
        .toElement()
}

// ── Local helpers ────────────────────────────────────────────────────────────

func equalIgnoreCase(left: String, right: String): Bool {
    asciiLowerS(left) == asciiLowerS(right)
}

func asciiLowerS(value: String): String {
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

func containsList(list: ArrayList<String>, value: String): Bool {
    for (a in list) {
        if (a == value) { return true }
    }
    false
}
