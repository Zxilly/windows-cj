package windows_core

import std.collection.*
import std.sync.AtomicInt64
import windows_interface.{InterfaceDescriptorSchema, RuntimeTypeContract, IID_IINSPECTABLE}
import windows_result.{Result, HRESULT}
import windows_result.Error as WinError
import windows_strings.*
import windows_implement.{
    comRegistryInsert,
    comRegistryLookup,
    comRegistryRemove,
    comSlotRegistryInsert,
    comSlotRegistryRemove,
    resolveSchema,
    resolveSchemas,
    resolveDescriptor,
    resolveDescriptors,
    resolveSupportedIids,
    supportedIidsFromSchemas,
    supportedIidsFromDescriptors,
    rootRegistryKeyFromRaw
}

public import windows_implement.{
    ComObjectBase,
    IInspectableBase,
    ImplementationAccess,
    WeakReferenceOwner,
    ResolvedDescriptor,
    asImpl,
    asImplFromRaw,
    buildIUnknownVtbl,
    buildIInspectableVtbl
}

public interface ComObjectInner {}

public interface ComObjectInterface<I> where I <: ComInterface & Interface<I> {
    func asInterfaceRef(descriptor: InterfaceDescriptor<I>): InterfaceRef<I>
}

public class ComObjectRuntime<T> <: ComObjectBase & IInspectableBase & ImplementationAccess & WeakReferenceOwner {
    private var inner: Option<T>
    private var outerObject: Option<Object> = None
    private let resolvedDescriptors: ArrayList<ResolvedDescriptor> = ArrayList<ResolvedDescriptor>()
    private let supportedIids: ArrayList<GUID> = ArrayList<GUID>()
    private let interfacePointers: ArrayList<CPointer<Unit>> = ArrayList<CPointer<Unit>>()
    private let registrationKeys: ArrayList<UIntNative> = ArrayList<UIntNative>()
    private let refCount = AtomicInt64(1)
    private let weakRefCount = WeakRefCount(CPointer<Unit>())
    private var registered: Bool = false
    private var identityKey: UIntNative = UIntNative(0)
    private var identityRaw: CPointer<Unit> = CPointer<Unit>()
    private var onDestroy: Option<() -> Unit> = None
    private var runtimeType: Option<RuntimeTypeContract> = None
    private var runtimeClassName: Option<HString> = None
    private var agileEnabled: Bool = false
    private var runtimePinned: Bool = false

    public init(inner: T, supportedIids: Array<GUID>, resolvedDescriptors: Array<ResolvedDescriptor>) {
        this.inner = Some(inner)
        captureOuterObject(inner)
        appendSupportedIid(IID_IUNKNOWN)
        for (iid in supportedIids) {
            appendSupportedIid(iid)
        }
        for (descriptor in resolvedDescriptors) {
            this.resolvedDescriptors.add(descriptor)
        }
        agileEnabled = true
    }

    public func bindInterfacePointers(pointers: Array<CPointer<Unit>>): Unit {
        for (pointer in pointers) {
            interfacePointers.add(pointer)
        }
    }

    public func attach(keys: Array<UIntNative>): Unit {
        if (keys.size == 0) {
            throw Exception("ComObjectRuntime.attach requires at least one COM identity key")
        }
        identityKey = keys[0]
        if (!registered) {
            comRegistryInsert(identityKey, this)
        }
        for (key in keys) {
            if (!containsRegistrationKey(key)) {
                registrationKeys.add(key)
                comSlotRegistryInsert(key, identityKey)
            }
        }
        registered = true
    }

    public func setOnDestroy(callback: () -> Unit): Unit {
        onDestroy = Some(callback)
    }

    public func setIdentityPointer(raw: CPointer<Unit>): Unit {
        identityRaw = raw
        weakRefCount.bind(raw)
    }

    public func setOuterObject<U>(outer: U): Unit where U <: Object {
        outerObject = Some(outer)
    }

    public func setRuntimeType(contract: RuntimeTypeContract): Unit {
        if (runtimePinned) {
            return
        }
        match (runtimeClassName) {
            case Some(value) => value.close()
            case None => ()
        }
        runtimeType = Some(contract)
        runtimeClassName = if (contract.runtimeName.isEmpty()) {
            None
        } else {
            Some(HString(contract.runtimeName))
        }
    }

