package windows_safearray

import windows_variant.VARIANT
import windows_variant.VT_I4
import windows_variant.VT_R8
import windows_variant.VT_BSTR
import windows_variant.VT_VARIANT
import windows_variant.variantClear
import windows_strings.BSTR

func closeOwnedSafeArrayOnFailure(arr: SafeArray, body: () -> Unit): Unit {
    var completed = false
    try {
        body()
        completed = true
    } finally {
        if (!completed) {
            arr.close()
        }
    }
}

func ensureLowerBoundZero(arr: SafeArray): Unit {
    if (arr.lbound(1u32) != 0i32) {
        throw SafeArrayAbiException("typed SafeArray wrapper requires lower bound 0")
    }
}

func ensureIndexInRange(arr: SafeArray, index: Int64): Int32 {
    let len = arr.length()
    if (index < 0 || index >= len) {
        throw SafeArrayAbiException("SafeArray index ${index} out of range [0, ${len})")
    }
    Int32(index)
}

func checkedSafeArrayElementCount(count: Int64, owner: String): UInt32 {
    if (count < 0) {
        throw SafeArrayAbiException("${owner}.withLength requires non-negative count")
    }
    let maxCount = Int64(UInt32.Max)
    if (count > maxCount) {
        throw SafeArrayAbiException("${owner}.withLength count ${count} exceeds SAFEARRAY UInt32 ABI limit ${maxCount}")
    }
    UInt32(count)
}

/// 1-d SAFEARRAY of VT_I4 (Int32). Wrapper retains exclusive ownership of
/// the underlying descriptor via its embedded SafeArray.
public class SafeArrayOfInt32 <: Resource {
    let inner: SafeArray

    init(inner: SafeArray) {
        this.inner = inner
    }

    public static func withLength(count: Int64): SafeArrayOfInt32 {
        let abiCount = checkedSafeArrayElementCount(count, "SafeArrayOfInt32")
        let arr = SafeArray.createVector(VT_I4, 0i32, abiCount)
        SafeArrayOfInt32(arr)
    }

    public static func fromArray(values: Array<Int32>): SafeArrayOfInt32 {
        let result = withLength(Int64(values.size))
        closeOwnedSafeArrayOnFailure(result.raw()) { =>
            for (i in 0..values.size) {
                result.set(i, values[i])
            }
        }
        result
    }

    /// Take ownership of an existing 1-d VT_I4 SAFEARRAY descriptor.
    public static func fromRaw(handle: CPointer<SAFEARRAY>): SafeArrayOfInt32 {
        let arr = SafeArray(handle)
        closeOwnedSafeArrayOnFailure(arr) { =>
            if (!arr.isNull()) {
                if (arr.vartype() != VT_I4) {
                    throw SafeArrayAbiException("SafeArrayOfInt32.fromRaw expected VT_I4 array")
                }
                ensureLowerBoundZero(arr)
            }
        }
        SafeArrayOfInt32(arr)
    }

    public func length(): Int64 {
        inner.length()
    }

    public func get(index: Int64): Int32 {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        var dataSlot: Int32 = 0
        let dataPtr = unsafe { CPointer<Int32>(inout dataSlot) }
        let dataPtrUnit = unsafe { CPointer<Unit>(dataPtr) }
        let hr = safeArrayGetElementAbi(inner.handle, indexPtr, dataPtrUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayGetElement (Int32) failed with HRESULT ${hr}")
        }
        dataSlot
    }

    public func set(index: Int64, value: Int32): Unit {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        var dataSlot: Int32 = value
        let dataPtr = unsafe { CPointer<Int32>(inout dataSlot) }
        let dataPtrUnit = unsafe { CPointer<Unit>(dataPtr) }
        let hr = safeArrayPutElementAbi(inner.handle, indexPtr, dataPtrUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayPutElement (Int32) failed with HRESULT ${hr}")
        }
    }

    public func toArray(): Array<Int32> {
        let len = length()
        let result = Array<Int32>(len, repeat: 0i32)
        for (i in 0..len) {
            result[i] = get(i)
        }
        result
    }

    public func raw(): SafeArray {
        inner
    }

    public func close(): Unit {
        inner.close()
    }

    public func isClosed(): Bool {
        inner.isClosed()
    }
}

/// 1-d SAFEARRAY of VT_R8 (Float64).
public class SafeArrayOfFloat64 <: Resource {
    let inner: SafeArray

