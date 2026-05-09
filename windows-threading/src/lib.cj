package windows_threading

import std.collection.HashMap
import std.sync.Mutex
import windows_common.Win32.System.Threading as Win32Threading
import windows_libloading as windows_libloading

public type BOOL = Int32
public type PTP_CALLBACK_INSTANCE = Win32Threading.PTP_CALLBACK_INSTANCE
public type PTP_CLEANUP_GROUP = Win32Threading.PTP_CLEANUP_GROUP
public type PTP_CLEANUP_GROUP_CANCEL_CALLBACK = Win32Threading.PTP_CLEANUP_GROUP_CANCEL_CALLBACK
public type PTP_POOL = Win32Threading.PTP_POOL
public type PTP_SIMPLE_CALLBACK = Win32Threading.PTP_SIMPLE_CALLBACK
public type TP_CALLBACK_ENVIRON_V3 = Win32Threading.TP_CALLBACK_ENVIRON_V3

private let TP_CALLBACK_PRIORITY_NORMAL = 1i32

func CloseThreadpool(ptpp: PTP_POOL): Unit {
    let proc = CFunc<(PTP_POOL) -> Unit>(windows_libloading.resolveProc("kernel32.dll", "CloseThreadpool"))
    unsafe { proc(ptpp) }
}

func CloseThreadpoolCleanupGroup(ptpcg: PTP_CLEANUP_GROUP): Unit {
    let proc = CFunc<(PTP_CLEANUP_GROUP) -> Unit>(
        windows_libloading.resolveProc("kernel32.dll", "CloseThreadpoolCleanupGroup")
    )
    unsafe { proc(ptpcg) }
}

func CloseThreadpoolCleanupGroupMembers(
    ptpcg: PTP_CLEANUP_GROUP,
    fCancelPendingCallbacks: BOOL,
    pvCleanupContext: CPointer<Unit>
): Unit {
    let proc = CFunc<(PTP_CLEANUP_GROUP, BOOL, CPointer<Unit>) -> Unit>(
        windows_libloading.resolveProc("kernel32.dll", "CloseThreadpoolCleanupGroupMembers")
    )
    unsafe { proc(ptpcg, fCancelPendingCallbacks, pvCleanupContext) }
}

func CreateThreadpool(reserved: CPointer<Unit>): PTP_POOL {
    let proc = CFunc<(CPointer<Unit>) -> PTP_POOL>(
        windows_libloading.resolveProc("kernel32.dll", "CreateThreadpool")
    )
    unsafe { proc(reserved) }
}

func CreateThreadpoolCleanupGroup(): PTP_CLEANUP_GROUP {
    let proc = CFunc<() -> PTP_CLEANUP_GROUP>(
        windows_libloading.resolveProc("kernel32.dll", "CreateThreadpoolCleanupGroup")
    )
    unsafe { proc() }
}

func GetCurrentThreadId(): UInt32 {
    let proc = CFunc<() -> UInt32>(windows_libloading.resolveProc("kernel32.dll", "GetCurrentThreadId"))
    unsafe { proc() }
}

func SetThreadpoolThreadMaximum(ptpp: PTP_POOL, cthrdMost: UInt32): Unit {
    let proc = CFunc<(PTP_POOL, UInt32) -> Unit>(
        windows_libloading.resolveProc("kernel32.dll", "SetThreadpoolThreadMaximum")
    )
    unsafe { proc(ptpp, cthrdMost) }
}

func SetThreadpoolThreadMinimum(ptpp: PTP_POOL, cthrdMic: UInt32): BOOL {
    let proc = CFunc<(PTP_POOL, UInt32) -> BOOL>(
        windows_libloading.resolveProc("kernel32.dll", "SetThreadpoolThreadMinimum")
    )
    unsafe { proc(ptpp, cthrdMic) }
}

func Sleep(dwMilliseconds: UInt32): Unit {
    let proc = CFunc<(UInt32) -> Unit>(windows_libloading.resolveProc("kernel32.dll", "Sleep"))
    unsafe { proc(dwMilliseconds) }
}

func TrySubmitThreadpoolCallbackProc(): CFunc<(
    PTP_SIMPLE_CALLBACK,
    CPointer<Unit>,
    CPointer<TP_CALLBACK_ENVIRON_V3>
) -> BOOL> {
    CFunc<(PTP_SIMPLE_CALLBACK, CPointer<Unit>, CPointer<TP_CALLBACK_ENVIRON_V3>) -> BOOL>(
        windows_libloading.resolveProc("kernel32.dll", "TrySubmitThreadpoolCallback")
    )
}

func TrySubmitThreadpoolCallback(
    pfns: PTP_SIMPLE_CALLBACK,
    pv: CPointer<Unit>,
    pcbe: CPointer<TP_CALLBACK_ENVIRON_V3>
): BOOL {
    let proc = TrySubmitThreadpoolCallbackProc()
    unsafe { proc(pfns, pv, pcbe) }
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
    let proc = TrySubmitThreadpoolCallbackProc()
    let success = unsafe {
        proc(
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
    private var poolHandle: PTP_POOL = PTP_POOL()
    private var cleanupGroup: PTP_CLEANUP_GROUP = PTP_CLEANUP_GROUP()
    private var closed = false

    public init() {
        assertTpCallbackEnvironV3SizeMatches()
        let createdPool = unsafe { CreateThreadpool(CPointer<Unit>()) }
        if (createdPool.Value.isNull()) {
            allocationFailed()
        }

        let createdCleanupGroup = unsafe { CreateThreadpoolCleanupGroup() }
        if (createdCleanupGroup.Value.isNull()) {
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
            if (cleanupGroup.Value.isNotNull()) {
                CloseThreadpoolCleanupGroup(cleanupGroup)
            }
            if (poolHandle.Value.isNotNull()) {
                CloseThreadpool(poolHandle)
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
            if (cleanupGroup.Value.isNotNull()) {
                CloseThreadpoolCleanupGroup(cleanupGroup)
            }
            if (poolHandle.Value.isNotNull()) {
                CloseThreadpool(poolHandle)
            }
        }
        cleanupGroup = PTP_CLEANUP_GROUP()
        poolHandle = PTP_POOL()
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
