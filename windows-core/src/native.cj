package windows_core

import windows_implement as windows_implement
import windows_libloading as windows_libloading

func CoTaskMemAlloc(cb: UIntNative): CPointer<Unit> {
    let proc = CFunc<(UIntNative) -> CPointer<Unit>>(windows_libloading.resolveProc("ole32.dll", "CoTaskMemAlloc"))
    unsafe { proc(cb) }
}

func CoTaskMemRealloc(pv: CPointer<Unit>, cb: UIntNative): CPointer<Unit> {
    let proc = CFunc<(CPointer<Unit>, UIntNative) -> CPointer<Unit>>(windows_libloading.resolveProc("ole32.dll", "CoTaskMemRealloc"))
    unsafe { proc(pv, cb) }
}

func CoTaskMemFree(pv: CPointer<Unit>): Unit {
    let proc = CFunc<(CPointer<Unit>) -> Unit>(windows_libloading.resolveProc("ole32.dll", "CoTaskMemFree"))
    unsafe { proc(pv) }
}

func RoGetAgileReference(
    options: Int32,
    riid: CPointer<GUID>,
    pUnk: CPointer<Unit>,
    ppAgileReference: CPointer<CPointer<Unit>>
): Int32 {
    let proc = CFunc<(Int32, CPointer<GUID>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(
        windows_libloading.resolveProc("combase.dll", "RoGetAgileReference")
    )
    unsafe { proc(options, riid, pUnk, ppAgileReference) }
}

func EncodePointer(ptr: CPointer<Unit>): CPointer<Unit> {
    let proc = CFunc<(CPointer<Unit>) -> CPointer<Unit>>(windows_libloading.resolveProc("kernel32.dll", "EncodePointer"))
    unsafe { proc(ptr) }
}

func CoCreateFreeThreadedMarshaler(
    punkOuter: CPointer<Unit>,
    ppunkMarshal: CPointer<CPointer<Unit>>
): Int32 {
    windows_implement.CoCreateFreeThreadedMarshaler(punkOuter, ppunkMarshal)
}
