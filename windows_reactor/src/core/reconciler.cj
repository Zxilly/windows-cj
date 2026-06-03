package windows_reactor.core

import std.collection.*

// ============================================================================
// Reconciler — diff/apply engine that drives a Backend from successive Element
// trees. Owns the bookkeeping needed to reuse controls across renders
// (children mirror, component instances, custom handles, templated-list state,
// header/pane element ids, …).
//
// Cangjie layout note: the reference splits the reconciler across six files via
// `impl Reconciler` blocks. Cangjie does NOT allow a class body to be split
// across files, and a parent package may not import its own subpackage (that
// would be a dependency cycle). So all reconciler member functions live on the
// single `Reconciler` class declared here, and the per-area logic is spread
// across flat sibling files in the same `windows_reactor.core` package:
//   reconciler_child.cj          — positional + keyed child diff + computeLis
//   reconciler_diff_helpers.cj   — diffOpt* / applyProps / diffProps (free fns)
//   reconciler_widget_dispatch.cj— mount/update widget, header/pane, tab/pivot
//   reconciler_wrappers.cj       — Component / ErrorBoundary / Provider / Custom
//   reconciler_templated.cj      — templated list mount/update + realize/recycle
// The methods declared on `Reconciler` in *this* file are the shared core
// (mount/update/unmount, tracked child ops, modifier apply/diff). The widget /
// wrappers / templated member functions are declared on the SAME class but the
// implementation bodies that the reference put in separate impl blocks are kept
// here too where they must be members; the standalone diff + child algorithms
// live as free functions in the sibling files (they take `Reconciler`).
//
// Integration contract (Engines-B owns render_context.cj / component.cj /
// context.cj — these names are the agreed cross-team surface):
//   class  RenderCx                      — hooks slot container (per component)
//     new(requestRerender: () -> Unit)
//     setContextStack(s: ContextStack); setMarshaller(m: ?UiMarshaller)
//     setInnerSizeCell(c: SizeCell); setDpiCell(c: DpiCell)
//     beginRender(); flushEffects(); runCleanups()
//     takeReadContexts(): HashSet<ContextId>
//     takeStateDirty(): Bool; peekStateDirty(): Bool
//   interface ComponentObject  (Foundation declares componentTypeId(); Engines-B
//     EXTENDS it with the following — same package, so the extended interface is
//     what ComponentElement.obj carries):
//       render(cx: RenderCx): Element
//       isEquivalent(other: ComponentObject): Bool
//       shouldUpdate(other: ComponentObject): Bool
//       invokeAppeared(cx: RenderCx): Unit
//       invokeDisappeared(cx: RenderCx): Unit
//       hasOnAppeared(): Bool; hasOnDisappeared(): Bool
//   class  ComponentElement                — Foundation declares key/obj;
//       Engines-B adds `memoised: Bool`.
//   class  ContextStack { new(); pushRawRetain(id, valueTypeId, value);
//       popRaw(); get<T>(id); depth() }
//   class  ContextProvision { contextId: ContextId; valueTypeId: UInt64;
//       value: Any-cell; equalsValue(other): Bool }   // ProviderElement carries
//       a list of these (Foundation's ProviderElement currently carries a single
//       contextId; Engines-B widens it to `provisions: ArrayList<ContextProvision>`).
//   class  UiMarshaller, SizeCell, DpiCell — Engines-C dispatcher/host types.
//   class  ContextId <: Hashable & Equatable<ContextId>
// CustomElement (Foundation interface) is extended by Engines-B/P3 with the
// imperative hooks: mount(backend), update(prev, id, backend),
// beforeDestroy(id, backend), eqDyn(other), cloneDyn().
// ============================================================================

// Per-component-instance state living across renders (the carrier of hooks).
public class ComponentInstance {
    public var renderCx: RenderCx
    public var lastRendered: Element
    public var lastObj: ComponentObject
    public var readContexts: HashSet<ContextId>

    public init(renderCx: RenderCx, lastRendered: Element, lastObj: ComponentObject,
                readContexts: HashSet<ContextId>) {
        this.renderCx = renderCx
        this.lastRendered = lastRendered
        this.lastObj = lastObj
        this.readContexts = readContexts
    }
}

// A realization request enqueued by a templated list's realize/recycle thunk and
// drained on the UI thread by drainRealizations(); carries the list id and row
// index. (The reference's Rc<RefCell<Vec<RealizationRequest>>> queue becomes the
// plain ArrayList field Reconciler.realizationQueue.)
public enum RealizationRequest {
    | RealizeReq(ControlId, Int64)
    | RecycleReq(ControlId, Int64)
}

