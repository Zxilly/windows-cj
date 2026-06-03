package windows_safearray

import windows_variant.VARIANT
import windows_variant as variant

func destroySafeArrayNoThrow(handle: CPointer<SAFEARRAY>, closed: Bool): Unit {
    try {
        let _ = closeSafeArrayState(handle, closed)
    } catch (_: Exception) {}
}

func closeSafeArrayState(handle: CPointer<SAFEARRAY>, closed: Bool): (CPointer<SAFEARRAY>, Bool) {
    if (closed || handle.isNull()) {
        return (CPointer<SAFEARRAY>(), true)
    }
    let hr = safeArrayDestroy(handle)
    if (hr < 0) {
        throw SafeArrayAbiException("SafeArrayDestroy failed with HRESULT ${hr}")
    }
    (CPointer<SAFEARRAY>(), true)
}

func takeSafeArrayCopyResult(hr: Int32, slot: CPointer<SAFEARRAY>): SafeArray {
    if (hr < 0) {
        destroySafeArrayNoThrow(slot, false)
        throw SafeArrayAbiException("SafeArrayCopy failed with HRESULT ${hr}")
    }
    if (slot.isNull()) {
        throw SafeArrayAbiException("SafeArrayCopy returned null")
    }
    SafeArray(slot)
}

/// SafeArray — owning wrapper around a SAFEARRAY descriptor pointer. Calls
/// SafeArrayDestroy on explicit close, which releases the descriptor,
/// the contained data block, and any contained reference-counted elements
/// (BSTR / IUnknown / IDispatch / VARIANT).
///
/// SAFEARRAY itself is an `@C struct` and cannot implement an interface; this
/// class is the Cangjie equivalent of an owning smart pointer.
public class SafeArray <: Resource {
    var handle: CPointer<SAFEARRAY> = CPointer<SAFEARRAY>()
    private var closed: Bool = false
    private var closing: Bool = false

    public init() {}

    /// Take ownership of an already-allocated SAFEARRAY descriptor.
    public init(raw: CPointer<SAFEARRAY>) {
        this.handle = raw
        if (raw.isNotNull()) {
            ensureSafeArrayDestroyAbiResolved()
        }
    }

    public static func createVector(vt: UInt16, lowerBound: Int32, elements: UInt32): SafeArray {
        let raw = safeArrayCreateVector(vt, lowerBound, elements)
        SafeArray(raw)
    }

    public static func create(vt: UInt16, bounds: Array<SAFEARRAYBOUND>): SafeArray {
        if (bounds.isEmpty()) {
            throw SafeArrayAbiException("SafeArray.create requires at least one bound")
        }
        var local = bounds.clone()
        unsafe {
            let boundsHandle = acquireArrayRawData(local)
            try {
                let raw = safeArrayCreate(vt, UInt32(local.size), boundsHandle.pointer)
                return SafeArray(raw)
            } finally {
                releaseArrayRawData(boundsHandle)
            }
        }
    }

    public func get(): CPointer<SAFEARRAY> {
        if (closed) {
            return CPointer<SAFEARRAY>()
        }
        handle
    }

    public func isClosed(): Bool {
        closed
    }

    public func isNull(): Bool {
        closed || handle.isNull()
    }

    public func dim(): UInt32 {
        if (isNull()) {
            return 0u32
        }
        safeArrayGetDimAbi(handle)
    }

