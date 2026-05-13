package windows_services

import std.collection.HashMap
import std.sync.Mutex
import windows_common.Win32.System.Services as Win32Services
import windows_strings.PWSTR

public type BOOL = Int32
public type SERVICE_STATUS_HANDLE = Win32Services.SERVICE_STATUS_HANDLE
public type LPHANDLER_FUNCTION_EX = Win32Services.LPHANDLER_FUNCTION_EX
public type LPSERVICE_MAIN_FUNCTIONW = Win32Services.LPSERVICE_MAIN_FUNCTIONW
public type SERVICE_STATUS = Win32Services.SERVICE_STATUS
public type SERVICE_TABLE_ENTRYW = Win32Services.SERVICE_TABLE_ENTRYW

private let NO_ERROR = 0u32
private let SERVICE_ACCEPT_STOP = 1u32
private let SERVICE_ACCEPT_PAUSE_CONTINUE = 2u32
private let SERVICE_ACCEPT_SHUTDOWN = 4u32
private let SERVICE_CONTROL_STOP = 1u32
private let SERVICE_CONTROL_PAUSE = 2u32
private let SERVICE_CONTROL_CONTINUE = 3u32
private let SERVICE_CONTROL_SHUTDOWN = 5u32
private let SERVICE_WIN32_OWN_PROCESS = 16u32
private let SERVICE_STOPPED = 1u32
private let SERVICE_START_PENDING = 2u32
private let SERVICE_STOP_PENDING = 3u32
private let SERVICE_RUNNING = 4u32
private let SERVICE_CONTINUE_PENDING = 5u32
private let SERVICE_PAUSE_PENDING = 6u32
private let SERVICE_PAUSED = 7u32

public enum ServiceResult<T> {
    | Ok(T)
    | Err(String)

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        !isOk()
    }

    public func unwrap(): T {
        match (this) {
            case Ok(value) => value
            case Err(message) => throw Exception(message)
        }
    }

    public func expect(message: String): T {
        match (this) {
            case Ok(value) => value
            case Err(error) => throw Exception("${message}: ${error}")
        }
    }
}

public struct ExtendedCommand {
    public let control: UInt32
    public let ty: UInt32
    public let data: CPointer<Unit>

    public init(control: UInt32, ty: UInt32, data: CPointer<Unit>) {
        this.control = control
        this.ty = ty
        this.data = data
    }
}

public enum Command {
    | Start
    | Stop
    | Pause
    | Resume
    | Extended(ExtendedCommand)
}

public enum State {
    | ContinuePending
    | Paused
    | PausePending
    | Running
    | StartPending
    | Stopped
    | StopPending

    public operator func ==(other: State): Bool {
        match ((this, other)) {
            case (State.ContinuePending, State.ContinuePending) => true
            case (State.Paused, State.Paused) => true
            case (State.PausePending, State.PausePending) => true
            case (State.Running, State.Running) => true
            case (State.StartPending, State.StartPending) => true
            case (State.Stopped, State.Stopped) => true
            case (State.StopPending, State.StopPending) => true
            case _ => false
        }
    }

    public operator func !=(other: State): Bool {
        !(this == other)
    }
}

private func stateToRaw(state: State): UInt32 {
    match (state) {
        case State.ContinuePending => SERVICE_CONTINUE_PENDING
        case State.Paused => SERVICE_PAUSED
        case State.PausePending => SERVICE_PAUSE_PENDING
        case State.Running => SERVICE_RUNNING
        case State.StartPending => SERVICE_START_PENDING
        case State.Stopped => SERVICE_STOPPED
        case State.StopPending => SERVICE_STOP_PENDING
    }
}

private func rawToState(raw: UInt32): State {
    if (raw == SERVICE_CONTINUE_PENDING) {
        return State.ContinuePending
    }
    if (raw == SERVICE_PAUSED) {
        return State.Paused
    }
    if (raw == SERVICE_PAUSE_PENDING) {
        return State.PausePending
    }
    if (raw == SERVICE_RUNNING) {
        return State.Running
    }
    if (raw == SERVICE_START_PENDING) {
        return State.StartPending
    }
    if (raw == SERVICE_STOP_PENDING) {
        return State.StopPending
    }
    State.Stopped
}

