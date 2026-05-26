package windows_propvariant

import std.sync.AtomicInt32
import windows_libloading as windows_libloading

public class PropVariantAbiException <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

let observedPropVariantClearCount = AtomicInt32(0)
let observedPropVariantCopyCount = AtomicInt32(0)
let observedPropVariantInitCount = AtomicInt32(0)
let observedCoTaskMemAllocCount = AtomicInt32(0)

public func debugObservedPropVariantClearCount(): Int32 {
    observedPropVariantClearCount.load()
}

public func debugObservedPropVariantCopyCount(): Int32 {
    observedPropVariantCopyCount.load()
}

public func debugObservedPropVariantInitCount(): Int32 {
    observedPropVariantInitCount.load()
}

public func debugObservedCoTaskMemAllocCount(): Int32 {
    observedCoTaskMemAllocCount.load()
}

func resolveOle32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("ole32.dll", name)
    } catch (_: Exception) {
        throw PropVariantAbiException("failed to resolve ole32 PROPVARIANT ABI for ${name}")
    }
}

let propVariantClearProc = windows_libloading.FinalizerSafeProc("ole32.dll", "PropVariantClear")

func ensurePropVariantClearAbiResolved(): Unit {
    try {
        let _ = propVariantClearProc.ensureResolved()
    } catch (_: Exception) {
        throw PropVariantAbiException("failed to resolve ole32 PropVariantClear ABI")
    }
}

func propVariantInitAbi(target: CPointer<PROPVARIANT>): Unit {
    let proc = resolveOle32Proc("PropVariantInit")
    let initFn = CFunc<(CPointer<PROPVARIANT>) -> Unit>(proc)
    unsafe {
        initFn(target)
    }
    observedPropVariantInitCount.fetchAdd(1)
}

func propVariantClearAbi(target: CPointer<PROPVARIANT>): Int32 {
    let proc = propVariantClearProc.rawIfResolvedForFinalizer()
    if (proc.isNull()) {
        throw PropVariantAbiException("PropVariantClear ABI was not resolved before finalizer-safe release")
    }
    let clearFn = CFunc<(CPointer<PROPVARIANT>) -> Int32>(proc)
    let hr = unsafe {
        clearFn(target)
    }
    observedPropVariantClearCount.fetchAdd(1)
    hr
}

func propVariantCopyAbi(dest: CPointer<PROPVARIANT>, src: CPointer<PROPVARIANT>): Int32 {
    ensurePropVariantClearAbiResolved()
    let proc = resolveOle32Proc("PropVariantCopy")
    let copyFn = CFunc<(CPointer<PROPVARIANT>, CPointer<PROPVARIANT>) -> Int32>(proc)
    let hr = unsafe {
        copyFn(dest, src)
    }
    observedPropVariantCopyCount.fetchAdd(1)
    hr
}

/// Call ole32 PropVariantInit on the supplied PROPVARIANT slot.
public func propVariantInit(target: CPointer<PROPVARIANT>): Unit {
    propVariantInitAbi(target)
}

/// Call ole32 PropVariantClear on the supplied PROPVARIANT slot. Returns the HRESULT.
public func propVariantClear(target: CPointer<PROPVARIANT>): Int32 {
    propVariantClearAbi(target)
}

/// Call ole32 PropVariantCopy. Performs a deep copy that honours BSTR/IUnknown/
/// IDispatch/SAFEARRAY/LPSTR/LPWSTR/CLSID semantics.
public func propVariantCopy(dest: CPointer<PROPVARIANT>, src: CPointer<PROPVARIANT>): Int32 {
    propVariantCopyAbi(dest, src)
}

func coTaskMemAllocAbi(size: UIntNative): CPointer<Unit> {
    let proc = resolveOle32Proc("CoTaskMemAlloc")
    let allocFn = CFunc<(UIntNative) -> CPointer<Unit>>(proc)
    let raw = unsafe {
        allocFn(size)
    }
    observedCoTaskMemAllocCount.fetchAdd(1)
    raw
}