    public func setRuntimeTypeFromName<U>(): Unit where U <: RuntimeName {
        setRuntimeType(U.runtimeType())
    }

    public func runtimeTypeContract(): Option<RuntimeTypeContract> {
        runtimeType
    }

    public func runtimeClassNameRaw(): CPointer<Unit> {
        match (runtimeClassName) {
            case Some(value) => value.asRaw()
            case None => CPointer<Unit>()
        }
    }

    public func addRefBase(): UInt32 {
        let oldCount = refCount.fetchAdd(1)
        UInt32(oldCount + 1)
    }

    public func isReferenceCountOne(): Bool {
        refCount.load() == 1
    }

    public func setAgileEnabled(value: Bool): Unit {
        agileEnabled = value
    }

    public func pinStaticReference(): Unit {
        runtimePinned = true
    }

    public func getMut(): Option<T> {
        if (runtimePinned || !isReferenceCountOne()) {
            return None
        }
        inner
    }

    public func getImplAs<U>(): Option<U> {
        match (outerObject) {
            case Some(value) =>
                match (value) {
                    case resolved: U => return Some(resolved)
                    case _ => ()
                }
            case None => ()
        }
        match (inner) {
            case Some(value) =>
                match (value) {
                    case resolved: U => Some(resolved)
                    case _ => None
                }
            case None => None
        }
    }

    public func takeInner(): Option<T> {
        if (runtimePinned || !isReferenceCountOne()) {
            return None
        }
        let value = inner
        inner = None
        value
    }

    public func identityPointer(): CPointer<Unit> {
        identityRaw
    }

    public func releaseBase(_: UIntNative): UInt32 {
        if (runtimePinned) {
            while (true) {
                let current = refCount.load()
                if (current <= 1) {
                    return 1u32
                }
                if (refCount.compareAndSwap(current, current - 1)) {
                    return UInt32(current - 1)
                }
            }
        }

        let oldCount = refCount.fetchSub(1)
        if (oldCount <= 0) {
            throw Exception("over-release: ref count already zero")
        }
        let count = oldCount - 1

        if (count == 0 && registered) {
            for (key in registrationKeys) {
                comSlotRegistryRemove(key)
            }
            comRegistryRemove(identityKey)
            registered = false
            weakRefCount.onObjectDestroyed()
            match (runtimeClassName) {
                case Some(value) =>
                    value.close()
                    runtimeClassName = None
                case None => ()
            }
            match (onDestroy) {
                case Some(cb) => cb()
                case None => ()
            }
        }
        UInt32(count)
    }

    public func queryInterfaceBase(_: CPointer<Unit>, iid: GUID, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        if (iid == IID_IUNKNOWN) {
            return writeInterfacePointer(0, ppvObject)
        }
        if (iid == IID_IINSPECTABLE && containsIid(IID_IINSPECTABLE)) {
            return writeInterfacePointer(0, ppvObject)
        }
        if (iid == IID_IAGILEOBJECT && agileEnabled) {
            return writeInterfacePointer(0, ppvObject)
        }
        if (iid == IID_IWEAKREFERENCESOURCE && agileEnabled) {
            return weakRefCount.writeWeakReferenceSource(ppvObject)
        }
        if (iid == IMarshal.iid() && agileEnabled) {
            return weakRefCount.writeObjectMarshaler(ppvObject)
        }
        for (descriptor in resolvedDescriptors) {
            if (descriptor.matchesNonIdentity(iid)) {
                return writeInterfacePointer(descriptor.slotIndex, ppvObject)
            }
        }
        if (ppvObject.isNotNull()) {
            unsafe { ppvObject.write(CPointer<Unit>()) }
        }
        E_NOINTERFACE.value
    }

    public func getIidsBase(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): Int32 {
        unsafe {
            if (count.isNull() || values.isNull()) {
                return E_POINTER.value
            }
            count.write(0u32)
            values.write(CPointer<GUID>())
        }
        S_OK.value
    }

