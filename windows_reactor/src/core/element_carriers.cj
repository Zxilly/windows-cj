package windows_reactor.core

import std.collection.*

// Non-widget Element carriers. These are the composition variants of the
// Element tree. The Foundation defined the minimal identity/key shapes; the
// Engines (hooks + reconciler) phase WIDENS the component / custom / provider
// carriers in place with the behaviour the reconciler drives (render against a
// RenderCx, structural equivalence, lifecycle, imperative mount/update, and the
// context-provision list). This widening is the agreed Engines-B surface — the
// reconciler (reconciler.cj / reconciler_wrappers.cj) is written against exactly
// these method/field names.

// Fragment flattened into its parent's child list during reconciliation.
public class GroupElement {
    public var key: ?String = None
    public var children: Array<Element>

    public init(children: Array<Element>) {
        this.children = children
    }

    public func withKey(k: String): GroupElement {
        this.key = Some(k)
        this
    }
}

public func group(children: Array<Element>): Element {
    Element.GroupEl(GroupElement(children))
}

// A user component object: renders to an Element tree given a render context.
// The reconciler carries this through ComponentElement.obj and drives it.
// componentTypeId() is the mount-vs-update identity (behaviour-equivalent of the
// reference TypeId); the remaining methods are the render / equivalence /
// lifecycle surface the reconciler invokes (see ComponentCell in
// component_element.cj for the concrete adapter).
public interface ComponentObject {
    func componentTypeId(): UInt64

    // Render the component's current props against its (per-instance) RenderCx.
    func render(cx: RenderCx): Element

    // Structural equivalence used by the memoised path: same type + equal props.
    func isEquivalent(other: ComponentObject): Bool

    // Whether the non-memoised path must re-render against the latest object.
    func shouldUpdate(other: ComponentObject): Bool

    // Lifecycle hooks (gated by hasOn* so the reconciler can skip the call).
    func invokeAppeared(cx: RenderCx): Unit
    func invokeDisappeared(cx: RenderCx): Unit
    func hasOnAppeared(): Bool
    func hasOnDisappeared(): Bool
}

public class ComponentElement {
    public var key: ?String = None
    public let obj: ComponentObject
    // True when the component is memoised: reuse prior output when props compare
    // equal (reconciler reads this in updateComponent).
    public var memoised: Bool = false

    public init(obj: ComponentObject) {
        this.obj = obj
    }

    public init(obj: ComponentObject, memoised: Bool) {
        this.obj = obj
        this.memoised = memoised
    }
}

// Error boundary: renders children, falling back to a fallback element when a
// child render throws (Engines maps the reference catch_unwind to try/catch).
public class ErrorBoundaryElement {
    public var key: ?String = None
    public var child: Element
    public var fallback: (String) -> Element

    public init(child: Element, fallback: (String) -> Element) {
        this.child = child
        this.fallback = fallback
    }
}

// Context provider: provides one or more typed values to descendants. The
// reconciler pushes each provision onto the ContextStack while mounting/updating
// the child subtree and force-rerenders dependent components when a provision
// value changes.
public class ProviderElement {
    public var key: ?String = None
    public var child: Element
    public var provisions: ArrayList<ContextProvision>

    public init(child: Element, provisions: ArrayList<ContextProvision>) {
        this.child = child
        this.provisions = provisions
    }

    // Convenience single-provision constructor.
    public init(provision: ContextProvision, child: Element) {
        this.child = child
        this.provisions = ArrayList<ContextProvision>()
        this.provisions.add(provision)
    }
}

// Custom element: imperatively mounted/updated subtree owned by the user.
// Engines drives mount/update/beforeDestroy; identity is via customTypeId().
public interface CustomElement {
    func kindName(): String
    func key(): ?String
    func customTypeId(): UInt64

    // Create the underlying control via `backend` and return its id.
    func mount(backend: Backend): ControlId

    // Apply the diff from `prev` (same customTypeId) to the live control `id`.
    func update(prev: CustomElement, id: ControlId, backend: Backend): Unit

    // Structural equality against another custom element of the same type id;
    // returning false is always safe but skips an update short-circuit.
    func eqDyn(other: CustomElement): Bool

    // Boxed clone so the reconciler can retain the handle across renders.
    func cloneDyn(): CustomElement

    // Hook fired just before Backend.destroy; defaults to no-op.
    func beforeDestroy(id: ControlId, backend: Backend): Unit {
        let _ = id
        let _ = backend
    }
}
