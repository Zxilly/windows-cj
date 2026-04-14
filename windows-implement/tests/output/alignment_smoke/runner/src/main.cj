package windows_implement_alignment_smoke

import windows_implement.*
import windows_interface.*

public class DemoFailure <: Exception {
    public init(message: String) {
        super(message)
    }
}

public class DemoRuntimeName <: RuntimeName {
    public static func runtimeName(): String {
        "Demo.Component.Runtime"
    }
}

public class DemoImpl {
    public var value: Int32

    public init(value!: Int32 = 0i32) {
        this.value = value
    }
}

public interface DemoOuter_Impl {
    func readValue(): Int32
}

public class DemoOuter <: DemoOuter_Impl {
    public let inner: DemoImpl

    public init(inner: DemoImpl) {
        this.inner = inner
    }

    public func readValue(): Int32 {
        inner.value
    }
}

@C
public struct DemoCallbackVtbl {
    public var Invoke: CFunc<(CPointer<Unit>, Int32) -> Int32> = { _, value => value }
    public init() {}
}

public interface DemoCallback_Impl {
    func invoke(value: Int32): Int32
}

public class DemoCallbackTarget <: DemoCallback_Impl {
    public var lastValue: Int32 = 0i32

    public func invoke(value: Int32): Int32 {
        lastValue = value
        value + 1i32
    }
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

@C
public struct IChildPriorityBaseVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public init() {}
}

func buildIChildPriorityBaseVtbl(): IChildPriorityBaseVtbl {
    var vtbl = IChildPriorityBaseVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl
}

public class IChildPriorityBase <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        GUID(
            0x44445555u32,
            0x6666u16,
            0x4777u16,
            0x80u8,
            0x88u8,
            0x99u8,
            0xAAu8,
            0xBBu8,
            0xCCu8,
            0xDDu8,
            0xEEu8
        )
    }

    public static func descriptor(): InterfaceDescriptor<IChildPriorityBase> {
        InterfaceDescriptor<IChildPriorityBase>(
            "IChildPriorityBase",
            IChildPriorityBase.iid(),
            IInspectable.descriptor(),
            { raw => IChildPriorityBase(raw, ownsReference: true) },
            { raw => IChildPriorityBase(raw) }
        )
    }

    public static let VTABLE: IChildPriorityBaseVtbl = buildIChildPriorityBaseVtbl()
    public static let VTABLE_HANDLE: CPointerHandle<IChildPriorityBaseVtbl> = unsafe { acquireArrayRawData(Array<IChildPriorityBaseVtbl>(1, { _ => VTABLE })) }

    public static func vtablePtr(): CPointer<Unit> {
        CPointer<Unit>(VTABLE_HANDLE.pointer)
    }
}

@C
public struct IChildPriorityLeafVtbl {
    public var base_: IChildPriorityBaseVtbl = IChildPriorityBaseVtbl()
    public init() {}
}

func buildIChildPriorityLeafVtbl(): IChildPriorityLeafVtbl {
    var vtbl = IChildPriorityLeafVtbl()
    vtbl.base_ = buildIChildPriorityBaseVtbl()
    vtbl
}

public class IChildPriorityLeaf <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        GUID(
            0x55556666u32,
            0x7777u16,
            0x4888u16,
            0x80u8,
            0x99u8,
            0xAAu8,
            0xBBu8,
            0xCCu8,
            0xDDu8,
            0xEEu8,
            0xFFu8
        )
    }

    public static func descriptor(): InterfaceDescriptor<IChildPriorityLeaf> {
        InterfaceDescriptor<IChildPriorityLeaf>(
            "IChildPriorityLeaf",
            IChildPriorityLeaf.iid(),
            IChildPriorityBase.descriptor(),
            { raw => IChildPriorityLeaf(raw, ownsReference: true) },
            { raw => IChildPriorityLeaf(raw) }
        )
    }

    public static let VTABLE: IChildPriorityLeafVtbl = buildIChildPriorityLeafVtbl()
    public static let VTABLE_HANDLE: CPointerHandle<IChildPriorityLeafVtbl> = unsafe { acquireArrayRawData(Array<IChildPriorityLeafVtbl>(1, { _ => VTABLE })) }

    public static func vtablePtr(): CPointer<Unit> {
        CPointer<Unit>(VTABLE_HANDLE.pointer)
    }
}

func fail(message: String): Unit {
    throw DemoFailure(message)
}

func expect(cond: Bool, message: String): Unit {
    if (!cond) {
        fail(message)
    }
}

func samePointer(left: CPointer<Unit>, right: CPointer<Unit>): Bool {
    left.toUIntNative() == right.toUIntNative()
}

let GLOBAL_STATIC_OBJECT = createStaticComObjectFromDescriptors(
    DemoImpl(value: 55i32),
    Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() })
)