    init(inner: SafeArray) {
        this.inner = inner
    }

    public static func withLength(count: Int64): SafeArrayOfFloat64 {
        let abiCount = checkedSafeArrayElementCount(count, "SafeArrayOfFloat64")
        let arr = SafeArray.createVector(VT_R8, 0i32, abiCount)
        SafeArrayOfFloat64(arr)
    }

    public static func fromArray(values: Array<Float64>): SafeArrayOfFloat64 {
        let result = withLength(Int64(values.size))
        closeOwnedSafeArrayOnFailure(result.raw()) { =>
            for (i in 0..values.size) {
                result.set(i, values[i])
            }
        }
        result
    }

    public static func fromRaw(handle: CPointer<SAFEARRAY>): SafeArrayOfFloat64 {
        let arr = SafeArray(handle)
        closeOwnedSafeArrayOnFailure(arr) { =>
            if (!arr.isNull()) {
                if (arr.vartype() != VT_R8) {
                    throw SafeArrayAbiException("SafeArrayOfFloat64.fromRaw expected VT_R8 array")
                }
                ensureLowerBoundZero(arr)
            }
        }
        SafeArrayOfFloat64(arr)
    }

    public func length(): Int64 {
        inner.length()
    }

    public func get(index: Int64): Float64 {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        var dataSlot: Float64 = 0.0
        let dataPtr = unsafe { CPointer<Float64>(inout dataSlot) }
        let dataPtrUnit = unsafe { CPointer<Unit>(dataPtr) }
        let hr = safeArrayGetElementAbi(inner.handle, indexPtr, dataPtrUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayGetElement (Float64) failed with HRESULT ${hr}")
        }
        dataSlot
    }

    public func set(index: Int64, value: Float64): Unit {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        var dataSlot: Float64 = value
        let dataPtr = unsafe { CPointer<Float64>(inout dataSlot) }
        let dataPtrUnit = unsafe { CPointer<Unit>(dataPtr) }
        let hr = safeArrayPutElementAbi(inner.handle, indexPtr, dataPtrUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayPutElement (Float64) failed with HRESULT ${hr}")
        }
    }

    public func toArray(): Array<Float64> {
        let len = length()
        let result = Array<Float64>(len, repeat: 0.0)
        for (i in 0..len) {
            result[i] = get(i)
        }
        result
    }

    public func raw(): SafeArray {
        inner
    }

    public func close(): Unit {
        inner.close()
    }

    public func isClosed(): Bool {
        inner.isClosed()
    }
}

/// 1-d SAFEARRAY of VT_BSTR. SafeArrayPutElement makes its own BSTR copy via
/// SysAllocStringByteLen; SafeArrayGetElement returns a freshly allocated
/// BSTR that the wrapper owns and must free via SysFreeString.
public class SafeArrayOfStrings <: Resource {
    let inner: SafeArray

    init(inner: SafeArray) {
        this.inner = inner
    }

    public static func withLength(count: Int64): SafeArrayOfStrings {
        let abiCount = checkedSafeArrayElementCount(count, "SafeArrayOfStrings")
        let arr = SafeArray.createVector(VT_BSTR, 0i32, abiCount)
        SafeArrayOfStrings(arr)
    }

    public static func fromArray(values: Array<String>): SafeArrayOfStrings {
        let result = withLength(Int64(values.size))
        closeOwnedSafeArrayOnFailure(result.raw()) { =>
            for (i in 0..values.size) {
                result.set(i, values[i])
            }
        }
        result
    }

    public static func fromRaw(handle: CPointer<SAFEARRAY>): SafeArrayOfStrings {
        let arr = SafeArray(handle)
        closeOwnedSafeArrayOnFailure(arr) { =>
            if (!arr.isNull()) {
                if (arr.vartype() != VT_BSTR) {
                    throw SafeArrayAbiException("SafeArrayOfStrings.fromRaw expected VT_BSTR array")
                }
                ensureLowerBoundZero(arr)
            }
        }
        SafeArrayOfStrings(arr)
    }

    public func length(): Int64 {
        inner.length()
    }

