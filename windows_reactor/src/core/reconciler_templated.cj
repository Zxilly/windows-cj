package windows_reactor.core

import std.collection.*

// ============================================================================
// Templated (virtualised) list reconciliation + realize/recycle. Reference:
// reconciler/templated.rs. Free functions over the Reconciler.
//
// GC notes: the reference's Rc<RefCell<Vec<RealizationRequest>>> queue and
// Rc<RefCell<Option<Callback<i32>>>> selection trampoline become a plain
// ArrayList field on the Reconciler and a SelectionTrampoline class (a mutable
// reference cell the realize/recycle/selection closures capture). The realize /
// recycle thunks the backend invokes push onto reconciler.realizationQueue;
// drainRealizations() walks it on the UI thread.
// ============================================================================

// A realized row: the rendered Element subtree and its mounted control id.
public class RealizedRow {
    public var rendered: Element
    public var contentId: ControlId
    public init(rendered: Element, contentId: ControlId) {
        this.rendered = rendered
        this.contentId = contentId
    }
}

// State for one templated list: the source element plus a sparse rows array
// (Some when a row is realized, None when virtualised away).
public class TemplatedListState {
    public var element: TemplatedListElement
    public var rows: ArrayList<?RealizedRow>
    public init(element: TemplatedListElement, rows: ArrayList<?RealizedRow>) {
        this.element = element
        this.rows = rows
    }
}

// Mutable selection-callback cell shared with the backend's attached handler so
// update() can swap the inner callback without re-attaching (replaces the
// reference Rc<RefCell<Option<Callback<i32>>>> trampoline).
public class SelectionTrampoline {
    public var inner: ?Callback<Int32> = None
    public init() {}
    public func set(cb: ?Callback<Int32>): Unit { inner = cb }
    public func invoke(idx: Int32): Unit {
        match (inner) { case Some(cb) => cb.invoke(idx); case None => () }
    }
}

func mountTemplatedList(r: Reconciler, tl: TemplatedListElement): ControlId {
    let kind = tl.kind.controlKind()
    let id = r.acquireControl(kind)
    r.applyModifiers(id, tl.modifiers)

    let count = tl.itemCount()
    let rows = ArrayList<?RealizedRow>()
    var z: Int64 = 0
    while (z < count) {
        rows.add(None)
        z++
    }
    r.templatedLists.add(id, TemplatedListState(tl, rows))

    if (tl.hasSelectionHandler()) {
        let trampoline = templatedTrampoline(r, id)
        trampoline.set(tl.rawSelectionCallback())
        let cb = Callback<Int32>({ idx => trampoline.invoke(idx) })
        r.backend.attachTemplatedSelectionChanged(id, cb)
    }

    // realize / recycle thunks enqueue onto the reconciler's realization queue.
    let listId = id
    let queue = r.realizationQueue
    let realize: (Int64) -> Unit = { rowIdx => queue.add(RealizationRequest.RealizeReq(listId, rowIdx)) }
    let recycle: (Int64) -> Unit = { rowIdx => queue.add(RealizationRequest.RecycleReq(listId, rowIdx)) }
    r.backend.attachTemplatedRealization(id, realize, recycle)

    r.backend.setTemplatedItemCount(id, count)
    r.backend.setTemplatedSelectionMode(id, tl.selectionMode)
    let sel = tl.selectedIndex()
    if (sel >= 0) {
        r.backend.setTemplatedSelectedIndex(id, sel)
    }

    if (r.eagerTemplatedRealization) {
        var rowIdx: Int64 = 0
        while (rowIdx < count) {
            r.realizationQueue.add(RealizationRequest.RealizeReq(id, rowIdx))
            rowIdx++
        }
    }

    id
}

func templatedTrampoline(r: Reconciler, id: ControlId): SelectionTrampoline {
    match (r.selectionCallbacks.get(id)) {
        case Some(t) => t
        case None =>
            let t = SelectionTrampoline()
            r.selectionCallbacks.add(id, t)
            t
    }
}

func updateTemplatedList(r: Reconciler, old: TemplatedListElement, neu: TemplatedListElement, id: ControlId): Unit {
    r.diffModifiers(id, old.modifiers, neu.modifiers)

    match (r.templatedLists.get(id)) {
        case Some(state) => state.element = neu
        case None => ()
    }

    match (r.selectionCallbacks.get(id)) {
        case Some(cell) => cell.set(neu.rawSelectionCallback())
        case None => ()
    }

    if (old.selectedIndex() != neu.selectedIndex()) {
        r.backend.setTemplatedSelectedIndex(id, neu.selectedIndex())
    }

    if (old.selectionMode != neu.selectionMode) {
        r.backend.setTemplatedSelectionMode(id, neu.selectionMode)
    }

    let oldCount = old.itemCount()
    let newCount = neu.itemCount()
    if (oldCount != newCount) {
        // Trim trailing realized rows beyond the new count, then resize.
        let toUnmount = ArrayList<(Int64, ControlId)>()
        match (r.templatedLists.get(id)) {
            case Some(state) =>
                if (newCount < state.rows.size) {
                    var i = state.rows.size - 1
                    while (i >= newCount) {
                        match (state.rows[i]) {
                            case Some(row) => toUnmount.add((i, row.contentId))
                            case None => ()
                        }
                        state.rows.remove(at: i)
                        i--
                    }
                }
                while (state.rows.size < newCount) { state.rows.add(None) }
            case None => ()
        }
        for ((rowIdx, cid) in toUnmount) {
            r.backend.setTemplatedRowContent(id, rowIdx, Option<ControlId>.None)
            r.unmount(cid)
        }
        r.backend.setTemplatedItemCount(id, newCount)
    }

    if (!old.sameItemsAs(neu)) {
        refreshRealizedRows(r, id, neu)
    }
}