// Thrown when an Element variant that cannot own a control reaches a single-child
// position (Group at a single-child slot, or update() with a real ControlId).
public class GroupPlacementException <: Exception {
    public init(msg: String) { super(msg) }
}

public class Reconciler {
    public var backend: Backend

    // Debug counters (mirror the reference's debug_* fields used by tests).
    public var debugElementsSkipped: Int64 = 0
    public var debugElementsDiffed: Int64 = 0
    public var debugUiElementsCreated: Int64 = 0

    // Parent -> ordered child ids. The single source of truth for child diffing.
    let childrenMirror = HashMap<ControlId, ArrayList<ControlId>>()
    let idKinds = HashMap<ControlId, ControlKind>()

    // Context stack shared with every nested RenderCx.
    var contextStack: ContextStack

    // Live component instances keyed by their rendered root control id.
    let componentInstances = HashMap<ControlId, ComponentInstance>()
    var appearedListenerCount: Int64 = 0
    var disappearedListenerCount: Int64 = 0

    // Context-forced re-render bookkeeping.
    var forceComponentRerender: Bool = false
    let forcedComponents = HashSet<ControlId>()
    let errorBoundaryFallbacks = HashSet<ControlId>()

    // Templated (virtualised) list state, custom handles, header / pane element
    // ids, and the realization queue (GC; no Rc<RefCell> needed).
    let templatedLists = HashMap<ControlId, TemplatedListState>()
    let customHandles = HashMap<ControlId, CustomElement>()
    let headerElements = HashMap<ControlId, ControlId>()
    let paneElements = HashMap<ControlId, ControlId>()
    // Selection trampolines so update can swap the inner callback without
    // re-attaching the backend handler.
    let selectionCallbacks = HashMap<ControlId, SelectionTrampoline>()

    public var eagerTemplatedRealization: Bool = false
    public var deferTemplatedUnmounts: Bool = false
    let deferredUnmounts = ArrayList<ControlId>()
    let realizationQueue = ArrayList<RealizationRequest>()

    // Propagated into nested RenderCx instances.
    var marshaller: ?UiMarshaller = None
    var innerSize: SizeCell
    var dpi: DpiCell
    // Rerender hook from the render host; cloned into each RenderCx.
    var requestRerender: () -> Unit

    public init(backend: Backend) {
        this.backend = backend
        this.contextStack = ContextStack()
        this.innerSize = SizeCell()
        this.dpi = DpiCell()
        this.requestRerender = { => () }
    }

    // ── Marshaller / cell installation (host wiring) ────────────────────────
    public func setMarshaller(m: ?UiMarshaller): Unit { this.marshaller = m }
    public func setInnerSizeCell(c: SizeCell): Unit { this.innerSize = c }
    public func setDpiCell(c: DpiCell): Unit { this.dpi = c }
    func contextStackHandle(): ContextStack { contextStack }

    public func flushDeferredUnmounts(): Unit {
        let drained = deferredUnmounts.toArray()
        deferredUnmounts.clear()
        for (cid in drained) { unmount(cid) }
    }

    // True when the component at `id` has dirty internal state since its last
    // render. Does NOT clear the flag (update_component consumes it).
    func isComponentStateDirty(id: ControlId): Bool {
        match (componentInstances.get(id)) {
            case Some(inst) => inst.renderCx.peekStateDirty()
            case None => false
        }
    }

    public func resetStats(): Unit {
        debugElementsSkipped = 0
        debugElementsDiffed = 0
        debugUiElementsCreated = 0
    }

    public func debugForcedComponentsLen(): Int64 { forcedComponents.size }
    public func debugAppearedListenerCount(): Int64 { appearedListenerCount }
    public func debugDisappearedListenerCount(): Int64 { disappearedListenerCount }

    // ── Control allocation + stale-state clearing ──────────────────────────
    func acquireControl(kind: ControlKind): ControlId {
        debugUiElementsCreated++
        let id = backend.create(kind)
        match (componentInstances.get(id)) {
            case Some(stale) =>
                stale.renderCx.deactivate()
                unregisterComponentListeners(stale)
                componentInstances.remove(id)
            case None => ()
        }
        templatedLists.remove(id)
        selectionCallbacks.remove(id)
        errorBoundaryFallbacks.remove(id)
        childrenMirror.remove(id)
        customHandles.remove(id)
        idKinds.add(id, kind)
        id
    }

