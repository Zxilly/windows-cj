package windows_future

import windows_interface as windows_interface
import std.collection.HashMap
import std.sync.*
import std.time.*
import windows_sys.Win32.Foundation as Win32Foundation
import windows_sys.Win32.Security as Win32Security
import windows_sys.Win32.System.Threading as Win32Threading
import windows_core
import windows_core.{ComObject, E_ABORT, E_FAIL, E_POINTER, HRESULT, HResult, HResultAbi, InParam, Result, S_OK, WinError}
import windows_interface.ComInterface
import windows_strings

type HANDLE = Win32Foundation.HANDLE
type SECURITY_ATTRIBUTES = Win32Security.SECURITY_ATTRIBUTES

// TerminalEvent wraps a manual-reset Win32 event used to signal that an async
// operation has reached a terminal status. Manual reset means once signalled
// every subsequent waiter returns immediately without blocking.
class TerminalEvent <: Resource {
    private let mutex = Mutex()
    private var handle: HANDLE = HANDLE()
    private var closed: Bool = false

    public init() {
        let h = Win32Threading.CreateEventW(CPointer<SECURITY_ATTRIBUTES>(), true, false, windows_strings.PWSTR())
        this.handle = h
    }

    public func rawHandle(): HANDLE {
        synchronized(mutex) {
            if (closed) {
                return HANDLE()
            }
            return handle
        }
    }

    public func signal(): Unit {
        synchronized(mutex) {
            if (closed) {
                return
            }
            if (handle.Value.isNotNull()) {
                Win32Threading.SetEvent(handle)
            }
        }
    }

    public func isClosed(): Bool {
        synchronized(mutex) {
            closed
        }
    }

    public func close(): Unit {
        synchronized(mutex) {
            if (closed) {
                return
            }
            closed = true
            let h = handle
            handle = HANDLE()
            if (h.Value.isNotNull()) {
                Win32Foundation.CloseHandle(h)
            }
        }
    }

    ~init() {
        if (!closed) {
            closed = true
            handle = HANDLE()
        }
    }
}

// Process-wide registry mapping async-id -> terminal event handle. Lets the
// public extend-side `waitForTerminalStatus` discover and wait on the event
// owned by our native IAsync* implementation, while still falling back to
// polling for foreign IAsyncInfo instances we did not create.
private let terminalRegistryMutex = Mutex()
private let terminalRegistry = HashMap<UInt32, TerminalEvent>()

private func registerTerminalEvent(id: UInt32, event: TerminalEvent): Unit {
    synchronized(terminalRegistryMutex) {
        terminalRegistry.add(id, event)
    }
}

private func unregisterTerminalEvent(id: UInt32): Unit {
    synchronized(terminalRegistryMutex) {
        terminalRegistry.remove(id)
    }
}

private func lookupTerminalEvent(id: UInt32): Option<TerminalEvent> {
    synchronized(terminalRegistryMutex) {
        terminalRegistry.get(id)
    }
}

private class TerminalEventRegistration <: Resource {
    private let id: UInt32
    private let active = AtomicBool(false)

    public init(id: UInt32, event: TerminalEvent) {
        this.id = id
        registerTerminalEvent(id, event)
        active.store(true)
    }

    public func close(): Unit {
        if (active.compareAndSwap(true, false)) {
            unregisterTerminalEvent(id)
        }
    }

    public func isClosed(): Bool {
        !active.load()
    }
}

private let asyncIdMutex = Mutex()
private var nextAsyncId: UInt32 = 1u32

private func allocateAsyncId(): UInt32 {
    synchronized(asyncIdMutex) {
        let id = nextAsyncId
        nextAsyncId += 1u32
        return id
    }
}

private func toFoundationHResult(code: HRESULT): HResult {
    var result = HResult()
    result.Value = code.value
    result
}

private func toCoreHRESULT(code: HResult): HRESULT {
    HRESULT(code.Value)
}

private let asyncOkCode: HResult = toFoundationHResult(S_OK)
private let asyncCanceledCode: HResult = toFoundationHResult(E_ABORT)
private let asyncFailureCode: HResult = toFoundationHResult(E_FAIL)
// HRESULT codes returned to callers that mimic the WinRT async runtime semantics. These
// values match `E_ILLEGAL_DELEGATE_ASSIGNMENT` (0x80000018) and `E_ILLEGAL_METHOD_CALL`
// (0x8000000E) in the Win32 SDK, but are kept inline here to avoid taking a dependency on
// generated native headers from the runtime package.
private let E_ILLEGAL_DELEGATE_ASSIGNMENT: HRESULT = HRESULT(-2147483624i32)
private let E_ILLEGAL_METHOD_CALL: HRESULT = HRESULT(-2147483634i32)

