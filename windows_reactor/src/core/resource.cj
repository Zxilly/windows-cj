package windows_reactor.core

import std.sync.*

// ============================================================================
// Async data primitives: Resource, MutationState, Generation, useResource,
// useMutation. These compose over useAsyncState + useEffect to provide a
// batteries-included pattern for loading remote data and performing async
// writes. Background work runs on a Cangjie thread (spawn); results are
// marshalled back onto the UI thread by AsyncSetState. Stale results are
// discarded via a monotonic Generation token (replaces the reference cancel).
//
// Decision (per plan): use_resource_retry is intentionally NOT implemented;
// retry semantics belong inside the caller's fetcher closure.
// ============================================================================

// ─── Resource lifecycle ─────────────────────────────────────────────────────

public enum Resource<T> {
    | ResIdle
    | ResLoading
    | ResReady(T)
    | ResReloading(T)
    | ResError(String)

    // Data if Ready or Reloading.
    public func data(): ?T {
        match (this) {
            case ResReady(v) => Some(v)
            case ResReloading(v) => Some(v)
            case _ => None
        }
    }

    public func isLoading(): Bool {
        match (this) {
            case ResLoading => true
            case ResReloading(_) => true
            case _ => false
        }
    }

    public func errorMessage(): ?String {
        match (this) {
            case ResError(e) => Some(e)
            case _ => None
        }
    }

    public func hasData(): Bool {
        match (this) {
            case ResReady(_) => true
            case ResReloading(_) => true
            case _ => false
        }
    }
}

// Equatable Resource for state diffing (useAsyncState requires Equatable<T>).
// Available only when T is itself Equatable.
extend<T> Resource<T> <: Equatable<Resource<T>> where T <: Equatable<T> {
    public operator func ==(other: Resource<T>): Bool {
        match ((this, other)) {
            case (ResIdle, ResIdle) => true
            case (ResLoading, ResLoading) => true
            case (ResReady(a), ResReady(b)) => a == b
            case (ResReloading(a), ResReloading(b)) => a == b
            case (ResError(a), ResError(b)) => a == b
            case _ => false
        }
    }

    public operator func !=(other: Resource<T>): Bool { !(this == other) }
}

// ─── Mutation lifecycle ─────────────────────────────────────────────────────

public enum MutationState<T> {
    | MutIdle
    | MutLoading
    | MutSuccess(T)
    | MutError(String)

    public func isLoading(): Bool {
        match (this) { case MutLoading => true; case _ => false }
    }

    public func isIdle(): Bool {
        match (this) { case MutIdle => true; case _ => false }
    }

    public func data(): ?T {
        match (this) { case MutSuccess(v) => Some(v); case _ => None }
    }

    public func errorMessage(): ?String {
        match (this) { case MutError(e) => Some(e); case _ => None }
    }
}

extend<T> MutationState<T> <: Equatable<MutationState<T>> where T <: Equatable<T> {
    public operator func ==(other: MutationState<T>): Bool {
        match ((this, other)) {
            case (MutIdle, MutIdle) => true
            case (MutLoading, MutLoading) => true
            case (MutSuccess(a), MutSuccess(b)) => a == b
            case (MutError(a), MutError(b)) => a == b
            case _ => false
        }
    }

    public operator func !=(other: MutationState<T>): Bool { !(this == other) }
}

// ─── Generation token for cancellation ──────────────────────────────────────

// Monotonic counter used to discard results from stale fetches. When deps
// change, advance() bumps the value; results stamped with an older generation
// are silently dropped. AtomicInt64 makes is_current safe across the worker
// thread. Reference-type cell so closures can capture it and escape.
public class Generation {
    let counter = AtomicInt64(0)

    public init() {}

    // Bump the generation; returns the new value to stamp this fetch with.
    public func advance(): Int64 {
        counter.fetchAdd(1) + 1
    }

    public func isCurrent(value: Int64): Bool {
        counter.load() == value
    }
}

// ─── FetchResult: the fetcher's Ok/Err return (replaces Result<T, String>) ──

public enum FetchResult<T> {
    | Ok(T)
    | Err(String)
}

// ─── use_resource / use_mutation (RenderCx extension) ───────────────────────

extend RenderCx {
    // Fetch data on a background thread, refetching when deps change. The
    // fetcher runs off the UI thread; its FetchResult is marshalled back. Stale
    // results (deps changed mid-flight) are dropped via the Generation token.
    public func useResource<T, D>(fetcher: (D) -> FetchResult<T>, deps: D): Resource<T>
        where T <: Equatable<T>, D <: Equatable<D> {
        let (state, setState) = useAsyncState<Resource<T>>(Resource<T>.ResLoading)
        let generation = useRef<Generation>(Generation())

        // Capture only reference cells / values that can escape: the Generation
        // cell, the AsyncSetState (a class), the fetcher, and the deps value.
        let gen = generation.value
        let depsForThread = deps
        let setForThread = setState
        let fetch = fetcher
        useEffect<D>(deps, { =>
            let myGen = gen.advance()
            setForThread.call(Resource<T>.ResLoading)
            let _ = spawn {
                let result = fetch(depsForThread)
                if (gen.isCurrent(myGen)) {
                    match (result) {
                        case Ok(value) => setForThread.call(Resource<T>.ResReady(value))
                        case Err(e) => setForThread.call(Resource<T>.ResError(e))
                    }
                }
            }
        })

        state
    }

    // Mutation hook for async write operations. Returns the current mutation
    // state and a trigger to fire writes from event handlers.
    public func useMutation<T>(): (MutationState<T>, MutationTrigger<T>)
        where T <: Equatable<T> {
        let (state, setState) = useAsyncState<MutationState<T>>(MutationState<T>.MutIdle)
        let trigger = MutationTrigger<T>(setState)
        (state, trigger)
    }
}

// ─── MutationTrigger ─────────────────────────────────────────────────────────

public class MutationTrigger<T> where T <: Equatable<T> {
    let setState: AsyncSetState<MutationState<T>>

    init(setState: AsyncSetState<MutationState<T>>) {
        this.setState = setState
    }

    // Fire a mutation on a background thread; transitions Loading -> Success/Error.
    public func fire(f: () -> FetchResult<T>): Unit {
        let set = setState
        set.call(MutationState<T>.MutLoading)
        let _ = spawn {
            let result = f()
            match (result) {
                case Ok(data) => set.call(MutationState<T>.MutSuccess(data))
                case Err(e) => set.call(MutationState<T>.MutError(e))
            }
        }
    }

    // Reset the mutation state back to Idle (e.g. after showing success).
    public func reset(): Unit {
        setState.call(MutationState<T>.MutIdle)
    }
}
