package windows_core

import std.unittest.*
import std.unittest.testmacro.*

func coreTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

let CORE_REQUIRED_IID = GUID.parse("A1111111-1111-1111-1111-111111111111")
let CORE_OWNER_IID = GUID.parse("A2222222-2222-2222-2222-222222222222")

func takeCoreRequiredFromAbi(raw: CPointer<Unit>): CoreRequiredInterface {
    CoreRequiredInterface(raw, takeOwnership: true, allowManualRelease: true)
}

func viewCoreRequired(raw: CPointer<Unit>): CoreRequiredInterface {
    CoreRequiredInterface(raw, takeOwnership: false, allowManualRelease: false)
}

func takeCoreOwnerFromAbi(raw: CPointer<Unit>): CoreOwnerInterface {
    CoreOwnerInterface(raw, takeOwnership: true, allowManualRelease: true)
}

func viewCoreOwner(raw: CPointer<Unit>): CoreOwnerInterface {
    CoreOwnerInterface(raw, takeOwnership: false, allowManualRelease: false)
}

public open class CoreRequiredInterface <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func iid(): GUID {
        CORE_REQUIRED_IID
    }

    public static func fromAbiTake(raw: CPointer<Unit>): CoreRequiredInterface {
        takeCoreRequiredFromAbi(raw)
    }

    public static func viewOf(raw: CPointer<Unit>): CoreRequiredInterface {
        viewCoreRequired(raw)
    }

    public static func descriptor(): InterfaceDescriptor<CoreRequiredInterface> {
        InterfaceDescriptor<CoreRequiredInterface>(
            "CoreRequiredInterface",
            CORE_REQUIRED_IID,
            IUnknown.descriptor(),
            takeCoreRequiredFromAbi,
            viewCoreRequired
        )
    }
}

extend CoreRequiredInterface <: Interface<CoreRequiredInterface> {}

public open class CoreOwnerInterface <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func iid(): GUID {
        CORE_OWNER_IID
    }

    public static func fromAbiTake(raw: CPointer<Unit>): CoreOwnerInterface {
        takeCoreOwnerFromAbi(raw)
    }

    public static func viewOf(raw: CPointer<Unit>): CoreOwnerInterface {
        viewCoreOwner(raw)
    }

    public static func descriptor(): InterfaceDescriptor<CoreOwnerInterface> {
        InterfaceDescriptor<CoreOwnerInterface>(
            "CoreOwnerInterface",
            CORE_OWNER_IID,
            IInspectable.descriptor(),
            [CORE_REQUIRED_IID],
            takeCoreOwnerFromAbi,
            viewCoreOwner
        )
    }
}

extend CoreOwnerInterface <: Interface<CoreOwnerInterface> {}

@Test
func testGuidValueRoundTripAndInvalidParse() {
    let guid = GuidValue.from_values(
        0x00112233u32,
        0x4455u16,
        0x6677u16,
        0x88u8,
        0x99u8,
        0xAAu8,
        0xBBu8,
        0xCCu8,
        0xDDu8,
        0xEEu8,
        0xFFu8
    )
    let roundTrip = GuidValue.from_u128(guid.to_u128())

    @Expect(guid.isZero(), false)
    @Expect(roundTrip == guid, true)
    @Expect(guid.toString(), "00112233-4455-6677-8899-AABBCCDDEEFF")
    @Expect(GuidValue.fromString("00112233-4455-6677-8899-AABBCCDDEEFF").isSome(), true)
    @Expect(GuidValue.fromString("00112233-4455-6677-8899-AABBCCDDEEFZ").isNone(), true)
}

@Test
func testHResultConstantsExposeSuccessAndFailureBits() {
    @Expect(S_OK.value, 0i32)
    @Expect(S_FALSE.isOk(), true)
    @Expect(E_POINTER.isErr(), true)
    @Expect(E_POINTER.toString(), "0x80004003")
    @Expect(REGDB_E_CLASSNOTREG.value, -2147221164i32)
    @Expect(CO_E_NOTINITIALIZED.value, -2147221008i32)
}

@Test
func testIUnknownDescriptorAndNullAbiBasics() {
    let descriptor = IUnknown.descriptor()

    @Expect(descriptor.descriptorName(), "IUnknown")
    @Expect(descriptor.descriptorIid() == IUnknown.IID(), true)
    @Expect(descriptor.descriptorIid().toString(), "00000000-0000-0000-C000-000000000046")
    @Expect(IUnknown.UNKNOWN(), true)
    @Expect(IUnknown.abiType(), "pointer")
    @Expect(IUnknown.isNullAbi(CPointer<Unit>()), true)
    @Expect(IUnknown.fromAbi(CPointer<Unit>()).isErr(), true)
}

