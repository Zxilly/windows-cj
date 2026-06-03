package windows_reactor.winui

import windows_reactor.core.{Callback, SelectionMode}
import windows_interface.IInspectable
import windows_common.Microsoft.UI.Xaml.Controls.{
    ItemsControl, ListViewBase, TextBlock
}
import windows_common.Microsoft.UI.Xaml.Controls.Primitives.Selector
import windows_common.Microsoft.UI.Xaml.Controls.SelectionChangedEventHandler
import windows_common.impl.{
    Windows_Foundation_Collections_IVector_1 as IVectorRaw,
    Microsoft_UI_Xaml_Controls_ListViewSelectionMode as ListViewSelectionModeAbi,
    Microsoft_UI_Xaml_Controls_ListViewSelectionMode_None as LVSelNone,
    Microsoft_UI_Xaml_Controls_ListViewSelectionMode_Single as LVSelSingle,
    Microsoft_UI_Xaml_Controls_ListViewSelectionMode_Multiple as LVSelMultiple,
    Microsoft_UI_Xaml_Controls_ListViewSelectionMode_Extended as LVSelExtended
}

// ============================================================================
// Templated (virtualised) list/grid/flip family — free functions.
//
// The templated-list backend path (ListView / GridView / FlipView) is the
// virtualised collection family: items are realised per-row by the reconciler
// via templatedSetRowContent rather than carried as a flat-list prop. These are
// the thin free functions the WinUIBackend templated methods delegate to.
//
// Reference: winui/backend/mod.rs set_templated_item_count /
// set_templated_row_content / set_templated_selected_index /
// set_templated_selection_mode / scroll_templated_to_index /
// attach_templated_selection_changed / attach_templated_realization.
//
// Projection ABI (spec §8.6, verified against the windows_common projections):
//   - ListView / GridView / FlipView are ItemsControl-derived; their item store
//     is `IItemsControl.Items` (an ItemCollection backed by an
//     IObservableVector<IInspectable>). QI the control to the high-level
//     ItemsControl class, read `Items`, then QI that ItemCollection to its
//     generic IVector<IInspectable> base via takeInspectableVector (which uses
//     the canonical PIID — the generated asIVector_…IInspectable_ mis-hashes the
//     IID and would throw E_NOINTERFACE; see util.cj/inspectableVectorIid) and
//     mutate it with the raw unsafe vtable Size / GetAt / SetAt / RemoveAt /
//     Append / Clear (each returning an HRESULT wrapped in checkHRESULT).
//   - SelectedIndex lives on Primitives.ISelector — ListView / GridView /
//     FlipView all extend Selector. QI the control to the high-level
//     Primitives.Selector class which exposes `mut prop SelectedIndex: Int32`
//     and the SelectionChanged accessor.
//   - SelectionMode lives on IListViewBase (ListView / GridView only — FlipView
//     is a Selector but NOT a ListViewBase, so it has no SelectionMode). QI to
//     the high-level ListViewBase class which exposes
//     `mut prop SelectionMode: ListViewSelectionMode`.
//   - ScrollIntoView lives on IListViewBase (ListView / GridView). FlipView has
//     no scroll surface; flipping to a row == setting Selector.SelectedIndex.
//
// COM-failure policy: the raw IVector ops and the high-level `mut prop` setters
// throw a WindowsException on a failing HRESULT; WinUIBackend's templated
// methods catch these so a failed apply never panics the render loop.
// ============================================================================

// ListViewBase item count. The reference WinUIBackend implements this as an
// explicit no-op (`fn set_templated_item_count(&mut self, _id, _count) {}`):
// the virtual collection's length is driven entirely by per-row realisation
// (templatedSetRowContent grows/shrinks the Items vector), so there is no
// independent count to push. Kept a faithful no-op.
func templatedSetItemCount(handle: Handle, count: Int64): Unit {
    let _ = handle
    let _ = count
}

