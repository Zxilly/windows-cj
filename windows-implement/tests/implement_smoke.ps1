$ErrorActionPreference = "Stop"

$repoRoot = "E:/Project/CS_Project/2026/ling"
$packageRoot = Join-Path $repoRoot "windows-cj/windows-implement"
$workspaceRoot = Join-Path $packageRoot "tests/output/implement_smoke"
$runnerRoot = Join-Path $workspaceRoot "runner"
$srcRoot = Join-Path $runnerRoot "src"

if (Test-Path $workspaceRoot) {
    Remove-Item -Recurse -Force $workspaceRoot
}
New-Item -ItemType Directory -Force $srcRoot | Out-Null

$manifest = @"
[package]
  name = "windows_implement_smoke"
  version = "0.1.0"
  description = "Smoke test for windows_implement"
  output-type = "executable"
  cjc-version = "1.1.0"

[dependencies]
  windows_implement = { path = "E:/Project/CS_Project/2026/ling/windows-cj/windows-implement" }
  windows_interface = { path = "E:/Project/CS_Project/2026/ling/windows-cj/windows-interface" }
"@

$main = @"
package windows_implement_smoke

import windows_implement.*
import windows_interface.*

public class SmokeFailure <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

public class DemoImpl {
    public init() {}
}

@C
public struct DemoGeneratedVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var ReadValue: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

public interface DemoGenerated_Impl {
    func readValue(): Int32
}

public class DemoGenerated <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func fromRaw(raw: CPointer<Unit>): DemoGenerated {
        DemoGenerated(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): DemoGenerated {
        DemoGenerated(raw)
    }

    public static func iid(): GUID {
        GUID(
            0x76543210u32,
            0x4321u16,
            0x4765u16,
            0x80u8,
            0x24u8,
            0x34u8,
            0x44u8,
            0x54u8,
            0x64u8,
            0x74u8,
            0x84u8
        )
    }

    public static let VTABLE: DemoGeneratedVtbl = buildDemoGeneratedVtbl()
    public static let VTABLE_HANDLE: CPointerHandle<DemoGeneratedVtbl> = unsafe { acquireArrayRawData(Array<DemoGeneratedVtbl>(1, { _ => VTABLE })) }

    public static func vtablePtr(): CPointer<Unit> {
        CPointer<Unit>(VTABLE_HANDLE.pointer)
    }

    public static func descriptor(): InterfaceDescriptor<DemoGenerated> {
        let methods = [
            InterfaceMethodSchema(
                "ReadValue",
                6,
                [InterfaceParameterSchema("result", "CPointer<Int32>", "OutRef<Int32>", InterfaceParameterBridgeKind.OutRef)],
                "Int32"
            )
        ]
        var descriptor = InterfaceDescriptor<DemoGenerated>(
            "DemoGenerated",
            DemoGenerated.iid(),
            IInspectable.descriptor(),
            { raw => DemoGenerated(raw, ownsReference: true) },
            { raw => DemoGenerated(raw) }
        )
        descriptor.methods = methods
        descriptor
    }

    public unsafe func vtbl(): DemoGeneratedVtbl {
        readVtbl<DemoGeneratedVtbl>(DemoGeneratedVtbl())
    }

    public func asIInspectable(): IInspectable {
        IInspectable(asRaw())
    }

    public unsafe func ReadValue(): Int32 {
        let v = vtbl()
        var result = 0i32
        let hr = v.ReadValue(asRaw(), CPointer<Int32>(inout result))
        HRESULT(hr).ok()
        result
    }
}

func buildDemoGeneratedVtbl(): DemoGeneratedVtbl {
    var vtbl = DemoGeneratedVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.ReadValue = DemoGeneratedReadValueThunk
    vtbl
}

@C
public func DemoGeneratedReadValueThunk(
    this_: CPointer<Unit>,
    result__: CPointer<Int32>
): Int32 {
    if (result__.isNull()) {
        return E_POINTER.value
    }
    match (unsafe { asImplFromRaw<DemoGenerated_Impl>(this_, slotOffset: 1) }) {
        case Some(impl) =>
            unsafe { result__.write(impl.readValue()) }
            S_OK.value
        case None =>
            E_NOINTERFACE.value
    }
}

public class DemoGeneratedImpl <: DemoGenerated_Impl {
    public init() {}

    public func readValue(): Int32 {
        123i32
    }
}

func fail(msg: String): Unit {
    throw SmokeFailure(msg)
}

