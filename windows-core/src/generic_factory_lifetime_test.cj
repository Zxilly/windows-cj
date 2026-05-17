package windows_core

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*

let genericFactoryReleaseCount = AtomicInt64(0)

@C
func genericFactoryReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = genericFactoryReleaseCount.fetchAdd(1)
    UInt32(oldCount + 1)
}

func resetGenericFactoryReleaseCount(): Unit {
    genericFactoryReleaseCount.store(0)
}

func genericFactoryLifetimeVtbl(): IGenericFactoryVtbl {
    var vtbl = IGenericFactoryVtbl()
    vtbl.base_.base_.Release = genericFactoryReleaseThunk
    vtbl
}

func withGenericFactoryRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IGenericFactoryVtbl>(genericFactoryLifetimeVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IGenericFactoryVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    action(raw)

    unsafe {
        windows_interface.freeNativeValue(objectHandle)
        windows_interface.freeNativeValue(vtblHandle)
    }
}

@Test
func testGenericFactoryBorrowedViewCannotManualRelease() {
    resetGenericFactoryReleaseCount()
    withGenericFactoryRaw({ raw: CPointer<Unit> =>
        let view = IGenericFactory.viewOf(raw)
        @Expect(view.release(), 0u32)
        @Expect(genericFactoryReleaseCount.load(), 0)

        let owned = IGenericFactory.fromAbiTake(raw)
        @Expect(owned.release(), 1u32)
        @Expect(genericFactoryReleaseCount.load(), 1)
    })
}