// Realise (or clear) the content element for row `rowIdx`.
//
// Mirrors set_templated_row_content: QI the list to IItemsControl, take its
// Items as a generic IVector<IInspectable>, and:
//   - content Some(ui): if rowIdx < current length, SetAt(rowIdx, ui); else
//     pad the vector with placeholder TextBlocks up to rowIdx, then Append(ui).
//   - content None: if rowIdx < current length, RemoveAt(rowIdx); else no-op.
// The resolved row-content UIElement identity (handle.asRaw, an IInspectable-
// derived object) is viewed non-owningly as IInspectable for the vector op.
func templatedSetRowContent(handle: Handle, rowIdx: Int64, content: ?Handle): Unit {
    // Only templated lists (ListView / GridView / FlipView) own a per-row Items
    // vector; other handles fall through to a no-op (mirrors the reference's
    // is-a-templated-list guard, but non-panicking per the spec render loop).
    match (handle) {
        case ListViewH(_) | GridViewH(_) | FlipViewH(_) => ()
        case _ =>
            return
    }
    let ic = ItemsControl.fromAbiTake(
        queryRequired(handle.asRaw(), ItemsControl.iid(),
            "Microsoft.UI.Xaml.Controls.IItemsControl")
    )
    try {
        let coll = ic.Items
        try {
            // QI the ItemCollection to IVector<Object> using the canonical PIID
            // (the generated asIVector_… uses a mis-hashed IID — see
            // util.cj/inspectableVectorIid — and would throw E_NOINTERFACE here).
            let vec = takeInspectableVector(coll.asRaw())
            try {
                let currentLen = Int64(templatedVectorSize(vec))
                match (content) {
                    case Some(rowH) =>
                        let insp = IInspectable.viewOf(rowH.asRaw())
                        if (rowIdx < currentLen) {
                            checkHRESULT(
                                unsafe { vec.SetAt(UInt32(rowIdx), insp.asRaw()) },
                                "ItemsControl.Items.SetAt"
                            )
                        } else {
                            // Grow with placeholder TextBlocks until the vector
                            // reaches rowIdx, then append the real content.
                            while (Int64(templatedVectorSize(vec)) < rowIdx) {
                                let pad = TextBlock.new()
                                try {
                                    checkHRESULT(
                                        unsafe { vec.Append(pad.asIInspectable().asRaw()) },
                                        "ItemsControl.Items.Append(pad)"
                                    )
                                } finally {
                                    pad.close()
                                }
                            }
                            checkHRESULT(
                                unsafe { vec.Append(insp.asRaw()) },
                                "ItemsControl.Items.Append"
                            )
                        }
                    case None =>
                        if (rowIdx < currentLen) {
                            checkHRESULT(
                                unsafe { vec.RemoveAt(UInt32(rowIdx)) },
                                "ItemsControl.Items.RemoveAt"
                            )
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

// Pivot exposes its pages via IItemsControl.Items (an IVector<IInspectable>),
// reached the same way as templatedSetRowContent. Used by the backend's Pivot
// visual-tree insert/remove/set arms (mirrors the reference Pivot cases). The
// caller OWNS the returned vector and must close() it; the intermediate
// ItemsControl + ItemCollection refs are released here.
func itemsControlItemsVector(handle: Handle): InspectableVector {
    let ic = ItemsControl.fromAbiTake(
        queryRequired(handle.asRaw(), ItemsControl.iid(),
            "Microsoft.UI.Xaml.Controls.IItemsControl")
    )
    try {
        let coll = ic.Items
        try {
            return takeInspectableVector(coll.asRaw())
        } finally {
            coll.close()
        }
    } finally {
        ic.close()
    }
}

// Selector.SelectedIndex on a templated list. Mirrors set_templated_selected_index:
// QI to the Primitives.Selector class (ListView / GridView / FlipView all extend
// Selector) and assign SelectedIndex. Non-templated handles no-op.
func templatedSetSelectedIndex(handle: Handle, index: Int32): Unit {
    match (handle) {
        case ListViewH(_) | GridViewH(_) | FlipViewH(_) =>
            let sel = Selector.fromAbiTake(
                queryRequired(handle.asRaw(), Selector.iid(),
                    "Microsoft.UI.Xaml.Controls.Primitives.ISelector")
            )
            try {
                sel.SelectedIndex = index
            } finally {
                sel.close()
            }
        case _ => ()
    }
}

// ListViewBase.SelectionMode mapped from the core SelectionMode. Mirrors
// set_templated_selection_mode: only ListView / GridView are ListViewBase-derived
// (FlipView is a Selector but not a ListViewBase, so it has no SelectionMode and
// is a no-op here, matching the reference's `_ => return` arm).
func templatedSetSelectionMode(handle: Handle, mode: SelectionMode): Unit {
    match (handle) {
        case ListViewH(_) | GridViewH(_) =>
            let lvb = ListViewBase.fromAbiTake(
                queryRequired(handle.asRaw(), ListViewBase.iid(),
                    "Microsoft.UI.Xaml.Controls.IListViewBase")
            )
            try {
                lvb.SelectionMode = templatedToXamlSelectionMode(mode)
            } finally {
                lvb.close()
            }
        case _ => ()
    }
}

// Scroll the templated list to the row at `index`. Mirrors scroll_templated_to_index:
//   - index < 0: no-op.
//   - FlipView: no ScrollIntoView surface; flipping == Selector.SelectedIndex.
//   - ListView / GridView: QI to ListViewBase, read the item at `index` from the
//     Items vector (only when index < size) and ScrollIntoView(item).
func templatedScrollToIndex(handle: Handle, index: Int32): Unit {
    if (index < 0) {
        return
    }
    match (handle) {
        case FlipViewH(_) =>
            let sel = Selector.fromAbiTake(
                queryRequired(handle.asRaw(), Selector.iid(),
                    "Microsoft.UI.Xaml.Controls.Primitives.ISelector")
            )
            try {
                sel.SelectedIndex = index
            } finally {
                sel.close()
            }
        case ListViewH(_) | GridViewH(_) =>
            let lvb = ListViewBase.fromAbiTake(
                queryRequired(handle.asRaw(), ListViewBase.iid(),
                    "Microsoft.UI.Xaml.Controls.IListViewBase")
            )
            try {
                let ic = ItemsControl.fromAbiTake(
                    queryRequired(handle.asRaw(), ItemsControl.iid(),
                        "Microsoft.UI.Xaml.Controls.IItemsControl")
                )
                try {
                    let coll = ic.Items
                    try {
                        // Canonical-PIID QI (see util.inspectableVectorIid).
                        let vec = takeInspectableVector(coll.asRaw())
                        try {
                            let size = templatedVectorSize(vec)
                            if (UInt32(index) < size) {
                                var slot = CPointer<Unit>()
                                checkHRESULT(
                                    unsafe { vec.GetAt(UInt32(index), CPointer<CPointer<Unit>>(inout slot)) },
                                    "ItemsControl.Items.GetAt"
                                )
                                if (slot.isNotNull()) {
                                    let item = IInspectable.fromAbiTake(slot)
                                    try {
                                        lvb.ScrollIntoView(item)
                                    } finally {
                                        item.close()
                                    }
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
            } finally {
                lvb.close()
            }
        case _ => ()
    }
}

// Subscribe SelectionChanged on a templated list, forwarding the new index to
// `handler`. Mirrors attach_templated_selection_changed: QI to the Selector
// primitive (ListView / GridView / FlipView), register a SelectionChanged
// delegate that reads SelectedIndex back from the sender (the same read used by
// the flat-list selection events), and invoke the callback. Returns the owning
// EventRevoker; None when the handle is not a templated list (nothing wired).
//
// The reference drops any prior registration before re-attaching so repeated
// attaches don't accumulate handlers; here that bookkeeping lives in the
// WinUIBackend revoker registry, which closes the previous revoker before
// storing this one. The returned revoker unregisters the handler and releases
// the captured target + delegate.
func templatedAttachSelectionChanged(handle: Handle, handler: Callback<Int32>): ?EventRevoker {
    match (handle) {
        case ListViewH(_) | GridViewH(_) | FlipViewH(_) =>
            let target = Selector.fromAbiTake(
                queryRequired(handle.asRaw(), Selector.iid(),
                    "Microsoft.UI.Xaml.Controls.Primitives.ISelector")
            )
            let delegate = SelectionChangedEventHandler.new({ sender, _ =>
                // Read the new index from the sender (matches the reference
                // closure: sender.cast::<ISelector>().get_SelectedIndex(),
                // defaulting to -1). Never let an exception cross Invoke.
                try {
                    handler.invoke(selectorSelectedIndex(sender))
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addSelectionChanged(delegate)
            return Some(EventRevoker({ =>
                try {
                    target.removeSelectionChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case _ =>
            let _ = handler
            return None
    }
}

// Realization (ContainerContentChanging realize / recycle) callbacks. The
// reference WinUIBackend leaves attach_templated_realization EMPTY (spec §8.6):
// WinUI virtualisation realises containers on its own schedule and the reactor
// reconciler does not depend on per-container realize/recycle notifications in
// the minimal backend. Kept a faithful no-op.
func templatedAttachRealization(handle: Handle, realize: (Int64) -> Unit, recycle: (Int64) -> Unit): Unit {
    let _ = handle
    let _ = realize
    let _ = recycle
}

// ── private helpers ─────────────────────────────────────────────────────────

// Read the current Size of a generic IVector<IInspectable> via its raw unsafe
// vtable accessor. Returns 0 on a failing Size HRESULT.
func templatedVectorSize(vec: IVectorRaw<IInspectable>): UInt32 {
    var size = 0u32
    let hr = unsafe { vec.Size(CPointer<UInt32>(inout size)) }
    if (hr.failed()) {
        return 0
    }
    size
}

// Map the reactor SelectionMode to the WinUI ListViewSelectionMode ABI value
// (None→0, Single→1, Multiple→2, Extended→3). Mirrors the reference match in
// set_templated_selection_mode.
func templatedToXamlSelectionMode(mode: SelectionMode): ListViewSelectionModeAbi {
    match (mode) {
        case NoneSel => LVSelNone
        case Single => LVSelSingle
        case Multiple => LVSelMultiple
        case Extended => LVSelExtended
    }
}
