package windows_reactor_gallery.pages.navigation

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Per-page component token (stable identity across re-renders) ─────────────
let navigationViewPageToken = newComponentTypeToken()

// ── NavigationView ───────────────────────────────────────────────────────────

func navigationViewPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<String>("page1")
    let (topSelected, setTopSelected) = cx.useState<String>("home")

    let items = ArrayList<NavViewItem>()
    items.add(NavViewItem("Home").tagOf("page1").iconOf(SymbolGlyph.Home))
    items.add(NavViewItem("Browse").tagOf("page2").iconOf(SymbolGlyph.Find))
    items.add(NavViewItem("Settings").tagOf("page3").iconOf(SymbolGlyph.Setting))

    let body: Element = if (selected == "page2") {
        text_block("Browse page content").toElement()
    } else if (selected == "page3") {
        text_block("Settings page content").toElement()
    } else {
        text_block("Home page content").toElement()
    }

    let topItems = ArrayList<NavViewItem>()
    topItems.add(NavViewItem("Home").tagOf("home").iconOf(SymbolGlyph.Home))
    topItems.add(NavViewItem("Documents").tagOf("docs").iconOf(SymbolGlyph.Edit))
    topItems.add(NavViewItem("Downloads").tagOf("downloads").iconOf(SymbolGlyph.Download))

    let topBody: Element = if (topSelected == "docs") {
        text_block("Documents area").toElement()
    } else if (topSelected == "downloads") {
        text_block("Downloads area").toElement()
    } else {
        text_block("Home area").toElement()
    }

    page_content(
        "NavigationView",
        "A side or top navigation pane for app-level navigation.",
        [
            sample_card(
                "Left-Pane NavigationView",
                navigation_view(items, body)
                    .selectedTagOf(selected)
                    .onSelectionChanged({ tag: String =>
                        if (!tag.isEmpty() && tag != selected) {
                            setSelected.call(tag)
                        }
                    })
                    .paneTitle("Nav Demo")
                    .settingsVisible(false)
                    .height(300.0)
                    .toElement(),
                "navigation_view(items, body)\n    .selectedTagOf(tag)\n    .onSelectionChanged(handler)\n    .paneTitle(\"Nav Demo\")"
            ),
            sample_card(
                "Top-Mode NavigationView",
                navigation_view(topItems, topBody)
                    .paneDisplayModeOf(NavViewPaneDisplayMode.Top)
                    .selectedTagOf(topSelected)
                    .onSelectionChanged({ tag: String =>
                        if (!tag.isEmpty() && tag != topSelected) {
                            setTopSelected.call(tag)
                        }
                    })
                    .settingsVisible(false)
                    .height(200.0)
                    .toElement(),
                "navigation_view(items, body)\n    .paneDisplayModeOf(NavViewPaneDisplayMode.Top)"
            )
        ]
    )
}
