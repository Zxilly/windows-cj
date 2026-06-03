package windows_reactor.core

import std.collection.*

// ============================================================================
// Children diff — positional + keyed (prefix/suffix shrink + LIS). Reference:
// reconciler/child.rs. Free functions over the Reconciler. Inputs are already
// flattened LiveChildren arrays (Empty dropped, Group spliced) so indices map
// straight onto the panel mirror for the prefix/positional paths.
// ============================================================================

func updateChildTracked(r: Reconciler, parent: ControlId, index: Int64, old: Element, neu: Element): Unit {
    let oldId = match (r.childAt(parent, index)) {
        case Some(x) => x
        case None => return
    }
    match (r.update(old, neu, oldId)) {
        case Some(nid) where nid != oldId => r.replaceChildTracked(parent, index, nid)
        case Some(_) => ()
        case None => r.removeChildTracked(parent, index)
    }
}

// Entry: route to keyed or positional based on whether any child carries a key.
func reconcileChildLists(r: Reconciler, parent: ControlId, oldLive: Array<Element>, newLive: Array<Element>): Unit {
    let hasKeys = anyHasKey(oldLive) || anyHasKey(newLive)
    if (hasKeys) {
        reconcileKeyedLive(r, parent, oldLive, newLive)
    } else {
        reconcilePositionalLive(r, parent, oldLive, newLive)
    }
}

func reconcilePositional(r: Reconciler, parent: ControlId, oldLive: Array<Element>, newLive: Array<Element>): Unit {
    reconcilePositionalLive(r, parent, oldLive, newLive)
}

func reconcilePositionalLive(r: Reconciler, parent: ControlId, oldLive: Array<Element>, newLive: Array<Element>): Unit {
    let oldLen = oldLive.size
    let newLen = newLive.size
    let common = minI64(oldLen, newLen)

    var i = 0
    while (i < common) {
        if (r.childAt(parent, i).isNone()) {
            // Out of mirror bounds — defensive break (reference debug_asserts).
            break
        }
        let oldEl = oldLive[i]
        let newEl = newLive[i]

        if (!r.forceComponentRerender && canSkipUpdate(oldEl, newEl)) {
            // Even when structurally identical, a child component whose state
            // was mutated via SetState must still re-render.
            let stateDirty = match (r.childAt(parent, i)) {
                case Some(cid) => r.isComponentStateDirty(cid)
                case None => false
            }
            if (!stateDirty) {
                r.debugElementsSkipped++
                i++
                continue
            }
        }

        if (oldEl.kindMatches(newEl)) {
            updateChildTracked(r, parent, i, oldEl, newEl)
        } else {
            match (r.childAt(parent, i)) {
                case Some(oldId) => r.unmount(oldId)
                case None => ()
            }
            match (r.mount(newEl)) {
                case Some(newId) => r.replaceChildTracked(parent, i, newId)
                case None => r.removeChildTracked(parent, i)
            }
        }
        i++
    }

    if (oldLen > newLen) {
        var idx = oldLen - 1
        while (idx >= common) {
            match (r.childAt(parent, idx)) {
                case Some(id) => r.unmount(id)
                case None => ()
            }
            r.removeChildTracked(parent, idx)
            idx--
        }
    }

    if (newLen > oldLen) {
        var k = common
        while (k < newLen) {
            match (r.mount(newLive[k])) {
                case Some(childId) => r.appendChildTracked(parent, childId)
                case None => ()
            }
            k++
        }
    }
}

func effectiveKey(el: Element, positionalIndex: Int64): String {
    match (el.key()) {
        case Some(k) => k
        case None => "__pos_${positionalIndex}_${el.kindName()}"
    }
}

func keyMatch(a: Element, b: Element): Bool {
    if (!a.canUpdate(b)) { return false }
    optStrEq(a.key(), b.key())
}