func makeCustomDescriptor(name: String, iid: GUID): InterfaceDescriptor<IUnknown> {
    InterfaceDescriptor<IUnknown>(
        name,
        iid,
        [IID_IINSPECTABLE, IID_IUNKNOWN],
        { ptr => IUnknown(ptr, ownsReference: true) },
        { ptr => IUnknown(ptr) }
    )
}

func makeAlphaDescriptor(): InterfaceDescriptor<IUnknown> {
    makeCustomDescriptor(
        "IAlpha",
        GUID(
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
    )
}

func makeBaseDescriptor(): InterfaceDescriptor<IUnknown> {
    makeCustomDescriptor(
        "IBaseChain",
        GUID(
            0x11112222u32,
            0x3333u16,
            0x4444u16,
            0x80u8,
            0x55u8,
            0x66u8,
            0x77u8,
            0x88u8,
            0x99u8,
            0xAAu8,
            0xBBu8
        )
    )
}

func makeDerivedDescriptor(base: InterfaceDescriptor<IUnknown>): InterfaceDescriptor<IUnknown> {
    InterfaceDescriptor<IUnknown>(
        "IDerivedChain",
        GUID(
            0x22223333u32,
            0x4444u16,
            0x5555u16,
            0x80u8,
            0x66u8,
            0x77u8,
            0x88u8,
            0x99u8,
            0xAAu8,
            0xBBu8,
            0xCCu8
        ),
        base,
        { ptr => IUnknown(ptr, ownsReference: true) },
        { ptr => IUnknown(ptr) }
    )
}

func makeLeafDescriptor(base: InterfaceDescriptor<IUnknown>): InterfaceDescriptor<IUnknown> {
    InterfaceDescriptor<IUnknown>(
        "ILeafChain",
        GUID(
            0x33334444u32,
            0x5555u16,
            0x6666u16,
            0x80u8,
            0x77u8,
            0x88u8,
            0x99u8,
            0xAAu8,
            0xBBu8,
            0xCCu8,
            0xDDu8
        ),
        base,
        { ptr => IUnknown(ptr, ownsReference: true) },
        { ptr => IUnknown(ptr) }
    )
}

func makeValueMethod(name: String, abiSlot: Int64): InterfaceMethodSchema {
    InterfaceMethodSchema(
        name,
        abiSlot,
        [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
        "Int32"
    )
}

func expectOuterSlotLayoutAndAsImplOffset(): Unit {
    let alphaDescriptor = makeAlphaDescriptor()
    let descriptors = Array<InterfaceDescriptor<IUnknown>>(1, { _ => alphaDescriptor })

    let alphaVtblHandle = unsafe { acquireArrayRawData(Array<IUnknownVtbl>(1, { _ => buildIUnknownVtbl() })) }
    let interfaceVtables = Array<CPointer<Unit>>(1, { _ => CPointer<Unit>(alphaVtblHandle.pointer) })
    var object = createComObjectFromDescriptors(DemoImpl(value: 91i32), descriptors, interfaceVtables)

    match (unsafe { IUnknown(object.asRaw()).query(alphaDescriptor) }) {
        case Some(alpha) =>
            let identityAddress = object.asRaw().toUIntNative()
            let alphaAddress = alpha.asRaw().toUIntNative()
            expect(alphaAddress - identityAddress == sizeOf<UIntNative>(), "custom interface slots should be laid out inline at pointer-sized offsets")

            comSlotRegistryRemove(alpha.asRaw().toUIntNative())
            match (unsafe { asImplFromRaw<DemoImpl>(alpha.asRaw(), slotOffset: 1) }) {
                case Some(inner) =>
                    expect(inner.value == 91i32, "AsImpl raw recovery should subtract the slot offset instead of relying on the slot registry")
                case None =>
                    fail("AsImpl raw recovery should succeed after removing the slot-registry entry")
            }
            comSlotRegistryInsert(alpha.asRaw().toUIntNative(), object.asRaw().toUIntNative())
            alpha.close()
        case None =>
            fail("identity pointer should be able to QueryInterface to the inline custom slot")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    expect(finalCount == 0u32, "inline-slot-layout test object should release cleanly")
    unsafe { releaseArrayRawData(alphaVtblHandle) }
}

func expectAsImpl(): Unit {
    var object = createComObjectFromDescriptors(
        DemoImpl(value: 7i32),
        Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() })
    )

    match (unsafe { asImpl<DemoImpl>(IUnknown(object.asRaw())) }) {
        case Some(inner) =>
            expect(inner.value == 7i32, "AsImpl should recover the implementation object")
            inner.value = 42i32
        case None =>
            fail("AsImpl should recover the implementation object from the identity interface")
    }

    match (unsafe { asImplFromRaw<DemoImpl>(object.asRaw()) }) {
        case Some(inner) =>
            expect(inner.value == 42i32, "AsImpl raw recovery should observe mutations through the implementation reference")
        case None =>
            fail("AsImpl raw recovery should succeed for the identity pointer")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    expect(finalCount == 0u32, "AsImpl test object should release cleanly")
}

func expectOuterImplBinding(): Unit {
    let inner = DemoImpl(value: 13i32)
    let outer = DemoOuter(inner)
    let object = createComObjectFromDescriptors(
        inner,
        Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() })
    ).bindOuterObject(outer)

    match (unsafe { asImplFromRaw<DemoOuter_Impl>(object.asRaw()) }) {
        case Some(boundOuter) =>
            expect(boundOuter.readValue() == 13i32, "_Impl lookup should bind to the explicit outer carrier before the inner payload")
        case None =>
            fail("_Impl lookup should recover the explicit outer carrier")
    }

    match (unsafe { asImplFromRaw<DemoImpl>(object.asRaw()) }) {
        case Some(boundInner) =>
            boundInner.value = 29i32
            expect(outer.readValue() == 29i32, "outer and inner bindings should continue to share the same underlying payload")
        case None =>
            fail("inner payload lookup should remain available alongside the outer carrier")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    expect(finalCount == 0u32, "outer-binding test object should release cleanly")
}

func expectInterfaceResourceAsImplFallback(): Unit {
    let descriptor = AbiReferenceDescriptor<DemoCallbackView>(
        "DemoCallback",
        { raw => DemoCallbackView(raw) },
        { raw => DemoCallbackView(raw) }
    )
    let vtblHandle = unsafe { acquireArrayRawData(Array<DemoCallbackVtbl>(1, { _ => DemoCallbackVtbl() })) }
    let target = DemoCallbackTarget()
    let scoped = unsafe {
        createInterfaceResourceFromTarget(
            descriptor,
            target,
            CPointer<Unit>(vtblHandle.pointer)
        )
    }
    let raw = scoped.asRaw()

    match (unsafe { asImplFromRaw<DemoCallback_Impl>(raw) }) {
        case Some(callback) =>
            expect(callback.invoke(8i32) == 9i32, "asImplFromRaw should recover target-backed non-COM implementations")
            expect(target.lastValue == 8i32, "target-backed non-COM lookup should surface the original target object")
        case None =>
            fail("asImplFromRaw should fall back to the target-backed scoped-interface registry")
    }

    scoped.close()

    match (unsafe { asImplFromRaw<DemoCallback_Impl>(raw) }) {
        case Some(_) =>
            fail("closing a target-backed InterfaceResource should remove the raw-to-target lookup")
        case None => ()
    }

}

func expectStaticComObject(): Unit {
    let raw = GLOBAL_STATIC_OBJECT.asRaw()
    expect(raw.isNotNull(), "StaticComObject should expose a stable identity pointer")
    expect(samePointer(raw, GLOBAL_STATIC_OBJECT.asRaw()), "StaticComObject should expose the same identity pointer on repeated access")

    let probe = IUnknown(raw)
    let addRefCount = probe.addRef()
    expect(addRefCount == 2u32, "StaticComObject should participate in COM reference counting")
    let releaseCount = probe.release()
    expect(releaseCount == 1u32, "StaticComObject AddRef/Release should round-trip cleanly")

    let floorProbe = IUnknown(raw)
    let floorCount = floorProbe.release()
    expect(floorCount == 1u32, "StaticComObject should keep an immortal static reference instead of dropping to zero")
}

func expectWeakReferences(): Unit {
    var object = createComObjectFromDescriptors(
        DemoImpl(value: 11i32),
        Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() })
    )
    let identity = IUnknown(object.asRaw())

    match (unsafe { identity.query(IWeakReferenceSource.descriptor()) }) {
        case Some(source) =>
            match (unsafe { source.getWeakReference() }) {
                case Some(weak) =>
                    match (unsafe { weak.resolve(IInspectable.descriptor()) }) {
                        case Some(resolved) =>
                            expect(samePointer(resolved.asRaw(), object.asRaw()), "weak resolve should return the live object identity")
                            resolved.close()
                        case None =>
                            fail("weak resolve should succeed while the strong object is alive")
                    }

                    let finalCount = IUnknown(object.asRaw()).release()
                    expect(finalCount == 1u32, "weak-reference source views should retain one outstanding strong reference until they are closed")

                    source.close()
                    let drainedCount = IUnknown(object.asRaw()).release()
                    expect(drainedCount == 0u32, "closing the weak-reference source view should allow the final strong reference to drain")

                    match (unsafe { weak.resolve(IInspectable.descriptor()) }) {
                        case Some(_) =>
                            fail("weak resolve should return None after the strong object is destroyed")
                        case None => ()
                    }

                    weak.close()
                case None =>
                    fail("IWeakReferenceSource should be able to create an IWeakReference")
            }
        case None =>
            fail("QueryInterface should expose IWeakReferenceSource automatically")
    }
}

