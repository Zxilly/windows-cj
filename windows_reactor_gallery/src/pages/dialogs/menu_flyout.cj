package windows_reactor_gallery.pages.dialogs

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let menuFlyoutPageToken = newComponentTypeToken()

// ── MenuFlyout ───────────────────────────────────────────────────────────────
func menuFlyoutPage(cx: RenderCx): Element {
    let (lastAction, setAction) = cx.useState<String>("(none)")

    let basicItems = ArrayList<MenuItemDef>()
    basicItems.add(MenuItemDef.Item("Cut"))
    basicItems.add(MenuItemDef.Item("Copy"))
    basicItems.add(MenuItemDef.Item("Paste"))

    let basicCard = sample_card(
        "Basic MenuFlyout",
        vstack([
            drop_down_button("Open Menu")
                .menuFlyout(basicItems)
                .onFlyoutItemClick({ s: String => setAction.call(s) })
                .toElement(),
            text_block("Last action: ${lastAction}").opacity(0.6).toElement()
        ]).spacing(8.0).toElement(),
        "drop_down_button(\"Open Menu\").menuFlyout([\n    MenuItemDef.Item(\"Cut\"),\n    MenuItemDef.Item(\"Copy\"),\n    MenuItemDef.Item(\"Paste\"),\n]).onFlyoutItemClick(handler)"
    )

    let formatItems = ArrayList<MenuItemDef>()
    formatItems.add(MenuItemDef.Item("Bold"))
    formatItems.add(MenuItemDef.Item("Italic"))
    formatItems.add(MenuItemDef.Separator)
    formatItems.add(MenuItemDef.Item("Underline"))
    formatItems.add(MenuItemDef.Item("Strikethrough"))

    let separatorsCard = sample_card(
        "MenuFlyout with Separators",
        vstack([
            drop_down_button("Format")
                .menuFlyout(formatItems)
                .onFlyoutItemClick({ s: String => setAction.call(s) })
                .toElement(),
            text_block("Last format: ${lastAction}").opacity(0.6).toElement()
        ]).spacing(8.0).toElement(),
        "drop_down_button(\"Format\").menuFlyout([\n    MenuItemDef.Item(\"Bold\"),\n    MenuItemDef.Separator,\n    MenuItemDef.Item(\"Underline\"),\n])"
    )

    page_content(
        "MenuFlyout",
        "A flyout that displays a list of menu commands attached to a button.",
        [basicCard, separatorsCard]
    )
}
