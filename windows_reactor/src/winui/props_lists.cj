package windows_reactor.winui

import std.collection.ArrayList
import windows_reactor.core.{Prop, PropValue, TreeNodeDef, TreeSelectionMode}
import windows_core.HString
import windows_interface.IInspectable
import windows_reference.hStringReference
import windows_reactor.bindings.Microsoft.UI.Xaml.Controls.{
    TreeViewNode, ItemsControl, Control, TextBlock
}
import windows_reactor.bindings.Microsoft.UI.Xaml.Controls.Primitives.Selector
import windows_reactor.bindings.Microsoft.UI.Xaml.Controls.{TreeViewSelectionMode as TreeViewSelectionModeAbi, TreeViewSelectionMode_None as TVSelNone, TreeViewSelectionMode_Single as TVSelSingle, TreeViewSelectionMode_Multiple as TVSelMultiple}

// ============================================================================
// Per-family property setters for selection / collection controls (ListView,
// GridView, ListBox, ComboBox, FlipView, TreeView). Returns true when the prop
// was consumed.
//
// ABI notes (spec §8.1, verified against the windows_sys projections):
//   - ComboBox / ListBox flat-list items: QI the control to the high-level
//     ItemsControl class (defaultInterface == IItemsControl), read its `Items`
//     (an ItemCollection backed by IObservableVector<IInspectable>), QI that to
//     the generic IVector<IInspectable> and rebuild it (Clear + Append). Each
//     string item is boxed into an IReference<HString> (IInspectable) — mirrors
//     the reference `IReference::from(s).cast::<IInspectable>()`.
//   - SelectedIndex lives on Primitives.ISelector, not on the leaf class; QI to
//     the high-level Primitives.Selector class which exposes `mut prop
//     SelectedIndex: Int32`.
//   - ComboBox.Header / PlaceholderText / IsEditable are direct high-level
//     ComboBox class properties. Header is an IInspectable: a string header is
//     wrapped in a TextBlock (matching `string_as_textblock`), Unset clears it
//     with a null IInspectable.
//   - IsEnabled lives on Control; QI to the high-level Control class.
//   - TreeView.RootNodes is an IVector<TreeViewNode>; nodes are built
//     recursively (Content = IReference<HString>, IsExpanded, Children) and
//     appended. SelectionMode is a direct high-level TreeView property.
//   - ListView / GridView / FlipView realise their items through the
//     templated-list Backend methods (reconciler/templated), not set_prop, so
//     they carry no per-control props here and correctly fall through to false.
//
// COM-failure policy: the high-level `mut prop` setters and the *.check()-based
// accessors throw a WindowsException on a failing HRESULT; the raw IVector
// Append/Clear are wrapped in checkHRESULT. WinUIBackend.setProp catches all of
// these so a failed set never panics the render loop (spec §8.3).
// ============================================================================
func applyListProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        case ComboBoxItems =>
            match ((handle, value)) {
                case (ComboBoxH(c), StrList(items)) =>
                    listsRebuildFlatItems(c.asRaw(), items)
                    true
                case _ => false
            }
        case ListBoxItems =>
            match ((handle, value)) {
                case (ListBoxH(lb), StrList(items)) =>
                    listsRebuildFlatItems(lb.asRaw(), items)
                    true
                case _ => false
            }
        case SelectedIndex =>
            match ((handle, value)) {
                case (ComboBoxH(c), I32(v)) =>
                    listsSetSelectorIndex(c.asRaw(), v)
                    true
                case (ListBoxH(lb), I32(v)) =>
                    listsSetSelectorIndex(lb.asRaw(), v)
                    true
                case _ => false
            }
        case Header =>
            match ((handle, value)) {
                case (ComboBoxH(c), Str(s)) =>
                    let tb = listsStringAsTextBlock(s)
                    try {
                        c.Header = tb.asIInspectable()
                    } finally {
                        tb.close()
                    }
                    true
                case (ComboBoxH(c), Unset) =>
                    c.Header = IInspectable.viewOf(CPointer<Unit>())
                    true
                case _ => false
            }
        case Placeholder =>
            match ((handle, value)) {
                case (ComboBoxH(c), Str(s)) =>
                    let hs = HString(s)
                    try {
                        c.PlaceholderText = hs
                    } finally {
                        hs.close()
                    }
                    true
                case (ComboBoxH(c), Unset) =>
                    let hs = HString("")
                    try {
                        c.PlaceholderText = hs
                    } finally {
                        hs.close()
                    }
                    true
                case _ => false
            }
        case IsEditable =>
            match ((handle, value)) {
                case (ComboBoxH(c), BoolV(v)) =>
                    c.IsEditable = v
                    true
                case _ => false
            }
        case IsEnabled =>
            match ((handle, value)) {
                case (ComboBoxH(c), BoolV(v)) =>
                    listsSetControlEnabled(c.asRaw(), v)
                    true
                case (ListBoxH(lb), BoolV(v)) =>
                    listsSetControlEnabled(lb.asRaw(), v)
                    true
                case _ => false
            }
        case TreeViewNodes =>
            match ((handle, value)) {
                case (TreeViewH(tv), TreeViewNodesV(nodes)) =>
                    let root = tv.RootNodes
                    try {
                        checkHRESULT(unsafe { root.Clear() }, "TreeView.RootNodes.Clear")
                        for (def in nodes) {
                            let node = listsBuildTreeViewNode(def)
                            try {
                                checkHRESULT(unsafe { root.Append(node.asRaw()) }, "TreeView.RootNodes.Append")
                            } finally {
                                node.close()
                            }
                        }
                    } finally {
                        root.close()
                    }
                    true
                case _ => false
            }
        case TreeViewSelectionMode =>
            match ((handle, value)) {
                case (TreeViewH(tv), TreeViewSelectionModeV(mode)) =>
                    tv.SelectionMode = listsToXamlTreeSelectionMode(mode)
                    true
                case _ => false
            }
        case _ => false
    }
}

