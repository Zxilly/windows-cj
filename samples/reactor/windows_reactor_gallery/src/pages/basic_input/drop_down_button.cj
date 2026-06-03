package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// DropDownButton
// ============================================================================
let dropDownButtonPageToken = newComponentTypeToken()

func dropDownButtonPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<String>("(none)")

    let menuItems = ArrayList<MenuItemDef>()
    menuItems.add(MenuItemDef.Item("Open"))
    menuItems.add(MenuItemDef.Item("Save"))
    menuItems.add(MenuItemDef.Separator)
    menuItems.add(MenuItemDef.Item("Exit"))

    page_content(
        "DropDownButton",
        "A button that displays a flyout of choices when clicked.",
        [
            sample_card(
                "DropDownButton with Menu",
                vstack([
                    drop_down_button("File Actions")
                        .menuFlyout(menuItems)
                        .onFlyoutItemClick({ s: String => setSelected.call(s) })
                        .toElement(),
                    text_block("Last action: ${selected}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "drop_down_button(\"File\").menuFlyout(items).onFlyoutItemClick(handler)"
            ),
            sample_card(
                "Disabled DropDownButton",
                drop_down_button("Disabled").enabled(false).toElement(),
                "drop_down_button(\"Disabled\").enabled(false)"
            )
        ]
    )
}
