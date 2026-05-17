package windows_safearray

import std.sync.AtomicInt32
import windows_libloading as windows_libloading

public class SafeArrayAbiException <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

let observedSafeArrayCreateCount = AtomicInt32(0)
let observedSafeArrayDestroyCount = AtomicInt32(0)
let observedSafeArrayLockCount = AtomicInt32(0)
let observedSafeArrayUnlockCount = AtomicInt32(0)
let observedSafeArrayAccessCount = AtomicInt32(0)
let observedSafeArrayUnaccessCount = AtomicInt32(0)

public func debugObservedSafeArrayCreateCount(): Int32 {
    observedSafeArrayCreateCount.load()
}

public func debugObservedSafeArrayDestroyCount(): Int32 {
    observedSafeArrayDestroyCount.load()
}

public func debugObservedSafeArrayLockCount(): Int32 {
    observedSafeArrayLockCount.load()
}

public func debugObservedSafeArrayUnlockCount(): Int32 {
    observedSafeArrayUnlockCount.load()
}

public func debugObservedSafeArrayAccessCount(): Int32 {
    observedSafeArrayAccessCount.load()
}

public func debugObservedSafeArrayUnaccessCount(): Int32 {
    observedSafeArrayUnaccessCount.load()
}

func resolveOleaut32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw SafeArrayAbiException("failed to resolve OleAut32 SAFEARRAY ABI '${name}'")
    }
}

let safeArrayDestroyProc = windows_libloading.FinalizerSafeProc("oleaut32.dll", "SafeArrayDestroy")

func ensureSafeArrayDestroyAbiResolved(): Unit {
    try {
        let _ = safeArrayDestroyProc.ensureResolved()
    } catch (_: Exception) {
        throw SafeArrayAbiException("failed to resolve OleAut32 SafeArrayDestroy ABI")
    }
}

public func safeArrayCreate(vt: UInt16, dims: UInt32, bounds: CPointer<SAFEARRAYBOUND>): CPointer<SAFEARRAY> {
    ensureSafeArrayDestroyAbiResolved()
    let proc = resolveOleaut32Proc("SafeArrayCreate")
    let createFn = CFunc<(UInt16, UInt32, CPointer<SAFEARRAYBOUND>) -> CPointer<SAFEARRAY>>(proc)
    let raw = unsafe { createFn(vt, dims, bounds) }
    if (raw.isNull()) {
        throw SafeArrayAbiException("SafeArrayCreate returned null")
    }
    observedSafeArrayCreateCount.fetchAdd(1)
    raw
}

public func safeArrayCreateVector(vt: UInt16, lLbound: Int32, cElements: UInt32): CPointer<SAFEARRAY> {
    ensureSafeArrayDestroyAbiResolved()
    let proc = resolveOleaut32Proc("SafeArrayCreateVector")
    let createFn = CFunc<(UInt16, Int32, UInt32) -> CPointer<SAFEARRAY>>(proc)
    let raw = unsafe { createFn(vt, lLbound, cElements) }
    if (raw.isNull()) {
        throw SafeArrayAbiException("SafeArrayCreateVector returned null")
    }
    observedSafeArrayCreateCount.fetchAdd(1)
    raw
}

public func safeArrayDestroy(handle: CPointer<SAFEARRAY>): Int32 {
    let proc = safeArrayDestroyProc.rawIfResolvedForFinalizer()
    if (proc.isNull()) {
        throw SafeArrayAbiException("SafeArrayDestroy ABI was not resolved before finalizer-safe release")
    }
    let destroyFn = CFunc<(CPointer<SAFEARRAY>) -> Int32>(proc)
    let hr = unsafe { destroyFn(handle) }
    observedSafeArrayDestroyCount.fetchAdd(1)
    hr
}

public func safeArrayLock(handle: CPointer<SAFEARRAY>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayLock")
    let lockFn = CFunc<(CPointer<SAFEARRAY>) -> Int32>(proc)
    let hr = unsafe { lockFn(handle) }
    observedSafeArrayLockCount.fetchAdd(1)
    hr
}

public func safeArrayUnlock(handle: CPointer<SAFEARRAY>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayUnlock")
    let unlockFn = CFunc<(CPointer<SAFEARRAY>) -> Int32>(proc)
    let hr = unsafe { unlockFn(handle) }
    observedSafeArrayUnlockCount.fetchAdd(1)
    hr
}

public func safeArrayAccessData(handle: CPointer<SAFEARRAY>, dataOut: CPointer<CPointer<Unit>>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayAccessData")
    let accessFn = CFunc<(CPointer<SAFEARRAY>, CPointer<CPointer<Unit>>) -> Int32>(proc)
    let hr = unsafe { accessFn(handle, dataOut) }
    observedSafeArrayAccessCount.fetchAdd(1)
    hr
}

public func safeArrayUnaccessData(handle: CPointer<SAFEARRAY>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayUnaccessData")
    let unaccessFn = CFunc<(CPointer<SAFEARRAY>) -> Int32>(proc)
    let hr = unsafe { unaccessFn(handle) }
    observedSafeArrayUnaccessCount.fetchAdd(1)
    hr
}

public func safeArrayGetDimAbi(handle: CPointer<SAFEARRAY>): UInt32 {
    let proc = resolveOleaut32Proc("SafeArrayGetDim")
    let dimFn = CFunc<(CPointer<SAFEARRAY>) -> UInt32>(proc)
    unsafe { dimFn(handle) }
}

public func safeArrayGetLBoundAbi(handle: CPointer<SAFEARRAY>, dim: UInt32, lboundOut: CPointer<Int32>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayGetLBound")
    let lboundFn = CFunc<(CPointer<SAFEARRAY>, UInt32, CPointer<Int32>) -> Int32>(proc)
    unsafe { lboundFn(handle, dim, lboundOut) }
}

public func safeArrayGetUBoundAbi(handle: CPointer<SAFEARRAY>, dim: UInt32, uboundOut: CPointer<Int32>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayGetUBound")
    let uboundFn = CFunc<(CPointer<SAFEARRAY>, UInt32, CPointer<Int32>) -> Int32>(proc)
    unsafe { uboundFn(handle, dim, uboundOut) }
}

public func safeArrayGetElementAbi(handle: CPointer<SAFEARRAY>, indices: CPointer<Int32>, slot: CPointer<Unit>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayGetElement")
    let getFn = CFunc<(CPointer<SAFEARRAY>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    unsafe { getFn(handle, indices, slot) }
}

public func safeArrayPutElementAbi(handle: CPointer<SAFEARRAY>, indices: CPointer<Int32>, slot: CPointer<Unit>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayPutElement")
    let putFn = CFunc<(CPointer<SAFEARRAY>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    unsafe { putFn(handle, indices, slot) }
}

public func safeArrayGetVartypeAbi(handle: CPointer<SAFEARRAY>, vtOut: CPointer<UInt16>): Int32 {
    let proc = resolveOleaut32Proc("SafeArrayGetVartype")
    let vtFn = CFunc<(CPointer<SAFEARRAY>, CPointer<UInt16>) -> Int32>(proc)
    unsafe { vtFn(handle, vtOut) }
}

public func safeArrayCopyAbi(handle: CPointer<SAFEARRAY>, copyOut: CPointer<CPointer<SAFEARRAY>>): Int32 {
    ensureSafeArrayDestroyAbiResolved()
    let proc = resolveOleaut32Proc("SafeArrayCopy")
    let copyFn = CFunc<(CPointer<SAFEARRAY>, CPointer<CPointer<SAFEARRAY>>) -> Int32>(proc)
    unsafe { copyFn(handle, copyOut) }
}
