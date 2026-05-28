package windows_future

import windows_interface as windows_interface
import std.sync.{AtomicBool, AtomicInt64}
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_ABORT, E_FAIL, E_POINTER, HResult, HResultAbi, InParam, Result, S_OK, WindowsException, createComObjectFromSchemas, foundationGenericOutThunk}
import windows_core as windows_core

let asyncJoinInfoCleanupCloseCalls = AtomicInt64(0)
let asyncJoinInfoCleanupResultsCalls = AtomicInt64(0)
let foundationGenericOutThunkCleanupCalls = AtomicInt64(0)
let foundationGenericOutThunkThrowWindows = AtomicBool(false)
var foundationGenericOutThunkCleanupRaw = CPointer<Unit>()

struct FoundationGenericOutThunkCleanupProbe <: windows_core.RuntimeType & windows_core.WinrtGenericType<FoundationGenericOutThunkCleanupProbe> {
    public init() {}

    public static func abiType(): String {
        "FoundationGenericOutThunkCleanupProbe"
    }

    public static func signature(): String {
        "test.foundation.generic.cleanup"
    }

    public static func winrtOutputBridge(): windows_core.WinrtOutputBridge<FoundationGenericOutThunkCleanupProbe> {
        FoundationGenericOutThunkCleanupBridge()
    }
}

class FoundationGenericOutThunkCleanupBridge <: windows_core.WinrtOutputBridge<FoundationGenericOutThunkCleanupProbe> {
    public init() {}

    public override func storeOut(
        result__: CPointer<CPointer<Unit>>,
        value: FoundationGenericOutThunkCleanupProbe
    ): Int32 {
        let _ = value
        if (result__.isNull()) {
            return E_POINTER.value
        }
        unsafe { result__.write(foundationGenericOutThunkCleanupRaw) }
        if (foundationGenericOutThunkThrowWindows.load()) {
            throw WindowsException(E_POINTER)
        }
        throw Exception("foundation generic out store failure")
    }

    public override func releaseOutRange(
        buffer: CPointer<Unit>,
        length: UInt32
    ): Unit {
        if (buffer.isNull() || length == 0u32) {
            return
        }
        let slot = CPointer<CPointer<Unit>>(buffer)
        if (unsafe { slot.read() }.isNotNull()) {
            let _ = foundationGenericOutThunkCleanupCalls.fetchAdd(1)
            unsafe { slot.write(CPointer<Unit>()) }
        }
    }
}

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
        futureTestNotImplemented<AsyncActionCompletedHandler>()
    }

    public func GetResults(): Result<Unit> {
        asyncJoinInfoCleanupResultsCalls.fetchAdd(1)
        Result<Unit>.Ok(())
    }
}

class AsyncCompletedRetainImpl <: IAsyncAction_Impl {
    private let handler: AsyncActionCompletedHandler

    public init(handler: AsyncActionCompletedHandler) {
        this.handler = handler
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
        Result<AsyncActionCompletedHandler>.Ok(handler)
    }

    public func GetResults(): Result<Unit> {
        Result<Unit>.Ok(())
    }
}

class AsyncInfoThrowingImpl <: IAsyncInfo_Impl {
    public var throwWindowsOnId: Bool = false
    public var throwPlainOnStatus: Bool = false
    public var throwPlainOnErrorCode: Bool = false
    public var throwWindowsOnCancel: Bool = false
    public var throwPlainOnClose: Bool = false

    public func Id(): Result<UInt32> {
        if (throwWindowsOnId) {
            throw WindowsException(E_POINTER)
        }
        Result<UInt32>.Ok(7u32)
    }

    public func Status(): Result<AsyncStatus> {
        if (throwPlainOnStatus) {
            throw Exception("Status failure")
        }
        Result<AsyncStatus>.Ok(AsyncStatus_Completed)
    }

    public func ErrorCode(): Result<HResult> {
        if (throwPlainOnErrorCode) {
            throw Exception("ErrorCode failure")
        }
        Result<HResult>.Ok(HResult())
    }

    public func Cancel(): Result<Unit> {
        if (throwWindowsOnCancel) {
            throw WindowsException(E_POINTER)
        }
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        if (throwPlainOnClose) {
            throw Exception("Close failure")
        }
        Result<Unit>.Ok(())
    }
}

