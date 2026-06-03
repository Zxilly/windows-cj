package windows_reactor_gallery.pages.media

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Media category pages.
//
// routeMedia maps each Media control tag to its page component. Each page fn
// is `func <name>_page(cx): Element` (wrapped by pageComponent) so it owns an
// independent hook scope; each page mints one module-scope component-type token
// via newComponentTypeToken() and reuses it on every route call.
//
//   tag              page fn          file
//   --------------   ---------------  ------------------
//   image            imagePage        image.cj
//   person-picture   personPicturePage person_picture.cj
// ============================================================================

// ── Dispatch ─────────────────────────────────────────────────────────────────
public func routeMedia(tag: String): ?Element {
    match (tag) {
        case "image" => Some(pageComponent(imagePageToken, imagePage))
        case "person-picture" => Some(pageComponent(personPicturePageToken, personPicturePage))
        case _ => None
    }
}
