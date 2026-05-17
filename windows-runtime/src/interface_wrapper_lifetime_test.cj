package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, WindowsException}
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

@C
func runtimeWrapperFailingIdThunk(_: CPointer<Unit>, result: CPointer<UInt32>): Int32 {
    if (!result.isNull()) {
        unsafe { result.write(99u32) }
    }
    E_FAIL.value
}

func runtimeWrapperFailingAsyncInfoVtbl(): IAsyncInfoVtbl {
    var vtbl = IAsyncInfoVtbl()
    vtbl.Id = runtimeWrapperFailingIdThunk
    vtbl.base_.base_.Release = runtimeWrapperReleaseThunk
    vtbl
}

func withRuntimeWrapperRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(runtimeWrapperTestVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    action(raw)

    unsafe {
        windows_interface.freeNativeValue(objectHandle)
        windows_interface.freeNativeValue(vtblHandle)
    }
}

func withRuntimeWrapperFailingAsyncInfoRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IAsyncInfoVtbl>(runtimeWrapperFailingAsyncInfoVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IAsyncInfoVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    try {
        action(raw)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
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
func testRuntimeWrapperThrowsOnFailedHRESULT() {
    withRuntimeWrapperFailingAsyncInfoRaw({ raw: CPointer<Unit> =>
        let info = IAsyncInfo.viewOf(raw)

        @Expect(runtimeWrapperThrowsWindowsException({ =>
            let _ = unsafe { info.Id() }
        }), true)
    })
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