    public func getRuntimeClassNameBase(value: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (value.isNull()) {
                return E_POINTER.value
            }
            match (runtimeClassName) {
                case Some(cached) =>
                    let fresh = cached.clone()
                    value.write(fresh.intoRaw())
                case None =>
                    value.write(CPointer<Unit>())
            }
        }
        S_OK.value
    }

    public func getTrustLevelBase(value: CPointer<Int32>): Int32 {
        unsafe {
            if (value.isNull()) {
                return E_POINTER.value
            }
            value.write(0i32)
        }
        S_OK.value
    }

    public func weakReferenceIdentity(): CPointer<Unit> {
        identityPointer()
    }

    public func weakReferenceIsAgileEnabled(): Bool {
        agileEnabled
    }

    public func weakReferenceQueryInterface(iid: GUID, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        queryInterfaceBase(identityPointer(), iid, ppvObject)
    }

    private func writeInterfacePointer(slotIndex: Int64, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        if (ppvObject.isNull()) {
            return E_POINTER.value
        }
        if (slotIndex < 0 || slotIndex >= interfacePointers.size) {
            unsafe { ppvObject.write(CPointer<Unit>()) }
            return E_NOINTERFACE.value
        }
        addRefBase()
        unsafe { ppvObject.write(interfacePointers[slotIndex]) }
        S_OK.value
    }

    func containsIid(iid: GUID): Bool {
        for (supported in supportedIids) {
            if (supported == iid) {
                return true
            }
        }
        false
    }

    func appendSupportedIid(iid: GUID): Unit {
        if (!containsIid(iid)) {
            supportedIids.add(iid)
        }
    }

    func containsRegistrationKey(candidate: UIntNative): Bool {
        for (registeredKey in registrationKeys) {
            if (registeredKey == candidate) {
                return true
            }
        }
        false
    }

    func captureOuterObject(value: T): Unit {
        match (value) {
            case objectValue: Object =>
                outerObject = Some(objectValue)
            case _ => ()
        }
    }
}

func emptyUnitPointerArray(): Array<CPointer<Unit>> {
    Array<CPointer<Unit>>(0, { _ => CPointer<Unit>() })
}

func customSlotCount(resolvedDescriptors: Array<ResolvedDescriptor>): Int64 {
    var maxSlot: Int64 = 0
    for (descriptor in resolvedDescriptors) {
        if (descriptor.slotIndex > maxSlot) {
            maxSlot = descriptor.slotIndex
        }
    }
    maxSlot
}

func shouldUseInspectableIdentity(supportedIids: Array<GUID>): Bool {
    for (iid in supportedIids) {
        if (iid == IID_IINSPECTABLE) {
            return true
        }
    }
    false
}

func defaultCustomVtblArray(
    slotCount: Int64,
    explicitCustomVtbls: Array<CPointer<Unit>>,
    fallbackCustomVtbl: CPointer<Unit>
): Array<CPointer<Unit>> {
    Array<CPointer<Unit>>(slotCount, { index =>
        if (index < explicitCustomVtbls.size) {
            explicitCustomVtbls[index]
        } else {
            fallbackCustomVtbl
        }
    })
}

func createInlineSlotHandle(vtables: Array<CPointer<Unit>>): CPointerHandle<CPointer<Unit>> {
    unsafe {
        acquireArrayRawData(vtables)
    }
}

func applyRuntimeTypeFromSchemas<T>(
    runtime: ComObjectRuntime<T>,
    schemas: Array<InterfaceDescriptorSchema>
): Unit {
    for (schema in schemas) {
        match (schema.runtimeTypeContract) {
            case Some(contract) =>
                runtime.setRuntimeType(contract)
                return
            case None => ()
        }
    }
}

func applyRuntimeTypeFromDescriptors<T, I>(
    runtime: ComObjectRuntime<T>,
    descriptors: Array<InterfaceDescriptor<I>>
): Unit {
    for (descriptor in descriptors) {
        match (descriptor.runtimeTypeContract) {
            case Some(contract) =>
                runtime.setRuntimeType(contract)
                return
            case None => ()
        }
    }
}

public class ComObject<T> {
    private var slotHandle: Option<CPointerHandle<CPointer<Unit>>> = None
    private var ownedUnknownVtblHandle: Option<CPointerHandle<IUnknownVtbl>> = None
    private var ownedInspectableVtblHandle: Option<CPointerHandle<IInspectableVtbl>> = None
    private var rawView: CPointer<Unit> = CPointer<Unit>()
    public let runtime: ComObjectRuntime<T>

