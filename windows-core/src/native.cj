package windows_core

import windows_libloading as windows_libloading

func CoTaskMemAlloc(cb: UIntNative): CPointer<Unit> {
    let proc = CFunc<(UIntNative) -> CPointer<Unit>>(windows_libloading.resolveProc("ole32.dll", "CoTaskMemAlloc"))
    unsafe { proc(cb) }
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

func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit> {
    let proc = CFunc<(CPointer<Unit>, CPointer<UInt8>) -> CPointer<Unit>>(
        windows_libloading.resolveProc("kernel32.dll", "GetProcAddress")
    )
    unsafe { proc(hModule, lpProcName) }
}

func LoadLibraryExA(lpLibFileName: CPointer<UInt8>, hFile: CPointer<Unit>, dwFlags: UInt32): CPointer<Unit> {
    let proc = CFunc<(CPointer<UInt8>, CPointer<Unit>, UInt32) -> CPointer<Unit>>(
        windows_libloading.resolveProc("kernel32.dll", "LoadLibraryExA")
    )
    unsafe { proc(lpLibFileName, hFile, dwFlags) }
}

func FreeLibrary(hLibModule: CPointer<Unit>): Int32 {
    let proc = CFunc<(CPointer<Unit>) -> Int32>(windows_libloading.resolveProc("kernel32.dll", "FreeLibrary"))
    unsafe { proc(hLibModule) }
}

func CoCreateFreeThreadedMarshaler(
    punkOuter: CPointer<Unit>,
    ppunkMarshal: CPointer<CPointer<Unit>>
): Int32 {
    let proc = CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(
        windows_libloading.resolveProc("ole32.dll", "CoCreateFreeThreadedMarshaler")
    )
    unsafe { proc(punkOuter, ppunkMarshal) }
}
