package windows_reactor_minimal

import std.collection.*
import windows_reactor.core.*

// ============================================================================
// Group: nav_menus
//
// Examples owned by this group (filled into routeNavMenus):
//   breadcrumb_bar, navigation_view, navigation_view_icons, pivot, tab_view,
//   selector_bar, command_bar, command_bar_flyout, menu_bar, menu_flyout,
//   title_bar
//
// Contract (see main.cj):
//   routeNavMenus(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesNavMenus()     -> the example names this group owns, for the banner.
// ============================================================================

// ── Local helpers ─────────────────────────────────────────────────────────

// Build an ArrayList<String> from a fixed array of labels (BreadcrumbBar feed).
func navStrList(items: Array<String>): ArrayList<String> {
    let out = ArrayList<String>()
    for (s in items) { out.add(s) }
    out
}

// ── breadcrumb_bar ──────────────────────────────────────────────────────────
// Two breadcrumb trails of different lengths stacked vertically.
func breadcrumbBarExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        text_block("Multi-segment trail").toElement(),
        breadcrumb_bar(navStrList(["Home", "Documents", "Projects", "windows-reactor"])).toElement(),
        text_block("Two-segment trail").toElement(),
        breadcrumb_bar(navStrList(["Home", "Settings"])).toElement()
    ]).spacing(8.0).toElement()
}

// ── navigation_view ───────────────────────────────────────────────────────────
// Left-pane NavigationView whose selected tag drives the body content.
func navigationViewExample(cx: RenderCx): Element {
    let (page, setPage) = cx.useState<String>("home")

    let menuItems = ArrayList<NavViewItem>()
    menuItems.add(NavViewItem("Home").tagOf("home"))
    menuItems.add(NavViewItem("Settings").tagOf("settings"))
    menuItems.add(NavViewItem("About").tagOf("about"))

    let body: Element = if (page == "settings") {
        text_block("Settings page").toElement()
    } else if (page == "about") {
        text_block("About page").toElement()
    } else {
        text_block("Home page").toElement()
    }

    navigation_view(menuItems, body)
        .selectedTagOf(page)
        .onSelectionChanged({ tag: String => setPage.call(tag) })
        .paneDisplayModeOf(NavViewPaneDisplayMode.Left)
        .paneTitle("Demo")
        .header("page: ${page}")
        .settingsVisible(false)
        .toElement()
}

// ── navigation_view_icons ─────────────────────────────────────────────────────
// NavigationView whose menu items carry symbol icons.
func navigationViewIconsExample(cx: RenderCx): Element {
    let (page, setPage) = cx.useState<String>("home")

    let content: Element = if (page == "home") {
        text_block("Welcome home!").toElement()
    } else if (page == "settings") {
        text_block("Settings page").toElement()
    } else if (page == "mail") {
        text_block("Mail inbox").toElement()
    } else if (page == "people") {
        text_block("Contacts").toElement()
    } else {
        text_block("Unknown page").toElement()
    }

    let items = ArrayList<NavViewItem>()
    items.add(NavViewItem("Home").tagOf("home").iconOf(SymbolGlyph.Home))
    items.add(NavViewItem("Mail").tagOf("mail").iconOf(SymbolGlyph.Mail))
    items.add(NavViewItem("People").tagOf("people").iconOf(SymbolGlyph.People))
    items.add(NavViewItem("Settings").tagOf("settings").iconOf(SymbolGlyph.Setting))

    navigation_view(items, content)
        .selectedTagOf(page)
        .onSelectionChanged({ tag: String => setPage.call(tag) })
        .toElement()
}

