package windows_core

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_implement.{comRegistryInsert, comRegistryRemove}
import windows_interface as windows_interface

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
let coreQueryFailureReleaseCount = AtomicInt64(0)
var coreQueryFailurePartialRaw = CPointer<Unit>()
let weakOwnerAddRefCount = AtomicInt64(0)
let weakOwnerReleaseCount = AtomicInt64(0)
let weakPartialReleaseCount = AtomicInt64(0)
var weakOwnerPartialRaw = CPointer<Unit>()
let reentrantInterfaceHandleReleaseCount = AtomicInt64(0)
var reentrantInterfaceHandleValue: Option<InterfaceHandle<IUnknown>> = None
let reentrantTearOffReleaseCount = AtomicInt64(0)
var reentrantTearOffValue: Option<TearOff<IUnknown>> = None
let reentrantMarshalerHandleReleaseCount = AtomicInt64(0)
var reentrantMarshalerHandleValue: Option<LocalAggregatedMarshalerHandle> = None
let reentrantFailedComOutSlotReleaseCount = AtomicInt64(0)
var reentrantFailedComOutSlotValue = CPointer<CPointer<Unit>>()
let reentrantGenericOutRangeReleaseCount = AtomicInt64(0)
var reentrantGenericOutRangeBuffer = CPointer<Unit>()

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

class CoreThrowingInspectableImpl <: IInspectableImpl {
    public var returnFailedIids: Bool = false
    public var throwWindowsIids: Bool = false
    public var throwWindowsRuntimeClassName: Bool = false
    public var throwPlainRuntimeClassName: Bool = false
    public var throwWindowsTrustLevel: Bool = false
    public var throwPlainTrustLevel: Bool = false
    public var partialIidsRaw = CPointer<Unit>()
    public var partialRuntimeClassNameRaw = CPointer<Unit>()

    public func getImpl<T>(): Option<T> {
        None
    }

    public func getImplMut<T>(): Option<T> {
        None
    }

    public func intoInner<T>(): Option<T> {
        None
    }

    public func addRefBase(): UInt32 {
        AddRef()
    }

    public func releaseBase(identityKey: UIntNative): UInt32 {
        let _ = identityKey
        Release()
    }

    public func queryInterfaceBase(
        raw: CPointer<Unit>,
        iid: GUID,
        resultSlot: CPointer<CPointer<Unit>>
    ): Int32 {
        let _ = raw
        QueryInterface(iid, resultSlot)
    }

    public func QueryInterface(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        let _ = iid
        if (resultSlot.isNotNull()) {
            unsafe { resultSlot.write(CPointer<Unit>()) }
        }
        E_NOINTERFACE.value
    }

    public func AddRef(): UInt32 {
        1u32
    }

    public func Release(): UInt32 {
        1u32
    }

    public func isReferenceCountOne(): Bool {
        true
    }

    public func GetTrustLevel(value: CPointer<Int32>): Int32 {
        getTrustLevelBase(value)
    }

    public func asInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        let _ = descriptor
        throw Exception("CoreThrowingInspectableImpl.asInterface is not supported")
    }

    public func toInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        let _ = descriptor
        throw Exception("CoreThrowingInspectableImpl.toInterface is not supported")
    }

    public func toObject<T>(): ComObject<T> {
        throw Exception("CoreThrowingInspectableImpl.toObject is not supported")
    }

    public func getIidsBase(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): Int32 {
        let raw = coTaskMemAlloc(sizeOf<GUID>())
        partialIidsRaw = raw
        unsafe {
            if (raw.isNotNull()) {
                CPointer<GUID>(raw).write(windows_interface.IID_IINSPECTABLE)
                count.write(1u32)
                values.write(CPointer<GUID>(raw))
            }
        }
        if (returnFailedIids) {
            return E_FAIL.value
        }
        if (throwWindowsIids) {
            throw WindowsException(E_POINTER)
        }
        throw Exception("core GetIids failure")
    }

    public func getRuntimeClassNameBase(value: CPointer<CPointer<Unit>>): Int32 {
        if (value.isNotNull()) {
            let source = HString("core-partial-runtime-class-thunk")
            let raw = source.toSystemHandleCopy()
            source.close()
            partialRuntimeClassNameRaw = raw
            unsafe { value.write(raw) }
        }
        if (throwWindowsRuntimeClassName) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainRuntimeClassName) {
            throw Exception("core GetRuntimeClassName failure")
        }
        E_NOTIMPL.value
    }

    public func getTrustLevelBase(value: CPointer<Int32>): Int32 {
        if (value.isNotNull()) {
            unsafe { value.write(77i32) }
        }
        if (throwWindowsTrustLevel) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainTrustLevel) {
            throw Exception("core GetTrustLevel failure")
        }
        E_NOTIMPL.value
    }
}

class ThrowingCoreAgileReferenceImpl <: IAgileReference_Impl {
    public var throwWindows: Bool = false
    public var throwPlain: Bool = false
    public var partialRaw: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public func Resolve(riid: CPointer<GUID>, ppvobjectreference: CPointer<CPointer<Unit>>): Result<Unit> {
        let _ = riid
        if (ppvobjectreference.isNotNull()) {
            unsafe { ppvobjectreference.write(partialRaw) }
        }
        if (throwWindows) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlain) {
            throw Exception("agile reference resolve failure")
        }
        Result<Unit>.Err(WinError.fromHRESULT(E_FAIL))
    }
}

class ThrowingCoreWeakReferenceImpl <: IWeakReference_Impl {
    public var throwWindows: Bool = false
    public var throwPlain: Bool = false
    public var partialRaw: CPointer<Unit> = CPointer<Unit>()

    public init() {}

    public func Resolve(riid: CPointer<GUID>, objectreference: CPointer<CPointer<Unit>>): Result<Unit> {
        let _ = riid
        if (objectreference.isNotNull()) {
            unsafe { objectreference.write(partialRaw) }
        }
        if (throwWindows) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlain) {
            throw Exception("weak reference resolve failure")
        }
        Result<Unit>.Err(WinError.fromHRESULT(E_FAIL))
    }
}

class ThrowingCoreWeakReferenceSourceImpl <: IWeakReferenceSource_Impl {
    public var throwWindows: Bool = false
    public var throwPlain: Bool = false

    public init() {}

    public func GetWeakReference(): Result<IWeakReference> {
        if (throwWindows) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlain) {
            throw Exception("weak reference source failure")
        }
        Result<IWeakReference>.Err(WinError.fromHRESULT(E_FAIL))
    }
}

@C
func coreQueryFailureQueryInterfaceThunk(
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (!result.isNull()) {
        unsafe { result.write(coreQueryFailurePartialRaw) }
    }
    E_FAIL.value
}

@C
func coreQueryFailureReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = coreQueryFailureReleaseCount.fetchAdd(1)
    UInt32(previous + 1)
}