public class Service {
    private let stateMutex = Mutex()
    private let callbackMutex = Mutex()
    private var accept_: UInt32 = 0u32
    private var fallback_: Option<(Service) -> Unit> = None
    private var handle_: SERVICE_STATUS_HANDLE = SERVICE_STATUS_HANDLE()
    private var callback_: Option<(Service, Command) -> Unit> = None
    private var status_ = SERVICE_STATUS()

    public init() {
        status_.dwServiceType = SERVICE_WIN32_OWN_PROCESS
        status_.dwCurrentState = SERVICE_STOPPED
        status_.dwControlsAccepted = 0u32
        status_.dwWin32ExitCode = 0u32
        status_.dwServiceSpecificExitCode = 0u32
        status_.dwCheckPoint = 0u32
        status_.dwWaitHint = 0u32
    }

    public static func new(): Service {
        Service()
    }

    public func canStop(): Service {
        accept_ |= SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN
        this
    }

    public func canPause(): Service {
        accept_ |= SERVICE_ACCEPT_PAUSE_CONTINUE
        this
    }

    public func canAccept(accept: UInt32): Service {
        accept_ |= accept
        this
    }

    public func canFallback(fallback: (Service) -> Unit): Service {
        fallback_ = Some(fallback)
        this
    }

    public func run(callback: (Service, Command) -> Unit): ServiceResult<Unit> {
        synchronized(stateMutex) {
            if (callback_.isSome()) {
                throw IllegalStateException("run was already called")
            }
            callback_ = Some(callback)
            status_.dwControlsAccepted = accept_
        }

        let serviceId = registerService(this)
        var table = Array<SERVICE_TABLE_ENTRYW>(2, repeat: SERVICE_TABLE_ENTRYW())
        let serviceName = Array<UInt16>(1, repeat: 0u16)
        let started = unsafe {
            let nameHandle = acquireArrayRawData(serviceName)
                let tableHandle = acquireArrayRawData(table)
                try {
                    var entry = SERVICE_TABLE_ENTRYW()
                    entry.lpServiceName = nameHandle.pointer
                    entry.lpServiceProc = serviceMainThunk
                    table[0] = entry
                    table[1] = SERVICE_TABLE_ENTRYW()
                    Win32Services.StartServiceCtrlDispatcherW(tableHandle.pointer)
                } finally {
                    releaseArrayRawData(tableHandle)
                    releaseArrayRawData(nameHandle)
            }
        }

        if (!started) {
            match (takeFallback()) {
                case Some(fallback) =>
                    setState(State.StartPending)
                    command(Command.Start)
                    setState(State.Running)
                    fallback(this)
                    setState(State.StopPending)
                    command(Command.Stop)
                    setState(State.Stopped)
                    unregisterService(serviceId)
                    return ServiceResult<Unit>.Ok(())
                case None =>
                    unregisterService(serviceId)
                    return ServiceResult<Unit>.Err("Use service control manager to start service")
            }
        }

        unregisterService(serviceId)
        ServiceResult<Unit>.Ok(())
    }

    public func setState(state: State): Unit {
        var handle = SERVICE_STATUS_HANDLE()
        var statusCopy = SERVICE_STATUS()
        synchronized(stateMutex) {
            status_.dwCurrentState = stateToRaw(state)
            handle = handle_
            statusCopy = status_
        }

        if (handle.Value.isNotNull()) {
            let _ = Win32Services.SetServiceStatus(handle, CPointer<SERVICE_STATUS>(inout statusCopy))
        }
    }

    public func handle(): SERVICE_STATUS_HANDLE {
        synchronized(stateMutex) {
            handle_
        }
    }