open class AsyncDerivedThrowingInfoBase {
    public var throwWindowsOnId: Bool = false
    public var throwPlainOnStatus: Bool = false
    public var status: AsyncStatus = AsyncStatus_Completed
    public var throwWindowsOnErrorCode: Bool = false
    public var throwPlainOnErrorCode: Bool = false
    public var throwWindowsOnSetProgress: Bool = false
    public var throwPlainOnSetProgress: Bool = false
    public var throwWindowsOnProgress: Bool = false
    public var throwPlainOnProgress: Bool = false
    public var throwWindowsOnSetCompleted: Bool = false
    public var throwPlainOnSetCompleted: Bool = false
    public var throwWindowsOnCompleted: Bool = false
    public var throwPlainOnCompleted: Bool = false
    public var throwWindowsOnGetResults: Bool = false
    public var throwPlainOnGetResults: Bool = false

    public func Id(): Result<UInt32> {
        if (throwWindowsOnId) {
            throw WindowsException(E_POINTER)
        }
        Result<UInt32>.Ok(7u32)
    }

    public func Status(): Result<AsyncStatus> {
        if (throwPlainOnStatus) {
            throw Exception("Status failure")
        }
        Result<AsyncStatus>.Ok(status)
    }

    public func ErrorCode(): Result<HResult> {
        if (throwWindowsOnErrorCode) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnErrorCode) {
            throw Exception("ErrorCode failure")
        }
        Result<HResult>.Ok(HResult())
    }

    public func Cancel(): Result<Unit> {
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        Result<Unit>.Ok(())
    }
}

class AsyncActionThrowingInfoImpl <: AsyncDerivedThrowingInfoBase & IAsyncAction_Impl {
    public func SetCompleted(handler: InParam<AsyncActionCompletedHandler>): Result<Unit> {
        let _ = handler
        if (throwWindowsOnSetCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnSetCompleted) {
            throw Exception("SetCompleted failure")
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncActionCompletedHandler> {
        if (throwWindowsOnCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnCompleted) {
            throw Exception("Completed failure")
        }
        futureTestNotImplemented<AsyncActionCompletedHandler>()
    }

    public func GetResults(): Result<Unit> {
        if (throwWindowsOnGetResults) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnGetResults) {
            throw Exception("GetResults failure")
        }
        Result<Unit>.Ok(())
    }
}

class AsyncActionWithProgressThrowingInfoImpl <: AsyncDerivedThrowingInfoBase & IAsyncActionWithProgress_Impl<UInt32> {
    public func SetProgress(handler: InParam<AsyncActionProgressHandler<UInt32>>): Result<Unit> {
        let _ = handler
        if (throwWindowsOnSetProgress) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnSetProgress) {
            throw Exception("SetProgress failure")
        }
        Result<Unit>.Ok(())
    }

    public func Progress(): Result<AsyncActionProgressHandler<UInt32>> {
        if (throwWindowsOnProgress) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnProgress) {
            throw Exception("Progress failure")
        }
        futureTestNotImplemented<AsyncActionProgressHandler<UInt32>>()
    }

    public func SetCompleted(handler: InParam<AsyncActionWithProgressCompletedHandler<UInt32>>): Result<Unit> {
        let _ = handler
        if (throwWindowsOnSetCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnSetCompleted) {
            throw Exception("SetCompleted failure")
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncActionWithProgressCompletedHandler<UInt32>> {
        if (throwWindowsOnCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnCompleted) {
            throw Exception("Completed failure")
        }
        futureTestNotImplemented<AsyncActionWithProgressCompletedHandler<UInt32>>()
    }

    public func GetResults(): Result<Unit> {
        if (throwWindowsOnGetResults) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnGetResults) {
            throw Exception("GetResults failure")
        }
        Result<Unit>.Ok(())
    }
}

class AsyncOperationThrowingInfoImpl <: AsyncDerivedThrowingInfoBase & IAsyncOperation_Impl<Int32> {
    public func SetCompleted(handler: InParam<AsyncOperationCompletedHandler<Int32>>): Result<Unit> {
        let _ = handler
        if (throwWindowsOnSetCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnSetCompleted) {
            throw Exception("SetCompleted failure")
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncOperationCompletedHandler<Int32>> {
        if (throwWindowsOnCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnCompleted) {
            throw Exception("Completed failure")
        }
        futureTestNotImplemented<AsyncOperationCompletedHandler<Int32>>()
    }

    public func GetResults(): Result<Int32> {
        if (throwWindowsOnGetResults) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnGetResults) {
            throw Exception("GetResults failure")
        }
        Result<Int32>.Ok(1i32)
    }
}

class AsyncOperationWithProgressThrowingInfoImpl <: AsyncDerivedThrowingInfoBase & IAsyncOperationWithProgress_Impl<Int32, UInt32> {
    public func SetProgress(handler: InParam<AsyncOperationProgressHandler<Int32, UInt32>>): Result<Unit> {
        let _ = handler
        if (throwWindowsOnSetProgress) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnSetProgress) {
            throw Exception("SetProgress failure")
        }
        Result<Unit>.Ok(())
    }

