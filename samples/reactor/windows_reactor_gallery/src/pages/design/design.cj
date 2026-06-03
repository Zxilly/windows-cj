package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Design Guidance category pages.
//
// routeDesign maps each Design Guidance tag to its page component. Each page
// fn is `func <name>_page(): Element` returning a
// pageComponent(token, { cx => ... }) so it owns an independent hook scope;
// one module-scope token per page is minted via newComponentTypeToken().
//
// Each control page now lives in its own file in this same package
// (typography.cj, color.cj, spacing.cj, iconography.cj, geometry.cj,
// theme.cj, materials.cj). This mod file keeps only the route table and the
// cross-control shared helpers below.
//
//   tag          page fn
//   ----------   ---------------
//   typography   typography_page
//   color        color_page
//   spacing      spacing_page
//   iconography  iconography_page
//   geometry     geometry_page
//   theme        theme_page
//   materials    materials_page
// ============================================================================

let accentColor = Color.rgb(0u8, 120u8, 212u8)
let neutralStroke = Color.rgb(128u8, 128u8, 128u8)

public func routeDesign(tag: String): ?Element {
    match (tag) {
        case "typography" => Some(typography_page())
        case "color" => Some(color_page())
        case "spacing" => Some(spacing_page())
        case "iconography" => Some(iconography_page())
        case "geometry" => Some(geometry_page())
        case "theme" => Some(theme_page())
        case "materials" => Some(materials_page())
        case _ => None
    }
}

// ── Small shared helpers ──────────────────────────────────────────────────────

// Pretty-print a Float64 that always holds an integral value (font sizes,
// spacing/radius px) without a trailing ".0", mirroring the reference labels.
// Used by typography, spacing and geometry pages.
func intText(value: Float64): String {
    "${Int64(value)}"
}