    // ── Component-instance registry (tracks appeared/disappeared listeners) ──
    func registerComponentInstance(id: ControlId, inst: ComponentInstance): Unit {
        if (inst.lastObj.hasOnAppeared()) { appearedListenerCount++ }
        if (inst.lastObj.hasOnDisappeared()) { disappearedListenerCount++ }
        match (componentInstances.get(id)) {
            case Some(prev) =>
                prev.renderCx.deactivate()
                unregisterComponentListeners(prev)
            case None => ()
        }
        componentInstances.add(id, inst)
    }

    func takeComponentInstance(id: ControlId): ?ComponentInstance {
        match (componentInstances.get(id)) {
            case Some(inst) =>
                unregisterComponentListeners(inst)
                componentInstances.remove(id)
                Some(inst)
            case None => None
        }
    }

    func unregisterComponentListeners(inst: ComponentInstance): Unit {
        if (inst.lastObj.hasOnAppeared()) {
            if (appearedListenerCount > 0) { appearedListenerCount-- }
        }
        if (inst.lastObj.hasOnDisappeared()) {
            if (disappearedListenerCount > 0) { disappearedListenerCount-- }
        }
    }

    // ── Top-level entry ─────────────────────────────────────────────────────
    public func reconcile(old: ?Element, neu: Element, existing: ?ControlId,
                          requestRerender: () -> Unit): ?ControlId {
        this.requestRerender = requestRerender
        match ((existing, old)) {
            case (None, _) => mount(neu)
            case (Some(id), Some(oldEl)) => update(oldEl, neu, id)
            case (Some(_), None) => mount(neu)
        }
    }

    public func mount(el: Element): ?ControlId {
        match (el) {
            case ComponentEl(ce) => return mountComponent(this, ce)
            case ErrorBoundaryEl(eb) => return mountErrorBoundary(this, eb)
            case ProviderEl(pe) => return mountProvider(this, pe)
            case TemplatedListEl(tl) => return Some(mountTemplatedList(this, tl))
            case CustomEl(c) => return Some(mountCustom(this, c))
            case GroupEl(_) =>
                throw GroupPlacementException(
                    "Element.GroupEl can only appear inside a multi-child container's child list. " +
                    "A Group at a single-child position is not supported. Wrap it in a StackPanel, " +
                    "or place it directly inside a StackPanel/Grid that owns it as one of many children.")
            case EmptyEl => return None
            case _ => ()
        }
        let widget = match (el.asWidget()) {
            case Some(w) => w
            case None => throw GroupPlacementException("mount: non-widget Element reached widget path")
        }
        let id = mountWidget(this, widget)
        // RichTextBlock paragraph/inline content is not a normal prop binding; it
        // is applied through the dedicated backend.setRichTextParagraphs path once
        // the control exists (mirrors the reference mount, reconciler.rs:239-242).
        match (el) {
            case RichTextBlockEl(rt) =>
                if (rt.paragraphs.size > 0) {
                    this.backend.setRichTextParagraphs(id, rt.paragraphs)
                }
            case _ => ()
        }
        Some(id)
    }

    public func update(old: Element, neu: Element, id: ControlId): ?ControlId {
        if (!forceComponentRerender && canSkipUpdate(old, neu)) {
            // A component with dirty internal state must still re-render even
            // when its element is structurally identical.
            if (!isComponentStateDirty(id)) {
                debugElementsSkipped++
                return Some(id)
            }
        }
        debugElementsDiffed++

        if (!old.kindMatches(neu)) {
            unmount(id)
            return mount(neu)
        }

        match ((old, neu)) {
            case (ComponentEl(o), ComponentEl(n)) => return updateComponent(this, o, n, id)
            case (ErrorBoundaryEl(o), ErrorBoundaryEl(n)) => return updateErrorBoundary(this, o, n, id)
            case (ProviderEl(o), ProviderEl(n)) => return updateProvider(this, o, n, id)
            case (TemplatedListEl(o), TemplatedListEl(n)) =>
                updateTemplatedList(this, o, n, id)
                return Some(id)
            case (CustomEl(o), CustomEl(n)) => return Some(updateCustom(this, o, n, id))
            case (GroupEl(_), GroupEl(_)) =>
                throw GroupPlacementException(
                    "Element.GroupEl reached update() with a ControlId. Group is a fragment and " +
                    "cannot own a control. This usually means a Group was placed at a single-child position.")
            case (EmptyEl, EmptyEl) => return None
            case _ => ()
        }

        match ((old.asWidget(), neu.asWidget())) {
            case (Some(ow), Some(nw)) => updateWidget(this, ow, nw, id)
            case _ =>
                throw GroupPlacementException(
                    "update: kindMatches guaranteed same variant; non-widget variants handled above")
        }
        // RichTextBlock paragraph content is re-applied through its dedicated
        // backend path when it differs (mirrors the reference update,
        // reconciler.rs:298-301).
        match ((old, neu)) {
            case (RichTextBlockEl(o), RichTextBlockEl(n)) =>
                if (!arrayEq<RichTextParagraph>(o.paragraphs, n.paragraphs)) {
                    this.backend.setRichTextParagraphs(id, n.paragraphs)
                }
            case _ => ()
        }
        Some(id)
    }