private func waitForTerminalStatus(info: IAsyncInfo): AsyncStatus {
    // Fast path: if status is already terminal, return immediately.
    let initial = unsafe { info.Status() }
    if (initial != AsyncStatus_Started) {
        return initial
    }
    // Try to use the registered terminal event (set by our native IAsync*
    // implementations) for an event-driven wait. Foreign IAsyncInfo instances
    // not produced by this package have no registry entry — fall through to
    // the polling path in that case.
    var eventOpt: Option<TerminalEvent> = None
    try {
        let id = unsafe { info.Id() }
        eventOpt = lookupTerminalEvent(id)
    } catch (_: Exception) {
        eventOpt = None
    }
    if (let Some(event) <- eventOpt) {
        let handle = event.rawHandle()
        if (handle.Value.isNotNull()) {
            while (true) {
                if (Thread.currentThread.hasPendingCancellation) {
                    try {
                        unsafe { info.Cancel() }
                    } catch (_: Exception) {
                        ()
                    }
                    return AsyncStatus_Canceled
                }
                let status = unsafe { info.Status() }
                if (status != AsyncStatus_Started) {
                    return status
                }
                // Wake periodically to honour cooperative cancellation while
                // still avoiding the original 1ms busy-wait CPU burn.
                Win32Threading.WaitForSingleObject(handle, 250u32)
            }
            return AsyncStatus_Error
        }
    }
    // Fallback polling loop for foreign IAsyncInfo instances.
    while (true) {
        if (Thread.currentThread.hasPendingCancellation) {
            try {
                unsafe { info.Cancel() }
            } catch (_: Exception) {
                ()
            }
            return AsyncStatus_Canceled
        }
        let status = unsafe { info.Status() }
        if (status != AsyncStatus_Started) {
            return status
        }
        sleep(Duration.millisecond * 10)
    }
    AsyncStatus_Error
}

private func failureFromInfo(info: IAsyncInfo): WinError {
    let code = unsafe { info.ErrorCode() }
    WinError.fromHRESULT(toCoreHRESULT(code))
}

private func canceledError(): WinError {
    WinError.fromHRESULT(E_ABORT)
}

private func fallbackError(): WinError {
    WinError.fromHRESULT(E_FAIL)
}

private func windowsExceptionError(error: windows_core.WindowsException): WinError {
    WinError.fromHRESULT(error.code())
}

private func emptyError(): WinError {
    WinError.fromHRESULT(S_OK)
}

private func checkedHandler<T>(handler: InParam<T>): Result<T> where T <: ComInterface {
    match (handler.ok()) {
        case Result<T>.Ok(callback) =>
            if (callback.asRaw().isNull()) {
                return Result<T>.Err(WinError.fromHRESULT(E_POINTER))
            }
            Result<T>.Ok(callback)
        case Result<T>.Err(error) =>
            Result<T>.Err(error)
    }
}

public class ProgressReporter<TProgress> where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    private let report_: (TProgress) -> Unit

    public init(report: (TProgress) -> Unit) {
        this.report_ = report
    }

    public func report(value: TProgress): Unit {
        report_(value)
    }
}

private class NativeAsyncActionImpl <: IAsyncAction_Impl & Resource {
    private let mutex = Mutex()
    private let id: UInt32 = allocateAsyncId()
    private let terminal: TerminalEvent = TerminalEvent()
    private let terminalRegistration: TerminalEventRegistration
    private let infoVtblHandle: CPointer<IAsyncInfoVtbl>
    private let vtblHandle: CPointer<IAsyncActionVtbl>
    private var closed: Bool = false
    private var status: AsyncStatus = AsyncStatus_Started
    private var errorCode: HResult = asyncOkCode
    private var completedHandler: Option<AsyncActionCompletedHandler> = None
    private var view: Option<IAsyncAction> = None
    private var worker: Option<Future<Unit>> = None

    public init(status!: AsyncStatus = AsyncStatus_Started, errorCode!: HResult = asyncOkCode) {
        this.status = status
        this.errorCode = errorCode
        this.infoVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncInfoVtbl>(IAsyncInfoVtbl.new<NativeAsyncActionImpl>())
        }
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncActionVtbl>(IAsyncActionVtbl.new<NativeAsyncActionImpl>())
        }
        this.terminalRegistration = TerminalEventRegistration(this.id, this.terminal)
        if (status != AsyncStatus_Started) {
            this.terminal.signal()
            this.terminalRegistration.close()
        }
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func bindView(view: IAsyncAction): Unit {
        synchronized(mutex) {
            this.view = Some(view)
        }
    }

    public func attachWorker(worker: Future<Unit>): Unit {
        synchronized(mutex) {
            this.worker = Some(worker)
        }
    }

    public func vtblPtrs(): Array<CPointer<Unit>> {
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(vtblHandle)]
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        terminalRegistration.close()
        terminal.close()
        unsafe {
            windows_interface.freeNativeValue(vtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
        closed = true
    }

    private func finish(status: AsyncStatus, errorCode!: HResult = asyncOkCode): Unit {
        var handler: Option<AsyncActionCompletedHandler> = None
        var view: Option<IAsyncAction> = None
        synchronized(mutex) {
            if (this.status != AsyncStatus_Started) {
                return
            }
            this.status = status
            this.errorCode = errorCode
            handler = completedHandler
            view = this.view
        }
        terminal.signal()
        terminalRegistration.close()
        if (let Some(callback) <- handler) {
            if (let Some(asyncView) <- view) {
                unsafe { callback.Invoke(asyncView, status) }
            }
        }
    }

    public func complete(): Unit {
        finish(AsyncStatus_Completed)
    }

    public func cancelFromWorker(): Unit {
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
    }

    public func fail(code: HResult): Unit {
        finish(AsyncStatus_Error, errorCode: code)
    }

    public func Id(): Result<UInt32> {
        Result<UInt32>.Ok(id)
    }

    public func Status(): Result<AsyncStatus> {
        synchronized(mutex) {
            Result<AsyncStatus>.Ok(status)
        }
    }

    public func ErrorCode(): Result<HResult> {
        synchronized(mutex) {
            Result<HResult>.Ok(errorCode)
        }
    }

    public func Cancel(): Result<Unit> {
        var workerCopy: Option<Future<Unit>> = None
        synchronized(mutex) {
            workerCopy = worker
        }
        if (let Some(value) <- workerCopy) {
            value.cancel()
        }
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        terminalRegistration.close()
        Result<Unit>.Ok(())
    }

    public func SetCompleted(handler: InParam<AsyncActionCompletedHandler>): Result<Unit> {
        var callback: Option<AsyncActionCompletedHandler> = None
        var view: Option<IAsyncAction> = None
        var status = AsyncStatus_Started
        var invokeNow = false
        synchronized(mutex) {
            if (completedHandler.isSome()) {
                return Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_DELEGATE_ASSIGNMENT))
            }
            match (checkedHandler(handler)) {
                case Result<AsyncActionCompletedHandler>.Ok(value) =>
                    callback = Some(value)
                    completedHandler = Some(value)
                case Result<AsyncActionCompletedHandler>.Err(error) =>
                    return Result<Unit>.Err(error)
            }
            view = this.view
            status = this.status
            invokeNow = status != AsyncStatus_Started
        }
        if (invokeNow) {
            if (let Some(value) <- callback) {
                if (let Some(asyncView) <- view) {
                    unsafe { value.Invoke(asyncView, status) }
                }
            }
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncActionCompletedHandler> {
        synchronized(mutex) {
            match (completedHandler) {
                case Some(value) => Result<AsyncActionCompletedHandler>.Ok(value)
                case None => Result<AsyncActionCompletedHandler>.Err(emptyError())
            }
        }
    }

    public func GetResults(): Result<Unit> {
        synchronized(mutex) {
            if (status == AsyncStatus_Completed) {
                return Result<Unit>.Ok(())
            }
            if (status == AsyncStatus_Canceled) {
                return Result<Unit>.Err(canceledError())
            }
            if (status == AsyncStatus_Error) {
                return Result<Unit>.Err(WinError.fromHRESULT(toCoreHRESULT(errorCode)))
            }
            // status is AsyncStatus_Started: GetResults must not be called before completion.
            Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_METHOD_CALL))
        }
    }
}

