package windows_implement

import windows_interface.*

func releaseComRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        if (vtblPtr.isNull()) {
            return 0u32
        }
        let vtbl = vtblPtr.read()
        vtbl.Release(raw)
    }
}

func releaseFailedComOutSlot(resultSlot: CPointer<CPointer<Unit>>): Unit {
    if (resultSlot.isNull()) {
        return
    }
    let raw = unsafe { resultSlot.read() }
    if (raw.isNotNull()) {
        unsafe { resultSlot.write(CPointer<Unit>()) }
        let _ = releaseComRaw(raw)
    }
}