    public func Progress(): Result<AsyncOperationProgressHandler<Int32, UInt32>> {
        if (throwWindowsOnProgress) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnProgress) {
            throw Exception("Progress failure")
        }
        futureTestNotImplemented<AsyncOperationProgressHandler<Int32, UInt32>>()
    }

    public func SetCompleted(handler: InParam<AsyncOperationWithProgressCompletedHandler<Int32, UInt32>>): Result<Unit> {
        let _ = handler
        if (throwWindowsOnSetCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnSetCompleted) {
            throw Exception("SetCompleted failure")
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncOperationWithProgressCompletedHandler<Int32, UInt32>> {
        if (throwWindowsOnCompleted) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnCompleted) {
            throw Exception("Completed failure")
        }
        futureTestNotImplemented<AsyncOperationWithProgressCompletedHandler<Int32, UInt32>>()
    }

    public func GetResults(): Result<Int32> {
        if (throwWindowsOnGetResults) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnGetResults) {
            throw Exception("GetResults failure")
        }
        Result<Int32>.Ok(1i32)
    }
}

func assertAsyncDerivedInfoThunksClearOutputsAndTranslateThrownExceptions(
    impl: AsyncDerivedThrowingInfoBase,
    idThunk: (CPointer<UInt32>) -> Int32,
    statusThunk: (CPointer<AsyncStatusAbi>) -> Int32,
    errorCodeThunk: (CPointer<HResultAbi>) -> Int32
): Unit {
    impl.throwWindowsOnId = true
    var id = 123u32
    @Expect(idThunk(CPointer<UInt32>(inout id)), E_POINTER.value)
    @Expect(id, 0u32)
    impl.throwWindowsOnId = false

    impl.throwPlainOnStatus = true
    var status = AsyncStatusAbi(99)
    @Expect(statusThunk(CPointer<AsyncStatusAbi>(inout status)), E_FAIL.value)
    @Expect(status.value, 0i32)
    impl.throwPlainOnStatus = false

    impl.throwPlainOnErrorCode = true
    var errorCode = HResultAbi()
    errorCode.Value = 123i32
    @Expect(errorCodeThunk(CPointer<HResultAbi>(inout errorCode)), E_FAIL.value)
    @Expect(errorCode.Value, 0i32)
    impl.throwPlainOnErrorCode = false
}

func assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
    setWindows: (Bool) -> Unit,
    setPlain: (Bool) -> Unit,
    thunk: (CPointer<CPointer<Unit>>) -> Int32
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(654i32) }
    try {
        setWindows(true)
        var raw = CPointer<Unit>(sentinel)
        @Expect(thunk(CPointer<CPointer<Unit>>(inout raw)), E_POINTER.value)
        @Expect(raw.isNull(), true)
        setWindows(false)

        setPlain(true)
        raw = CPointer<Unit>(sentinel)
        @Expect(thunk(CPointer<CPointer<Unit>>(inout raw)), E_FAIL.value)
        @Expect(raw.isNull(), true)
        setPlain(false)
    } finally {
        setWindows(false)
        setPlain(false)
        unsafe { windows_interface.freeNativeValue(sentinel) }
    }
}

func assertAsyncManualUnitThunkTranslatesThrownExceptions(
    setWindows: (Bool) -> Unit,
    setPlain: (Bool) -> Unit,
    thunk: () -> Int32
): Unit {
    setWindows(true)
    @Expect(thunk(), E_POINTER.value)
    setWindows(false)

    setPlain(true)
    @Expect(thunk(), E_FAIL.value)
    setPlain(false)
}

