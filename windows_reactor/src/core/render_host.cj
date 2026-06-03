package windows_reactor.core

import std.collection.*

// ============================================================================
// RenderHost — owns a Reconciler + a root component, coalescing render requests
// onto a Dispatcher (typically the UI thread). The RenderState machine merges a
// burst of requests into a single pass; a request that arrives mid-render is
// folded into a follow-up Low-priority pass so the tree settles.
//
// INTEGRATION CONTRACT (Reconciler is owned by the reconciler module): RenderHost
// drives the Reconciler through this surface, matching the architecture spec §4:
//   Reconciler(backend: Backend)
//   reconciler.setInnerSizeCell(SizeCell) / setDpiCell(DpiCell) / setMarshaller(?UiMarshaller)
//   reconciler.resetStats()
//   reconciler.reconcile(old: ?Element, neu: Element, existing: ?ControlId,
//                        requestRerender: () -> Unit): ?ControlId
//   reconciler.drainRealizations()
//   reconciler.clearForcedComponentRerender()
//   reconciler.debugElementsDiffed / debugElementsSkipped / debugUiElementsCreated : Int64
//   reconciler.forceContextSubscribers(root: ControlId, changed: HashSet<ContextId>)
// The root component is a ComponentObject (carries its own props), rendered via
// render(cx); this replaces the reference Box<dyn Component> + root.render(&()).
// ============================================================================

// Per-render telemetry snapshot.
public class RenderStats {
    public var fps: Float64 = 0.0
    public var rendersInWindow: Int64 = 0
    public var totalRenders: Int64 = 0
    public var avgTreeBuildMs: Float64 = 0.0
    public var avgReconcileMs: Float64 = 0.0
    public var avgEffectsMs: Float64 = 0.0
    public var lastDiffed: Int64 = 0
    public var lastSkipped: Int64 = 0
    public var lastCreated: Int64 = 0
    public init() {}
}

enum RenderState {
    | Idle | Pending | Rendering | RenderingDirty

    func tag(): Int64 {
        match (this) {
            case Idle => 0
            case Pending => 1
            case Rendering => 2
            case RenderingDirty => 3
        }
    }

    func eq(other: RenderState): Bool { tag() == other.tag() }
}

public class RenderHost {
    let reconciler: Reconciler
    var root: ComponentObject
    let renderCx: RenderCx
    let dispatcher: Dispatcher

    var rootId: ?ControlId = None
    var lastTree: ?Element = None
    var state = RenderState.Idle
    var marshaller: ?UiMarshaller = None
    var renderCount: Int64 = 0
    var stats = RenderStats()

    var postRender: ?((?ControlId) -> Unit) = None
    var renderComplete: ?((Float64, Float64, Float64) -> Unit) = None

    let innerSize = SizeCell()
    let dpi = DpiCell()

    public init(backend: Backend, root: ComponentObject, dispatcher: Dispatcher) {
        this.reconciler = Reconciler(backend)
        this.root = root
        this.dispatcher = dispatcher
        this.renderCx = RenderCx({ => })

        renderCx.setInnerSizeCell(innerSize)
        renderCx.setDpiCell(dpi)
        reconciler.setInnerSizeCell(innerSize)
        reconciler.setDpiCell(dpi)
    }

    public func statsValue(): RenderStats { stats }
    public func renderCountValue(): Int64 { renderCount }
    public func rootIdValue(): ?ControlId { rootId }

    public func isRenderPending(): Bool { !state.eq(RenderState.Idle) }
    public func isRendering(): Bool {
        state.eq(RenderState.Rendering) || state.eq(RenderState.RenderingDirty)
    }
    public func needsRerender(): Bool {
        state.eq(RenderState.Pending) || state.eq(RenderState.RenderingDirty)
    }
    public func isIdle(): Bool { state.eq(RenderState.Idle) }

    // Install (or clear) the UiMarshaller used for off-UI-thread state writes,
    // and publish this host's rerender hook to the UI thread's UI_RERENDER slot.
    public func setMarshaller(m: ?UiMarshaller): Unit {
        marshaller = m
        renderCx.setMarshaller(m)
        reconciler.setMarshaller(m)
        match (m) {
            case Some(_) =>
                let host = this
                setUiRerender(Some({ => host.requestRender() }))
            case None => setUiRerender(None)
        }
    }

    // Enable eager realization of templated lists: every row is realized up front
    // (rather than lazily on scroll). Mirrors App::eager_templated_realization.
    public func setEagerTemplatedRealization(v: Bool): Unit {
        reconciler.eagerTemplatedRealization = v
    }

    // Wire the rerender request closure into the render context and kick off the
    // first render. The closure captures `this` (the host is the long-lived
    // owner; teardown clears UI_RERENDER via setMarshaller(None)).
    public func kick(): Unit {
        let host = this
        renderCx.setRequestRerender({ => host.requestRender() })
        requestRender()
    }