// ── pivot ─────────────────────────────────────────────────────────────────────
// Three-tab Pivot with selection tracking shown beneath it.
func pivotExample(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int32>(0)

    let items = ArrayList<PivotItem>()
    items.add(PivotItem("First", text_block("Pivot — first tab").padding(Thickness.uniform(12.0)).toElement()))
    items.add(PivotItem("Second", text_block("Pivot — second tab").padding(Thickness.uniform(12.0)).toElement()))
    items.add(PivotItem("Third", text_block("Pivot — third tab").padding(Thickness.uniform(12.0)).toElement()))

    vstack([
        pivot(items)
            .title("Demo")
            .selectedIndex(selected)
            .onSelectionChanged({ i: Int32 => setSelected.call(i) })
            .toElement(),
        text_block("selected_index = ${selected}").toElement()
    ]).spacing(8.0).toElement()
}

// ── tab_view ──────────────────────────────────────────────────────────────────
// Closable, reorderable tabs. The "overview" tab is fixed; closing a tab
// removes it and clamps the selection. The set of remaining tab keys is stored
// as a comma-separated String so the useState payload stays Equatable.
struct TabSpec {
    public TabSpec(let key: String, let header: String) {}
}

func tabSpecs(): Array<TabSpec> {
    [TabSpec("overview", "Overview"), TabSpec("badges", "Badges"), TabSpec("notice", "Notice")]
}

// Split a comma-separated key list into its (non-empty) parts.
func splitKeys(csv: String): Array<String> {
    csv.split(",", removeEmpty: true)
}

func joinKeys(keys: ArrayList<String>): String {
    var s = ""
    var first = true
    for (k in keys) {
        if (first) { s = k; first = false } else { s = s + "," + k }
    }
    s
}

func headerFor(key: String): String {
    for (spec in tabSpecs()) {
        if (spec.key == key) { return spec.header }
    }
    key
}

func tabViewExample(cx: RenderCx): Element {
    // Comma-separated list of the keys still open.
    let (openCsv, setOpenCsv) = cx.useState<String>("overview,badges,notice")
    let (selected, setSelected) = cx.useState<Int32>(0)

    let openKeys = splitKeys(openCsv)

    let items = ArrayList<TabItem>()
    for (key in openKeys) {
        let header = headerFor(key)
        let item = TabItem(header, text_block("Tab content — ${header}").padding(Thickness.uniform(12.0)).toElement())
        item.key = Some(key)
        item.isClosable = Some(key != "overview")
        items.add(item)
    }

    let remaining = openKeys.size

    vstack([
        tab_view(items)
            .selectedIndex(selected)
            .canReorder(true)
            .onSelectionChanged({ i: Int32 => setSelected.call(i) })
            .onTabCloseRequested({ key: String =>
                let next = ArrayList<String>()
                for (k in splitKeys(openCsv)) {
                    if (k != key) { next.add(k) }
                }
                let maxIndex = if (next.size > 0) { Int32(next.size) - 1 } else { 0i32 }
                var clamped = selected
                if (clamped > maxIndex) { clamped = maxIndex }
                if (clamped < 0) { clamped = 0 }
                setOpenCsv.call(joinKeys(next))
                if (clamped != selected) { setSelected.call(clamped) }
            })
            .toElement(),
        text_block("selected_index = ${selected}, tabs remaining = ${remaining}").toElement()
    ]).spacing(8.0).toElement()
}

// ── selector_bar ──────────────────────────────────────────────────────────────
// A SelectorBar with three options; the selected text is echoed beneath.
func selectorBarExample(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<String>("Recent")

    let recent = SelectorBarItemDef("Recent")
    let shared = SelectorBarItemDef("Shared")
    shared.icon = Some(SymbolGlyph.People)
    let favorites = SelectorBarItemDef("Favorites")
    favorites.icon = Some(SymbolGlyph.Favorite)

    vstack([
        selector_bar(ArrayList<SelectorBarItemDef>([recent, shared, favorites]))
            .onSelectionChanged({ text: String => setSelected.call(text) })
            .toElement(),
        text_block("Selected: ${selected}").toElement()
    ]).spacing(12.0).toElement()
}