func samePointer(left: CPointer<Unit>, right: CPointer<Unit>): Bool {
    left.toUIntNative() == right.toUIntNative()
}

func expectInspectableDefaults(raw: CPointer<Unit>): Unit {
    let unknown = IUnknown(raw)
    match (unsafe { unknown.queryRaw(IID_IINSPECTABLE) }) {
        case Some(inspectableRaw) =>
            if (!samePointer(inspectableRaw, raw)) {
                fail("IInspectable QueryInterface should resolve to the identity pointer")
            }
            let rawRelease = IUnknown(inspectableRaw).release()
            if (rawRelease != 1u32) {
                fail("releasing the raw IInspectable QueryInterface result should restore the reference count to 1")
            }
        case None =>
            fail("IInspectable QueryInterface should succeed when the identity slot is initialized")
    }

    match (unsafe { unknown.query(IInspectable.descriptor()) }) {
        case Some(inspectable) =>
            if (!samePointer(inspectable.asRaw(), raw)) {
                fail("descriptor-based IInspectable query should wrap the identity pointer")
            }
            let unknownView = inspectable.asIUnknown()
            if (!samePointer(unknownView.asRaw(), raw)) {
                fail("borrowed IUnknown upcast should preserve the identity pointer")
            }
            var trustLevel = -1i32
            let trustHr = unsafe { inspectable.getTrustLevel(CPointer<Int32>(inout trustLevel)) }
            if (trustHr.value != 0i32 || trustLevel != 0i32) {
                fail("default IInspectable trust level should return S_OK and BaseTrust")
            }
            var iidCount = 9u32
            var iidStorage = IID_IINSPECTABLE
            var iidValues = CPointer<GUID>(inout iidStorage)
            let iidsHr = unsafe {
                inspectable.getIids(
                    CPointer<UInt32>(inout iidCount),
                    CPointer<CPointer<GUID>>(inout iidValues)
                )
            }
            if (iidsHr.value != 0i32 || iidCount != 0u32 || !iidValues.isNull()) {
                fail("default IInspectable GetIids should return S_OK with an empty IID list")
            }
            var runtimeClassSeed = 9u32
            var runtimeClassName = CPointer<Unit>(CPointer<UInt32>(inout runtimeClassSeed))
            let runtimeClassHr = unsafe {
                inspectable.getRuntimeClassNameRaw(CPointer<CPointer<Unit>>(inout runtimeClassName))
            }
            if (runtimeClassHr.value != 0i32 || !runtimeClassName.isNull()) {
                fail("default IInspectable GetRuntimeClassName should return S_OK with a null HSTRING")
            }
            unknownView.close()
            let borrowedCloseProbe = IUnknown(raw)
            let afterBorrowedClose = borrowedCloseProbe.addRef()
            if (afterBorrowedClose != 3u32) {
                fail("borrowed upcast close should not consume the QueryInterface reference")
            }
            let resetBorrowedClose = borrowedCloseProbe.release()
            if (resetBorrowedClose != 2u32) {
                fail("borrowed upcast probe should restore the reference count to the owned-query state")
            }
            inspectable.close()
            let ownedCloseProbe = IUnknown(raw)
            let afterOwnedClose = ownedCloseProbe.addRef()
            if (afterOwnedClose != 2u32) {
                fail("closing the typed query wrapper should release the QueryInterface reference exactly once")
            }
            let resetOwnedClose = ownedCloseProbe.release()
            if (resetOwnedClose != 1u32) {
                fail("owned query close probe should restore the steady-state reference count")
            }
        case None =>
            fail("descriptor-based query should succeed for IInspectable")
    }
}

func expectUnsupportedQuery(raw: CPointer<Unit>): Unit {
    let unknown = IUnknown(raw)
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
    match (unsafe { unknown.queryRaw(missingIid) }) {
        case Some(_) =>
            fail("unsupported QueryInterface should not produce a raw pointer")
        case None => ()
    }
    let missingDescriptor = InterfaceDescriptor<IUnknown>("MissingIUnknown", missingIid, { ptr => IUnknown(ptr, ownsReference: true) }, { ptr => IUnknown(ptr) })
    match (unsafe { unknown.query(missingDescriptor) }) {
        case Some(_) =>
            fail("unsupported descriptor-based query should not wrap a pointer")
        case None => ()
    }
}