func expectAgileQueries(): Unit {
    var object = createComObjectFromDescriptors(
        DemoImpl(value: 21i32),
        Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() })
    )
    let identity = IUnknown(object.asRaw())

    match (unsafe { identity.query(IAgileObject.descriptor()) }) {
        case Some(agile) =>
            expect(samePointer(agile.asRaw(), object.asRaw()), "IAgileObject should resolve to the identity pointer")
            agile.close()
        case None =>
            fail("QueryInterface should expose IAgileObject automatically")
    }

    match (unsafe { identity.query(IMarshal.descriptor()) }) {
        case Some(marshal) =>
            expect(marshal.asRaw().isNotNull(), "IMarshal should expose a non-null marshaler tear-off")
            marshal.close()
        case None =>
            fail("QueryInterface should expose IMarshal automatically")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount == 1u32) {
        let drainedCount = IUnknown(object.asRaw()).release()
        expect(drainedCount == 0u32, "agile marshaler caches should not prevent the final strong reference from draining")
    } else {
        expect(finalCount == 0u32, "agile test object should release cleanly")
    }
}

func expectExplicitAgileFlag(): Unit {
    var object = createComObjectFromDescriptors(
        DemoImpl(value: 23i32),
        Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() }),
        agile: false
    )
    let identity = IUnknown(object.asRaw())

    match (unsafe { identity.query(IAgileObject.descriptor()) }) {
        case Some(_) =>
            fail("explicit agile: false should suppress IAgileObject")
        case None => ()
    }
    match (unsafe { identity.query(IMarshal.descriptor()) }) {
        case Some(_) =>
            fail("explicit agile: false should suppress IMarshal")
        case None => ()
    }

    let finalCount = IUnknown(object.asRaw()).release()
    expect(finalCount == 0u32, "non-agile test object should release cleanly")
}

