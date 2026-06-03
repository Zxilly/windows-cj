package windows_reactor.winui

// ============================================================================
// Event thunks — shared event-subscription infrastructure.
//
// The projection layer already emits fully-managed COM delegate objects from
// Cangjie closures (e.g. `RoutedEventHandler.new(invoke)`), with the
// exception→HRESULT translation built into the generated invoker. So the
// minimal backend does NOT hand-write @C vtable thunks: it wraps the
// reconciler's EventHandler in the appropriate delegate type and registers it
// through the high-level `addX`/`removeX` event accessors. See `event_button.cj`
// (Click) for the canonical wiring sample.
//
// EventRevoker (<: Resource) owns ONE registration as an opaque revoke closure.
// The closure captures whatever it needs (target projection + token + delegate)
// and, when invoked, unregisters the handler and releases the captured COM
// projections. close() runs it at most once, guarding double-free with a
// `closed` flag (spec §8.5). Family wiring functions return zero or more of
// these; the backend stores them per (control, event) and closes them on
// detach / destroy.
// ============================================================================

public class EventRevoker <: Resource {
    private var revoke: ?(() -> Unit) = None
    private var closed: Bool = false

    public init(revoke: () -> Unit) {
        this.revoke = Some(revoke)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (!closed) {
            closed = true
            match (revoke) {
                case Some(f) =>
                    // Unregistering on a torn-down control can fail; swallow so
                    // teardown never throws across the FFI boundary.
                    try {
                        f()
                    } catch (_: Exception) {
                        ()
                    }
                case None => ()
            }
            revoke = None
        }
    }

    ~init() {
        revoke = None
        closed = true
    }
}
