package windows_core

public struct AgileReferenceOptions {
    public let value: Int32

    public init() {
        value = 0i32
    }

    public init(value: Int32) {
        this.value = value
    }

    public static let DEFAULT = AgileReferenceOptions(0i32)
    public static let DELAYED_MARSHAL = AgileReferenceOptions(1i32)

    public operator func ==(other: AgileReferenceOptions): Bool {
        value == other.value
    }

    public operator func !=(other: AgileReferenceOptions): Bool {
        value != other.value
    }
}

foreign {
    func RoGetAgileReference(
        options: Int32,
        riid: CPointer<GUID>,
        pUnk: CPointer<Unit>,
        ppAgileReference: CPointer<CPointer<Unit>>
    ): Int32
}

public interface IAgileObject_Impl {}

public func newIAgileObjectVtbl<T>(offset!: Int64 = 0): IAgileObjectVtbl where T <: IAgileObject_Impl {
    var vtbl = IAgileObjectVtbl()
    vtbl.base_ = buildIUnknownVtbl(offset: offset)
    vtbl
}

public func matchesIAgileObjectVtbl(iid: GUID): Bool {
    iid == IAgileObject.iid()
}

public interface IAgileReference_Impl {
    func Resolve(riid: CPointer<GUID>, ppvobjectreference: CPointer<CPointer<Unit>>): Result<Unit>
}

@C
func agileReferenceResolveThunk(
    instanceRaw: CPointer<Unit>,
    riid: CPointer<GUID>,
    ppvobjectreference: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (ppvobjectreference.isNull()) {
            return E_POINTER.value
        }
        ppvobjectreference.write(CPointer<Unit>())
        if (riid.isNull()) {
            return E_POINTER.value
        }
    }

    match (lookupComInnerImpl<IAgileReference_Impl>(instanceRaw)) {
        case Some(value) =>
            match (value.Resolve(riid, ppvobjectreference)) {
                case Result<Unit>.Ok(_) => S_OK.value
                case Result<Unit>.Err(error) => error.code().value
            }
        case None =>
            E_NOINTERFACE.value
    }
}

public func newIAgileReferenceVtbl<T>(offset!: Int64 = 0): IAgileReferenceVtbl where T <: IAgileReference_Impl {
    var vtbl = IAgileReferenceVtbl()
    vtbl.base_ = buildIUnknownVtbl(offset: offset)
    vtbl.Resolve = agileReferenceResolveThunk
    vtbl
}

public func matchesIAgileReferenceVtbl(iid: GUID): Bool {
    iid == IAgileReference.iid()
}

public class AgileReference<T> <: Resource where T <: ComInterface {
    private let descriptor: InterfaceDescriptor<T>
    private let inner: Option<IAgileReference>
    private let local: Option<InterfaceHandle<T>>
    private var closed: Bool = false

    init(inner: Option<IAgileReference>, local: Option<InterfaceHandle<T>>, descriptor: InterfaceDescriptor<T>) {
        this.inner = inner
        this.local = local
        this.descriptor = descriptor
    }

    public static func new(object: T, descriptor: InterfaceDescriptor<T>): Result<AgileReference<T>> {
        let liveRaw = object.asRaw()
        if (liveRaw.isNull()) {
            return Result<AgileReference<T>>.Err(WinError(E_POINTER))
        }

        var iid = descriptor.iid
        var raw = CPointer<Unit>()
        let hr = unsafe {
            HRESULT(
                RoGetAgileReference(
                    AgileReferenceOptions.DEFAULT.value,
                    CPointer<GUID>(inout iid),
                    liveRaw,
                    CPointer<CPointer<Unit>>(inout raw)
                )
            )
        }
        if (hr.failed()) {
            return Result<AgileReference<T>>.Err(WinError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<AgileReference<T>>.Err(WinError(E_POINTER))
        }
        Result<AgileReference<T>>.Ok(
            AgileReference<T>(Some(IAgileReference.fromAbiTake(raw)), None, descriptor)
        )
    }

    public func isClosed(): Bool {
        if (closed) {
            return true
        }
        match (inner) {
            case Some(reference) =>
                if (reference.isClosed()) {
                    return true
                }
            case None => ()
        }
        match (local) {
            case Some(pointer) => pointer.isClosed()
            case None => false
        }
    }

    public func resolve(): Result<T> {
        if (isClosed()) {
            return Result<T>.Err(WinError(E_POINTER))
        }
        match (inner) {
            case Some(reference) =>
                return unsafe { reference.resolve(descriptor) }
            case None => ()
        }
        match (local) {
            case Some(pointer) =>
                let cloned = pointer.retain()
                let raw = cloned.intoAbi()
                return Result<T>.Ok(descriptor.takeFromAbi(raw))
            case None =>
                Result<T>.Err(WinError(E_POINTER))
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        match (inner) {
            case Some(reference) => reference.close()
            case None => ()
        }
        match (local) {
            case Some(pointer) => pointer.close()
            case None => ()
        }
        closed = true
    }
}
