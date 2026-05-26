package windows_implement

import std.sync.AtomicInt64
import windows_libloading as windows_libloading

let observedCoTaskMemFreeCount = AtomicInt64(0)

public func debugObservedCoTaskMemFreeCount(): Int64 {
    observedCoTaskMemFreeCount.load()
}

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

func coTaskMemAllocProc(): CPointer<Unit> {
    windows_libloading.resolveProc("ole32.dll", "CoTaskMemAlloc")
}

public func CoTaskMemAlloc(cb: UIntNative): CPointer<Unit> {
    let proc = CFunc<(UIntNative) -> CPointer<Unit>>(coTaskMemAllocProc())
    unsafe { proc(cb) }
}

func coTaskMemFreeProc(): CPointer<Unit> {
    windows_libloading.resolveProc("ole32.dll", "CoTaskMemFree")
}

public func CoTaskMemFree(pv: CPointer<Unit>): Unit {
    let proc = CFunc<(CPointer<Unit>) -> Unit>(coTaskMemFreeProc())
    unsafe { proc(pv) }
    if (pv.isNotNull()) {
        observedCoTaskMemFreeCount.fetchAdd(1)
    }
}
