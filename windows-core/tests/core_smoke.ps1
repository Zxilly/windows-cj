$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$corePath = ($packageRoot -replace '\\', '/')
$implementPath = ((Join-Path $repoRoot 'windows-cj/windows-implement') -replace '\\', '/')
$workspaceRoot = Join-Path $packageRoot "tests/output/core_smoke"
$runnerRoot = Join-Path $workspaceRoot "runner"
$srcRoot = Join-Path $runnerRoot "src"

if (Test-Path $workspaceRoot) {
    Remove-Item -Recurse -Force $workspaceRoot
}
New-Item -ItemType Directory -Force $srcRoot | Out-Null

$manifest = @"
[package]
  name = "windows_core_smoke"
  version = "0.1.0"
  description = "Smoke test for windows_core"
  output-type = "executable"
  cjc-version = "1.1.0"
  compile-option = "-lole32 -loleaut32 -lwindowsapp"

[dependencies]
  windows_core = { path = "$corePath" }
  windows_implement = { path = "$implementPath" }
"@

$main = @"
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

public class FreeProbe <: Free & CloneResource<FreeProbe> {
    public var freeCount: Int32 = 0

    public init() {}

    public func clone(): FreeProbe {
        this
    }

    public func free(): Unit {
        freeCount += 1
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

    public static func fromAbi(abi: String): Result<DemoAbiType> {
        let _ = abi
        Result<DemoAbiType>.Ok(DemoAbiType())
    }

    public static func fromDefault(defaultValue: String): Result<DemoAbiType> {
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
    resultSlot: CPointer<CPointer<Unit>>
): Result<Unit> {
    unsafe {
        if (resultSlot.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        resultSlot.write(CPointer<Unit>())
        if (riid.isNull() || target.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        match (queryInterfaceRaw(target, riid.read())) {
            case Some(raw) =>
                resultSlot.write(raw)
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
        Result<IWeakReference>.Ok(IWeakReference.fromAbiTake(weakReference.asRaw()))
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
    let callViewParam = paramValue.borrow()
    if (callViewParam.isNull()) {
        fail("ParamValue.borrow should produce a non-null InParam for concrete values")
    }
    if (callViewParam.get() != 42i32) {
        fail("InParam.get should expose the call-bound ABI value")
    }
    match (callViewParam.ok()) {
        case Ok(value) =>
            if (value != 42i32) {
                fail("InParam.ok should wrap the call-bound value in Result.Ok")
            }
        case Err(error) =>
            fail("InParam.ok should not fail for concrete values: ${error}")
    }
    match (callViewParam.as_ref()) {
        case Some(value) =>
            if (value != 42i32) {
                fail("InParam.as_ref should expose the call-bound value")
            }
        case None =>
            fail("InParam.as_ref should return Some for concrete values")
    }
    if (callViewParam.unwrap() != 42i32) {
        fail("InParam.unwrap should return the call-bound ABI value")
    }
    match (callViewParam.cloned()) {
        case Some(value) =>
            if (value != 42i32) {
                fail("InParam.cloned should preserve the call-bound value")
            }
        case None =>
            fail("InParam.cloned should return Some for concrete values")
    }
    let callBoundAbi: Int32 = callViewParam.borrow()
    if (callBoundAbi != 42i32) {
        fail("InParam.borrow should project copy values through their ABI shape")
    }
    let emptyRef = InParam<Int32>()
    if (!emptyRef.isNull()) {
        fail("InParam default construction should model an empty call-bound reference")
    }
    var emptyRefFailed = false
    try {
        emptyRef.get()
    } catch (_: IllegalStateException) {
        emptyRefFailed = true
    }
    if (!emptyRefFailed) {
        fail("InParam.get should reject empty call-bound references")
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
    let outSlot = OutSlot<Int32>()
    if (outSlot.isNull()) {
        fail("OutSlot should remain live until explicitly closed")
    }
    outSlot.write(99i32)
    match (outSlot.get()) {
        case Some(value) =>
            if (value != 99i32) {
                fail("OutSlot.write should populate the captured value")
            }
        case None =>
            fail("OutSlot.write should store a value")
    }
    outSlot.clear()
    match (outSlot.get()) {
        case Some(_) =>
            fail("OutSlot.clear should reset the captured ABI value")
        case None =>
            ()
    }
    let rawOutSlot: CPointer<Int32> = outSlot.borrowMut()
    unsafe { rawOutSlot.write(123i32) }
    if (unsafe { rawOutSlot.read() } != 123i32) {
        fail("OutSlot.borrowMut should expose a writable ABI output slot")
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
            fail("GUID.new failed unexpectedly: ${error}")
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
            fail("GUID.tryFrom failed unexpectedly: ${error}")
    }
    if (GUID.fromSignature(signatureText) != signatureGuid) {
        fail("GUID.fromSignature should route through the same signature hashing logic")
    }
    if (GUID.from_signature(signatureText) != signatureGuid) {
        fail("GUID.from_signature should share the same signature hashing logic")
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
            fail("IAgileReference Resolve dispatch failed: ${error}")
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
            fail("IWeakReference Resolve dispatch failed: ${error}")
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
                    fail("resolved weak reference should be usable: ${error}")
            }
            resolvedWeakReference.close()
        case Result<IWeakReference>.Err(error) =>
            fail("IWeakReferenceSource GetWeakReference dispatch failed: ${error}")
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

    let retainedUnknown = object.toInterface(IUnknown.descriptor())
    let unknownRef = InterfaceRef<IUnknown>.fromInterface(retainedUnknown)
    if (!samePointer(unknownRef.asRaw(), retainedUnknown.asRaw())) {
        fail("InterfaceRef.fromInterface should retain the same COM pointer")
    }
    let clonedUnknown = unknownRef.retain()
    if (!samePointer(clonedUnknown.asRaw(), retainedUnknown.asRaw())) {
        fail("InterfaceRef.retain should clone the same COM identity")
    }
    clonedUnknown.close()
    retainedUnknown.close()

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
    let scopedSlot = scopedUnknown.slotInfo()
    if (scopedSlot.instancePtr != scopedObject.asRaw().toUIntNative()) {
        fail("InterfaceResource should capture the COM instance pointer")
    }
    if (scopedSlot.vtable == UIntNative(0)) {
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
            fail("paramFromInterface upcast path failed unexpectedly: ${error}")
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
            fail("paramFromInterface QI path failed unexpectedly: ${error}")
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
    let unknownHandle = InterfaceHandle<IUnknown>(unknown.asRaw(), IUnknown.descriptor(), addRef: true)
    if (!unknownHandle.hasValue()) {
        fail("InterfaceHandle.hasValue should report a live retained handle")
    }
    let unknownView = unknownHandle.value()
    if (unknownView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
        fail("InterfaceHandle<IUnknown>.value should wrap the attached raw pointer")
    }
    unknownView.close()
    let viewUnknownProbe = IUnknown(object.asRaw())
    let afterViewUnknownClose = viewUnknownProbe.addRef()
    if (afterViewUnknownClose != 3u32) {
        fail("closing a view returned by InterfaceHandle.value should not consume the retained COM reference")
    }
    let resetViewUnknownClose = viewUnknownProbe.release()
    if (resetViewUnknownClose != 2u32) {
        fail("InterfaceHandle.value close probe should restore the reference count")
    }

    let cloned = unknownHandle.retain()
    let clonedView = cloned.value()
    if (clonedView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
        fail("InterfaceHandle.retain should preserve the wrapped raw pointer")
    }
    clonedView.close()

    let transferredHandle = unknownHandle.retain()
    let detachedRaw = transferredHandle.intoAbi()
    if (detachedRaw.toUIntNative() != object.asRaw().toUIntNative()) {
        fail("InterfaceHandle.intoAbi should yield the wrapped raw pointer")
    }
    if (transferredHandle.hasValue()) {
        fail("InterfaceHandle.intoAbi should leave the source handle empty")
    }
    transferredHandle.close()

    match (unsafe { queryInterfaceResult(object.asRaw(), IInspectable.descriptor()) }) {
        case Ok(inspectablePtr) =>
            let inspectableView = inspectablePtr.value()
            if (inspectableView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
                fail("queryInterfaceResult should return the resolved interface pointer")
            }
            inspectableView.close()
            inspectablePtr.close()
        case Err(hr) =>
            fail("queryInterfaceResult should succeed for IInspectable, got ${hr}")
    }

    match (unsafe { queryInterfaceResult(object.asRaw(), MissingInterface.descriptor()) }) {
        case Ok(_) =>
            fail("queryInterfaceResult should report HRESULT failure for unsupported interfaces")
        case Err(hr) =>
            if (hr.value != -2147467262i32) {
                fail("queryInterfaceResult should preserve E_NOINTERFACE for unsupported interfaces")
            }
    }

    match (unsafe { unknownHandle.query(IInspectable.descriptor()) }) {
        case Some(inspectablePtr) =>
            let inspectableView = inspectablePtr.value()
            if (inspectableView.asRaw().toUIntNative() != object.asRaw().toUIntNative()) {
                fail("query should wrap the same raw object for IInspectable")
            }
            let unknownSubview = inspectableView.asIUnknown()
            unknownSubview.close()
            var trustLevel = -1i32
            let trustHr = unsafe { inspectableView.getTrustLevel(CPointer<Int32>(inout trustLevel)) }
            if (trustHr.value != 0i32) {
                fail("default IInspectable trust level should report S_OK through InterfaceHandle")
            }
            if (trustLevel != 0i32) {
                fail("default IInspectable trust level should return BaseTrust")
            }
            inspectableView.close()
            let inspectableViewProbe = IUnknown(object.asRaw())
            let afterInspectableViewClose = inspectableViewProbe.addRef()
            if (afterInspectableViewClose != 6u32) {
                fail("closing views from InterfaceHandle.query should not consume the retained handle reference")
            }
            let resetInspectableViewClose = inspectableViewProbe.release()
            if (resetInspectableViewClose != 5u32) {
                fail("InterfaceHandle.query close probe should restore the reference count")
            }
            inspectablePtr.close()
        case None =>
            fail("InterfaceHandle.query should succeed for IInspectable")
    }

    cloned.close()
    unknownHandle.close()
    let detachedRelease = IUnknown(detachedRaw).release()
    if (detachedRelease != 1u32) {
        fail("transferred COM references should remain live until released explicitly")
    }
    if (unknownHandle.hasValue()) {
        fail("closed InterfaceHandle instances should report no value")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("closing InterfaceHandle instances should release their references")
    }
}
"@

Set-Content -Path (Join-Path $runnerRoot "cjpm.toml") -Value $manifest -NoNewline
Set-Content -Path (Join-Path $srcRoot "main.cj") -Value $main -NoNewline

Push-Location $runnerRoot
try {
    cjpm build | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm build failed"
    }
    $runOutput = cjpm run 2>&1 | Tee-Object -Variable coreSmokeOutput | Out-String
    $coreSmokeOutput | Out-Host
    if ($LASTEXITCODE -ne 0 -or $runOutput -match "An exception has occurred") {
        throw "cjpm run failed"
    }
}
finally {
    Pop-Location
}

Write-Host "windows-core smoke test passed."
