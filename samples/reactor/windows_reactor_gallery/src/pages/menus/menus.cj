package windows_reactor_gallery.pages.menus

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Menus and Toolbars category pages.
//
// routeMenus maps each Menus and Toolbars tag to its page component. Each
// page fn is `func <name>_page(cx: RenderCx): Element` driving its sample
// state through cx.useState; routeMenus wraps it in pageComponent(token, ..)
// so it owns an independent hook scope. One stable module-scope token is
// minted per page via newComponentTypeToken() (in each control's own file).
//
//   tag            page fn               file
//   ------------   ------------------    ----------------
//   command-bar    command_bar_page      command_bar.cj
//   menu-bar       menu_bar_page         menu_bar.cj
//   selector-bar   selector_bar_page     selector_bar.cj
// ============================================================================

public func routeMenus(tag: String): ?Element {
    match (tag) {
        case "command-bar" => Some(pageComponent(commandBarPageToken, command_bar_page))
        case "menu-bar" => Some(pageComponent(menuBarPageToken, menu_bar_page))
        case "selector-bar" => Some(pageComponent(selectorBarPageToken, selector_bar_page))
        case _ => None
    }
}