@Test
func testInterfaceDefaultSignatureUsesCanonicalGuidCase() {
    @Expect(CoreRequiredInterface.signature(), "{a1111111-1111-1111-1111-111111111111}")
}

@Test
func testQueryRequiredForUsesOnlyVtableBaseChain() {
    @Expect(queryRequiredFor<IUnknown, CoreOwnerInterface>(), false)
    @Expect(queryRequiredFor<IInspectable, CoreOwnerInterface>(), false)
    @Expect(queryRequiredFor<CoreRequiredInterface, CoreOwnerInterface>(), true)
}

@When[os == "Windows"]
@Test
func testHStringGenericOutBridgeUsesSystemHandleOwnership() {
    let createBefore = debugObservedWindowsCreateStringCount()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    let slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ =>
        winrtStoreGenericOut<HString>(result__, HString("generic"))
    }
    let projected = winrtCallGenericOut<HString>(slot, CPointer<Unit>())

    @Expect(projected.get(), "generic")
    @Expect(debugObservedWindowsCreateStringCount() > createBefore, true)
    @Expect(debugObservedWindowsDeleteStringCount() > deleteBefore, true)
    projected.close()
}

@When[os == "Windows"]
@Test
func testHStringGenericInputBridgeCopiesBorrowedSystemHandle() {
    let source = HString("input")
    let raw = source.toSystemHandleCopy()
    let projected = winrtProjectGenericIn<HString>(raw)
    let consumed = HString.fromSystemHandleTake(raw)

    @Expect(projected.get(), "input")
    @Expect(consumed.get(), "input")
    @Expect(source.get(), "input")

    consumed.close()
    projected.close()
    source.close()
}

@When[os == "Windows"]
@Test
func testHStringGenericInputBorrowPublishesSystemHandleCopy() {
    let source = HString("borrow-send")
    let sourceRaw = source.asRaw()
    let createBefore = debugObservedWindowsCreateStringCount()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    try (borrow = winrtBorrowGenericIn<HString>(source)) {
        let raw = borrow.asRaw()
        if (raw.toUIntNative() == sourceRaw.toUIntNative()) {
            throw Exception("HString generic input borrow must publish a system HSTRING copy")
        }
        @Expect(debugObservedWindowsCreateStringCount() > createBefore, true)
        let projected = HString.fromSystemHandleCopy(raw)
        @Expect(projected.get(), "borrow-send")
        projected.close()
    }
    @Expect(debugObservedWindowsDeleteStringCount() > deleteBefore, true)
    @Expect(source.get(), "borrow-send")
    source.close()
}

@When[os == "Windows"]
@Test
func testHStringIntoWinrtHandlePublishesSystemHandleCopy() {
    let source = HString("handle-copy")
    let createBefore = debugObservedWindowsCreateStringCount()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    let raw = HString.intoWinrtHandle(source)
    @Expect(raw.isNotNull(), true)
    @Expect(debugObservedWindowsCreateStringCount() > createBefore, true)
    let projected = HString.fromSystemHandleTake(raw)

    @Expect(projected.get(), "handle-copy")
    @Expect(debugObservedWindowsDeleteStringCount() > deleteBefore, true)

    projected.close()
    source.close()
}

@When[os == "Windows"]
@Test
func testHStringInParamBorrowRejectsRawAbiProjection() {
    let source = HString("borrow")
    @Expect(coreTestThrows({ =>
        let _ = InParam<HString>(source).borrow<CPointer<Unit>>()
    }), true)
    source.close()
}

@When[os == "Windows"]
@Test
func testWithHStringInParamClosesCopiedInput() {
    let source = HString("dispatch-input")
    let raw = source.toSystemHandleCopy()
    let freeBefore = debugObservedHStringFreeCount()

    try {
        let value = withHStringInParam(raw, { param =>
            if (param.isNull()) {
                throw Exception("expected non-null HString input")
            }
            param.get().get()
        })

        @Expect(value, "dispatch-input")
        @Expect(debugObservedHStringFreeCount() - freeBefore, 1)
    } finally {
        releaseSystemHStringHandle(raw)
        source.close()
    }
}
