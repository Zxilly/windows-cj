package windows_core_smoke

import windows_core.*

public class SmokeFailure <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

public class DemoImpl <: IAgileObject_Impl {
    public init() {}
}

public class MissingInterface <: ComInterface {
    private let raw_: CPointer<Unit>

    public init(raw: CPointer<Unit>) {
        this.raw_ = raw
    }

    public static func iid(): GUID {
        GUID.fromValues(0x13572468u32, 0x2468u16, 0x369Cu16, 0x11u8, 0x22u8, 0x33u8, 0x44u8, 0x55u8, 0x66u8, 0x77u8, 0x88u8)
    }

    public func asRaw(): CPointer<Unit> {
        raw_
    }

    public static func descriptor(): InterfaceDescriptor<MissingInterface> {
        InterfaceDescriptor<MissingInterface>("MissingInterface", MissingInterface.iid(), { raw => MissingInterface(raw) })
    }
}

public class DemoAbiType <: RuntimeType & Type<DemoAbiType, String, String> & CloneType {
    public init() {}

    public static func abiType(): String {
        "demo-abi"
    }

    public static func signature(): String {
        "demo-signature"
    }

    public static func assumeInitRef(abi: String): DemoAbiType {
        let _ = abi
        DemoAbiType()
    }

    public static func from_abi(abi: String): Result<DemoAbiType> {
        let _ = abi
        Result<DemoAbiType>.Ok(DemoAbiType())
    }

    public static func from_default(defaultValue: String): Result<DemoAbiType> {
        let _ = defaultValue
        Result<DemoAbiType>.Ok(DemoAbiType())
    }

    public static func isNullAbi(abi: String): Bool {
        abi.isEmpty()
    }
}

public class DemoCanInto <: CanInto<DemoCanInto> {
    public init() {}
}

