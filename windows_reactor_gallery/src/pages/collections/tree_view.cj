package windows_reactor_gallery.pages.collections

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let treeViewPageToken = newComponentTypeToken()

// ── TreeView ───────────────────────────────────────────────────────────────--
// A hierarchical list with expanding and collapsing nodes. The file-explorer
// card reports the last invoked item; the flat card has no children.
func treeViewPage(cx: RenderCx): Element {
    let (invoked, setInvoked) = cx.useState<String>("(none)")

    let fileSystem = ArrayList<TreeNodeDef>()
    fileSystem.add(treeNode("Documents", true, [
        treeNode("Work", false, [leafNode("Report.docx"), leafNode("Budget.xlsx")]),
        treeNode("Personal", false, [leafNode("Resume.pdf")])
    ]))
    fileSystem.add(treeNode("Pictures", false, [leafNode("Vacation.jpg"), leafNode("Family.png")]))
    fileSystem.add(treeNode("Music", false, [leafNode("Song1.mp3"), leafNode("Song2.mp3")]))

    let fileTree = tree_view(fileSystem)
        .onItemInvoked({ s: String => setInvoked.call(s) })
        .toElement()

    let fileSample = vstack([
        fileTree,
        text_block("Last invoked: ${invoked}").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    let flatNodes = ArrayList<TreeNodeDef>()
    flatNodes.add(leafNode("Item A"))
    flatNodes.add(leafNode("Item B"))
    flatNodes.add(leafNode("Item C"))
    let flatTree = tree_view(flatNodes).toElement()

    page_content(
        "TreeView",
        "A hierarchical list with expanding and collapsing nodes.",
        [
            sample_card(
                "File Explorer TreeView",
                fileSample,
                "tree_view(nodes).on_item_invoked(|s| set(s))"
            ),
            sample_card(
                "Flat TreeView",
                flatTree,
                "tree_view(vec![tree_node(\"A\"), tree_node(\"B\")])"
            )
        ]
    )
}

// Build a TreeNodeDef with an expanded flag and child nodes.
func treeNode(text: String, expanded: Bool, children: Array<TreeNodeDef>): TreeNodeDef {
    let node = TreeNodeDef(text)
    node.isExpanded = expanded
    let kids = ArrayList<TreeNodeDef>()
    for (c in children) { kids.add(c) }
    node.children = kids
    node
}

// Build a leaf TreeNodeDef (no children, not expanded).
func leafNode(text: String): TreeNodeDef {
    TreeNodeDef(text)
}
