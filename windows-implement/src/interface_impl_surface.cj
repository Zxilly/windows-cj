package windows_implement

import windows_interface as windows_interface
import std.collection.*
import std.reflect.*
import std.sync.AtomicBool
import std.sync.AtomicInt64
import windows_interface.*
import windows_result.{Result, HRESULT}
import windows_result.Error as WinError
import windows_strings.*

public let S_OK: Int32 = 0i32
public let E_POINTER: Int32 = -2147467261i32
public let E_NOINTERFACE: Int32 = -2147467262i32
public let E_NOTIMPL: Int32 = -2147467263i32
public let E_OUTOFMEMORY: Int32 = -2147024882i32

func isSystemTearOffIid(iid: GUID): Bool {
    iid == IID_IUNKNOWN ||
        iid == IID_IINSPECTABLE ||
        iid == IID_IAGILEOBJECT ||
        iid == IID_IMARSHAL ||
        iid == IID_IWEAKREFERENCE ||
        iid == IID_IWEAKREFERENCESOURCE ||
        iid == IID_IAGILEREFERENCE
}

public interface ComObjectBase {
    func addRefBase(): UInt32
    func releaseBase(identityKey: UIntNative): UInt32
    func queryInterfaceBase(raw: CPointer<Unit>, iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32
}

public interface IInspectableBase {
    func getIidsBase(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): Int32
    func getRuntimeClassNameBase(value: CPointer<CPointer<Unit>>): Int32
    func getTrustLevelBase(value: CPointer<Int32>): Int32
}

public interface ImplementationAccess {
    func getImplAs<U>(): Option<U>
}

public class ComObjectRuntime<T> <: ComObjectBase & IInspectableBase & ImplementationAccess & WeakReferenceOwner {
    private var inner: Option<T>
    private var outerObject: Option<Object> = None
    private let resolvedDescriptors: ArrayList<ResolvedDescriptor> = ArrayList<ResolvedDescriptor>()
    private let supportedIids: ArrayList<GUID> = ArrayList<GUID>()
    private let interfacePointers: ArrayList<CPointer<Unit>> = ArrayList<CPointer<Unit>>()
    private let registrationKeys: ArrayList<UIntNative> = ArrayList<UIntNative>()
    private let refCount = AtomicInt64(1)
    private let destroyed = AtomicBool(false)
    private let weakRefCount = WeakRefCount(CPointer<Unit>())
    private var registered: Bool = false
    private var identityKey: UIntNative = UIntNative(0)
    private var identityRaw: CPointer<Unit> = CPointer<Unit>()
    private var onDestroy: Option<() -> Unit> = None
    private var queryInterfaceFallback: Option<(GUID, CPointer<CPointer<Unit>>) -> Int32> = None
    private var runtimeType: Option<RuntimeTypeContract> = None
    private var runtimeClassName: Option<HString> = None
    private var trustLevel: Int32 = 0i32
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
        agileEnabled = containsIid(IID_IINSPECTABLE)
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

    public func setQueryInterfaceFallback(callback: (GUID, CPointer<CPointer<Unit>>) -> Int32): Unit {
        queryInterfaceFallback = Some(callback)
    }

    public func clearQueryInterfaceFallback(): Unit {
        queryInterfaceFallback = None
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
        if (contract.runtimeName.isEmpty()) {
            runtimeClassName = None
        } else {
            runtimeClassName = Some(HString(contract.runtimeName))
        }
    }

    public func setRuntimeTypeFromName<U>(): Unit where U <: RuntimeName {
        setRuntimeType(U.runtimeType())
    }

    public func runtimeTypeContract(): Option<RuntimeTypeContract> {
        runtimeType
    }

    public func setTrustLevel(value: Int32): Unit {
        trustLevel = value
    }

    public func addRefBase(): UInt32 {
        if (isDestroyed()) {
            return 0u32
        }
        let oldCount = refCount.fetchAdd(1)
        UInt32(oldCount + 1)
    }

    public func isReferenceCountOne(): Bool {
        refCount.load() == 1
    }

    public func isDestroyed(): Bool {
        destroyed.load()
    }

    public func setAgileEnabled(value: Bool): Unit {
        agileEnabled = value
    }

    public func pinStaticReference(): Unit {
        runtimePinned = true
    }

