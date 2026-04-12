package windows_interface_alignment_smoke

import windows_interface.*
import windows_strings.*

let S_OK_VALUE: Int32 = 0i32
let E_NOINTERFACE_VALUE: Int32 = -2147467262i32
let E_POINTER_VALUE: Int32 = -2147467261i32

func expect(cond: Bool, message: String): Unit {
    if (!cond) {
        throw Exception(message)
    }
}

func samePointer(left: CPointer<Unit>, right: CPointer<Unit>): Bool {
    left.toUIntNative() == right.toUIntNative()
}

public class DemoRuntimeName <: RuntimeName {
    public static func runtimeName(): String {
        "Demo.Runtime.Type"
    }
}

@C
public struct FakeInspectableObject {
    public var vtbl: CPointer<IInspectableVtbl> = CPointer<IInspectableVtbl>()
    public init() {}
}

@C
public struct DemoCallbackVtbl {
    public var Invoke: CFunc<(CPointer<Unit>, Int32) -> Int32> = { _, value => value }
    public init() {}
}

public class DemoCallbackView <: AbiPointerBacked {
    private let raw: CPointer<Unit>

    public init(raw: CPointer<Unit>) {
        this.raw = raw
    }

    public func asAbiPointer(): CPointer<Unit> {
        raw
    }
}

var targetBackedReleaseCalls: UInt32 = 0u32

public class DemoCallbackTarget {
    public var lastValue: Int32 = 0i32
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
            return E_POINTER_VALUE
        }

        let requested = iid.read()
        if (requested == IUnknown.iid() || requested == IInspectable.iid()) {
            refCount = fakeAddRef(this_)
            resultPtr.write(this_)
            return S_OK_VALUE
        }

        resultPtr.write(CPointer<Unit>())
        return E_NOINTERFACE_VALUE
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
    S_OK_VALUE
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
    S_OK_VALUE
}

@C
public func fakeGetTrustLevel(_: CPointer<Unit>, value: CPointer<Int32>): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER_VALUE
        }
        value.write(7i32)
    }
    S_OK_VALUE
}

func expectDescriptorChains(raw: CPointer<Unit>): Unit {
    let middleIid = GUID(
        0x01020304u32,
        0x0506u16,
        0x4708u16,
        0x80u8,
        0x10u8,
        0x20u8,
        0x30u8,
        0x40u8,
        0x50u8,
        0x60u8,
        0x70u8
    )
    let leafIid = GUID(
        0x11223344u32,
        0x5566u16,
        0x4788u16,
        0x90u8,
        0x11u8,
        0x21u8,
        0x31u8,
        0x41u8,
        0x51u8,
        0x61u8,
        0x71u8
    )

    let middleDescriptor = InterfaceDescriptor<IUnknown>(
        "IMiddle",
        middleIid,
        IInspectable.descriptor(),
        { value => IUnknown(value, ownsReference: true) },
        { value => IUnknown(value) }
    )
    let leafDescriptor = InterfaceDescriptor<IUnknown>(
        "ILeaf",
        leafIid,
        middleDescriptor,
        { value => IUnknown(value, ownsReference: true) },
        { value => IUnknown(value) }
    )

    expect(leafDescriptor.matches(leafIid), "leaf descriptor should match its own IID")
    expect(leafDescriptor.matches(middleIid), "leaf descriptor should match its direct base IID")
    expect(leafDescriptor.matches(IInspectable.iid()), "leaf descriptor should match inherited WinRT IID")
    expect(leafDescriptor.matches(IUnknown.iid()), "leaf descriptor should match transitive IUnknown IID")
    expect(leafDescriptor.ancestorIids.size == 3, "leaf descriptor should expand the full ancestor IID chain")
    expect(leafDescriptor.ancestorIids[0] == middleIid, "expanded chain should start with the direct base IID")
    expect(leafDescriptor.ancestorIids[1] == IInspectable.iid(), "expanded chain should include intermediate WinRT base IID")
    expect(leafDescriptor.ancestorIids[2] == IUnknown.iid(), "expanded chain should include terminal IUnknown IID")
    match (leafDescriptor.directBaseName) {
        case Some(baseName) =>
            expect(baseName == "IMiddle", "descriptor directBaseName should preserve the direct parent name")
        case None =>
            throw Exception("leaf descriptor should preserve direct-base name metadata")
    }
    match (leafDescriptor.directBaseDescriptor()) {
        case Some(baseDescriptor) =>
            expect(baseDescriptor.descriptorName() == "IMiddle", "descriptor directBaseDescriptor should point at the direct parent descriptor")
        case None =>
            throw Exception("leaf descriptor should preserve the direct-base descriptor reference")
    }

    let schemaMethods = Array<InterfaceMethodSchema>(1, { _ =>
        InterfaceMethodSchema(
            "Invoke",
            6,
            Array<String>(1, { _ => "Int32" }),
            "Int32"
        )
    })
    let leafSchema = InterfaceDescriptorSchema(
        "LeafSchema",
        leafIid,
        IActivationFactory.descriptorSchema(),
        "LeafSchemaVtbl",
        "LeafSchema",
        "LeafSchema_Impl",
        schemaMethods
    )
    expect(leafSchema.ancestorIids.size == 3, "descriptor schema should expand the full ancestor IID chain")
    expect(leafSchema.ancestorIids[0] == IID_IACTIVATIONFACTORY, "schema chain should begin with the direct base IID")
    expect(leafSchema.ancestorIids[1] == IID_IINSPECTABLE, "schema chain should include IInspectable")
    expect(leafSchema.ancestorIids[2] == IID_IUNKNOWN, "schema chain should include IUnknown")
    expect(leafSchema.ancestorInterfaceNames.size == 3, "descriptor schema should expand ancestor names alongside ancestor IIDs")
    match (leafSchema.directBaseSchema) {
        case Some(baseSchema) =>
            expect(baseSchema.interfaceName == "IActivationFactory", "descriptor schema should preserve the direct-base schema reference")
        case None =>
            throw Exception("descriptor schema should preserve the direct-base schema reference")
    }

    match (unsafe { IUnknown(raw).query(leafDescriptor) }) {
        case Some(_) =>
            throw Exception("fake object should not unexpectedly implement the synthetic leaf descriptor")
        case None => ()
    }
}

