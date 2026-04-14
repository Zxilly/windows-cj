package windows_core

import windows_implement.ComObjectBase
import windows_implement.{ImplementationAccess, comRegistryLookup, rootRegistryKeyFromRaw}

public interface IUnknownImpl <: ComObjectBase {
    func getImpl<T>(): Option<T>
    func getImplMut<T>(): Option<T>
    func intoInner<T>(): Option<T>
    func QueryInterface(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32
    func AddRef(): UInt32
    func Release(): UInt32
    func isReferenceCountOne(): Bool
    func GetTrustLevel(value: CPointer<Int32>): Int32
    func asInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I>
    func toInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I>
    func toObject<T>(): ComObject<T>
}

extend<T> ComObjectRuntime<T> <: IUnknownImpl {
    public func getImpl<U>(): Option<U> {
        getImplAs<U>()
    }

    public func getImplMut<U>(): Option<U> {
        match (getMut()) {
            case Some(value) =>
                match (value as U) {
                    case Some(resolved) => Some(resolved)
                    case None => None
                }
            case None =>
                None
        }
    }

    public func intoInner<U>(): Option<U> {
        match (takeInner()) {
            case Some(value) =>
                match (value as U) {
                    case Some(resolved) => Some(resolved)
                    case None => None
                }
            case None =>
                None
        }
    }

    public func QueryInterface(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        queryInterfaceBase(identityPointer(), iid, resultSlot)
    }

    public func AddRef(): UInt32 {
        addRefBase()
    }

    public func Release(): UInt32 {
        releaseBase(identityPointer().toUIntNative())
    }

    public func isReferenceCountOne(): Bool {
        isReferenceCountOne()
    }

    public func GetTrustLevel(value: CPointer<Int32>): Int32 {
        getTrustLevelBase(value)
    }

    public func asInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        match (unsafe { queryInterfaceRaw(identityPointer(), descriptor.iid) }) {
            case Some(raw) =>
                let view = descriptor.viewOf(raw)
                descriptor.releasePointer(raw)
                view
            case None =>
                throw Exception("IUnknownImpl.asInterface: requested interface is not implemented")
        }
    }

    public func toInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        match (unsafe { queryInterfaceRaw(identityPointer(), descriptor.iid) }) {
            case Some(raw) =>
                descriptor.takeFromAbi(raw)
            case None =>
                throw Exception("IUnknownImpl.toInterface: requested interface is not implemented")
        }
    }

    public func toObject<U>(): ComObject<U> {
        let raw = identityPointer()
        if (raw.isNull()) {
            throw Exception("IUnknownImpl.toObject requires a live COM identity")
        }
        match (ComObject<U>.castFromRaw(raw)) {
            case Some(value) =>
                value
            case None =>
                throw Exception("IUnknownImpl.toObject: requested implementation type does not match")
        }
    }
}

public func newIUnknownVtbl<T>(offset!: Int64 = 0): IUnknownVtbl where T <: IUnknownImpl {
    buildIUnknownVtbl(offset: offset)
}

func lookupComImpl<T>(instanceRaw: CPointer<Unit>): Option<T> {
    if (instanceRaw.isNull()) {
        return None
    }
    let lookupKey = unsafe { rootRegistryKeyFromRaw(instanceRaw) }
    match (comRegistryLookup(lookupKey)) {
        case Some(obj) =>
            match (obj) {
                case value: T => Some(value)
                case _ => None
            }
        case None =>
            None
    }
}

func lookupComInnerImpl<T>(instanceRaw: CPointer<Unit>): Option<T> {
    if (instanceRaw.isNull()) {
        return None
    }
    let lookupKey = unsafe { rootRegistryKeyFromRaw(instanceRaw) }
    match (comRegistryLookup(lookupKey)) {
        case Some(obj) =>
            match (obj) {
                case value: ImplementationAccess => value.getImplAs<T>()
                case _ => None
            }
        case None =>
            None
    }
}
