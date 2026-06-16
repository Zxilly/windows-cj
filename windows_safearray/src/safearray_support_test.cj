package windows_safearray

import windows_sys.Win32.System.Com.IUnknownVtbl
import windows_strings.BSTR

func safeArrayTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

func safeArraySmokeVectorFromBstr(value: String): SafeArray {
    let proc = resolveOleaut32Proc("VectorFromBstr")
    let vectorFromBstrFn = CFunc<(CPointer<UInt16>, CPointer<CPointer<SAFEARRAY>>) -> Int32>(proc)
    let source = BSTR(value)
    var raw: CPointer<SAFEARRAY> = CPointer<SAFEARRAY>()
    let rawPtr = unsafe { CPointer<CPointer<SAFEARRAY>>(inout raw) }
    var hr: Int32 = 0
    try {
        hr = unsafe { vectorFromBstrFn(source.asPtr(), rawPtr) }
    } finally {
        source.close()
    }
    if (hr < 0) {
        if (raw.isNotNull()) {
            SafeArray(raw).close()
        }
        throw SafeArrayAbiException("VectorFromBstr failed in SAFEARRAY smoke test with HRESULT ${hr}")
    }
    if (raw.isNull()) {
        throw SafeArrayAbiException("VectorFromBstr returned null SAFEARRAY")
    }
    SafeArray(raw)
}

func safeArraySmokeBstrFromVector(arr: SafeArray): BSTR {
    let proc = resolveOleaut32Proc("BstrFromVector")
    let bstrFromVectorFn = CFunc<(CPointer<SAFEARRAY>, CPointer<CPointer<UInt16>>) -> Int32>(proc)
    var raw: CPointer<UInt16> = CPointer<UInt16>()
    let rawPtr = unsafe { CPointer<CPointer<UInt16>>(inout raw) }
    let hr = unsafe { bstrFromVectorFn(arr.get(), rawPtr) }
    if (hr < 0) {
        if (raw.isNotNull()) {
            BSTR.fromRawTake(raw).close()
        }
        throw SafeArrayAbiException("BstrFromVector failed in SAFEARRAY smoke test with HRESULT ${hr}")
    }
    if (raw.isNull()) {
        throw SafeArrayAbiException("BstrFromVector returned null BSTR")
    }
    BSTR.fromRawTake(raw)
}

@C
struct ReentrantSafeArrayUnknown {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

var reentrantSafeArrayTarget: Option<SafeArray> = None
var reentrantSafeArrayReleaseCalls: UInt32 = 0u32

@C
func reentrantSafeArrayRelease(_: CPointer<Unit>): UInt32 {
    reentrantSafeArrayReleaseCalls += 1u32
    if (let Some(target) <- reentrantSafeArrayTarget) {
        target.close()
    }
    0u32
}