    public func state(): State {
        let raw = synchronized(stateMutex) {
            status_.dwCurrentState
        }
        return rawToState(raw)
    }

    public func command(command: Command): Unit {
        synchronized(callbackMutex) {
            match (callback_) {
                case Some(callback) => callback(this, command)
                case None => ()
            }
        }
    }

    public func handler(control: UInt32, eventType: UInt32, eventData: CPointer<Unit>): UInt32 {
        dispatchServiceControl(this, control, eventType, eventData)
    }

    func storeHandle(handle: SERVICE_STATUS_HANDLE): Unit {
        synchronized(stateMutex) {
            handle_ = handle
        }
    }

    private func takeFallback(): Option<(Service) -> Unit> {
        let fallback = fallback_
        fallback_ = None
        fallback
    }
}

private let registryMutex = Mutex()
private var nextServiceId: UIntNative = 1
private var activeServiceId: UIntNative = 0
private var serviceRegistry = HashMap<UIntNative, Service>()

private func contextPointer(id: UIntNative): CPointer<Unit> {
    unsafe { CPointer<Unit>(CPointer<UInt8>() + Int64(id)) }
}

private func registerService(service: Service): UIntNative {
    synchronized(registryMutex) {
        let id = nextServiceId
        nextServiceId += 1
        activeServiceId = id
        serviceRegistry.add(id, service)
        return id
    }
}

private func unregisterService(id: UIntNative): Unit {
    synchronized(registryMutex) {
        if (activeServiceId == id) {
            activeServiceId = 0
        }
        serviceRegistry.remove(id)
    }
}

private func currentActiveServiceId(): UIntNative {
    synchronized(registryMutex) {
        activeServiceId
    }
}

private func currentActiveService(): Option<Service> {
    synchronized(registryMutex) {
        if (activeServiceId == 0) {
            return None
        }
        serviceRegistry.get(activeServiceId)
    }
}

private func serviceFromContext(context: CPointer<Unit>): Option<Service> {
    let id = context.toUIntNative()
    if (id == 0) {
        return None
    }
    synchronized(registryMutex) {
        serviceRegistry.get(id)
    }
}

private func dispatchServiceControl(
    service: Service,
    control: UInt32,
    eventType: UInt32,
    eventData: CPointer<Unit>
): UInt32 {
    if (control == SERVICE_CONTROL_CONTINUE && service.state() == State.Paused) {
        service.setState(State.ContinuePending)
        service.command(Command.Resume)
        service.setState(State.Running)
        return NO_ERROR
    }

    if (control == SERVICE_CONTROL_PAUSE && service.state() == State.Running) {
        service.setState(State.PausePending)
        service.command(Command.Pause)
        service.setState(State.Paused)
        return NO_ERROR
    }

    if (control == SERVICE_CONTROL_SHUTDOWN || control == SERVICE_CONTROL_STOP) {
        service.setState(State.StopPending)
        service.command(Command.Stop)
        service.setState(State.Stopped)
        return NO_ERROR
    }

    service.command(Command.Extended(ExtendedCommand(control, eventType, eventData)))
    NO_ERROR
}

@C
private func serviceMainThunk(_: UInt32, _: CPointer<CPointer<UInt16>>): Unit {
    match (currentActiveService()) {
        case Some(service) =>
            let handle = unsafe {
                Win32Services.RegisterServiceCtrlHandlerExW(
                    PWSTR(),
                    handlerThunk,
                    contextPointer(currentActiveServiceId())
                )
            }
            service.storeHandle(handle)
            service.setState(State.StartPending)
            service.command(Command.Start)
            service.setState(State.Running)
        case None =>
            ()
    }
}

@C
private func handlerThunk(
    control: UInt32,
    eventType: UInt32,
    eventData: CPointer<Unit>,
    context: CPointer<Unit>
): UInt32 {
    match (serviceFromContext(context)) {
        case Some(service) => dispatchServiceControl(service, control, eventType, eventData)
        case None => NO_ERROR
    }
}