private class NativeAsyncOperationImpl<TResult> <: IAsyncOperation_Impl<TResult> & Resource
    where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    private let mutex = Mutex()
    private let id: UInt32 = allocateAsyncId()
    private let terminal: TerminalEvent = TerminalEvent()
    private let terminalRegistration: TerminalEventRegistration
    private let infoVtblHandle: CPointer<IAsyncInfoVtbl>
    private let vtblHandle: CPointer<IAsyncOperationVtbl>
    private var closed: Bool = false
    private var status: AsyncStatus = AsyncStatus_Started
    private var errorCode: HResult = asyncOkCode
    private var completedHandler: Option<AsyncOperationCompletedHandler<TResult>> = None
    private var result: Option<TResult> = None
    private var view: Option<IAsyncOperation<TResult>> = None
    private var worker: Option<Future<Unit>> = None

    public init(
        status!: AsyncStatus = AsyncStatus_Started,
        errorCode!: HResult = asyncOkCode,
        result!: Option<TResult> = None
    ) {
        this.status = status
        this.errorCode = errorCode
        this.result = result
        this.infoVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncInfoVtbl>(IAsyncInfoVtbl.new<NativeAsyncOperationImpl<TResult>>())
        }
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncOperationVtbl>(IAsyncOperationVtbl.new<NativeAsyncOperationImpl<TResult>, TResult>())
        }
        this.terminalRegistration = TerminalEventRegistration(this.id, this.terminal)
        if (status != AsyncStatus_Started) {
            this.terminal.signal()
            this.terminalRegistration.close()
        }
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func bindView(view: IAsyncOperation<TResult>): Unit {
        synchronized(mutex) {
            this.view = Some(view)
        }
    }

    public func attachWorker(worker: Future<Unit>): Unit {
        synchronized(mutex) {
            this.worker = Some(worker)
        }
    }

    public func vtblPtrs(): Array<CPointer<Unit>> {
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(vtblHandle)]
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        terminalRegistration.close()
        terminal.close()
        unsafe {
            windows_interface.freeNativeValue(vtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
        closed = true
    }

    private func finish(
        status: AsyncStatus,
        errorCode!: HResult = asyncOkCode,
        result!: Option<TResult> = None
    ): Unit {
        var handler: Option<AsyncOperationCompletedHandler<TResult>> = None
        var view: Option<IAsyncOperation<TResult>> = None
        synchronized(mutex) {
            if (this.status != AsyncStatus_Started) {
                return
            }
            this.status = status
            this.errorCode = errorCode
            this.result = result
            handler = completedHandler
            view = this.view
        }
        terminal.signal()
        terminalRegistration.close()
        if (let Some(callback) <- handler) {
            if (let Some(asyncView) <- view) {
                unsafe { callback.Invoke(asyncView, status) }
            }
        }
    }

    public func complete(result: TResult): Unit {
        finish(AsyncStatus_Completed, result: Some(result))
    }

    public func cancelFromWorker(): Unit {
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
    }

    public func fail(code: HResult): Unit {
        finish(AsyncStatus_Error, errorCode: code)
    }

    public func Id(): Result<UInt32> {
        Result<UInt32>.Ok(id)
    }

    public func Status(): Result<AsyncStatus> {
        synchronized(mutex) {
            Result<AsyncStatus>.Ok(status)
        }
    }

    public func ErrorCode(): Result<HResult> {
        synchronized(mutex) {
            Result<HResult>.Ok(errorCode)
        }
    }

    public func Cancel(): Result<Unit> {
        var workerCopy: Option<Future<Unit>> = None
        synchronized(mutex) {
            workerCopy = worker
        }
        if (let Some(value) <- workerCopy) {
            value.cancel()
        }
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        terminalRegistration.close()
        Result<Unit>.Ok(())
    }

    public func SetCompleted(handler: InParam<AsyncOperationCompletedHandler<TResult>>): Result<Unit> {
        var callback: Option<AsyncOperationCompletedHandler<TResult>> = None
        var view: Option<IAsyncOperation<TResult>> = None
        var status = AsyncStatus_Started
        var invokeNow = false
        synchronized(mutex) {
            if (completedHandler.isSome()) {
                return Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_DELEGATE_ASSIGNMENT))
            }
            match (checkedHandler(handler)) {
                case Result<AsyncOperationCompletedHandler<TResult>>.Ok(value) =>
                    callback = Some(value)
                    completedHandler = Some(value)
                case Result<AsyncOperationCompletedHandler<TResult>>.Err(error) =>
                    return Result<Unit>.Err(error)
            }
            view = this.view
            status = this.status
            invokeNow = status != AsyncStatus_Started
        }
        if (invokeNow) {
            if (let Some(value) <- callback) {
                if (let Some(asyncView) <- view) {
                    unsafe { value.Invoke(asyncView, status) }
                }
            }
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncOperationCompletedHandler<TResult>> {
        synchronized(mutex) {
            match (completedHandler) {
                case Some(value) => Result<AsyncOperationCompletedHandler<TResult>>.Ok(value)
                case None => Result<AsyncOperationCompletedHandler<TResult>>.Err(emptyError())
            }
        }
    }

    public func GetResults(): Result<TResult> {
        synchronized(mutex) {
            if (status == AsyncStatus_Completed) {
                match (result) {
                    case Some(value) => return Result<TResult>.Ok(value)
                    case None => return Result<TResult>.Err(WinError.fromHRESULT(E_FAIL))
                }
            }
            if (status == AsyncStatus_Canceled) {
                return Result<TResult>.Err(canceledError())
            }
            if (status == AsyncStatus_Error) {
                return Result<TResult>.Err(WinError.fromHRESULT(toCoreHRESULT(errorCode)))
            }
            // status is AsyncStatus_Started: GetResults must not be called before completion.
            Result<TResult>.Err(WinError.fromHRESULT(E_ILLEGAL_METHOD_CALL))
        }
    }
}

