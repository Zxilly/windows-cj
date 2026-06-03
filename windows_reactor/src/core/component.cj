package windows_reactor.core

// ============================================================================
// Component<P> — a stateless render unit parameterised by props P. Implementors
// return an Element tree from render(); the host re-invokes render when
// shouldUpdate returns true for the latest props. on_appeared / on_disappeared
// are optional lifecycle hooks (gated by hasOnAppeared / hasOnDisappeared so
// the reconciler can skip the call entirely).
//
// P is constrained Equatable so the default shouldUpdate can compare props.
// Function-style components (a bare render closure) are wrapped by FnComponent.
// ============================================================================

public interface Component<P> where P <: Equatable<P> {
    func render(props: P, cx: RenderCx): Element

    func shouldUpdate(oldProps: P, newProps: P): Bool {
        oldProps != newProps
    }

    func hasOnAppeared(): Bool { false }
    func hasOnDisappeared(): Bool { false }

    func onAppeared(props: P, cx: RenderCx): Unit {
        let _ = props
        let _ = cx
    }

    func onDisappeared(props: P, cx: RenderCx): Unit {
        let _ = props
        let _ = cx
    }
}

// Adapter so a bare `(P, RenderCx) -> Element` closure can be used as a
// Component<P> (replaces the reference blanket impl for Fn). Pass it to
// component()/memo() like any other component.
public class FnComponent<P> <: Component<P> where P <: Equatable<P> {
    let body: (P, RenderCx) -> Element

    public init(body: (P, RenderCx) -> Element) {
        this.body = body
    }

    public func render(props: P, cx: RenderCx): Element {
        body(props, cx)
    }
}

// Props placeholder for unit-prop components. Equatable so it satisfies the
// Component<P> constraint; all instances compare equal.
public struct NoProps <: Equatable<NoProps> {
    public init() {}
    public operator func ==(other: NoProps): Bool { let _ = other; true }
    public operator func !=(other: NoProps): Bool { let _ = other; false }
}
