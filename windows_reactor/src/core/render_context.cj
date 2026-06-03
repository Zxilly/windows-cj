package windows_reactor.core

import std.collection.*
import std.sync.*

// ============================================================================
// Render context + hooks. This is the load-bearing runtime piece: every
// component instance owns a RenderCx that survives across renders and holds its
// hook slots. The reference used Rc<RefCell<…>> + Box<dyn Any>; Cangjie is GC,
// so shared mutable state is just a class reference. The hard rule (verified in
// the foundation probes): closures that outlive the render MUST capture a
// reference-type cell (a class with a var field), never a local var — locals
// cannot escape. Every setter / effect / cleanup here captures StateCell /
// DirtyFlag / Generation / cells accordingly.
// ============================================================================

// ─── Reference-type state cells ─────────────────────────────────────────────

// Holds a hook's current value. GC reference == shared mutable state (replaces
// Rc<RefCell<Box<dyn Any>>>).
public class StateCell<T> {
    public var value: T
    public init(value: T) { this.value = value }
}

// Shared "a setter changed a value since begin_render" flag. The reconciler
// reads this to force re-render of the owning component even when its parent's
// element tree is structurally identical.
public class DirtyFlag {
    public var flag: Bool = false
    public init() {}
}

public class LifecycleFlag {
    public var active: Bool = true
    public init() {}
}

// Identity-stable mutable cell returned by useRef. Same instance every render;
// writing it does NOT request a re-render (mirrors the reference HookRef).
public class HookRef<T> {
    public var value: T
    public init(value: T) { this.value = value }

    public func get(): T { value }
    public func set(v: T): Unit { value = v }
}

// Thread-safe state cell backing useAsyncState; writes can come from any
// thread, so the value is guarded by a mutex.
public class AsyncStateCell<T> {
    let lock = Mutex()
    var value: T
    public init(value: T) { this.value = value }

    public func get(): T {
        synchronized(lock) { value }
    }

    // Returns true when the value changed (so the caller pumps a rerender).
    public func setIfChanged(v: T, eq: (T, T) -> Bool): Bool {
        synchronized(lock) {
            if (eq(value, v)) {
                return false
            }
            value = v
            return true
        }
    }
}

// Monotonic per-monitor DPI / inner-size cells shared with the host + reconciler.
public class SizeCell {
    public var value: Size = Size(0.0, 0.0)
    public init() {}
}

public class DpiCell {
    public var value: UInt32 = 96
    public init() {}
}

// ─── Deps boxing (replaces Box<dyn Deps> type erasure) ──────────────────────

// useMemo/useEffect/useCallback take D <: Equatable<D>. The slot must store the
// previous deps without carrying a generic type argument on the slot class, so
// we wrap the typed value in a DepsHolder<D> and put it behind a DepsHolderBox.
// The box compares against a freshly boxed deps value of the SAME static type D
// (the comparison closure is monomorphic in D, produced at the typed call site),
// recovering the typed holder via a single runtime type match — no cross-type
// downcast is ever required.
public class DepsHolder<D> where D <: Equatable<D> {
    public let value: D
    public init(value: D) { this.value = value }
    public func equals(other: DepsHolder<D>): Bool { value == other.value }
}

// ─── Hook slots (class hierarchy; heterogeneous typed payloads) ─────────────

public open class HookSlot {
    public init() {}
}

public class StateSlot<T> <: HookSlot {
    public var cell: StateCell<T>
    public init(cell: StateCell<T>) {
        this.cell = cell
    }
}

// useRef slot: the HookRef identity is stable, stored once.
public class RefSlot<T> <: HookSlot {
    public let handle: HookRef<T>
    public init(handle: HookRef<T>) {
        this.handle = handle
    }
}

public class MemoSlot<T> <: HookSlot {
    public var value: T
    public var deps: ?DepsHolderBox
    public init(value: T, deps: ?DepsHolderBox) {
        this.value = value
        this.deps = deps
    }
}

