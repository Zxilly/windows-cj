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

@C
public struct IAgileObjectVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()

    public init() {}
}

@C
public struct IAgileReferenceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Resolve: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }

    public init() {}
}

foreign {
    func RoGetAgileReference(
        options: Int32,
        riid: CPointer<GUID>,
        pUnk: CPointer<Unit>,
        ppAgileReference: CPointer<CPointer<Unit>>
    ): Int32
}

let IID_IAGILEOBJECT = GUID.fromValues(0x94EA2B94u32, 0xE9CCu16, 0x49E0u16, 0xC0u8, 0xFFu8, 0xEEu8, 0x64u8, 0xCAu8, 0x8Fu8, 0x5Bu8, 0x90u8)
let IID_IAGILEREFERENCE = GUID.fromValues(0xC03F6A43u32, 0x65A4u16, 0x9818u16, 0x98u8, 0x7Eu8, 0xE0u8, 0xB8u8, 0x10u8, 0xD2u8, 0xA6u8, 0xF2u8)

func takeIAgileObjectFromAbi(raw: CPointer<Unit>): IAgileObject {
    IAgileObject.fromAbiTake(raw)
}

func viewIAgileObject(raw: CPointer<Unit>): IAgileObject {
    IAgileObject.viewOf(raw)
}

func takeIAgileReferenceFromAbi(raw: CPointer<Unit>): IAgileReference {
    IAgileReference.fromAbiTake(raw)
}

func viewIAgileReference(raw: CPointer<Unit>): IAgileReference {
    IAgileReference.viewOf(raw)
}

public class IAgileObject <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAgileObject {
        IAgileObject(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAgileObject {
        IAgileObject(raw)
    }

    public static func iid(): GUID {
        IID_IAGILEOBJECT
    }

    public static func descriptor(): InterfaceDescriptor<IAgileObject> {
        InterfaceDescriptor<IAgileObject>("IAgileObject", IID_IAGILEOBJECT, takeIAgileObjectFromAbi, viewIAgileObject)
    }

    public unsafe func vtbl(): IAgileObjectVtbl {
        readVtbl<IAgileObjectVtbl>(IAgileObjectVtbl())
    }
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

public class IAgileReference <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAgileReference {
        IAgileReference(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAgileReference {
        IAgileReference(raw)
    }

    public static func iid(): GUID {
        IID_IAGILEREFERENCE
    }

    public static func descriptor(): InterfaceDescriptor<IAgileReference> {
        InterfaceDescriptor<IAgileReference>("IAgileReference", IID_IAGILEREFERENCE, takeIAgileReferenceFromAbi, viewIAgileReference)
    }

    public unsafe func vtbl(): IAgileReferenceVtbl {
        readVtbl<IAgileReferenceVtbl>(IAgileReferenceVtbl())
    }

    public unsafe func resolve<T>(descriptor: InterfaceDescriptor<T>): Result<T> where T <: ComInterface {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return Result<T>.Err(WinError(E_POINTER))
        }

        var iid = descriptor.iid
        var raw = CPointer<Unit>()
        let hr = HRESULT(vtbl().Resolve(liveRaw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout raw)))
        if (hr.failed()) {
            return Result<T>.Err(WinError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<T>.Err(WinError(E_POINTER))
        }
        Result<T>.Ok(descriptor.takeFromAbi(raw))
    }
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