func expectNullPointerErrors(raw: CPointer<Unit>): Unit {
    var iid = IID_IINSPECTABLE
    let nullResultHr = unsafe {
        iunknownQueryInterfaceThunk(
            raw,
            CPointer<GUID>(inout iid),
            CPointer<CPointer<Unit>>()
        )
    }
    if (nullResultHr != E_POINTER) {
        fail("QueryInterface should return E_POINTER when ppvObject is null")
    }

    var nullIidResult = raw
    let nullIidHr = unsafe {
        iunknownQueryInterfaceThunk(
            raw,
            CPointer<GUID>(),
            CPointer<CPointer<Unit>>(inout nullIidResult)
        )
    }
    if (nullIidHr != E_POINTER) {
        fail("QueryInterface should return E_POINTER when iid is null")
    }
    if (!nullIidResult.isNull()) {
        fail("QueryInterface should null out the result storage when iid is null")
    }
}

func expectDefaultIUnknownOnly(): Unit {
    var object = createComObject(DemoImpl(), [IID_IUNKNOWN])
    let probe = IUnknown(object.asRaw())
    let addRefCount = probe.addRef()
    if (addRefCount != 2u32) {
        fail("createComObject without an explicit vtable should still expose a live IUnknown slot")
    }
    let releaseCount = probe.release()
    if (releaseCount != 1u32) {
        fail("default IUnknown-only object should restore the reference count to 1")
    }
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("IUnknown-only object should release cleanly")
    }
}

func expectDefaultSchemaPath(): Unit {
    let supported = Array<InterfaceDescriptorSchema>(1, { _ => IInspectable.descriptorSchema() })
    var object = createComObjectFromSchemas(DemoImpl(), supported)
    expectInspectableDefaults(object.asRaw())
    expectUnsupportedQuery(object.asRaw())
    expectNullPointerErrors(object.asRaw())
    let finalProbe = IUnknown(object.asRaw())
    let addRefCount = finalProbe.addRef()
    if (addRefCount != 2u32) {
        fail("AddRef thunk should increment the schema-backed identity reference count to 2")
    }
    let releaseCount = finalProbe.release()
    if (releaseCount != 1u32) {
        fail("Release thunk should decrement the schema-backed identity reference count to 1")
    }
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("schema-backed object should release cleanly")
    }
}

func expectDefaultDescriptorPath(): Unit {
    let descriptors = Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() })
    var object = createComObjectFromDescriptors(DemoImpl(), descriptors)
    match (unsafe { IUnknown(object.asRaw()).query(IInspectable.descriptor()) }) {
        case Some(inspectable) =>
            if (!samePointer(inspectable.asRaw(), object.asRaw())) {
                fail("descriptor-backed object should expose the identity pointer without an explicit vtable")
            }
            inspectable.close()
        case None =>
            fail("descriptor-backed object should answer QueryInterface for IInspectable")
    }
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("descriptor-backed object should release cleanly")
    }
}

func expectGeneratedDescriptorThunkVtable(): Unit {
    let descriptors = Array<InterfaceDescriptor<DemoGenerated>>(1, { _ => DemoGenerated.descriptor() })
    var object = createComObjectFromDescriptors(DemoGeneratedImpl(), descriptors)
    let identityUnknown = IUnknown(object.asRaw())

    match (unsafe { identityUnknown.query(DemoGenerated.descriptor()) }) {
        case Some(generated) =>
            let slotVtblPtr = unsafe { CPointer<CPointer<Unit>>(generated.asRaw()).read() }
            if (!samePointer(slotVtblPtr, DemoGenerated.vtablePtr())) {
                fail("descriptor-backed object should wire the generated thunk vtable when no explicit vtblPtrs are supplied")
            }
            let value = unsafe { generated.ReadValue() }
            if (value != 123i32) {
                fail("generated thunk vtable should dispatch through the implementation object")
            }
            generated.close()
        case None =>
            fail("descriptor-backed object should answer QueryInterface for the generated interface")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("generated descriptor-backed object should release cleanly")
    }
}