    public func lbound(dimension: UInt32): Int32 {
        if (isNull()) {
            throw SafeArrayAbiException("SafeArray.lbound on closed/null handle")
        }
        var slot: Int32 = 0
        let slotPtr = unsafe { CPointer<Int32>(inout slot) }
        let hr = safeArrayGetLBoundAbi(handle, dimension, slotPtr)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayGetLBound failed with HRESULT ${hr}")
        }
        slot
    }

    public func ubound(dimension: UInt32): Int32 {
        if (isNull()) {
            throw SafeArrayAbiException("SafeArray.ubound on closed/null handle")
        }
        var slot: Int32 = 0
        let slotPtr = unsafe { CPointer<Int32>(inout slot) }
        let hr = safeArrayGetUBoundAbi(handle, dimension, slotPtr)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayGetUBound failed with HRESULT ${hr}")
        }
        slot
    }

    /// Number of elements along the first dimension (ubound - lbound + 1).
    public func length(): Int64 {
        if (isNull()) {
            return 0
        }
        let lo = lbound(1u32)
        let hi = ubound(1u32)
        Int64(hi - lo + 1)
    }

    public func vartype(): UInt16 {
        if (isNull()) {
            return 0u16
        }
        var slot: UInt16 = 0
        let slotPtr = unsafe { CPointer<UInt16>(inout slot) }
        let hr = safeArrayGetVartypeAbi(handle, slotPtr)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayGetVartype failed with HRESULT ${hr}")
        }
        slot
    }

    public func features(): UInt16 {
        if (isNull()) {
            return 0u16
        }
        safeArrayFeatures(handle)
    }

    public func elementSize(): UInt32 {
        if (isNull()) {
            return 0u32
        }
        safeArrayElementSize(handle)
    }

    public func lockCount(): UInt32 {
        if (isNull()) {
            return 0u32
        }
        safeArrayLockCount(handle)
    }

    public func lock(): Unit {
        if (isNull()) {
            throw SafeArrayAbiException("SafeArray.lock on closed/null handle")
        }
        let hr = safeArrayLock(handle)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayLock failed with HRESULT ${hr}")
        }
    }

    public func unlock(): Unit {
        if (isNull()) {
            throw SafeArrayAbiException("SafeArray.unlock on closed/null handle")
        }
        let hr = safeArrayUnlock(handle)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayUnlock failed with HRESULT ${hr}")
        }
    }

    /// Independent deep copy via SafeArrayCopy. The new SafeArray owns its
    /// own descriptor and data block.
    public func cloneSelf(): SafeArray {
        if (isNull()) {
            return SafeArray()
        }
        var slot: CPointer<SAFEARRAY> = CPointer<SAFEARRAY>()
        let slotPtr = unsafe { CPointer<CPointer<SAFEARRAY>>(inout slot) }
        let hr = safeArrayCopyAbi(handle, slotPtr)
        takeSafeArrayCopyResult(hr, slot)
    }

    /// Transfer ownership of the raw descriptor pointer to the caller.
    /// The caller is responsible for SafeArrayDestroy.
    public func intoRaw(): CPointer<SAFEARRAY> {
        let raw = handle
        handle = CPointer<SAFEARRAY>()
        closed = true
        raw
    }

    public func close(): Unit {
        if (closed || closing) {
            return
        }
        closing = true
        try {
            let (nextHandle, nextClosed) = closeSafeArrayState(handle, false)
            handle = nextHandle
            closed = nextClosed
        } finally {
            closing = false
        }
    }

    ~init() {
        destroySafeArrayNoThrow(handle, closed || closing)
        handle = CPointer<SAFEARRAY>()
        closed = true
        closing = false
    }
}

/// Lock the SafeArray for the duration of `body`, guaranteeing Unlock via
/// try-finally even if the body throws.
public func withSafeArray<R>(arr: SafeArray, body: (SafeArray) -> R): R {
    arr.lock()
    try {
        body(arr)
    } finally {
        try {
            arr.unlock()
        } catch (_: Exception) {}
    }
}

/// Acquire the raw data pointer for the duration of `body` via
/// SafeArrayAccessData / SafeArrayUnaccessData. The pointer is valid only
/// inside `body`.
public func withSafeArrayData<R>(arr: SafeArray, body: (CPointer<Unit>) -> R): R {
    if (arr.isNull()) {
        throw SafeArrayAbiException("withSafeArrayData on closed/null SafeArray")
    }
    var dataSlot: CPointer<Unit> = CPointer<Unit>()
    let slotPtr = unsafe { CPointer<CPointer<Unit>>(inout dataSlot) }
    let hr = safeArrayAccessData(arr.handle, slotPtr)
    if (hr < 0) {
        throw SafeArrayAbiException("SafeArrayAccessData failed with HRESULT ${hr}")
    }
    try {
        body(dataSlot)
    } finally {
        try {
            let _ = safeArrayUnaccessData(arr.handle)
        } catch (_: Exception) {}
    }
}
