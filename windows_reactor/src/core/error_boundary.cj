package windows_reactor.core

// ============================================================================
// Error boundary. The carrier (ErrorBoundaryElement in element_carriers.cj)
// holds a child Element and a fallback (String) -> Element. The reference caught
// descendant *panics* via catch_unwind; Cangjie has no unwind catch, so the
// equivalent is a try/catch around the render that produced/updated the child.
// This is a deliberate paradigm mapping (panic -> Exception): every component
// render error path is funnelled through thrown Exceptions, and the boundary
// converts a caught Exception's message into the fallback subtree.
// ============================================================================

// Build an ErrorBoundary element wrapping `child`, using `fallback` to recover.
public func errorBoundary(child: Element, fallback: (String) -> Element): Element {
    Element.ErrorBoundaryEl(ErrorBoundaryElement(child, fallback))
}

// Same, with an explicit key for keyed reconciliation.
public func errorBoundaryKeyed(key: String, child: Element, fallback: (String) -> Element): Element {
    let eb = ErrorBoundaryElement(child, fallback)
    eb.key = Some(key)
    Element.ErrorBoundaryEl(eb)
}

// Extract a human-readable message from a caught exception (behaviour-equivalent
// of the reference panic_message payload sniffing).
public func panicMessage(e: Exception): String {
    let m = e.message
    if (m.size == 0) {
        return "<non-string panic>"
    }
    m
}

// Run `body` (which produces an Element subtree, e.g. mounting/rendering the
// boundary's child), catching any thrown Exception and converting it to the
// fallback subtree. This is the primitive the reconciler calls in place of
// catch_unwind; it returns the recovered Element on error so the boundary always
// yields a renderable subtree.
public func guardRender(body: () -> Element, fallback: (String) -> Element): Element {
    try {
        body()
    } catch (e: Exception) {
        fallback(panicMessage(e))
    }
}

// Like guardRender, but for side-effecting work that may produce an optional
// control id (e.g. reconciler mount returning ?ControlId). On error the boundary
// renders the fallback via `onError` and returns its result instead.
public func guardMount<R>(body: () -> R, onError: (String) -> R): R {
    try {
        body()
    } catch (e: Exception) {
        onError(panicMessage(e))
    }
}