    // ── Unmount + subtree collection (reverse-order teardown) ───────────────
    public func unmount(id: ControlId): Unit {
        let toRelease = ArrayList<ControlId>()
        collectSubtree(id, toRelease)
        for (node in toRelease) {
            match (componentInstances.get(node)) {
                case Some(inst) => inst.renderCx.deactivate()
                case None => ()
            }
        }
        var i = toRelease.size - 1
        while (i >= 0) {
            let node = toRelease[i]
            // 1. component cleanup (effects must run here; GC does not do it).
            match (takeComponentInstance(node)) {
                case Some(inst) => inst.renderCx.runCleanups()
                case None => ()
            }
            // 2. recursively unmount realized templated rows.
            match (templatedLists.get(node)) {
                case Some(state) =>
                    templatedLists.remove(node)
                    for (row in state.rows) {
                        match (row) {
                            case Some(r) => unmount(r.contentId)
                            case None => ()
                        }
                    }
                case None => ()
            }
            // 3. unmount header/pane element subtrees tracked outside
            //    childrenMirror (mounted via header_element / pane_element on
            //    NavigationView/SplitView etc.). collectSubtree never reaches
            //    them, so without this they (and every native control + handle
            //    they own) leak on every unmount — the residual per-navigation
            //    handle growth in the gallery. remove() returns the removed
            //    value, so match on it directly.
            match (headerElements.remove(node)) {
                case Some(hdrId) => unmount(hdrId)
                case None => ()
            }
            match (paneElements.remove(node)) {
                case Some(paneId) => unmount(paneId)
                case None => ()
            }
            // 4. selection trampoline / error-boundary marker.
            selectionCallbacks.remove(node)
            errorBoundaryFallbacks.remove(node)
            // 5. custom element teardown hook before destroy.
            match (customHandles.get(node)) {
                case Some(handle) =>
                    customHandles.remove(node)
                    handle.beforeDestroy(node, backend)
                case None => ()
            }
            // 6. mirror / kind cleanup + backend destroy.
            childrenMirror.remove(node)
            idKinds.remove(node)
            backend.destroy(node)
            i--
        }
    }

    // DFS using an ArrayList as a stack; out ends up in pre-order so unmount can
    // walk it in reverse for leaf-first teardown.
    func collectSubtree(id: ControlId, out: ArrayList<ControlId>): Unit {
        let stack = ArrayList<ControlId>()
        stack.add(id)
        while (stack.size > 0) {
            let node = stack.remove(at: stack.size - 1)
            out.add(node)
            match (childrenMirror.get(node)) {
                case Some(children) =>
                    var j = children.size - 1
                    while (j >= 0) {
                        stack.add(children[j])
                        j--
                    }
                case None => ()
            }
        }
    }

    func collectSubtreeIds(id: ControlId): Array<ControlId> {
        let out = ArrayList<ControlId>()
        collectSubtree(id, out)
        out.toArray()
    }

    // ── Tracked child operations (mirror is updated before backend call) ────
    func appendChildTracked(parent: ControlId, child: ControlId): Unit {
        childListMut(parent).add(child)
        backend.appendChild(parent, child)
    }

    func removeChildTracked(parent: ControlId, index: Int64): Unit {
        match (childrenMirror.get(parent)) {
            case Some(list) => if (index >= 0 && index < list.size) { list.remove(at: index) }
            case None => ()
        }
        backend.removeChild(parent, index)
    }

    func replaceChildTracked(parent: ControlId, index: Int64, newChild: ControlId): Unit {
        match (childrenMirror.get(parent)) {
            case Some(list) => if (index >= 0 && index < list.size) { list[index] = newChild }
            case None => ()
        }
        backend.replaceChild(parent, index, newChild)
    }

    func moveChildTracked(parent: ControlId, from: Int64, to: Int64): Unit {
        if (from == to) { return }
        match (childrenMirror.get(parent)) {
            case Some(list) =>
                if (from >= 0 && from < list.size && to >= 0 && to < list.size) {
                    let item = list.remove(at: from)
                    list.add(item, at: to)
                }
            case None => ()
        }
        backend.moveChild(parent, from, to)
    }

