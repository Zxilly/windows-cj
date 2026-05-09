package windows_winui3.win32

import windows_core.HRESULT
import windows_libloading.resolveProc

public let COINIT_APARTMENTTHREADED = 2u32

let OLE32_DLL = "ole32.dll"
let CO_INITIALIZE_EX = "CoInitializeEx"
let CO_UNINITIALIZE = "CoUninitialize"

public func CoInitializeEx(reserved: CPointer<Unit>, coInit: UInt32): HRESULT {
    let proc = resolveProc(OLE32_DLL, CO_INITIALIZE_EX)
    let call = CFunc<(CPointer<Unit>, UInt32) -> Int32>(proc)
    HRESULT(unsafe { call(reserved, coInit) })
}

public func CoUninitialize(): Unit {
    let proc = resolveProc(OLE32_DLL, CO_UNINITIALIZE)
    let call = CFunc<() -> Unit>(proc)
    unsafe { call() }
}

public func initializeApartmentThreaded(): HRESULT {
    CoInitializeEx(CPointer<Unit>(), COINIT_APARTMENTTHREADED)
}

public func uninitializeApartment(): Unit {
    CoUninitialize()
}