@C
func weakOwnerQueryFailureThunk(
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    unsafe { result.write(weakOwnerPartialRaw) }
    E_FAIL.value
}

@C
func weakOwnerNoWriteQueryFailureThunk(
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    let _ = result
    E_FAIL.value
}

@C
func weakOwnerAddRefThunk(_: CPointer<Unit>): UInt32 {
    let previous = weakOwnerAddRefCount.fetchAdd(1)
    UInt32(previous + 1)
}

@C
func weakOwnerReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = weakOwnerReleaseCount.fetchAdd(1)
    UInt32(previous + 1)
}

@C
func weakPartialReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = weakPartialReleaseCount.fetchAdd(1)
    UInt32(previous + 1)
}

@C
func reentrantInterfaceHandleReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = reentrantInterfaceHandleReleaseCount.fetchAdd(1)
    if (previous == 0) {
        match (reentrantInterfaceHandleValue) {
            case Some(handle) => handle.close()
            case None => ()
        }
    }
    UInt32(previous + 1)
}

@C
func reentrantTearOffReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = reentrantTearOffReleaseCount.fetchAdd(1)
    if (previous == 0) {
        match (reentrantTearOffValue) {
            case Some(handle) => handle.close()
            case None => ()
        }
    }
    UInt32(previous + 1)
}

@C
func reentrantMarshalerHandleReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = reentrantMarshalerHandleReleaseCount.fetchAdd(1)
    if (previous == 0) {
        match (reentrantMarshalerHandleValue) {
            case Some(handle) => handle.close()
            case None => ()
        }
    }
    UInt32(previous + 1)
}

@C
func reentrantFailedComOutSlotReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = reentrantFailedComOutSlotReleaseCount.fetchAdd(1)
    if (previous == 0) {
        releaseFailedComOutSlot(reentrantFailedComOutSlotValue)
    }
    UInt32(previous + 1)
}

@C
func reentrantGenericOutRangeReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = reentrantGenericOutRangeReleaseCount.fetchAdd(1)
    if (previous == 0) {
        winrtReleaseGenericOutRange<IInspectable>(reentrantGenericOutRangeBuffer, 1u32)
    }
    UInt32(previous + 1)
}

func coreQueryFailureVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.QueryInterface = coreQueryFailureQueryInterfaceThunk
    vtbl.Release = coreQueryFailureReleaseThunk
    vtbl
}

func weakOwnerFailureVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.QueryInterface = weakOwnerQueryFailureThunk
    vtbl.AddRef = weakOwnerAddRefThunk
    vtbl.Release = weakOwnerReleaseThunk
    vtbl
}

func weakOwnerNoWriteFailureVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.QueryInterface = weakOwnerNoWriteQueryFailureThunk
    vtbl.AddRef = weakOwnerAddRefThunk
    vtbl.Release = weakOwnerReleaseThunk
    vtbl
}

func weakPartialVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = weakPartialReleaseThunk
    vtbl
}

func reentrantInterfaceHandleVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = reentrantInterfaceHandleReleaseThunk
    vtbl
}

func reentrantTearOffVtbl(): IWeakReferenceVtbl {
    var vtbl = IWeakReferenceVtbl()
    vtbl.base_.Release = reentrantTearOffReleaseThunk
    vtbl
}

func reentrantMarshalerHandleVtbl(): IMarshalVtbl {
    var vtbl = IMarshalVtbl()
    vtbl.base_.Release = reentrantMarshalerHandleReleaseThunk
    vtbl
}

func reentrantFailedComOutSlotVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = reentrantFailedComOutSlotReleaseThunk
    vtbl
}

func reentrantGenericOutRangeVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = reentrantGenericOutRangeReleaseThunk
    vtbl
}

func resetCoreQueryFailureState(): Unit {
    coreQueryFailureReleaseCount.store(0)
    coreQueryFailurePartialRaw = CPointer<Unit>()
}

func resetReentrantInterfaceHandleState(): Unit {
    reentrantInterfaceHandleReleaseCount.store(0)
    reentrantInterfaceHandleValue = None
}

func resetReentrantWeakHandleState(): Unit {
    reentrantTearOffReleaseCount.store(0)
    reentrantTearOffValue = None
    reentrantMarshalerHandleReleaseCount.store(0)
    reentrantMarshalerHandleValue = None
}

func resetReentrantFailedComOutSlotState(): Unit {
    reentrantFailedComOutSlotReleaseCount.store(0)
    reentrantFailedComOutSlotValue = CPointer<CPointer<Unit>>()
}

func resetReentrantGenericOutRangeState(): Unit {
    reentrantGenericOutRangeReleaseCount.store(0)
    reentrantGenericOutRangeBuffer = CPointer<Unit>()
}

func resetWeakOwnerFailureState(): Unit {
    weakOwnerAddRefCount.store(0)
    weakOwnerReleaseCount.store(0)
    weakPartialReleaseCount.store(0)
    weakOwnerPartialRaw = CPointer<Unit>()
}

func withCoreQueryFailureRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(coreQueryFailureVtbl()) }
    let sourceHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    let partialHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    coreQueryFailurePartialRaw = CPointer<Unit>(partialHandle)

    try {
        action(CPointer<Unit>(sourceHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(sourceHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(vtblHandle)
        }
        resetCoreQueryFailureState()
    }
}

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
func testInterfaceHandleCloseIsReleaseReentrantSafe() {
    resetReentrantInterfaceHandleState()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(reentrantInterfaceHandleVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    let handle = InterfaceHandle<IUnknown>.fromAbiTake(CPointer<Unit>(objectHandle), IUnknown.descriptor())
    reentrantInterfaceHandleValue = Some(handle)
    try {
        handle.close()
        @Expect(handle.isClosed(), true)
        @Expect(reentrantInterfaceHandleReleaseCount.load(), 1)
    } finally {
        reentrantInterfaceHandleValue = None
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(objectHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(vtblHandle)
        }
    }
}

@Test
func testWeakTearOffCloseIsReleaseReentrantSafe() {
    resetReentrantWeakHandleState()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IWeakReferenceVtbl>(reentrantTearOffVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IWeakReferenceVtbl>>(vtblHandle) }
    let weakReference = IWeakReference.fromAbiTake(CPointer<Unit>(objectHandle))
    let tearOff = TearOff<IUnknown>(IUnknown.descriptor(), weakReference)
    reentrantTearOffValue = Some(tearOff)
    try {
        tearOff.close()
        @Expect(tearOff.isClosed(), true)
        @Expect(reentrantTearOffReleaseCount.load(), 1)
    } finally {
        reentrantTearOffValue = None
        unsafe {
            windows_interface.freeNativeValue<CPointer<IWeakReferenceVtbl>>(objectHandle)
            windows_interface.freeNativeValue<IWeakReferenceVtbl>(vtblHandle)
        }
    }
}

@Test
func testLocalAggregatedMarshalerCloseIsReleaseReentrantSafe() {
    resetReentrantWeakHandleState()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IMarshalVtbl>(reentrantMarshalerHandleVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IMarshalVtbl>>(vtblHandle) }
    let marshaler = IMarshal.fromAbiTake(CPointer<Unit>(objectHandle))
    let handle = LocalAggregatedMarshalerHandle(marshaler)
    reentrantMarshalerHandleValue = Some(handle)
    try {
        handle.close()
        @Expect(handle.isClosed(), true)
        @Expect(reentrantMarshalerHandleReleaseCount.load(), 1)
    } finally {
        reentrantMarshalerHandleValue = None
        unsafe {
            windows_interface.freeNativeValue<CPointer<IMarshalVtbl>>(objectHandle)
            windows_interface.freeNativeValue<IMarshalVtbl>(vtblHandle)
        }
    }
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

@Test
func testQueryInterfaceResultReleasesPartialOutputOnFailedHRESULT() {
    resetCoreQueryFailureState()
    withCoreQueryFailureRaw({ sourceRaw: CPointer<Unit> =>
        let result = unsafe { queryInterfaceResult<CoreRequiredInterface>(sourceRaw, CoreRequiredInterface.descriptor()) }
        match (result) {
            case QueryResult<InterfaceHandle<CoreRequiredInterface>>.Ok(handle) =>
                handle.close()
                throw Exception("queryInterfaceResult unexpectedly succeeded")
            case QueryResult<InterfaceHandle<CoreRequiredInterface>>.Err(hr) =>
                @Expect(hr, E_FAIL)
        }
        @Expect(coreQueryFailureReleaseCount.load(), 1)
    })
}

@Test
func testCastPreservesFailedQueryInterfaceHRESULT() {
    resetCoreQueryFailureState()
    withCoreQueryFailureRaw({ sourceRaw: CPointer<Unit> =>
        let source = CoreOwnerInterface.viewOf(sourceRaw)
        let result = unsafe { cast<CoreOwnerInterface, CoreRequiredInterface>(source, CoreRequiredInterface.descriptor()) }
        match (result) {
            case Result<CoreRequiredInterface>.Ok(value) =>
                value.close()
                throw Exception("cast unexpectedly succeeded")
            case Result<CoreRequiredInterface>.Err(error) =>
                @Expect(error.code(), E_FAIL)
        }
        @Expect(coreQueryFailureReleaseCount.load(), 1)
    })
}

@Test
func testAgileReferenceFromRoGetResultReleasesPartialOutputOnFailedHRESULT() {
    resetCoreQueryFailureState()
    withCoreQueryFailureRaw({ sourceRaw: CPointer<Unit> =>
        let _ = sourceRaw
        let result = AgileReference<CoreRequiredInterface>.fromRoGetResult(
            CoreRequiredInterface.descriptor(),
            E_FAIL,
            coreQueryFailurePartialRaw
        )
        match (result) {
            case Result<AgileReference<CoreRequiredInterface>>.Ok(reference) =>
                reference.close()
                throw Exception("AgileReference.fromRoGetResult unexpectedly succeeded")
            case Result<AgileReference<CoreRequiredInterface>>.Err(error) =>
                @Expect(error.code(), E_FAIL)
        }
        @Expect(coreQueryFailureReleaseCount.load(), 1)
    })
}

@Test
func testEventEntryFromAgileReferenceResultReleasesPartialOutputOnFailedHRESULT() {
    resetCoreQueryFailureState()
    withCoreQueryFailureRaw({ sourceRaw: CPointer<Unit> =>
        let _ = sourceRaw
        let result = eventEntryFromRoGetAgileReferenceResult<CoreRequiredInterface>(
            CoreRequiredInterface.descriptor(),
            E_FAIL,
            coreQueryFailurePartialRaw
        )
        match (result) {
            case Result<EventEntry<CoreRequiredInterface>>.Ok(entry) =>
                entry.close()
                throw Exception("eventEntryFromRoGetAgileReferenceResult unexpectedly succeeded")
            case Result<EventEntry<CoreRequiredInterface>>.Err(error) =>
                @Expect(error.code(), E_FAIL)
        }
        @Expect(coreQueryFailureReleaseCount.load(), 1)
    })
}

@Test
func testFactoryActivationHelperReleasesPartialOutputOnFailedHRESULT() {
    resetCoreQueryFailureState()
    withCoreQueryFailureRaw({ sourceRaw: CPointer<Unit> =>
        let _ = sourceRaw
        let result = activationFactoryFromRaw<CoreRequiredInterface>(
            coreQueryFailurePartialRaw,
            E_FAIL,
            CoreRequiredInterface.descriptor()
        )
        match (result) {
            case Result<CoreRequiredInterface>.Ok(value) =>
                value.close()
                throw Exception("activationFactoryFromRaw unexpectedly succeeded")
            case Result<CoreRequiredInterface>.Err(error) =>
                @Expect(error.code(), E_FAIL)
        }
        @Expect(coreQueryFailureReleaseCount.load(), 1)
    })
}

@Test
func testFailedComOutSlotReleaseClearsPartialOutput() {
    resetCoreQueryFailureState()
    withCoreQueryFailureRaw({ sourceRaw: CPointer<Unit> =>
        let _ = sourceRaw
        var raw = coreQueryFailurePartialRaw
        releaseFailedComOutSlot(CPointer<CPointer<Unit>>(inout raw))
        @Expect(raw.isNull(), true)
        @Expect(coreQueryFailureReleaseCount.load(), 1)
    })
}

@Test
func testFailedComOutSlotReleaseIsReentrantSafe() {
    resetReentrantFailedComOutSlotState()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(reentrantFailedComOutSlotVtbl()) }
    let rawHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    var raw = CPointer<Unit>(rawHandle)
    reentrantFailedComOutSlotValue = CPointer<CPointer<Unit>>(inout raw)

    try {
        releaseFailedComOutSlot(reentrantFailedComOutSlotValue)
        @Expect(raw.isNull(), true)
        @Expect(reentrantFailedComOutSlotReleaseCount.load(), 1)
    } finally {
        resetReentrantFailedComOutSlotState()
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(rawHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(vtblHandle)
        }
    }
}

@Test
func testWinrtGenericOutRangeReleaseIsReentrantSafe() {
    resetReentrantGenericOutRangeState()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(reentrantGenericOutRangeVtbl()) }
    let rawHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(vtblHandle) }
    let buffer = coTaskMemAlloc(sizeOf<CPointer<Unit>>())
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe { slots.write(CPointer<Unit>(rawHandle)) }
    reentrantGenericOutRangeBuffer = buffer

    try {
        winrtReleaseGenericOutRange<IInspectable>(buffer, 1u32)
        @Expect(unsafe { slots.read() }.isNull(), true)
        @Expect(reentrantGenericOutRangeReleaseCount.load(), 1)
    } finally {
        resetReentrantGenericOutRangeState()
        coTaskMemFree(buffer)
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(rawHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(vtblHandle)
        }
    }
}