@Test
func testFoundationGenericOutThunkCleansStoreExceptions(): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(654i32) }
    try {
        foundationGenericOutThunkCleanupCalls.store(0)
        foundationGenericOutThunkCleanupRaw = CPointer<Unit>(sentinel)
        foundationGenericOutThunkThrowWindows.store(true)
        var raw = CPointer<Unit>()
        let windowsHr = foundationGenericOutThunk<FoundationGenericOutThunkCleanupProbe>(
            CPointer<CPointer<Unit>>(inout raw),
            { => Result<FoundationGenericOutThunkCleanupProbe>.Ok(FoundationGenericOutThunkCleanupProbe()) }
        )
        @Expect(windowsHr, E_POINTER.value)
        @Expect(raw.isNull(), true)
        @Expect(foundationGenericOutThunkCleanupCalls.load(), 1)

        foundationGenericOutThunkCleanupRaw = CPointer<Unit>(sentinel)
        foundationGenericOutThunkThrowWindows.store(false)
        raw = CPointer<Unit>()
        let plainHr = foundationGenericOutThunk<FoundationGenericOutThunkCleanupProbe>(
            CPointer<CPointer<Unit>>(inout raw),
            { => Result<FoundationGenericOutThunkCleanupProbe>.Ok(FoundationGenericOutThunkCleanupProbe()) }
        )
        @Expect(plainHr, E_FAIL.value)
        @Expect(raw.isNull(), true)
        @Expect(foundationGenericOutThunkCleanupCalls.load(), 2)
    } finally {
        foundationGenericOutThunkCleanupRaw = CPointer<Unit>()
        foundationGenericOutThunkThrowWindows.store(false)
        unsafe { windows_interface.freeNativeValue<Int32>(sentinel) }
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

func withThrowingAsyncAction(impl: AsyncActionThrowingInfoImpl, body: (IAsyncAction) -> Unit): Unit {
    let infoVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncInfoVtbl>(IAsyncInfoVtbl.new<AsyncActionThrowingInfoImpl>())
    }
    let actionVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncActionVtbl>(IAsyncActionVtbl.new<AsyncActionThrowingInfoImpl>())
    }
    let object = createComObjectFromSchemas(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncAction.descriptorSchema()],
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(actionVtblHandle)]
    )
    let action = object.toInterface(IAsyncAction.descriptor())
    object.close()

    try {
        body(action)
    } finally {
        action.close()
        unsafe {
            windows_interface.freeNativeValue(actionVtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
    }
}

func withThrowingAsyncOperation(impl: AsyncOperationThrowingInfoImpl, body: (IAsyncOperation<Int32>) -> Unit): Unit {
    let infoVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncInfoVtbl>(IAsyncInfoVtbl.new<AsyncOperationThrowingInfoImpl>())
    }
    let operationVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncOperationVtbl>(
            IAsyncOperationVtbl.new<AsyncOperationThrowingInfoImpl, Int32>()
        )
    }
    let object = createComObjectFromSchemas(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncOperation<Int32>.descriptorSchema()],
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(operationVtblHandle)]
    )
    let operation = object.toInterface(IAsyncOperation<Int32>.descriptor())
    object.close()

    try {
        body(operation)
    } finally {
        operation.close()
        unsafe {
            windows_interface.freeNativeValue(operationVtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
    }
}

func withThrowingAsyncActionWithProgress(
    impl: AsyncActionWithProgressThrowingInfoImpl,
    body: (IAsyncActionWithProgress<UInt32>) -> Unit
): Unit {
    let infoVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncInfoVtbl>(
            IAsyncInfoVtbl.new<AsyncActionWithProgressThrowingInfoImpl>()
        )
    }
    let actionVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncActionWithProgressVtbl>(
            IAsyncActionWithProgressVtbl.new<AsyncActionWithProgressThrowingInfoImpl, UInt32>()
        )
    }
    let object = createComObjectFromSchemas(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncActionWithProgress<UInt32>.descriptorSchema()],
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(actionVtblHandle)]
    )
    let action = object.toInterface(IAsyncActionWithProgress<UInt32>.descriptor())
    object.close()

    try {
        body(action)
    } finally {
        action.close()
        unsafe {
            windows_interface.freeNativeValue(actionVtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
    }
}

func withThrowingAsyncOperationWithProgress(
    impl: AsyncOperationWithProgressThrowingInfoImpl,
    body: (IAsyncOperationWithProgress<Int32, UInt32>) -> Unit
): Unit {
    let infoVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncInfoVtbl>(
            IAsyncInfoVtbl.new<AsyncOperationWithProgressThrowingInfoImpl>()
        )
    }
    let operationVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAsyncOperationWithProgressVtbl>(
            IAsyncOperationWithProgressVtbl.new<AsyncOperationWithProgressThrowingInfoImpl, Int32, UInt32>()
        )
    }
    let object = createComObjectFromSchemas(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncOperationWithProgress<Int32, UInt32>.descriptorSchema()],
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(operationVtblHandle)]
    )
    let operation = object.toInterface(IAsyncOperationWithProgress<Int32, UInt32>.descriptor())
    object.close()

    try {
        body(operation)
    } finally {
        operation.close()
        unsafe {
            windows_interface.freeNativeValue(operationVtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
    }
}

func expectAsyncJoinError<T>(result: Result<T>, expected: windows_core.HRESULT): Unit {
    match (result) {
        case Result<T>.Err(error) => @Expect(error.code(), expected)
        case Result<T>.Ok(_) => @Expect(false, true)
    }
}

func asyncTestToCoreHRESULT(code: HResult): windows_core.HRESULT {
    windows_core.HRESULT(code.Value)
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
func testSpawnedActionPreservesWindowsExceptionHRESULT() {
    let action = IAsyncAction.spawnAsync({ =>
        throw WindowsException(E_POINTER)
    })
    let info = action.asIAsyncInfo()

    try {
        expectAsyncJoinError<Unit>(action.join(), E_POINTER)
        @Expect(unsafe { info.Status() } == AsyncStatus_Error, true)
        @Expect(asyncTestToCoreHRESULT(unsafe { info.ErrorCode() }), E_POINTER)
    } finally {
        info.close()
        action.close()
    }
}

@Test
func testSpawnedOperationPreservesWindowsExceptionHRESULT() {
    let operation = IAsyncOperation<Int32>.spawnAsync({ =>
        throw WindowsException(E_POINTER)
    })
    let info = operation.asIAsyncInfo()

    try {
        expectAsyncJoinError<Int32>(operation.join(), E_POINTER)
        @Expect(unsafe { info.Status() } == AsyncStatus_Error, true)
        @Expect(asyncTestToCoreHRESULT(unsafe { info.ErrorCode() }), E_POINTER)
    } finally {
        info.close()
        operation.close()
    }
}

@Test
func testSpawnedActionWithProgressPreservesWindowsExceptionHRESULT() {
    let action = IAsyncActionWithProgress<UInt32>.spawnAsync({ reporter =>
        reporter.report(1u32)
        throw WindowsException(E_POINTER)
    })
    let info = action.asIAsyncInfo()

    try {
        expectAsyncJoinError<Unit>(action.join(), E_POINTER)
        @Expect(unsafe { info.Status() } == AsyncStatus_Error, true)
        @Expect(asyncTestToCoreHRESULT(unsafe { info.ErrorCode() }), E_POINTER)
    } finally {
        info.close()
        action.close()
    }
}

@Test
func testSpawnedOperationWithProgressPreservesWindowsExceptionHRESULT() {
    let operation = IAsyncOperationWithProgress<Int32, UInt32>.spawnAsync({ reporter =>
        reporter.report(1u32)
        throw WindowsException(E_POINTER)
    })
    let info = operation.asIAsyncInfo()

    try {
        expectAsyncJoinError<Int32>(operation.join(), E_POINTER)
        @Expect(unsafe { info.Status() } == AsyncStatus_Error, true)
        @Expect(asyncTestToCoreHRESULT(unsafe { info.ErrorCode() }), E_POINTER)
    } finally {
        info.close()
        operation.close()
    }
}

@Test
func testAsyncJoinPreservesWindowsExceptionFromCompletedGetResults() {
    let actionImpl = AsyncActionThrowingInfoImpl()
    actionImpl.throwWindowsOnGetResults = true
    withThrowingAsyncAction(actionImpl, { action =>
        expectAsyncJoinError<Unit>(action.join(), E_POINTER)
    })

    let operationImpl = AsyncOperationThrowingInfoImpl()
    operationImpl.throwWindowsOnGetResults = true
    withThrowingAsyncOperation(operationImpl, { operation =>
        expectAsyncJoinError<Int32>(operation.join(), E_POINTER)
    })

    let actionWithProgressImpl = AsyncActionWithProgressThrowingInfoImpl()
    actionWithProgressImpl.throwWindowsOnGetResults = true
    withThrowingAsyncActionWithProgress(actionWithProgressImpl, { action =>
        expectAsyncJoinError<Unit>(action.join(), E_POINTER)
    })

    let operationWithProgressImpl = AsyncOperationWithProgressThrowingInfoImpl()
    operationWithProgressImpl.throwWindowsOnGetResults = true
    withThrowingAsyncOperationWithProgress(operationWithProgressImpl, { operation =>
        expectAsyncJoinError<Int32>(operation.join(), E_POINTER)
    })
}

@Test
func testAsyncJoinPreservesWindowsExceptionFromErrorCode() {
    let actionImpl = AsyncActionThrowingInfoImpl()
    actionImpl.status = AsyncStatus_Error
    actionImpl.throwWindowsOnErrorCode = true
    withThrowingAsyncAction(actionImpl, { action =>
        expectAsyncJoinError<Unit>(action.join(), E_POINTER)
    })

    let operationImpl = AsyncOperationThrowingInfoImpl()
    operationImpl.status = AsyncStatus_Error
    operationImpl.throwWindowsOnErrorCode = true
    withThrowingAsyncOperation(operationImpl, { operation =>
        expectAsyncJoinError<Int32>(operation.join(), E_POINTER)
    })

    let actionWithProgressImpl = AsyncActionWithProgressThrowingInfoImpl()
    actionWithProgressImpl.status = AsyncStatus_Error
    actionWithProgressImpl.throwWindowsOnErrorCode = true
    withThrowingAsyncActionWithProgress(actionWithProgressImpl, { action =>
        expectAsyncJoinError<Unit>(action.join(), E_POINTER)
    })

    let operationWithProgressImpl = AsyncOperationWithProgressThrowingInfoImpl()
    operationWithProgressImpl.status = AsyncStatus_Error
    operationWithProgressImpl.throwWindowsOnErrorCode = true
    withThrowingAsyncOperationWithProgress(operationWithProgressImpl, { operation =>
        expectAsyncJoinError<Int32>(operation.join(), E_POINTER)
    })
}

@Test
func testIAsyncActionCompletedThunkRetainsReturnedHandlerWithoutClosingCachedWrapper() {
    let handler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        let _ = info
        let _ = status
    })
    let impl = AsyncCompletedRetainImpl(handler)
    var raw = CPointer<Unit>()

    try {
        let hr = impl.__winrtThunk_Completed(CPointer<CPointer<Unit>>(inout raw))
        @Expect(hr, S_OK.value)
        @Expect(raw.isNotNull(), true)
        @Expect(handler.isClosed(), false)
    } finally {
        if (raw.isNotNull()) {
            AsyncActionCompletedHandler.fromAbiTake(raw).close()
        }
        handler.close()
    }
}