func refreshRealizedRows(r: Reconciler, id: ControlId, neu: TemplatedListElement): Unit {
    let realizedIndices = ArrayList<Int64>()
    match (r.templatedLists.get(id)) {
        case Some(state) =>
            var i: Int64 = 0
            while (i < state.rows.size) {
                match (state.rows[i]) {
                    case Some(_) => realizedIndices.add(i)
                    case None => ()
                }
                i++
            }
        case None => return
    }

    for (rowIdx in realizedIndices) {
        if (rowIdx >= neu.itemCount()) { continue }
        var oldEl = Element.EmptyEl
        var contentId: ?ControlId = None
        match (r.templatedLists.get(id)) {
            case Some(state) =>
                match (state.rows[rowIdx]) {
                    case Some(row) =>
                        oldEl = row.rendered
                        contentId = Some(row.contentId)
                    case None => ()
                }
            case None => ()
        }
        let cid = match (contentId) {
            case Some(c) => c
            case None => continue
        }
        let newEl = neu.buildItemView(rowIdx)

        if (canSkipUpdate(oldEl, newEl)) {
            r.debugElementsSkipped++
            match (r.templatedLists.get(id)) {
                case Some(state) =>
                    match (state.rows[rowIdx]) {
                        case Some(row) => row.rendered = newEl
                        case None => ()
                    }
                case None => ()
            }
            continue
        }

        match (r.update(oldEl, newEl, cid)) {
            case Some(nid) =>
                match (r.templatedLists.get(id)) {
                    case Some(state) => state.rows[rowIdx] = Some(RealizedRow(newEl, nid))
                    case None => ()
                }
                if (nid != cid) {
                    r.backend.setTemplatedRowContent(id, rowIdx, Some(nid))
                }
            case None =>
                match (r.templatedLists.get(id)) {
                    case Some(state) => state.rows[rowIdx] = None
                    case None => ()
                }
                r.backend.setTemplatedRowContent(id, rowIdx, Option<ControlId>.None)
        }
    }
}

public func drainRealizations(r: Reconciler): Unit {
    let drained = r.realizationQueue.toArray()
    r.realizationQueue.clear()
    for (req in drained) {
        match (req) {
            case RealizeReq(listId, rowIdx) => realizeRowInner(r, listId, rowIdx)
            case RecycleReq(listId, rowIdx) => recycleRowInner(r, listId, rowIdx)
        }
    }
}

func realizeRowInner(r: Reconciler, listId: ControlId, rowIdx: Int64): Unit {
    let state = match (r.templatedLists.get(listId)) {
        case Some(s) => s
        case None => return
    }
    if (rowIdx >= state.element.itemCount()) { return }
    let rendered = state.element.buildItemView(rowIdx)
    let count = state.element.itemCount()

    match (clearRowRealizedState(r, listId, rowIdx)) {
        case Some(existing) => r.unmount(existing)
        case None => ()
    }

    let contentId = match (r.mount(rendered)) {
        case Some(c) => c
        case None =>
            return
    }

    r.backend.setTemplatedRowContent(listId, rowIdx, Some(contentId))
    match (r.templatedLists.get(listId)) {
        case Some(state) =>
            while (state.rows.size < count) { state.rows.add(None) }
            state.rows[rowIdx] = Some(RealizedRow(rendered, contentId))
        case None => ()
    }

    dispatchAppeared(r, contentId)
}

func recycleRowInner(r: Reconciler, listId: ControlId, rowIdx: Int64): Unit {
    let existing = match (clearRowRealizedState(r, listId, rowIdx)) {
        case Some(e) => e
        case None => return
    }

    dispatchDisappeared(r, existing)
    r.backend.setTemplatedRowContent(listId, rowIdx, Option<ControlId>.None)
    if (r.deferTemplatedUnmounts) {
        r.deferredUnmounts.add(existing)
    } else {
        r.unmount(existing)
    }
}

func clearRowRealizedState(r: Reconciler, listId: ControlId, rowIdx: Int64): ?ControlId {
    match (r.templatedLists.get(listId)) {
        case Some(state) =>
            if (rowIdx < 0 || rowIdx >= state.rows.size) { return None }
            match (state.rows[rowIdx]) {
                case Some(row) =>
                    state.rows[rowIdx] = None
                    Some(row.contentId)
                case None => None
            }
        case None => None
    }
}

func dispatchAppeared(r: Reconciler, id: ControlId): Unit {
    if (r.appearedListenerCount == 0) { return }
    let subtree = r.collectSubtreeIds(id)
    for (node in subtree) {
        match (r.componentInstances.get(node)) {
            case Some(inst) =>
                if (!inst.lastObj.hasOnAppeared()) { continue }
                inst.renderCx.setContextStack(r.contextStackHandle())
                inst.lastObj.invokeAppeared(inst.renderCx)
            case None => ()
        }
    }
}

func dispatchDisappeared(r: Reconciler, id: ControlId): Unit {
    if (r.disappearedListenerCount == 0) { return }
    let subtree = r.collectSubtreeIds(id)
    for (node in subtree) {
        match (r.componentInstances.get(node)) {
            case Some(inst) =>
                if (!inst.lastObj.hasOnDisappeared()) { continue }
                inst.renderCx.setContextStack(r.contextStackHandle())
                inst.lastObj.invokeDisappeared(inst.renderCx)
            case None => ()
        }
    }
}
