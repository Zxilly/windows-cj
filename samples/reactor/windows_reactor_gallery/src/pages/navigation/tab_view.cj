package windows_reactor_gallery.pages.navigation

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Per-page component token (stable identity across re-renders) ─────────────
let tabViewPageToken = newComponentTypeToken()

// Build a non-closable TabItem (isClosable is a plain field, not a builder).
func fixedTab(header: String, content: Element): TabItem {
    let item = TabItem(header, content)
    item.isClosable = Some(false)
    item
}

// ── TabView ──────────────────────────────────────────────────────────────────

func tabViewPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int32>(0)
    let (tabCount, setTabCount) = cx.useState<Int32>(3)

    // Basic tabs.
    let basicTabs = ArrayList<TabItem>()
    basicTabs.add(TabItem("Home", text_block("Home content").toElement()))
    basicTabs.add(TabItem("Document", text_block("Document content").toElement()))
    basicTabs.add(TabItem("Settings", text_block("Settings content").toElement()))

    // Dynamic tabs: 1..=tabCount.
    let dynamicTabs = ArrayList<TabItem>()
    var i: Int32 = 1
    while (i <= tabCount) {
        dynamicTabs.add(TabItem("Tab ${i}", text_block("Content of Tab ${i}").toElement()))
        i++
    }
    let clampedSelected = if (selected < tabCount - 1) { selected } else { tabCount - 1 }

    // Non-closable tabs.
    let fixedTabs = ArrayList<TabItem>()
    fixedTabs.add(fixedTab("Fixed A", text_block("Always present").toElement()))
    fixedTabs.add(fixedTab("Fixed B", text_block("Cannot close").toElement()))

    page_content(
        "TabView",
        "A control that displays closable, rearrangeable tabs.",
        [
            sample_card(
                "Basic TabView",
                tab_view(basicTabs)
                    .selectedIndex(selected)
                    .onSelectionChanged({ idx: Int32 => setSelected.call(idx) })
                    .height(200.0)
                    .toElement(),
                "tab_view([\n    TabItem(\"Home\", content),\n    TabItem(\"Document\", content),\n]).selectedIndex(idx).onSelectionChanged(handler)"
            ),
            sample_card(
                "Dynamic Tabs",
                vstack([
                    tab_view(dynamicTabs)
                        .selectedIndex(clampedSelected)
                        .onSelectionChanged({ idx: Int32 => setSelected.call(idx) })
                        .height(180.0)
                        .toElement(),
                    hstack([
                        button("Add Tab")
                            .onClick({ => setTabCount.call(tabCount + 1) })
                            .toElement(),
                        button("Remove Tab")
                            .enabled(tabCount > 1)
                            .onClick({ =>
                                let next = tabCount - 1
                                setTabCount.call(if (next > 1) { next } else { 1 })
                            })
                            .toElement()
                    ]).spacing(8.0).toElement()
                ]).spacing(8.0).toElement(),
                "let tabs = (1..=count).map { i => TabItem(\"Tab \${i}\", content) }\ntab_view(tabs)"
            ),
            sample_card(
                "Non-closable Tabs",
                tab_view(fixedTabs)
                    .height(150.0)
                    .toElement(),
                "let item = TabItem(\"Tab\", content); item.isClosable = Some(false)"
            )
        ]
    )
}
