package windows_threading

import std.collection.HashMap
import std.sync.Mutex

public type BOOL = Int32
public type PTP_CALLBACK_INSTANCE = CPointer<Unit>
public type PTP_CLEANUP_GROUP = CPointer<Unit>
public type PTP_CLEANUP_GROUP_CANCEL_CALLBACK = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>
public type PTP_POOL = CPointer<Unit>
public type PTP_SIMPLE_CALLBACK = CFunc<(PTP_CALLBACK_INSTANCE, CPointer<Unit>) -> Unit>

private let TP_CALLBACK_PRIORITY_NORMAL = 1i32

// Minimal ABI slice used by windows-threading.
// Keep these declarations aligned with the native threadpool ABI.
@C
public struct TP_CALLBACK_ENVIRON_V3 {
    public var Version: UInt32 = 0
    public var Pool: PTP_POOL = CPointer<Unit>()
    public var CleanupGroup: PTP_CLEANUP_GROUP = CPointer<Unit>()
    public var CleanupGroupCancelCallback: PTP_CLEANUP_GROUP_CANCEL_CALLBACK = { _, _ => () }
    public var RaceDll: CPointer<Unit> = CPointer<Unit>()
    public var ActivationContext: IntNative = 0
    public var FinalizationCallback: PTP_SIMPLE_CALLBACK = { _, _ => () }
    public var Flags: UInt32 = 0
    public var CallbackPriority: Int32 = 0
    public var Size: UInt32 = 0
    public init() {}
}

foreign {
    func CloseThreadpool(ptpp: PTP_POOL): Unit
    func CloseThreadpoolCleanupGroup(ptpcg: PTP_CLEANUP_GROUP): Unit
    func CloseThreadpoolCleanupGroupMembers(
        ptpcg: PTP_CLEANUP_GROUP,
        fCancelPendingCallbacks: BOOL,
        pvCleanupContext: CPointer<Unit>
    ): Unit
    func CreateThreadpool(reserved: CPointer<Unit>): PTP_POOL
    func CreateThreadpoolCleanupGroup(): PTP_CLEANUP_GROUP
    func GetCurrentThreadId(): UInt32
    func SetThreadpoolThreadMaximum(ptpp: PTP_POOL, cthrdMost: UInt32): Unit
    func SetThreadpoolThreadMinimum(ptpp: PTP_POOL, cthrdMic: UInt32): BOOL
    func Sleep(dwMilliseconds: UInt32): Unit
    func TrySubmitThreadpoolCallback(
        pfns: PTP_SIMPLE_CALLBACK,
        pv: CPointer<Unit>,
        pcbe: CPointer<TP_CALLBACK_ENVIRON_V3>
    ): BOOL
}

private let taskMutex = Mutex()
private var nextTaskKey: UIntNative = 1
private var taskRegistry = HashMap<UIntNative, WorkItem>()

private class PoolState {
    private let mutex = Mutex()
    private var firstFailure: Option<String> = None

    public func recordFailure(message: String): Unit {
        mutex.lock()
        try {
            if (firstFailure.isNone()) {
                firstFailure = Some(message)
            }
        } finally {
            mutex.unlock()
        }
    }

    public func takeFailure(): Option<String> {
        mutex.lock()
        try {
            let result = firstFailure
            firstFailure = None
            result
        } finally {
            mutex.unlock()
        }
    }
}

private class WorkItem {
    private let work_: () -> Unit
    private let sink_: Option<PoolState>

    public init(work: () -> Unit, sink!: Option<PoolState> = None) {
        this.work_ = work
        this.sink_ = sink
    }

    public func run(): Unit {
        try {
            work_()
        } catch (error: Exception) {
            if (let Some(state) <- sink_) {
                state.recordFailure("${error}")
            } else {
                println("windows_threading worker failure: ${error}")
            }
        }
    }
}

private func allocationFailed(): Nothing {
    throw Exception("allocation failed")
}

private func allocateTaskKey(): UIntNative {
    taskMutex.lock()
    try {
        let key = nextTaskKey
        nextTaskKey += 1
        return key
    } finally {
        taskMutex.unlock()
    }
}

private func registerTask(work: () -> Unit, sink!: Option<PoolState> = None): UIntNative {
    let key = allocateTaskKey()
    taskMutex.lock()
    try {
        taskRegistry.add(key, WorkItem(work, sink: sink))
    } finally {
        taskMutex.unlock()
    }
    key
}

private func takeTask(key: UIntNative): Option<WorkItem> {
    taskMutex.lock()
    try {
        let result = taskRegistry.get(key)
        if (result.isSome()) {
            taskRegistry.remove(key)
        }
        return result
    } finally {
        taskMutex.unlock()
    }
}

private unsafe func createTaskContext(key: UIntNative): CPointer<Unit> {
    let raw = LibC.malloc<UIntNative>()
    if (raw.isNull()) {
        allocationFailed()
    }
    raw.write(key)
    CPointer<Unit>(raw)
}