    public init(inner: T, supportedIids: Array<GUID>, agile!: Bool = true) {
        let resolvedDescriptors = resolveSupportedIids(supportedIids)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        attachRuntime(defaultIdentityVtblPtr(supportedIids), emptyUnitPointerArray(), resolvedDescriptors)
    }

    public init(inner: T, supportedIids: Array<GUID>, vtblPtr: CPointer<Unit>, agile!: Bool = true) {
        let resolvedDescriptors = resolveSupportedIids(supportedIids)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        let slotCount = customSlotCount(resolvedDescriptors)
        if (slotCount == 0) {
            attachRuntime(vtblPtr, emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            attachRuntime(defaultIdentityVtblPtr(supportedIids), Array<CPointer<Unit>>(1, { _ => vtblPtr }), resolvedDescriptors)
        }
    }

    public init(inner: T, supportedIids: Array<GUID>, resolvedDescriptors: Array<ResolvedDescriptor>, agile!: Bool = true) {
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        attachRuntime(defaultIdentityVtblPtr(supportedIids), emptyUnitPointerArray(), resolvedDescriptors)
    }

    public init(inner: T, schemas: Array<InterfaceDescriptorSchema>, agile!: Bool = true) {
        let supportedIids = supportedIidsFromSchemas(schemas)
        let resolvedDescriptors = resolveSchemas(schemas)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        applyRuntimeTypeFromSchemas(runtime, schemas)
        attachRuntime(defaultIdentityVtblPtr(supportedIids), emptyUnitPointerArray(), resolvedDescriptors)
    }

    public init(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtr: CPointer<Unit>, agile!: Bool = true) {
        let supportedIids = supportedIidsFromSchemas(schemas)
        let resolvedDescriptors = resolveSchemas(schemas)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        applyRuntimeTypeFromSchemas(runtime, schemas)
        let slotCount = customSlotCount(resolvedDescriptors)
        if (slotCount == 0) {
            attachRuntime(vtblPtr, emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            attachRuntime(defaultIdentityVtblPtr(supportedIids), Array<CPointer<Unit>>(1, { _ => vtblPtr }), resolvedDescriptors)
        }
    }

    private init(runtime: ComObjectRuntime<T>, rawView: CPointer<Unit>) {
        this.runtime = runtime
        this.rawView = rawView
    }

    public static func new(inner: T, supportedIids: Array<GUID>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, supportedIids, agile: agile)
    }

    public static func new(inner: T, supportedIids: Array<GUID>, vtblPtr: CPointer<Unit>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, supportedIids, vtblPtr, agile: agile)
    }

