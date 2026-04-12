package windows_core

@C
public struct IWeakReferenceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Resolve: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }

    public init() {}
}

@C
public struct IWeakReferenceSourceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var GetWeakReference: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }

    public init() {}
}

let IID_IWEAKREFERENCE = GUID.fromValues(0x00000037u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)
let IID_IWEAKREFERENCESOURCE = GUID.fromValues(0x00000038u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)

func wrapIWeakReferenceOwned(raw: CPointer<Unit>): IWeakReference {
    IWeakReference(raw, ownsReference: true)
}

func wrapIWeakReferenceBorrowed(raw: CPointer<Unit>): IWeakReference {
    IWeakReference(raw)
}

func wrapIWeakReferenceSourceOwned(raw: CPointer<Unit>): IWeakReferenceSource {
    IWeakReferenceSource(raw, ownsReference: true)
}

func wrapIWeakReferenceSourceBorrowed(raw: CPointer<Unit>): IWeakReferenceSource {
    IWeakReferenceSource(raw)
}

public class IWeakReference <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        IID_IWEAKREFERENCE
    }

    public static func descriptor(): InterfaceDescriptor<IWeakReference> {
        InterfaceDescriptor<IWeakReference>("IWeakReference", IID_IWEAKREFERENCE, wrapIWeakReferenceOwned, wrapIWeakReferenceBorrowed)
    }

    public unsafe func vtbl(): IWeakReferenceVtbl {
        readVtbl<IWeakReferenceVtbl>(IWeakReferenceVtbl())
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
        Result<T>.Ok(descriptor.wrapOwned(raw))
    }
}

public interface IWeakReference_Impl {
    func Resolve(riid: CPointer<GUID>, objectreference: CPointer<CPointer<Unit>>): Result<Unit>
}

@C
func weakReferenceResolveThunk(
    this_: CPointer<Unit>,
    riid: CPointer<GUID>,
    objectreference: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (objectreference.isNull()) {
            return E_POINTER.value
        }
        objectreference.write(CPointer<Unit>())
        if (riid.isNull()) {
            return E_POINTER.value
        }
    }

    match (lookupComInnerImpl<IWeakReference_Impl>(this_)) {
        case Some(value) =>
            match (value.Resolve(riid, objectreference)) {
                case Result<Unit>.Ok(_) => S_OK.value
                case Result<Unit>.Err(error) => error.code().value
            }
        case None =>
            E_NOINTERFACE.value
    }
}

public func newIWeakReferenceVtbl<T>(offset!: Int64 = 0): IWeakReferenceVtbl where T <: IWeakReference_Impl {
    var vtbl = IWeakReferenceVtbl()
    vtbl.base_ = buildIUnknownVtbl(offset: offset)
    vtbl.Resolve = weakReferenceResolveThunk
    vtbl
}

public func matchesIWeakReferenceVtbl(iid: GUID): Bool {
    iid == IWeakReference.iid()
}

public class IWeakReferenceSource <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        IID_IWEAKREFERENCESOURCE
    }

    public static func descriptor(): InterfaceDescriptor<IWeakReferenceSource> {
        InterfaceDescriptor<IWeakReferenceSource>("IWeakReferenceSource", IID_IWEAKREFERENCESOURCE, wrapIWeakReferenceSourceOwned, wrapIWeakReferenceSourceBorrowed)
    }

    public unsafe func vtbl(): IWeakReferenceSourceVtbl {
        readVtbl<IWeakReferenceSourceVtbl>(IWeakReferenceSourceVtbl())
    }

    public unsafe func getWeakReference(): Result<IWeakReference> {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return Result<IWeakReference>.Err(WinError(E_POINTER))
        }

        var raw = CPointer<Unit>()
        let hr = HRESULT(vtbl().GetWeakReference(liveRaw, CPointer<CPointer<Unit>>(inout raw)))
        if (hr.failed()) {
            return Result<IWeakReference>.Err(WinError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<IWeakReference>.Err(WinError(E_POINTER))
        }
        Result<IWeakReference>.Ok(IWeakReference(raw, ownsReference: true))
    }
}

