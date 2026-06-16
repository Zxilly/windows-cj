package windows_threading

import std.collection.HashMap
import std.sync.{AtomicBool, Mutex}
import windows_sys.Win32.System.Threading as Win32Threading

public type BOOL = Int32
public type PTP_CALLBACK_INSTANCE = Win32Threading.PTP_CALLBACK_INSTANCE
public type PTP_CLEANUP_GROUP = Win32Threading.PTP_CLEANUP_GROUP
public type PTP_CLEANUP_GROUP_CANCEL_CALLBACK = Win32Threading.PTP_CLEANUP_GROUP_CANCEL_CALLBACK
public type PTP_POOL = Win32Threading.PTP_POOL
public type PTP_SIMPLE_CALLBACK = Win32Threading.PTP_SIMPLE_CALLBACK
public type TP_CALLBACK_ENVIRON_V3 = Win32Threading.TP_CALLBACK_ENVIRON_V3

private let TP_CALLBACK_PRIORITY_NORMAL = 1i32

private let taskMutex = Mutex()
private var nextTaskKey: UIntNative = 1
private var taskRegistry = HashMap<UIntNative, WorkItem>()

private class PoolState {
    private let mutex = Mutex()
    private var firstFailure: Option<String> = None

    public func recordFailure(message: String): Unit {
        synchronized(mutex) {
            if (firstFailure.isNone()) {
                firstFailure = Some(message)
            }
        }
    }

    public func takeFailure(): Option<String> {
        synchronized(mutex) {
            let result = firstFailure
            firstFailure = None
            result
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
    synchronized(taskMutex) {
        let key = nextTaskKey
        nextTaskKey += 1
        return key
    }
}

private func registerTask(work: () -> Unit, sink!: Option<PoolState> = None): UIntNative {
    let key = allocateTaskKey()
    synchronized(taskMutex) {
        taskRegistry.add(key, WorkItem(work, sink: sink))
    }
    key
}

private func takeTask(key: UIntNative): Option<WorkItem> {
    synchronized(taskMutex) {
        let result = taskRegistry.get(key)
        if (result.isSome()) {
            taskRegistry.remove(key)
        }
        return result
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

// Expected x86_64 Windows layout for TP_CALLBACK_ENVIRON_V3:
//   Version u32(4) + 4 padding +
//   Pool, CleanupGroup, CleanupGroupCancelCallback, RaceDll, ActivationContext,
//   FinalizationCallback (6 * 8 = 48) +
//   Flags u32(4) + CallbackPriority i32(4) + Size u32(4) +
//   4 trailing padding (struct alignment = 8) = 72 bytes.
// Windows rejects callback submission if the struct layout disagrees with
// what the threadpool ABI expects, so unsupported targets fail before use.
@When[os == "Windows" && arch == "x86_64"]
private let tpCallbackEnvironV3ExpectedSize: Option<UInt64> = Some(72u64)

@When[os != "Windows" || arch != "x86_64"]
private let tpCallbackEnvironV3ExpectedSize: Option<UInt64> = None

private let abiSizeMutex = Mutex()
private var abiSizeChecked: Bool = false

private func expectedTpCallbackEnvironV3Size(): UInt64 {
    match (tpCallbackEnvironV3ExpectedSize) {
        case Some(size) => size
        case None => throw Exception(
            "windows_threading TP_CALLBACK_ENVIRON_V3 is only validated for x86_64 Windows"
        )
    }
}

private func assertTpCallbackEnvironV3SizeMatches(): Unit {
    synchronized(abiSizeMutex) {
        if (abiSizeChecked) {
            return
        }
        let expected = expectedTpCallbackEnvironV3Size()
        let actual = UInt64(sizeOf<TP_CALLBACK_ENVIRON_V3>())
        if (actual != expected) {
            throw Exception(
                "TP_CALLBACK_ENVIRON_V3 ABI mismatch: expected ${expected} bytes, got ${actual}"
            )
        }
        abiSizeChecked = true
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
        Win32Threading.TrySubmitThreadpoolCallback(
            taskThunk,
            context,
            CPointer<TP_CALLBACK_ENVIRON_V3>()
        )
    }
    if (!success) {
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
    let success = Win32Threading.TrySubmitThreadpoolCallback(
        taskThunk,
        context,
        CPointer<TP_CALLBACK_ENVIRON_V3>(inout env)
    )
    if (!success) {
        let _ = takeTask(key)
        unsafe { destroyTaskContext(context) }
        allocationFailed()
    }
}

@C
private func taskThunk(
    _: CPointer<Unit>,
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
    unsafe { Win32Threading.GetCurrentThreadId() }
}

public func sleep(milliseconds: UInt32): Unit {
    unsafe {
        Win32Threading.Sleep(milliseconds)
    }
}

public class Pool <: Resource {
    private let lifecycleMutex = Mutex()
    private let state = PoolState()
    private var poolHandle: PTP_POOL = PTP_POOL()
    private var cleanupGroup: PTP_CLEANUP_GROUP = PTP_CLEANUP_GROUP()
    private let closed = AtomicBool(false)

    public init() {
        assertTpCallbackEnvironV3SizeMatches()
        let createdPool = unsafe { Win32Threading.CreateThreadpool() }
        if (createdPool.Value.isNull()) {
            allocationFailed()
        }

        let createdCleanupGroup = unsafe { Win32Threading.CreateThreadpoolCleanupGroup() }
        if (createdCleanupGroup.Value.isNull()) {
            unsafe { Win32Threading.CloseThreadpool(createdPool) }
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
        closed.load()
    }

    public func setThreadLimits(min: UInt32, max: UInt32): Unit {
        synchronized(lifecycleMutex) {
            throwIfClosed(closed.load())
            let success = unsafe { Win32Threading.SetThreadpoolThreadMinimum(poolHandle, min) }
            if (!success) {
                allocationFailed()
            }
            unsafe { Win32Threading.SetThreadpoolThreadMaximum(poolHandle, max) }
        }
    }

    public func submit(work: () -> Unit): Unit {
        synchronized(lifecycleMutex) {
            throwIfClosed(closed.load())
            submitToPool(poolHandle, cleanupGroup, work, sink: Some(state))
        }
    }

    public func scope<R>(body: (Scope) -> R): R {
        synchronized(lifecycleMutex) {
            throwIfClosed(closed.load())
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
        synchronized(lifecycleMutex) {
            throwIfClosed(closed.load())
        }
        unsafe {
            Win32Threading.CloseThreadpoolCleanupGroupMembers(
                cleanupGroup,
                false,
                CPointer<Unit>()
            )
        }
        rethrowFailure(state)
    }

    private func closeSilently(): Unit {
        closeInternal(false)
    }

    private func closeInternal(reportFailures: Bool): Unit {
        var shouldClose = false
        synchronized(lifecycleMutex) {
            shouldClose = closed.compareAndSwap(false, true)
        }
        if (!shouldClose) {
            return
        }

        var failure: Option<String> = None
        try {
            unsafe {
                Win32Threading.CloseThreadpoolCleanupGroupMembers(
                    cleanupGroup,
                    false,
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
            if (cleanupGroup.Value.isNotNull()) {
                Win32Threading.CloseThreadpoolCleanupGroup(cleanupGroup)
            }
            if (poolHandle.Value.isNotNull()) {
                Win32Threading.CloseThreadpool(poolHandle)
            }
        }
        cleanupGroup = PTP_CLEANUP_GROUP()
        poolHandle = PTP_POOL()

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
        // Threadpool shutdown can block. Pools must be closed explicitly.
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