func copyQueryResult(
    target: CPointer<Unit>,
    riid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Result<Unit> {
    unsafe {
        if (ppvObject.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        ppvObject.write(CPointer<Unit>())
        if (riid.isNull() || target.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        match (queryInterfaceRaw(target, riid.read())) {
            case Some(raw) =>
                ppvObject.write(raw)
                Result<Unit>.Ok(())
            case None =>
                Result<Unit>.Err(WinError(E_NOINTERFACE))
        }
    }
}

public class DemoAgileReferenceImpl <: IAgileReference_Impl {
    private let target: CPointer<Unit>

    public init(target: CPointer<Unit>) {
        this.target = target
    }

    public func Resolve(
        riid: CPointer<GUID>,
        ppvobjectreference: CPointer<CPointer<Unit>>
    ): Result<Unit> {
        copyQueryResult(target, riid, ppvobjectreference)
    }
}

public class DemoWeakReferenceImpl <: IWeakReference_Impl {
    private let target: CPointer<Unit>

    public init(target: CPointer<Unit>) {
        this.target = target
    }

    public func Resolve(
        riid: CPointer<GUID>,
        objectreference: CPointer<CPointer<Unit>>
    ): Result<Unit> {
        copyQueryResult(target, riid, objectreference)
    }
}

public class DemoWeakReferenceSourceImpl <: IWeakReferenceSource_Impl {
    private let weakReference: IWeakReference

    public init(weakReference: IWeakReference) {
        this.weakReference = weakReference
    }

    public func GetWeakReference(): Result<IWeakReference> {
        weakReference.addRef()
        Result<IWeakReference>.Ok(IWeakReference(weakReference.asRaw(), ownsReference: true))
    }
}

func readParamAbi<T>(value: Param<T>): T {
    value.abi()
}

func readAbiType<T>(): String where T <: WindowsType {
    T.abiType()
}

func readRuntimeSignature<T>(): String where T <: RuntimeType {
    T.signature()
}

func readTypeKind<T, A, D>(): TypeKind where T <: Type<T, A, D> {
    T.typeKind()
}

func readNullAbi<T, A, D>(abi: A): Bool where T <: Type<T, A, D> {
    T.isNullAbi(abi)
}

func readCanIntoQuery<T, U>(): Bool where T <: CanInto<U> {
    T.query()
}

func buildUnknownVtblFor<T>(): IUnknownVtbl where T <: IUnknownImpl {
    newIUnknownVtbl<T>()
}

func buildInspectableVtblFor<T>(): IInspectableVtbl where T <: IInspectableImpl {
    newIInspectableVtbl<T>()
}

func buildAgileObjectVtblFor<T>(): IAgileObjectVtbl where T <: IAgileObject_Impl {
    newIAgileObjectVtbl<T>()
}

func buildAgileReferenceVtblFor<T>(): IAgileReferenceVtbl where T <: IAgileReference_Impl {
    newIAgileReferenceVtbl<T>()
}

func buildWeakReferenceVtblFor<T>(): IWeakReferenceVtbl where T <: IWeakReference_Impl {
    newIWeakReferenceVtbl<T>()
}

func buildWeakReferenceSourceVtblFor<T>(): IWeakReferenceSourceVtbl where T <: IWeakReferenceSource_Impl {
    newIWeakReferenceSourceVtbl<T>()
}

func samePointer(left: CPointer<Unit>, right: CPointer<Unit>): Bool {
    left.toUIntNative() == right.toUIntNative()
}

@C
public func fakeGetRuntimeClassNameValue(
    _: CPointer<Unit>,
    valuePtr: CPointer<CPointer<Unit>>
): Int32 {
    if (valuePtr.isNull()) {
        return -2147467261i32
    }

    let runtimeClassName = HString("Demo.RuntimeClass")
    unsafe {
        valuePtr.write(runtimeClassName.asRaw())
    }
    0i32
}

func fail(msg: String): Unit {
    throw SmokeFailure(msg)
}

main(_: Array<String>) {
    let supported = Array(1, { _ => IInspectable.descriptorSchema() })
    let unknownDescriptor: InterfaceDescriptor<IUnknown> = IUnknown.descriptor()

    var vtbl = buildIInspectableVtbl()
    let vtblPtr = CPointer<Unit>(CPointer<IInspectableVtbl>(inout vtbl))
    var object = createComObjectFromSchemas(DemoImpl(), supported, vtblPtr)

    let paramValue = ParamValue<Int32>(42i32)
    if (readParamAbi<Int32>(paramValue) != 42i32) {
        fail("ParamValue.abi should expose the wrapped ABI value")
    }
    let borrowedParam = paramValue.borrow()
    if (borrowedParam.isNull()) {
        fail("ParamValue.borrow should produce a non-null RefParam for concrete values")
    }
    if (borrowedParam.get() != 42i32) {
        fail("RefParam.get should expose the borrowed ABI value")
    }
    match (borrowedParam.ok()) {
        case Ok(value) =>
            if (value != 42i32) {
                fail("RefParam.ok should wrap the borrowed value in Result.Ok")
            }
        case Err(error) =>
            fail("RefParam.ok should not fail for concrete values: ")
    }
    match (borrowedParam.as_ref()) {
        case Some(value) =>
            if (value != 42i32) {
                fail("RefParam.as_ref should expose the borrowed value")
            }
        case None =>
            fail("RefParam.as_ref should return Some for concrete values")
    }
    if (borrowedParam.unwrap() != 42i32) {
        fail("RefParam.unwrap should return the borrowed ABI value")
    }
    match (borrowedParam.cloned()) {
        case Some(value) =>
            if (value != 42i32) {
                fail("RefParam.cloned should preserve the borrowed value")
            }
        case None =>
            fail("RefParam.cloned should return Some for concrete values")
    }
    let borrowedAbi: Int32 = borrowedParam.borrow()
    if (borrowedAbi != 42i32) {
        fail("Ref.borrow should project copy values through their ABI shape")
    }
    let emptyRef = RefParam<Int32>()
    if (!emptyRef.isNull()) {
        fail("RefParam default construction should model an empty borrowed reference")
    }
    var emptyRefFailed = false
    try {
        emptyRef.get()
    } catch (_: IllegalStateException) {
        emptyRefFailed = true
    }
    if (!emptyRefFailed) {
        fail("RefParam.get should reject empty borrowed references")
    }
    if (readAbiType<DemoAbiType>() != "demo-abi") {
        fail("WindowsType static ABI metadata should be callable through generic constraints")
    }
    if (readRuntimeSignature<DemoAbiType>() != "demo-signature") {
        fail("RuntimeType static signature metadata should be callable through generic constraints")
    }
    match (readTypeKind<DemoAbiType, String, String>()) {
        case TypeKind.Clone =>
            ()
        case _ =>
            fail("Type.typeKind should surface CloneType metadata through generic constraints")
    }
    if (!readNullAbi<DemoAbiType, String, String>("")) {
        fail("Type.isNullAbi should support custom ABI nullability checks")
    }
    match (readTypeKind<IUnknown, CPointer<Unit>, Option<IUnknown>>()) {
        case TypeKind.Interface =>
            ()
        case _ =>
            fail("Interface<T> should project COM wrappers as InterfaceType")
    }
    if (!readNullAbi<IUnknown, CPointer<Unit>, Option<IUnknown>>(CPointer<Unit>())) {
        fail("Interface<T> should treat a null COM ABI pointer as empty")
    }
    let outParam = OutParam<Int32>()
    let outRef = outParam.borrow()
    if (outRef.isNull()) {
        fail("OutParam.borrow should produce a writable OutRef")
    }
    outRef.write(99i32)
    match (outParam.get()) {
        case Some(value) =>
            if (value != 99i32) {
                fail("OutRef.write should populate the backing OutParam value")
            }
        case None =>
            fail("OutRef.write should store a value into OutParam")
    }
    outParam.clear()
    match (outParam.get()) {
        case Some(_) =>
            fail("OutParam.clear should reset the captured ABI value")
        case None =>
            ()
    }
    let nullOutRef = OutRef<Int32>.none()
    if (!nullOutRef.isNull()) {
        fail("OutRef.none should model a missing output target")
    }
    var nullOutWriteFailed = false
    try {
        nullOutRef.write(1i32)
    } catch (_: IllegalStateException) {
        nullOutWriteFailed = true
    }
    if (!nullOutWriteFailed) {
        fail("OutRef.write should reject null output targets")
    }
    let rawOutSlot: CPointer<Int32> = outRef.borrowMut()
    unsafe { rawOutSlot.write(123i32) }
    if (unsafe { rawOutSlot.read() } != 123i32) {
        fail("OutRef.borrowMut should expose a writable ABI output slot")
    }

    let guidHigh = 0x0011223344556677u64
    let guidLow = 0x8899AABBCCDDEEFFu64
    let guid = GUID.fromU128(guidHigh, guidLow)
    let (roundTripHigh, roundTripLow) = guid.toU128()
    if (roundTripHigh != guidHigh || roundTripLow != guidLow) {
        fail("GUID.fromU128/toU128 should round-trip the original 128-bit value")
    }
    let snakeCaseValue = UInt128(guidHigh, guidLow)
    let snakeCaseGuid = GUID.from_u128(snakeCaseValue)
    let snakeCaseRoundTrip = snakeCaseGuid.to_u128()
    if (snakeCaseRoundTrip.high != guidHigh || snakeCaseRoundTrip.low != guidLow) {
        fail("GUID.from_u128/to_u128 should preserve the canonical 128-bit payload")
    }
    if (!GUID.zeroed().isZero()) {
        fail("GUID.zeroed should return the all-zero identifier")
    }
    var parsedGuid = GUID_ZERO
    match (GUID.fromString("00112233-4455-6677-8899-AABBCCDDEEFF")) {
        case Some(value) =>
            parsedGuid = value
        case None =>
            fail("GUID.fromString should parse canonical GUID text")
    }
    let expectedGuid = GUID.fromValues(
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
    if (parsedGuid != expectedGuid) {
        fail("GUID.fromString should parse canonical GUID text")
    }
    if (parsedGuid.toString() != "00112233-4455-6677-8899-AABBCCDDEEFF") {
        fail("GUID.fromString should preserve canonical formatting")
    }
    let parsedGuidHash = parsedGuid.hashCode()
    let expectedGuidHash = expectedGuid.hashCode()
    if (parsedGuidHash != expectedGuidHash) {
        fail("GUID hashCode should be stable for equal GUID values")
    }
    let generatedGuid = GUID.generate()
    if (generatedGuid.isZero()) {
        fail("GUID.generate should not return GUID_ZERO")
    }
    match (GUID.fromString(generatedGuid.toString())) {
        case Some(roundTripGuid) =>
            if (roundTripGuid != generatedGuid) {
                fail("GUID.fromString should parse the text produced by GUID.generate")
            }
        case None =>
            fail("GUID.fromString should parse the text produced by GUID.generate")
    }
    match (GUID.new()) {
        case Ok(value) =>
            if (value.isZero()) {
                fail("GUID.new should return a non-zero GUID on success")
            }
        case Err(error) =>
            fail("GUID.new failed unexpectedly: ")
    }
    let signatureText = "pinterface({00000000-0000-0000-c000-000000000046})"
    let signatureGuid = guidFromSignature(ConstBuffer.fromUtf8(signatureText))
    if (signatureGuid != guidFromSignature(ConstBuffer.fromUtf8(signatureText))) {
        fail("guidFromSignature should be stable for the same signature text")
    }
    match (GUID.tryFrom("00112233-4455-6677-8899-AABBCCDDEEFF")) {
        case Ok(value) =>
            if (value != expectedGuid) {
                fail("GUID.tryFrom should parse canonical GUID text")
            }
        case Err(error) =>
            fail("GUID.tryFrom failed unexpectedly: ")
    }
    if (GUID.fromSignature(signatureText) != signatureGuid) {
        fail("GUID.fromSignature should share the same signature hashing logic")
    }
    if (unknownDescriptor.iid != IUnknown.iid()) {
        fail("InterfaceDescriptor should be re-exported through windows_core")
    }
    if (readCanIntoQuery<DemoCanInto, DemoCanInto>()) {
        fail("CanInto.query should default to false")
    }
    if (!queryRequiredFor<IInspectable, IUnknown>()) {
        fail("queryRequiredFor should require QI when converting IUnknown to IInspectable")
    }
    if (queryRequiredFor<IUnknown, IInspectable>()) {
        fail("queryRequiredFor should detect direct interface upcasts without QI")
    }

    let builtUnknownVtbl = buildUnknownVtblFor<ComObjectRuntime<DemoImpl>>()
    let builtInspectableVtbl = buildInspectableVtblFor<ComObjectRuntime<DemoImpl>>()
    let builtAgileObjectVtbl = buildAgileObjectVtblFor<DemoImpl>()
    let builtAgileReferenceVtbl = buildAgileReferenceVtblFor<DemoAgileReferenceImpl>()
    let builtWeakReferenceVtbl = buildWeakReferenceVtblFor<DemoWeakReferenceImpl>()
    let builtWeakReferenceSourceVtbl = buildWeakReferenceSourceVtblFor<DemoWeakReferenceSourceImpl>()
    if (unsafe { builtUnknownVtbl.AddRef(CPointer<Unit>()) } != 0u32) {
        fail("IUnknownVtbl.new should wire the AddRef thunk")
    }
    var trustLevel = 123i32
    let trustLevelHr = unsafe {
        builtInspectableVtbl.GetTrustLevel(
            CPointer<Unit>(),
            CPointer<Int32>(inout trustLevel)
        )
    }
    if (trustLevelHr != E_NOINTERFACE.value || trustLevel != 0i32) {
        fail("IInspectableVtbl.new should wire the GetTrustLevel thunk")
    }
    if (unsafe { builtAgileObjectVtbl.base_.Release(CPointer<Unit>()) } != 0u32) {
        fail("IAgileObject vtable helper should reuse the IUnknown release thunk")
    }
    let agileReferenceSupported = Array<GUID>(1, { _ => IAgileReference.iid() })
    var agileReferenceVtbl = builtAgileReferenceVtbl
    let agileReferenceVtblPtr = CPointer<Unit>(CPointer<IAgileReferenceVtbl>(inout agileReferenceVtbl))
    let agileReferenceObject = ComObject<DemoAgileReferenceImpl>.new(
        DemoAgileReferenceImpl(object.asRaw()),
        agileReferenceSupported,
        agileReferenceVtblPtr
    )
    let agileReference = agileReferenceObject.toInterface(IAgileReference.descriptor())
    match (unsafe { agileReference.resolve(IInspectable.descriptor()) }) {
        case Result<IInspectable>.Ok(resolved) =>
            if (!samePointer(resolved.asRaw(), object.asRaw())) {
                fail("IAgileReference vtable helper should dispatch Resolve to the implementation object")
            }
            resolved.close()
        case Result<IInspectable>.Err(error) =>
            fail("IAgileReference Resolve dispatch failed: ")
    }
    agileReference.close()

    let weakReferenceSupported = Array<GUID>(1, { _ => IWeakReference.iid() })
    var weakReferenceVtbl = builtWeakReferenceVtbl
    let weakReferenceVtblPtr = CPointer<Unit>(CPointer<IWeakReferenceVtbl>(inout weakReferenceVtbl))
    let weakReferenceObject = ComObject<DemoWeakReferenceImpl>.new(
        DemoWeakReferenceImpl(object.asRaw()),
        weakReferenceSupported,
        weakReferenceVtblPtr
    )
    let weakReference = weakReferenceObject.toInterface(IWeakReference.descriptor())
    match (unsafe { weakReference.resolve(IInspectable.descriptor()) }) {
        case Result<IInspectable>.Ok(resolved) =>
            if (!samePointer(resolved.asRaw(), object.asRaw())) {
                fail("IWeakReference vtable helper should dispatch Resolve to the implementation object")
            }
            resolved.close()
        case Result<IInspectable>.Err(error) =>
            fail("IWeakReference Resolve dispatch failed: ")
    }

    let weakReferenceSourceSupported = Array<GUID>(1, { _ => IWeakReferenceSource.iid() })
    var weakReferenceSourceVtbl = builtWeakReferenceSourceVtbl
    let weakReferenceSourceVtblPtr = CPointer<Unit>(CPointer<IWeakReferenceSourceVtbl>(inout weakReferenceSourceVtbl))
    let weakReferenceSourceObject = ComObject<DemoWeakReferenceSourceImpl>.new(
        DemoWeakReferenceSourceImpl(weakReference),
        weakReferenceSourceSupported,
        weakReferenceSourceVtblPtr
    )
    let weakReferenceSource = weakReferenceSourceObject.toInterface(IWeakReferenceSource.descriptor())
    match (unsafe { weakReferenceSource.getWeakReference() }) {
        case Result<IWeakReference>.Ok(resolvedWeakReference) =>
            match (unsafe { resolvedWeakReference.resolve(IInspectable.descriptor()) }) {
                case Result<IInspectable>.Ok(resolved) =>
                    if (!samePointer(resolved.asRaw(), object.asRaw())) {
                        fail("IWeakReferenceSource vtable helper should dispatch GetWeakReference to the implementation object")
                    }
                    resolved.close()
                case Result<IInspectable>.Err(error) =>
                    fail("resolved weak reference should be usable: ")
            }
            resolvedWeakReference.close()
        case Result<IWeakReference>.Err(error) =>
            fail("IWeakReferenceSource GetWeakReference dispatch failed: ")
    }
    weakReferenceSource.close()
    weakReference.close()
    if (!matchesIAgileObjectVtbl(IAgileObject.iid())) {
        fail("IAgileObject matches helper should recognize the canonical IID")
    }
    if (!matchesIAgileReferenceVtbl(IAgileReference.iid())) {
        fail("IAgileReference matches helper should recognize the canonical IID")
    }
    if (!matchesIWeakReferenceVtbl(IWeakReference.iid())) {
        fail("IWeakReference matches helper should recognize the canonical IID")
    }
    if (!matchesIWeakReferenceSourceVtbl(IWeakReferenceSource.iid())) {
        fail("IWeakReferenceSource matches helper should recognize the canonical IID")
    }

    let borrowedUnknown = object.toInterface(IUnknown.descriptor())
    let unknownRef = InterfaceRef<IUnknown>.fromInterface(borrowedUnknown)
    if (!samePointer(unknownRef.asRaw(), borrowedUnknown.asRaw())) {
        fail("InterfaceRef.fromInterface should retain the borrowed COM pointer")
    }
    let ownedUnknown = unknownRef.retain()
    if (!samePointer(ownedUnknown.asRaw(), borrowedUnknown.asRaw())) {
        fail("InterfaceRef.retain should clone the same COM identity")
    }
    ownedUnknown.close()
    borrowedUnknown.close()

    let genericFactoryDescriptor = IGenericFactory.descriptor()
    if (genericFactoryDescriptor.iid != IGenericFactory.iid()) {
        fail("IGenericFactory should expose a stable descriptor")
    }
    let genericFactory = IGenericFactory.viewOf(CPointer<Unit>())
    match (unsafe { genericFactory.ActivateInstance(IInspectable.descriptor()) }) {
        case Result<IInspectable>.Ok(_) =>
            fail("IGenericFactory.ActivateInstance should reject null factories")
        case Result<IInspectable>.Err(_) =>
            ()
    }

    let refCount = RefCount()
    if (!refCount.isOne()) {
        fail("RefCount should start at one")
    }
    if (refCount.addRef() != 2i32) {
        fail("RefCount.addRef should return the incremented count")
    }
    if (refCount.release() != 1i32) {
        fail("RefCount.release should return the decremented count")
    }
    if (!refCount.isOne()) {
        fail("RefCount.isOne should report true after a balanced addRef/release pair")
    }
    if (refCount.release() != 0i32) {
        fail("RefCount.release should allow the count to reach zero")
    }
    var overReleaseFailed = false
    try {
        refCount.release()
    } catch (_: IllegalStateException) {
        overReleaseFailed = true
    }
    if (!overReleaseFailed) {
        fail("RefCount.release should reject over-release")
    }
    let seededRefCount = RefCount.new(3u32)
    if (seededRefCount.release() != 2i32) {
        fail("RefCount.new should seed the initial reference count")
    }
    if (seededRefCount.release() != 1i32) {
        fail("RefCount.new should preserve balanced release semantics")
    }
    if (seededRefCount.release() != 0i32) {
        fail("RefCount.new should allow the seeded count to release to zero")
    }

    var scopedObject = createComObjectFromSchemas(DemoImpl(), supported, vtblPtr)
    let scopedUnknown = InterfaceResource<IUnknown>(scopedObject.asRaw(), IUnknown.descriptor(), addRef: true)
    let scopedHeap = scopedUnknown.slotInfo()
    if (scopedHeap.this_ptr != scopedObject.asRaw().toUIntNative()) {
        fail("InterfaceResource should capture the COM this pointer")
    }
    if (scopedHeap.vtable == UIntNative(0)) {
        fail("InterfaceResource should capture the COM vtable pointer")
    }
    if (scopedUnknown.isClosed()) {
        fail("InterfaceResource should start open")
    }
    let scopedView = scopedUnknown.value()
    if (scopedView.asRaw().toUIntNative() != scopedObject.asRaw().toUIntNative()) {
        fail("InterfaceResource.value should expose the wrapped COM interface")
    }
    scopedView.close()
    scopedUnknown.close()
    if (!scopedUnknown.isClosed()) {
        fail("InterfaceResource.close should mark the scope as closed")
    }
    let scopedProbe = IUnknown(scopedObject.asRaw())
    let afterScopedClose = scopedProbe.addRef()
    if (afterScopedClose != 2u32) {
        fail("InterfaceResource.close should leave the underlying COM reference count unchanged")
    }
    let resetScopedClose = scopedProbe.release()
    if (resetScopedClose != 1u32) {
        fail("InterfaceResource close probe should restore the original COM refcount")
    }
    let scopedFinalCount = IUnknown(scopedObject.asRaw()).release()
    if (scopedFinalCount != 0u32) {
        fail("InterfaceResource test object should release cleanly")
    }

    var identityLeftObject = createComObjectFromSchemas(DemoImpl(), supported, vtblPtr)
    var identityRightObject = createComObjectFromSchemas(DemoImpl(), supported, vtblPtr)
    let identityLeftUnknown = IUnknown(identityLeftObject.asRaw())
    let identityLeftInspectable = IInspectable(identityLeftObject.asRaw())
    let identityRightUnknown = IUnknown(identityRightObject.asRaw())
    if (!unsafe { identityLeftUnknown.hasSameIdentity(identityLeftInspectable) }) {
        fail("IUnknown identity helper should treat different views of the same COM object as equal")
    }
    if (unsafe { identityLeftUnknown.hasSameIdentity(identityRightUnknown) }) {
        fail("IUnknown identity helper should distinguish different COM objects")
    }
    let identityLeftFinalCount = IUnknown(identityLeftObject.asRaw()).release()
    if (identityLeftFinalCount != 0u32) {
        fail("identity-equality left object should release cleanly")
    }
    let identityRightFinalCount = IUnknown(identityRightObject.asRaw()).release()
    if (identityRightFinalCount != 0u32) {
        fail("identity-equality right object should release cleanly")
    }

    var runtimeVtbl = buildIInspectableVtbl()
    runtimeVtbl.GetRuntimeClassName = fakeGetRuntimeClassNameValue
    let runtimeVtblPtr = CPointer<Unit>(CPointer<IInspectableVtbl>(inout runtimeVtbl))
    var runtimeObject = createComObjectFromSchemas(DemoImpl(), supported, runtimeVtblPtr)
    let runtimeInspectable = IInspectable(runtimeObject.asRaw())
    match (paramFromInterface<IUnknown, IInspectable>(runtimeInspectable, IUnknown.descriptor())) {
        case Ok(param) =>
            let paramUnknown = param.abi()
            if (!samePointer(paramUnknown.asRaw(), runtimeObject.asRaw())) {
                fail("paramFromInterface should upcast without QI when the hierarchy already matches")
            }
            paramUnknown.close()
        case Err(error) =>
            fail("paramFromInterface upcast path failed unexpectedly: ")
    }
    let runtimeUnknown = IUnknown(runtimeObject.asRaw())
    match (paramFromInterface<IInspectable, IUnknown>(runtimeUnknown, IInspectable.descriptor())) {
        case Ok(param) =>
            let paramInspectable = param.abi()
            if (!samePointer(paramInspectable.asRaw(), runtimeObject.asRaw())) {
                fail("paramFromInterface should use QI when the target interface is not in the direct hierarchy")
            }
            paramInspectable.close()
        case Err(error) =>
            fail("paramFromInterface QI path failed unexpectedly: ")
    }
    let runtimeClassName = unsafe { runtimeInspectable.getRuntimeClassName() }
    if (runtimeClassName.get() != "Demo.RuntimeClass") {
        fail("IInspectable.getRuntimeClassName should convert the raw HSTRING into HString")
    }
    runtimeClassName.close()
    runtimeInspectable.close()
    let runtimeFinalCount = IUnknown(runtimeObject.asRaw()).release()
    if (runtimeFinalCount != 0u32) {
        fail("runtime-class-name object should release cleanly")
    }

    let unknown = IUnknown(object.asRaw())
    let unknownPtr = InterfaceHandle<IUnknown>(unknown.asRaw(), IUnknown.descriptor(), addRef: true)
    if (!unknownPtr.hasValue()) {
        fail("InterfaceHandle.hasValue should report a live owning pointer")
    }
    let unknownView = unknownPtr.value()
    if (unknownView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
        fail("InterfaceHandle<IUnknown>.value should wrap the attached raw pointer")
    }
    unknownView.close()
    let borrowedUnknownProbe = IUnknown(object.asRaw())
    let afterBorrowedUnknownClose = borrowedUnknownProbe.addRef()
    if (afterBorrowedUnknownClose != 3u32) {
        fail("closing a borrowed InterfaceHandle value view should not consume the owned COM reference")
    }
    let resetBorrowedUnknownClose = borrowedUnknownProbe.release()
    if (resetBorrowedUnknownClose != 2u32) {
        fail("borrowed InterfaceHandle value probe should restore the reference count")
    }

    let cloned = unknownPtr.retain()
    let clonedView = cloned.value()
    if (clonedView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
        fail("retain should preserve the wrapped raw pointer")
    }
    clonedView.close()

    let detachedPtr = unknownPtr.retain()
    let detachedRaw = detachedPtr.intoAbi()
    if (detachedRaw.toUIntNative() != object.asRaw().toUIntNative()) {
        fail("InterfaceHandle.intoAbi should yield the wrapped raw pointer")
    }
    if (detachedPtr.hasValue()) {
        fail("InterfaceHandle.intoAbi should leave the source pointer empty")
    }
    detachedPtr.close()

    match (unsafe { queryInterfaceResult(object.asRaw(), IInspectable.descriptor()) }) {
        case Ok(inspectablePtr) =>
            let inspectableView = inspectablePtr.value()
            if (inspectableView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
                fail("queryInterfaceResult should return the resolved interface pointer")
            }
            inspectableView.close()
            inspectablePtr.close()
        case Err(hr) =>
            fail("queryInterfaceResult should succeed for IInspectable, got ")
    }

    match (unsafe { queryInterfaceResult(object.asRaw(), MissingInterface.descriptor()) }) {
        case Ok(_) =>
            fail("queryInterfaceResult should report HRESULT failure for unsupported interfaces")
        case Err(hr) =>
            if (hr.value != -2147467262i32) {
                fail("queryInterfaceResult should preserve E_NOINTERFACE for unsupported interfaces")
            }
    }

    match (unsafe { unknownPtr.query(IInspectable.descriptor()) }) {
        case Some(inspectablePtr) =>
            let inspectableView = inspectablePtr.value()
            if (inspectableView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
                fail("query should wrap the same raw object for IInspectable")
            }
            let borrowedUnknownView = inspectableView.asIUnknown()
            borrowedUnknownView.close()
            var trustLevel = -1i32
            let trustHr = unsafe { inspectableView.getTrustLevel(CPointer<Int32>(inout trustLevel)) }
            if (trustHr.value != 0i32) {
                fail("default IInspectable trust level should report S_OK through InterfaceHandle")
            }
            if (trustLevel != 0i32) {
                fail("default IInspectable trust level should return BaseTrust")
            }
            inspectableView.close()
            let borrowedInspectableProbe = IUnknown(object.asRaw())
            let afterBorrowedInspectableClose = borrowedInspectableProbe.addRef()
            if (afterBorrowedInspectableClose != 6u32) {
                fail("closing borrowed views from InterfaceHandle.query should not consume the owned InterfaceHandle reference")
            }
            let resetBorrowedInspectableClose = borrowedInspectableProbe.release()
            if (resetBorrowedInspectableClose != 5u32) {
                fail("borrowed InterfaceHandle.query probe should restore the reference count")
            }
            inspectablePtr.close()
        case None =>
            fail("InterfaceHandle.query should succeed for IInspectable")
    }

    cloned.close()
    unknownPtr.close()
    let detachedRelease = IUnknown(detachedRaw).release()
    if (detachedRelease != 1u32) {
        fail("detached COM references should remain owned until released explicitly")
    }
    if (unknownPtr.hasValue()) {
        fail("closed InterfaceHandle instances should report no value")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("closing InterfaceHandle instances should release their references")
    }
}