public class EffectSlot <: HookSlot {
    public var deps: ?DepsHolderBox
    // effect body, runs to (optionally) produce a cleanup
    public var pending: ?(() -> ?(() -> Unit))
    public var cleanup: ?(() -> Unit)
    public var pendingCleanup: ?(() -> Unit)
    public init(deps: ?DepsHolderBox, pending: ?(() -> ?(() -> Unit))) {
        this.deps = deps
        this.pending = pending
        this.cleanup = None
        this.pendingCleanup = None
    }
}

public class AsyncStateSlot<T> <: HookSlot {
    public let cell: AsyncStateCell<T>
    public init(cell: AsyncStateCell<T>) {
        this.cell = cell
    }
}

// Type-erased deps comparison wrapper that actually works: it stores a closure
// `(HookSlot-stored other) -> Bool` recovering the typed holder. Because each
// hook compares a *new* deps value of the SAME static type D against the slot's
// stored one, we wrap the stored holder and provide a comparison that accepts a
// fresh holder of D. The fresh holder is supplied at the call site (compile-time
// typed), so no runtime downcast across types is needed.
public class DepsHolderBox {
    // Compare against a freshly boxed deps value of the same D. The closure was
    // produced at the typed call site, so it is monomorphic in D.
    let compareFresh: (DepsHolderBox) -> Bool
    // Identity carrier so the fresh box can hand its holder back.
    public let carrier: Object

    init(carrier: Object, compareFresh: (DepsHolderBox) -> Bool) {
        this.carrier = carrier
        this.compareFresh = compareFresh
    }

    public func equalsAgainst(fresh: DepsHolderBox): Bool { compareFresh(fresh) }
}

func makeDepsHolderBox<D>(value: D): DepsHolderBox where D <: Equatable<D> {
    let holder = DepsHolder<D>(value)
    DepsHolderBox(
        holder,
        { fresh: DepsHolderBox =>
            // fresh.carrier is a DepsHolder<D> produced at the same typed site.
            match (fresh.carrier) {
                case h: DepsHolder<D> => holder.equals(h)
                case _ => false
            }
        }
    )
}

// ─── Hook ordering exception (replaces Rust panic) ──────────────────────────

public class HookOrderException <: Exception {
    public init(msg: String) { super(msg) }
}

// ─── Setter / updater / dispatch handles ────────────────────────────────────

// Returned by useState. Calling it replaces the slot value and (if changed)
// marks dirty + requests a rerender. Captures only reference cells.
public class SetState<T> where T <: Equatable<T> {
    let cell: StateCell<T>
    let dirty: DirtyFlag
    let lifecycle: LifecycleFlag
    let request: () -> Unit

    init(cell: StateCell<T>, dirty: DirtyFlag, lifecycle: LifecycleFlag, request: () -> Unit) {
        this.cell = cell
        this.dirty = dirty
        this.lifecycle = lifecycle
        this.request = request
    }

    public func call(value: T): Unit {
        if (!lifecycle.active) { return }
        if (cell.value == value) { return }
        cell.value = value
        dirty.flag = true
        request()
    }

    // Expose as a Callback<T> so it can be wired to events directly.
    public func asCallback(): Callback<T> {
        let c = cell
        let d = dirty
        let l = lifecycle
        let r = request
        Callback<T>({ v: T =>
            if (!l.active) {
                return
            }
            if (!(c.value == v)) {
                c.value = v
                d.flag = true
                r()
            }
        })
    }
}

// Functional updater returned by useReducer: mutate via f(prev) -> next.
public class Updater<T> where T <: Equatable<T> {
    let cell: StateCell<T>
    let dirty: DirtyFlag
    let lifecycle: LifecycleFlag
    let request: () -> Unit

    init(cell: StateCell<T>, dirty: DirtyFlag, lifecycle: LifecycleFlag, request: () -> Unit) {
        this.cell = cell
        this.dirty = dirty
        this.lifecycle = lifecycle
        this.request = request
    }

    public func call(f: (T) -> T): Unit {
        if (!lifecycle.active) { return }
        let prev = cell.value
        let next = f(prev)
        if (prev == next) { return }
        cell.value = next
        dirty.flag = true
        request()
    }
}

// Action dispatcher returned by useReducerFn: next = reducer(prev, action).
public class Dispatch<A> {
    let apply: (A) -> Unit