    public func getMut(): Option<T> {
        if (isDestroyed() || runtimePinned || !isReferenceCountOne()) {
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
        if (isDestroyed() || runtimePinned || !isReferenceCountOne()) {
            return None
        }
        let value = inner
        inner = None
        value
    }

    public func identityPointer(): CPointer<Unit> {
        identityRaw
    }

    private func closeInnerResource(): Unit {
        match (inner) {
            case Some(value) =>
                match (value) {
                    case resource: Resource =>
                        resource.close()
                        inner = None
                        outerObject = None
                    case _ => ()
                }
            case None => ()
        }
    }

    public func releaseBase(_: UIntNative): UInt32 {
        if (isDestroyed()) {
            return 0u32
        }
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

        if (count == 0) {
            let wasDestroyed = destroyed.swap(true)
            if (!wasDestroyed) {
                if (registered) {
                    for (key in registrationKeys) {
                        comSlotRegistryRemove(key)
                    }
                    comRegistryRemove(identityKey)
                    registered = false
                    weakRefCount.onObjectDestroyed()
                }
                closeInnerResource()
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
        }
        UInt32(count)
    }

    public func queryInterfaceBase(_: CPointer<Unit>, iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (isDestroyed()) {
            if (resultSlot.isNotNull()) {
                unsafe { resultSlot.write(CPointer<Unit>()) }
            }
            return E_NOINTERFACE
        }
        if (iid == IID_IUNKNOWN) {
            return writeInterfacePointer(0, resultSlot)
        }
        if (iid == IID_IINSPECTABLE && containsIid(IID_IINSPECTABLE)) {
            return writeInterfacePointer(0, resultSlot)
        }
        if (iid == IID_IAGILEOBJECT && agileEnabled) {
            return writeInterfacePointer(0, resultSlot)
        }
        if (iid == IID_IWEAKREFERENCESOURCE && containsIid(IID_IINSPECTABLE)) {
            return weakRefCount.writeWeakReferenceSource(resultSlot)
        }
        if (iid == IID_IMARSHAL && agileEnabled) {
            return weakRefCount.writeObjectMarshaler(resultSlot)
        }
        for (descriptor in resolvedDescriptors) {
            if (descriptor.iid == iid) {
                return writeInterfacePointer(descriptor.slotIndex, resultSlot)
            }
        }
        for (descriptor in resolvedDescriptors) {
            if (descriptorAncestorMatchesNonIdentity(descriptor, iid)) {
                return writeInterfacePointer(descriptor.slotIndex, resultSlot)
            }
        }

        match (queryInterfaceFallback) {
            case Some(callback) =>
                let delegated = callback(iid, resultSlot)
                if (delegated != E_NOINTERFACE) {
                    return delegated
                }
            case None => ()
        }

        if (resultSlot.isNotNull()) {
            unsafe { resultSlot.write(CPointer<Unit>()) }
        }
        E_NOINTERFACE
    }

    public func getIidsBase(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): Int32 {
        unsafe {
            if (count.isNull() || values.isNull()) {
                return E_POINTER
            }
        }
        let projected = ArrayList<GUID>()
        for (iid in supportedIids) {
            if (isSystemTearOffIid(iid)) {
                continue
            }
            projected.add(iid)
        }
        unsafe {
            if (projected.size == 0) {
                count.write(0u32)
                values.write(CPointer<GUID>())
                return S_OK
            }
            let bytes = UIntNative(projected.size) * sizeOf<GUID>()
            let buffer = CPointer<GUID>(CoTaskMemAlloc(bytes))
            if (buffer.isNull()) {
                count.write(0u32)
                values.write(CPointer<GUID>())
                return E_OUTOFMEMORY
            }
            var index: Int64 = 0
            while (index < projected.size) {
                (buffer + index).write(projected[index])
                index += 1
            }
            count.write(UInt32(projected.size))
            values.write(buffer)
        }
        S_OK
    }

    public func getRuntimeClassNameBase(value: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (value.isNull()) {
                return E_POINTER
            }
            match (runtimeClassName) {
                case Some(cached) =>
                    value.write(cached.toSystemHandleCopy())
                case None =>
                    value.write(CPointer<Unit>())
            }
        }
        S_OK
    }

    public func getTrustLevelBase(value: CPointer<Int32>): Int32 {
        unsafe {
            if (value.isNull()) {
                return E_POINTER
            }
            value.write(trustLevel)
        }
        S_OK
    }

    public func weakReferenceIdentity(): CPointer<Unit> {
        identityPointer()
    }

    public func weakReferenceIsAgileEnabled(): Bool {
        agileEnabled
    }

    public func weakReferenceQueryInterface(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        queryInterfaceBase(identityPointer(), iid, resultSlot)
    }

    private func writeInterfacePointer(slotIndex: Int64, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (resultSlot.isNull()) {
            return E_POINTER
        }
        if (isDestroyed()) {
            unsafe { resultSlot.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        if (slotIndex < 0 || slotIndex >= interfacePointers.size) {
            unsafe { resultSlot.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        addRefBase()
        unsafe { resultSlot.write(interfacePointers[slotIndex]) }
        S_OK
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

func hasMissingCustomVtbl(slotCount: Int64, explicitCustomVtbls: Array<CPointer<Unit>>): Bool {
    if (explicitCustomVtbls.size < slotCount) {
        return true
    }
    var index: Int64 = 0
    while (index < slotCount) {
        if (explicitCustomVtbls[index].isNull()) {
            return true
        }
        index += 1
    }
    false
}

func descriptorAncestorMatchesNonIdentity(descriptor: ResolvedDescriptor, candidate: GUID): Bool {
    if (candidate == IID_IUNKNOWN || candidate == IID_IINSPECTABLE) {
        return false
    }
    for (ancestor in descriptor.vtableAncestorIids) {
        if (ancestor == candidate) {
            return true
        }
    }
    false
}

func resolvedCustomVtblArray(
    slotCount: Int64,
    explicitCustomVtbls: Array<CPointer<Unit>>
): Array<CPointer<Unit>> {
    Array<CPointer<Unit>>(slotCount, { index => explicitCustomVtbls[index] })
}

func reflectedWrapperVtblPtr(descriptor: ResolvedDescriptor): Option<CPointer<Unit>> {
    match (descriptor.wrapperQualifiedTypeName) {
        case Some(qualifiedName) =>
            try {
                let wrapperType = TypeInfo.get(qualifiedName)
                let vtablePtrFunc = wrapperType.getStaticFunction("vtablePtr", Array<TypeInfo>(0, { _ => TypeInfo.of<Int64>() }))
                match (vtablePtrFunc.apply(wrapperType, Array<Any>(0, { _ => 0i32 })) as CPointer<Unit>) {
                    case Some(vtblPtr) =>
                        if (vtblPtr.isNotNull()) {
                            return Some(vtblPtr)
                        }
                    case None => ()
                }
            } catch (_: Exception) {
                ()
            }
        case None => ()
    }
    None
}

func resolvedDescriptorInheritanceDepth(
    resolvedDescriptors: Array<ResolvedDescriptor>,
    descriptorIndex: Int64
): Int64 {
    resolvedDescriptorVtableAncestorDepth(resolvedDescriptors, descriptorIndex)
}

func requiredDescriptorIndicesForCustomSlots(resolvedDescriptors: Array<ResolvedDescriptor>): Array<Int64> {
    let slotCount = customSlotCount(resolvedDescriptors)
    let requiredIndices = Array<Int64>(slotCount, { _ => -1 })
    let depths = Array<Int64>(slotCount, { _ => -1 })
    var index: Int64 = 0
    while (index < resolvedDescriptors.size) {
        let descriptor = resolvedDescriptors[index]
        if (descriptor.slotIndex > 0) {
            let slot = descriptor.slotIndex - 1
            let depth = resolvedDescriptorInheritanceDepth(resolvedDescriptors, index)
            if (requiredIndices[slot] < 0 || depth >= depths[slot]) {
                requiredIndices[slot] = index
                depths[slot] = depth
            }
        }
        index += 1
    }
    requiredIndices
}

func descriptorCustomVtblArray(resolvedDescriptors: Array<ResolvedDescriptor>): Array<CPointer<Unit>> {
    let slotCount = customSlotCount(resolvedDescriptors)
    if (slotCount == 0) {
        return emptyUnitPointerArray()
    }

    let requiredIndices = requiredDescriptorIndicesForCustomSlots(resolvedDescriptors)
    var vtblPtrs = Array<CPointer<Unit>>(slotCount, { _ => CPointer<Unit>() })
    var slot: Int64 = 0
    while (slot < slotCount) {
        let descriptorIndex = requiredIndices[slot]
        if (descriptorIndex >= 0) {
            match (reflectedWrapperVtblPtr(resolvedDescriptors[descriptorIndex])) {
                case Some(vtblPtr) =>
                    vtblPtrs[slot] = vtblPtr
                case None => ()
            }
        }
        slot += 1
    }
    vtblPtrs
}

func explicitCustomVtblArray(
    resolvedDescriptors: Array<ResolvedDescriptor>,
    descriptorVtblPtrs: Array<CPointer<Unit>>
): Array<CPointer<Unit>> {
    let slotCount = customSlotCount(resolvedDescriptors)
    if (slotCount == 0) {
        return emptyUnitPointerArray()
    }

    var vtblPtrs = Array<CPointer<Unit>>(slotCount, { _ => CPointer<Unit>() })
    let requiredIndices = requiredDescriptorIndicesForCustomSlots(resolvedDescriptors)
    var slot: Int64 = 0
    while (slot < slotCount) {
        let descriptorIndex = requiredIndices[slot]
        if (descriptorIndex >= 0 && descriptorIndex < descriptorVtblPtrs.size && descriptorVtblPtrs[descriptorIndex].isNotNull()) {
            vtblPtrs[slot] = descriptorVtblPtrs[descriptorIndex]
        }
        slot += 1
    }
    vtblPtrs
}

func requireExplicitSchemaCustomVtbls(resolvedDescriptors: Array<ResolvedDescriptor>): Unit {
    if (customSlotCount(resolvedDescriptors) > 0) {
        throw Exception("schema-backed custom interfaces require explicit vtable pointers")
    }
}

func requireCompleteCustomVtbls(
    resolvedDescriptors: Array<ResolvedDescriptor>,
    customVtbls: Array<CPointer<Unit>>
): Unit {
    let slotCount = customSlotCount(resolvedDescriptors)
    if (hasMissingCustomVtbl(slotCount, customVtbls)) {
        throw Exception("custom interfaces require explicit vtable pointers for every resolved slot")
    }
}

func singleCustomVtblArray(
    resolvedDescriptors: Array<ResolvedDescriptor>,
    vtblPtr: CPointer<Unit>
): Array<CPointer<Unit>> {
    let slotCount = customSlotCount(resolvedDescriptors)
    if (slotCount == 0) {
        return emptyUnitPointerArray()
    }
    if (slotCount != 1 || vtblPtr.isNull()) {
        throw Exception("single custom vtable pointer requires exactly one resolved custom slot")
    }
    Array<CPointer<Unit>>(1, { _ => vtblPtr })
}

func createInlineSlotHandle(vtables: Array<CPointer<Unit>>): CPointer<CPointer<Unit>> {
    unsafe {
        windows_interface.allocateNativeArray<CPointer<Unit>>(vtables)
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

public class ComObject<T> <: Resource {
    private var slotHandle: Option<CPointer<CPointer<Unit>>> = None
    private var identityUnknownVtblHandle: Option<CPointer<IUnknownVtbl>> = None
    private var identityInspectableVtblHandle: Option<CPointer<IInspectableVtbl>> = None
    private var rawView: CPointer<Unit> = CPointer<Unit>()
    private var closed: Bool = false
    public let runtime: ComObjectRuntime<T>

    public init(inner: T, supportedIids: Array<GUID>, agile!: Bool = true) {
        let resolvedDescriptors = resolveSupportedIids(supportedIids)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        let vtblPtrs = descriptorCustomVtblArray(resolvedDescriptors)
        attachRuntime(defaultIdentityVtblPtr(supportedIids), vtblPtrs, resolvedDescriptors)
    }

    public init(inner: T, supportedIids: Array<GUID>, vtblPtr: CPointer<Unit>, agile!: Bool = true) {
        let resolvedDescriptors = resolveSupportedIids(supportedIids)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        let slotCount = customSlotCount(resolvedDescriptors)
        if (slotCount == 0) {
            attachRuntime(vtblPtr, emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            let customVtblPtrs = singleCustomVtblArray(resolvedDescriptors, vtblPtr)
            attachRuntime(defaultIdentityVtblPtr(supportedIids), customVtblPtrs, resolvedDescriptors)
        }
    }

    public init(inner: T, supportedIids: Array<GUID>, vtblPtrs: Array<CPointer<Unit>>, agile!: Bool = true) {
        let resolvedDescriptors = resolveSupportedIids(supportedIids)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        let slotCount = customSlotCount(resolvedDescriptors)
        if (slotCount == 0 && vtblPtrs.size > 0) {
            attachRuntime(vtblPtrs[0], emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            requireCompleteCustomVtbls(resolvedDescriptors, vtblPtrs)
            attachRuntime(defaultIdentityVtblPtr(supportedIids), vtblPtrs, resolvedDescriptors)
        }
    }

    public init(inner: T, supportedIids: Array<GUID>, resolvedDescriptors: Array<ResolvedDescriptor>, agile!: Bool = true) {
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        let slotCount = customSlotCount(resolvedDescriptors)
        let vtblPtrs = descriptorCustomVtblArray(resolvedDescriptors)
        if (slotCount == 0 && vtblPtrs.size > 0) {
            attachRuntime(vtblPtrs[0], emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            attachRuntime(defaultIdentityVtblPtr(supportedIids), vtblPtrs, resolvedDescriptors)
        }
    }

    public init(
        inner: T,
        supportedIids: Array<GUID>,
        resolvedDescriptors: Array<ResolvedDescriptor>,
        vtblPtr: CPointer<Unit>,
        agile!: Bool = true
    ) {
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        let slotCount = customSlotCount(resolvedDescriptors)
        if (slotCount == 0) {
            attachRuntime(vtblPtr, emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            let customVtblPtrs = singleCustomVtblArray(resolvedDescriptors, vtblPtr)
            attachRuntime(defaultIdentityVtblPtr(supportedIids), customVtblPtrs, resolvedDescriptors)
        }
    }

    public init(
        inner: T,
        supportedIids: Array<GUID>,
        resolvedDescriptors: Array<ResolvedDescriptor>,
        vtblPtrs: Array<CPointer<Unit>>,
        agile!: Bool = true
    ) {
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        let slotCount = customSlotCount(resolvedDescriptors)
        let customVtblPtrs = explicitCustomVtblArray(resolvedDescriptors, vtblPtrs)
        if (slotCount == 0 && vtblPtrs.size > 0) {
            attachRuntime(vtblPtrs[0], emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            requireCompleteCustomVtbls(resolvedDescriptors, customVtblPtrs)
            attachRuntime(defaultIdentityVtblPtr(supportedIids), customVtblPtrs, resolvedDescriptors)
        }
    }

    public init(inner: T, schemas: Array<InterfaceDescriptorSchema>, agile!: Bool = true) {
        let supportedIids = supportedIidsFromSchemas(schemas)
        let resolvedDescriptors = resolveSchemas(schemas)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        applyRuntimeTypeFromSchemas(runtime, schemas)
        requireExplicitSchemaCustomVtbls(resolvedDescriptors)
        let vtblPtrs = descriptorCustomVtblArray(resolvedDescriptors)
        attachRuntime(defaultIdentityVtblPtr(supportedIids), vtblPtrs, resolvedDescriptors)
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
            let customVtblPtrs = singleCustomVtblArray(resolvedDescriptors, vtblPtr)
            attachRuntime(defaultIdentityVtblPtr(supportedIids), customVtblPtrs, resolvedDescriptors)
        }
    }

    public init(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtrs: Array<CPointer<Unit>>, agile!: Bool = true) {
        let supportedIids = supportedIidsFromSchemas(schemas)
        let resolvedDescriptors = resolveSchemas(schemas)
        runtime = ComObjectRuntime<T>(inner, supportedIids, resolvedDescriptors)
        runtime.setAgileEnabled(agile)
        applyRuntimeTypeFromSchemas(runtime, schemas)
        let slotCount = customSlotCount(resolvedDescriptors)
        let customVtblPtrs = explicitCustomVtblArray(resolvedDescriptors, vtblPtrs)
        if (slotCount == 0 && vtblPtrs.size > 0) {
            attachRuntime(vtblPtrs[0], emptyUnitPointerArray(), resolvedDescriptors)
        } else {
            requireCompleteCustomVtbls(resolvedDescriptors, customVtblPtrs)
            attachRuntime(defaultIdentityVtblPtr(supportedIids), customVtblPtrs, resolvedDescriptors)
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

    public static func new(inner: T, supportedIids: Array<GUID>, vtblPtrs: Array<CPointer<Unit>>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, supportedIids, vtblPtrs, agile: agile)
    }

    public static func new(inner: T, schemas: Array<InterfaceDescriptorSchema>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, schemas, agile: agile)
    }

    public static func new(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtr: CPointer<Unit>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, schemas, vtblPtr, agile: agile)
    }

    public static func new(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtrs: Array<CPointer<Unit>>, agile!: Bool = true): ComObject<T> {
        ComObject<T>(inner, schemas, vtblPtrs, agile: agile)
    }

    public static func new<I>(inner: T, descriptors: Array<InterfaceDescriptor<I>>, agile!: Bool = true): ComObject<T> where I <: ComInterface {
        let supportedIids = supportedIidsFromDescriptors(descriptors)
        let resolvedDescriptors = resolveDescriptors(descriptors)
        let object = ComObject<T>(inner, supportedIids, resolvedDescriptors, agile: agile)
        applyRuntimeTypeFromDescriptors(object.runtime, descriptors)
        object
    }

    public static func new<I>(
        inner: T,
        descriptors: Array<InterfaceDescriptor<I>>,
        vtblPtr: CPointer<Unit>,
        agile!: Bool = true
    ): ComObject<T> where I <: ComInterface {
        let supportedIids = supportedIidsFromDescriptors(descriptors)
        let resolvedDescriptors = resolveDescriptors(descriptors)
        let object = ComObject<T>(inner, supportedIids, resolvedDescriptors, vtblPtr, agile: agile)
        applyRuntimeTypeFromDescriptors(object.runtime, descriptors)
        object
    }

    public static func new<I>(
        inner: T,
        descriptors: Array<InterfaceDescriptor<I>>,
        vtblPtrs: Array<CPointer<Unit>>,
        agile!: Bool = true
    ): ComObject<T> where I <: ComInterface {
        let supportedIids = supportedIidsFromDescriptors(descriptors)
        let resolvedDescriptors = resolveDescriptors(descriptors)
        let object = ComObject<T>(inner, supportedIids, resolvedDescriptors, vtblPtrs, agile: agile)
        applyRuntimeTypeFromDescriptors(object.runtime, descriptors)
        object
    }

    public static unsafe func fromRaw(raw: CPointer<Unit>): Result<ComObject<T>> {
        match (castFromRaw(raw)) {
            case Some(value) => Result<ComObject<T>>.Ok(value)
            case None => Result<ComObject<T>>.Err(WinError.fromHRESULT(HRESULT(E_NOINTERFACE)))
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

    private func ensureIdentityIUnknownVtblPtr(): CPointer<Unit> {
        match (identityUnknownVtblHandle) {
            case Some(handle) => return CPointer<Unit>(handle)
            case None => ()
        }
        let handle = unsafe { windows_interface.allocateNativeValue<IUnknownVtbl>(buildIUnknownVtbl()) }
        identityUnknownVtblHandle = Some(handle)
        CPointer<Unit>(handle)
    }

    private func ensureIdentityIInspectableVtblPtr(): CPointer<Unit> {
        match (identityInspectableVtblHandle) {
            case Some(handle) => return CPointer<Unit>(handle)
            case None => ()
        }
        let handle = unsafe { windows_interface.allocateNativeValue<IInspectableVtbl>(buildIInspectableVtbl()) }
        identityInspectableVtblHandle = Some(handle)
        CPointer<Unit>(handle)
    }

    private func defaultIdentityVtblPtr(supportedIids: Array<GUID>): CPointer<Unit> {
        if (shouldUseInspectableIdentity(supportedIids)) {
            return ensureIdentityIInspectableVtblPtr()
        }
        ensureIdentityIUnknownVtblPtr()
    }

    private func attachRuntime(
        identityVtblPtr: CPointer<Unit>,
        explicitCustomVtbls: Array<CPointer<Unit>>,
        resolvedDescriptors: Array<ResolvedDescriptor>
    ): Unit {
        let slotCount = customSlotCount(resolvedDescriptors)
        requireCompleteCustomVtbls(resolvedDescriptors, explicitCustomVtbls)

        let customVtables = resolvedCustomVtblArray(slotCount, explicitCustomVtbls)
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
            CPointer<Unit>(unsafe { handle + index })
        })
        rawView = rawPointers[0]
        runtime.setIdentityPointer(rawPointers[0])
        runtime.bindInterfacePointers(rawPointers)
        runtime.attach(Array<UIntNative>(rawPointers.size, { index => rawPointers[index].toUIntNative() }))

        let finalSlotHandle = slotHandle
        let finalIdentityUnknownVtblHandle = identityUnknownVtblHandle
        let finalIdentityInspectableVtblHandle = identityInspectableVtblHandle

        runtime.setOnDestroy({ =>
            match (finalIdentityInspectableVtblHandle) {
                case Some(vtblHandle) =>
                    unsafe { windows_interface.freeNativeValue(vtblHandle) }
                case None => ()
            }
            match (finalIdentityUnknownVtblHandle) {
                case Some(vtblHandle) =>
                    unsafe { windows_interface.freeNativeValue(vtblHandle) }
                case None => ()
            }
            match (finalSlotHandle) {
                case Some(inlineHandle) =>
                    unsafe { windows_interface.freeNativeValue(inlineHandle) }
                case None => ()
            }
        })
    }

    private func liveRaw(): CPointer<Unit> {
        if (rawView.isNotNull()) {
            return rawView
        }
        match (slotHandle) {
            case Some(handle) => CPointer<Unit>(handle)
            case None => CPointer<Unit>()
        }
    }

    public func asRaw(): CPointer<Unit> {
        if (isClosed()) {
            return CPointer<Unit>()
        }
        liveRaw()
    }

    public func addRefBase(): UInt32 {
        if (isClosed()) {
            closed = true
            return 0u32
        }
        runtime.addRefBase()
    }

    public func releaseBase(): UInt32 {
        if (isClosed()) {
            closed = true
            return 0u32
        }
        let count = runtime.releaseBase(liveRaw().toUIntNative())
        if (count == 0u32) {
            closed = true
        }
        count
    }

    public func isClosed(): Bool {
        closed || runtime.isDestroyed()
    }

    public func close(): Unit {
        if (isClosed()) {
            closed = true
            return
        }
        let _ = runtime.releaseBase(liveRaw().toUIntNative())
        closed = true
    }

    ~init() {
        if (closed || runtime.isDestroyed()) {
            return
        }
        closed = true
    }

    public func queryInterfaceBase(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (isClosed()) {
            closed = true
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
            return E_NOINTERFACE
        }
        runtime.queryInterfaceBase(asRaw(), iid, resultSlot)
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
                    case Some(runtime) =>
                        if (runtime.isDestroyed()) {
                            return None
                        }
                        let _ = runtime.addRefBase()
                        Some(ComObject<T>(runtime, runtime.identityPointer()))
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
        match (unsafe { queryInterfaceRaw(asRaw(), descriptor.iid) }) {
            case Some(raw) =>
                let view = descriptor.viewOf(raw)
                let _ = descriptor.releasePointer(raw)
                view
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
        let value = toInterface(descriptor)
        close()
        value
    }
}

func appendMethodSignature(sb: StringBuilder, method: InterfaceMethodSchema): Unit {
    sb.append("    public func ")
    sb.append(method.name)
    sb.append("(")
    var index: Int64 = 0
    while (index < visibleParameterCount(method)) {
        if (index > 0) {
            sb.append(", ")
        }
        sb.append(method.parameters[index].name)
        sb.append(": ")
        sb.append(method.parameters[index].callerType)
        index += 1
    }
    sb.append("): ")
    sb.append(implSurfaceReturnType(method))
    sb.append("\n")
}

public func renderImplSurface(descriptor: ResolvedDescriptor): String {
    let sb = StringBuilder()
    sb.append("public interface ")
    sb.append(descriptor.implSurfaceName)
    match (descriptor.baseInterfaceName) {
        case Some(name) =>
            sb.append(" <: ")
            sb.append(name)
            sb.append("_Impl")
        case None => ()
    }
    sb.append(" {\n")
    for (method in descriptor.methods) {
        appendMethodSignature(sb, method)
    }
    sb.append("}")
    sb.toString()
}
