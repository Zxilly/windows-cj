package windows_reactor_gallery.pages.navigation

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Per-page component token (stable identity across re-renders) ─────────────
let titleBarPageToken = newComponentTypeToken()

// ── TitleBar ─────────────────────────────────────────────────────────────────

func titleBarPage(cx: RenderCx): Element {
    let _ = cx
    page_content(
        "TitleBar",
        "A customizable application title bar.",
        [
            sample_card(
                "Basic TitleBar",
                text_block(
                    "TitleBar is automatically configured via the application shell.\nSee the gallery shell for a live example."
                ).toElement(),
                "title_bar(\"My App\")"
            )
        ]
    )
}
