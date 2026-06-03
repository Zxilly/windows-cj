package windows_reactor_minimal

import std.collection.*
import windows_reactor.core.*

// ============================================================================
// Group: collections
//
// Examples owned by this group (filled into routeCollections):
//   list_box, list_view, grid_view, flip_view, tree_view, combo_box
//
// Contract (see main.cj):
//   routeCollections(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesCollections()     -> the example names this group owns, for the banner.
// ============================================================================

// ── list_box ───────────────────────────────────────────────────────────────
// A single ListBox of fruit. Selection updates a state cell; the label echoes
// the selected index, or "No selection" when nothing is chosen (index < 0).
func listBoxExample(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int64>(-1)

    let items = ArrayList<String>()
    for (s in ["Apple", "Banana", "Cherry", "Date", "Elderberry"]) { items.add(s) }

    let label = if (selected >= 0) {
        "Selected index: ${selected}"
    } else {
        "No selection"
    }

    vstack([
        list_box()
            .items(items)
            .onSelectionChanged({ idx: Int32 => setSelected.call(Int64(idx)) })
            .toElement(),
        text_block(label).toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── list_view ──────────────────────────────────────────────────────────────
// Two templated ListViews: a selection-mode picker (None/Single/Multiple/
// Extended) drives the SelectionMode of the colour list below it. The footer
// echoes the selected index, its label, and the active mode.
func listViewExample(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int64>(-1)
    let (modeIdx, setModeIdx) = cx.useState<Int64>(1) // default = Single

    let items: Array<String> = ["Red", "Green", "Blue", "Yellow", "Magenta"]

    let modes: Array<SelectionMode> = [
        SelectionMode.NoneSel,
        SelectionMode.Single,
        SelectionMode.Multiple,
        SelectionMode.Extended
    ]
    let modeNames: Array<String> = ["None", "Single", "Multiple", "Extended"]
    let modeIdxClamped = if (modeIdx >= 0 && modeIdx < modes.size) { modeIdx } else { 1 }
    let mode = modes[modeIdxClamped]
    let modeName = modeNames[modeIdxClamped]

    let label = if (selected >= 0 && selected < items.size) {
        items[selected]
    } else {
        "(none)"
    }

    let modeItems: Array<String> = ["None", "Single", "Multiple", "Extended"]

    let modeList = listView<String>(modeItems, { s: String, _idx: Int64 =>
        text_block(s).padding(Thickness.xy(12.0, 4.0)).toElement()
    })
        .withKeySelector({ s: String => s })
        .selectedIndex(Int32(modeIdx))
        .onSelectionChanged({ i: Int32 => setModeIdx.call(Int64(i)) })
        .height(120.0)
        .build()

    let itemsList = listView<String>(items, { s: String, _idx: Int64 =>
        text_block(s).padding(Thickness.xy(12.0, 6.0)).toElement()
    })
        .withKeySelector({ s: String => s })
        .selectedIndex(Int32(selected))
        .selectionMode(mode)
        .onSelectionChanged({ i: Int32 => setSelected.call(Int64(i)) })
        .height(180.0)
        .build()

    vstack([
        text_block("Selection Mode:").bold().toElement(),
        modeList,
        text_block("Items:").bold().toElement(),
        itemsList,
        text_block("selected_index = ${selected} (${label}) | mode = ${modeName}").toElement()
    ])
        .spacing(8.0)
        .maxWidth(320.0)
        .toElement()
}

// ── grid_view ──────────────────────────────────────────────────────────────
// A static templated GridView of colour tiles. Each item renders as a bordered,
// fixed-size coloured cell. No selection state.
func gridViewExample(_cx: RenderCx): Element {
    let items: Array<String> = ["Red", "Green", "Blue", "Yellow", "Magenta", "Cyan"]

    gridView<String>(items, { s: String, _idx: Int64 =>
        border(text_block(s).fontSize(12.0).bold().toElement())
            .background(Brush.Solid(Color.rgb(220u8, 230u8, 245u8)))
            .padding(Thickness.uniform(10.0))
            .width(110.0)
            .height(70.0)
            .toElement()
    })
        .withKeySelector({ s: String => s })
        .height(220.0)
        .build()
}

// ── flip_view ──────────────────────────────────────────────────────────────
// A templated FlipView showing one coloured page at a time. Prev/Next buttons
// clamp the page index at the ends; selection changes from the flip gesture
// also update the page state. The footer echoes the current page index.
func flipViewExample(cx: RenderCx): Element {
    let (page, setPage) = cx.useState<Int64>(0)

    let items: Array<String> = ["Red", "Green", "Blue"]
    let last = items.size - 1

    let flip = flipView<String>(items, { s: String, _idx: Int64 =>
        border(text_block(s).fontSize(20.0).bold().toElement())
            .background(Brush.Solid(Color.rgb(245u8, 230u8, 220u8)))
            .padding(Thickness.uniform(24.0))
            .toElement()
    })
        .withKeySelector({ s: String => s })
        .selectedIndex(Int32(page))
        .onSelectionChanged({ i: Int32 => setPage.call(Int64(i)) })
        .height(180.0)
        .build()

    let prevPage = if (page - 1 > 0) { page - 1 } else { 0 }
    let nextPage = if (page + 1 < last) { page + 1 } else { last }

    vstack([
        flip,
        hstack([
            button("Prev").onClick({ => setPage.call(prevPage) }).toElement(),
            button("Next").onClick({ => setPage.call(nextPage) }).toElement(),
            text_block("page = ${page}").opacity(0.7).toElement()
        ])
            .spacing(8.0)
            .toElement()
    ])
        .spacing(8.0)
        .maxWidth(360.0)
        .toElement()
}

// ── tree_view ──────────────────────────────────────────────────────────────
// A hierarchical TreeView modelling a small file tree. The Documents node is
// expanded by default. Invoking an item records its text into a state cell that
// the footer echoes.
func treeViewExample(cx: RenderCx): Element {
    let (lastInvoked, setLastInvoked) = cx.useState<String>("(none)")

    let nodes = ArrayList<TreeNodeDef>()
    nodes.add(collTreeNode("Documents", true, [
        collTreeNode("Work", false, [collLeaf("report.docx")]),
        collTreeNode("Personal", false, [collLeaf("budget.xlsx"), collLeaf("notes.txt")])
    ]))
    nodes.add(collTreeNode("Pictures", false, [collLeaf("vacation.jpg"), collLeaf("family.png")]))
    nodes.add(collTreeNode("Music", false, [collLeaf("playlist.m3u")]))

    vstack([
        tree_view(nodes)
            .onItemInvoked({ text: String => setLastInvoked.call(text) })
            .toElement(),
        text_block("Last invoked: ${lastInvoked}").toElement()
    ])
        .spacing(12.0)
        .toElement()
}

// Build a TreeNodeDef with an expanded flag and child nodes.
func collTreeNode(text: String, expanded: Bool, children: Array<TreeNodeDef>): TreeNodeDef {
    let node = TreeNodeDef(text)
    node.isExpanded = expanded
    let kids = ArrayList<TreeNodeDef>()
    for (c in children) { kids.add(c) }
    node.children = kids
    node
}

// Build a leaf TreeNodeDef (no children, not expanded).
func collLeaf(text: String): TreeNodeDef {
    TreeNodeDef(text)
}

// ── combo_box ──────────────────────────────────────────────────────────────
// Three ComboBoxes: a selectable colour picker echoing its index/label, an
// editable animal box, and a disabled box pinned to index 0.
func comboBoxExample(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int64>(-1)

    let colors: Array<String> = ["Red", "Green", "Blue"]
    let label = if (selected >= 0 && selected < colors.size) {
        colors[selected]
    } else {
        "(none)"
    }

    let colorItems = ArrayList<String>()
    for (c in colors) { colorItems.add(c) }

    let animalItems = ArrayList<String>()
    for (a in ["Cat", "Dog", "Fox"]) { animalItems.add(a) }

    let disabledItems = ArrayList<String>()
    for (d in ["A", "B", "C"]) { disabledItems.add(d) }

    vstack([
        combo_box(colorItems)
            .header("Color")
            .placeholder("Pick a color")
            .selectedIndexOf(Int32(selected))
            .onSelectionChanged({ i: Int32 => setSelected.call(Int64(i)) })
            .toElement(),
        text_block("selected_index = ${selected} (${label})").toElement(),
        combo_box(animalItems)
            .header("Editable")
            .placeholder("Type or pick an animal")
            .editable(true)
            .toElement(),
        combo_box(disabledItems)
            .header("Disabled")
            .selectedIndexOf(0)
            .enabled(false)
            .toElement()
    ])
        .spacing(8.0)
        .maxWidth(320.0)
        .toElement()
}

func routeCollections(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "list_box" => Some(("Sample", listBoxExample))
        case "list_view" => Some(("Sample", listViewExample))
        case "grid_view" => Some(("Sample", gridViewExample))
        case "flip_view" => Some(("Sample", flipViewExample))
        case "tree_view" => Some(("TreeView Sample", treeViewExample))
        case "combo_box" => Some(("Sample", comboBoxExample))
        case _ => None
    }
}

func namesCollections(): Array<String> {
    ["list_box", "list_view", "grid_view", "flip_view", "tree_view", "combo_box"]
}