    public static func new(inner: T, schemas: Array<InterfaceDescriptorSchema>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, schemas, agile: agile)
    }

    public static func new(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtr: CPointer<Unit>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, schemas, vtblPtr, agile: agile)
    }

    public static func new<I>(inner: T, descriptors: Array<InterfaceDescriptor<I>>, agile!: Bool = true): ComObject<T> where I <: ComInterface {
        let supportedIids = supportedIidsFromDescriptors(descriptors)
        let resolvedDescriptors = resolveDescriptors(descriptors)
        let object = ComObject<T>(inner, supportedIids, resolvedDescriptors, agile: agile)
        applyRuntimeTypeFromDescriptors(object.runtime, descriptors)
        object
    }

    public static unsafe func fromRaw(raw: CPointer<Unit>): Result<ComObject<T>> {
        match (castFromRaw(raw)) {
            case Some(value) => Result<ComObject<T>>.Ok(value)
            case None => Result<ComObject<T>>.Err(WinError.fromHRESULT(HRESULT(E_NOINTERFACE.value)))
        }
    }

    public func get(): T {
        match (runtime.getImplAs<T>()) {
            case Some(value) => value
            case None => throw IllegalStateException("ComObject.get requires a live implementation value")
        }
    }

    public func bindOuterObject<U>(outer: U): ComObject<T> where U <: Object {
        runtime.setOuterObject(outer)
        this
    }

    private func ensureOwnedIUnknownVtblPtr(): CPointer<Unit> {
        match (ownedUnknownVtblHandle) {
            case Some(handle) => return CPointer<Unit>(handle.pointer)
            case None => ()
        }
        let handle = unsafe { acquireArrayRawData(Array<IUnknownVtbl>(1, { _ => buildIUnknownVtbl() })) }
        ownedUnknownVtblHandle = Some(handle)
        CPointer<Unit>(handle.pointer)
    }

    private func ensureOwnedIInspectableVtblPtr(): CPointer<Unit> {
        match (ownedInspectableVtblHandle) {
            case Some(handle) => return CPointer<Unit>(handle.pointer)
            case None => ()
        }
        let handle = unsafe { acquireArrayRawData(Array<IInspectableVtbl>(1, { _ => buildIInspectableVtbl() })) }
        ownedInspectableVtblHandle = Some(handle)
        CPointer<Unit>(handle.pointer)
    }

    private func defaultIdentityVtblPtr(supportedIids: Array<GUID>): CPointer<Unit> {
        if (shouldUseInspectableIdentity(supportedIids)) {
            return ensureOwnedIInspectableVtblPtr()
        }
        ensureOwnedIUnknownVtblPtr()
    }

    private func attachRuntime(
        identityVtblPtr: CPointer<Unit>,
        explicitCustomVtbls: Array<CPointer<Unit>>,
        resolvedDescriptors: Array<ResolvedDescriptor>
    ): Unit {
        let slotCount = customSlotCount(resolvedDescriptors)
        var fallbackCustomVtbl = CPointer<Unit>()
        if (slotCount > 0 && explicitCustomVtbls.size < slotCount) {
            fallbackCustomVtbl = ensureOwnedIUnknownVtblPtr()
        }

        let customVtables = defaultCustomVtblArray(slotCount, explicitCustomVtbls, fallbackCustomVtbl)
        let allVtables = Array<CPointer<Unit>>(slotCount + 1, { index =>
            if (index == 0) {
                identityVtblPtr
            } else {
                customVtables[index - 1]
            }
        })

        let handle = createInlineSlotHandle(allVtables)
        slotHandle = Some(handle)

        let rawPointers = Array<CPointer<Unit>>(allVtables.size, { index =>
            CPointer<Unit>(unsafe { handle.pointer + index })
        })
        rawView = rawPointers[0]
        runtime.setIdentityPointer(rawPointers[0])
        runtime.bindInterfacePointers(rawPointers)
        runtime.attach(Array<UIntNative>(rawPointers.size, { index => rawPointers[index].toUIntNative() }))

        let finalSlotHandle = slotHandle
        let finalOwnedUnknownVtblHandle = ownedUnknownVtblHandle
        let finalOwnedInspectableVtblHandle = ownedInspectableVtblHandle

        runtime.setOnDestroy({ =>
            match (finalOwnedInspectableVtblHandle) {
                case Some(vtblHandle) => unsafe { releaseArrayRawData(vtblHandle) }
                case None => ()
            }
            match (finalOwnedUnknownVtblHandle) {
                case Some(vtblHandle) => unsafe { releaseArrayRawData(vtblHandle) }
                case None => ()
            }
            match (finalSlotHandle) {
                case Some(inlineHandle) => unsafe { releaseArrayRawData(inlineHandle) }
                case None => ()
            }
        })
    }

    public func asRaw(): CPointer<Unit> {
        if (rawView.isNotNull()) {
            return rawView
        }
        match (slotHandle) {
            case Some(handle) => CPointer<Unit>(handle.pointer)
            case None => CPointer<Unit>()
        }
    }

    public func addRefBase(): UInt32 {
        runtime.addRefBase()
    }

    public func releaseBase(): UInt32 {
        runtime.releaseBase(asRaw().toUIntNative())
    }

    public func queryInterfaceBase(iid: GUID, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        runtime.queryInterfaceBase(asRaw(), iid, ppvObject)
    }

    public unsafe func cast<I>(descriptor: InterfaceDescriptor<I>): Option<I> where I <: ComInterface {
        queryInterfaceAs(asRaw(), descriptor)
    }

    public static func castFrom(source: ComInterface): Option<ComObject<T>> {
        castFromRaw(source.asRaw())
    }

    public static func castFromRaw(raw: CPointer<Unit>): Option<ComObject<T>> {
        if (raw.isNull()) {
            return None
        }
        let lookupKey = unsafe { rootRegistryKeyFromRaw(raw) }
        match (comRegistryLookup(lookupKey)) {
            case Some(obj) =>
                match (obj as ComObjectRuntime<T>) {
                    case Some(runtime) => Some(ComObject<T>(runtime, runtime.identityPointer()))
                    case None => None
                }
            case None => None
        }
    }

    public func getMut(): Option<T> {
        runtime.getMut()
    }

    public func take(): Option<T> {
        runtime.takeInner()
    }

    public func asInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface {
        match (unsafe { cast(descriptor) }) {
            case Some(value) =>
                let raw = value.asRaw()
                let borrowed = descriptor.wrapBorrowed(raw)
                IUnknown(raw).release()
                borrowed
            case None =>
                throw Exception("ComObject.asInterface: requested interface is not implemented")
        }
    }

    public func toInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface {
        match (unsafe { cast(descriptor) }) {
            case Some(value) => value
            case None => throw Exception("ComObject.toInterface: requested interface is not implemented")
        }
    }

    public func intoInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface {
        toInterface(descriptor)
    }
}

