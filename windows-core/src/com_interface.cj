package windows_core

// Thin compatibility re-exports for the split interface package.
public import windows_interface.{
    ComInterface,
    InterfaceDescriptor,
    InterfaceWrapperBase,
    IUnknownVtbl,
    IInspectableVtbl,
    IUnknown,
    IInspectable,
    IID_IUNKNOWN,
    queryInterfaceRaw,
    queryInterfaceAs
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

    QueryResult<InterfaceHandle<U>>.Err(hr)
}

// 比较两个 COM 包装是否指向同一个 IUnknown 身份。
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
    // 通过 QI 到 IUnknown 后比较指针地址，判断是否为同一 COM 身份。
    public unsafe func hasSameIdentity(other: ComInterface): Bool {
        sameComIdentity(this, other)
    }
}