private class NativeAsyncActionWithProgressImpl<TProgress> <: IAsyncActionWithProgress_Impl<TProgress> & Resource
    where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    private let mutex = Mutex()
    private let id: UInt32 = allocateAsyncId()
    private let terminal: TerminalEvent = TerminalEvent()
    private let terminalRegistration: TerminalEventRegistration
    private let infoVtblHandle: CPointer<IAsyncInfoVtbl>
    private let vtblHandle: CPointer<IAsyncActionWithProgressVtbl>
    private var closed: Bool = false
    private var status: AsyncStatus = AsyncStatus_Started
    private var errorCode: HResult = asyncOkCode
    private var progressHandler: Option<AsyncActionProgressHandler<TProgress>> = None
    private var completedHandler: Option<AsyncActionWithProgressCompletedHandler<TProgress>> = None
    private var lastProgress: Option<TProgress> = None
    private var view: Option<IAsyncActionWithProgress<TProgress>> = None
    private var worker: Option<Future<Unit>> = None

    public init(
        status!: AsyncStatus = AsyncStatus_Started,
        errorCode!: HResult = asyncOkCode,
        lastProgress!: Option<TProgress> = None
    ) {
        this.status = status
        this.errorCode = errorCode
        this.lastProgress = lastProgress
        this.infoVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncInfoVtbl>(IAsyncInfoVtbl.new<NativeAsyncActionWithProgressImpl<TProgress>>())
        }
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncActionWithProgressVtbl>(
                IAsyncActionWithProgressVtbl.new<NativeAsyncActionWithProgressImpl<TProgress>, TProgress>()
            )
        }
        this.terminalRegistration = TerminalEventRegistration(this.id, this.terminal)
        if (status != AsyncStatus_Started) {
            this.terminal.signal()
            this.terminalRegistration.close()
        }
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func bindView(view: IAsyncActionWithProgress<TProgress>): Unit {
        synchronized(mutex) {
            this.view = Some(view)
        }
    }

    public func attachWorker(worker: Future<Unit>): Unit {
        synchronized(mutex) {
            this.worker = Some(worker)
        }
    }

    public func vtblPtrs(): Array<CPointer<Unit>> {
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(vtblHandle)]
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        terminalRegistration.close()
        terminal.close()
        unsafe {
            windows_interface.freeNativeValue(vtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
        closed = true
    }

    public func reportProgress(progress: TProgress): Unit {
        var handler: Option<AsyncActionProgressHandler<TProgress>> = None
        var view: Option<IAsyncActionWithProgress<TProgress>> = None
        synchronized(mutex) {
            lastProgress = Some(progress)
            handler = progressHandler
            view = this.view
        }
        if (let Some(callback) <- handler) {
            if (let Some(asyncView) <- view) {
                unsafe { callback.Invoke(asyncView, progress) }
            }
        }
    }

    private func finish(status: AsyncStatus, errorCode!: HResult = asyncOkCode): Unit {
        var handler: Option<AsyncActionWithProgressCompletedHandler<TProgress>> = None
        var view: Option<IAsyncActionWithProgress<TProgress>> = None
        synchronized(mutex) {
            if (this.status != AsyncStatus_Started) {
                return
            }
            this.status = status
            this.errorCode = errorCode
            handler = completedHandler
            view = this.view
        }
        terminal.signal()
        terminalRegistration.close()
        if (let Some(callback) <- handler) {
            if (let Some(asyncView) <- view) {
                unsafe { callback.Invoke(asyncView, status) }
            }
        }
    }

    public func complete(): Unit {
        finish(AsyncStatus_Completed)
    }

    public func cancelFromWorker(): Unit {
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
    }

    public func fail(code: HResult): Unit {
        finish(AsyncStatus_Error, errorCode: code)
    }

    public func Id(): Result<UInt32> {
        Result<UInt32>.Ok(id)
    }

    public func Status(): Result<AsyncStatus> {
        synchronized(mutex) {
            Result<AsyncStatus>.Ok(status)
        }
    }

    public func ErrorCode(): Result<HResult> {
        synchronized(mutex) {
            Result<HResult>.Ok(errorCode)
        }
    }

    public func Cancel(): Result<Unit> {
        var workerCopy: Option<Future<Unit>> = None
        synchronized(mutex) {
            workerCopy = worker
        }
        if (let Some(value) <- workerCopy) {
            value.cancel()
        }
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        terminalRegistration.close()
        Result<Unit>.Ok(())
    }

    public func SetProgress(handler: InParam<AsyncActionProgressHandler<TProgress>>): Result<Unit> {
        synchronized(mutex) {
            if (progressHandler.isSome()) {
                return Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_DELEGATE_ASSIGNMENT))
            }
            match (checkedHandler(handler)) {
                case Result<AsyncActionProgressHandler<TProgress>>.Ok(value) =>
                    progressHandler = Some(value)
                case Result<AsyncActionProgressHandler<TProgress>>.Err(error) =>
                    return Result<Unit>.Err(error)
            }
        }
        Result<Unit>.Ok(())
    }

    public func Progress(): Result<AsyncActionProgressHandler<TProgress>> {
        synchronized(mutex) {
            match (progressHandler) {
                case Some(value) => Result<AsyncActionProgressHandler<TProgress>>.Ok(value)
                case None => Result<AsyncActionProgressHandler<TProgress>>.Err(emptyError())
            }
        }
    }

    public func SetCompleted(handler: InParam<AsyncActionWithProgressCompletedHandler<TProgress>>): Result<Unit> {
        var callback: Option<AsyncActionWithProgressCompletedHandler<TProgress>> = None
        var view: Option<IAsyncActionWithProgress<TProgress>> = None
        var status = AsyncStatus_Started
        var invokeNow = false
        synchronized(mutex) {
            if (completedHandler.isSome()) {
                return Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_DELEGATE_ASSIGNMENT))
            }
            match (checkedHandler(handler)) {
                case Result<AsyncActionWithProgressCompletedHandler<TProgress>>.Ok(value) =>
                    callback = Some(value)
                    completedHandler = Some(value)
                case Result<AsyncActionWithProgressCompletedHandler<TProgress>>.Err(error) =>
                    return Result<Unit>.Err(error)
            }
            view = this.view
            status = this.status
            invokeNow = status != AsyncStatus_Started
        }
        if (invokeNow) {
            if (let Some(value) <- callback) {
                if (let Some(asyncView) <- view) {
                    unsafe { value.Invoke(asyncView, status) }
                }
            }
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncActionWithProgressCompletedHandler<TProgress>> {
        synchronized(mutex) {
            match (completedHandler) {
                case Some(value) => Result<AsyncActionWithProgressCompletedHandler<TProgress>>.Ok(value)
                case None => Result<AsyncActionWithProgressCompletedHandler<TProgress>>.Err(emptyError())
            }
        }
    }

    public func GetResults(): Result<Unit> {
        synchronized(mutex) {
            if (status == AsyncStatus_Completed) {
                return Result<Unit>.Ok(())
            }
            if (status == AsyncStatus_Canceled) {
                return Result<Unit>.Err(canceledError())
            }
            if (status == AsyncStatus_Error) {
                return Result<Unit>.Err(WinError.fromHRESULT(toCoreHRESULT(errorCode)))
            }
            // status is AsyncStatus_Started: GetResults must not be called before completion.
            Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_METHOD_CALL))
        }
    }
}