    init(apply: (A) -> Unit) { this.apply = apply }

    public func call(action: A): Unit { apply(action) }
}

// Thread-safe setter returned by useAsyncState. .call(value) is safe from any
// thread: the write is marshalled onto the UI thread, the cell is locked,
// short-circuited on equality, then a rerender is pumped.
public class AsyncSetState<T> where T <: Equatable<T> {
    let cell: AsyncStateCell<T>
    let marshaller: UiMarshaller
    let lifecycle: LifecycleFlag

    init(cell: AsyncStateCell<T>, marshaller: UiMarshaller, lifecycle: LifecycleFlag) {
        this.cell = cell
        this.marshaller = marshaller
        this.lifecycle = lifecycle
    }

    public func call(value: T): Unit {
        if (!lifecycle.active) { return }
        let c = cell
        let l = lifecycle
        let _ = marshaller.dispatch({ =>
            if (!l.active) {
                return
            }
            let changed = c.setIfChanged(value, { a: T, b: T => a == b })
            if (changed) {
                requestUiRerenderOnUiThread()
            }
        })
    }
}

// ─── Context (minimal types hooks depend on) ────────────────────────────────

let contextIdCounter = CallbackIdCounter()

// Stable identity for a context channel. The reconciler keys the context stack
// and subscriber tracking on this.
public class ContextId <: Hashable & Equatable<ContextId> {
    public let raw: UInt64
    public init() { this.raw = contextIdCounter.allocate() }
    init(raw: UInt64) { this.raw = raw }

    // Reconstruct a ContextId from a raw id (bridge for any raw-id carrier).
    public static func fromRaw(raw: UInt64): ContextId { ContextId(raw) }

    public func hashCode(): Int64 { Int64(raw) }
    public operator func ==(other: ContextId): Bool { raw == other.raw }
    public operator func !=(other: ContextId): Bool { raw != other.raw }
}

// Typed context handle: id + default value used when no provider is in scope.
public class Context<T> {
    public let id: ContextId
    public let defaultValue: T
    public init(defaultValue: T) {
        this.id = ContextId()
        this.defaultValue = defaultValue
    }
}

// A single context value provision carried by a ProviderElement. The value is
// boxed as a type-erased ContextValue<T>; valueTypeId is the context id (stable
// per channel) and equalsValue compares two provisions of the same context.
public class ContextProvision {
    public let contextId: ContextId
    public let valueTypeId: UInt64
    public let value: Object
    let eq: (ContextProvision) -> Bool

    public init(contextId: ContextId, value: Object, eq: (ContextProvision) -> Bool) {
        this.contextId = contextId
        this.valueTypeId = contextId.raw
        this.value = value
        this.eq = eq
    }

    public func equalsValue(other: ContextProvision): Bool { eq(other) }
}

// Build a context provision whose value equality compares by ==, for contexts
// whose value type is Equatable (so dependent components only re-render when the
// provided value actually changes).
public func provideContextEq<T>(context: Context<T>, value: T): ContextProvision
    where T <: Equatable<T> {
    ContextProvision(context.id, ContextValue<T>(value), { other: ContextProvision =>
        match (other.value) {
            case ov: ContextValue<T> => value == ov.value
            case _ => false
        }
    })
}

// Build a context provision for a non-Equatable value type. Such provisions
// always compare unequal, so dependent components re-render on every provider
// update (safe; never skips a needed update). Prefer provideContextEq when T is
// Equatable.
public func provideContext<T>(context: Context<T>, value: T): ContextProvision {
    ContextProvision(context.id, ContextValue<T>(value), { _ => false })
}

// Wrap `child` in a ProviderElement carrying one provision.
public func provider(provision: ContextProvision, child: Element): Element {
    Element.ProviderEl(ProviderElement(provision, child))
}

// Wrap `child` in a ProviderElement carrying several provisions.
public func providerAll(provisions: ArrayList<ContextProvision>, child: Element): Element {
    Element.ProviderEl(ProviderElement(child, provisions))
}

