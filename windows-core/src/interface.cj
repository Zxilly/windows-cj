package windows_core

public interface Interface<T> <: InterfaceType & Type<T, CPointer<Unit>, Option<T>> where T <: ComInterface {
    static func descriptor(): InterfaceDescriptor<T>
    static func fromAbiTake(raw: CPointer<Unit>): T
    static func viewOf(raw: CPointer<Unit>): T

    static func IID(): GUID {
        descriptor().iid
    }

    static func UNKNOWN(): Bool {
        true
    }

    static func abiType(): String {
        "pointer"
    }

    static func isNullAbi(abi: CPointer<Unit>): Bool {
        abi.isNull()
    }

    static func assumeInitRef(abi: CPointer<Unit>): T {
        viewOf(abi)
    }

    static func fromAbi(abi: CPointer<Unit>): Result<T> {
        if (abi.isNull()) {
            return Result<T>.Err(WinError(E_POINTER))
        }
        Result<T>.Ok(fromAbiTake(abi))
    }

    static func fromDefault(defaultValue: Option<T>): Result<T> {
        match (defaultValue) {
            case Some(value) =>
                match (value as InterfaceWrapperBase) {
                    case Some(wrapper) =>
                        let raw = wrapper.asRaw()
                    if (raw.isNull()) {
                        return Result<T>.Err(WinError(E_POINTER))
                    }
                    let retained = wrapper.retainRaw()
                    Result<T>.Ok(fromAbiTake(retained))
                case None =>
                    Result<T>.Ok(value)
                }
            case None =>
                Result<T>.Err(WinError(E_POINTER))
        }
    }
}

public struct InterfaceRef<T> where T <: ComInterface & Interface<T> {
    private let raw_: CPointer<Unit>

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            throw IllegalArgumentException("InterfaceRef requires a non-null interface pointer")
        }
        raw_ = raw
    }

    public static unsafe func fromRaw(raw: CPointer<Unit>): InterfaceRef<T> {
        InterfaceRef<T>(raw)
    }

    public static func fromInterface(value: T): InterfaceRef<T> {
        let raw = value.asRaw()
        if (raw.isNull()) {
            throw IllegalStateException("InterfaceRef.fromInterface requires a live interface")
        }
        InterfaceRef<T>(raw)
    }

    public func asRaw(): CPointer<Unit> {
        raw_
    }

    public func value(): T {
        T.viewOf(raw_)
    }

    public func retain(): T {
        interfaceHandleAddRefRaw(raw_)
        T.fromAbiTake(raw_)
    }

}

extend IUnknown <: Interface<IUnknown> {}

extend IInspectable <: Interface<IInspectable> {}

extend IAgileObject {
    public static func fromAbiTake(raw: CPointer<Unit>): IAgileObject {
        IAgileObject(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAgileObject {
        IAgileObject(raw)
    }
}

extend IAgileObject <: Interface<IAgileObject> {}

extend IAgileReference {
    public static func fromAbiTake(raw: CPointer<Unit>): IAgileReference {
        IAgileReference(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAgileReference {
        IAgileReference(raw)
    }
}

extend IAgileReference <: Interface<IAgileReference> {}

extend IWeakReference {
    public static func fromAbiTake(raw: CPointer<Unit>): IWeakReference {
        IWeakReference(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IWeakReference {
        IWeakReference(raw)
    }
}

extend IWeakReference <: Interface<IWeakReference> {}

extend IWeakReferenceSource {
    public static func fromAbiTake(raw: CPointer<Unit>): IWeakReferenceSource {
        IWeakReferenceSource(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IWeakReferenceSource {
        IWeakReferenceSource(raw)
    }
}

extend IWeakReferenceSource <: Interface<IWeakReferenceSource> {}

public unsafe func cast<T, U>(
    value: T,
    descriptor: InterfaceDescriptor<U>
): Result<U> where T <: ComInterface & Interface<T>, U <: ComInterface & Interface<U> {
    let raw = value.asRaw()
    if (raw.isNull()) {
        return Result<U>.Err(WinError(E_POINTER))
    }
    if (descriptor.matches(T.IID())) {
        return Result<U>.Ok(descriptor.viewOf(raw))
    }
    match (queryInterfaceRaw(raw, descriptor.iid)) {
        case Some(resolved) =>
            Result<U>.Ok(descriptor.takeFromAbi(resolved))
        case None =>
            Result<U>.Err(WinError(E_NOINTERFACE))
    }
}

public unsafe func castToAny<T, U>(value: T): Option<U> where T <: ComInterface & Interface<T> {
    asImpl<U>(value)
}

public unsafe func castObject<T, U>(value: T): Result<ComObject<U>> where T <: ComInterface & Interface<T> {
    match (ComObject<U>.castFrom(value)) {
        case Some(object) =>
            Result<ComObject<U>>.Ok(object)
        case None =>
            Result<ComObject<U>>.Err(WinError(E_NOINTERFACE))
    }
}

public func toRef<T>(value: T): InterfaceRef<T> where T <: ComInterface & Interface<T> {
    InterfaceRef<T>.fromInterface(value)
}