// ── command_bar ───────────────────────────────────────────────────────────────
// A CommandBar with primary icon commands plus secondary overflow commands.
func commandBarExample(cx: RenderCx): Element {
    let (lastClick, setLastClick) = cx.useState<String>("(none)")

    let primary = ArrayList<CommandBarCommandDef>([
        CommandBarCommandDef.Button("Add", Some(SymbolGlyph.Add)),
        CommandBarCommandDef.Button("Edit", Some(SymbolGlyph.Edit)),
        CommandBarCommandDef.Separator,
        CommandBarCommandDef.Button("Save", Some(SymbolGlyph.Save)),
        CommandBarCommandDef.Button("Delete", Some(SymbolGlyph.Delete))
    ])
    let secondary = ArrayList<CommandBarCommandDef>([
        CommandBarCommandDef.Button("Select All", None),
        CommandBarCommandDef.Button("Share", None)
    ])

    vstack([
        command_bar(primary)
            .secondaryCommands(secondary)
            .onClick({ label: String => setLastClick.call(label) })
            .toElement(),
        text_block("Last clicked: ${lastClick}").toElement()
    ]).spacing(12.0).toElement()
}

// ── command_bar_flyout ──────────────────────────────────────────────────────
// The reference attaches a CommandBarFlyout to a plain Button. The Cangjie
// Button widget exposes no flyout builder, and there is no CommandBarFlyout
// projection. Behaviour is approximated with a CommandBar carrying the same
// primary (Cut/Copy/Paste) and secondary (Select All/Print) commands and the
// same click callback — the user sees the identical command set and gets the
// label of each invoked command.
func commandBarFlyoutExample(cx: RenderCx): Element {
    let (lastAction, setAction) = cx.useState<String>("(none)")

    let primary = ArrayList<CommandBarCommandDef>([
        CommandBarCommandDef.Button("Cut", Some(SymbolGlyph.Cut)),
        CommandBarCommandDef.Button("Copy", Some(SymbolGlyph.Copy)),
        CommandBarCommandDef.Button("Paste", Some(SymbolGlyph.Paste))
    ])
    let secondary = ArrayList<CommandBarCommandDef>([
        CommandBarCommandDef.Button("Select All", None),
        CommandBarCommandDef.Button("Print", None)
    ])

    vstack([
        command_bar(primary)
            .secondaryCommands(secondary)
            .onClick({ label: String => setAction.call(label) })
            .toElement(),
        text_block("Last action: ${lastAction}").toElement()
    ]).spacing(8.0).toElement()
}

// ── menu_bar ──────────────────────────────────────────────────────────────────
// A MenuBar (File/Edit/Help) with nested sub-menus and separators, plus a
// DropDownButton menu flyout. Both share one click callback.
func menuBarExample(cx: RenderCx): Element {
    let (lastClick, setLastClick) = cx.useState<String>("(none)")

    let fileItem = MenuBarItemDef("File")
    let recent = ArrayList<MenuItemDef>([MenuItemDef.Item("doc1.txt"), MenuItemDef.Item("doc2.txt")])
    fileItem.items = ArrayList<MenuItemDef>([
        MenuItemDef.Item("New"),
        MenuItemDef.Item("Open"),
        MenuItemDef.Separator,
        MenuItemDef.SubItem("Recent", recent),
        MenuItemDef.Separator,
        MenuItemDef.Item("Exit")
    ])

    let editItem = MenuBarItemDef("Edit")
    editItem.items = ArrayList<MenuItemDef>([
        MenuItemDef.Item("Cut"),
        MenuItemDef.Item("Copy"),
        MenuItemDef.Item("Paste")
    ])

    let helpItem = MenuBarItemDef("Help")
    helpItem.items = ArrayList<MenuItemDef>([MenuItemDef.Item("About")])

    let more = ArrayList<MenuItemDef>([MenuItemDef.Item("Action C"), MenuItemDef.Item("Action D")])
    let flyout = ArrayList<MenuItemDef>([
        MenuItemDef.Item("Action A"),
        MenuItemDef.Item("Action B"),
        MenuItemDef.Separator,
        MenuItemDef.SubItem("More", more)
    ])

    vstack([
        menu_bar(ArrayList<MenuBarItemDef>([fileItem, editItem, helpItem]))
            .onItemClick({ text: String => setLastClick.call(text) })
            .toElement(),
        drop_down_button("Actions")
            .menuFlyout(flyout)
            .onFlyoutItemClick({ text: String => setLastClick.call(text) })
            .toElement(),
        text_block("Last clicked: ${lastClick}").toElement()
    ]).spacing(12.0).toElement()
}

