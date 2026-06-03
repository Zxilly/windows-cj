package windows_reactor_gallery.pages.navigation

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Per-page component token (stable identity across re-renders) ─────────────
let pivotPageToken = newComponentTypeToken()

// ── Pivot ────────────────────────────────────────────────────────────────────

func pivotPage(cx: RenderCx): Element {
    let (tabIdx, setTab) = cx.useState<Int32>(0)

    let basicItems = ArrayList<PivotItem>()
    basicItems.add(PivotItem("Tab 1", text_block("Content of tab 1").toElement()))
    basicItems.add(PivotItem("Tab 2", text_block("Content of tab 2").toElement()))
    basicItems.add(PivotItem("Tab 3", text_block("Content of tab 3").toElement()))

    let trackItems = ArrayList<PivotItem>()
    trackItems.add(PivotItem("Overview", text_block("Overview content").toElement()))
    trackItems.add(PivotItem("Details", text_block("Detail content").toElement()))
    trackItems.add(PivotItem("History", text_block("History content").toElement()))

    page_content(
        "Pivot",
        "A tabbed interface for switching between content sections.",
        [
            sample_card(
                "Basic Pivot",
                pivot(basicItems).toElement(),
                "pivot([PivotItem(\"Tab\", content), ...])"
            ),
            sample_card(
                "Pivot with Selection Tracking",
                vstack([
                    pivot(trackItems)
                        .selectedIndex(tabIdx)
                        .onSelectionChanged({ i: Int32 => setTab.call(i) })
                        .toElement(),
                    text_block("Active tab index: ${tabIdx}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "pivot(items).selectedIndex(idx).onSelectionChanged(handler)"
            )
        ]
    )
}