@Test
func testNativeAsyncCompletedGettersReturnStoredHandlers() {
    let actionCounter = AtomicInt64(0)
    let action = IAsyncAction.ready()
    let actionHandler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        let _ = info
        @Expect(status == AsyncStatus_Completed, true)
        actionCounter.fetchAdd(1)
    })
    try {
        unsafe { action.SetCompleted(actionHandler) }
        @Expect(actionCounter.load(), 1)
        let returnedActionHandler = unsafe { action.Completed() }
        try {
            @Expect(returnedActionHandler.asRaw().isNotNull(), true)
            unsafe { returnedActionHandler.Invoke(action, AsyncStatus_Completed) }
            @Expect(actionCounter.load(), 2)
        } finally {
            returnedActionHandler.close()
        }
    } finally {
        actionHandler.close()
        action.close()
    }

    let operationCounter = AtomicInt64(0)
    let operation = IAsyncOperation<Int32>.ready(42i32)
    let operationHandler = AsyncOperationCompletedHandler<Int32>.new({
        info: InParam<IAsyncOperation<Int32>>,
        status: AsyncStatus =>
        let _ = info
        @Expect(status == AsyncStatus_Completed, true)
        operationCounter.fetchAdd(1)
    })
    try {
        unsafe { operation.SetCompleted(operationHandler) }
        @Expect(operationCounter.load(), 1)
        let returnedOperationHandler = unsafe { operation.Completed() }
        try {
            @Expect(returnedOperationHandler.asRaw().isNotNull(), true)
            unsafe { returnedOperationHandler.Invoke(operation, AsyncStatus_Completed) }
            @Expect(operationCounter.load(), 2)
        } finally {
            returnedOperationHandler.close()
        }
    } finally {
        operationHandler.close()
        operation.close()
    }

    let actionWithProgressCounter = AtomicInt64(0)
    let actionWithProgress = IAsyncActionWithProgress<UInt32>.ready(7u32)
    let actionWithProgressHandler = AsyncActionWithProgressCompletedHandler<UInt32>.new({
        info: InParam<IAsyncActionWithProgress<UInt32>>,
        status: AsyncStatus =>
        let _ = info
        @Expect(status == AsyncStatus_Completed, true)
        actionWithProgressCounter.fetchAdd(1)
    })
    try {
        unsafe { actionWithProgress.SetCompleted(actionWithProgressHandler) }
        @Expect(actionWithProgressCounter.load(), 1)
        let returnedActionWithProgressHandler = unsafe { actionWithProgress.Completed() }
        try {
            @Expect(returnedActionWithProgressHandler.asRaw().isNotNull(), true)
            unsafe { returnedActionWithProgressHandler.Invoke(actionWithProgress, AsyncStatus_Completed) }
            @Expect(actionWithProgressCounter.load(), 2)
        } finally {
            returnedActionWithProgressHandler.close()
        }
    } finally {
        actionWithProgressHandler.close()
        actionWithProgress.close()
    }

    let operationWithProgressCounter = AtomicInt64(0)
    let operationWithProgress = IAsyncOperationWithProgress<Int32, UInt32>.ready(11i32, 3u32)
    let operationWithProgressHandler = AsyncOperationWithProgressCompletedHandler<Int32, UInt32>.new({
        info: InParam<IAsyncOperationWithProgress<Int32, UInt32>>,
        status: AsyncStatus =>
        let _ = info
        @Expect(status == AsyncStatus_Completed, true)
        operationWithProgressCounter.fetchAdd(1)
    })
    try {
        unsafe { operationWithProgress.SetCompleted(operationWithProgressHandler) }
        @Expect(operationWithProgressCounter.load(), 1)
        let returnedOperationWithProgressHandler = unsafe { operationWithProgress.Completed() }
        try {
            @Expect(returnedOperationWithProgressHandler.asRaw().isNotNull(), true)
            unsafe { returnedOperationWithProgressHandler.Invoke(operationWithProgress, AsyncStatus_Completed) }
            @Expect(operationWithProgressCounter.load(), 2)
        } finally {
            returnedOperationWithProgressHandler.close()
        }
    } finally {
        operationWithProgressHandler.close()
        operationWithProgress.close()
    }
}

