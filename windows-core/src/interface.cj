package windows_core

public interface Interface<T> <: InterfaceType & Type<T, CPointer<Unit>, Option<T>> where T <: ComInterface {
    static func descriptor(): InterfaceDescriptor<T>
    static func fromRaw(raw: CPointer<Unit>): T
    static func fromRawBorrowed(raw: CPointer<Unit>): T

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
        fromRawBorrowed(abi)
    }

    static func from_abi(abi: CPointer<Unit>): Result<T> {
        if (abi.isNull()) {
            return Result<T>.Err(WinError(E_POINTER))
        }
        Result<T>.Ok(fromRaw(abi))
    }

    static func from_default(defaultValue: Option<T>): Result<T> {
        match (defaultValue) {
            case Some(value) =>
                match (value as InterfaceWrapperBase) {
                    case Some(wrapper) =>
                        let raw = wrapper.asRaw()
                        if (raw.isNull()) {
                            return Result<T>.Err(WinError(E_POINTER))
                        }
                        wrapper.addRef()
                        Result<T>.Ok(fromRaw(raw))
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
        T.fromRawBorrowed(raw_)
    }

    public func toOwned(): T {
        comPtrAddRefRaw(raw_)
        T.fromRaw(raw_)
    }
}

extend IUnknown <: Interface<IUnknown> {}

extend IInspectable <: Interface<IInspectable> {}

extend IAgileObject {
    public static func fromRaw(raw: CPointer<Unit>): IAgileObject {
        IAgileObject(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IAgileObject {
        IAgileObject(raw)
    }
}

extend IAgileObject <: Interface<IAgileObject> {}

extend IAgileReference {
    public static func fromRaw(raw: CPointer<Unit>): IAgileReference {
        IAgileReference(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IAgileReference {
        IAgileReference(raw)
    }
}

extend IAgileReference <: Interface<IAgileReference> {}

extend IWeakReference {
    public static func fromRaw(raw: CPointer<Unit>): IWeakReference {
        IWeakReference(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IWeakReference {
        IWeakReference(raw)
    }
}

extend IWeakReference <: Interface<IWeakReference> {}

extend IWeakReferenceSource {
    public static func fromRaw(raw: CPointer<Unit>): IWeakReferenceSource {
        IWeakReferenceSource(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IWeakReferenceSource {
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
        return Result<U>.Ok(descriptor.wrapBorrowed(raw))
    }
    match (queryInterfaceRaw(raw, descriptor.iid)) {
        case Some(resolved) =>
            Result<U>.Ok(descriptor.wrapOwned(resolved))
        case None =>
            Result<U>.Err(WinError(E_NOINTERFACE))
    }
}

public unsafe func cast_to_any<T, U>(value: T): Option<U> where T <: ComInterface & Interface<T> {
    asImpl<U>(value)
}

public unsafe func cast_object<T, U>(value: T): Result<ComObject<U>> where T <: ComInterface & Interface<T> {
    match (ComObject<U>.cast_from(value)) {
        case Some(object) =>
            Result<ComObject<U>>.Ok(object)
        case None =>
            Result<ComObject<U>>.Err(WinError(E_NOINTERFACE))
    }
}

public func to_ref<T>(value: T): InterfaceRef<T> where T <: ComInterface & Interface<T> {
    InterfaceRef<T>.fromInterface(value)
}