func reconcileKeyedLive(r: Reconciler, parent: ControlId, old: Array<Element>, neu: Array<Element>): Unit {
    let oldLen = old.size
    let newLen = neu.size

    // Prefix scan: match from the head and update in place.
    var prefix = 0
    while (prefix < oldLen && prefix < newLen && keyMatch(old[prefix], neu[prefix])) {
        let oldEl = old[prefix]
        let newEl = neu[prefix]
        if (r.childAt(parent, prefix).isSome()) {
            if (!r.forceComponentRerender && canSkipUpdate(oldEl, newEl)) {
                let stateDirty = match (r.childAt(parent, prefix)) {
                    case Some(cid) => r.isComponentStateDirty(cid)
                    case None => false
                }
                if (stateDirty) {
                    updateChildTracked(r, parent, prefix, oldEl, newEl)
                } else {
                    r.debugElementsSkipped++
                }
            } else {
                updateChildTracked(r, parent, prefix, oldEl, newEl)
            }
        }
        prefix++
    }

    let oldRemaining = saturatingSub(oldLen, prefix)
    let newRemaining = saturatingSub(newLen, prefix)

    // Suffix scan: match from the tail; panel index is derived from the mirror
    // length so it tracks mid-section insert/remove offsets.
    var suffix = 0
    while (suffix < oldRemaining && suffix < newRemaining &&
           keyMatch(old[oldLen - 1 - suffix], neu[newLen - 1 - suffix])) {
        let oldIdx = oldLen - 1 - suffix
        let panelIdx = saturatingSub(saturatingSub(r.mirrorLen(parent), 1), suffix)
        let oldEl = old[oldIdx]
        let newEl = neu[newLen - 1 - suffix]
        if (r.childAt(parent, panelIdx).isSome()) {
            if (!r.forceComponentRerender && canSkipUpdate(oldEl, newEl)) {
                let stateDirty = match (r.childAt(parent, panelIdx)) {
                    case Some(cid) => r.isComponentStateDirty(cid)
                    case None => false
                }
                if (stateDirty) {
                    updateChildTracked(r, parent, panelIdx, oldEl, newEl)
                } else {
                    r.debugElementsSkipped++
                }
            } else {
                updateChildTracked(r, parent, panelIdx, oldEl, newEl)
            }
        }
        suffix++
    }

    let oldStart = prefix
    let oldEnd = oldLen - suffix
    let newStart = prefix
    let newEnd = newLen - suffix
    let oldMidLen = oldEnd - oldStart
    let newMidLen = newEnd - newStart

    if (oldMidLen == 0 && newMidLen == 0) { return }

    if (oldMidLen == 0) {
        var i = 0
        while (i < newMidLen) {
            match (r.mount(neu[newStart + i])) {
                case Some(ctrl) => r.insertChildTracked(parent, prefix + i, ctrl)
                case None => ()
            }
            i++
        }
        return
    }

    if (newMidLen == 0) {
        var i = oldMidLen - 1
        while (i >= 0) {
            let panelIdx = prefix + i
            match (r.childAt(parent, panelIdx)) {
                case Some(id) => r.unmount(id)
                case None => ()
            }
            r.removeChildTracked(parent, panelIdx)
            i--
        }
        return
    }

    reconcileKeyedMiddle(r, parent, old, neu, oldStart, oldMidLen, newStart, newMidLen, prefix)
}

func reconcileKeyedMiddle(r: Reconciler, parent: ControlId, old: Array<Element>, neu: Array<Element>,
                          oldStart: Int64, oldMidLen: Int64, newStart: Int64, newMidLen: Int64,
                          prefix: Int64): Unit {
    // Build old-key -> relative position map.
    let oldKeyMap = HashMap<String, Int64>()
    var i = 0
    while (i < oldMidLen) {
        let el = old[oldStart + i]
        oldKeyMap.add(effectiveKey(el, oldStart + i), i)
        i++
    }

    // Map each new element to a matched old relative position (-1 = new).
    let newToOld = Array<Int64>(newMidLen, repeat: -1)
    let matched = Array<Bool>(oldMidLen, repeat: false)
    i = 0
    while (i < newMidLen) {
        let el = neu[newStart + i]
        let key = effectiveKey(el, newStart + i)
        match (oldKeyMap.get(key)) {
            case Some(oldRel) =>
                let oldEl = old[oldStart + oldRel]
                if (oldEl.canUpdate(el)) {
                    newToOld[i] = oldRel
                    matched[oldRel] = true
                }
            case None => ()
        }
        i++
    }

    let lis = computeLis(newToOld)

    // Reverse-order unmount of unmatched old nodes.
    i = oldMidLen - 1
    while (i >= 0) {
        if (!matched[i]) {
            let panelIdx = prefix + i
            match (r.childAt(parent, panelIdx)) {
                case Some(id) => r.unmount(id)
                case None => ()
            }
            r.removeChildTracked(parent, panelIdx)
        }
        i--
    }

    // Build key -> current panel slot for the surviving (matched) old nodes.
    let keyToPanel = HashMap<String, Int64>()
    var panelIdx = prefix
    i = 0
    while (i < oldMidLen) {
        if (matched[i]) {
            let key = effectiveKey(old[oldStart + i], oldStart + i)
            keyToPanel.add(key, panelIdx)
            panelIdx++
        }
        i++
    }

    // Left -> right over the new middle.
    i = 0
    while (i < newMidLen) {
        let targetPanelIdx = prefix + i
        let newEl = neu[newStart + i]

        if (newToOld[i] == -1) {
            match (r.mount(newEl)) {
                case Some(ctrl) =>
                    r.insertChildTracked(parent, targetPanelIdx, ctrl)
                    shiftPanelMapOnInsert(keyToPanel, targetPanelIdx)
                case None => ()
            }
        } else if (lis.contains(i)) {
            // LIS items don't move, but earlier non-LIS moves may have shifted
            // them to a different actual slot. Use keyToPanel for the current
            // position (NOT targetPanelIdx) so we update the right control.
            let oldRel = newToOld[i]
            let oldEl = old[oldStart + oldRel]
            let key = effectiveKey(oldEl, oldStart + oldRel)
            let actualPos = keyToPanel.get(key).getOrThrow()
            if (r.childAt(parent, actualPos).isSome()) {
                if (canSkipUpdate(oldEl, newEl)) {
                    let stateDirty = match (r.childAt(parent, actualPos)) {
                        case Some(cid) => r.isComponentStateDirty(cid)
                        case None => false
                    }
                    if (stateDirty) {
                        updateChildTracked(r, parent, actualPos, oldEl, newEl)
                    } else {
                        r.debugElementsSkipped++
                    }
                } else {
                    updateChildTracked(r, parent, actualPos, oldEl, newEl)
                }
            }
        } else {
            let oldRel = newToOld[i]
            let oldEl = old[oldStart + oldRel]
            let key = effectiveKey(oldEl, oldStart + oldRel)
            let currentPos = keyToPanel.get(key).getOrThrow()
            if (currentPos != targetPanelIdx) {
                r.moveChildTracked(parent, currentPos, targetPanelIdx)
                shiftPanelMapOnMove(keyToPanel, currentPos, targetPanelIdx)
            }
            if (r.childAt(parent, targetPanelIdx).isSome()) {
                if (canSkipUpdate(oldEl, newEl)) {
                    let stateDirty = match (r.childAt(parent, targetPanelIdx)) {
                        case Some(cid) => r.isComponentStateDirty(cid)
                        case None => false
                    }
                    if (stateDirty) {
                        updateChildTracked(r, parent, targetPanelIdx, oldEl, newEl)
                    } else {
                        r.debugElementsSkipped++
                    }
                } else {
                    updateChildTracked(r, parent, targetPanelIdx, oldEl, newEl)
                }
            }
        }
        i++
    }
}

