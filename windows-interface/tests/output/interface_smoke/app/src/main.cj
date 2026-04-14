package interface_smoke_app

import windows_interface.*
import windows_result.*

func expect(cond: Bool, message: String): Unit {
    if (!cond) {
        throw Exception(message)
    }
}

@C
public struct FakeInspectableObject {
    public var vtbl: CPointer<IInspectableVtbl> = CPointer<IInspectableVtbl>()
    public init() {}
}

var addRefCalls: UInt32 = 0u32
var releaseCalls: UInt32 = 0u32
var queryCalls: UInt32 = 0u32
var refCount: UInt32 = 1u32

@C
public func fakeQueryInterface(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultPtr: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        queryCalls += 1u32
        if (iid.isNull() || resultPtr.isNull()) {
            return E_POINTER.value
        }
        let requested = iid.read()
        if (requested == IUnknown.iid() || requested == IInspectable.iid()) {
            refCount = fakeAddRef(this_)
            resultPtr.write(this_)
            return S_OK.value
        }
        resultPtr.write(CPointer<Unit>())
        return E_NOINTERFACE.value
    }
}

@C
public func fakeAddRef(_: CPointer<Unit>): UInt32 {
    addRefCalls += 1u32
    refCount += 1u32
    refCount
}

@C
public func fakeRelease(_: CPointer<Unit>): UInt32 {
    releaseCalls += 1u32
    if (refCount > 0u32) {
        refCount -= 1u32
    }
    refCount
}

@C
public func fakeGetIids(
    _: CPointer<Unit>,
    count: CPointer<UInt32>,
    values: CPointer<CPointer<GUID>>
): Int32 {
    unsafe {
        if (!count.isNull()) {
            count.write(0u32)
        }
        if (!values.isNull()) {
            values.write(CPointer<GUID>())
        }
    }
    S_OK.value
}

@C
public func fakeGetRuntimeClassName(
    _: CPointer<Unit>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (!value.isNull()) {
            value.write(CPointer<Unit>())
        }
    }
    S_OK.value
}

@C
public func fakeGetTrustLevel(_: CPointer<Unit>, value: CPointer<Int32>): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER.value
        }
        value.write(7i32)
    }
    S_OK.value
}

public class DemoTarget {
    public var lastValue: Int32 = 0i32
}

public class DemoTargetView <: AbiPointerBacked {
    private let raw: CPointer<Unit>

    public init(raw: CPointer<Unit>) {
        this.raw = raw
    }

    public func asAbiPointer(): CPointer<Unit> {
        raw
    }
}

var targetScopedReleaseCalls: UInt32 = 0u32

func expectTargetBackedInterfaceResource(): Unit {
    let descriptor = AbiReferenceDescriptor<DemoTargetView>(
        "DemoTarget",
        { raw => DemoTargetView(raw) },
        { raw => DemoTargetView(raw) },
        { _ => 0u32 },
        { _ =>
            targetScopedReleaseCalls += 1u32
            1u32
        }
    )
    let target = DemoTarget()
    targetScopedReleaseCalls = 0u32

    let firstVtblHandle = unsafe { acquireArrayRawData(Array<IUnknownVtbl>(1, { _ => IUnknownVtbl() })) }
    let firstScoped = unsafe {
        createInterfaceResourceFromTarget(
            descriptor,
            target,
            CPointer<Unit>(firstVtblHandle.pointer)
        )
    }
    let firstRaw = firstScoped.asRaw()

    let secondVtblHandle = unsafe { acquireArrayRawData(Array<IUnknownVtbl>(1, { _ => IUnknownVtbl() })) }
    let secondScoped = unsafe {
        createInterfaceResourceFromTarget(
            descriptor,
            target,
            CPointer<Unit>(secondVtblHandle.pointer)
        )
    }
    let secondRaw = secondScoped.asRaw()

    expect(firstRaw.isNotNull(), "target-backed InterfaceResource should allocate a live raw view")
    expect(secondRaw.isNotNull(), "target-backed InterfaceResource should allocate one raw view per scope")
    expect(firstScoped.slotInfo().vtable == CPointer<Unit>(firstVtblHandle.pointer).toUIntNative(), "target-backed InterfaceResource should retain the supplied vtable pointer")
    expect(firstScoped.slotInfo().this_ptr == secondScoped.slotInfo().this_ptr, "target-backed InterfaceResource should record the target identity instead of the synthetic raw slot")
    expect(firstScoped.slotInfo().this_ptr != firstRaw.toUIntNative(), "target-backed InterfaceResource should not store the synthetic raw slot as its this pointer")

    match (lookupInterfaceTarget<DemoTarget>(firstRaw)) {
        case Some(resolved) =>
            resolved.lastValue = 17i32
            expect(target.lastValue == 17i32, "target-backed InterfaceResource should register the original target object")
        case None =>
            throw Exception("target-backed InterfaceResource should register its target for raw lookup")
    }

    firstScoped.close()
    expect(targetScopedReleaseCalls == 0u32, "target-backed InterfaceResource.close should not dispatch through Release")
    match (lookupInterfaceTarget<DemoTarget>(firstRaw)) {
        case Some(_) =>
            throw Exception("closing a target-backed InterfaceResource should remove its raw registry entry")
        case None => ()
    }
    match (lookupInterfaceTarget<DemoTarget>(secondRaw)) {
        case Some(_) => ()
        case None =>
            throw Exception("closing one target-backed InterfaceResource should not invalidate sibling raw views")
    }

    secondScoped.close()
    expect(targetScopedReleaseCalls == 0u32, "all target-backed InterfaceResource.close paths should bypass Release")
    match (lookupInterfaceTarget<DemoTarget>(secondRaw)) {
        case Some(_) =>
            throw Exception("closing the final target-backed InterfaceResource should remove the raw registry entry")
        case None => ()
    }
}