@When[os == "Windows"]
@Test
func testFailedRuntimeClassNameSlotReleasesPartialSystemHandle() {
    let source = HString("core-partial-runtime-class")
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    var raw = source.toSystemHandleCopy()

    let hr = releaseFailedRuntimeClassNameSlot(E_FAIL.value, CPointer<CPointer<Unit>>(inout raw))

    @Expect(hr, E_FAIL.value)
    @Expect(raw.isNull(), true)
    @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
    source.close()
}

@When[os == "Windows"]
@Test
func testCoreIInspectableGetIidsThunkReleasesPartialIidArrayOnFailedHRESULT() {
    let probe = CoreThrowingInspectableImpl()
    probe.returnFailedIids = true
    let raw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x7711) }
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        var count = 123u32
        var iids = CPointer<GUID>()
        let hr = unsafe {
            coreIInspectableGetIidsThunk(
                raw,
                CPointer<UInt32>(inout count),
                CPointer<CPointer<GUID>>(inout iids)
            )
        }

        @Expect(hr, E_FAIL.value)
        @Expect(count, 0u32)
        @Expect(iids.isNull(), true)
        @Expect(probe.partialIidsRaw.isNotNull(), true)
        @Expect(coTaskMemAllocationSize(probe.partialIidsRaw).isNone(), true)
    } finally {
        comRegistryRemove(raw.toUIntNative())
    }
}

@When[os == "Windows"]
@Test
func testCoreIInspectableGetIidsThunkReleasesPartialIidArrayOnThrownException() {
    let probe = CoreThrowingInspectableImpl()
    probe.throwWindowsIids = true
    let raw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x7721) }
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        var count = 123u32
        var iids = CPointer<GUID>()
        let hr = unsafe {
            coreIInspectableGetIidsThunk(
                raw,
                CPointer<UInt32>(inout count),
                CPointer<CPointer<GUID>>(inout iids)
            )
        }

        @Expect(hr, E_POINTER.value)
        @Expect(count, 0u32)
        @Expect(iids.isNull(), true)
        @Expect(probe.partialIidsRaw.isNotNull(), true)
        @Expect(coTaskMemAllocationSize(probe.partialIidsRaw).isNone(), true)
    } finally {
        comRegistryRemove(raw.toUIntNative())
    }
}

@When[os == "Windows"]
@Test
func testCoreIInspectableGetRuntimeClassNameThunkReleasesPartialHandleOnThrownWindowsException() {
    let probe = CoreThrowingInspectableImpl()
    probe.throwWindowsRuntimeClassName = true
    let raw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x7731) }
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        let deleteBefore = debugObservedWindowsDeleteStringCount()
        var nameRaw = CPointer<Unit>()
        let hr = unsafe {
            coreIInspectableGetRuntimeClassNameThunk(
                raw,
                CPointer<CPointer<Unit>>(inout nameRaw)
            )
        }

        @Expect(hr, E_POINTER.value)
        @Expect(nameRaw.isNull(), true)
        @Expect(probe.partialRuntimeClassNameRaw.isNotNull(), true)
        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
    } finally {
        comRegistryRemove(raw.toUIntNative())
    }
}

@When[os == "Windows"]
@Test
func testCoreIInspectableGetRuntimeClassNameThunkReleasesPartialHandleOnThrownPlainException() {
    let probe = CoreThrowingInspectableImpl()
    probe.throwPlainRuntimeClassName = true
    let raw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x7741) }
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        let deleteBefore = debugObservedWindowsDeleteStringCount()
        var nameRaw = CPointer<Unit>()
        let hr = unsafe {
            coreIInspectableGetRuntimeClassNameThunk(
                raw,
                CPointer<CPointer<Unit>>(inout nameRaw)
            )
        }

        @Expect(hr, E_FAIL.value)
        @Expect(nameRaw.isNull(), true)
        @Expect(probe.partialRuntimeClassNameRaw.isNotNull(), true)
        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
    } finally {
        comRegistryRemove(raw.toUIntNative())
    }
}

@Test
func testCoreIInspectableGetTrustLevelThunkTranslatesExceptionsAndClearsOutSlot() {
    let windowsProbe = CoreThrowingInspectableImpl()
    windowsProbe.throwWindowsTrustLevel = true
    let windowsRaw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x7751) }
    comRegistryInsert(windowsRaw.toUIntNative(), windowsProbe)

    try {
        var trustLevel = 77i32
        let hr = unsafe {
            coreIInspectableGetTrustLevelThunk(windowsRaw, CPointer<Int32>(inout trustLevel))
        }
        @Expect(hr, E_POINTER.value)
        @Expect(trustLevel, 0i32)
    } finally {
        comRegistryRemove(windowsRaw.toUIntNative())
    }

    let plainProbe = CoreThrowingInspectableImpl()
    plainProbe.throwPlainTrustLevel = true
    let plainRaw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x7761) }
    comRegistryInsert(plainRaw.toUIntNative(), plainProbe)

    try {
        var trustLevel = 77i32
        let hr = unsafe {
            coreIInspectableGetTrustLevelThunk(plainRaw, CPointer<Int32>(inout trustLevel))
        }
        @Expect(hr, E_FAIL.value)
        @Expect(trustLevel, 0i32)
    } finally {
        comRegistryRemove(plainRaw.toUIntNative())
    }
}

@Test
func testWeakReferenceSourceQueryInterfaceReleasesFailedOwnerPartialOutput() {
    resetWeakOwnerFailureState()
    let ownerVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakOwnerFailureVtbl()) }
    let ownerHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(ownerVtblHandle) }
    let partialVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakPartialVtbl()) }
    let partialHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(partialVtblHandle) }
    weakOwnerPartialRaw = CPointer<Unit>(partialHandle)
    let weak = WeakRefCount.new(raw: CPointer<Unit>(ownerHandle))
    var sourceRaw = CPointer<Unit>()

    try {
        let hr = weak.writeWeakReferenceSource(CPointer<CPointer<Unit>>(inout sourceRaw))
        @Expect(hr, S_OK.value)
        @Expect(sourceRaw.isNotNull(), true)

        var resultRaw = CPointer<Unit>()
        var iid = CORE_OWNER_IID
        let sourceVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(sourceRaw).read() }
        let sourceVtbl = unsafe { sourceVtblPtr.read() }
        let queryHr = unsafe {
            sourceVtbl.base_.QueryInterface(
                sourceRaw,
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }

        @Expect(queryHr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(weakPartialReleaseCount.load(), 1)
    } finally {
        if (sourceRaw.isNotNull()) {
            let sourceVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(sourceRaw).read() }
            let sourceVtbl = unsafe { sourceVtblPtr.read() }
            let _ = unsafe { sourceVtbl.base_.Release(sourceRaw) }
        }
        weak.onObjectDestroyed()
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(partialVtblHandle)
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(ownerHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(ownerVtblHandle)
        }
        resetWeakOwnerFailureState()
    }
}

