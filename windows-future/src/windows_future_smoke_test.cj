package windows_future

import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, WindowsException}
import windows_core as windows_core

// Real WinRT smoke: project async operations/actions and drive them through join/when
// across the generated IAsyncInfo/IAsyncOperation ABI. Exercises the actual async
// projection + completion path, not constants.
@Test
func testReadyOperationProjectsCompletedResult() {
    let operation = IAsyncOperation<Int32>.ready(42i32)
    let info = operation.asIAsyncInfo()
    try {
        @Expect(unsafe { info.Status() } == AsyncStatus_Completed, true)
        match (operation.join()) {
            case Result<Int32>.Ok(value) => @Expect(value, 42i32)
            case Result<Int32>.Err(_) => @Expect(false, true)
        }
        match (operation.when().get(Duration.second * 2)) {
            case Result<Int32>.Ok(value) => @Expect(value, 42i32)
            case Result<Int32>.Err(_) => @Expect(false, true)
        }
    } finally {
        info.close()
        operation.close()
    }
}

@Test
func testSpawnedActionPropagatesWindowsExceptionThroughJoin() {
    let action = IAsyncAction.spawnAsync({ =>
        throw WindowsException(E_POINTER)
    })
    let info = action.asIAsyncInfo()
    try {
        match (action.join()) {
            case Result<Unit>.Err(error) => @Expect(error.code(), E_POINTER)
            case Result<Unit>.Ok(_) => @Expect(false, true)
        }
        @Expect(unsafe { info.Status() } == AsyncStatus_Error, true)
    } finally {
        info.close()
        action.close()
    }
}