private class NativeAsyncOperationWithProgressImpl<TResult, TProgress> <: IAsyncOperationWithProgress_Impl<TResult, TProgress> & Resource
    where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>,
        TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    private let mutex = Mutex()
    private let id: UInt32 = allocateAsyncId()
    private let terminal: TerminalEvent = TerminalEvent()
    private let terminalRegistration: TerminalEventRegistration
    private let infoVtblHandle: CPointer<IAsyncInfoVtbl>
    private let vtblHandle: CPointer<IAsyncOperationWithProgressVtbl>
    private var closed: Bool = false
    private var status: AsyncStatus = AsyncStatus_Started
    private var errorCode: HResult = asyncOkCode
    private var progressHandler: Option<AsyncOperationProgressHandler<TResult, TProgress>> = None
    private var completedHandler: Option<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>> = None
    private var result: Option<TResult> = None
    private var lastProgress: Option<TProgress> = None
    private var view: Option<IAsyncOperationWithProgress<TResult, TProgress>> = None
    private var worker: Option<Future<Unit>> = None

    public init(
        status!: AsyncStatus = AsyncStatus_Started,
        errorCode!: HResult = asyncOkCode,
        result!: Option<TResult> = None,
        lastProgress!: Option<TProgress> = None
    ) {
        this.status = status
        this.errorCode = errorCode
        this.result = result
        this.lastProgress = lastProgress
        this.infoVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncInfoVtbl>(IAsyncInfoVtbl.new<NativeAsyncOperationWithProgressImpl<TResult, TProgress>>())
        }
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IAsyncOperationWithProgressVtbl>(
                IAsyncOperationWithProgressVtbl.new<
                    NativeAsyncOperationWithProgressImpl<TResult, TProgress>,
                    TResult,
                    TProgress
                >()
            )
        }
        this.terminalRegistration = TerminalEventRegistration(this.id, this.terminal)
        if (status != AsyncStatus_Started) {
            this.terminal.signal()
            this.terminalRegistration.close()
        }
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func bindView(view: IAsyncOperationWithProgress<TResult, TProgress>): Unit {
        synchronized(mutex) {
            this.view = Some(view)
        }
    }

    public func attachWorker(worker: Future<Unit>): Unit {
        synchronized(mutex) {
            this.worker = Some(worker)
        }
    }

    public func vtblPtrs(): Array<CPointer<Unit>> {
        [CPointer<Unit>(infoVtblHandle), CPointer<Unit>(vtblHandle)]
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        terminalRegistration.close()
        terminal.close()
        unsafe {
            windows_interface.freeNativeValue(vtblHandle)
            windows_interface.freeNativeValue(infoVtblHandle)
        }
        closed = true
    }

    public func reportProgress(progress: TProgress): Unit {
        var handler: Option<AsyncOperationProgressHandler<TResult, TProgress>> = None
        var view: Option<IAsyncOperationWithProgress<TResult, TProgress>> = None
        synchronized(mutex) {
            lastProgress = Some(progress)
            handler = progressHandler
            view = this.view
        }
        if (let Some(callback) <- handler) {
            if (let Some(asyncView) <- view) {
                unsafe { callback.Invoke(asyncView, progress) }
            }
        }
    }

    private func finish(
        status: AsyncStatus,
        errorCode!: HResult = asyncOkCode,
        result!: Option<TResult> = None
    ): Unit {
        var handler: Option<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>> = None
        var view: Option<IAsyncOperationWithProgress<TResult, TProgress>> = None
        synchronized(mutex) {
            if (this.status != AsyncStatus_Started) {
                return
            }
            this.status = status
            this.errorCode = errorCode
            this.result = result
            handler = completedHandler
            view = this.view
        }
        terminal.signal()
        terminalRegistration.close()
        if (let Some(callback) <- handler) {
            if (let Some(asyncView) <- view) {
                unsafe { callback.Invoke(asyncView, status) }
            }
        }
    }

    public func complete(result: TResult): Unit {
        finish(AsyncStatus_Completed, result: Some(result))
    }

    public func cancelFromWorker(): Unit {
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
    }

    public func fail(code: HResult): Unit {
        finish(AsyncStatus_Error, errorCode: code)
    }

    public func Id(): Result<UInt32> {
        Result<UInt32>.Ok(id)
    }

    public func Status(): Result<AsyncStatus> {
        synchronized(mutex) {
            Result<AsyncStatus>.Ok(status)
        }
    }

    public func ErrorCode(): Result<HResult> {
        synchronized(mutex) {
            Result<HResult>.Ok(errorCode)
        }
    }

    public func Cancel(): Result<Unit> {
        var workerCopy: Option<Future<Unit>> = None
        synchronized(mutex) {
            workerCopy = worker
        }
        if (let Some(value) <- workerCopy) {
            value.cancel()
        }
        finish(AsyncStatus_Canceled, errorCode: asyncCanceledCode)
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        terminalRegistration.close()
        Result<Unit>.Ok(())
    }

    public func SetProgress(handler: InParam<AsyncOperationProgressHandler<TResult, TProgress>>): Result<Unit> {
        synchronized(mutex) {
            if (progressHandler.isSome()) {
                return Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_DELEGATE_ASSIGNMENT))
            }
            match (checkedHandler(handler)) {
                case Result<AsyncOperationProgressHandler<TResult, TProgress>>.Ok(value) =>
                    progressHandler = Some(value)
                case Result<AsyncOperationProgressHandler<TResult, TProgress>>.Err(error) =>
                    return Result<Unit>.Err(error)
            }
        }
        Result<Unit>.Ok(())
    }

    public func Progress(): Result<AsyncOperationProgressHandler<TResult, TProgress>> {
        synchronized(mutex) {
            match (progressHandler) {
                case Some(value) => Result<AsyncOperationProgressHandler<TResult, TProgress>>.Ok(value)
                case None => Result<AsyncOperationProgressHandler<TResult, TProgress>>.Err(emptyError())
            }
        }
    }

    public func SetCompleted(handler: InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>): Result<Unit> {
        var callback: Option<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>> = None
        var view: Option<IAsyncOperationWithProgress<TResult, TProgress>> = None
        var status = AsyncStatus_Started
        var invokeNow = false
        synchronized(mutex) {
            if (completedHandler.isSome()) {
                return Result<Unit>.Err(WinError.fromHRESULT(E_ILLEGAL_DELEGATE_ASSIGNMENT))
            }
            match (checkedHandler(handler)) {
                case Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>.Ok(value) =>
                    callback = Some(value)
                    completedHandler = Some(value)
                case Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>.Err(error) =>
                    return Result<Unit>.Err(error)
            }
            view = this.view
            status = this.status
            invokeNow = status != AsyncStatus_Started
        }
        if (invokeNow) {
            if (let Some(value) <- callback) {
                if (let Some(asyncView) <- view) {
                    unsafe { value.Invoke(asyncView, status) }
                }
            }
        }
        Result<Unit>.Ok(())
    }

    public func Completed(): Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>> {
        synchronized(mutex) {
            match (completedHandler) {
                case Some(value) => Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>.Ok(value)
                case None => Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>.Err(emptyError())
            }
        }
    }

    public func GetResults(): Result<TResult> {
        synchronized(mutex) {
            if (status == AsyncStatus_Completed) {
                match (result) {
                    case Some(value) => return Result<TResult>.Ok(value)
                    case None => return Result<TResult>.Err(WinError.fromHRESULT(E_FAIL))
                }
            }
            if (status == AsyncStatus_Canceled) {
                return Result<TResult>.Err(canceledError())
            }
            if (status == AsyncStatus_Error) {
                return Result<TResult>.Err(WinError.fromHRESULT(toCoreHRESULT(errorCode)))
            }
            // status is AsyncStatus_Started: GetResults must not be called before completion.
            Result<TResult>.Err(WinError.fromHRESULT(E_ILLEGAL_METHOD_CALL))
        }
    }
}