@Test
func testWeakReferenceSourceQueryInterfaceClearsStaleOutputBeforeNoWriteOwnerFailure() {
    resetWeakOwnerFailureState()
    let ownerVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakOwnerNoWriteFailureVtbl()) }
    let ownerHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(ownerVtblHandle) }
    let staleVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakPartialVtbl()) }
    let staleHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    let weak = WeakRefCount.new(raw: CPointer<Unit>(ownerHandle))
    var sourceRaw = CPointer<Unit>()

    try {
        let sourceHr = weak.writeWeakReferenceSource(CPointer<CPointer<Unit>>(inout sourceRaw))
        @Expect(sourceHr, S_OK.value)
        @Expect(sourceRaw.isNotNull(), true)

        var resultRaw = CPointer<Unit>(staleHandle)
        var iid = CORE_OWNER_IID
        let sourceVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(sourceRaw).read() }
        let sourceVtbl = unsafe { sourceVtblPtr.read() }
        let queryHr = unsafe {
            sourceVtbl.base_.QueryInterface(
                sourceRaw,
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }

        @Expect(queryHr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(weakPartialReleaseCount.load(), 0)
    } finally {
        if (sourceRaw.isNotNull()) {
            let sourceVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(sourceRaw).read() }
            let sourceVtbl = unsafe { sourceVtblPtr.read() }
            let _ = unsafe { sourceVtbl.base_.Release(sourceRaw) }
        }
        weak.onObjectDestroyed()
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(staleVtblHandle)
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(ownerHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(ownerVtblHandle)
        }
        resetWeakOwnerFailureState()
    }
}

@Test
func testCoreWeakReferenceResolveClearsStaleOutputBeforeNoWriteOwnerFailure() {
    resetWeakOwnerFailureState()
    let ownerVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakOwnerNoWriteFailureVtbl()) }
    let ownerHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(ownerVtblHandle) }
    let staleVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakPartialVtbl()) }
    let staleHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    let weak = WeakRefCount.new(raw: CPointer<Unit>(ownerHandle))
    var sourceRaw = CPointer<Unit>()
    var weakRaw = CPointer<Unit>()

    try {
        let sourceHr = weak.writeWeakReferenceSource(CPointer<CPointer<Unit>>(inout sourceRaw))
        @Expect(sourceHr, S_OK.value)
        @Expect(sourceRaw.isNotNull(), true)

        let sourceVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(sourceRaw).read() }
        let sourceVtbl = unsafe { sourceVtblPtr.read() }
        let weakHr = unsafe { sourceVtbl.GetWeakReference(sourceRaw, CPointer<CPointer<Unit>>(inout weakRaw)) }
        @Expect(weakHr, S_OK.value)
        @Expect(weakRaw.isNotNull(), true)

        var resultRaw = CPointer<Unit>(staleHandle)
        var iid = CORE_OWNER_IID
        let weakVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceVtbl>>(weakRaw).read() }
        let weakVtbl = unsafe { weakVtblPtr.read() }
        let resolveHr = unsafe {
            weakVtbl.Resolve(
                weakRaw,
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }

        @Expect(resolveHr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(weakPartialReleaseCount.load(), 0)
    } finally {
        if (weakRaw.isNotNull()) {
            let weakVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceVtbl>>(weakRaw).read() }
            let weakVtbl = unsafe { weakVtblPtr.read() }
            let _ = unsafe { weakVtbl.base_.Release(weakRaw) }
        }
        if (sourceRaw.isNotNull()) {
            let sourceVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(sourceRaw).read() }
            let sourceVtbl = unsafe { sourceVtblPtr.read() }
            let _ = unsafe { sourceVtbl.base_.Release(sourceRaw) }
        }
        weak.onObjectDestroyed()
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(staleVtblHandle)
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(ownerHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(ownerVtblHandle)
        }
        resetWeakOwnerFailureState()
    }
}

@Test
func testCoreAgileReferenceResolveThunkCleansThrownPartialOutputs() {
    resetWeakOwnerFailureState()
    let agileVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IAgileReferenceVtbl>(newIAgileReferenceVtbl<ThrowingCoreAgileReferenceImpl>())
    }
    let partialVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakPartialVtbl()) }
    let partialHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(partialVtblHandle) }
    let impl = ThrowingCoreAgileReferenceImpl()
    impl.partialRaw = CPointer<Unit>(partialHandle)
    let object = createComObject(impl, [IID_IAGILEREFERENCE], CPointer<Unit>(agileVtblHandle))
    let reference = object.toInterface(IAgileReference.descriptor())

    try {
        let raw = reference.asRaw()
        let vtblPtr = unsafe { CPointer<CPointer<IAgileReferenceVtbl>>(raw).read() }
        let vtbl = unsafe { vtblPtr.read() }
        var iid = IID_IUNKNOWN

        impl.throwWindows = true
        var resultRaw = CPointer<Unit>()
        let windowsHr = unsafe {
            vtbl.Resolve(raw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout resultRaw))
        }
        @Expect(windowsHr, E_POINTER.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(weakPartialReleaseCount.load(), 1)
        impl.throwWindows = false

        impl.throwPlain = true
        iid = IID_IUNKNOWN
        resultRaw = CPointer<Unit>()
        let plainHr = unsafe {
            vtbl.Resolve(raw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout resultRaw))
        }
        @Expect(plainHr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(weakPartialReleaseCount.load(), 2)
        impl.throwPlain = false
    } finally {
        reference.close()
        object.close()
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(partialVtblHandle)
            windows_interface.freeNativeValue<IAgileReferenceVtbl>(agileVtblHandle)
        }
        resetWeakOwnerFailureState()
    }
}

@Test
func testCoreWeakReferenceResolveThunkCleansThrownPartialOutputs() {
    resetWeakOwnerFailureState()
    let weakVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IWeakReferenceVtbl>(newIWeakReferenceVtbl<ThrowingCoreWeakReferenceImpl>())
    }
    let partialVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(weakPartialVtbl()) }
    let partialHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(partialVtblHandle) }
    let impl = ThrowingCoreWeakReferenceImpl()
    impl.partialRaw = CPointer<Unit>(partialHandle)
    let object = createComObject(impl, [IID_IWEAKREFERENCE], CPointer<Unit>(weakVtblHandle))
    let reference = object.toInterface(IWeakReference.descriptor())

    try {
        let raw = reference.asRaw()
        let vtblPtr = unsafe { CPointer<CPointer<IWeakReferenceVtbl>>(raw).read() }
        let vtbl = unsafe { vtblPtr.read() }
        var iid = IID_IUNKNOWN

        impl.throwWindows = true
        var resultRaw = CPointer<Unit>()
        let windowsHr = unsafe {
            vtbl.Resolve(raw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout resultRaw))
        }
        @Expect(windowsHr, E_POINTER.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(weakPartialReleaseCount.load(), 1)
        impl.throwWindows = false

        impl.throwPlain = true
        iid = IID_IUNKNOWN
        resultRaw = CPointer<Unit>()
        let plainHr = unsafe {
            vtbl.Resolve(raw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout resultRaw))
        }
        @Expect(plainHr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(weakPartialReleaseCount.load(), 2)
        impl.throwPlain = false
    } finally {
        reference.close()
        object.close()
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(partialVtblHandle)
            windows_interface.freeNativeValue<IWeakReferenceVtbl>(weakVtblHandle)
        }
        resetWeakOwnerFailureState()
    }
}

