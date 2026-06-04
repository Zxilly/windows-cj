package windows_reactor.core

import std.collection.*

// ============================================================================
// Widget dispatch — mount/update a Widget into backend ops. Reference:
// reconciler/widget_dispatch.rs. Free functions over the Reconciler (the
// reference's `impl Reconciler` methods can't be split onto the class body in
// Cangjie). Attached props (canvas / relative panel / grid) are folded into
// Modifiers in this port, so they are applied by applyModifiers / diffModifiers
// rather than a separate attached() accessor.
// ============================================================================

func mountWidget(r: Reconciler, w: Widget): ControlId {
    let id = r.acquireControl(w.kind())
    applyProps(r.backend, id, w.bindings())
    r.applyModifiers(id, w.modifiers())
    mountWidgetChildren(r, id, w.children())
    match (w.headerElement()) {
        case Some(hdr) =>
            match (r.mount(hdr)) {
                case Some(hdrId) =>
                    r.backend.setHeaderElement(id, Some(hdrId))
                    r.headerElements.add(id, hdrId)
                case None => ()
            }
        case None => ()
    }
    match (w.paneElement()) {
        case Some(pane) =>
            match (r.mount(pane)) {
                case Some(paneId) =>
                    r.backend.setPaneElement(id, Some(paneId))
                    r.paneElements.add(id, paneId)
                case None => ()
            }
        case None => ()
    }
    // On-mounted native-element callback (mirrors the reference mount path that
    // invokes Widget::on_mounted_callback with the backend's native element).
    // Fires once after the control + its subtree exist, handing the control's
    // opaque NativeElement token to user code (used by SwapChainPanel to attach
    // a native swap chain). Only widgets that override onMountedCallback (i.e.
    // return Some) incur any work; for every other widget this is a no-op.
    match (w.onMountedCallback()) {
        case Some(cb) =>
            match (r.backend.getNativeElement(id)) {
                case Some(native) => cb.invoke(native)
                case None => ()
            }
        case None => ()
    }
    id
}

func updateWidget(r: Reconciler, old: Widget, neu: Widget, id: ControlId): Unit {
    diffProps(r.backend, id, old.bindings(), neu.bindings())
    r.diffModifiers(id, old.modifiers(), neu.modifiers())
    updateWidgetChildren(r, id, old.children(), neu.children())
    updateHeaderElement(r, id, old.headerElement(), neu.headerElement())
    updatePaneElement(r, id, old.paneElement(), neu.paneElement())
}

func mountWidgetChildren(r: Reconciler, id: ControlId, children: Children): Unit {
    match (children) {
        case NoneCh => ()
        case PositionalSingle(child) =>
            match (r.mount(child)) {
                case Some(childId) => r.appendChildTracked(id, childId)
                case None => ()
            }
        case Keyed(list) =>
            for (child in collectLive(list)) {
                match (r.mount(child)) {
                    case Some(childId) => r.appendChildTracked(id, childId)
                    case None => ()
                }
            }
        case Tabs(tabs) =>
            for (tab in tabs) { mountTabItem(r, id, tab) }
        case PivotItems(items) =>
            for (item in items) { mountPivotItem(r, id, item) }
    }
}

func updateWidgetChildren(r: Reconciler, id: ControlId, old: Children, neu: Children): Unit {
    match ((old, neu)) {
        case (NoneCh, NoneCh) => ()
        case (PositionalSingle(o), PositionalSingle(n)) =>
            r.reconcileChildrenPositional(id, [o], [n])
        case (Keyed(o), Keyed(n)) =>
            r.reconcileChildren(id, o, n)
        case (Tabs(o), Tabs(n)) =>
            reconcileTabs(r, id, o, n)
        case (PivotItems(o), PivotItems(n)) =>
            reconcilePivotItems(r, id, o, n)
        case _ =>
            // child-layout shape changed across update — the reference asserts;
            // we silently no-op (a widget never changes its Children shape).
            ()
    }
}

func updateHeaderElement(r: Reconciler, id: ControlId, old: ?Element, neu: ?Element): Unit {
    match ((old, neu)) {
        case (None, None) => ()
        case (None, Some(hdr)) =>
            match (r.mount(hdr)) {
                case Some(hdrId) =>
                    r.backend.setHeaderElement(id, Some(hdrId))
                    r.headerElements.add(id, hdrId)
                case None => ()
            }
        case (Some(_), None) =>
            match (r.headerElements.get(id)) {
                case Some(hdrId) =>
                    r.headerElements.remove(id)
                    r.backend.setHeaderElement(id, Option<ControlId>.None)
                    r.unmount(hdrId)
                case None => ()
            }
        case (Some(oldEl), Some(newEl)) =>
            match (r.headerElements.get(id)) {
                case Some(hdrId) =>
                    if (oldEl.kindMatches(newEl)) {
                        match (r.update(oldEl, newEl, hdrId)) {
                            case Some(nid) where nid != hdrId =>
                                r.backend.setHeaderElement(id, Some(nid))
                                r.headerElements.add(id, nid)
                            case None =>
                                r.backend.setHeaderElement(id, Option<ControlId>.None)
                                r.headerElements.remove(id)
                            case _ => ()
                        }
                        return
                    }
                    r.headerElements.remove(id)
                    r.unmount(hdrId)
                case None => ()
            }
            match (r.mount(newEl)) {
                case Some(hdrId) =>
                    r.backend.setHeaderElement(id, Some(hdrId))
                    r.headerElements.add(id, hdrId)
                case None => ()
            }
    }
}

