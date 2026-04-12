package windows_core

import windows_implement.ComObjectBase
import windows_implement.{ImplementationAccess, comRegistryLookup, rootRegistryKeyFromRaw}

public interface IUnknownImpl <: ComObjectBase {
    func get_impl<T>(): Option<T>
    func get_impl_mut<T>(): Option<T>
    func into_inner<T>(): Option<T>
    func QueryInterface(iid: GUID, ppvObject: CPointer<CPointer<Unit>>): Int32
    func AddRef(): UInt32
    func Release(): UInt32
    func is_reference_count_one(): Bool
    func GetTrustLevel(value: CPointer<Int32>): Int32
    func as_interface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I>
    func to_interface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I>
    func to_object<T>(): ComObject<T>
}

extend<T> ComObjectRuntime<T> <: IUnknownImpl {
    public func get_impl<U>(): Option<U> {
        getImplAs<U>()
    }

    public func get_impl_mut<U>(): Option<U> {
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

    public func into_inner<U>(): Option<U> {
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

    public func QueryInterface(iid: GUID, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        queryInterfaceBase(identityPointer(), iid, ppvObject)
    }

    public func AddRef(): UInt32 {
        addRefBase()
    }

    public func Release(): UInt32 {
        releaseBase(identityPointer().toUIntNative())
    }

    public func is_reference_count_one(): Bool {
        isReferenceCountOne()
    }

    public func GetTrustLevel(value: CPointer<Int32>): Int32 {
        getTrustLevelBase(value)
    }

    public func as_interface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        match (unsafe { queryInterfaceRaw(identityPointer(), descriptor.iid) }) {
            case Some(raw) =>
                let borrowed = descriptor.wrapBorrowed(raw)
                descriptor.releasePointer(raw)
                borrowed
            case None =>
                throw Exception("IUnknownImpl.as_interface: requested interface is not implemented")
        }
    }

    public func to_interface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        match (unsafe { queryInterfaceRaw(identityPointer(), descriptor.iid) }) {
            case Some(raw) =>
                descriptor.wrapOwned(raw)
            case None =>
                throw Exception("IUnknownImpl.to_interface: requested interface is not implemented")
        }
    }

    public func to_object<U>(): ComObject<U> {
        let raw = identityPointer()
        if (raw.isNull()) {
            throw Exception("IUnknownImpl.to_object requires a live COM identity")
        }
        match (ComObject<U>.castFromRaw(raw)) {
            case Some(value) =>
                value
            case None =>
                throw Exception("IUnknownImpl.to_object: requested implementation type does not match")
        }
    }
}

public func newIUnknownVtbl<T>(offset!: Int64 = 0): IUnknownVtbl where T <: IUnknownImpl {
    buildIUnknownVtbl(offset: offset)
}

func lookupComImpl<T>(this_: CPointer<Unit>): Option<T> {
    if (this_.isNull()) {
        return None
    }
    let lookupKey = unsafe { rootRegistryKeyFromRaw(this_) }
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

func lookupComInnerImpl<T>(this_: CPointer<Unit>): Option<T> {
    if (this_.isNull()) {
        return None
    }
    let lookupKey = unsafe { rootRegistryKeyFromRaw(this_) }
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