@Test
func testCoreWeakReferenceSourceThunkTranslatesThrownExceptions() {
    let sourceVtblHandle = unsafe {
        windows_interface.allocateNativeValue<IWeakReferenceSourceVtbl>(
            newIWeakReferenceSourceVtbl<ThrowingCoreWeakReferenceSourceImpl>()
        )
    }
    let impl = ThrowingCoreWeakReferenceSourceImpl()
    let object = createComObject(impl, [IID_IWEAKREFERENCESOURCE], CPointer<Unit>(sourceVtblHandle))
    let source = object.toInterface(IWeakReferenceSource.descriptor())

    try {
        let raw = source.asRaw()
        let vtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(raw).read() }
        let vtbl = unsafe { vtblPtr.read() }

        impl.throwWindows = true
        var resultRaw = CPointer<Unit>()
        let windowsHr = unsafe { vtbl.GetWeakReference(raw, CPointer<CPointer<Unit>>(inout resultRaw)) }
        @Expect(windowsHr, E_POINTER.value)
        @Expect(resultRaw.isNull(), true)
        impl.throwWindows = false

        impl.throwPlain = true
        resultRaw = CPointer<Unit>()
        let plainHr = unsafe { vtbl.GetWeakReference(raw, CPointer<CPointer<Unit>>(inout resultRaw)) }
        @Expect(plainHr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        impl.throwPlain = false
    } finally {
        source.close()
        object.close()
        unsafe { windows_interface.freeNativeValue<IWeakReferenceSourceVtbl>(sourceVtblHandle) }
    }
}

