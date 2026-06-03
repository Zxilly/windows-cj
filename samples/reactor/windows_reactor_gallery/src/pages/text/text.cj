package windows_reactor_gallery.pages.text

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Text category pages.
//
// routeText maps each Text control tag to its page component. Each page fn is
// `func ctrlPage(cx: RenderCx): Element` wrapped via pageComponent(token, body)
// so it owns an independent hook scope; one module-scope token is minted per
// page via newComponentTypeToken(). Each control lives in its own file
// (mirroring the reference pages/text/<control>.rs layout):
//
//   tag                page fn                 file
//   ----------------   ---------------------   --------------------
//   auto-suggest-box   autoSuggestBoxPage      auto_suggest_box.cj
//   rich-edit-box      richEditBoxPage         rich_edit_box.cj
//   rich-text-block    richTextBlockPage       rich_text_block.cj
//   type-ramp          typeRampPage            type_ramp.cj
//
// asciiLower (case-insensitive fold) is shared from registry.cj in this package.
// ============================================================================

public func routeText(tag: String): ?Element {
    match (tag) {
        case "auto-suggest-box" => Some(pageComponent(autoSuggestBoxPageToken, autoSuggestBoxPage))
        case "rich-edit-box" => Some(pageComponent(richEditBoxPageToken, richEditBoxPage))
        case "rich-text-block" => Some(pageComponent(richTextBlockPageToken, richTextBlockPage))
        case "type-ramp" => Some(pageComponent(typeRampPageToken, typeRampPage))
        case _ => None
    }
}
