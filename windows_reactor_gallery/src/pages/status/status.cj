package windows_reactor_gallery.pages.status

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Status and Info category pages.
//
// routeStatus maps each Status and Info tag to its page component. Each page
// fn is `func <name>_page(): Element` returning a
// pageComponent(token, { cx => ... }) so it owns an independent hook scope;
// mint one module-scope token per page via newComponentTypeToken().
//
//   tag            page fn         file
//   ------------   --------------- -----------------
//   info-badge     info_badge_page info_badge.cj
//   info-bar       info_bar_page   info_bar.cj
//   progress-bar   progress_bar_page progress_bar.cj
//   progress-ring  progress_ring_page progress_ring.cj
//   tool-tip       tool_tip_page   tool_tip.cj
// ============================================================================

// Format a non-negative progress value (0..100) to a whole-number string,
// matching the reference's `{value:.0}` display rounding. Shared by
// progress_bar_page and progress_ring_page.
func percent0(value: Float64): String {
    "${Int64(value + 0.5)}"
}

// ── Dispatch ─────────────────────────────────────────────────────────────────

public func routeStatus(tag: String): ?Element {
    match (tag) {
        case "info-badge" => Some(info_badge_page())
        case "info-bar" => Some(info_bar_page())
        case "progress-bar" => Some(progress_bar_page())
        case "progress-ring" => Some(progress_ring_page())
        case "tool-tip" => Some(tool_tip_page())
        case _ => None
    }
}
