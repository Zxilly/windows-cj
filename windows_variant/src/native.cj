package windows_variant

import std.sync.AtomicInt32
import windows_libloading as windows_libloading

public class VariantAbiException <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

let observedVariantClearCount = AtomicInt32(0)
let observedVariantCopyCount = AtomicInt32(0)
let observedVariantInitCount = AtomicInt32(0)

public func debugObservedVariantClearCount(): Int32 {
    observedVariantClearCount.load()
}

public func debugObservedVariantCopyCount(): Int32 {
    observedVariantCopyCount.load()
}

public func debugObservedVariantInitCount(): Int32 {
    observedVariantInitCount.load()
}

func resolveOleaut32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw VariantAbiException("failed to resolve OleAut32 VARIANT ABI")
    }
}

let variantClearProc = windows_libloading.FinalizerSafeProc("oleaut32.dll", "VariantClear")

func ensureVariantClearAbiResolved(): Unit {
    try {
        let _ = variantClearProc.ensureResolved()
    } catch (_: Exception) {
        throw VariantAbiException("failed to resolve OleAut32 VariantClear ABI")
    }
}

func variantInitAbi(target: CPointer<VARIANT>): Unit {
    let proc = resolveOleaut32Proc("VariantInit")
    let initFn = CFunc<(CPointer<VARIANT>) -> Unit>(proc)
    unsafe {
        initFn(target)
    }
    observedVariantInitCount.fetchAdd(1)
}

func variantClearAbi(target: CPointer<VARIANT>): Int32 {
    let proc = variantClearProc.rawIfResolvedForFinalizer()
    if (proc.isNull()) {
        throw VariantAbiException("VariantClear ABI was not resolved before finalizer-safe release")
    }
    let clearFn = CFunc<(CPointer<VARIANT>) -> Int32>(proc)
    let hr = unsafe {
        clearFn(target)
    }
    observedVariantClearCount.fetchAdd(1)
    hr
}

func variantCopyAbi(dest: CPointer<VARIANT>, src: CPointer<VARIANT>): Int32 {
    ensureVariantClearAbiResolved()
    let proc = resolveOleaut32Proc("VariantCopy")
    let copyFn = CFunc<(CPointer<VARIANT>, CPointer<VARIANT>) -> Int32>(proc)
    let hr = unsafe {
        copyFn(dest, src)
    }
    observedVariantCopyCount.fetchAdd(1)
    hr
}

/// Call OleAut32 VariantInit on the supplied VARIANT slot.
public func variantInit(target: CPointer<VARIANT>): Unit {
    variantInitAbi(target)
}

/// Call OleAut32 VariantClear on the supplied VARIANT slot. Returns the HRESULT.
public func variantClear(target: CPointer<VARIANT>): Int32 {
    variantClearAbi(target)
}

/// Call OleAut32 VariantCopy. Performs a deep copy that honours BSTR/IUnknown/IDispatch/SAFEARRAY semantics.
public func variantCopy(dest: CPointer<VARIANT>, src: CPointer<VARIANT>): Int32 {
    variantCopyAbi(dest, src)
}