// ── menu_flyout ───────────────────────────────────────────────────────────────
// The reference attaches a MenuFlyout to a plain Button. The Cangjie Button
// widget has no menu-flyout builder; DropDownButton is the projected control
// that hosts a MenuFlyout (same item tree, separators, sub-items, and the same
// per-item click callback), so the menu flyout is presented on a
// DropDownButton instead.
func menuFlyoutExample(cx: RenderCx): Element {
    let (lastAction, setAction) = cx.useState<String>("(none)")

    let fontSize = ArrayList<MenuItemDef>([
        MenuItemDef.Item("Small"),
        MenuItemDef.Item("Medium"),
        MenuItemDef.Item("Large")
    ])
    let flyout = ArrayList<MenuItemDef>([
        MenuItemDef.Item("Cut"),
        MenuItemDef.Item("Copy"),
        MenuItemDef.Item("Paste"),
        MenuItemDef.Separator,
        MenuItemDef.SubItem("Font Size", fontSize)
    ])

    vstack([
        drop_down_button("Open Menu")
            .menuFlyout(flyout)
            .onFlyoutItemClick({ text: String => setAction.call(text) })
            .toElement(),
        text_block("Last action: ${lastAction}").toElement()
    ]).spacing(8.0).toElement()
}

// ── title_bar ─────────────────────────────────────────────────────────────────
// A TitleBar with back and pane-toggle buttons; each press bumps a counter.
func titleBarExample(cx: RenderCx): Element {
    let (backClicks, setBack) = cx.useState<Int32>(0)
    let (paneClicks, setPane) = cx.useState<Int32>(0)

    vstack([
        title_bar("windows_reactor — title_bar sample")
            .subtitleOf("Minimal demo")
            .backButtonVisible(true)
            .backButtonEnabled(true)
            .paneToggleButtonVisible(true)
            .onBackRequested({ => setBack.call(backClicks + 1) })
            .onPaneToggleRequested({ => setPane.call(paneClicks + 1) })
            .toElement(),
        text_block("back_clicks = ${backClicks}, pane_toggle_clicks = ${paneClicks}").toElement()
    ]).spacing(8.0).toElement()
}

// ── Dispatch ──────────────────────────────────────────────────────────────────

func routeNavMenus(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "breadcrumb_bar" => Some(("Sample", breadcrumbBarExample))
        case "navigation_view" => Some(("Sample", navigationViewExample))
        case "navigation_view_icons" => Some(("NavigationView Icons Sample", navigationViewIconsExample))
        case "pivot" => Some(("Sample", pivotExample))
        case "tab_view" => Some(("Sample", tabViewExample))
        case "selector_bar" => Some(("SelectorBar Sample", selectorBarExample))
        case "command_bar" => Some(("CommandBar Sample", commandBarExample))
        case "command_bar_flyout" => Some(("Sample", commandBarFlyoutExample))
        case "menu_bar" => Some(("MenuBar Sample", menuBarExample))
        case "menu_flyout" => Some(("Sample", menuFlyoutExample))
        case "title_bar" => Some(("Sample", titleBarExample))
        case _ => None
    }
}

func namesNavMenus(): Array<String> {
    ["breadcrumb_bar", "navigation_view", "navigation_view_icons", "pivot", "tab_view",
     "selector_bar", "command_bar", "command_bar_flyout", "menu_bar", "menu_flyout", "title_bar"]
}