// Ambient provider stack queried by useContext. A push/pop stack of provisions
// (the reconciler pushes while descending into a provider's subtree and pops on
// the way out). get<T> walks from the top so the nearest enclosing provision
// wins; recovery is via a runtime type match on the boxed ContextValue<T>.
public class ContextStack {
    let stack = ArrayList<ContextProvision>()

    public init() {}

    // Push a raw provision (id + value-type id + boxed value). The valueTypeId is
    // retained alongside so identity/equality can be checked without unboxing.
    public func pushRawRetain(id: ContextId, valueTypeId: UInt64, value: Object): Unit {
        let _ = valueTypeId
        // Reconstruct a provision that compares unequal by default (the provider
        // already computed change sets before pushing); the push only needs to
        // expose the value to get<T>().
        stack.add(ContextProvision(id, value, { _ => false }))
    }

    public func popRaw(): Unit {
        if (stack.size > 0) {
            stack.remove(at: stack.size - 1)
        }
    }

    public func depth(): Int64 { stack.size }

    // Resolve the nearest provided value for `id`, recovering its type via a
    // runtime match on ContextValue<T>.
    public func get<T>(id: ContextId): ?T {
        var i = stack.size - 1
        while (i >= 0) {
            let prov = stack[i]
            if (prov.contextId == id) {
                match (prov.value) {
                    case v: ContextValue<T> => return Some(v.value)
                    case _ => return None
                }
            }
            i--
        }
        None
    }
}

// Stable ContextIds used to track subscribers of useInnerSize / useDpi. Lazy
// singletons (the reference used OnceLock).
class StableContextIds {
    let innerSize = ContextId()
    let dpi = ContextId()
}
let stableContextIds = StableContextIds()

public func innerSizeContextId(): ContextId { stableContextIds.innerSize }
public func dpiContextId(): ContextId { stableContextIds.dpi }

// ─── RenderCx ───────────────────────────────────────────────────────────────

public class RenderCx {
    let hooks = ArrayList<HookSlot>()
    var cursor: Int64 = 0
    var requestRerender: () -> Unit
    // Shared dirty flag; SetState/Updater/Dispatch set it, the reconciler reads
    // it to force re-render of this component instance.
    let dirty = DirtyFlag()
    let lifecycle = LifecycleFlag()
    let readContexts = HashSet<ContextId>()
    var contextStack: ?ContextStack = None
    var marshaller: ?UiMarshaller = None
    var innerSize = SizeCell()
    var dpi = DpiCell()

    public init(requestRerender: () -> Unit) {
        this.requestRerender = requestRerender
    }

    public static func forTest(): RenderCx {
        RenderCx({ => })
    }

    // ── per-frame bookkeeping ──
    public func beginRender(): Unit {
        cursor = 0
        readContexts.clear()
        dirty.flag = false
    }

    public func hookCount(): Int64 { hooks.size }

    public func setRequestRerender(r: () -> Unit): Unit { requestRerender = r }

    public func setContextStack(stack: ContextStack): Unit { contextStack = Some(stack) }

    public func setMarshaller(m: ?UiMarshaller): Unit { marshaller = m }

    public func setInnerSizeCell(cell: SizeCell): Unit { innerSize = cell }
    public func setDpiCell(cell: DpiCell): Unit { dpi = cell }

    public func deactivate(): Unit { lifecycle.active = false }

    // Returns true if a setter changed a value since beginRender, clearing it.
    public func takeStateDirty(): Bool {
        let d = dirty.flag
        dirty.flag = false
        d
    }

    public func peekStateDirty(): Bool { dirty.flag }

    // Take (move out) the set of contexts read this render, clearing it.
    public func takeReadContexts(): HashSet<ContextId> {
        let out = HashSet<ContextId>()
        for (id in readContexts) { out.add(id) }
        readContexts.clear()
        out
    }

    func nextSlot(): Int64 {
        let i = cursor
        cursor = cursor + 1
        i
    }

    // ── useState ──
    public func useState<T>(initial: T): (T, SetState<T>) where T <: Equatable<T> {
        let slotIndex = nextSlot()
        let cell = stateCell<T>(slotIndex, initial)
        let setter = SetState<T>(cell, dirty, lifecycle, requestRerender)
        (cell.value, setter)
    }