private func createAsyncActionImpl(impl: NativeAsyncActionImpl): IAsyncAction {
    let object = ComObject<NativeAsyncActionImpl>.new(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncAction.descriptorSchema()],
        impl.vtblPtrs()
    )
    let view = object.intoInterface(IAsyncAction.descriptor())
    impl.bindView(view)
    view
}

private func createAsyncOperationImpl<TResult>(impl: NativeAsyncOperationImpl<TResult>): IAsyncOperation<TResult>
    where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    let object = ComObject<NativeAsyncOperationImpl<TResult>>.new(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncOperation<TResult>.descriptorSchema()],
        impl.vtblPtrs()
    )
    let view = object.intoInterface(IAsyncOperation<TResult>.descriptor())
    impl.bindView(view)
    view
}

private func createAsyncActionWithProgressImpl<TProgress>(
    impl: NativeAsyncActionWithProgressImpl<TProgress>
): IAsyncActionWithProgress<TProgress> where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    let object = ComObject<NativeAsyncActionWithProgressImpl<TProgress>>.new(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncActionWithProgress<TProgress>.descriptorSchema()],
        impl.vtblPtrs()
    )
    let view = object.intoInterface(IAsyncActionWithProgress<TProgress>.descriptor())
    impl.bindView(view)
    view
}

