package windows_reactor_gallery.pages.collections

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Collections category pages.
//
// routeCollections maps each Collections control tag to its page component.
// Each page fn is `func ctrlPage(cx: RenderCx): Element` returning a
// page_content(title, description, [sample_card(...), ...]); routeCollections
// wraps it via pageComponent(token, body) so each page owns an independent
// hook scope. One module-scope token is minted per page via
// newComponentTypeToken().
//
// Each control lives in its own file in this package:
//   tag          page fn          file
//   ----------   ---------------  -------------
//   flip-view    flipViewPage     flip_view.cj
//   grid-view    gridViewPage     grid_view.cj
//   list-box     listBoxPage      list_box.cj
//   list-view    listViewPage     list_view.cj
//   tree-view    treeViewPage     tree_view.cj
// ============================================================================

public func routeCollections(tag: String): ?Element {
    match (tag) {
        case "flip-view" => Some(pageComponent(flipViewPageToken, flipViewPage))
        case "grid-view" => Some(pageComponent(gridViewPageToken, gridViewPage))
        case "list-box" => Some(pageComponent(listBoxPageToken, listBoxPage))
        case "list-view" => Some(pageComponent(listViewPageToken, listViewPage))
        case "tree-view" => Some(pageComponent(treeViewPageToken, treeViewPage))
        case _ => None
    }
}