    func insertChildTracked(parent: ControlId, index: Int64, child: ControlId): Unit {
        let list = childListMut(parent)
        var clamped = index
        if (clamped > list.size) { clamped = list.size }
        if (clamped < 0) { clamped = 0 }
        list.add(child, at: clamped)
        backend.insertChild(parent, clamped, child)
    }

    func childAt(parent: ControlId, i: Int64): ?ControlId {
        match (childrenMirror.get(parent)) {
            case Some(list) => if (i >= 0 && i < list.size) { Some(list[i]) } else { None }
            case None => None
        }
    }

    func childListMut(parent: ControlId): ArrayList<ControlId> {
        match (childrenMirror.get(parent)) {
            case Some(list) => list
            case None =>
                let list = ArrayList<ControlId>()
                childrenMirror.add(parent, list)
                list
        }
    }

    func mirrorLen(parent: ControlId): Int64 {
        match (childrenMirror.get(parent)) {
            case Some(list) => list.size
            case None => 0
        }
    }

    // ── Modifier application + diff ─────────────────────────────────────────
    func applyModifiers(id: ControlId, mods: Modifiers): Unit {
        if (mods.isEmpty()) { return }
        match (mods.margin) { case Some(v) => backend.setProp(id, Prop.Margin, PropValue.ThicknessV(v)); case None => () }
        match (mods.padding) { case Some(v) => backend.setProp(id, Prop.Padding, PropValue.ThicknessV(v)); case None => () }
        match (mods.width) { case Some(v) => backend.setProp(id, Prop.Width, PropValue.F64(v)); case None => () }
        match (mods.height) { case Some(v) => backend.setProp(id, Prop.Height, PropValue.F64(v)); case None => () }
        match (mods.minWidth) { case Some(v) => backend.setProp(id, Prop.MinWidth, PropValue.F64(v)); case None => () }
        match (mods.maxWidth) { case Some(v) => backend.setProp(id, Prop.MaxWidth, PropValue.F64(v)); case None => () }
        match (mods.minHeight) { case Some(v) => backend.setProp(id, Prop.MinHeight, PropValue.F64(v)); case None => () }
        match (mods.maxHeight) { case Some(v) => backend.setProp(id, Prop.MaxHeight, PropValue.F64(v)); case None => () }
        match (mods.horizontalAlignment) { case Some(v) => backend.setProp(id, Prop.HorizontalAlignment, PropValue.HAlign(v)); case None => () }
        match (mods.verticalAlignment) { case Some(v) => backend.setProp(id, Prop.VerticalAlignment, PropValue.VAlign(v)); case None => () }
        match (mods.opacity) { case Some(v) => backend.setProp(id, Prop.Opacity, PropValue.F64(v)); case None => () }
        match (mods.background) { case Some(v) => backend.setProp(id, Prop.Background, PropValue.BrushV(v)); case None => () }
        match (mods.foreground) { case Some(v) => backend.setProp(id, Prop.Foreground, PropValue.BrushV(v)); case None => () }
        match (mods.fontFamily) { case Some(v) => backend.setProp(id, Prop.FontFamily, PropValue.Str(v)); case None => () }
        match (mods.fontSize) { case Some(v) => backend.setProp(id, Prop.FontSize, PropValue.F64(v)); case None => () }

        applyThemeBindingsFor(id, mods)
        applyAnimationsFor(id, mods)
        applyAccessibilityFor(id, mods)
        applyKeyboardAcceleratorsFor(id, mods)
        applyTooltipFor(id, mods)
        applyPointerHandlersFor(id, mods)

        match (mods.grid) { case Some(p) => applyGridPlacement(id, p); case None => () }
        match (mods.canvasPosition) { case Some(p) => applyCanvasPosition(id, p); case None => () }
        match (mods.relativeAlign) { case Some(p) => applyRelativePanelAlignment(id, p); case None => () }

        match (mods.resources) {
            case Some(res) =>
                if (res.size > 0) { backend.setProp(id, Prop.Resources, PropValue.ResourcesV(cloneStrMap(res))) }
            case None => ()
        }
    }

    func applyTooltipFor(id: ControlId, mods: Modifiers): Unit {
        match (mods.tooltip) {
            case Some(tt) => backend.setTooltip(id, Some(tt))
            case None => ()
        }
    }

    func applyPointerHandlersFor(id: ControlId, mods: Modifiers): Unit {
        match (mods.pointerHandlers) {
            case Some(ph) => if (!ph.isEmpty()) { backend.setPointerHandlers(id, Some(ph)) }
            case None => ()
        }
    }