@Test
func testIAsyncInfoThunksClearOutputsAndTranslateThrownExceptions() {
    let impl = AsyncInfoThrowingImpl()

    impl.throwWindowsOnId = true
    var id = 123u32
    @Expect(impl.__winrtThunk_Id(CPointer<UInt32>(inout id)), E_POINTER.value)
    @Expect(id, 0u32)
    impl.throwWindowsOnId = false

    impl.throwPlainOnStatus = true
    var status = AsyncStatusAbi(99)
    @Expect(impl.__winrtThunk_Status(CPointer<AsyncStatusAbi>(inout status)), E_FAIL.value)
    @Expect(status.value, 0i32)
    impl.throwPlainOnStatus = false

    impl.throwPlainOnErrorCode = true
    var errorCode = HResultAbi()
    errorCode.Value = 123i32
    @Expect(impl.__winrtThunk_ErrorCode(CPointer<HResultAbi>(inout errorCode)), E_FAIL.value)
    @Expect(errorCode.Value, 0i32)
    impl.throwPlainOnErrorCode = false

    impl.throwWindowsOnCancel = true
    @Expect(impl.__winrtThunk_Cancel(), E_POINTER.value)
    impl.throwWindowsOnCancel = false

    impl.throwPlainOnClose = true
    @Expect(impl.__winrtThunk_Close(), E_FAIL.value)
    impl.throwPlainOnClose = false
}

