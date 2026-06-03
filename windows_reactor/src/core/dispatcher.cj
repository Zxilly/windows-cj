package windows_reactor.core

import std.collection.*
import std.sync.*

// ============================================================================
// Dispatcher — schedules deferred work onto a render-aware queue (typically
// the UI thread). The reconciler / render host enqueue render loops here so
// many render requests coalesce into a single pass. Two priority lanes mirror
// the reference (Normal, Low) so a re-render kicked while rendering is queued
// behind the current pass but ahead of nothing.
// ============================================================================

public enum DispatchPriority <: Equatable<DispatchPriority> {
    | Normal | Low

    public func tag(): Int64 {
        match (this) {
            case Normal => 0
            case Low => 1
        }
    }

    public operator func ==(other: DispatchPriority): Bool { tag() == other.tag() }
    public operator func !=(other: DispatchPriority): Bool { tag() != other.tag() }
}

// Schedules deferred (same-thread) work. Returns false when the queue refuses
// the item (e.g. the underlying UI queue is shutting down); callers treat a
// false result as "the render did not get scheduled" and reset their state.
public interface Dispatcher {
    func enqueue(priority: DispatchPriority, work: () -> Unit): Bool
}

// Thread-safe variant accepting work that may be produced off the UI thread.
// Implementations marshal the closure back onto the UI thread before running
// it. Backs AsyncSetState / use_async_state state writes.
public interface SendDispatcher {
    func enqueueSend(priority: DispatchPriority, work: () -> Unit): Bool
}

// ============================================================================
// UI_RERENDER — the UI thread's rerender hook, installed by the render host's
// setMarshaller(). WinUI is STA single-threaded, so a module-level cell is the
// behaviour-equivalent of the reference thread_local: at most one host per UI
// thread publishes its request_render here, and off-thread async writes call
// requestUiRerenderOnUiThread() (after marshalling) to pump a frame.
// ============================================================================

class UiRerenderCell {
    var hook: ?(() -> Unit) = None
}

let uiRerenderCell = UiRerenderCell()

// Install (or clear, with None) the UI thread's rerender hook.
public func setUiRerender(rerender: ?(() -> Unit)): Unit {
    uiRerenderCell.hook = rerender
}

// Request a rerender on the UI thread the marshaller targets. No-op when no
// host has published a hook.
public func requestUiRerenderOnUiThread(): Unit {
    match (uiRerenderCell.hook) {
        case Some(rr) => rr()
        case None => ()
    }
}

// ============================================================================
// UiMarshaller — clonable handle to the UI thread's render-aware dispatcher.
// AsyncSetState uses it to marshal state writes (which may originate on a
// background thread) back onto the UI thread. GC-managed reference type; no Arc
// needed — sharing the same instance is sharing the same SendDispatcher.
// ============================================================================

public class UiMarshaller {
    let inner: SendDispatcher

    public init(inner: SendDispatcher) {
        this.inner = inner
    }

    // Schedule f to run on the UI thread at normal priority.
    public func dispatch(f: () -> Unit): Bool {
        inner.enqueueSend(DispatchPriority.Normal, f)
    }

    // Schedule f to run on the UI thread at low priority.
    public func dispatchLow(f: () -> Unit): Bool {
        inner.enqueueSend(DispatchPriority.Low, f)
    }
}

// ============================================================================
// RunOnDemandDispatcher — in-process Dispatcher that buffers work until drain()
// is called. Used by headless tests and Application::run_once. Normal lane is
// always preferred over Low; work enqueued while draining (e.g. a Normal
// follow-up pushed by a Low item) is promoted ahead of the remaining Low items
// because each drain step re-checks the Normal lane first.
// ============================================================================

public class RunOnDemandDispatcher <: Dispatcher {
    let normal = ArrayList<() -> Unit>()
    let low = ArrayList<() -> Unit>()

    public init() {}

    public func pending(): Int64 { normal.size + low.size }

    public func enqueue(priority: DispatchPriority, work: () -> Unit): Bool {
        match (priority) {
            case Normal => normal.add(work)
            case Low => low.add(work)
        }
        true
    }

    // Run buffered work to completion, Normal-before-Low, re-checking the
    // Normal lane each step so freshly-enqueued Normal work jumps the queue.
    // Returns the number of closures fired.
    public func drain(): Int64 {
        var fired: Int64 = 0
        while (true) {
            let item = popNext()
            match (item) {
                case Some(f) =>
                    f()
                    fired = fired + 1
                case None => break
            }
        }
        fired
    }

    func popNext(): ?(() -> Unit) {
        if (normal.size > 0) {
            let f = normal[0]
            normal.remove(at: 0)
            return Some(f)
        }
        if (low.size > 0) {
            let f = low[0]
            low.remove(at: 0)
            return Some(f)
        }
        None
    }
}

// ============================================================================
// ChannelDispatcher — thread-safe SendDispatcher used by tests to exercise the
// async / marshalling path without a real UI queue. Closures are buffered under
// a mutex; drain() runs them (single-threaded, Normal before Low).
// ============================================================================

public class ChannelDispatcher <: SendDispatcher {
    let lock = Mutex()
    let normal = ArrayList<() -> Unit>()
    let low = ArrayList<() -> Unit>()

    public init() {}

    public func enqueueSend(priority: DispatchPriority, work: () -> Unit): Bool {
        synchronized(lock) {
            match (priority) {
                case Normal => normal.add(work)
                case Low => low.add(work)
            }
        }
        true
    }

    public func pending(): Int64 {
        synchronized(lock) {
            normal.size + low.size
        }
    }

    // Drain all buffered closures, Normal-before-Low. Closures run outside the
    // lock so they may legally re-enqueue.
    public func drain(): Int64 {
        var fired: Int64 = 0
        while (true) {
            let item = popNextLocked()
            match (item) {
                case Some(f) =>
                    f()
                    fired = fired + 1
                case None => break
            }
        }
        fired
    }

    func popNextLocked(): ?(() -> Unit) {
        synchronized(lock) {
            if (normal.size > 0) {
                let f = normal[0]
                normal.remove(at: 0)
                return Some(f)
            }
            if (low.size > 0) {
                let f = low[0]
                low.remove(at: 0)
                return Some(f)
            }
            return None
        }
    }

    // Convenience: a UiMarshaller backed by this dispatcher.
    public func marshaller(): UiMarshaller {
        UiMarshaller(this)
    }
}