@Test
func testLocalWeakReferenceLookupMissRejectsNullAndClearsOutSlots() {
    var iid = IID_IUNKNOWN
    let staleHandle = unsafe { windows_interface.allocateNativeValue<Int32>(123i32) }
    let staleRaw = CPointer<Unit>(staleHandle)
    var resultRaw = staleRaw

    try {
        let nullSourceQueryHr = unsafe {
            localWeakReferenceSourceQueryInterfaceThunk(
                CPointer<Unit>(),
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>()
            )
        }
        @Expect(nullSourceQueryHr, E_POINTER.value)

        resultRaw = staleRaw
        let nullSourceQueryIidHr = unsafe {
            localWeakReferenceSourceQueryInterfaceThunk(
                CPointer<Unit>(),
                CPointer<GUID>(),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }
        @Expect(nullSourceQueryIidHr, E_POINTER.value)
        @Expect(resultRaw.isNull(), true)

        resultRaw = staleRaw
        let missingSourceQueryHr = unsafe {
            localWeakReferenceSourceQueryInterfaceThunk(
                CPointer<Unit>(),
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }
        @Expect(missingSourceQueryHr, E_NOINTERFACE.value)
        @Expect(resultRaw.isNull(), true)

        resultRaw = staleRaw
        let nullGetWeakReferenceHr = unsafe {
            localWeakReferenceSourceGetWeakReferenceThunk(CPointer<Unit>(), CPointer<CPointer<Unit>>())
        }
        @Expect(nullGetWeakReferenceHr, E_POINTER.value)
        let missingGetWeakReferenceHr = unsafe {
            localWeakReferenceSourceGetWeakReferenceThunk(
                CPointer<Unit>(),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }
        @Expect(missingGetWeakReferenceHr, E_NOINTERFACE.value)
        @Expect(resultRaw.isNull(), true)

        resultRaw = staleRaw
        let nullWeakQueryHr = unsafe {
            localWeakReferenceQueryInterfaceThunk(CPointer<Unit>(), CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>())
        }
        @Expect(nullWeakQueryHr, E_POINTER.value)
        let missingWeakQueryHr = unsafe {
            localWeakReferenceQueryInterfaceThunk(
                CPointer<Unit>(),
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }
        @Expect(missingWeakQueryHr, E_NOINTERFACE.value)
        @Expect(resultRaw.isNull(), true)

        resultRaw = staleRaw
        let nullWeakResolveHr = unsafe {
            localWeakReferenceResolveThunk(CPointer<Unit>(), CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>())
        }
        @Expect(nullWeakResolveHr, E_POINTER.value)
        let missingWeakResolveHr = unsafe {
            localWeakReferenceResolveThunk(
                CPointer<Unit>(),
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }
        @Expect(missingWeakResolveHr, E_NOINTERFACE.value)
        @Expect(resultRaw.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<Int32>(staleHandle) }
    }
}

@Test
func testWinrtGenericOutThrowsOnFailedHRESULT() {
    let slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ =>
        if (!result__.isNull()) {
            unsafe { CPointer<Int32>(result__).write(123i32) }
        }
        E_FAIL.value
    }

    @Expect(coreTestThrows({ =>
        let _ = winrtCallGenericOut<Int32>(slot, CPointer<Unit>())
    }), true)
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
func testHStringGenericOutReleasesPartialOutputOnFailedHRESULT() {
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    let slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ =>
        if (!result__.isNull()) {
            let source = HString("failed-generic-out")
            let raw = source.toSystemHandleCopy()
            source.close()
            unsafe { result__.write(raw) }
        }
        E_FAIL.value
    }

    @Expect(coreTestThrows({ =>
        let _ = winrtCallGenericOut<HString>(slot, CPointer<Unit>())
    }), true)
    @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
}

@When[os == "Windows"]
@Test
func testHStringGenericOutAfterUInt32ReleasesPartialOutputOnFailedHRESULT() {
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    let slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> = { _, _, result__ =>
        if (!result__.isNull()) {
            let source = HString("failed-generic-out-after-u32")
            let raw = source.toSystemHandleCopy()
            source.close()
            unsafe { result__.write(raw) }
        }
        E_FAIL.value
    }

    @Expect(coreTestThrows({ =>
        let _ = winrtCallGenericOutAfterUInt32<HString>(slot, CPointer<Unit>(), 7u32)
    }), true)
    @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
}

@When[os == "Windows"]
@Test
func testHStringGenericOutFromGenericInputReleasesPartialOutputOnFailedHRESULT() {
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    let slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, result__ =>
        if (!result__.isNull()) {
            let source = HString("failed-generic-out-from-input")
            let raw = source.toSystemHandleCopy()
            source.close()
            unsafe { result__.write(raw) }
        }
        E_FAIL.value
    }

    @Expect(coreTestThrows({ =>
        let _ = winrtCallGenericOutFromGenericInput<HString, Int32>(slot, CPointer<Unit>(), 7i32)
    }), true)
    @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
}

@When[os == "Windows"]
@Test
func testHStringGenericArrayOutReleaseHelperReleasesElementsAndStorage() {
    let first = HString("failed-array-one")
    let second = HString("failed-array-two")
    let rawFirst = first.toSystemHandleCopy()
    let rawSecond = second.toSystemHandleCopy()
    first.close()
    second.close()
    let array = AbiArray<CPointer<Unit>>.fromSlice([rawFirst, rawSecond])
    let (rawArray, length) = array.intoAbi()
    let deleteBefore = debugObservedWindowsDeleteStringCount()

    winrtReleaseGenericArrayOut<HString>(CPointer<Unit>(rawArray), length)

    @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 2)
}

@C
func coreFailingHStringArrayOutAfterOne(
    instanceRaw: CPointer<Unit>,
    size: UInt32,
    items: CPointer<CPointer<Unit>>,
    result: CPointer<UInt32>
): Int32 {
    let _ = instanceRaw
    if (size == 0u32 || items.isNull() || result.isNull()) {
        return E_POINTER.value
    }
    let value = HString("partial-array-out")
    let raw = value.toSystemHandleCopy()
    value.close()
    unsafe {
        items.write(raw)
        result.write(1u32)
    }
    E_FAIL.value
}

@C
func coreFailingHStringArrayOutAfterOneWithoutCount(
    instanceRaw: CPointer<Unit>,
    size: UInt32,
    items: CPointer<CPointer<Unit>>,
    result: CPointer<UInt32>
): Int32 {
    let _ = instanceRaw
    if (size == 0u32 || items.isNull() || result.isNull()) {
        return E_POINTER.value
    }
    let value = HString("partial-array-out-no-count")
    let raw = value.toSystemHandleCopy()
    value.close()
    unsafe { items.write(raw) }
    E_FAIL.value
}

@C
func coreNoWriteFailingHStringArrayOut(
    instanceRaw: CPointer<Unit>,
    size: UInt32,
    items: CPointer<CPointer<Unit>>,
    result: CPointer<UInt32>
): Int32 {
    let _ = instanceRaw
    if (size == 0u32 || items.isNull() || result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(1u32) }
    E_FAIL.value
}

@C
func coreFailingHStringArrayOutAfterUInt32AfterOne(
    instanceRaw: CPointer<Unit>,
    arg0: UInt32,
    size: UInt32,
    items: CPointer<CPointer<Unit>>,
    result: CPointer<UInt32>
): Int32 {
    let _ = arg0
    unsafe { coreFailingHStringArrayOutAfterOne(instanceRaw, size, items, result) }
}

@C
func coreFailingHStringArrayOutAfterUInt32AfterOneWithoutCount(
    instanceRaw: CPointer<Unit>,
    arg0: UInt32,
    size: UInt32,
    items: CPointer<CPointer<Unit>>,
    result: CPointer<UInt32>
): Int32 {
    let _ = arg0
    unsafe { coreFailingHStringArrayOutAfterOneWithoutCount(instanceRaw, size, items, result) }
}

@C
func coreNoWriteFailingHStringArrayOutAfterUInt32(
    instanceRaw: CPointer<Unit>,
    arg0: UInt32,
    size: UInt32,
    items: CPointer<CPointer<Unit>>,
    result: CPointer<UInt32>
): Int32 {
    let _ = arg0
    unsafe { coreNoWriteFailingHStringArrayOut(instanceRaw, size, items, result) }
}

func assertHStringGenericArrayOutClearsStaleSlot(action: (CPointer<Unit>) -> UInt32): Unit {
    let buffer = coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    let stale = HString("stale-core-array-out")
    let staleRaw = stale.toSystemHandleCopy()
    stale.close()
    unsafe {
        slots.write(staleRaw)
        (slots + 1).write(CPointer<Unit>())
    }
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    try {
        @Expect(coreTestThrows({ =>
            let _ = action(buffer)
        }), true)

        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 0)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        releaseSystemHStringHandle(staleRaw)
        coTaskMemFree(buffer)
    }
}

@When[os == "Windows"]
@Test
func testHStringGenericArrayOutCallClearsStaleSlotBeforeNoWriteFailure() {
    let bridge = HString.winrtOutputBridge()
    assertHStringGenericArrayOutClearsStaleSlot({ buffer: CPointer<Unit> =>
        bridge.callArrayOut(coreNoWriteFailingHStringArrayOut, CPointer<Unit>(), 2u32, buffer)
    })
}

@When[os == "Windows"]
@Test
func testHStringGenericArrayOutAfterUInt32CallClearsStaleSlotBeforeNoWriteFailure() {
    let bridge = HString.winrtOutputBridge()
    assertHStringGenericArrayOutClearsStaleSlot({ buffer: CPointer<Unit> =>
        bridge.callArrayOutAfterUInt32(coreNoWriteFailingHStringArrayOutAfterUInt32, CPointer<Unit>(), 7u32, 2u32, buffer)
    })
}

@When[os == "Windows"]
@Test
func testHStringGenericArrayOutCallReleasesFailedPartialOutputs() {
    let buffer = coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe {
        slots.write(CPointer<Unit>())
        (slots + 1).write(CPointer<Unit>())
    }
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    try {
        let bridge = HString.winrtOutputBridge()
        @Expect(coreTestThrows({ =>
            let _ = bridge.callArrayOut(coreFailingHStringArrayOutAfterOne, CPointer<Unit>(), 2u32, buffer)
        }), true)

        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        let remaining = unsafe { slots.read() }
        if (remaining.isNotNull()) {
            releaseSystemHStringHandle(remaining)
        }
        coTaskMemFree(buffer)
    }
}

@C
func coreNoWriteFailingGetUnmarshalClassThunk(
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    _: CPointer<Unit>,
    _: UInt32,
    _: CPointer<Unit>,
    _: UInt32,
    _: CPointer<GUID>
): Int32 {
    E_FAIL.value
}

@C
func coreNoWriteFailingGetMarshalSizeMaxThunk(
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    _: CPointer<Unit>,
    _: UInt32,
    _: CPointer<Unit>,
    _: UInt32,
    _: CPointer<UInt32>
): Int32 {
    E_FAIL.value
}

@C
func coreNoWriteFailingUnmarshalInterfaceThunk(
    _: CPointer<Unit>,
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    _: CPointer<CPointer<Unit>>
): Int32 {
    E_FAIL.value
}

func coreNoWriteFailingMarshalVtbl(): IMarshalVtbl {
    var vtbl = IMarshalVtbl()
    vtbl.GetUnmarshalClass = coreNoWriteFailingGetUnmarshalClassThunk
    vtbl.GetMarshalSizeMax = coreNoWriteFailingGetMarshalSizeMaxThunk
    vtbl.UnmarshalInterface = coreNoWriteFailingUnmarshalInterfaceThunk
    vtbl
}

@Test
func testAggregatedMarshalerUnmarshalClearsStaleOutputBeforeNoWriteFailure() {
    resetCoreQueryFailureState()
    let innerVtblHandle = unsafe { windows_interface.allocateNativeValue<IMarshalVtbl>(coreNoWriteFailingMarshalVtbl()) }
    let innerHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IMarshalVtbl>>(innerVtblHandle) }
    let staleVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(coreQueryFailureVtbl()) }
    let staleHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    var resultRaw = CPointer<Unit>(staleHandle)
    let state = AggregatedMarshalerState(IUnknown.viewOf(CPointer<Unit>()), IMarshal.viewOf(CPointer<Unit>(innerHandle)))

    try {
        let hr = state.unmarshalInterface(
            CPointer<Unit>(),
            CPointer<GUID>(),
            CPointer<CPointer<Unit>>(inout resultRaw)
        )

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(coreQueryFailureReleaseCount.load(), 0)

        var classId = GUID(1u32, 2u16, 3u16, 4u8, 5u8, 6u8, 7u8, 8u8, 9u8, 10u8, 11u8)
        let classHr = state.getUnmarshalClass(
            CPointer<GUID>(),
            CPointer<Unit>(),
            0u32,
            CPointer<Unit>(),
            0u32,
            CPointer<GUID>(inout classId)
        )
        @Expect(classHr, E_FAIL.value)
        @Expect(classId.data1, 0u32)
        @Expect(classId.data2, 0u16)
        @Expect(classId.data3, 0u16)
        @Expect(classId.data4[0], 0u8)

        var size = 99u32
        let sizeHr = state.getMarshalSizeMax(
            CPointer<GUID>(),
            CPointer<Unit>(),
            0u32,
            CPointer<Unit>(),
            0u32,
            CPointer<UInt32>(inout size)
        )
        @Expect(sizeHr, E_FAIL.value)
        @Expect(size, 0u32)
    } finally {
        let _ = state.release()
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(staleVtblHandle)
            windows_interface.freeNativeValue<CPointer<IMarshalVtbl>>(innerHandle)
            windows_interface.freeNativeValue<IMarshalVtbl>(innerVtblHandle)
        }
        resetCoreQueryFailureState()
    }
}

