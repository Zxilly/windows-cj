package windows_reactor.core

// ============================================================================
// Component object adapter + component()/memo() factories.
//
// The Element carrier `ComponentElement` (element_carriers.cj) holds an erased
// `obj: ComponentObject`. The reconciler drives that object directly:
// obj.render(cx), obj.isEquivalent(other), obj.shouldUpdate(other),
// obj.invokeAppeared/Disappeared(cx), obj.hasOnAppeared/Disappeared(),
// obj.componentTypeId(). `ComponentCell<P>` is the concrete adapter wrapping a
// Component<P> + its props.
//
// Cangjie has no TypeId::of::<C>(); the reference's per-type identity is modelled
// by an explicit, stable type token the caller mints once per component type via
// newComponentTypeToken(). This token drives mount-vs-update identity and is the
// value returned by componentTypeId(). Props equivalence recovers the typed
// props via a runtime type match monomorphic in P (no cross-type downcast).
// ============================================================================

// Monotonic minting of per-component-type tokens (behaviour-equivalent of
// TypeId::of::<C>()). Mint one module-level token per component type and reuse it
// across all component()/memo() calls for that type.
let componentTypeTokenCounter = CallbackIdCounter()

public func newComponentTypeToken(): UInt64 {
    componentTypeTokenCounter.allocate()
}

// The concrete erased cell: a Component<P> + its props + the type token.
public class ComponentCell<P> <: ComponentObject where P <: Equatable<P> {
    let component: Component<P>
    let props: P
    let typeToken: UInt64

    public init(component: Component<P>, props: P, typeToken: UInt64) {
        this.component = component
        this.props = props
        this.typeToken = typeToken
    }

    public func componentTypeId(): UInt64 { typeToken }

    public func render(cx: RenderCx): Element {
        component.render(props, cx)
    }

    // Recover the other object's props for comparison: returns true iff `other`
    // carries the same type token and props that compare equal.
    func sameProps(other: ComponentObject): Bool {
        if (other.componentTypeId() != typeToken) {
            return false
        }
        // Same token guarantees the same P at every call site; recover via a
        // runtime type match (monomorphic in P at this site).
        match (other) {
            case o: ComponentCell<P> => props == o.props
            case _ => false
        }
    }

    public func isEquivalent(other: ComponentObject): Bool {
        sameProps(other)
    }

    public func shouldUpdate(other: ComponentObject): Bool {
        if (other.componentTypeId() != typeToken) {
            return true
        }
        match (other) {
            case o: ComponentCell<P> => component.shouldUpdate(props, o.props)
            case _ => true
        }
    }

    public func invokeAppeared(cx: RenderCx): Unit {
        component.onAppeared(props, cx)
    }

    public func invokeDisappeared(cx: RenderCx): Unit {
        component.onDisappeared(props, cx)
    }

    public func hasOnAppeared(): Bool { component.hasOnAppeared() }
    public func hasOnDisappeared(): Bool { component.hasOnDisappeared() }
}

// ─── Factories ───────────────────────────────────────────────────────────────

// Wrap a Component<P> + props into an Element. `typeToken` is the caller's
// stable per-type identity (see newComponentTypeToken()).
public func component<P>(comp: Component<P>, props: P, typeToken: UInt64): Element
    where P <: Equatable<P> {
    let cell = ComponentCell<P>(comp, props, typeToken)
    Element.ComponentEl(ComponentElement(cell, false))
}

// Like component(), but memoised: the reconciler reuses the previous render
// output when props compare equal.
public func memo<P>(comp: Component<P>, props: P, typeToken: UInt64): Element
    where P <: Equatable<P> {
    let cell = ComponentCell<P>(comp, props, typeToken)
    Element.ComponentEl(ComponentElement(cell, true))
}

// Convenience: wrap a bare `(P, RenderCx) -> Element` closure.
public func component<P>(body: (P, RenderCx) -> Element, props: P, typeToken: UInt64): Element
    where P <: Equatable<P> {
    component<P>(FnComponent<P>(body), props, typeToken)
}

public func memo<P>(body: (P, RenderCx) -> Element, props: P, typeToken: UInt64): Element
    where P <: Equatable<P> {
    memo<P>(FnComponent<P>(body), props, typeToken)
}

// Stable token reused for all unit-prop root components.
let rootComponentToken = newComponentTypeToken()

// Build a ComponentObject from a bare unit-prop render closure, suitable as the
// RenderHost root (the host renders a ComponentObject, not an Element).
public func rootComponent(body: (RenderCx) -> Element): ComponentObject {
    ComponentCell<NoProps>(
        FnComponent<NoProps>({ _: NoProps, cx: RenderCx => body(cx) }),
        NoProps(),
        rootComponentToken
    )
}