func expectRuntimeClassName(): Unit {
    var object = createComObjectFromDescriptors(
        DemoImpl(value: 31i32),
        Array<InterfaceDescriptor<IInspectable>>(1, { _ => IInspectable.descriptor() })
    )
    object.runtime.setRuntimeType(runtimeTypeFromName<DemoRuntimeName>())

    let inspectable = IInspectable(object.asRaw())
    var rawName = CPointer<Unit>()
    let hr = unsafe {
        inspectable.getRuntimeClassNameRaw(CPointer<CPointer<Unit>>(inout rawName))
    }
    expect(hr.value == 0i32, "GetRuntimeClassName should return S_OK after RuntimeName registration")
    expect(rawName.isNotNull(), "GetRuntimeClassName should produce a non-null HSTRING handle after RuntimeName registration")
    expect(samePointer(rawName, object.runtime.runtimeClassNameRaw()), "GetRuntimeClassName should surface the runtime-managed HSTRING handle")

    let finalCount = IUnknown(object.asRaw()).release()
    expect(finalCount == 0u32, "runtime-class-name test object should release cleanly")
}

func expectDescriptorCodegen(): Unit {
    let methods = Array<InterfaceMethodSchema>(3, { index =>
        if (index == 0) {
            InterfaceMethodSchema(
                "GetValue",
                6,
                [
                    InterfaceParameterSchema(
                        "source",
                        "CPointer<Unit>",
                        "Ref<IInspectable>",
                        InterfaceParameterBridgeKind.Ref
                    ),
                    InterfaceParameterSchema(
                        "value",
                        "CPointer<Int32>",
                        "OutRef<Int32>",
                        InterfaceParameterBridgeKind.OutRef
                    )
                ],
                "Int32"
            )
        } else if (index == 1) {
            InterfaceMethodSchema(
                "ReadValue",
                7,
                [InterfaceParameterSchema("result", "CPointer<Int32>", "OutRef<Int32>", InterfaceParameterBridgeKind.OutRef)],
                "Int32"
            )
        } else {
            InterfaceMethodSchema(
                "SetValue",
                8,
                [
                    InterfaceParameterSchema(
                        "value",
                        "Int32",
                        "Int32",
                        InterfaceParameterBridgeKind.Value
                    ),
                    InterfaceParameterSchema(
                        "commit",
                        "Bool",
                        "Bool",
                        InterfaceParameterBridgeKind.Value
                    )
                ],
                "Int32"
            )
        }
    })
    var schema = InterfaceDescriptorSchema(
        "IDemoGenerated",
        GUID(
            0x87654321u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xA2u8
        ),
        IInspectable.descriptorSchema(),
        "IDemoGeneratedVtbl",
        "IDemoGenerated",
        "IDemoGenerated_Impl",
        methods
    )
    schema.runtimeTypeContract = Some(RuntimeTypeContract("Demo.Component.Runtime", "Demo.Component.Signature", schema.iid))
    let rendered = renderDescriptor(createResolvedDescriptor(schema))

    expect(rendered.contains("public static func descriptor(): InterfaceDescriptor<IDemoGenerated> {\n        let methods = "), "descriptor codegen should materialize methods before assigning them in descriptor()")
    expect(rendered.contains("descriptor.methods = methods"), "descriptor codegen should preserve InterfaceDescriptor method metadata")
    expect(rendered.contains("public interface IDemoGenerated_Impl"), "descriptor codegen should emit the _Impl surface")
    expect(rendered.contains("public var GetValue"), "descriptor codegen should emit the vtable slot field for GetValue")
    expect(rendered.contains("public func IDemoGenerated_GetValueThunk"), "descriptor codegen should emit a thunk for GetValue")
    expect(rendered.contains("public func IDemoGenerated_ReadValueThunk"), "descriptor codegen should emit a thunk for bridged Result returns")
    expect(rendered.contains("public func IDemoGenerated_SetValueThunk"), "descriptor codegen should emit a thunk for SetValue")
    expect(rendered.contains("borrow()"), "descriptor codegen should bridge Ref parameters through borrow()")
    expect(rendered.contains("borrowMut()"), "descriptor codegen should bridge OutRef parameters through borrowMut()")
    expect(rendered.contains("func ReadValue(): windows_result.Result<Int32>"), "descriptor codegen should fully qualify Result<T> on the _Impl trait")
    expect(rendered.contains("public unsafe func ReadValue(): Int32"), "descriptor codegen should expose the bridged result as a direct caller-side return")
    expect(rendered.contains("let hr = v.ReadValue(asRaw(), CPointer<Int32>(inout result))"), "descriptor codegen should synthesize the hidden out parameter for Result<T> caller bridges")
    expect(rendered.contains("windows_result.HRESULT(hr).ok()"), "descriptor codegen should fully qualify HRESULT helpers in caller wrappers")
    expect(rendered.contains("case windows_result.Result<Int32>.Ok(value) =>"), "descriptor codegen should fully qualify Result.Ok matches in dispatch thunks")
    expect(rendered.contains("case windows_result.Result<Int32>.Err(error) =>"), "descriptor codegen should fully qualify Result.Err matches in dispatch thunks")
    expect(rendered.contains("public static func signature(): String"), "descriptor codegen should emit RuntimeType signature metadata")
    expect(rendered.contains("\"Demo.Component.Signature\""), "descriptor codegen should preserve the declared runtime signature string")
    expect(rendered.contains("public static func runtimeType(): RuntimeTypeContract"), "descriptor codegen should emit RuntimeTypeContract metadata")
    expect(rendered.contains("RuntimeTypeContract(\"Demo.Component.Runtime\", IDemoGenerated.signature(), GUID.parse(\"87654321-4321-4876-8042-5262728292A2\"))"), "descriptor codegen should preserve the runtime name, signature and default interface IID")
    expect(rendered.contains("public static let VTABLE_HANDLE"), "descriptor codegen should materialize a static vtable allocation for COM wrappers")
    expect(rendered.contains("public static func vtablePtr(): CPointer<Unit>"), "descriptor codegen should expose a static vtable pointer helper for COM wrappers")
    expect(rendered.contains("public func clone()"), "descriptor codegen should emit clone support on wrappers")
    expect(rendered.contains("operator func =="), "descriptor codegen should emit equality support on wrappers")
    expect(rendered.contains("public func toString()"), "descriptor codegen should emit debug/toString support on wrappers")

    let unsortedMethods = [
        InterfaceMethodSchema(
            "Later",
            7,
            [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
            "Int32"
        ),
        InterfaceMethodSchema(
            "Earlier",
            6,
            [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
            "Int32"
        )
    ]
    let unsortedSchema = InterfaceDescriptorSchema(
        "IDemoSorted",
        GUID(
            0x87654320u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xA1u8
        ),
        IInspectable.descriptorSchema(),
        "IDemoSortedVtbl",
        "IDemoSorted",
        "IDemoSorted_Impl",
        unsortedMethods
    )
    let resolved = createResolvedDescriptor(unsortedSchema)
    expect(resolved.methods[0].abiSlot == 6, "resolved descriptors should sort methods by abiSlot before codegen")
    expect(resolved.methods[1].abiSlot == 7, "resolved descriptors should keep abi slots contiguous after sorting")

    let autoSlotsSchema = InterfaceDescriptorSchema(
        "IDemoAutoSlots",
        GUID(
            0x87654321u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xA2u8
        ),
        IInspectable.descriptorSchema(),
        "IDemoAutoSlotsVtbl",
        "IDemoAutoSlots",
        "IDemoAutoSlots_Impl",
        [
            InterfaceMethodSchema(
                "AutoFirst",
                [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
                "Int32"
            ),
            InterfaceMethodSchema(
                "AutoSecond",
                [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
                "Int32"
            )
        ]
    )
    let autoResolved = createResolvedDescriptor(autoSlotsSchema)
    expect(autoResolved.methods[0].abiSlot == 6, "automatic abi slots should start after the inherited prefix")
    expect(autoResolved.methods[1].abiSlot == 7, "automatic abi slots should follow declaration order")

    let gappedSchema = InterfaceDescriptorSchema(
        "IDemoGap",
        GUID(
            0x87654322u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xA3u8
        ),
        IInspectable.descriptorSchema(),
        "IDemoGapVtbl",
        "IDemoGap",
        "IDemoGap_Impl",
        [
            InterfaceMethodSchema(
                "Gap",
                8,
                [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
                "Int32"
            )
        ]
    )
    var rejectedGap = false
    try {
        createResolvedDescriptor(gappedSchema)
    } catch (_: IllegalArgumentException) {
        rejectedGap = true
    }
    expect(rejectedGap, "abiSlot validation should reject gaps after the inherited vtable prefix")

    let nonComRendered = renderDescriptor(
        createResolvedDescriptor(
            InterfaceDescriptorSchema(
                "IDemoCallback",
                GUID(
                    0x87654323u32,
                    0x4321u16,
                    0x4876u16,
                    0x80u8,
                    0x42u8,
                    0x52u8,
                    0x62u8,
                    0x72u8,
                    0x82u8,
                    0x92u8,
                    0xA4u8
                ),
                "IDemoCallbackVtbl",
                "IDemoCallback",
                "IDemoCallback_Impl",
                [
                    InterfaceMethodSchema(
                        "Invoke",
                        0,
                        [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value)],
                        "Unit"
                    )
                ]
            )
        )
    )
    expect(nonComRendered.contains("InterfaceResource"), "non-COM descriptor codegen should route construction through InterfaceResource")
    expect(nonComRendered.contains("public static func new<"), "non-COM descriptor codegen should emit a static new(this) wrapper")
    expect(nonComRendered.contains("createInterfaceResourceFromTarget"), "non-COM descriptor codegen should allocate target-backed scoped interfaces instead of placeholder raw views")
    expect(nonComRendered.contains("public static let VTABLE_HANDLE"), "non-COM descriptor codegen should materialize a static vtable allocation")

    let descriptor = InterfaceDescriptor<IUnknown>(
        "IDemoDescriptor",
        GUID(
            0x87654324u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xA5u8
        ),
        IInspectable.descriptor(),
        { raw => IUnknown(raw, ownsReference: true) },
        { raw => IUnknown(raw) }
    )
    descriptor.methods = [makeValueMethod("DescriptorOnly", 6)]
    let descriptorResolved = createResolvedDescriptor(descriptor)
    expect(descriptorResolved.methods.size == 1, "resolved descriptors should preserve methods copied from InterfaceDescriptor")
    expect(descriptorResolved.methods[0].name == "DescriptorOnly", "resolved descriptors should preserve InterfaceDescriptor method metadata")
}

func expectBuiltinSchemaBaseSlots(): Unit {
    let shadowUnknownBase = InterfaceDescriptorSchema(
        "IShadowUnknown",
        IID_IUNKNOWN,
        "IShadowUnknownVtbl",
        "IShadowUnknown",
        "IShadowUnknown_Impl",
        [InterfaceMethodSchema("ShadowUnknownValue", Array<String>(0, { _ => "" }), "Int32")]
    )
    let unknownDerived = InterfaceDescriptorSchema(
        "IUnknownShadowChild",
        GUID(
            0x87654328u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xA9u8
        ),
        shadowUnknownBase,
        "IUnknownShadowChildVtbl",
        "IUnknownShadowChild",
        "IUnknownShadowChild_Impl",
        [InterfaceMethodSchema("ReadUnknownShadow", Array<String>(0, { _ => "" }), "Int32")]
    )
    let unknownResolved = createResolvedDescriptor(unknownDerived)
    expect(unknownResolved.abiPrefixSlotCount == 3, "schemas that inherit from an IUnknown-shaped base should keep the fixed 3-slot ABI prefix")
    expect(unknownResolved.methods[0].abiSlot == 3, "IUnknown-shaped schema bases should not inherit synthetic extra slots")

    let shadowInspectableBase = InterfaceDescriptorSchema(
        "IShadowInspectable",
        IID_IINSPECTABLE,
        IUnknown.descriptorSchema(),
        "IShadowInspectableVtbl",
        "IShadowInspectable",
        "IShadowInspectable_Impl",
        [InterfaceMethodSchema("ShadowInspectableValue", Array<String>(0, { _ => "" }), "Int32")]
    )
    let inspectableDerived = InterfaceDescriptorSchema(
        "IInspectableShadowChild",
        GUID(
            0x87654329u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xAAu8
        ),
        shadowInspectableBase,
        "IInspectableShadowChildVtbl",
        "IInspectableShadowChild",
        "IInspectableShadowChild_Impl",
        [InterfaceMethodSchema("ReadInspectableShadow", Array<String>(0, { _ => "" }), "Int32")]
    )
    let inspectableResolved = createResolvedDescriptor(inspectableDerived)
    expect(inspectableResolved.abiPrefixSlotCount == 6, "schemas that inherit from an IInspectable-shaped base should keep the fixed 6-slot ABI prefix")
    expect(inspectableResolved.methods[0].abiSlot == 6, "IInspectable-shaped schema bases should not inherit synthetic extra slots")
}

func expectShadowedImplDispatchUsesQualifiedInterfaceView(): Unit {
    let baseMethods = [
        InterfaceMethodSchema("Shadow", 6, Array<String>(0, { _ => "" }), "Int32"),
        InterfaceMethodSchema(
            "ReadShadow",
            7,
            [InterfaceParameterSchema("result", "CPointer<Int32>", "OutRef<Int32>", InterfaceParameterBridgeKind.OutRef)],
            "Int32"
        )
    ]
    let baseSchema = InterfaceDescriptorSchema(
        "IShadowDispatchBase",
        GUID(
            0x8765432Au32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xABu8
        ),
        IInspectable.descriptorSchema(),
        "IShadowDispatchBaseVtbl",
        "IShadowDispatchBase",
        "IShadowDispatchBase_Impl",
        baseMethods
    )
    let childMethods = [
        InterfaceMethodSchema("Shadow", 8, Array<String>(0, { _ => "" }), "Int32"),
        InterfaceMethodSchema(
            "ReadShadow",
            9,
            [InterfaceParameterSchema("result", "CPointer<Int32>", "OutRef<Int32>", InterfaceParameterBridgeKind.OutRef)],
            "Int32"
        )
    ]
    let childSchema = InterfaceDescriptorSchema(
        "IShadowDispatchChild",
        GUID(
            0x8765432Bu32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xACu8
        ),
        baseSchema,
        "IShadowDispatchChildVtbl",
        "IShadowDispatchChild",
        "IShadowDispatchChild_Impl",
        childMethods
    )
    let baseRendered = renderDescriptor(createResolvedDescriptor(baseSchema))
    let childRendered = renderDescriptor(createResolvedDescriptor(childSchema))

    expect(baseRendered.contains("match (impl as IShadowDispatchBase_Impl)"), "base thunks should qualify dispatch through the base _Impl surface when names shadow across interfaces")
    expect(baseRendered.contains("qualifiedImpl.Shadow()"), "base thunks should call the base-qualified implementation for duplicate method names")
    expect(baseRendered.contains("match (qualifiedImpl.ReadShadow()) {"), "bridged base thunks should dispatch through the base-qualified implementation before matching Result")

    expect(childRendered.contains("public interface IShadowDispatchChild_Impl <: IShadowDispatchBase_Impl"), "child _Impl surfaces should still inherit the parent _Impl surface")
    expect(childRendered.contains("match (impl as IShadowDispatchChild_Impl)"), "child thunks should qualify dispatch through the child _Impl surface when names shadow across interfaces")
    expect(childRendered.contains("qualifiedImpl.Shadow()"), "child thunks should call the child-qualified implementation for duplicate method names")
    expect(childRendered.contains("match (qualifiedImpl.ReadShadow()) {"), "bridged child thunks should dispatch through the child-qualified implementation before matching Result")
}

func expectDeepInheritanceChainSlots(): Unit {
    let baseDescriptor = makeBaseDescriptor()
    baseDescriptor.methods = [makeValueMethod("BaseValue", 6)]
    let derivedDescriptor = makeDerivedDescriptor(baseDescriptor)
    derivedDescriptor.methods = [makeValueMethod("DerivedValue", 7)]
    let leafDescriptor = makeLeafDescriptor(derivedDescriptor)
    leafDescriptor.methods = [makeValueMethod("LeafValue", 8)]
    let descriptors = [baseDescriptor, derivedDescriptor, leafDescriptor]

    let resolvedLeaf = createResolvedDescriptor(leafDescriptor)
    expect(resolvedLeaf.abiPrefixSlotCount == 8, "deep inheritance chains should recursively accumulate every ancestor method count")

    let autoLeafSchema = InterfaceDescriptorSchema(
        "ILeafAuto",
        GUID(
            0x87654325u32,
            0x4321u16,
            0x4876u16,
            0x80u8,
            0x42u8,
            0x52u8,
            0x62u8,
            0x72u8,
            0x82u8,
            0x92u8,
            0xA6u8
        ),
        InterfaceDescriptorSchema(
            "IDerivedAuto",
            GUID(
                0x87654326u32,
                0x4321u16,
                0x4876u16,
                0x80u8,
                0x42u8,
                0x52u8,
                0x62u8,
                0x72u8,
                0x82u8,
                0x92u8,
                0xA7u8
            ),
            InterfaceDescriptorSchema(
                "IBaseAuto",
                GUID(
                    0x87654327u32,
                    0x4321u16,
                    0x4876u16,
                    0x80u8,
                    0x42u8,
                    0x52u8,
                    0x62u8,
                    0x72u8,
                    0x82u8,
                    0x92u8,
                    0xA8u8
                ),
                IInspectable.descriptorSchema(),
                "IBaseAutoVtbl",
                "IBaseAuto",
                "IBaseAuto_Impl",
                [InterfaceMethodSchema("BaseAutoValue", Array<String>(0, { _ => "" }), "Int32")]
            ),
            "IDerivedAutoVtbl",
            "IDerivedAuto",
            "IDerivedAuto_Impl",
            [InterfaceMethodSchema("DerivedAutoValue", Array<String>(0, { _ => "" }), "Int32")]
        ),
        "ILeafAutoVtbl",
        "ILeafAuto",
        "ILeafAuto_Impl",
        [InterfaceMethodSchema("LeafAutoValue", Array<String>(0, { _ => "" }), "Int32")]
    )
    let autoLeafResolved = createResolvedDescriptor(autoLeafSchema)
    expect(autoLeafResolved.abiPrefixSlotCount == 8, "automatic abi slots should still honor recursive ancestor method counts")
    expect(autoLeafResolved.methods[0].abiSlot == 8, "automatic abi slots should begin at the full inherited prefix for deep chains")

    var derivedVtbl = buildIUnknownVtbl()
    let object = createComObjectFromDescriptors(
        DemoImpl(value: 71i32),
        descriptors,
        [CPointer<Unit>(CPointer<IUnknownVtbl>(inout derivedVtbl))]
    )
    let identity = IUnknown(object.asRaw())

    match (unsafe { identity.query(baseDescriptor) }) {
        case Some(baseView) =>
            match (unsafe { identity.query(derivedDescriptor) }) {
                case Some(derivedView) =>
                    match (unsafe { identity.query(leafDescriptor) }) {
                        case Some(leafView) =>
                            expect(samePointer(baseView.asRaw(), derivedView.asRaw()), "interfaces in the same inheritance chain should share a single slot root")
                            expect(samePointer(baseView.asRaw(), leafView.asRaw()), "deep inheritance descendants should continue to reuse the same slot root")
                            leafView.close()
                        case None =>
                            fail("identity pointer should be able to query the leaf chain root")
                    }
                    derivedView.close()
                case None =>
                    fail("identity pointer should be able to query the derived chain root")
            }
            baseView.close()
        case None =>
            fail("identity pointer should be able to query the base chain view")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    expect(finalCount == 0u32, "deep-chain test object should release cleanly")
}

func expectDescriptorCustomVtblPrefersChildWrapper(): Unit {
    let baseResolved = createResolvedDescriptor(IChildPriorityBase.descriptor())
    let leafResolved = createResolvedDescriptor(IChildPriorityLeaf.descriptor())
    let resolvedDescriptors = [leafResolved, baseResolved]
    let supportedIids = [IChildPriorityLeaf.iid(), IChildPriorityBase.iid()]
    var object = ComObject(DemoImpl(value: 33i32), supportedIids, resolvedDescriptors)
    let identity = IUnknown(object.asRaw())

    match (unsafe { identity.query(IChildPriorityLeaf.descriptor()) }) {
        case Some(leafView) =>
            let slotVtblPtr = unsafe { CPointer<CPointer<Unit>>(leafView.asRaw()).read() }
            expect(samePointer(slotVtblPtr, IChildPriorityLeaf.vtablePtr()), "child descriptors should override parent vtables when a slot root is shared")
            expect(!samePointer(slotVtblPtr, IChildPriorityBase.vtablePtr()), "shared slot roots should not retain the parent vtable after a child override")
            match (unsafe { identity.query(IChildPriorityBase.descriptor()) }) {
                case Some(baseView) =>
                    expect(samePointer(baseView.asRaw(), leafView.asRaw()), "parent and child descriptors in the same chain should still share one slot pointer")
                    baseView.close()
                case None =>
                    fail("identity pointer should still resolve the parent view in the shared slot chain")
            }
            leafView.close()
        case None =>
            fail("identity pointer should resolve the child descriptor from the shared slot chain")
    }

    let finalCount = IUnknown(object.asRaw()).release()
    expect(finalCount == 0u32, "child-priority descriptor object should release cleanly")
}

main(_args: Array<String>) {
    expectOuterSlotLayoutAndAsImplOffset()
    expectAsImpl()
    expectOuterImplBinding()
    expectInterfaceResourceAsImplFallback()
    expectStaticComObject()
    expectWeakReferences()
    expectAgileQueries()
    expectExplicitAgileFlag()
    expectRuntimeClassName()
    expectDescriptorCodegen()
    expectBuiltinSchemaBaseSlots()
    expectShadowedImplDispatchUsesQualifiedInterfaceView()
    expectDeepInheritanceChainSlots()
    expectDescriptorCustomVtblPrefersChildWrapper()
}