@Test
func testAggregatedMarshalerLookupMissClearsOutSlots() {
    let staleVtblHandle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(coreQueryFailureVtbl()) }
    let staleHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    var pcid = GUID(1u32, 2u16, 3u16, 4u8, 5u8, 6u8, 7u8, 8u8, 9u8, 10u8, 11u8)
    var size = 99u32
    var ppv = CPointer<Unit>(staleHandle)

    try {
        let classHr = unsafe {
            aggregatedMarshalerGetUnmarshalClassThunk(
                CPointer<Unit>(),
                CPointer<GUID>(),
                CPointer<Unit>(),
                0u32,
                CPointer<Unit>(),
                0u32,
                CPointer<GUID>(inout pcid)
            )
        }
        @Expect(classHr, E_NOINTERFACE.value)
        @Expect(pcid.data1, 0u32)
        @Expect(pcid.data2, 0u16)
        @Expect(pcid.data3, 0u16)
        @Expect(pcid.data4[0], 0u8)

        let sizeHr = unsafe {
            aggregatedMarshalerGetMarshalSizeMaxThunk(
                CPointer<Unit>(),
                CPointer<GUID>(),
                CPointer<Unit>(),
                0u32,
                CPointer<Unit>(),
                0u32,
                CPointer<UInt32>(inout size)
            )
        }
        @Expect(sizeHr, E_NOINTERFACE.value)
        @Expect(size, 0u32)

        let unmarshalHr = unsafe {
            aggregatedMarshalerUnmarshalInterfaceThunk(
                CPointer<Unit>(),
                CPointer<Unit>(),
                CPointer<GUID>(),
                CPointer<CPointer<Unit>>(inout ppv)
            )
        }
        @Expect(unmarshalHr, E_NOINTERFACE.value)
        @Expect(ppv.isNull(), true)
    } finally {
        unsafe {
            windows_interface.freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            windows_interface.freeNativeValue<IUnknownVtbl>(staleVtblHandle)
        }
    }
}

@When[os == "Windows"]
@Test
func testHStringGenericArrayOutCallReleasesFailedPartialOutputsWithoutReturnedCount() {
    let buffer = coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe {
        slots.write(CPointer<Unit>())
        (slots + 1).write(CPointer<Unit>())
    }
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    try {
        let bridge = HString.winrtOutputBridge()
        @Expect(coreTestThrows({ =>
            let _ = bridge.callArrayOut(coreFailingHStringArrayOutAfterOneWithoutCount, CPointer<Unit>(), 2u32, buffer)
        }), true)

        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        let remaining = unsafe { slots.read() }
        if (remaining.isNotNull()) {
            releaseSystemHStringHandle(remaining)
        }
        coTaskMemFree(buffer)
    }
}

@When[os == "Windows"]
@Test
func testHStringGenericArrayOutAfterUInt32CallReleasesFailedPartialOutputs() {
    let buffer = coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe {
        slots.write(CPointer<Unit>())
        (slots + 1).write(CPointer<Unit>())
    }
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    try {
        let bridge = HString.winrtOutputBridge()
        @Expect(coreTestThrows({ =>
            let _ = bridge.callArrayOutAfterUInt32(coreFailingHStringArrayOutAfterUInt32AfterOne, CPointer<Unit>(), 7u32, 2u32, buffer)
        }), true)

        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        let remaining = unsafe { slots.read() }
        if (remaining.isNotNull()) {
            releaseSystemHStringHandle(remaining)
        }
        coTaskMemFree(buffer)
    }
}

@When[os == "Windows"]
@Test
func testHStringGenericArrayOutAfterUInt32CallReleasesFailedPartialOutputsWithoutReturnedCount() {
    let buffer = coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe {
        slots.write(CPointer<Unit>())
        (slots + 1).write(CPointer<Unit>())
    }
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    try {
        let bridge = HString.winrtOutputBridge()
        @Expect(coreTestThrows({ =>
            let _ = bridge.callArrayOutAfterUInt32(coreFailingHStringArrayOutAfterUInt32AfterOneWithoutCount, CPointer<Unit>(), 7u32, 2u32, buffer)
        }), true)

        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        let remaining = unsafe { slots.read() }
        if (remaining.isNotNull()) {
            releaseSystemHStringHandle(remaining)
        }
        coTaskMemFree(buffer)
    }
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
