package windows_future

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOTIMPL, HResultAbi}
import windows_interface as windows_interface

func assertAsyncDefaultComOut1Cleared(
    slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(3u8) }
    try {
        var raw = CPointer<Unit>(sentinel)
        @Expect(unsafe { slot(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout raw)) }, E_NOTIMPL.value)
        @Expect(raw.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

func assertAsyncDefaultUInt32OutCleared(slot: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32>): Unit {
    var value = 37u32
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<UInt32>(inout value)) }, E_NOTIMPL.value)
    @Expect(value, 0u32)
}

func assertAsyncDefaultAsyncStatusOutCleared(
    slot: CFunc<(CPointer<Unit>, CPointer<AsyncStatusAbi>) -> Int32>
): Unit {
    var value = AsyncStatusAbi(3)
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<AsyncStatusAbi>(inout value)) }, E_NOTIMPL.value)
    @Expect(value.value, 0i32)
}

func assertAsyncDefaultHResultOutCleared(slot: CFunc<(CPointer<Unit>, CPointer<HResultAbi>) -> Int32>): Unit {
    var value = HResultAbi()
    value.Value = -1i32
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<HResultAbi>(inout value)) }, E_NOTIMPL.value)
    @Expect(value.Value, 0i32)
}

@Test
func testAsyncInfoDefaultScalarVtableClearsOutSlotsBeforeNotImpl() {
    var asyncInfo = IAsyncInfoVtbl()
    assertAsyncDefaultUInt32OutCleared(asyncInfo.Id)
    assertAsyncDefaultAsyncStatusOutCleared(asyncInfo.Status)
    assertAsyncDefaultHResultOutCleared(asyncInfo.ErrorCode)
}

@Test
func testAsyncDefaultVtablesClearOutSlotsBeforeNotImpl() {
    var action = IAsyncActionVtbl()
    assertAsyncDefaultComOut1Cleared(action.Completed)

    var actionWithProgress = IAsyncActionWithProgressVtbl()
    assertAsyncDefaultComOut1Cleared(actionWithProgress.Progress)
    assertAsyncDefaultComOut1Cleared(actionWithProgress.Completed)

    var operation = IAsyncOperationVtbl()
    assertAsyncDefaultComOut1Cleared(operation.Completed)
    assertAsyncDefaultComOut1Cleared(operation.GetResults)

    var operationWithProgress = IAsyncOperationWithProgressVtbl()
    assertAsyncDefaultComOut1Cleared(operationWithProgress.Progress)
    assertAsyncDefaultComOut1Cleared(operationWithProgress.Completed)
    assertAsyncDefaultComOut1Cleared(operationWithProgress.GetResults)
}