func expectMultipleInterfaceSlots(): Unit {
    let alphaIid = GUID(
        0x01234567u32,
        0x89ABu16,
        0x4CDEu16,
        0x80u8,
        0x11u8,
        0x22u8,
        0x33u8,
        0x44u8,
        0x55u8,
        0x66u8,
        0x77u8
    )
    let betaIid = GUID(
        0x89ABCDEFu32,
        0x0123u16,
        0x4A67u16,
        0x90u8,
        0x10u8,
        0x20u8,
        0x30u8,
        0x40u8,
        0x50u8,
        0x60u8,
        0x70u8
    )
    let alphaDescriptor = InterfaceDescriptor<IUnknown>(
        "IAlpha",
        alphaIid,
        [IID_IINSPECTABLE, IID_IUNKNOWN],
        { ptr => IUnknown(ptr, ownsReference: true) },
        { ptr => IUnknown(ptr) }
    )
    let betaDescriptor = InterfaceDescriptor<IUnknown>(
        "IBeta",
        betaIid,
        [IID_IINSPECTABLE, IID_IUNKNOWN],
        { ptr => IUnknown(ptr, ownsReference: true) },
        { ptr => IUnknown(ptr) }
    )
    let descriptors = Array<InterfaceDescriptor<IUnknown>>(2, { index =>
        if (index == 0) {
            alphaDescriptor
        } else {
            betaDescriptor
        }
    })

    var alphaVtbl = buildIUnknownVtbl()
    var betaVtbl = buildIUnknownVtbl()
    let alphaVtblPtr = CPointer<Unit>(CPointer<IUnknownVtbl>(inout alphaVtbl))
    let betaVtblPtr = CPointer<Unit>(CPointer<IUnknownVtbl>(inout betaVtbl))
    let interfaceVtables = Array<CPointer<Unit>>(2, { index =>
        if (index == 0) {
            alphaVtblPtr
        } else {
            betaVtblPtr
        }
    })

    var object = createComObjectFromDescriptors(DemoImpl(), descriptors, interfaceVtables)
    let identityUnknown = IUnknown(object.asRaw())

    match (unsafe { identityUnknown.query(alphaDescriptor) }) {
        case Some(alpha) =>
            if (samePointer(alpha.asRaw(), object.asRaw())) {
                fail("custom interface QueryInterface should not return the identity pointer")
            }

            let aliasProbe = IUnknown(alpha.asRaw())
            let aliasAddRef = aliasProbe.addRef()
            if (aliasAddRef != 3u32) {
                fail("AddRef through a non-identity interface slot should resolve the same runtime")
            }
            let aliasRelease = aliasProbe.release()
            if (aliasRelease != 2u32) {
                fail("Release through a non-identity interface slot should restore the prior reference count")
            }

            match (unsafe { identityUnknown.query(betaDescriptor) }) {
                case Some(beta) =>
                    if (samePointer(beta.asRaw(), object.asRaw()) || samePointer(beta.asRaw(), alpha.asRaw())) {
                        fail("different interface IIDs should resolve to different COM interface pointers")
                    }

                    match (unsafe { alpha.query(betaDescriptor) }) {
                        case Some(betaFromAlpha) =>
                            if (!samePointer(betaFromAlpha.asRaw(), beta.asRaw())) {
                                fail("QueryInterface from one custom slot to another should return the target slot pointer")
                            }
                            betaFromAlpha.close()
                        case None =>
                            fail("custom interface slot should be able to QueryInterface to another custom slot")
                    }

                    match (unsafe { beta.query(alphaDescriptor) }) {
                        case Some(alphaFromBeta) =>
                            if (!samePointer(alphaFromBeta.asRaw(), alpha.asRaw())) {
                                fail("reverse custom QueryInterface should resolve to the original custom slot")
                            }
                            alphaFromBeta.close()
                        case None =>
                            fail("reverse custom QueryInterface should succeed")
                    }

                    match (unsafe { alpha.query(IInspectable.descriptor()) }) {
                        case Some(inspectable) =>
                            if (!samePointer(inspectable.asRaw(), object.asRaw())) {
                                fail("QueryInterface to IInspectable should still resolve to the identity pointer")
                            }
                            inspectable.close()
                        case None =>
                            fail("custom interface slot should be able to QueryInterface to IInspectable")
                    }

                    beta.close()
                case None =>
                    fail("identity pointer should be able to QueryInterface to the second custom interface")
            }

            alpha.close()
        case None =>
            fail("identity pointer should be able to QueryInterface to the first custom interface")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("multi-interface object should release cleanly")
    }
}

main(_args: Array<String>) {
    expectDefaultIUnknownOnly()
    expectDefaultSchemaPath()
    expectDefaultDescriptorPath()
    expectGeneratedDescriptorThunkVtable()
    expectMultipleInterfaceSlots()
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
    $runOutput = cjpm run 2>&1 | Tee-Object -Variable implementSmokeOutput | Out-String
    $implementSmokeOutput | Out-Host
    if ($LASTEXITCODE -ne 0 -or $runOutput -match "An exception has occurred") {
        throw "cjpm run failed"
    }
}
finally {
    Pop-Location
}

Write-Host "windows-implement smoke test passed."
