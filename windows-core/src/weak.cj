package windows_core

public interface IWeakReference_Impl {
    func Resolve(riid: CPointer<GUID>, objectreference: CPointer<CPointer<Unit>>): Result<Unit>
}

@C
func weakReferenceResolveThunk(
    instanceRaw: CPointer<Unit>,
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

    match (lookupComInnerImpl<IWeakReference_Impl>(instanceRaw)) {
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

public interface IWeakReferenceSource_Impl {
    func GetWeakReference(): Result<IWeakReference>
}

@C
func weakReferenceSourceGetWeakReferenceThunk(
    instanceRaw: CPointer<Unit>,
    weakreference: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (weakreference.isNull()) {
            return E_POINTER.value
        }
        weakreference.write(CPointer<Unit>())
    }

    match (lookupComInnerImpl<IWeakReferenceSource_Impl>(instanceRaw)) {
        case Some(value) =>
            match (value.GetWeakReference()) {
                case Result<IWeakReference>.Ok(reference) =>
                    let raw = reference.intoAbi()
                    if (raw.isNull()) {
                        reference.close()
                        return E_POINTER.value
                    }
                    unsafe { weakreference.write(raw) }
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
