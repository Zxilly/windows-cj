package windows_reactor_gallery.pages.menus

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── MenuBar ──────────────────────────────────────────────────────────────────
// A horizontal bar hosting drop-down menus. The card tracks the last clicked
// menu item label.
func menu_bar_page(cx: RenderCx): Element {
    let (status, setStatus) = cx.useState<String>("Last clicked: (none)")

    let fileItem = MenuBarItemDef("File")
    fileItem.items = ArrayList<MenuItemDef>([
        MenuItemDef.Item("New"),
        MenuItemDef.Item("Open"),
        MenuItemDef.Item("Save")
    ])

    let editItem = MenuBarItemDef("Edit")
    editItem.items = ArrayList<MenuItemDef>([
        MenuItemDef.Item("Undo"),
        MenuItemDef.Item("Cut"),
        MenuItemDef.Item("Copy"),
        MenuItemDef.Item("Paste")
    ])

    let bar = menu_bar(ArrayList<MenuBarItemDef>([fileItem, editItem]))
        .onItemClick({ label: String => setStatus.call("Last clicked: ${label}") })

    let sample = vstack([
        bar.toElement(),
        text_block(status).opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    page_content(
        "MenuBar",
        "A horizontal bar hosting drop-down menus.",
        [
            sample_card(
                "Basic MenuBar",
                sample,
                #"menu_bar(items).onItemClick({ label => setStatus.call("Last clicked: ${label}") })"#
            )
        ]
    )
}

let menuBarPageToken = newComponentTypeToken()