public interface IWeakReferenceSource_Impl {
    func GetWeakReference(): Result<IWeakReference>
}

@C
func weakReferenceSourceGetWeakReferenceThunk(
    this_: CPointer<Unit>,
    weakreference: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (weakreference.isNull()) {
            return E_POINTER.value
        }
        weakreference.write(CPointer<Unit>())
    }

    match (lookupComInnerImpl<IWeakReferenceSource_Impl>(this_)) {
        case Some(value) =>
            match (value.GetWeakReference()) {
                case Result<IWeakReference>.Ok(reference) =>
                    let raw = reference.asRaw()
                    if (raw.isNull()) {
                        reference.close()
                        return E_POINTER.value
                    }
                    reference.addRef()
                    unsafe { weakreference.write(raw) }
                    reference.close()
                    S_OK.value
                case Result<IWeakReference>.Err(error) =>
                    error.code().value
            }
        case None =>
            E_NOINTERFACE.value
    }
}

public func newIWeakReferenceSourceVtbl<T>(offset!: Int64 = 0): IWeakReferenceSourceVtbl where T <: IWeakReferenceSource_Impl {
    var vtbl = IWeakReferenceSourceVtbl()
    vtbl.base_ = buildIUnknownVtbl(offset: offset)
    vtbl.GetWeakReference = weakReferenceSourceGetWeakReferenceThunk
    vtbl
}

public func matchesIWeakReferenceSourceVtbl(iid: GUID): Bool {
    iid == IWeakReferenceSource.iid()
}

public class Weak<T> <: Resource where T <: ComInterface {
    private let descriptor: InterfaceDescriptor<T>
    private let systemReference: Option<IWeakReference>
    private let tearOff: Option<TearOff<T>>
    private var closed: Bool = false

    private init(
        descriptor: InterfaceDescriptor<T>,
        systemReference: Option<IWeakReference>,
        tearOff: Option<TearOff<T>>
    ) {
        this.descriptor = descriptor
        this.systemReference = systemReference
        this.tearOff = tearOff
    }

    public static func new(descriptor: InterfaceDescriptor<T>): Weak<T> {
        Weak<T>(descriptor, None, None)
    }

    public static func downgrade(source: T, descriptor: InterfaceDescriptor<T>): Weak<T> {
        let liveRaw = source.asRaw()
        if (liveRaw.isNull()) {
            return Weak<T>.new(descriptor)
        }

        match (unsafe { queryInterfaceAs(liveRaw, IWeakReferenceSource.descriptor()) }) {
            case Some(sourceInterface) =>
                match (unsafe { sourceInterface.getWeakReference() }) {
                    case Result<IWeakReference>.Ok(reference) =>
                        sourceInterface.close()
                        return Weak<T>(descriptor, Some(reference), None)
                    case Result<IWeakReference>.Err(_) =>
                        sourceInterface.close()
                }
            case None => ()
        }

        match (comRegistryLookup(unsafe { rootRegistryKeyFromRaw(liveRaw) })) {
            case Some(_) =>
                let count = WeakRefCount(liveRaw)
                return Weak<T>(descriptor, None, Some(count.createTearOff(descriptor)))
            case None =>
                Weak<T>.new(descriptor)
        }
    }

    public func upgrade(): Option<T> {
        if (closed) {
            return Option<T>.None
        }

        match (systemReference) {
            case Some(reference) =>
                match (unsafe { reference.resolve(descriptor) }) {
                    case Result<T>.Ok(value) => return Some(value)
                    case Result<T>.Err(_) => return Option<T>.None
                }
            case None => ()
        }

        match (tearOff) {
            case Some(localReference) => localReference.upgrade()
            case None => Option<T>.None
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        match (systemReference) {
            case Some(reference) => reference.close()
            case None => ()
        }
        match (tearOff) {
            case Some(localReference) => localReference.close()
            case None => ()
        }
        closed = true
    }
}
