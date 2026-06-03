package windows_reactor_gallery.pages.layout

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Layout category pages.
//
// routeLayout maps each Layout control tag to its page component. Each page
// fn is `func <name>Page(cx: RenderCx): Element` returning a page_content(...)
// of sample_card(...) demos; routeLayout wraps each in pageComponent(token, fn)
// so it owns an independent hook scope. One module-scope token per page is
// minted via newComponentTypeToken().
//
// Each control's page fn + its page token (and any control-local helper such as
// canvas.cj's withCanvasPos, relative_panel.cj's withRelativeAlign, or grid.cj's
// gridCell) lives in its own <control>.cj file in this package.
//
//   tag              page fn             file
//   --------------   -----------------   -------------------
//   border           borderPage         border.cj
//   canvas           canvasPage         canvas.cj
//   expander         expanderPage       expander.cj
//   grid             gridPage           grid.cj
//   relative-panel   relativePanelPage  relative_panel.cj
//   scroll-view      scrollViewPage     scroll_view.cj
//   split-view       splitViewPage      split_view.cj
//   stack-panel      stackPanelPage     stack_panel.cj
//   viewbox          viewboxPage        viewbox.cj
// ============================================================================

// ── Dispatch ─────────────────────────────────────────────────────────────────

public func routeLayout(tag: String): ?Element {
    match (tag) {
        case "border" => Some(pageComponent(borderPageToken, borderPage))
        case "canvas" => Some(pageComponent(canvasPageToken, canvasPage))
        case "expander" => Some(pageComponent(expanderPageToken, expanderPage))
        case "grid" => Some(pageComponent(gridPageToken, gridPage))
        case "relative-panel" => Some(pageComponent(relativePanelPageToken, relativePanelPage))
        case "scroll-view" => Some(pageComponent(scrollViewPageToken, scrollViewPage))
        case "split-view" => Some(pageComponent(splitViewPageToken, splitViewPage))
        case "stack-panel" => Some(pageComponent(stackPanelPageToken, stackPanelPage))
        case "viewbox" => Some(pageComponent(viewboxPageToken, viewboxPage))
        case _ => None
    }
}