private unsafe func destroyTaskContext(context: CPointer<Unit>): Unit {
    if (context.isNotNull()) {
        LibC.free<UIntNative>(CPointer<UIntNative>(context))
    }
}

// Expected x64 layout for TP_CALLBACK_ENVIRON_V3:
//   Version u32(4) + 4 padding +
//   Pool, CleanupGroup, CleanupGroupCancelCallback, RaceDll, ActivationContext,
//   FinalizationCallback (6 * 8 = 48) +
//   Flags u32(4) + CallbackPriority i32(4) + Size u32(4) +
//   4 trailing padding (struct alignment = 8) = 72 bytes.
// Windows kernel rejects callback submission if the struct layout disagrees
// with what the threadpool ABI expects, so we verify once before submission.
private const EXPECTED_TP_CALLBACK_ENVIRON_V3_SIZE: UInt64 = 72

private let abiSizeMutex = Mutex()
private var abiSizeChecked: Bool = false

private func assertTpCallbackEnvironV3SizeMatches(): Unit {
    abiSizeMutex.lock()
    try {
        if (abiSizeChecked) {
            return
        }
        let actual = UInt64(sizeOf<TP_CALLBACK_ENVIRON_V3>())
        if (actual != EXPECTED_TP_CALLBACK_ENVIRON_V3_SIZE) {
            throw Exception(
                "TP_CALLBACK_ENVIRON_V3 ABI mismatch: expected ${EXPECTED_TP_CALLBACK_ENVIRON_V3_SIZE} bytes, got ${actual}"
            )
        }
        abiSizeChecked = true
    } finally {
        abiSizeMutex.unlock()
    }
}

private func makeEnvironment(
    pool: PTP_POOL,
    cleanupGroup: PTP_CLEANUP_GROUP
): TP_CALLBACK_ENVIRON_V3 {
    var env = TP_CALLBACK_ENVIRON_V3()
    env.Version = 3u32
    env.Pool = pool
    env.CleanupGroup = cleanupGroup
    env.CallbackPriority = TP_CALLBACK_PRIORITY_NORMAL
    env.Size = UInt32(sizeOf<TP_CALLBACK_ENVIRON_V3>())
    env
}

private func rethrowFailure(state: PoolState): Unit {
    if (let Some(message) <- state.takeFailure()) {
        throw Exception("thread pool callback failed: ${message}")
    }
}

private func submitDefault(work: () -> Unit): Unit {
    let key = registerTask(work)
    let context = unsafe { createTaskContext(key) }
    let success = unsafe {
        TrySubmitThreadpoolCallback(
            taskThunk,
            context,
            CPointer<TP_CALLBACK_ENVIRON_V3>()
        )
    }
    if (success == 0) {
        let _ = takeTask(key)
        unsafe { destroyTaskContext(context) }
        allocationFailed()
    }
}

private func submitToPool(
    pool: PTP_POOL,
    cleanupGroup: PTP_CLEANUP_GROUP,
    work: () -> Unit,
    sink!: Option<PoolState> = None
): Unit {
    let key = registerTask(work, sink: sink)
    let context = unsafe { createTaskContext(key) }
    var env = makeEnvironment(pool, cleanupGroup)
    let success = unsafe {
        TrySubmitThreadpoolCallback(
            taskThunk,
            context,
            inout env
        )
    }
    if (success == 0) {
        let _ = takeTask(key)
        unsafe { destroyTaskContext(context) }
        allocationFailed()
    }
}

@C
private func taskThunk(
    _: PTP_CALLBACK_INSTANCE,
    context: CPointer<Unit>
): Unit {
    if (context.isNull()) {
        return
    }
    let key = unsafe { CPointer<UIntNative>(context).read() }
    unsafe { destroyTaskContext(context) }
    match (takeTask(key)) {
        case Some(work) => work.run()
        case None => ()
    }
}

private func throwIfClosed(closed: Bool): Unit {
    if (closed) {
        throw IllegalStateException("thread pool is closed")
    }
}

public func submit(work: () -> Unit): Unit {
    submitDefault(work)
}

public func forEach<T>(source: Iterable<T>, work: (T) -> Unit): Unit {
    Pool.withScope<Unit> { scope =>
        for (item in source) {
            let current = item
            scope.submit {
                work(current)
            }
        }
    }
}

public func threadId(): UInt32 {
    unsafe { GetCurrentThreadId() }
}

public func sleep(milliseconds: UInt32): Unit {
    unsafe {
        Sleep(milliseconds)
    }
}

public class Pool <: Resource {
    private let lifecycleMutex = Mutex()
    private let state = PoolState()
    private var poolHandle: PTP_POOL = CPointer<Unit>()
    private var cleanupGroup: PTP_CLEANUP_GROUP = CPointer<Unit>()
    private var closed = false

