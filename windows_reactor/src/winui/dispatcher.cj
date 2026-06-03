package windows_reactor.winui

import windows_reactor.core.{Dispatcher, SendDispatcher, DispatchPriority, UiMarshaller}
import windows_common.Microsoft.UI.Dispatching.{DispatcherQueue, DispatcherQueueHandler}

// ============================================================================
// WinUIDispatcher — drives the RenderHost render loop onto the WinUI UI thread
// via DispatcherQueue.TryEnqueue. The projection emits a managed
// DispatcherQueueHandler from a Cangjie closure (DispatcherQueueHandler.new),
// so no hand-written thunk is required. WinUI is STA single-threaded; the same
// queue backs both the same-thread Dispatcher path and the cross-thread
// SendDispatcher path (TryEnqueue itself is agile/thread-safe).
// ============================================================================

public class WinUIDispatcher <: Dispatcher & SendDispatcher {
    private let queue: DispatcherQueue

    public init(queue: DispatcherQueue) {
        this.queue = queue
    }

    // Capture the calling thread's DispatcherQueue. Must be called on the UI
    // thread (inside the Application launch callback).
    public static func forCurrentThread(): WinUIDispatcher {
        WinUIDispatcher(DispatcherQueue.GetForCurrentThread())
    }

    public func marshaller(): UiMarshaller {
        UiMarshaller(this)
    }

    private func tryEnqueue(work: () -> Unit): Bool {
        // DispatcherQueueHandler.new is a Cangjie CCW (allocates a native vtable + roots
        // itself in the COM registry while its refcount > 0). TryEnqueue AddRefs it; once
        // we drop OUR wrapper ref the queue is the sole owner, and the CCW is freed when
        // the queue invokes+releases it. Without this close() every render loop leaks a
        // CCW (native vtable + a permanent registry root) — a steady per-navigation leak.
        let handler = DispatcherQueueHandler.new(work)
        try {
            return queue.TryEnqueue(handler)
        } catch (_: Exception) {
            return false
        } finally {
            handler.close()
        }
    }

    public func enqueue(priority: DispatchPriority, work: () -> Unit): Bool {
        let _ = priority
        tryEnqueue(work)
    }

    public func enqueueSend(priority: DispatchPriority, work: () -> Unit): Bool {
        let _ = priority
        tryEnqueue(work)
    }
}