@Test
func testDerivedAsyncInfoThunksClearOutputsAndTranslateThrownExceptions() {
    let action = AsyncActionThrowingInfoImpl()
    assertAsyncDerivedInfoThunksClearOutputsAndTranslateThrownExceptions(
        action,
        { result => action.__winrtThunk_Id(result) },
        { result => action.__winrtThunk_Status(result) },
        { result => action.__winrtThunk_ErrorCode(result) }
    )

    let actionWithProgress = AsyncActionWithProgressThrowingInfoImpl()
    assertAsyncDerivedInfoThunksClearOutputsAndTranslateThrownExceptions(
        actionWithProgress,
        { result => actionWithProgress.__winrtThunk_Id(result) },
        { result => actionWithProgress.__winrtThunk_Status(result) },
        { result => actionWithProgress.__winrtThunk_ErrorCode(result) }
    )

    let operation = AsyncOperationThrowingInfoImpl()
    assertAsyncDerivedInfoThunksClearOutputsAndTranslateThrownExceptions(
        operation,
        { result => operation.__winrtThunk_Id(result) },
        { result => operation.__winrtThunk_Status(result) },
        { result => operation.__winrtThunk_ErrorCode(result) }
    )

    let operationWithProgress = AsyncOperationWithProgressThrowingInfoImpl()
    assertAsyncDerivedInfoThunksClearOutputsAndTranslateThrownExceptions(
        operationWithProgress,
        { result => operationWithProgress.__winrtThunk_Id(result) },
        { result => operationWithProgress.__winrtThunk_Status(result) },
        { result => operationWithProgress.__winrtThunk_ErrorCode(result) }
    )
}

