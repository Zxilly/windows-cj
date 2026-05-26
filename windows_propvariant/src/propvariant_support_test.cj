package windows_propvariant

import windows_interface.IUnknownVtbl
import windows_strings.BSTR
import windows_strings.decodeWideFromPointer
import windows_libloading as windows_libloading

func propVariantSmokeOleAut32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw PropVariantAbiException("failed to resolve OleAut32 smoke ABI '${name}'")
    }
}

func propVariantSmokePropsysProc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("propsys.dll", name)
    } catch (_: Exception) {
        throw PropVariantAbiException("failed to resolve Propsys smoke ABI '${name}'")
    }
}

func propVariantSmokeToString(value: PROPVARIANT): String {
    let proc = propVariantSmokePropsysProc("PropVariantToString")
    let toStringFn = CFunc<(CPointer<PROPVARIANT>, CPointer<UInt16>, UInt32) -> Int32>(proc)
    var local = value
    var buffer = Array<UInt16>(128, { _ => 0u16 })
    let valuePtr = unsafe { CPointer<PROPVARIANT>(inout local) }
    let handle = unsafe { acquireArrayRawData(buffer) }
    try {
        let hr = unsafe { toStringFn(valuePtr, handle.pointer, UInt32(buffer.size)) }
        if (hr < 0) {
            throw PropVariantAbiException("PropVariantToString failed in PROPVARIANT smoke test with HRESULT ${hr}")
        }
        decodeWideFromPointer(handle.pointer)
    } finally {
        unsafe { releaseArrayRawData(handle) }
    }
}

func propVariantSmokeToInt32(value: PROPVARIANT): Int32 {
    let proc = propVariantSmokePropsysProc("PropVariantToInt32")
    let toInt32Fn = CFunc<(CPointer<PROPVARIANT>, CPointer<Int32>) -> Int32>(proc)
    var local = value
    var result: Int32 = 0
    let valuePtr = unsafe { CPointer<PROPVARIANT>(inout local) }
    let resultPtr = unsafe { CPointer<Int32>(inout result) }
    let hr = unsafe { toInt32Fn(valuePtr, resultPtr) }
    if (hr < 0) {
        throw PropVariantAbiException("PropVariantToInt32 failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
    result
}

func propVariantSmokeSafeArrayCreateVector(vt: VARENUM, count: Int64): CPointer<Unit> {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayCreateVector")
    let createFn = CFunc<(UInt16, Int32, UInt32) -> CPointer<Unit>>(proc)
    let handle = unsafe { createFn(vt, 0i32, UInt32(count)) }
    if (handle.isNull()) {
        throw PropVariantAbiException("SafeArrayCreateVector returned null in PROPVARIANT smoke test")
    }
    handle
}

func propVariantSmokeSafeArrayDestroy(handle: CPointer<Unit>): Unit {
    if (handle.isNull()) {
        return
    }
    let proc = propVariantSmokeOleAut32Proc("SafeArrayDestroy")
    let destroyFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { destroyFn(handle) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayDestroy failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayLock(handle: CPointer<Unit>): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayLock")
    let lockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { lockFn(handle) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayLock failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayUnlock(handle: CPointer<Unit>): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayUnlock")
    let unlockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { unlockFn(handle) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayUnlock failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayPutElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayPutElement")
    let putFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { putFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayPutElement failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayGetElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayGetElement")
    let getFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { getFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayGetElement failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArraySetBstr(handle: CPointer<Unit>, index: Int64, value: String): Unit {
    let bstr = BSTR(value)
    try {
        var indexSlot = Int32(index)
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        let rawUnit = unsafe { CPointer<Unit>(bstr.asPtr()) }
        propVariantSmokeSafeArrayPutElement(handle, indexPtr, rawUnit)
    } finally {
        bstr.close()
    }
}

func propVariantSmokeSafeArrayBstrText(handle: CPointer<Unit>, index: Int64): String {
    var indexSlot = Int32(index)
    let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
    var raw: CPointer<UInt16> = CPointer<UInt16>()
    let rawPtr = unsafe { CPointer<CPointer<UInt16>>(inout raw) }
    let rawPtrUnit = unsafe { CPointer<Unit>(rawPtr) }
    propVariantSmokeSafeArrayGetElement(handle, indexPtr, rawPtrUnit)
    let bstr = BSTR.fromRawTake(raw)
    var text = ""
    try {
        text = bstr.get()
    } finally {
        bstr.close()
    }
    text
}

func propVariantSmokeCreateBstrSafeArray(values: Array<String>): CPointer<Unit> {
    let handle = propVariantSmokeSafeArrayCreateVector(VT_BSTR, values.size)
    var completed = false
    try {
        for (i in 0..values.size) {
            propVariantSmokeSafeArraySetBstr(handle, i, values[i])
        }
        completed = true
    } finally {
        if (!completed) {
            propVariantSmokeSafeArrayDestroy(handle)
        }
    }
    handle
}

func propVariantSmokeFromSafeArrayRaw(vt: VARENUM, handle: CPointer<Unit>): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_ARRAY | vt))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        writePayloadPointer(payloadBase(slotPtr), 0, handle)
    }
    result
}

func propVariantSmokeSafeArrayRaw(value: PROPVARIANT): CPointer<Unit> {
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        readPayloadPointer(payloadBase(slotPtr), 0)
    }
}

func propVariantTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@C
struct ReentrantPropVariantUnknown {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

var reentrantPropVariantTarget: Option<PropVariant> = None
var reentrantPropVariantReleaseCalls: UInt32 = 0u32

@C
func reentrantPropVariantRelease(_: CPointer<Unit>): UInt32 {
    reentrantPropVariantReleaseCalls += 1u32
    if (let Some(target) <- reentrantPropVariantTarget) {
        target.close()
    }
    0u32
}
