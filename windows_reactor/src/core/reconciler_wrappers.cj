package windows_reactor.core

import std.collection.*

// ============================================================================
// Composition-node wrappers — Component / ErrorBoundary / Provider / Custom.
// Reference: reconciler/wrappers.rs. Free functions over the Reconciler.
//
// Cross-team contract (Engines-B owns render_context.cj / component.cj /
// context.cj). The names below are the agreed surface this file is written
// against; the Integration phase reconciles any naming with Engines-B:
//   RenderCx(requestRerender) ; setContextStack/setMarshaller/setInnerSizeCell/
//     setDpiCell ; beginRender ; flushEffects ; runCleanups ; takeReadContexts ;
//     takeStateDirty
//   ComponentObject.render(cx)/isEquivalent(other)/shouldUpdate(other)/
//     componentTypeId() (Foundation) — Engines-B extends the Foundation
//     interface with render/isEquivalent/shouldUpdate/invoke*/hasOn*.
//   ComponentElement.memoised: Bool  (Engines-B adds to Foundation class)
//   ProviderElement.provisions: ArrayList<ContextProvision> (Engines-B widens
//     the Foundation single-contextId carrier; falls back to the single
//     contextId if provisions is unavailable — see note in mountProvider).
//   ContextStack.pushRawRetain(id, valueTypeId, value)/popRaw()
//   ContextProvision.contextId: ContextId ; valueTypeId ; equalsValue(other)
//   CustomElement.mount(backend)/update(prev,id,backend)/beforeDestroy(id,backend)
//     /eqDyn(other)/cloneDyn() (Engines-B/P3 extend the Foundation interface).
//
// The reference's catch_unwind error-boundary recovery is ported to try/catch:
// any Exception thrown during a child's render/mount/update is caught and the
// fallback element is mounted instead (panic -> Exception is an accepted
// paradigm difference, documented here).
// ============================================================================

func mountComponent(r: Reconciler, ce: ComponentElement): ?ControlId {
    let cx = RenderCx(r.requestRerender)
    cx.setContextStack(r.contextStackHandle())
    cx.setMarshaller(r.marshaller)
    cx.setInnerSizeCell(r.innerSize)
    cx.setDpiCell(r.dpi)
    cx.beginRender()
    let rendered = ce.obj.render(cx)
    cx.flushEffects()
    let readContexts = cx.takeReadContexts()

    match (r.mount(rendered)) {
        case Some(renderedId) =>
            r.registerComponentInstance(renderedId,
                ComponentInstance(cx, rendered, ce.obj, readContexts))
            Some(renderedId)
        case None => None
    }
}

func updateComponent(r: Reconciler, old: ComponentElement, neu: ComponentElement, id: ControlId): ?ControlId {
    if (old.obj.componentTypeId() != neu.obj.componentTypeId()) {
        r.unmount(id)
        return mountComponent(r, neu)
    }

    let forcedByContext = r.forcedComponents.contains(id)
    let stateDirty = match (r.componentInstances.get(id)) {
        case Some(inst) => inst.renderCx.takeStateDirty()
        case None => false
    }
    let needsUpdate = if (forcedByContext || stateDirty) {
        true
    } else if (neu.memoised) {
        !old.obj.isEquivalent(neu.obj)
    } else {
        old.obj.shouldUpdate(neu.obj)
    }

    if (!needsUpdate) {
        match (r.componentInstances.get(id)) {
            case Some(inst) => inst.lastObj = neu.obj
            case None => ()
        }
        return Some(id)
    }

    let inst = match (r.takeComponentInstance(id)) {
        case Some(x) => x
        case None => return mountComponent(r, neu)
    }

    inst.renderCx.setContextStack(r.contextStackHandle())
    inst.renderCx.setInnerSizeCell(r.innerSize)
    inst.renderCx.setDpiCell(r.dpi)
    inst.renderCx.beginRender()
    let rendered = neu.obj.render(inst.renderCx)
    inst.renderCx.flushEffects()
    inst.readContexts = inst.renderCx.takeReadContexts()

    let newId = r.update(inst.lastRendered, rendered, id)

    inst.lastRendered = rendered
    inst.lastObj = neu.obj

    match (newId) {
        case Some(nid) =>
            r.registerComponentInstance(nid, inst)
            Some(nid)
        case None =>
            inst.renderCx.deactivate()
            inst.renderCx.runCleanups()
            None
    }
}

