package windows_propvariant

func releasePropVariantStorageNoThrow(storage: PROPVARIANT, closed: Bool): Unit {
    if (closed || propVariantVt(storage) == VT_EMPTY) {
        return
    }
    try {
        var slot = storage
        let slotPtr = unsafe { CPointer<PROPVARIANT>(inout slot) }
        let _ = propVariantClear(slotPtr)
    } catch (_: Exception) {}
}

/// PropVariant — owning wrapper around a 24-byte PROPVARIANT value that
/// releases its payload (BSTR / IUnknown / IDispatch / SAFEARRAY / LPSTR /
/// LPWSTR / CLSID / STREAM / STORAGE / ...) on close or finalization.
///
/// PROPVARIANT itself is an `@C struct` and cannot implement an interface;
/// this class provides the Cangjie-equivalent free behaviour via
/// PropVariantClear.
public class PropVariant <: Resource {
    private var storage: PROPVARIANT = PROPVARIANT()
    private var closed: Bool = false

    public init() {}

    /// Take ownership of an already-initialised PROPVARIANT value. The caller
    /// must no longer release the payload — this wrapper will call
    /// PropVariantClear on close / finalisation.
    public init(value: PROPVARIANT) {
        this.storage = value
        if (propVariantVt(value) != VT_EMPTY) {
            ensurePropVariantClearAbiResolved()
        }
    }

    /// Deep-copy the supplied PROPVARIANT via ole32 PropVariantCopy. Honors
    /// BSTR, COM interface, SAFEARRAY and CoTaskMem allocation semantics.
    public static func clone(source: PROPVARIANT): PropVariant {
        var src = source
        let result = PropVariant()
        var dst = result.storage
        let dstPtr = unsafe { CPointer<PROPVARIANT>(inout dst) }
        let srcPtr = unsafe { CPointer<PROPVARIANT>(inout src) }
        let hr = propVariantCopy(dstPtr, srcPtr)
        if (hr < 0) {
            throw PropVariantAbiException("PropVariantCopy failed with HRESULT ${hr}")
        }
        result.storage = dst
        if (propVariantVt(result.storage) != VT_EMPTY) {
            ensurePropVariantClearAbiResolved()
        }
        return result
    }

    public func get(): PROPVARIANT {
        if (closed) {
            return PROPVARIANT()
        }
        storage
    }

    public func vt(): VARENUM {
        if (closed) {
            return VT_EMPTY
        }
        propVariantVt(storage)
    }

    public func isEmpty(): Bool {
        if (closed) {
            return true
        }
        propVariantIsEmpty(storage)
    }

    public func cloneSelf(): PropVariant {
        if (closed) {
            return PropVariant()
        }
        PropVariant.clone(storage)
    }

    /// Replace the wrapped value, releasing the prior payload first.
    public func reset(value: PROPVARIANT): Unit {
        if (closed) {
            throw PropVariantAbiException("PropVariant is already closed")
        }
        releasePropVariantStorageNoThrow(storage, false)
        storage = value
        if (propVariantVt(value) != VT_EMPTY) {
            ensurePropVariantClearAbiResolved()
        }
    }

    /// Transfer the inner PROPVARIANT to the caller, who becomes responsible
    /// for PropVariantClear. The wrapper becomes closed.
    public func intoRaw(): PROPVARIANT {
        let value = storage
        storage = PROPVARIANT()
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
        releasePropVariantStorageNoThrow(storage, false)
        storage = PROPVARIANT()
        closed = true
    }

    ~init() {
        if (!closed) {
            releasePropVariantStorageNoThrow(storage, false)
            storage = PROPVARIANT()
            closed = true
        }
    }
}
