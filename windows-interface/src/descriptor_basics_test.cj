package windows_interface

import std.unittest.*
import std.unittest.testmacro.*
import std.sync.AtomicInt64
import windows_result.{E_NOINTERFACE, Result, S_OK, WindowsException}

let typedActivationTestIid = GUID.parse("00000031-0000-0000-C000-000000000046")
let typedActivationQueryCount = AtomicInt64(0)
let typedActivationReleaseCount = AtomicInt64(0)
var typedActivationRaw = CPointer<Unit>()
var typedActivationProjectedRaw = CPointer<Unit>()

class TypedActivationTestInterface <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): TypedActivationTestInterface {
        TypedActivationTestInterface(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): TypedActivationTestInterface {
        TypedActivationTestInterface(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        typedActivationTestIid
    }

    public static func descriptor(): InterfaceDescriptor<TypedActivationTestInterface> {
        InterfaceDescriptor<TypedActivationTestInterface>(
            "TypedActivationTestInterface",
            typedActivationTestIid,
            IInspectable.descriptor(),
            { raw => TypedActivationTestInterface.fromAbiTake(raw) },
            { raw => TypedActivationTestInterface.viewOf(raw) }
        )
    }
}

@C
func typedActivationQueryInterfaceThunk(
    _: CPointer<Unit>,
    iid: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    let _ = typedActivationQueryCount.fetchAdd(1)
    let requestedIid = unsafe { iid.read() }
    if (requestedIid == typedActivationTestIid) {
        unsafe { result.write(typedActivationProjectedRaw) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    E_NOINTERFACE.value
}

@C
func typedActivationReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = typedActivationReleaseCount.fetchAdd(1)
    UInt32(previous + 1)
}

@C
func typedActivationActivateInstanceThunk(
    _: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    unsafe { result.write(typedActivationRaw) }
    S_OK.value
}

func resetTypedActivationTestState(): Unit {
    typedActivationQueryCount.store(0)
    typedActivationReleaseCount.store(0)
    typedActivationRaw = CPointer<Unit>()
    typedActivationProjectedRaw = CPointer<Unit>()
}

func typedActivationFactoryVtbl(): IActivationFactoryVtbl {
    var vtbl = IActivationFactoryVtbl()
    vtbl.ActivateInstance = typedActivationActivateInstanceThunk
    vtbl
}

func typedActivationObjectVtbl(): IInspectableVtbl {
    var vtbl = IInspectableVtbl()
    vtbl.base_.QueryInterface = typedActivationQueryInterfaceThunk
    vtbl.base_.Release = typedActivationReleaseThunk
    vtbl
}

func optionGuidEquals(value: Option<GUID>, expected: GUID): Bool {
    match (value) {
        case Some(actual) => actual == expected
        case None => false
    }
}

func bridgeKindIsValue(value: InterfaceParameterBridgeKind): Bool {
    match (value) {
        case InterfaceParameterBridgeKind.Value => true
        case _ => false
    }
}

func interfaceTestThrowsWindowsException(action: () -> Unit): Bool {
    try {
        action()
        false
    } catch (_: WindowsException) {
        true
    } catch (_: Exception) {
        false
    }
}

@Test
func testGuidSignatureIsDeterministicAndVersioned() {
    let first = GUID.from_signature("rc(Windows.Foundation.IAsyncAction;{5A648006-843A-4DA9-865B-9D26E5DFAD7B})")
    let second = GUID.from_signature("rc(Windows.Foundation.IAsyncAction;{5A648006-843A-4DA9-865B-9D26E5DFAD7B})")
    let different = GUID.from_signature("rc(Windows.Foundation.IAsyncOperation`1<String>;{9FC2B0BB-E446-44E2-AA61-9CAB8F636AF2})")

    @Expect(first == second, true)
    @Expect(first != different, true)
    @Expect(UInt16(first.data3 & 0xF000u16), 0x5000u16)
    @Expect(UInt8(first.data4[0] & 0xC0u8), 0x80u8)
}

@Test
func testInterfaceFromAbiTakeRejectsNullOwnedPointer() {
    @Expect(interfaceTestThrowsWindowsException({ =>
        let _ = IUnknown.fromAbiTake(CPointer<Unit>())
    }), true)

    @Expect(IUnknown.viewOf(CPointer<Unit>()).asRaw().isNull(), true)
}

@Test
func testGuidFromSignatureCanonicalizesGuidCase() {
    let lower = GUID.from_signature("pinterface({61c17706-2d65-11e0-9ae8-d48564015472};b1)")
    let upper = GUID.from_signature("pinterface({61C17706-2D65-11E0-9AE8-D48564015472};b1)")

    @Expect(upper == lower, true)
    @Expect(lower.toString(), "3C00FD60-2950-5939-A21A-2D12C5A01B8A")
}

@Test
func testGuidTryFromRejectsMalformedStrings() {
    @Expect(GUID.tryFrom("00112233-4455-6677-8899-AABBCCDDEEFF").isOk(), true)
    @Expect(GUID.tryFrom("00112233-4455-6677-8899-AABBCCDDEEF").isErr(), true)
    @Expect(GUID.tryFrom("00112233_4455-6677-8899-AABBCCDDEEFF").isErr(), true)
    @Expect(GUID.tryFrom("00112233-4455-6677-8899-AABBCCDDEEFG").isErr(), true)
}

@Test
func testInterfaceDescriptorMatchesOwnAndAncestorIids() {
    let baseIid = GUID.parse("00000001-0000-0000-C000-000000000046")
    let extraIid = GUID.parse("00000002-0000-0000-C000-000000000046")
    let ownIid = GUID.parse("00000003-0000-0000-C000-000000000046")
    let base = InterfaceDescriptor<CPointer<Unit>>(
        "IBase",
        baseIid,
        { raw => raw }
    )
    let descriptor = InterfaceDescriptor<CPointer<Unit>>(
        "IDerived",
        ownIid,
        base,
        [extraIid],
        { raw => raw },
        { raw => raw }
    )

    @Expect(descriptor.descriptorName(), "IDerived")
    @Expect(descriptor.matches(ownIid), true)
    @Expect(descriptor.matches(baseIid), true)
    @Expect(descriptor.matches(extraIid), true)
    @Expect(descriptor.matches(GUID_ZERO), false)
    @Expect(optionStringEquals(descriptor.descriptorDirectBaseName(), "IBase"), true)
}

@Test
func testActivationFactoryTypedActivateUsesDescriptorQueryAndReleasesInspectable() {
    resetTypedActivationTestState()
    let factoryVtblHandle = unsafe { allocateNativeValue<IActivationFactoryVtbl>(typedActivationFactoryVtbl()) }
    let factoryObjectHandle = unsafe { allocateNativeValue<CPointer<IActivationFactoryVtbl>>(factoryVtblHandle) }
    let objectVtblHandle = unsafe { allocateNativeValue<IInspectableVtbl>(typedActivationObjectVtbl()) }
    let objectHandle = unsafe { allocateNativeValue<CPointer<IInspectableVtbl>>(objectVtblHandle) }
    typedActivationRaw = CPointer<Unit>(objectHandle)
    typedActivationProjectedRaw = CPointer<Unit>(objectHandle)

    try {
        let factory = IActivationFactory.viewOf(CPointer<Unit>(factoryObjectHandle))
        let result = unsafe {
            factory.activateInstance<TypedActivationTestInterface>(TypedActivationTestInterface.descriptor())
        }
        match (result) {
            case Result<TypedActivationTestInterface>.Ok(value) =>
                @Expect(value.asRaw().toUIntNative(), CPointer<Unit>(objectHandle).toUIntNative())
                @Expect(typedActivationQueryCount.load(), 1)
                @Expect(typedActivationReleaseCount.load(), 1)
                value.close()
                @Expect(typedActivationReleaseCount.load(), 2)
            case Result<TypedActivationTestInterface>.Err(error) =>
                throw Exception("typed activation failed: ${error}")
        }
    } finally {
        unsafe {
            freeNativeValue<CPointer<IInspectableVtbl>>(objectHandle)
            freeNativeValue<IInspectableVtbl>(objectVtblHandle)
            freeNativeValue<CPointer<IActivationFactoryVtbl>>(factoryObjectHandle)
            freeNativeValue<IActivationFactoryVtbl>(factoryVtblHandle)
        }
        resetTypedActivationTestState()
    }
}

@Test
func testDescriptorSchemaDirectBaseAndMethodsStayAligned() {
    let baseIid = GUID.parse("00000010-0000-0000-C000-000000000046")
    let derivedIid = GUID.parse("00000011-0000-0000-C000-000000000046")
    let base = InterfaceDescriptorSchema(
        "IBase",
        baseIid,
        "IBaseVtbl",
        "IBase",
        "IBase_Impl",
        []
    )
    let parameter = InterfaceParameterSchema(
        "value",
        "Int32",
        "Int32",
        InterfaceParameterBridgeKind.Value
    )
    let derived = InterfaceDescriptorSchema(
        "IDerived",
        derivedIid,
        base,
        "IDerivedVtbl",
        "IDerived",
        "IDerived_Impl",
        [InterfaceMethodSchema("Put", 6, [parameter], "HRESULT")]
    )

    @Expect(optionStringEquals(derived.baseInterfaceName, "IBase"), true)
    @Expect(optionGuidEquals(derived.baseIid, baseIid), true)
    @Expect(derived.ancestorInterfaceNames.size, 1)
    @Expect(derived.ancestorIids[0] == baseIid, true)
    @Expect(bridgeKindIsValue(derived.methods[0].parameters[0].bridgeKind), true)
}
