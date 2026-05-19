package windows_variant

func releaseVariantStorageNoThrow(storage: VARIANT, closed: Bool): Unit {
    if (closed || variantVt(storage) == VT_EMPTY) {
        return
    }
    try {
        var slot = storage
        let slotPtr = unsafe { CPointer<VARIANT>(inout slot) }
        let _ = variantClear(slotPtr)
    } catch (_: Exception) {}
}

func releaseVariantStorage(storage: VARIANT, closed: Bool): Unit {
    if (closed || variantVt(storage) == VT_EMPTY) {
        return
    }
    var slot = storage
    let slotPtr = unsafe { CPointer<VARIANT>(inout slot) }
    let hr = variantClear(slotPtr)
    if (hr < 0) {
        throw VariantAbiException("VariantClear failed with HRESULT ${hr}")
    }
}

/// Variant — owning wrapper around a 24-byte VARIANT value that releases its
/// payload (BSTR / IUnknown / IDispatch / SAFEARRAY) on explicit close.
///
/// VARIANT itself is an `@C struct` and cannot implement an interface, so this
/// class provides the Cangjie owning resource boundary.
public class Variant <: Resource {
    private var storage: VARIANT = VARIANT()
    private var closed: Bool = false
    private var closing: Bool = false

    public init() {}

    /// Take ownership of an already-initialised VARIANT value. The caller must
    /// no longer release the payload — this wrapper will call VariantClear on
    /// explicit close.
    public init(value: VARIANT) {
        this.storage = value
        if (variantVt(value) != VT_EMPTY) {
            ensureVariantClearAbiResolved()
        }
    }

    /// Deep-copy the supplied VARIANT via OleAut32 VariantCopy. Honors BSTR,
    /// COM interface and SAFEARRAY ref-counting / allocation semantics.
    public static func clone(source: VARIANT): Variant {
        var src = source
        let result = Variant()
        var dst = result.storage
        let dstPtr = unsafe { CPointer<VARIANT>(inout dst) }
        let srcPtr = unsafe { CPointer<VARIANT>(inout src) }
        let hr = variantCopy(dstPtr, srcPtr)
        if (hr < 0) {
            throw VariantAbiException("VariantCopy failed with HRESULT ${hr}")
        }
        result.storage = dst
        if (variantVt(result.storage) != VT_EMPTY) {
            ensureVariantClearAbiResolved()
        }
        return result
    }

    public func get(): VARIANT {
        if (closed) {
            return VARIANT()
        }
        storage
    }

    public func vt(): VARENUM {
        if (closed) {
            return VT_EMPTY
        }
        variantVt(storage)
    }

    public func isEmpty(): Bool {
        if (closed) {
            return true
        }
        variantIsEmpty(storage)
    }

    public func cloneSelf(): Variant {
        if (closed) {
            return Variant()
        }
        Variant.clone(storage)
    }

    /// Replace the wrapped value, releasing the prior payload first.
    public func reset(value: VARIANT): Unit {
        if (closed) {
            throw VariantAbiException("Variant is already closed")
        }
        if (closing) {
            throw VariantAbiException("Variant is already closing")
        }
        closing = true
        try {
            releaseVariantStorage(storage, false)
            storage = value
            if (variantVt(value) != VT_EMPTY) {
                ensureVariantClearAbiResolved()
            }
        } finally {
            closing = false
        }
    }

    /// Transfer the inner VARIANT to the caller, who becomes responsible for
    /// VariantClear. The wrapper becomes closed.
    public func intoRaw(): VARIANT {
        let value = storage
        storage = VARIANT()
        closed = true
        value
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed || closing) {
            return
        }
        closing = true
        try {
            releaseVariantStorage(storage, false)
            closed = true
            storage = VARIANT()
        } finally {
            closing = false
        }
    }

    ~init() {
        closed = true
        closing = false
        storage = VARIANT()
    }
}