    func applyAccessibilityFor(id: ControlId, mods: Modifiers): Unit {
        match (mods.accessibility) {
            case Some(acc) => if (!acc.isEmpty()) { backend.setAccessibility(id, acc) }
            case None => ()
        }
    }

    func applyKeyboardAcceleratorsFor(id: ControlId, mods: Modifiers): Unit {
        match (mods.keyboardAccelerators) {
            case Some(list) => if (list.size > 0) { backend.setKeyboardAccelerators(id, list.toArray()) }
            case None => ()
        }
    }

    func applyAnimationsFor(id: ControlId, mods: Modifiers): Unit {
        match (mods.animations) {
            case Some(anim) =>
                if (anim.isEmpty()) { return }
                match (anim.implicitTransitions) {
                    case Some(trans) => if (!trans.isEmpty()) { backend.setImplicitTransitions(id, Some(trans)) }
                    case None => ()
                }
                match (anim.layoutAnimation) {
                    case Some(la) => backend.setLayoutAnimation(id, Some(la))
                    case None => ()
                }
                match (anim.propertyAnimation) {
                    case Some(p) => backend.runPropertyAnimation(id, Some(p))
                    case None =>
                        match (anim.enterTransition) {
                            case Some(enter) => backend.runPropertyAnimation(id, Some(enter))
                            case None => ()
                        }
                }
            case None => ()
        }
    }

    func diffAnimationsFor(id: ControlId, old: ?AnimationModifiers, neu: ?AnimationModifiers): Unit {
        let oldIt = optAnimImplicit(old)
        let newIt = optAnimImplicit(neu)
        if (!optAnimTransEq(oldIt, newIt)) {
            backend.setImplicitTransitions(id, filterNonEmptyTransitions(newIt))
        }
        let oldLa = optAnimLayout(old)
        let newLa = optAnimLayout(neu)
        if (!optLayoutEq(oldLa, newLa)) {
            backend.setLayoutAnimation(id, newLa)
        }
        let oldPa = optAnimProperty(old)
        let newPa = optAnimProperty(neu)
        if (!optAnimCfgEq(oldPa, newPa)) {
            backend.runPropertyAnimation(id, newPa)
        }
    }

    func applyThemeBindingsFor(id: ControlId, mods: Modifiers): Unit {
        match (mods.themeBindings) {
            case Some(map) =>
                if (map.size == 0) { return }
                let kind = match (idKinds.get(id)) {
                    case Some(k) => k
                    case None => return
                }
                backend.setThemeBindings(id, kind, themeBindingArray(map))
            case None => ()
        }
    }

