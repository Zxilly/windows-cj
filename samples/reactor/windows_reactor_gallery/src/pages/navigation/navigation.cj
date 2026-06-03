package windows_reactor_gallery.pages.navigation

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Navigation category pages.
//
// routeNavigation maps each Navigation control tag to its page component.
// Each page fn is `func ctrlPage(cx: RenderCx): Element` returning a
// page_content(title, description, [sample_card(...), ...]); routeNavigation
// wraps it via pageComponent(token, body) so each page owns an independent
// hook scope. One module-scope token per page is minted via
// newComponentTypeToken().
//
// Each control now lives in its own file (mirroring the rs layout):
//
//   tag               page fn               file
//   ---------------   --------------------  ----------------------
//   breadcrumb-bar    breadcrumbBarPage     breadcrumb_bar.cj
//   navigation-view   navigationViewPage    navigation_view.cj
//   pivot             pivotPage             pivot.cj
//   tab-view          tabViewPage           tab_view.cj
//   title-bar         titleBarPage          title_bar.cj
// ============================================================================

// ── Dispatch ─────────────────────────────────────────────────────────────────

public func routeNavigation(tag: String): ?Element {
    match (tag) {
        case "breadcrumb-bar" => Some(pageComponent(breadcrumbBarPageToken, breadcrumbBarPage))
        case "navigation-view" => Some(pageComponent(navigationViewPageToken, navigationViewPage))
        case "pivot" => Some(pageComponent(pivotPageToken, pivotPage))
        case "tab-view" => Some(pageComponent(tabViewPageToken, tabViewPage))
        case "title-bar" => Some(pageComponent(titleBarPageToken, titleBarPage))
        case _ => None
    }
}
