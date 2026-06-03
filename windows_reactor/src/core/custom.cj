package windows_reactor.core

// ============================================================================
// Custom elements — the extension hatch for downstream widgets that aren't part
// of the core Element enum. The CustomElement interface (element_carriers.cj) is
// the full imperative surface the reconciler drives: identity (kindName / key /
// customTypeId), mount(backend), update(prev, id, backend), eqDyn(other),
// cloneDyn(), and beforeDestroy(id, backend). This file provides the stable
// type-token minter and the structural-equivalence helper.
// ============================================================================

// Mint stable per-custom-type tokens, the value a CustomElement returns from
// customTypeId() (behaviour-equivalent of the reference TypeId). Mint one per
// custom widget type and reuse it.
let customTypeTokenCounter = CallbackIdCounter()

public func newCustomTypeToken(): UInt64 {
    customTypeTokenCounter.allocate()
}

// True when the reconciler can skip diffing two custom elements: same type id,
// same key, and structurally equal.
public func customElementEquivalent(a: CustomElement, b: CustomElement): Bool {
    if (a.customTypeId() != b.customTypeId()) {
        return false
    }
    if (!optStrEq(a.key(), b.key())) {
        return false
    }
    a.eqDyn(b)
}