func mountErrorBoundary(r: Reconciler, eb: ErrorBoundaryElement): ?ControlId {
    try {
        return r.mount(eb.child)
    } catch (e: Exception) {
        let msg = panicMessage(e)
        let fallback = eb.fallback(msg)
        let id = r.mount(fallback)
        match (id) {
            case Some(fid) => r.errorBoundaryFallbacks.add(fid)
            case None => ()
        }
        return id
    }
}

func updateErrorBoundary(r: Reconciler, old: ErrorBoundaryElement, neu: ErrorBoundaryElement, id: ControlId): ?ControlId {
    if (r.errorBoundaryFallbacks.contains(id)) {
        r.errorBoundaryFallbacks.remove(id)
        r.unmount(id)
        try {
            return r.mount(neu.child)
        } catch (e: Exception) {
            let msg = panicMessage(e)
            let fallback = neu.fallback(msg)
            let nid = r.mount(fallback)
            match (nid) {
                case Some(f) => r.errorBoundaryFallbacks.add(f)
                case None => ()
            }
            return nid
        }
    }

    try {
        return r.update(old.child, neu.child, id)
    } catch (e: Exception) {
        let msg = panicMessage(e)
        let fallback = neu.fallback(msg)
        r.unmount(id)
        let nid = r.mount(fallback)
        match (nid) {
            case Some(f) => r.errorBoundaryFallbacks.add(f)
            case None => ()
        }
        return nid
    }
}

func mountProvider(r: Reconciler, p: ProviderElement): ?ControlId {
    let pushed = pushProvisions(r, p)
    try {
        return r.mount(p.child)
    } finally {
        popProvisions(r, pushed)
    }
}

func updateProvider(r: Reconciler, old: ProviderElement, neu: ProviderElement, id: ControlId): ?ControlId {
    // Compute the set of context ids whose provided value changed (added,
    // removed, or value-differs) so dependent components are force-rerendered.
    let changedIds = HashSet<ContextId>()
    let oldById = HashMap<ContextId, ContextProvision>()
    for (pr in providerProvisions(old)) { oldById.add(pr.contextId, pr) }
    for (newP in providerProvisions(neu)) {
        match (oldById.get(newP.contextId)) {
            case None => changedIds.add(newP.contextId)
            case Some(oldP) =>
                if (!oldP.equalsValue(newP)) { changedIds.add(newP.contextId) }
                oldById.remove(newP.contextId)
        }
    }
    for ((leftover, _) in oldById) { changedIds.add(leftover) }

    let prevFlag = r.forceComponentRerender
    let savedForced = snapshotForced(r)
    if (changedIds.size > 0) {
        let affected = r.collectAffectedComponents(id, changedIds)
        if (affected.size > 0) {
            r.forceComponentRerender = true
            for (a in affected) { r.forcedComponents.add(a) }
        }
    }

    let pushed = pushProvisions(r, neu)
    var resultId: ?ControlId = None
    try {
        resultId = r.update(old.child, neu.child, id)
    } finally {
        popProvisions(r, pushed)
        restoreForced(r, savedForced)
        r.forceComponentRerender = prevFlag
    }
    resultId
}

func pushProvisions(r: Reconciler, p: ProviderElement): Int64 {
    let provisions = providerProvisions(p)
    for (pr in provisions) {
        r.contextStack.pushRawRetain(pr.contextId, pr.valueTypeId, pr.value)
    }
    provisions.size
}

func popProvisions(r: Reconciler, count: Int64): Unit {
    var i = 0
    while (i < count) {
        r.contextStack.popRaw()
        i++
    }
}

// Provider provisions accessor. Engines-B widens ProviderElement to carry an
// ArrayList<ContextProvision>; until then this returns its provisions list.
func providerProvisions(p: ProviderElement): Array<ContextProvision> {
    p.provisions.toArray()
}

func snapshotForced(r: Reconciler): Array<ControlId> {
    let out = ArrayList<ControlId>()
    for (c in r.forcedComponents) { out.add(c) }
    out.toArray()
}

func restoreForced(r: Reconciler, saved: Array<ControlId>): Unit {
    r.forcedComponents.clear()
    for (c in saved) { r.forcedComponents.add(c) }
}

func mountCustom(r: Reconciler, c: CustomElement): ControlId {
    r.debugUiElementsCreated++
    let id = c.mount(r.backend)
    r.customHandles.add(id, c.cloneDyn())
    id
}

func updateCustom(r: Reconciler, old: CustomElement, neu: CustomElement, id: ControlId): ControlId {
    // kindMatches already guaranteed same custom type id before reaching here.
    if (!old.eqDyn(neu)) {
        neu.update(old, id, r.backend)
        r.customHandles.add(id, neu.cloneDyn())
    }
    id
}