    public func get(index: Int64): BSTR {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        var raw: CPointer<UInt16> = CPointer<UInt16>()
        let rawPtr = unsafe { CPointer<CPointer<UInt16>>(inout raw) }
        let rawPtrUnit = unsafe { CPointer<Unit>(rawPtr) }
        let hr = safeArrayGetElementAbi(inner.handle, indexPtr, rawPtrUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayGetElement (BSTR) failed with HRESULT ${hr}")
        }
        BSTR.fromRawTake(raw)
    }

    public func set(index: Int64, value: String): Unit {
        let bstr = BSTR(value)
        try {
            setBstr(index, bstr)
        } finally {
            bstr.close()
        }
    }

    public func setBstr(index: Int64, value: BSTR): Unit {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        let raw = value.asPtr()
        let rawUnit = unsafe { CPointer<Unit>(raw) }
        let hr = safeArrayPutElementAbi(inner.handle, indexPtr, rawUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayPutElement (BSTR) failed with HRESULT ${hr}")
        }
    }

    public func toArray(): Array<String> {
        let len = length()
        let result = Array<String>(len, repeat: "")
        for (i in 0..len) {
            let bstr = get(i)
            try {
                result[i] = bstr.get()
            } finally {
                bstr.close()
            }
        }
        result
    }

    public func raw(): SafeArray {
        inner
    }

    public func close(): Unit {
        inner.close()
    }

    public func isClosed(): Bool {
        inner.isClosed()
    }
}

/// 1-d SAFEARRAY of VT_VARIANT. SafeArrayPutElement invokes VariantCopy
/// internally; SafeArrayGetElement returns a fresh VARIANT (deep-copied)
/// owned by the wrapper and must be released with VariantClear.
public class SafeArrayOfVariants <: Resource {
    let inner: SafeArray

    init(inner: SafeArray) {
        this.inner = inner
    }

    public static func withLength(count: Int64): SafeArrayOfVariants {
        let abiCount = checkedSafeArrayElementCount(count, "SafeArrayOfVariants")
        let arr = SafeArray.createVector(VT_VARIANT, 0i32, abiCount)
        SafeArrayOfVariants(arr)
    }

    public static func fromArray(values: Array<VARIANT>): SafeArrayOfVariants {
        let result = withLength(Int64(values.size))
        closeOwnedSafeArrayOnFailure(result.raw()) { =>
            for (i in 0..values.size) {
                result.setRaw(i, values[i])
            }
        }
        result
    }

    public static func fromRaw(handle: CPointer<SAFEARRAY>): SafeArrayOfVariants {
        let arr = SafeArray(handle)
        closeOwnedSafeArrayOnFailure(arr) { =>
            if (!arr.isNull()) {
                if (arr.vartype() != VT_VARIANT) {
                    throw SafeArrayAbiException("SafeArrayOfVariants.fromRaw expected VT_VARIANT array")
                }
                ensureLowerBoundZero(arr)
            }
        }
        SafeArrayOfVariants(arr)
    }

    public func length(): Int64 {
        inner.length()
    }

    /// Returns a fresh, owning VARIANT slot. Caller must release it via
    /// VariantClear (typically by wrapping in `windows_variant.Variant`).
    public func get(index: Int64): VARIANT {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        var slot = VARIANT()
        let slotPtr = unsafe { CPointer<VARIANT>(inout slot) }
        let slotPtrUnit = unsafe { CPointer<Unit>(slotPtr) }
        let hr = safeArrayGetElementAbi(inner.handle, indexPtr, slotPtrUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayGetElement (VARIANT) failed with HRESULT ${hr}")
        }
        slot
    }

    /// SafeArrayPutElement performs VariantCopy internally — the caller
    /// retains ownership of `value` and must release it independently.
    public func setRaw(index: Int64, value: VARIANT): Unit {
        let idx = ensureIndexInRange(inner, index)
        var indexSlot: Int32 = idx
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        var src = value
        let srcPtr = unsafe { CPointer<VARIANT>(inout src) }
        let srcPtrUnit = unsafe { CPointer<Unit>(srcPtr) }
        let hr = safeArrayPutElementAbi(inner.handle, indexPtr, srcPtrUnit)
        if (hr < 0) {
            throw SafeArrayAbiException("SafeArrayPutElement (VARIANT) failed with HRESULT ${hr}")
        }
    }

    public func raw(): SafeArray {
        inner
    }

    public func close(): Unit {
        inner.close()
    }

    public func isClosed(): Bool {
        inner.isClosed()
    }
}