@Test
func testAsyncManualThunksClearOutputsAndTranslateThrownExceptions() {
    let action = AsyncActionThrowingInfoImpl()
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => action.throwWindowsOnSetCompleted = value },
        { value: Bool => action.throwPlainOnSetCompleted = value },
        { => action.__winrtThunk_SetCompleted(CPointer<Unit>()) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => action.throwWindowsOnCompleted = value },
        { value: Bool => action.throwPlainOnCompleted = value },
        { result => action.__winrtThunk_Completed(result) }
    )
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => action.throwWindowsOnGetResults = value },
        { value: Bool => action.throwPlainOnGetResults = value },
        { => action.__winrtThunk_GetResults() }
    )

    let actionWithProgress = AsyncActionWithProgressThrowingInfoImpl()
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => actionWithProgress.throwWindowsOnSetProgress = value },
        { value: Bool => actionWithProgress.throwPlainOnSetProgress = value },
        { => actionWithProgress.__winrtThunk_SetProgress(CPointer<Unit>()) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => actionWithProgress.throwWindowsOnProgress = value },
        { value: Bool => actionWithProgress.throwPlainOnProgress = value },
        { result => actionWithProgress.__winrtThunk_Progress(result) }
    )
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => actionWithProgress.throwWindowsOnSetCompleted = value },
        { value: Bool => actionWithProgress.throwPlainOnSetCompleted = value },
        { => actionWithProgress.__winrtThunk_SetCompleted(CPointer<Unit>()) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => actionWithProgress.throwWindowsOnCompleted = value },
        { value: Bool => actionWithProgress.throwPlainOnCompleted = value },
        { result => actionWithProgress.__winrtThunk_Completed(result) }
    )
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => actionWithProgress.throwWindowsOnGetResults = value },
        { value: Bool => actionWithProgress.throwPlainOnGetResults = value },
        { => actionWithProgress.__winrtThunk_GetResults() }
    )

    let operation = AsyncOperationThrowingInfoImpl()
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => operation.throwWindowsOnSetCompleted = value },
        { value: Bool => operation.throwPlainOnSetCompleted = value },
        { => operation.__winrtThunk_SetCompleted(CPointer<Unit>()) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => operation.throwWindowsOnCompleted = value },
        { value: Bool => operation.throwPlainOnCompleted = value },
        { result => operation.__winrtThunk_Completed(result) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => operation.throwWindowsOnGetResults = value },
        { value: Bool => operation.throwPlainOnGetResults = value },
        { result => operation.__winrtThunk_GetResults(result) }
    )

    let operationWithProgress = AsyncOperationWithProgressThrowingInfoImpl()
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => operationWithProgress.throwWindowsOnSetProgress = value },
        { value: Bool => operationWithProgress.throwPlainOnSetProgress = value },
        { => operationWithProgress.__winrtThunk_SetProgress(CPointer<Unit>()) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => operationWithProgress.throwWindowsOnProgress = value },
        { value: Bool => operationWithProgress.throwPlainOnProgress = value },
        { result => operationWithProgress.__winrtThunk_Progress(result) }
    )
    assertAsyncManualUnitThunkTranslatesThrownExceptions(
        { value: Bool => operationWithProgress.throwWindowsOnSetCompleted = value },
        { value: Bool => operationWithProgress.throwPlainOnSetCompleted = value },
        { => operationWithProgress.__winrtThunk_SetCompleted(CPointer<Unit>()) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => operationWithProgress.throwWindowsOnCompleted = value },
        { value: Bool => operationWithProgress.throwPlainOnCompleted = value },
        { result => operationWithProgress.__winrtThunk_Completed(result) }
    )
    assertAsyncManualComOutThunkClearsOutputsAndTranslatesThrownExceptions(
        { value: Bool => operationWithProgress.throwWindowsOnGetResults = value },
        { value: Bool => operationWithProgress.throwPlainOnGetResults = value },
        { result => operationWithProgress.__winrtThunk_GetResults(result) }
    )
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