    public init() {
        assertTpCallbackEnvironV3SizeMatches()
        let createdPool = unsafe { CreateThreadpool(CPointer<Unit>()) }
        if (createdPool.isNull()) {
            allocationFailed()
        }

        let createdCleanupGroup = unsafe { CreateThreadpoolCleanupGroup() }
        if (createdCleanupGroup.isNull()) {
            unsafe { CloseThreadpool(createdPool) }
            allocationFailed()
        }

        poolHandle = createdPool
        cleanupGroup = createdCleanupGroup
    }

    public static func new(): Pool {
        Pool()
    }

    public static func withScope<R>(body: (Scope) -> R): R {
        let pool = Pool.new()
        try {
            let result = pool.scope(body)
            pool.close()
            return result
        } catch (error: Exception) {
            pool.closeSilently()
            throw error
        }
    }

    public func isClosed(): Bool {
        lifecycleMutex.lock()
        try {
            closed
        } finally {
            lifecycleMutex.unlock()
        }
    }

    public func setThreadLimits(min: UInt32, max: UInt32): Unit {
        lifecycleMutex.lock()
        try {
            throwIfClosed(closed)
            let success = unsafe { SetThreadpoolThreadMinimum(poolHandle, min) }
            if (success == 0) {
                allocationFailed()
            }
            unsafe { SetThreadpoolThreadMaximum(poolHandle, max) }
        } finally {
            lifecycleMutex.unlock()
        }
    }

    public func submit(work: () -> Unit): Unit {
        lifecycleMutex.lock()
        try {
            throwIfClosed(closed)
            submitToPool(poolHandle, cleanupGroup, work, sink: Some(state))
        } finally {
            lifecycleMutex.unlock()
        }
    }

    public func scope<R>(body: (Scope) -> R): R {
        lifecycleMutex.lock()
        try {
            throwIfClosed(closed)
        } finally {
            lifecycleMutex.unlock()
        }

        let scope = Scope(this)
        try {
            let result = body(scope)
            join()
            return result
        } catch (error: Exception) {
            try {
                join()
            } catch (_: Exception) {
                ()
            }
            throw error
        }
    }

    public func join(): Unit {
        lifecycleMutex.lock()
        try {
            throwIfClosed(closed)
        } finally {
            lifecycleMutex.unlock()
        }
        unsafe {
            CloseThreadpoolCleanupGroupMembers(
                cleanupGroup,
                0,
                CPointer<Unit>()
            )
        }
        rethrowFailure(state)
    }

    private func closeSilently(): Unit {
        closeInternal(false)
    }

    private func closeInternal(reportFailures: Bool): Unit {
        lifecycleMutex.lock()
        let alreadyClosed = closed
        if (!alreadyClosed) {
            closed = true
        }
        lifecycleMutex.unlock()
        if (alreadyClosed) {
            return
        }

        var failure: Option<String> = None
        try {
            unsafe {
                CloseThreadpoolCleanupGroupMembers(
                    cleanupGroup,
                    0,
                    CPointer<Unit>()
                )
            }
            if (let Some(message) <- state.takeFailure()) {
                failure = Some(message)
            }
        } catch (error: Exception) {
            failure = Some("${error}")
        }

        unsafe {
            if (cleanupGroup.isNotNull()) {
                CloseThreadpoolCleanupGroup(cleanupGroup)
            }
            if (poolHandle.isNotNull()) {
                CloseThreadpool(poolHandle)
            }
        }
        cleanupGroup = CPointer<Unit>()
        poolHandle = CPointer<Unit>()

        if (reportFailures) {
            if (let Some(message) <- failure) {
                throw Exception("thread pool callback failed: ${message}")
            }
        }
    }

    public func close(): Unit {
        closeInternal(true)
    }

    ~init() {
        lifecycleMutex.lock()
        let alreadyClosed = closed
        if (!alreadyClosed) {
            closed = true
        }
        lifecycleMutex.unlock()
        if (alreadyClosed) {
            return
        }

        try {
            unsafe {
                CloseThreadpoolCleanupGroupMembers(
                    cleanupGroup,
                    0,
                    CPointer<Unit>()
                )
            }
        } catch (_: Exception) {
            ()
        }

        unsafe {
            if (cleanupGroup.isNotNull()) {
                CloseThreadpoolCleanupGroup(cleanupGroup)
            }
            if (poolHandle.isNotNull()) {
                CloseThreadpool(poolHandle)
            }
        }
        cleanupGroup = CPointer<Unit>()
        poolHandle = CPointer<Unit>()
    }
}

public class Scope {
    private let pool_: Pool

    init(pool: Pool) {
        this.pool_ = pool
    }

    public func submit(work: () -> Unit): Unit {
        pool_.submit(work)
    }

    public func setThreadLimits(min: UInt32, max: UInt32): Unit {
        pool_.setThreadLimits(min, max)
    }

    public func join(): Unit {
        pool_.join()
    }
}
