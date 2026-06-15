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
        //
        // The closure MUST NOT let anything escape into the CCW thunk: the
        // generated __winrtThunk_Invoke converts an Exception into a FAILING
        // HRESULT returned to the DispatcherQueue (lifted CoreMessaging
        // fail-fasts on a failed dispatch callback — CFlat::Abandonment inside
        // CoreMessagingXP, exception code 0xe0464645), and a Cangjie Error is
        // not caught at all and unwinds straight through the native frames.
        let handler = DispatcherQueueHandler.new({ =>
            try {
                work()
            } catch (e: Exception) {
                println("WinUIDispatcher: dispatched work threw: ${e}")
                e.printStackTrace()
            } catch (e: Error) {
                println("WinUIDispatcher: dispatched work raised error: ${e}")
                e.printStackTrace()
            }
        })
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