private func createAsyncOperationWithProgressImpl<TResult, TProgress>(
    impl: NativeAsyncOperationWithProgressImpl<TResult, TProgress>
): IAsyncOperationWithProgress<TResult, TProgress>
    where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>,
        TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    let object = ComObject<NativeAsyncOperationWithProgressImpl<TResult, TProgress>>.new(
        impl,
        [IAsyncInfo.descriptorSchema(), IAsyncOperationWithProgress<TResult, TProgress>.descriptorSchema()],
        impl.vtblPtrs()
    )
    let view = object.intoInterface(IAsyncOperationWithProgress<TResult, TProgress>.descriptor())
    impl.bindView(view)
    view
}

extend IAsyncAction {
    public func join(): Result<Unit> {
        try {
            try (info = asIAsyncInfo()) {
                let status = waitForTerminalStatus(info)
                if (status == AsyncStatus_Completed) {
                    unsafe { GetResults() }
                    return Result<Unit>.Ok(())
                }
                if (status == AsyncStatus_Error) {
                    return Result<Unit>.Err(failureFromInfo(info))
                }
                return Result<Unit>.Err(canceledError())
            }
            throw IllegalStateException("IAsyncAction.join async-info call did not execute")
        } catch (error: windows_core.WindowsException) {
            Result<Unit>.Err(windowsExceptionError(error))
        } catch (_: Exception) {
            Result<Unit>.Err(fallbackError())
        }
    }

    public func when(): Future<Result<Unit>> {
        let action = this
        spawn { action.join() }
    }

    public static func ready(): IAsyncAction {
        createAsyncActionImpl(NativeAsyncActionImpl(status: AsyncStatus_Completed))
    }

    public static func spawnAsync(work: () -> Unit): IAsyncAction {
        let impl = NativeAsyncActionImpl()
        let action = createAsyncActionImpl(impl)
        let worker = spawn {
            try {
                work()
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.complete()
                }
            } catch (error: windows_core.WindowsException) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(toFoundationHResult(error.code()))
                }
            } catch (_: Exception) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(asyncFailureCode)
                }
            }
        }
        impl.attachWorker(worker)
        action
    }
}

