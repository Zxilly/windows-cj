package windows_reactor_gallery

import windows_reactor.core.*
import windows_reactor_gallery.shared.*
import windows_reactor_gallery.pages.basic_input.*
import windows_reactor_gallery.pages.collections.*
import windows_reactor_gallery.pages.date_time.*
import windows_reactor_gallery.pages.design.*
import windows_reactor_gallery.pages.dialogs.*
import windows_reactor_gallery.pages.layout.*
import windows_reactor_gallery.pages.media.*
import windows_reactor_gallery.pages.menus.*
import windows_reactor_gallery.pages.navigation.*
import windows_reactor_gallery.pages.status.*
import windows_reactor_gallery.pages.text.*

// ============================================================================
// Tag -> page routing. The shell hands a selected control tag here; route()
// asks each category router in turn (route<Category>(tag): ?Element) and the
// first Some wins. Each category file (page_<category>.cj) owns the page
// components for its controls; an unmatched tag falls through to the
// placeholder page so navigation, history, and search keep working before a
// category is filled in.
// ============================================================================

public func route(tag: String): Element {
    match (routeBasicInput(tag)) { case Some(e) => return e; case None => () }
    match (routeCollections(tag)) { case Some(e) => return e; case None => () }
    match (routeDateTime(tag)) { case Some(e) => return e; case None => () }
    match (routeDesign(tag)) { case Some(e) => return e; case None => () }
    match (routeDialogs(tag)) { case Some(e) => return e; case None => () }
    match (routeLayout(tag)) { case Some(e) => return e; case None => () }
    match (routeMedia(tag)) { case Some(e) => return e; case None => () }
    match (routeMenus(tag)) { case Some(e) => return e; case None => () }
    match (routeNavigation(tag)) { case Some(e) => return e; case None => () }
    match (routeStatus(tag)) { case Some(e) => return e; case None => () }
    match (routeText(tag)) { case Some(e) => return e; case None => () }
    placeholderPage(tag)
}

// Fallback page for a tag no category claims: control title + "coming soon".
func placeholderPage(tag: String): Element {
    let title = match (findControlByTitleByTag(tag)) {
        case Some(c) => c.title
        case None => tag
    }
    let body = vstack([
        text_block(title).fontSize(28.0).bold().toElement(),
        text_block("Sample page coming soon.").opacity(0.6).toElement(),
        text_block("Tag: ${tag}").fontSize(13.0).opacity(0.5).toElement()
    ])
        .spacing(8.0)
        .margin(Thickness(36.0, 40.0, 36.0, 36.0))
        .hAlign(HorizontalAlignment.Stretch)

    scroll_view(body.toElement()).toElement()
}

// Lookup the control whose tag matches (registry stores tags, not titles).
func findControlByTitleByTag(tag: String): ?ControlInfo {
    for (c in ALL_CONTROLS()) {
        if (c.tag == tag) {
            return Some(c)
        }
    }
    None
}