    // Wire the rerender request closure and render the FIRST frame synchronously
    // on the calling thread. WinUI's OnLaunched runs on the UI thread, so the
    // initial tree can be materialized into the backend (and attached to the
    // window) before Window.Activate(), guaranteeing content is present for the
    // first composition/layout pass. Subsequent re-renders still coalesce onto
    // the dispatcher via requestRender(). Safe to call only on the UI thread when
    // idle; if a render is already pending it falls back to a queued kick().
    public func kickSync(): Unit {
        let host = this
        renderCx.setRequestRerender({ => host.requestRender() })
        if (state.eq(RenderState.Idle)) {
            state = RenderState.Rendering
            renderOnce()
            // A re-render requested during the synchronous pass (RenderingDirty)
            // settles asynchronously; otherwise we return to Idle.
            if (state.eq(RenderState.RenderingDirty)) {
                state = RenderState.Pending
                let ok = dispatcher.enqueue(DispatchPriority.Low, { => host.renderLoop() })
                if (!ok) { state = RenderState.Idle }
            } else {
                state = RenderState.Idle
            }
        } else {
            requestRender()
        }
    }

    public func setPostRender(f: (?ControlId) -> Unit): Unit { postRender = Some(f) }
    public func setRenderComplete(f: (Float64, Float64, Float64) -> Unit): Unit {
        renderComplete = Some(f)
    }

    public func innerSizeValue(): Size { innerSize.value }
    public func dpiValue(): UInt32 { dpi.value }

    public func setInnerSize(size: Size): Unit {
        if (innerSize.value == size) { return }
        innerSize.value = size
        match (rootId) {
            case Some(rid) =>
                let changed = HashSet<ContextId>()
                changed.add(innerSizeContextId())
                reconciler.forceContextSubscribers(rid, changed)
            case None => ()
        }
        requestRender()
    }

    public func setDpi(value: UInt32): Unit {
        if (dpi.value == value) { return }
        dpi.value = value
        match (rootId) {
            case Some(rid) =>
                let changed = HashSet<ContextId>()
                changed.add(dpiContextId())
                reconciler.forceContextSubscribers(rid, changed)
            case None => ()
        }
        requestRender()
    }

    // ── State machine ──
    // Idle      -> Pending, enqueue renderLoop (reset to Idle if the queue rejects)
    // Pending / RenderingDirty -> ignore (request already coalesced)
    // Rendering -> RenderingDirty (re-render after the current pass settles)
    public func requestRender(): Unit {
        match (state) {
            case Idle =>
                state = RenderState.Pending
                let host = this
                let ok = dispatcher.enqueue(DispatchPriority.Normal, { => host.renderLoop() })
                if (!ok) {
                    state = RenderState.Idle
                }
            case Pending => ()
            case RenderingDirty => ()
            case Rendering =>
                state = RenderState.RenderingDirty
        }
    }

    func renderLoop(): Unit {
        state = RenderState.Rendering
        renderOnce()

        if (state.eq(RenderState.RenderingDirty)) {
            state = RenderState.Pending
            let host = this
            let ok = dispatcher.enqueue(DispatchPriority.Low, { => host.renderLoop() })
            if (!ok) {
                state = RenderState.Idle
            }
        } else {
            state = RenderState.Idle
        }
    }

    func renderOnce(): Unit {
        // 1. Build the new tree from the root component.
        renderCx.setContextStack(reconciler.contextStackHandle())
        renderCx.setMarshaller(marshaller)
        renderCx.beginRender()
        let newTree = root.render(renderCx)

        // 2. Reconcile against the previous tree (taken, not cloned).
        let oldTree = lastTree
        lastTree = None
        reconciler.resetStats()

        let existing = rootId
        let host = this
        let requestRerender: () -> Unit = { => host.requestRender() }
        let newRootId = reconciler.reconcile(oldTree, newTree, existing, requestRerender)
        drainRealizations(reconciler)
        reconciler.clearForcedComponentRerender()

        let lastDiffed = reconciler.debugElementsDiffed
        let lastSkipped = reconciler.debugElementsSkipped
        let lastCreated = reconciler.debugUiElementsCreated

        rootId = newRootId
        lastTree = Some(newTree)

        // 3. Flush queued effects (cleanups then effects).
        renderCx.flushEffects()

        renderCount = renderCount + 1

        // Record stats (no high-resolution timing in the headless host; the
        // WinUI host can override timing later — keep counts accurate).
        stats.totalRenders = renderCount
        stats.lastDiffed = lastDiffed
        stats.lastSkipped = lastSkipped
        stats.lastCreated = lastCreated

        // 4. postRender callback (take-then-restore to allow re-entrancy without
        // double-firing — mirrors the reference take/restore guard).
        match (postRender) {
            case Some(cb) =>
                postRender = None
                cb(rootId)
                match (postRender) {
                    case None => postRender = Some(cb)
                    case Some(_) => ()
                }
            case None => ()
        }

        match (renderComplete) {
            case Some(cb) =>
                renderComplete = None
                cb(0.0, 0.0, 0.0)
                match (renderComplete) {
                    case None => renderComplete = Some(cb)
                    case Some(_) => ()
                }
            case None => ()
        }
    }
}