func updatePaneElement(r: Reconciler, id: ControlId, old: ?Element, neu: ?Element): Unit {
    match ((old, neu)) {
        case (None, None) => ()
        case (None, Some(pane)) =>
            match (r.mount(pane)) {
                case Some(paneId) =>
                    r.backend.setPaneElement(id, Some(paneId))
                    r.paneElements.add(id, paneId)
                case None => ()
            }
        case (Some(_), None) =>
            match (r.paneElements.get(id)) {
                case Some(paneId) =>
                    r.paneElements.remove(id)
                    r.backend.setPaneElement(id, Option<ControlId>.None)
                    r.unmount(paneId)
                case None => ()
            }
        case (Some(oldEl), Some(newEl)) =>
            match (r.paneElements.get(id)) {
                case Some(paneId) =>
                    if (oldEl.kindMatches(newEl)) {
                        match (r.update(oldEl, newEl, paneId)) {
                            case Some(nid) where nid != paneId =>
                                r.backend.setPaneElement(id, Some(nid))
                                r.paneElements.add(id, nid)
                            case None =>
                                r.backend.setPaneElement(id, Option<ControlId>.None)
                                r.paneElements.remove(id)
                            case _ => ()
                        }
                        return
                    }
                    r.paneElements.remove(id)
                    r.unmount(paneId)
                case None => ()
            }
            match (r.mount(newEl)) {
                case Some(paneId) =>
                    r.backend.setPaneElement(id, Some(paneId))
                    r.paneElements.add(id, paneId)
                case None => ()
            }
    }
}

// ── Tab / Pivot child management ────────────────────────────────────────────

func mountTabItem(r: Reconciler, parent: ControlId, tab: TabItem): Unit {
    let tabId = r.acquireControl(ControlKind.TabViewItem)
    r.backend.setProp(tabId, Prop.TabHeader, PropValue.Str(tab.header))
    match (tab.key) {
        case Some(k) => r.backend.setProp(tabId, Prop.TabItemKey, PropValue.Str(k))
        case None => ()
    }
    match (tab.isClosable) {
        case Some(closable) => r.backend.setProp(tabId, Prop.IsClosable, PropValue.BoolV(closable))
        case None => ()
    }
    match (r.mount(tab.content)) {
        case Some(contentId) => r.appendChildTracked(tabId, contentId)
        case None => ()
    }
    r.appendChildTracked(parent, tabId)
}

func mountPivotItem(r: Reconciler, parent: ControlId, item: PivotItem): Unit {
    let itemId = r.acquireControl(ControlKind.PivotItem)
    r.backend.setProp(itemId, Prop.PivotItemHeader, PropValue.Str(item.header))
    match (r.mount(item.content)) {
        case Some(contentId) => r.appendChildTracked(itemId, contentId)
        case None => ()
    }
    r.appendChildTracked(parent, itemId)
}

func reconcileTabs(r: Reconciler, parent: ControlId, old: Array<TabItem>, neu: Array<TabItem>): Unit {
    let common = minI64(old.size, neu.size)
    var i = 0
    while (i < common) {
        match (r.childAt(parent, i)) {
            case Some(tabId) =>
                let o = old[i]
                let n = neu[i]
                if (o.header != n.header) {
                    r.backend.setProp(tabId, Prop.TabHeader, PropValue.Str(n.header))
                }
                if (!optStrEq(o.key, n.key)) {
                    match (n.key) {
                        case Some(k) => r.backend.setProp(tabId, Prop.TabItemKey, PropValue.Str(k))
                        case None => ()
                    }
                }
                if (!optBoolEq(o.isClosable, n.isClosable)) {
                    let v = match (n.isClosable) { case Some(c) => c; case None => true }
                    r.backend.setProp(tabId, Prop.IsClosable, PropValue.BoolV(v))
                }
                r.reconcileChildrenPositional(tabId, [o.content], [n.content])
            case None => ()
        }
        i++
    }

    if (neu.size > old.size) {
        var j = old.size
        while (j < neu.size) {
            mountTabItem(r, parent, neu[j])
            j++
        }
    }

    while (r.childAt(parent, neu.size).isSome()) {
        let extraId = r.childAt(parent, neu.size).getOrThrow()
        r.removeChildTracked(parent, neu.size)
        r.unmount(extraId)
    }
}

func reconcilePivotItems(r: Reconciler, parent: ControlId, old: Array<PivotItem>, neu: Array<PivotItem>): Unit {
    let common = minI64(old.size, neu.size)
    var i = 0
    while (i < common) {
        match (r.childAt(parent, i)) {
            case Some(itemId) =>
                let o = old[i]
                let n = neu[i]
                if (o.header != n.header) {
                    r.backend.setProp(itemId, Prop.PivotItemHeader, PropValue.Str(n.header))
                }
                r.reconcileChildrenPositional(itemId, [o.content], [n.content])
            case None => ()
        }
        i++
    }

    if (neu.size > old.size) {
        var j = old.size
        while (j < neu.size) {
            mountPivotItem(r, parent, neu[j])
            j++
        }
    }

    while (r.childAt(parent, neu.size).isSome()) {
        let extraId = r.childAt(parent, neu.size).getOrThrow()
        r.removeChildTracked(parent, neu.size)
        r.unmount(extraId)
    }
}

func minI64(a: Int64, b: Int64): Int64 { if (a < b) { a } else { b } }
