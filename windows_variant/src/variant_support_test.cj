package windows_variant

import windows_sys.Win32.System.Com.IUnknownVtbl
import windows_strings.BSTR
import windows_libloading as windows_libloading

func variantSmokeOleAut32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw VariantAbiException("failed to resolve OleAut32 smoke ABI '${name}'")
    }
}

func variantSmokeChangeType(value: VARIANT, target: VARENUM): Variant {
    let proc = variantSmokeOleAut32Proc("VariantChangeType")
    let changeFn = CFunc<(CPointer<VARIANT>, CPointer<VARIANT>, UInt16, VARENUM) -> Int32>(proc)
    var source = value
    var result = VARIANT()
    let sourcePtr = unsafe { CPointer<VARIANT>(inout source) }
    let resultPtr = unsafe { CPointer<VARIANT>(inout result) }
    variantInit(resultPtr)
    let hr = unsafe { changeFn(resultPtr, sourcePtr, 0u16, target) }
    if (hr < 0) {
        let _ = variantClear(resultPtr)
        throw VariantAbiException("VariantChangeType failed in VARIANT smoke test with HRESULT ${hr}")
    }
    Variant(result)
}

func variantSmokeSafeArrayCreateVector(vt: VARENUM, count: Int64): CPointer<Unit> {
    let proc = variantSmokeOleAut32Proc("SafeArrayCreateVector")
    let createFn = CFunc<(UInt16, Int32, UInt32) -> CPointer<Unit>>(proc)
    let handle = unsafe { createFn(vt, 0i32, UInt32(count)) }
    if (handle.isNull()) {
        throw VariantAbiException("SafeArrayCreateVector returned null in VARIANT smoke test")
    }
    handle
}

func variantSmokeSafeArrayDestroy(handle: CPointer<Unit>): Unit {
    if (handle.isNull()) {
        return
    }
    let proc = variantSmokeOleAut32Proc("SafeArrayDestroy")
    let destroyFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { destroyFn(handle) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayDestroy failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayLock(handle: CPointer<Unit>): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayLock")
    let lockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { lockFn(handle) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayLock failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayUnlock(handle: CPointer<Unit>): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayUnlock")
    let unlockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { unlockFn(handle) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayUnlock failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayPutElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayPutElement")
    let putFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { putFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayPutElement failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayGetElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayGetElement")
    let getFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { getFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayGetElement failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArraySetBstr(handle: CPointer<Unit>, index: Int64, value: String): Unit {
    let bstr = BSTR(value)
    try {
        var indexSlot = Int32(index)
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        let rawUnit = unsafe { CPointer<Unit>(bstr.asPtr()) }
        variantSmokeSafeArrayPutElement(handle, indexPtr, rawUnit)
    } finally {
        bstr.close()
    }
}

func variantSmokeSafeArrayBstrText(handle: CPointer<Unit>, index: Int64): String {
    var indexSlot = Int32(index)
    let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
    var raw: CPointer<UInt16> = CPointer<UInt16>()
    let rawPtr = unsafe { CPointer<CPointer<UInt16>>(inout raw) }
    let rawPtrUnit = unsafe { CPointer<Unit>(rawPtr) }
    variantSmokeSafeArrayGetElement(handle, indexPtr, rawPtrUnit)
    let bstr = BSTR.fromRawTake(raw)
    var text = ""
    try {
        text = bstr.get()
    } finally {
        bstr.close()
    }
    text
}

func variantSmokeCreateBstrSafeArray(values: Array<String>): CPointer<Unit> {
    let handle = variantSmokeSafeArrayCreateVector(VT_BSTR, values.size)
    var completed = false
    try {
        for (i in 0..values.size) {
            variantSmokeSafeArraySetBstr(handle, i, values[i])
        }
        completed = true
    } finally {
        if (!completed) {
            variantSmokeSafeArrayDestroy(handle)
        }
    }
    handle
}

func variantSmokeFromSafeArrayRaw(vt: VARENUM, handle: CPointer<Unit>): VARIANT {
    var payload = VariantValue()
    payload.parray = handle
    variantWithPayload(VT_ARRAY | vt, payload)
}

func variantSmokeSafeArrayRaw(value: VARIANT): CPointer<Unit> {
    variantPayload(value).Anonymous.parray
}

func variantTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@C
struct ReentrantVariantUnknown {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

var reentrantVariantTarget: Option<Variant> = None
var reentrantVariantReleaseCalls: UInt32 = 0u32

@C
func reentrantVariantRelease(_: CPointer<Unit>): UInt32 {
    reentrantVariantReleaseCalls += 1u32
    if (let Some(target) <- reentrantVariantTarget) {
        target.close()
    }
    0u32
}