    // ── useReducer (functional updater) ──
    public func useReducer<T>(initial: T): (T, Updater<T>) where T <: Equatable<T> {
        let slotIndex = nextSlot()
        let cell = stateCell<T>(slotIndex, initial)
        let updater = Updater<T>(cell, dirty, lifecycle, requestRerender)
        (cell.value, updater)
    }

    // ── useReducerFn (action dispatcher over a reducer) ──
    public func useReducerFn<S, A>(reducer: (S, A) -> S, initial: S): (S, Dispatch<A>)
        where S <: Equatable<S> {
        let slotIndex = nextSlot()
        let cell = stateCell<S>(slotIndex, initial)
        let d = dirty
        let l = lifecycle
        let r = requestRerender
        let dispatch = Dispatch<A>({ action: A =>
            if (!l.active) {
                return
            }
            let prev = cell.value
            let next = reducer(prev, action)
            if (!(prev == next)) {
                cell.value = next
                d.flag = true
                r()
            }
        })
        (cell.value, dispatch)
    }

    // Shared state-slot acquisition: push on first render, reuse + type-check on
    // re-render. A mismatching slot type means the hook call order changed.
    func stateCell<T>(slotIndex: Int64, initial: T): StateCell<T> {
        if (slotIndex == hooks.size) {
            let cell = StateCell<T>(initial)
            hooks.add(StateSlot<T>(cell))
            return cell
        }
        match (hooks[slotIndex]) {
            case s: StateSlot<T> => s.cell
            case _ => throw HookOrderException(
                "hook called in different order at slot ${slotIndex}: expected state slot")
        }
    }

    // ── useRef ──
    public func useRef<T>(initial: T): HookRef<T> {
        let slotIndex = nextSlot()
        if (slotIndex == hooks.size) {
            let h = HookRef<T>(initial)
            hooks.add(RefSlot<T>(h))
            return h
        }
        match (hooks[slotIndex]) {
            case s: RefSlot<T> => s.handle
            case _ => throw HookOrderException(
                "hook called in different order at slot ${slotIndex}: expected ref slot")
        }
    }

    // ── useMemo ──
    public func useMemo<T, D>(deps: D, factory: () -> T): T where D <: Equatable<D> {
        let slotIndex = nextSlot()
        let freshDeps = makeDepsHolderBox<D>(deps)
        if (slotIndex == hooks.size) {
            let value = factory()
            hooks.add(MemoSlot<T>(value, Some(freshDeps)))
            return value
        }
        match (hooks[slotIndex]) {
            case s: MemoSlot<T> =>
                let equal = match (s.deps) {
                    case Some(stored) => stored.equalsAgainst(freshDeps)
                    case None => false
                }
                if (equal) {
                    return s.value
                }
                let nv = factory()
                s.value = nv
                s.deps = Some(freshDeps)
                return nv
            case _ => throw HookOrderException(
                "hook called in different order at slot ${slotIndex}: expected memo slot")
        }
    }

    // ── useCallback (memoised Callback; stable id lets the reconciler skip
    // event re-binding) ──
    public func useCallback<A, D>(deps: D, f: (A) -> Unit): Callback<A>
        where D <: Equatable<D> {
        useMemo<Callback<A>, D>(deps, { => Callback<A>(f) })
    }

    // ── useEffect (no cleanup) ──
    public func useEffect<D>(deps: D, f: () -> Unit): Unit where D <: Equatable<D> {
        useEffectWithCleanup<D>(deps, { =>
            f()
            return Option<() -> Unit>.None
        })
    }

    // ── useEffectWithCleanup ──
    // Only QUEUES pending; never runs here. On a deps change the prior cleanup
    // is moved to pendingCleanup and a new pending body is stored. flushEffects
    // runs pending in two passes (all cleanups, then all effects).
    public func useEffectWithCleanup<D>(deps: D, f: () -> ?(() -> Unit)): Unit
        where D <: Equatable<D> {
        let slotIndex = nextSlot()
        let freshDeps = makeDepsHolderBox<D>(deps)
        if (slotIndex == hooks.size) {
            hooks.add(EffectSlot(Some(freshDeps), Some(f)))
            return
        }
        match (hooks[slotIndex]) {
            case s: EffectSlot =>
                let equal = match (s.deps) {
                    case Some(stored) => stored.equalsAgainst(freshDeps)
                    case None => false
                }
                if (!equal) {
                    match (s.cleanup) {
                        case Some(prev) =>
                            s.pendingCleanup = Some(prev)
                            s.cleanup = None
                        case None => ()
                    }
                    s.deps = Some(freshDeps)
                    s.pending = Some(f)
                }
            case _ => throw HookOrderException(
                "hook called in different order at slot ${slotIndex}: expected effect slot")
        }
    }