// Rebuild a flat-list ItemsControl's Items collection from string items.
// `raw` is the control's identity pointer (ComboBox / ListBox). Clears the
// existing items then appends each string boxed as IReference<HString>.
func listsRebuildFlatItems(raw: CPointer<Unit>, items: ArrayList<String>): Unit {
    let ic = ItemsControl.fromAbiTake(
        queryRequired(raw, ItemsControl.iid(), "Microsoft.UI.Xaml.Controls.IItemsControl")
    )
    try {
        let coll = ic.Items
        try {
            // QI the ItemCollection to IVector<Object> using the canonical PIID
            // (the generated asIVector_… mis-hashes the IID and throws
            // E_NOINTERFACE — see util.cj/inspectableVectorIid).
            let vec = takeInspectableVector(coll.asRaw())
            try {
                checkHRESULT(unsafe { vec.Clear() }, "ItemsControl.Items.Clear")
                for (s in items) {
                    let boxed = hStringReference(s)
                    try {
                        checkHRESULT(unsafe { vec.Append(boxed.asRaw()) }, "ItemsControl.Items.Append")
                    } finally {
                        boxed.close()
                    }
                }
            } finally {
                vec.close()
            }
        } finally {
            coll.close()
        }
    } finally {
        ic.close()
    }
}

// Set the SelectedIndex on a Selector-derived control (ComboBox / ListBox) via
// the high-level Primitives.Selector projection (ISelector identity).
func listsSetSelectorIndex(raw: CPointer<Unit>, index: Int32): Unit {
    let sel = Selector.fromAbiTake(
        queryRequired(raw, Selector.iid(), "Microsoft.UI.Xaml.Controls.Primitives.ISelector")
    )
    try {
        sel.SelectedIndex = index
    } finally {
        sel.close()
    }
}

// Set IsEnabled on any Control-derived control via the high-level Control
// projection (IControl identity).
func listsSetControlEnabled(raw: CPointer<Unit>, enabled: Bool): Unit {
    let ctrl = Control.fromAbiTake(
        queryRequired(raw, Control.iid(), "Microsoft.UI.Xaml.Controls.IControl")
    )
    try {
        ctrl.IsEnabled = enabled
    } finally {
        ctrl.close()
    }
}

// Build a TextBlock carrying `s` (mirrors the reference `string_as_textblock`).
// Caller owns the returned TextBlock and must close() it.
func listsStringAsTextBlock(s: String): TextBlock {
    let tb = TextBlock.new()
    let hs = HString(s)
    try {
        tb.Text = hs
    } finally {
        hs.close()
    }
    tb
}

// Recursively build a TreeViewNode from a TreeNodeDef (mirrors the reference
// build_tree_view_node): Content is the node text boxed as IReference<HString>;
// IsExpanded is applied; children are built and appended in order. Caller owns
// the returned node and must close() it.
func listsBuildTreeViewNode(def: TreeNodeDef): TreeViewNode {
    let node = makeComposable(TreeViewNode.CreateInstance)
    let content = hStringReference(def.text)
    try {
        node.SetContent(content.asIInspectable())
    } finally {
        content.close()
    }
    node.SetIsExpanded(def.isExpanded)
    if (def.children.size > 0) {
        let children = node.Children()
        try {
            for (childDef in def.children) {
                let childNode = listsBuildTreeViewNode(childDef)
                try {
                    checkHRESULT(unsafe { children.Append(childNode.asRaw()) }, "TreeViewNode.Children.Append")
                } finally {
                    childNode.close()
                }
            }
        } finally {
            children.close()
        }
    }
    node
}

// Map the reactor TreeSelectionMode to the WinUI TreeViewSelectionMode ABI
// value (None→0, Single→1, Multiple→2).
func listsToXamlTreeSelectionMode(mode: TreeSelectionMode): TreeViewSelectionModeAbi {
    match (mode) {
        case NoneSel => TVSelNone
        case Single => TVSelSingle
        case Multiple => TVSelMultiple
    }
}
