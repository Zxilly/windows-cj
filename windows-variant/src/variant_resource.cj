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

/// Variant — owning wrapper around a 24-byte VARIANT value that releases its
/// payload (BSTR / IUnknown / IDispatch / SAFEARRAY) on close or finalization.
///
/// VARIANT itself is an `@C struct` and cannot implement an interface; this
/// class is the Cangjie-equivalent of Rust's `impl Free for VARIANT`.
public class Variant <: Resource {
    private var storage: VARIANT = VARIANT()
    private var closed: Bool = false

    public init() {}

    /// Take ownership of an already-initialised VARIANT value. The caller must
    /// no longer release the payload — this wrapper will call VariantClear on
    /// close / finalisation.
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
        releaseVariantStorageNoThrow(storage, false)
        storage = value
        if (variantVt(value) != VT_EMPTY) {
            ensureVariantClearAbiResolved()
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
        if (closed) {
            return
        }
        releaseVariantStorageNoThrow(storage, false)
        storage = VARIANT()
        closed = true
    }

    ~init() {
        if (!closed) {
            releaseVariantStorageNoThrow(storage, false)
            storage = VARIANT()
            closed = true
        }
    }
}