    func diffModifiers(id: ControlId, old: Modifiers, neu: Modifiers): Unit {
        diffOptThickness(backend, id, Prop.Margin, old.margin, neu.margin)
        diffOptThickness(backend, id, Prop.Padding, old.padding, neu.padding)
        diffOptF64(backend, id, Prop.Width, old.width, neu.width)
        diffOptF64(backend, id, Prop.Height, old.height, neu.height)
        diffOptF64(backend, id, Prop.MinWidth, old.minWidth, neu.minWidth)
        diffOptF64(backend, id, Prop.MaxWidth, old.maxWidth, neu.maxWidth)
        diffOptF64(backend, id, Prop.MinHeight, old.minHeight, neu.minHeight)
        diffOptF64(backend, id, Prop.MaxHeight, old.maxHeight, neu.maxHeight)
        diffOptHAlign(backend, id, Prop.HorizontalAlignment, old.horizontalAlignment, neu.horizontalAlignment)
        diffOptVAlign(backend, id, Prop.VerticalAlignment, old.verticalAlignment, neu.verticalAlignment)
        diffOptF64(backend, id, Prop.Opacity, old.opacity, neu.opacity)
        diffOptBrush(backend, id, Prop.Background, old.background, neu.background)
        diffOptBrush(backend, id, Prop.Foreground, old.foreground, neu.foreground)
        diffOptStr(backend, id, Prop.FontFamily, old.fontFamily, neu.fontFamily)
        diffOptF64(backend, id, Prop.FontSize, old.fontSize, neu.fontSize)

        // Theme bindings.
        if (!themeBindingsEq(old.themeBindings, neu.themeBindings)) {
            match (idKinds.get(id)) {
                case Some(kind) =>
                    let arr = match (neu.themeBindings) {
                        case Some(m) => themeBindingArray(m)
                        case None => Array<(Prop, ThemeRef)>()
                    }
                    backend.setThemeBindings(id, kind, arr)
                case None => ()
            }
        }

        // Animations.
        if (!animsEq(old.animations, neu.animations)) {
            diffAnimationsFor(id, old.animations, neu.animations)
        }

        // Accessibility — emit an empty modifiers object on Some -> None so a
        // previously-set automation name is cleared.
        if (!a11yEq(old.accessibility, neu.accessibility)) {
            let acc = match (neu.accessibility) {
                case Some(a) => a
                case None => AccessibilityModifiers()
            }
            backend.setAccessibility(id, acc)
        }

        // Keyboard accelerators.
        if (!accelsEq(old.keyboardAccelerators, neu.keyboardAccelerators)) {
            let arr = match (neu.keyboardAccelerators) {
                case Some(v) => v.toArray()
                case None => Array<KeyboardAccelerator>()
            }
            backend.setKeyboardAccelerators(id, arr)
        }

        // Tooltip (ToolTipService attached prop) — emit None clear on Some->None.
        if (!tooltipOptEq(old.tooltip, neu.tooltip)) {
            backend.setTooltip(id, neu.tooltip)
        }

        // Pointer handlers — clear on Some->None to avoid leaking event tokens.
        if (!pointersEq(old.pointerHandlers, neu.pointerHandlers)) {
            backend.setPointerHandlers(id, filterNonEmptyPointers(neu.pointerHandlers))
        }

        // Grid placement fast-path: always emit all four props on change so
        // stale values are cleared.
        if (!optEq<GridPlacement>(old.grid, neu.grid)) {
            applyGridPlacementFull(id, gridOrDefault(neu.grid))
        }

        // Canvas placement attached props.
        if (!optEq<CanvasPosition>(old.canvasPosition, neu.canvasPosition)) {
            applyCanvasPositionFull(id, canvasOrDefault(neu.canvasPosition))
        }

        // RelativePanel alignment attached props.
        if (!optEq<RelativePanelAlignment>(old.relativeAlign, neu.relativeAlign)) {
            applyRelativePanelAlignmentFull(id, relativeOrDefault(neu.relativeAlign))
        }

        // Resources.
        if (!resourcesOptEq(old.resources, neu.resources)) {
            match (neu.resources) {
                case Some(res) =>
                    if (res.size > 0) { backend.setProp(id, Prop.Resources, PropValue.ResourcesV(cloneStrMap(res))) }
                case None => ()
            }
        }
    }

    // ── Attached-prop application helpers (grid / canvas / relative panel) ──
    func applyGridPlacement(id: ControlId, p: GridPlacement): Unit {
        if (p.row != 0) { backend.setProp(id, Prop.AttachedGridRow, PropValue.I32(p.row)) }
        if (p.column != 0) { backend.setProp(id, Prop.AttachedGridColumn, PropValue.I32(p.column)) }
        if (p.rowSpan > 1) { backend.setProp(id, Prop.AttachedGridRowSpan, PropValue.I32(p.rowSpan)) }
        if (p.columnSpan > 1) { backend.setProp(id, Prop.AttachedGridColumnSpan, PropValue.I32(p.columnSpan)) }
    }

    func applyGridPlacementFull(id: ControlId, p: GridPlacement): Unit {
        backend.setProp(id, Prop.AttachedGridRow, PropValue.I32(p.row))
        backend.setProp(id, Prop.AttachedGridColumn, PropValue.I32(p.column))
        backend.setProp(id, Prop.AttachedGridRowSpan, PropValue.I32(p.rowSpan))
        backend.setProp(id, Prop.AttachedGridColumnSpan, PropValue.I32(p.columnSpan))
    }

    func applyCanvasPosition(id: ControlId, p: CanvasPosition): Unit {
        if (p.left != 0.0) { backend.setProp(id, Prop.AttachedCanvasLeft, PropValue.F64(p.left)) }
        if (p.top != 0.0) { backend.setProp(id, Prop.AttachedCanvasTop, PropValue.F64(p.top)) }
        if (p.zIndex != 0) { backend.setProp(id, Prop.AttachedCanvasZIndex, PropValue.I32(p.zIndex)) }
    }

    func applyCanvasPositionFull(id: ControlId, p: CanvasPosition): Unit {
        backend.setProp(id, Prop.AttachedCanvasLeft, PropValue.F64(p.left))
        backend.setProp(id, Prop.AttachedCanvasTop, PropValue.F64(p.top))
        backend.setProp(id, Prop.AttachedCanvasZIndex, PropValue.I32(p.zIndex))
    }

