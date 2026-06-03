package windows_reactor_gallery.pages.navigation

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Per-page component token (stable identity across re-renders) ─────────────
let breadcrumbBarPageToken = newComponentTypeToken()

// Build an ArrayList<String> from a fixed array of header labels.
func strList(items: Array<String>): ArrayList<String> {
    let out = ArrayList<String>()
    for (s in items) { out.add(s) }
    out
}

// ── BreadcrumbBar ────────────────────────────────────────────────────────────

func breadcrumbBarPage(cx: RenderCx): Element {
    let (clicked, setClicked) = cx.useState<Int32>(-1)

    page_content(
        "BreadcrumbBar",
        "A trail showing the navigation path.",
        [
            sample_card(
                "Basic BreadcrumbBar",
                breadcrumb_bar(strList(["Home", "Documents", "Report"])).toElement(),
                "breadcrumb_bar([\"Home\", \"Documents\", \"Report\"])"
            ),
            sample_card(
                "Interactive BreadcrumbBar",
                vstack([
                    breadcrumb_bar(strList(["Root", "Users", "Settings", "Profile"]))
                        .onItemClicked({ i: Int32 => setClicked.call(i) })
                        .toElement(),
                    text_block("Clicked index: ${clicked}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "breadcrumb_bar(items).onItemClicked({ idx => handler(idx) })"
            )
        ]
    )
}
