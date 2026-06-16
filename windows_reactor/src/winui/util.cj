package windows_reactor.winui

import windows_core.{
    GUID,
    HString,
    HRESULT,
    E_NOINTERFACE,
    IUnknown,
    Result,
    WindowsException,
    queryInterfaceRaw
}
import windows_interface.IInspectable
import windows_sys.impl.Windows_Foundation_Collections.{Windows_Foundation_Collections_IVector_1 as IVectorRawUtil, Windows_Foundation_Collections_IMap_2 as IMapRawUtil}

// The reactor's canonical Object-vector wrapper: a generic
// IVector<IInspectable> obtained by QI'ing a WinRT object with the canonical
// PIID. Used to mutate ItemsControl.Items / ComboBox / ListBox item stores.
public type InspectableVector = IVectorRawUtil<IInspectable>

// The reactor's canonical Object->Object map wrapper: a generic
// IMap<IInspectable, IInspectable> obtained by QI'ing a WinRT object with the
// canonical PIID. Used to read Application.Resources (a ResourceDictionary that
// projects IMap<Object, Object>) for named-style lookup.
public type InspectableMap = IMapRawUtil<IInspectable, IInspectable>

// ============================================================================
// Shared FFI helpers (ported from the runtime-only WinUI support package).
// Made public so the backend / host / thunk modules in this package can share
// them. checkHRESULT/expectFactory/releaseRaw/releaseFailedWinuiOutSlot/
// hStringOutToString/readWinuiVtbl/queryRequired mirror the proven host code.
// ============================================================================

public func checkHRESULT(hr: HRESULT, operation: String): Unit {
    if (hr.failed()) {
        let _ = operation
        throw WindowsException(hr)
    }
}

public func expectFactory<T>(result: Result<T>, operation: String): T {
    match (result) {
        case Result<T>.Ok(value) => value
        case Result<T>.Err(error) => throw Exception("${operation} failed: ${error}")
    }
}

public func releaseRaw(raw: CPointer<Unit>): Unit {
    if (raw.isNotNull()) {
        IUnknown.fromAbiTake(raw).close()
    }
}

public func releaseFailedWinuiOutSlot(slot: CPointer<CPointer<Unit>>): Unit {
    if (slot.isNull()) {
        return
    }
    let raw = unsafe { slot.read() }
    if (raw.isNotNull()) {
        unsafe { slot.write(CPointer<Unit>()) }
        releaseRaw(raw)
    }
}

public func readWinuiVtbl<T>(raw: CPointer<Unit>): T where T <: CType {
    if (raw.isNull()) {
        throw Exception("WinRT object pointer is null")
    }
    let table = unsafe { CPointer<CPointer<T>>(raw).read() }
    if (table.isNull()) {
        throw Exception("WinRT vtable pointer is null")
    }
    return unsafe { table.read() }
}

public func queryRequired(raw: CPointer<Unit>, iid: GUID, name: String): CPointer<Unit> {
    match (unsafe { queryInterfaceRaw(raw, iid) }) {
        case Some(value) => return value
        case None => throw Exception("QueryInterface failed for ${name}: ${E_NOINTERFACE}")
    }
}

// Canonical PIID for Windows.Foundation.Collections.IVector<Object> /
// IVector<IInspectable> = B32BDCA4-5E52-5B27-BC5D-D66A1A268C2A.
//
// The generated Windows_Foundation_Collections_IVector_1<IInspectable>.iid()
// mis-computes this PIID: it hashes "pinterface({913337e9-…};" + T.signature() + ")"
// where T.signature() is taken through the windows_core.RuntimeType static witness,
// and for IInspectable that witness resolves to the inherited RuntimeName default
// "" (not the class-body "cinterface(IInspectable)" override), so the element token
// is dropped and the wrong GUID F29F8B50-… is produced. A real WinRT
// Object-parameterized vector (e.g. a Microsoft.UI.Xaml.Controls.ItemCollection
// returned by ItemsControl.Items) only answers QueryInterface for the canonical IID,
// so the generated iid() yields E_NOINTERFACE.
//
// We rebuild the signature with the element token spelled explicitly — the value
// IInspectable.signature() returns when called directly is correct — and hash that,
// which reproduces the canonical IID. Computed once lazily.
let CORRECT_IVECTOR_IINSPECTABLE_SIG = "pinterface({913337e9-11a1-4345-a3a2-4e7f956e222d};cinterface(IInspectable))"

public func inspectableVectorIid(): GUID {
    GUID.from_signature(CORRECT_IVECTOR_IINSPECTABLE_SIG)
}

// QI `raw` (an ItemCollection / IObservableVector<Object> identity) to the
// generic IVector<IInspectable> using the canonical PIID, and wrap the owned
// result. Caller owns the returned vector and must close() it. Throws (via
// queryRequired) when the object does not answer QI for IVector<Object>.
public func takeInspectableVector(raw: CPointer<Unit>): InspectableVector {
    let vecRaw = queryRequired(raw, inspectableVectorIid(),
        "Windows.Foundation.Collections.IVector<Object>")
    InspectableVector.fromAbiTake(vecRaw)
}

// Canonical PIID for Windows.Foundation.Collections.IMap<Object, Object> /
// IMap<IInspectable, IInspectable> = F5F69427-55ED-5512-8429-D4F6626DFCDD.
//
// Same mis-hash defect as inspectableVectorIid: the generated
// Windows_Foundation_Collections_IMap_2<IInspectable, IInspectable>.iid() takes
// each element's signature through the windows_core.RuntimeType static witness,
// which for IInspectable does not resolve to the class-body
// "cinterface(IInspectable)" override, so both element tokens are dropped and a
// wrong GUID is hashed. A real WinRT Object->Object map (e.g. a
// Microsoft.UI.Xaml.ResourceDictionary returned by Application.Resources) only
// answers QueryInterface for the canonical IID, so the generated iid() yields
// E_NOINTERFACE. We rebuild the signature with both element tokens spelled
// explicitly — the value IInspectable.signature() returns when called directly
// is correct — and hash that, which reproduces the canonical IID. Computed once
// lazily.
let CORRECT_IMAP_IINSPECTABLE_SIG =
    "pinterface({3c2925fe-8519-45c1-aa79-197b6718c1c1};cinterface(IInspectable);cinterface(IInspectable))"

public func inspectableMapIid(): GUID {
    GUID.from_signature(CORRECT_IMAP_IINSPECTABLE_SIG)
}

// QI `raw` (a ResourceDictionary / IMap<Object, Object> identity) to the generic
// IMap<IInspectable, IInspectable> using the canonical PIID, and wrap the owned
// result. Caller owns the returned map and must close() it. Throws (via
// queryRequired) when the object does not answer QI for IMap<Object, Object>.
public func takeInspectableMap(raw: CPointer<Unit>): InspectableMap {
    let mapRaw = queryRequired(raw, inspectableMapIid(),
        "Windows.Foundation.Collections.IMap<Object, Object>")
    InspectableMap.fromAbiTake(mapRaw)
}

public func hStringOutToString(raw: CPointer<Unit>): String {
    let value = HString.fromSystemHandleTake(raw)
    try {
        return value.toString()
    } finally {
        value.close()
    }
}