main(_args: Array<String>) {
    let guid = GUID(
        0x12345678u32,
        0x9ABCu16,
        0xDEF0u16,
        0x12u8,
        0x34u8,
        0x56u8,
        0x78u8,
        0x9Au8,
        0xBCu8,
        0xDEu8,
        0xF0u8
    )
    let same = GUID(
        0x12345678u32,
        0x9ABCu16,
        0xDEF0u16,
        0x12u8,
        0x34u8,
        0x56u8,
        0x78u8,
        0x9Au8,
        0xBCu8,
        0xDEu8,
        0xF0u8
    )
    expect(guid == same, "GUID equality should compare all fields")
    expect(guid != GUID_ZERO, "non-zero GUID should differ from GUID_ZERO")
    expect(guid.toString() == "12345678-9ABC-DEF0-1234-56789ABCDEF0", "GUID formatting should be canonical")

    let inspectableDescriptor = IInspectable.descriptor()
    expect(inspectableDescriptor.matches(IInspectable.iid()), "descriptor should match its own IID")
    expect(inspectableDescriptor.matches(IUnknown.iid()), "descriptor should match inherited IIDs through its ancestor chain")
    match (inspectableDescriptor.baseIid) {
        case Some(base) =>
            expect(base == IUnknown.iid(), "baseIid compatibility view should expose the first ancestor IID")
        case None =>
            throw Exception("IInspectable descriptor should expose IUnknown as its compatible base IID")
    }
    let multiLevelDescriptor = InterfaceDescriptor<IUnknown>(
        "NestedIUnknown",
        guid,
        [IInspectable.iid(), IUnknown.iid()],
        { raw => IUnknown(raw) }
    )
    expect(multiLevelDescriptor.matches(IInspectable.iid()), "descriptor should match a direct ancestor IID")
    expect(multiLevelDescriptor.matches(IUnknown.iid()), "descriptor should match a transitive ancestor IID")

    let defaultInspectableVtbl = IInspectableVtbl()
    var defaultIidCount = 9u32
    var defaultGuidStorage = guid
    var defaultIidValues = CPointer<GUID>(inout defaultGuidStorage)
    let defaultIidsHr = unsafe {
        defaultInspectableVtbl.GetIids(
            CPointer<Unit>(),
            CPointer<UInt32>(inout defaultIidCount),
            CPointer<CPointer<GUID>>(inout defaultIidValues)
        )
    }
    expect(defaultIidsHr == S_OK.value, "default GetIids should report success")
    expect(defaultIidCount == 0u32, "default GetIids should report zero extra IIDs")
    expect(defaultIidValues.isNull(), "default GetIids should null the IID array output")
    var defaultRuntimeClassSeed = 99u32
    var defaultRuntimeClassName = CPointer<Unit>(CPointer<UInt32>(inout defaultRuntimeClassSeed))
    let defaultRuntimeClassHr = unsafe {
        defaultInspectableVtbl.GetRuntimeClassName(
            CPointer<Unit>(),
            CPointer<CPointer<Unit>>(inout defaultRuntimeClassName)
        )
    }
    expect(defaultRuntimeClassHr == S_OK.value, "default GetRuntimeClassName should report success")
    expect(defaultRuntimeClassName.isNull(), "default GetRuntimeClassName should return a null HSTRING")
    var defaultTrustLevel = -1i32
    let defaultTrustLevelHr = unsafe {
        defaultInspectableVtbl.GetTrustLevel(CPointer<Unit>(), CPointer<Int32>(inout defaultTrustLevel))
    }
    expect(defaultTrustLevelHr == S_OK.value, "default GetTrustLevel should report success")
    expect(defaultTrustLevel == 0i32, "default GetTrustLevel should return BaseTrust")

    var inspectableVtbl = IInspectableVtbl()
    inspectableVtbl.base_.QueryInterface = fakeQueryInterface
    inspectableVtbl.base_.AddRef = fakeAddRef
    inspectableVtbl.base_.Release = fakeRelease
    inspectableVtbl.GetIids = fakeGetIids
    inspectableVtbl.GetRuntimeClassName = fakeGetRuntimeClassName
    inspectableVtbl.GetTrustLevel = fakeGetTrustLevel

    var object = FakeInspectableObject()
    object.vtbl = CPointer<IInspectableVtbl>(inout inspectableVtbl)

    let raw = CPointer<Unit>(CPointer<FakeInspectableObject>(inout object))
    let unknown = IUnknown(raw)
    let refCountProbe = IUnknown(raw)

    expect(unknown.asRaw().toUIntNative() == raw.toUIntNative(), "IUnknown should round-trip raw pointers")
    expect(IUnknown.descriptor().iid == IUnknown.iid(), "IUnknown descriptor should expose the IID")

    let addRefCount = refCountProbe.addRef()
    let releaseCount = refCountProbe.release()
    expect(addRefCount == 2u32, "IUnknown.addRef should delegate to the vtable and increment the reference count")
    expect(releaseCount == 1u32, "IUnknown.release should delegate to the vtable and decrement the reference count")

    match (unsafe { unknown.query(IInspectable.descriptor()) }) {
        case Some(inspectable) =>
            expect(inspectable.asRaw().toUIntNative() == raw.toUIntNative(), "query helper should wrap the returned pointer")
            expect(refCount == 2u32, "QueryInterface should transfer one owned reference to the typed wrapper")
            let unknownView = inspectable.asIUnknown()
            expect(unknownView.asRaw().toUIntNative() == raw.toUIntNative(), "IInspectable should preserve IUnknown identity")
            var trustLevel = 0i32
            let hr = unsafe { inspectable.getTrustLevel(CPointer<Int32>(inout trustLevel)) }
            expect(hr == S_OK, "IInspectable.getTrustLevel should surface HRESULT")
            expect(trustLevel == 7i32, "IInspectable.getTrustLevel should populate the output")
            unknownView.close()
            expect(releaseCalls == 1u32, "borrowed upcasts should not release the underlying COM pointer")
            inspectable.close()
            expect(refCount == 1u32, "closing the owned query wrapper should release the QueryInterface reference exactly once")
        case None =>
            throw Exception("query helper should return IInspectable for the fake object")
    }

    expect(queryCalls == 1u32, "query helper should call QueryInterface exactly once")
    let missingIid = GUID(
        0x89ABCDEFu32,
        0x0123u16,
        0x4567u16,
        0x89u8,
        0xABu8,
        0xCDu8,
        0xEFu8,
        0x01u8,
        0x23u8,
        0x45u8,
        0x67u8
    )
    let missingDescriptor = InterfaceDescriptor<IUnknown>("MissingIUnknown", missingIid, { raw => IUnknown(raw) })
    match (unsafe { unknown.query(missingDescriptor) }) {
        case Some(_) =>
            throw Exception("query helper should not wrap unsupported interfaces")
        case None =>
            expect(refCount == 1u32, "failed QueryInterface should not leak or release references")
    }
    expect(queryCalls == 2u32, "unsupported query should still invoke QueryInterface")

    expectTargetBackedInterfaceResource()
}