    // ── useAsyncState ──
    public func useAsyncState<T>(initial: T): (T, AsyncSetState<T>) where T <: Equatable<T> {
        let slotIndex = nextSlot()
        let cell = asyncStateCell<T>(slotIndex, initial)
        let m = match (marshaller) {
            case Some(mm) => mm
            case None => throw HookOrderException("useAsyncState requires a host marshaller")
        }
        let setter = AsyncSetState<T>(cell, m, lifecycle)
        (cell.get(), setter)
    }

    func asyncStateCell<T>(slotIndex: Int64, initial: T): AsyncStateCell<T> {
        if (slotIndex == hooks.size) {
            let cell = AsyncStateCell<T>(initial)
            hooks.add(AsyncStateSlot<T>(cell))
            return cell
        }
        match (hooks[slotIndex]) {
            case s: AsyncStateSlot<T> => s.cell
            case _ => throw HookOrderException(
                "hook called in different order at slot ${slotIndex}: expected async-state slot")
        }
    }

    // The UI-thread marshaller installed by the host (throws if absent).
    public func useUiMarshaller(): UiMarshaller {
        match (marshaller) {
            case Some(m) => m
            case None => throw HookOrderException("useUiMarshaller requires a WinUI host")
        }
    }

    // ── useContext ──
    public func useContext<T>(context: Context<T>): T {
        readContexts.add(context.id)
        match (contextStack) {
            case Some(stack) =>
                match (stack.get<T>(context.id)) {
                    case Some(v) => v
                    case None => context.defaultValue
                }
            case None => context.defaultValue
        }
    }

    // ── useColorScheme / useInnerSize / useDpi ──
    public func useColorScheme(): ColorScheme {
        currentColorScheme()
    }

    public func useInnerSize(): Size {
        readContexts.add(innerSizeContextId())
        innerSize.value
    }

    public func useDpi(): UInt32 {
        readContexts.add(dpiContextId())
        dpi.value
    }

    // ── Effect flushing ──
    // Two passes: run every queued cleanup first, then every queued effect
    // (storing the returned cleanup). Mirrors the reference ordering so an
    // effect's prior cleanup always runs before its new body.
    public func flushEffects(): Unit {
        for (slot in hooks) {
            match (slot) {
                case e: EffectSlot =>
                    match (e.pendingCleanup) {
                        case Some(c) =>
                            e.pendingCleanup = None
                            c()
                        case None => ()
                    }
                case _ => ()
            }
        }
        for (slot in hooks) {
            match (slot) {
                case e: EffectSlot =>
                    match (e.pending) {
                        case Some(effect) =>
                            e.pending = None
                            e.cleanup = effect()
                        case None => ()
                    }
                case _ => ()
            }
        }
    }

    // Run all cleanups on unmount: pending + live. Called explicitly by the
    // reconciler when tearing down a component instance (GC will not run these).
    public func runCleanups(): Unit {
        for (slot in hooks) {
            match (slot) {
                case e: EffectSlot =>
                    match (e.pendingCleanup) {
                        case Some(c) =>
                            e.pendingCleanup = None
                            c()
                        case None => ()
                    }
                    match (e.cleanup) {
                        case Some(c) =>
                            e.cleanup = None
                            c()
                        case None => ()
                    }
                case _ => ()
            }
        }
    }
}

// Typed carrier stored in the ContextStack so useContext<T> can recover the
// value. Engines' ProviderElement wiring boxes provided values into these.
public class ContextValue<T> {
    public let value: T
    public init(value: T) { this.value = value }
}