extend<TResult> IAsyncOperation<TResult> where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    public func join(): Result<TResult> {
        try {
            try (info = asIAsyncInfo()) {
                let status = waitForTerminalStatus(info)
                if (status == AsyncStatus_Completed) {
                    return Result<TResult>.Ok(unsafe { GetResults() })
                }
                if (status == AsyncStatus_Error) {
                    return Result<TResult>.Err(failureFromInfo(info))
                }
                return Result<TResult>.Err(canceledError())
            }
            throw IllegalStateException("IAsyncOperation.join async-info call did not execute")
        } catch (error: windows_core.WindowsException) {
            Result<TResult>.Err(windowsExceptionError(error))
        } catch (_: Exception) {
            Result<TResult>.Err(fallbackError())
        }
    }

    public func when(): Future<Result<TResult>> {
        let operation = this
        spawn { operation.join() }
    }

    public static func ready(result: TResult): IAsyncOperation<TResult> {
        createAsyncOperationImpl(NativeAsyncOperationImpl<TResult>(status: AsyncStatus_Completed, result: Some(result)))
    }

    public static func spawnAsync(work: () -> TResult): IAsyncOperation<TResult> {
        let impl = NativeAsyncOperationImpl<TResult>()
        let operation = createAsyncOperationImpl(impl)
        let worker = spawn {
            try {
                let result = work()
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.complete(result)
                }
            } catch (error: windows_core.WindowsException) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(toFoundationHResult(error.code()))
                }
            } catch (_: Exception) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(asyncFailureCode)
                }
            }
        }
        impl.attachWorker(worker)
        operation
    }
}

extend<TProgress> IAsyncActionWithProgress<TProgress> where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func join(): Result<Unit> {
        try {
            try (info = asIAsyncInfo()) {
                let status = waitForTerminalStatus(info)
                if (status == AsyncStatus_Completed) {
                    unsafe { GetResults() }
                    return Result<Unit>.Ok(())
                }
                if (status == AsyncStatus_Error) {
                    return Result<Unit>.Err(failureFromInfo(info))
                }
                return Result<Unit>.Err(canceledError())
            }
            throw IllegalStateException("IAsyncActionWithProgress.join async-info call did not execute")
        } catch (error: windows_core.WindowsException) {
            Result<Unit>.Err(windowsExceptionError(error))
        } catch (_: Exception) {
            Result<Unit>.Err(fallbackError())
        }
    }

    public func when(): Future<Result<Unit>> {
        let action = this
        spawn { action.join() }
    }

    public static func ready(progress: TProgress): IAsyncActionWithProgress<TProgress> {
        createAsyncActionWithProgressImpl(
            NativeAsyncActionWithProgressImpl<TProgress>(
                status: AsyncStatus_Completed,
                lastProgress: Some(progress)
            )
        )
    }

    public static func spawnAsync(work: (ProgressReporter<TProgress>) -> Unit): IAsyncActionWithProgress<TProgress> {
        let impl = NativeAsyncActionWithProgressImpl<TProgress>()
        let action = createAsyncActionWithProgressImpl(impl)
        let reporter = ProgressReporter<TProgress>({ progress => impl.reportProgress(progress) })
        let worker = spawn {
            try {
                work(reporter)
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.complete()
                }
            } catch (error: windows_core.WindowsException) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(toFoundationHResult(error.code()))
                }
            } catch (_: Exception) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(asyncFailureCode)
                }
            }
        }
        impl.attachWorker(worker)
        action
    }
}

extend<TResult, TProgress> IAsyncOperationWithProgress<TResult, TProgress>
    where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>,
        TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func join(): Result<TResult> {
        try {
            try (info = asIAsyncInfo()) {
                let status = waitForTerminalStatus(info)
                if (status == AsyncStatus_Completed) {
                    return Result<TResult>.Ok(unsafe { GetResults() })
                }
                if (status == AsyncStatus_Error) {
                    return Result<TResult>.Err(failureFromInfo(info))
                }
                return Result<TResult>.Err(canceledError())
            }
            throw IllegalStateException("IAsyncOperationWithProgress.join async-info call did not execute")
        } catch (error: windows_core.WindowsException) {
            Result<TResult>.Err(windowsExceptionError(error))
        } catch (_: Exception) {
            Result<TResult>.Err(fallbackError())
        }
    }

    public func when(): Future<Result<TResult>> {
        let operation = this
        spawn { operation.join() }
    }

    public static func ready(result: TResult, progress: TProgress): IAsyncOperationWithProgress<TResult, TProgress> {
        createAsyncOperationWithProgressImpl(
            NativeAsyncOperationWithProgressImpl<TResult, TProgress>(
                status: AsyncStatus_Completed,
                result: Some(result),
                lastProgress: Some(progress)
            )
        )
    }

    public static func spawnAsync(
        work: (ProgressReporter<TProgress>) -> TResult
    ): IAsyncOperationWithProgress<TResult, TProgress> {
        let impl = NativeAsyncOperationWithProgressImpl<TResult, TProgress>()
        let operation = createAsyncOperationWithProgressImpl(impl)
        let reporter = ProgressReporter<TProgress>({ progress => impl.reportProgress(progress) })
        let worker = spawn {
            try {
                let result = work(reporter)
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.complete(result)
                }
            } catch (error: windows_core.WindowsException) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(toFoundationHResult(error.code()))
                }
            } catch (_: Exception) {
                if (Thread.currentThread.hasPendingCancellation) {
                    impl.cancelFromWorker()
                } else {
                    impl.fail(asyncFailureCode)
                }
            }
        }
        impl.attachWorker(worker)
        operation
    }
}