func expectParameterSchemaMetadata(): Unit {
    let parameters = [
        InterfaceParameterSchema(
            "source",
            "CPointer<Unit>",
            "Ref<IInspectable>",
            InterfaceParameterBridgeKind.Ref
        ),
        InterfaceParameterSchema(
            "result",
            "CPointer<CPointer<Unit>>",
            "OutRef<IInspectable>",
            InterfaceParameterBridgeKind.OutRef
        )
    ]
    let method = InterfaceMethodSchema("Resolve", 6, parameters, "Int32")

    expect(method.parameters.size == 2, "InterfaceMethodSchema should preserve parameter metadata")
    expect(method.parameters[0].name == "source", "parameter schema should preserve the parameter name")
    expect(method.parameters[0].callerType == "Ref<IInspectable>", "parameter schema should preserve caller-side Ref types")
    match (method.parameters[0].bridgeKind) {
        case InterfaceParameterBridgeKind.Ref => ()
        case _ => throw Exception("parameter schema should mark Ref parameters explicitly")
    }
    expect(method.parameters[1].callerType == "OutRef<IInspectable>", "parameter schema should preserve caller-side OutRef types")
    match (method.parameters[1].bridgeKind) {
        case InterfaceParameterBridgeKind.OutRef => ()
        case _ => throw Exception("parameter schema should mark OutRef parameters explicitly")
    }
    expect(method.parameterTypes.size == 2, "legacy abiType view should remain available for ABI layout consumers")
    expect(method.parameterTypes[0] == "CPointer<Unit>", "legacy abiType view should continue exposing ABI parameter types")

    let autoSlotMethod = InterfaceMethodSchema(
        "ResolveAuto",
        [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
        "Int32"
    )
    expect(autoSlotMethod.abiSlot == -1, "InterfaceMethodSchema should support automatic abi slot assignment when omitted")

    let legacyAutoSlotMethod = InterfaceMethodSchema("ResolveLegacyAuto", ["Int32"], "Int32")
    expect(legacyAutoSlotMethod.abiSlot == -1, "legacy parameterType constructors should also support automatic abi slot assignment")
    expect(legacyAutoSlotMethod.parameterTypes[0] == "Int32", "automatic abi slot constructors should preserve legacy parameterType metadata")
}

func expectParamWrappers(raw: CPointer<Unit>): Unit {
    let borrowedInspectable = IInspectable(raw)
    let refArg = Ref<IInspectable>(borrowedInspectable)
    expect(samePointer(refArg.borrow(), raw), "Ref.borrow should surface the wrapped interface pointer")

    var outArg = OutRef<IInspectable>()
    var requested = IInspectable.iid()
    let hr = unsafe {
        fakeQueryInterface(raw, CPointer<GUID>(inout requested), outArg.borrowMut())
    }
    expect(hr == S_OK_VALUE, "OutRef.borrowMut should expose writable storage for ABI calls")

    match (outArg.take(IInspectable.descriptor())) {
        case Some(inspectable) =>
            expect(samePointer(inspectable.asRaw(), raw), "OutRef.take should wrap the ABI result with the provided descriptor")
            inspectable.close()
        case None =>
            throw Exception("OutRef.take should produce a wrapped interface value")
    }
}

func expectScopedInterface(raw: CPointer<Unit>): Unit {
    let scopedInspectable = unsafe { createScopedInterface(IInspectable.descriptor(), raw) }
    expect(samePointer(scopedInspectable.asRaw(), raw), "ScopedInterface should expose the wrapped raw pointer")
    expect(!scopedInspectable.isClosed(), "ScopedInterface should begin in the open state")
    scopedInspectable.close()
    expect(scopedInspectable.isClosed(), "ScopedInterface.close should mark the wrapper as closed")
}

func expectTargetBackedScopedInterface(): Unit {
    let descriptor = AbiReferenceDescriptor<DemoCallbackView>(
        "DemoCallback",
        { raw => DemoCallbackView(raw) },
        { raw => DemoCallbackView(raw) },
        { _ => 0u32 },
        { _ =>
            targetBackedReleaseCalls += 1u32
            1u32
        }
    )
    let target = DemoCallbackTarget()
    targetBackedReleaseCalls = 0u32

    let firstVtblHandle = unsafe { acquireArrayRawData(Array<DemoCallbackVtbl>(1, { _ => DemoCallbackVtbl() })) }
    let firstScoped = unsafe {
        createScopedInterfaceFromTarget(
            descriptor,
            target,
            CPointer<Unit>(firstVtblHandle.pointer)
        )
    }
    let firstRaw = firstScoped.asRaw()

    let secondVtblHandle = unsafe { acquireArrayRawData(Array<DemoCallbackVtbl>(1, { _ => DemoCallbackVtbl() })) }
    let secondScoped = unsafe {
        createScopedInterfaceFromTarget(
            descriptor,
            target,
            CPointer<Unit>(secondVtblHandle.pointer)
        )
    }
    let secondRaw = secondScoped.asRaw()

    expect(firstRaw.isNotNull(), "target-backed ScopedInterface should allocate a live raw view")
    expect(secondRaw.isNotNull(), "target-backed ScopedInterface should allocate an independent raw view per scope")
    expect(firstScoped.heap().vtable == CPointer<Unit>(firstVtblHandle.pointer).toUIntNative(), "target-backed ScopedInterface should retain the supplied static vtable pointer")
    expect(samePointer(firstScoped.value().asAbiPointer(), firstRaw), "target-backed ScopedInterface.value should wrap the allocated raw view")
    expect(firstScoped.heap().this_ptr == secondScoped.heap().this_ptr, "target-backed ScopedInterface should record the target identity rather than the synthetic raw slot")
    expect(firstScoped.heap().this_ptr != firstRaw.toUIntNative(), "target-backed ScopedInterface should not record the synthetic raw slot as the target identity")

    match (lookupScopedInterfaceTarget<DemoCallbackTarget>(firstRaw)) {
        case Some(resolved) =>
            resolved.lastValue = 17i32
            expect(target.lastValue == 17i32, "target-backed ScopedInterface should register the original target object")
        case None =>
            throw Exception("target-backed ScopedInterface should register its target for raw lookup")
    }

    firstScoped.close()
    expect(firstScoped.isClosed(), "target-backed ScopedInterface.close should close the allocated raw view")
    expect(targetBackedReleaseCalls == 0u32, "target-backed ScopedInterface.close should not dispatch through Release")
    match (lookupScopedInterfaceTarget<DemoCallbackTarget>(firstRaw)) {
        case Some(_) =>
            throw Exception("target-backed ScopedInterface.close should remove the raw-to-target registry entry")
        case None => ()
    }
    match (lookupScopedInterfaceTarget<DemoCallbackTarget>(secondRaw)) {
        case Some(_) => ()
        case None =>
            throw Exception("closing one target-backed ScopedInterface should not invalidate sibling raw views")
    }

    secondScoped.close()
    expect(targetBackedReleaseCalls == 0u32, "target-backed ScopedInterface siblings should also bypass Release when closed")
    match (lookupScopedInterfaceTarget<DemoCallbackTarget>(secondRaw)) {
        case Some(_) =>
            throw Exception("closing the final target-backed ScopedInterface should remove its raw-to-target registry entry")
        case None => ()
    }
}

func expectRuntimeNames(): Unit {
    let contract = runtimeTypeFromName<DemoRuntimeName>()
    expect(contract.runtimeName == "Demo.Runtime.Type", "runtimeTypeFromName should preserve the runtime class name")

    let runtimeClassName = runtimeClassNameOf<DemoRuntimeName>()
    expect(runtimeClassName.get() == "Demo.Runtime.Type", "runtimeClassNameOf should materialize the runtime class name as HString")
    runtimeClassName.close()
}

main(_args: Array<String>) {
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

    expectDescriptorChains(raw)
    expectParameterSchemaMetadata()
    expectParamWrappers(raw)
    expectScopedInterface(raw)
    expectTargetBackedScopedInterface()
    expectRuntimeNames()
}