public func createComObject<T>(inner: T, supportedIids: Array<GUID>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, supportedIids, agile: agile)
}

public func createComObject<T>(inner: T, supportedIids: Array<GUID>, vtblPtr: CPointer<Unit>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, supportedIids, vtblPtr, agile: agile)
}

public func createComObjectFromSchemas<T>(inner: T, schemas: Array<InterfaceDescriptorSchema>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, schemas, agile: agile)
}

public func createComObjectFromSchemas<T>(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtr: CPointer<Unit>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, schemas, vtblPtr, agile: agile)
}

public func createComObjectFromDescriptors<T, I>(inner: T, descriptors: Array<InterfaceDescriptor<I>>, agile!: Bool = true): ComObject<T> where I <: ComInterface {
    ComObject<T>.new(inner, descriptors, agile: agile)
}

public func createResolvedDescriptor(schema: InterfaceDescriptorSchema): ResolvedDescriptor {
    resolveSchema(schema)
}

public func createResolvedDescriptor<I>(descriptor: InterfaceDescriptor<I>): ResolvedDescriptor {
    resolveDescriptor(descriptor)
}

public class StaticComObject<T> {
    private let object: ComObject<T>
    public let runtime: ComObjectRuntime<T>

    public init(object: ComObject<T>) {
        this.object = object
        this.runtime = object.runtime
        this.runtime.pinStaticReference()
    }

    public func asRaw(): CPointer<Unit> {
        object.asRaw()
    }

    public func toInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface {
        object.toInterface(descriptor)
    }

    public func asInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface {
        object.asInterface(descriptor)
    }
}

public func createStaticComObject<T>(inner: T, supportedIids: Array<GUID>, agile!: Bool = true): StaticComObject<T> {
    StaticComObject<T>(createComObject(inner, supportedIids, agile: agile))
}

public func createStaticComObjectFromSchemas<T>(
    inner: T,
    schemas: Array<InterfaceDescriptorSchema>,
    agile!: Bool = true
): StaticComObject<T> {
    StaticComObject<T>(createComObjectFromSchemas(inner, schemas, agile: agile))
}

public func createStaticComObjectFromDescriptors<T, I>(
    inner: T,
    descriptors: Array<InterfaceDescriptor<I>>,
    agile!: Bool = true
): StaticComObject<T> where I <: ComInterface {
    StaticComObject<T>(createComObjectFromDescriptors(inner, descriptors, agile: agile))
}

extend<T> ComObject<T> {
    public func get_mut(): Option<T> {
        getMut()
    }

    public func asInterfaceRef<I>(descriptor: InterfaceDescriptor<I>): InterfaceRef<I> where I <: ComInterface & Interface<I> {
        let view = asInterface(descriptor)
        InterfaceRef<I>.fromInterface(view)
    }

    public func to_interface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        toInterface(descriptor)
    }

    public func into_interface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface & Interface<I> {
        intoInterface(descriptor)
    }
}

extend<T> ComObject<T> {
    public static func cast_from(source: ComInterface): Option<ComObject<T>> {
        castFrom(source)
    }
}
