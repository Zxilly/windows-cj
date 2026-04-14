package result_smoke_hidden_api

import windows_result.*
import windows_result.Error as WinError

main(): Unit {
    let _ = GUID.zeroed()
    let _ = BasicString()
    let _ = HeapString()
    let _ = InterfaceHandle<IUnknown>(CPointer<IUnknown>())
    let _ = IUnknownVtbl()
    let _ = WindowsException(WinError.fromHRESULT(E_FAIL))
}