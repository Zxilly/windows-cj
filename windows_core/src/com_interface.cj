package windows_core

import windows_interface as windows_interface
// Intentional public compatibility surface for COM interface APIs that now live
// in windows_interface. Keep these re-exports so existing windows_core users do
// not need to change imports while the implementation remains split.
public import windows_interface.{
    ComInterface,
    InterfaceDescriptor,
    InterfaceDescriptorBase,
    InterfaceWrapperBase,
    IUnknownVtbl,
    IInspectableVtbl,
    IAgileObjectVtbl,
    IAgileReferenceVtbl,
    IMarshalVtbl,
    IWeakReferenceVtbl,
    IWeakReferenceSourceVtbl,
    IUnknown,
    IInspectable,
    IAgileObject,
    IAgileReference,
    IMarshal,
    IWeakReference,
    IWeakReferenceSource,
    IID_IUNKNOWN,
    IID_IAGILEOBJECT,
    IID_IAGILEREFERENCE,
    IID_IMARSHAL,
    IID_IWEAKREFERENCE,
    IID_IWEAKREFERENCESOURCE,
    queryInterfaceRaw,
    queryInterfaceAs,
    eraseInterfaceDescriptor
}

public enum QueryResult<T> {
    | Ok(T)
    | Err(HRESULT)
}

public interface IUnknownIdentity {
    func hasSameIdentity(other: ComInterface): Bool
}

public unsafe func queryInterface(source: CPointer<Unit>, targetIid: GUID): Option<CPointer<Unit>> {
    queryInterfaceRaw(source, targetIid)
}

// Query a raw COM pointer for IInspectable, throwing a descriptive error when the
// object does not implement it. Shared by delegate/event-handler projections in
// both the collections and foundation packages, so it lives in windows_core.
public func delegateAsInspectable(raw: CPointer<Unit>, typeName: String): IInspectable {
    match (unsafe { queryInterfaceAs(raw, IInspectable.descriptor()) }) {
        case Some(value) =>
            value
        case None =>
            throw Exception("${typeName} does not implement IInspectable")
    }
}

public unsafe func queryInterfaceResult<U>(
    source: CPointer<Unit>,
    target: InterfaceDescriptor<U>
): QueryResult<InterfaceHandle<U>> where U <: ComInterface {
    let pointerError = HRESULT(-2147467261i32)
    if (source.isNull()) {
        return QueryResult<InterfaceHandle<U>>.Err(pointerError)
    }

    var iid = target.iid
    var result = CPointer<Unit>()
    let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(source).read()
    let vtbl = vtblPtr.read()
    let hr = HRESULT(vtbl.QueryInterface(source, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout result)))

    if (hr.succeeded()) {
        if (!result.isNull()) {
            return QueryResult<InterfaceHandle<U>>.Ok(InterfaceHandle<U>.fromAbiTake(result, target))
        }
        return QueryResult<InterfaceHandle<U>>.Err(pointerError)
    }

    if (result.isNotNull()) {
        interfaceHandleReleaseRaw(result)
    }
    QueryResult<InterfaceHandle<U>>.Err(hr)
}

// Compare whether two COM wrappers point at the same IUnknown identity.
public unsafe func sameComIdentity(left: ComInterface, right: ComInterface): Bool {
    let leftRaw = left.asRaw()
    let rightRaw = right.asRaw()
    if (leftRaw.isNull() || rightRaw.isNull()) {
        return false
    }

    match (queryInterfaceRaw(leftRaw, IID_IUNKNOWN)) {
        case Some(leftIdentity) =>
            match (queryInterfaceRaw(rightRaw, IID_IUNKNOWN)) {
                case Some(rightIdentity) =>
                    let same = leftIdentity.toUIntNative() == rightIdentity.toUIntNative()
                    interfaceHandleReleaseRaw(leftIdentity)
                    interfaceHandleReleaseRaw(rightIdentity)
                    return same
                case None =>
                    interfaceHandleReleaseRaw(leftIdentity)
                    return false
            }
        case None =>
            return false
    }
}

extend IUnknown <: IUnknownIdentity {
    // Query both wrappers to IUnknown and compare the canonical identity pointer.
    public unsafe func hasSameIdentity(other: ComInterface): Bool {
        sameComIdentity(this, other)
    }
}
