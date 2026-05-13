package windows_runtime

import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_ABORT, Result}

@Test
func testReadyActionJoinAndWhenCompleteSuccessfully() {
    let action = IAsyncAction.ready()

    @Expect(unsafe { action.asIAsyncInfo().Status() } == AsyncStatus_Completed, true)
    @Expect(action.join().isOk(), true)
    @Expect(action.when().get(Duration.second * 2).isOk(), true)
}

@Test
func testSpawnedActionCancelTransitionsToCanceled() {
    let action = IAsyncAction.spawnAsync({ =>
        sleep(Duration.millisecond * 100)
    })
    let info = action.asIAsyncInfo()

    unsafe { info.Cancel() }

    @Expect(unsafe { info.Status() } == AsyncStatus_Canceled, true)
    match (action.join()) {
        case Result<Unit>.Err(error) => @Expect(error.code(), E_ABORT)
        case Result<Unit>.Ok(_) => @Expect(false, true)
    }
}

@Test
func testReadyOperationJoinAndWhenReturnValue() {
    let operation = IAsyncOperation<Int32>.ready(42i32)

    @Expect(unsafe { operation.asIAsyncInfo().Status() } == AsyncStatus_Completed, true)
    match (operation.join()) {
        case Result<Int32>.Ok(value) => @Expect(value, 42i32)
        case Result<Int32>.Err(_) => @Expect(false, true)
    }
    match (operation.when().get(Duration.second * 2)) {
        case Result<Int32>.Ok(value) => @Expect(value, 42i32)
        case Result<Int32>.Err(_) => @Expect(false, true)
    }
}

@Test
func testReadyOperationWithProgressReturnsResultAndTerminalStatus() {
    let operation = IAsyncOperationWithProgress<Int32, UInt32>.ready(7i32, 3u32)

    @Expect(unsafe { operation.asIAsyncInfo().Status() } == AsyncStatus_Completed, true)
    match (operation.join()) {
        case Result<Int32>.Ok(value) => @Expect(value, 7i32)
        case Result<Int32>.Err(_) => @Expect(false, true)
    }
}
