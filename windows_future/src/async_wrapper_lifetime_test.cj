package windows_future

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, WindowsException}
import windows_interface.*

let asyncWrapperReleaseCount = AtomicInt64(0)

@C
func asyncWrapperReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = asyncWrapperReleaseCount.fetchAdd(1)
    UInt32(oldCount + 1)
}

func resetAsyncWrapperReleaseCount(): Unit {
    asyncWrapperReleaseCount.store(0)
}

func asyncWrapperThrowsWindowsException(action: () -> Unit): Bool {
    try {
        action()
        false
    } catch (_: WindowsException) {
        true
    } catch (_: Exception) {
        false
    }
}

func asyncWrapperTestVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = asyncWrapperReleaseThunk
    vtbl
}

@C
func asyncWrapperFailingIdThunk(_: CPointer<Unit>, result: CPointer<UInt32>): Int32 {
    if (!result.isNull()) {
        unsafe { result.write(99u32) }
    }
    E_FAIL.value
}

func asyncWrapperFailingAsyncInfoVtbl(): IAsyncInfoVtbl {
    var vtbl = IAsyncInfoVtbl()
    vtbl.Id = asyncWrapperFailingIdThunk
    vtbl.base_.base_.Release = asyncWrapperReleaseThunk
    vtbl
}

func withAsyncWrapperRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(asyncWrapperTestVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    action(raw)

    unsafe {
        windows_interface.freeNativeValue(objectHandle)
        windows_interface.freeNativeValue(vtblHandle)
    }
}

func withAsyncWrapperFailingAsyncInfoRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IAsyncInfoVtbl>(asyncWrapperFailingAsyncInfoVtbl()) }
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
    @Expect(asyncWrapperThrowsWindowsException({ =>
        let _ = IAsyncInfo.fromAbiTake(CPointer<Unit>())
    }), true)

    @Expect(IAsyncInfo.viewOf(CPointer<Unit>()).asRaw().isNull(), true)
}

@Test
func testRuntimeWrapperThrowsOnFailedHRESULT() {
    withAsyncWrapperFailingAsyncInfoRaw({ raw: CPointer<Unit> =>
        let info = IAsyncInfo.viewOf(raw)

        @Expect(asyncWrapperThrowsWindowsException({ =>
            let _ = unsafe { info.Id() }
        }), true)
    })
}

@Test
func testFoundationRuntimeBorrowedViewCannotManualRelease() {
    resetAsyncWrapperReleaseCount()
    withAsyncWrapperRaw({ raw: CPointer<Unit> =>
        let view = IAsyncInfo.viewOf(raw)
        @Expect(view.release(), 0u32)
        @Expect(asyncWrapperReleaseCount.load(), 0)

        let owned = IAsyncInfo.fromAbiTake(raw)
        @Expect(owned.release(), 1u32)
        @Expect(asyncWrapperReleaseCount.load(), 1)
    })
}
