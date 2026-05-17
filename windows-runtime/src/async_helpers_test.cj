package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_ABORT, E_NOTIMPL, InParam, Result, WinError, createComObjectFromSchemas}

let asyncJoinInfoCleanupCloseCalls = AtomicInt64(0)
let asyncJoinInfoCleanupResultsCalls = AtomicInt64(0)

class AsyncJoinInfoCleanupActionImpl <: IAsyncAction_Impl & Resource {
    private let infoVtblHandle: CPointer<IAsyncInfoVtbl>
    private let actionVtblHandle: CPointer<IAsyncActionVtbl>
    private var closed = false

    public init() {
        this.infoVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncInfoVtbl>(IAsyncInfoVtbl.new<AsyncJoinInfoCleanupActionImpl>())
        }
        this.actionVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncActionVtbl>(IAsyncActionVtbl.new<AsyncJoinInfoCleanupActionImpl>())
        }
    }

    public func infoVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(infoVtblHandle)
    }

    public func actionVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(actionVtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe {
            windows_interface.freeNativeValue(actionVtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
        asyncJoinInfoCleanupCloseCalls.fetchAdd(1)
        closed = true
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func Id(): Result<UInt32> {
        Result<UInt32>.Ok(1u32)
    }

    public func Status(): Result<AsyncStatus> {
        Result<AsyncStatus>.Ok(AsyncStatus_Completed)
    }

    public func ErrorCode(): Result<HResult> {
        Result<HResult>.Ok(HResult())
    }

    public func Cancel(): Result<Unit> {
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        Result<Unit>.Ok(())
    }

    public func SetCompleted(handler: InParam<AsyncActionCompletedHandler>): Result<Unit> {
        let _ = handler
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncActionCompletedHandler> {
        Result<AsyncActionCompletedHandler>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetResults(): Result<Unit> {
        asyncJoinInfoCleanupResultsCalls.fetchAdd(1)
        Result<Unit>.Ok(())
    }
}

func createAsyncJoinInfoCleanupAction(): IAsyncAction {
    let impl = AsyncJoinInfoCleanupActionImpl()
    let object = createComObjectFromSchemas(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncAction.descriptorSchema()],
        [impl.infoVtblPtr(), impl.actionVtblPtr()]
    )
    let action = object.toInterface(IAsyncAction.descriptor())
    object.close()
    action
}

@Test
func testReadyActionJoinAndWhenCompleteSuccessfully() {
    let action = IAsyncAction.ready()
    let info = action.asIAsyncInfo()

    try {
        @Expect(unsafe { info.Status() } == AsyncStatus_Completed, true)
        @Expect(action.join().isOk(), true)
        @Expect(action.when().get(Duration.second * 2).isOk(), true)
    } finally {
        info.close()
        action.close()
    }
}

@Test
func testAsyncActionJoinReleasesTemporaryAsyncInfo() {
    asyncJoinInfoCleanupCloseCalls.store(0)
    asyncJoinInfoCleanupResultsCalls.store(0)
    let action = createAsyncJoinInfoCleanupAction()

    try {
        @Expect(action.join().isOk(), true)
        @Expect(asyncJoinInfoCleanupResultsCalls.load(), 1)
    } finally {
        action.close()
    }
    @Expect(asyncJoinInfoCleanupCloseCalls.load(), 1)
}

@Test
func testSpawnedActionCancelTransitionsToCanceled() {
    let action = IAsyncAction.spawnAsync({ =>
        sleep(Duration.millisecond * 100)
    })
    let info = action.asIAsyncInfo()

    try {
        unsafe { info.Cancel() }

        @Expect(unsafe { info.Status() } == AsyncStatus_Canceled, true)
        match (action.join()) {
            case Result<Unit>.Err(error) => @Expect(error.code(), E_ABORT)
            case Result<Unit>.Ok(_) => @Expect(false, true)
        }
    } finally {
        info.close()
        action.close()
    }
}

@Test
func testReadyOperationJoinAndWhenReturnValue() {
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
func testReadyOperationWithProgressReturnsResultAndTerminalStatus() {
    let operation = IAsyncOperationWithProgress<Int32, UInt32>.ready(7i32, 3u32)
    let info = operation.asIAsyncInfo()

    try {
        @Expect(unsafe { info.Status() } == AsyncStatus_Completed, true)
        match (operation.join()) {
            case Result<Int32>.Ok(value) => @Expect(value, 7i32)
            case Result<Int32>.Err(_) => @Expect(false, true)
        }
    } finally {
        info.close()
        operation.close()
    }
}