    func applyRelativePanelAlignment(id: ControlId, p: RelativePanelAlignment): Unit {
        if (p.alignLeftWithPanel) { backend.setProp(id, Prop.RelativePanelAlignLeftWithPanel, PropValue.BoolV(true)) }
        if (p.alignRightWithPanel) { backend.setProp(id, Prop.RelativePanelAlignRightWithPanel, PropValue.BoolV(true)) }
        if (p.alignTopWithPanel) { backend.setProp(id, Prop.RelativePanelAlignTopWithPanel, PropValue.BoolV(true)) }
        if (p.alignBottomWithPanel) { backend.setProp(id, Prop.RelativePanelAlignBottomWithPanel, PropValue.BoolV(true)) }
        if (p.alignHCenterWithPanel) { backend.setProp(id, Prop.RelativePanelAlignHCenterWithPanel, PropValue.BoolV(true)) }
        if (p.alignVCenterWithPanel) { backend.setProp(id, Prop.RelativePanelAlignVCenterWithPanel, PropValue.BoolV(true)) }
    }

    func applyRelativePanelAlignmentFull(id: ControlId, p: RelativePanelAlignment): Unit {
        backend.setProp(id, Prop.RelativePanelAlignLeftWithPanel, PropValue.BoolV(p.alignLeftWithPanel))
        backend.setProp(id, Prop.RelativePanelAlignRightWithPanel, PropValue.BoolV(p.alignRightWithPanel))
        backend.setProp(id, Prop.RelativePanelAlignTopWithPanel, PropValue.BoolV(p.alignTopWithPanel))
        backend.setProp(id, Prop.RelativePanelAlignBottomWithPanel, PropValue.BoolV(p.alignBottomWithPanel))
        backend.setProp(id, Prop.RelativePanelAlignHCenterWithPanel, PropValue.BoolV(p.alignHCenterWithPanel))
        backend.setProp(id, Prop.RelativePanelAlignVCenterWithPanel, PropValue.BoolV(p.alignVCenterWithPanel))
    }

    // ── Context-affected component collection (provider / theme propagation) ──
    func collectAffectedComponents(rootId: ControlId, changed: HashSet<ContextId>): ArrayList<ControlId> {
        let result = ArrayList<ControlId>()
        let stack = ArrayList<ControlId>()
        stack.add(rootId)
        while (stack.size > 0) {
            let id = stack.remove(at: stack.size - 1)
            match (componentInstances.get(id)) {
                case Some(inst) =>
                    if (anyContextRead(inst.readContexts, changed)) { result.add(id) }
                case None => ()
            }
            match (childrenMirror.get(id)) {
                case Some(kids) => for (k in kids) { stack.add(k) }
                case None => ()
            }
        }
        result
    }

    public func notifyThemeChanged(): Unit { backend.onThemeChanged() }

    func forceContextSubscribers(rootId: ControlId, contextIds: HashSet<ContextId>): Unit {
        let affected = collectAffectedComponents(rootId, contextIds)
        if (affected.size > 0) {
            forceComponentRerender = true
            for (a in affected) { forcedComponents.add(a) }
        }
    }

    public func clearForcedComponentRerender(): Unit {
        forceComponentRerender = false
        forcedComponents.clear()
    }

    // ── children-diff entry points (delegate to free functions in
    //    reconciler_child.cj, which take this reconciler) ────────────────────
    func reconcileChildrenPositional(parent: ControlId, old: Array<Element>, neu: Array<Element>): Unit {
        let oldLive = collectLive(old)
        let newLive = collectLive(neu)
        reconcilePositional(this, parent, oldLive, newLive)
    }

    func reconcileChildren(parent: ControlId, old: Array<Element>, neu: Array<Element>): Unit {
        let oldLive = collectLive(old)
        let newLive = collectLive(neu)
        reconcileChildLists(this, parent, oldLive, newLive)
    }
}

// ── LiveChildren flatten: drop EmptyEl and recursively splice GroupEl children.
// Element is a reference-semantics carrier, so collecting into a fresh Array is
// cheap. (We always materialise an Array rather than the reference's Flat/Filtered
// two-state optimisation; behaviour is identical.)
func collectLive(slice: Array<Element>): Array<Element> {
    let out = ArrayList<Element>()
    for (el in slice) { pushLive(el, out) }
    out.toArray()
}

func pushLive(el: Element, out: ArrayList<Element>): Unit {
    match (el) {
        case EmptyEl => ()
        case GroupEl(g) => for (child in g.children) { pushLive(child, out) }
        case _ => out.add(el)
    }
}

func anyHasKey(slice: Array<Element>): Bool {
    for (e in slice) {
        if (e.key().isSome()) { return true }
    }
    false
}

func anyContextRead(read: HashSet<ContextId>, changed: HashSet<ContextId>): Bool {
    for (c in read) {
        if (changed.contains(c)) { return true }
    }
    false
}
