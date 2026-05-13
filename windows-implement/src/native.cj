package windows_implement

import windows_libloading as windows_libloading

func coCreateFreeThreadedMarshalerProc(): CPointer<Unit> {
    windows_libloading.resolveProc("ole32.dll", "CoCreateFreeThreadedMarshaler")
}

public func CoCreateFreeThreadedMarshaler(
    punkOuter: CPointer<Unit>,
    ppunkMarshal: CPointer<CPointer<Unit>>
): Int32 {
    let proc = CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(coCreateFreeThreadedMarshalerProc())
    unsafe { proc(punkOuter, ppunkMarshal) }
}