// Bump every panel slot >= insertion point (a fresh control was inserted there).
func shiftPanelMapOnInsert(keyToPanel: HashMap<String, Int64>, targetPanelIdx: Int64): Unit {
    let keys = ArrayList<String>()
    for ((k, _) in keyToPanel) { keys.add(k) }
    for (k in keys) {
        let v = keyToPanel.get(k).getOrThrow()
        if (v >= targetPanelIdx) { keyToPanel.add(k, v + 1) }
    }
}

// Re-thread panel slots after moving the control at currentPos to targetPanelIdx.
func shiftPanelMapOnMove(keyToPanel: HashMap<String, Int64>, currentPos: Int64, targetPanelIdx: Int64): Unit {
    let keys = ArrayList<String>()
    for ((k, _) in keyToPanel) { keys.add(k) }
    for (k in keys) {
        let v = keyToPanel.get(k).getOrThrow()
        if (v == currentPos) {
            keyToPanel.add(k, targetPanelIdx)
        } else if (currentPos < targetPanelIdx && v > currentPos && v <= targetPanelIdx) {
            keyToPanel.add(k, v - 1)
        } else if (currentPos > targetPanelIdx && v >= targetPanelIdx && v < currentPos) {
            keyToPanel.add(k, v + 1)
        }
    }
}

// computeLis — patience sorting + binary search, O(n log n). Returns the SET of
// new indices that belong to a longest increasing subsequence of `arr`
// (ignoring -1 entries = freshly-mounted nodes that need no move). The returned
// indices identify elements that do NOT need to be moved.
func computeLis(arr: Array<Int64>): HashSet<Int64> {
    let result = HashSet<Int64>()
    let n = arr.size
    if (n == 0) { return result }

    let tails = ArrayList<Int64>()      // smallest possible tail value per length
    let tailIdx = ArrayList<Int64>()    // index in arr achieving that tail
    let pred = Array<Int64>(n, repeat: -1)

    var i = 0
    while (i < n) {
        let val = arr[i]
        if (val == -1) {
            i++
            continue
        }
        // Lower-bound binary search for the first tail >= val.
        var lo = 0
        var hi = tails.size
        while (lo < hi) {
            let mid = (lo + hi) / 2
            if (tails[mid] < val) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        if (lo == tails.size) {
            tails.add(val)
            tailIdx.add(i)
        } else {
            tails[lo] = val
            tailIdx[lo] = i
        }
        if (lo > 0) {
            pred[i] = tailIdx[lo - 1]
        }
        i++
    }

    if (tailIdx.size == 0) { return result }
    var idx = tailIdx[tailIdx.size - 1]
    while (idx != -1) {
        result.add(idx)
        idx = pred[idx]
    }
    result
}

func saturatingSub(a: Int64, b: Int64): Int64 {
    if (a < b) { 0 } else { a - b }
}
