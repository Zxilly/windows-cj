package windows_runtime

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.WindowsException
import windows_interface.*

let runtimeWrapperReleaseCount = AtomicInt64(0)

@C
func runtimeWrapperReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = runtimeWrapperReleaseCount.fetchAdd(1)
    UInt32(oldCount + 1)
}

func resetRuntimeWrapperReleaseCount(): Unit {
    runtimeWrapperReleaseCount.store(0)
}

func runtimeWrapperThrowsWindowsException(action: () -> Unit): Bool {
    try {
        action()
        false
    } catch (_: WindowsException) {
        true
    } catch (_: Exception) {
        false
    }
}

func runtimeWrapperTestVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = runtimeWrapperReleaseThunk
    vtbl
}

func withRuntimeWrapperRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IUnknownVtbl>(1, { _ => runtimeWrapperTestVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IUnknownVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)

    action(raw)

    unsafe {
        releaseArrayRawData(objectHandle)
        releaseArrayRawData(vtblHandle)
    }
}

@Test
func testRuntimeFromAbiTakeRejectsNullOwnedPointer() {
    @Expect(runtimeWrapperThrowsWindowsException({ =>
        let _ = IAsyncInfo.fromAbiTake(CPointer<Unit>())
    }), true)

    @Expect(IAsyncInfo.viewOf(CPointer<Unit>()).asRaw().isNull(), true)
}

@Test
func testFoundationRuntimeBorrowedViewCannotManualRelease() {
    resetRuntimeWrapperReleaseCount()
    withRuntimeWrapperRaw({ raw: CPointer<Unit> =>
        let view = IAsyncInfo.viewOf(raw)
        @Expect(view.release(), 0u32)
        @Expect(runtimeWrapperReleaseCount.load(), 0)

        let owned = IAsyncInfo.fromAbiTake(raw)
        @Expect(owned.release(), 1u32)
        @Expect(runtimeWrapperReleaseCount.load(), 1)
    })
}

@Test
func testCollectionRuntimeBorrowedViewCannotManualRelease() {
    resetRuntimeWrapperReleaseCount()
    withRuntimeWrapperRaw({ raw: CPointer<Unit> =>
        let view = IIterator<Int32>.viewOf(raw)
        @Expect(view.release(), 0u32)
        @Expect(runtimeWrapperReleaseCount.load(), 0)

        let owned = IIterator<Int32>.fromAbiTake(raw)
        @Expect(owned.release(), 1u32)
        @Expect(runtimeWrapperReleaseCount.load(), 1)
    })
}
