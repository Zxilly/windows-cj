package windows_collections

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*

let collectionWrapperReleaseCount = AtomicInt64(0)

@C
func collectionWrapperReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = collectionWrapperReleaseCount.fetchAdd(1)
    UInt32(oldCount + 1)
}

func resetCollectionWrapperReleaseCount(): Unit {
    collectionWrapperReleaseCount.store(0)
}

func collectionWrapperTestVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = collectionWrapperReleaseThunk
    vtbl
}

func withCollectionWrapperRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(collectionWrapperTestVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    action(raw)

    unsafe {
        windows_interface.freeNativeValue(objectHandle)
        windows_interface.freeNativeValue(vtblHandle)
    }
}

@Test
func testCollectionRuntimeBorrowedViewCannotManualRelease() {
    resetCollectionWrapperReleaseCount()
    withCollectionWrapperRaw({ raw: CPointer<Unit> =>
        let view = IIterator<Int32>.viewOf(raw)
        @Expect(view.release(), 0u32)
        @Expect(collectionWrapperReleaseCount.load(), 0)

        let owned = IIterator<Int32>.fromAbiTake(raw)
        @Expect(owned.release(), 1u32)
        @Expect(collectionWrapperReleaseCount.load(), 1)
    })
}
