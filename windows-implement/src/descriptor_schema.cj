package windows_implement

public import windows_interface.*

import std.collection.*
import std.reflect.*

func emptyMethodSchemas(): Array<InterfaceMethodSchema> {
    Array<InterfaceMethodSchema>(0, { _ =>
        InterfaceMethodSchema("", 0, Array<String>(0, { _ => "" }), "")
    })
}

func emptyStrings(): Array<String> {
    Array<String>(0, { _ => "" })
}

func emptyGuids(): Array<GUID> {
    Array<GUID>(0, { _ => GUID_ZERO })
}

func containsGuid(values: Array<GUID>, candidate: GUID): Bool {
    for (value in values) {
        if (value == candidate) {
            return true
        }
    }
    false
}

func directBaseIidFromDescriptor<I>(descriptor: InterfaceDescriptor<I>): Option<GUID> {
    descriptor.baseIid
}

func isComDescriptor(iid: GUID, ancestorIids: Array<GUID>): Bool {
    iid == IID_IUNKNOWN ||
        iid == IID_IINSPECTABLE ||
        containsGuid(ancestorIids, IID_IUNKNOWN) ||
        containsGuid(ancestorIids, IID_IINSPECTABLE)
}

func builtInOwnMethodSlotCount(iid: GUID): Int64 {
    if (iid == IID_IUNKNOWN) {
        return 3
    }
    if (iid == IID_IINSPECTABLE) {
        return 3
    }
    0
}

func fixedAbiTotalSlotCountForBaseSchema(schema: InterfaceDescriptorSchema): Option<Int64> {
    if (schema.iid == IID_IUNKNOWN) {
        return Some(3)
    }
    if (schema.iid == IID_IINSPECTABLE) {
        return Some(6)
    }
    None
}

func abiPrefixSlotCountForSchema(schema: InterfaceDescriptorSchema): Int64 {
    if (schema.iid == IID_IUNKNOWN) {
        return 0
    }
    if (schema.iid == IID_IINSPECTABLE) {
        return 3
    }
    match (schema.directBaseSchema) {
        case Some(baseSchema) =>
            match (fixedAbiTotalSlotCountForBaseSchema(baseSchema)) {
                case Some(slotCount) => slotCount
                case None => totalAbiSlotCountForSchema(baseSchema)
            }
        case None =>
            match (schema.baseIid) {
                case Some(baseIid) =>
                    if (baseIid == IID_IUNKNOWN) {
                        return 3
                    }
                    if (baseIid == IID_IINSPECTABLE) {
                        return 6
                    }
                    if (containsGuid(schema.ancestorIids, IID_IINSPECTABLE)) {
                        return 6
                    }
                    if (containsGuid(schema.ancestorIids, IID_IUNKNOWN)) {
                        return 3
                    }
                    0
                case None =>
                    if (containsGuid(schema.ancestorIids, IID_IINSPECTABLE)) {
                        return 6
                    }
                    if (containsGuid(schema.ancestorIids, IID_IUNKNOWN)) {
                        return 3
                    }
                    0
            }
    }
}

func totalAbiSlotCountForSchema(schema: InterfaceDescriptorSchema): Int64 {
    abiPrefixSlotCountForSchema(schema) + builtInOwnMethodSlotCount(schema.iid) + schema.methods.size
}

func totalAbiSlotCountForDescriptorBase(base: InterfaceDescriptorBase): Int64 {
    let iid = base.descriptorIid()
    if (iid == IID_IUNKNOWN) {
        return 3
    }
    if (iid == IID_IINSPECTABLE) {
        return 6
    }
    match (base.descriptorDirectBase()) {
        case Some(grandBase) =>
            totalAbiSlotCountForDescriptorBase(grandBase) + base.descriptorOwnMethodCount()
        case None =>
            let ancestorIids = base.descriptorAncestorIids()
            if (containsGuid(ancestorIids, IID_IINSPECTABLE)) {
                return 6 + base.descriptorOwnMethodCount()
            }
            if (containsGuid(ancestorIids, IID_IUNKNOWN)) {
                return 3 + base.descriptorOwnMethodCount()
            }
            base.descriptorOwnMethodCount()
    }
}

func abiPrefixSlotCountForDescriptor<I>(descriptor: InterfaceDescriptor<I>): Int64 {
    if (descriptor.iid == IID_IUNKNOWN) {
        return 0
    }
    if (descriptor.iid == IID_IINSPECTABLE) {
        return 3
    }
    match (descriptor.directBaseDescriptor()) {
        case Some(base) =>
            totalAbiSlotCountForDescriptorBase(base)
        case None =>
            match (descriptor.baseIid) {
                case Some(baseIid) =>
                    if (baseIid == IID_IUNKNOWN) {
                        return 3
                    }
                    if (baseIid == IID_IINSPECTABLE) {
                        return 6
                    }
                    if (containsGuid(descriptor.ancestorIids, IID_IINSPECTABLE)) {
                        return 6
                    }
                    if (containsGuid(descriptor.ancestorIids, IID_IUNKNOWN)) {
                        return 3
                    }
                    0
                case None =>
                    if (containsGuid(descriptor.ancestorIids, IID_IINSPECTABLE)) {
                        return 6
                    }
                    if (containsGuid(descriptor.ancestorIids, IID_IUNKNOWN)) {
                        return 3
                    }
                    0
            }
    }
}

func copyMethods(methods: Array<InterfaceMethodSchema>): Array<InterfaceMethodSchema> {
    Array<InterfaceMethodSchema>(methods.size, { index => methods[index] })
}

func sortMethodsByAbiSlot(methods: Array<InterfaceMethodSchema>): Array<InterfaceMethodSchema> {
    var sorted = copyMethods(methods)
    var left: Int64 = 0
    while (left < sorted.size) {
        var minIndex = left
        var right = left + 1
        while (right < sorted.size) {
            if (sorted[right].abiSlot < sorted[minIndex].abiSlot) {
                minIndex = right
            }
            right += 1
        }
        if (minIndex != left) {
            let current = sorted[left]
            sorted[left] = sorted[minIndex]
            sorted[minIndex] = current
        }
        left += 1
    }
    sorted
}

func hasAutomaticAbiSlot(method: InterfaceMethodSchema): Bool {
    method.abiSlot < 0
}

func withAbiSlot(method: InterfaceMethodSchema, abiSlot: Int64): InterfaceMethodSchema {
    InterfaceMethodSchema(method.name, abiSlot, method.parameters, method.returnType)
}

func normalizeMethodSchemas(
    interfaceName: String,
    methods: Array<InterfaceMethodSchema>,
    abiPrefixSlotCount: Int64
): Array<InterfaceMethodSchema> {
    if (methods.size == 0) {
        return methods
    }

    var sawAutomatic = false
    var sawExplicit = false
    for (method in methods) {
        if (hasAutomaticAbiSlot(method)) {
            sawAutomatic = true
        } else {
            sawExplicit = true
        }
    }

    if (sawAutomatic && sawExplicit) {
        throw IllegalArgumentException("${interfaceName} mixes automatic and explicit abi slots")
    }

    if (sawAutomatic) {
        return Array<InterfaceMethodSchema>(methods.size, { index =>
            withAbiSlot(methods[index], abiPrefixSlotCount + index)
        })
    }

    let sorted = sortMethodsByAbiSlot(methods)
    var expectedSlot = abiPrefixSlotCount
    for (method in sorted) {
        if (method.abiSlot != expectedSlot) {
            throw IllegalArgumentException(
                "${interfaceName} declares abi slot ${method.abiSlot.toString()} but expected ${expectedSlot.toString()}"
            )
        }
        expectedSlot += 1
    }
    sorted
}

// Adapter-only view derived from windows-interface schema objects.
// This is not a new interface truth source; it is just the minimum runtime
// shape the implement side needs after consuming the schema contract.
public struct ResolvedDescriptor {
    public let name: String
    public let iid: GUID
    public let directBaseName: Option<String>
    public let directBaseIid: Option<GUID>
    public let ancestorInterfaceNames: Array<String>
    public let ancestorIids: Array<GUID>
    public let slotIndex: Int64
    public let abiPrefixSlotCount: Int64
    public let isComInterface: Bool
    public let runtimeTypeContract: Option<RuntimeTypeContract>
    public let vtableTypeName: String
    public let wrapperTypeName: String
    public let wrapperQualifiedTypeName: Option<String>
    public let implSurfaceName: String
    public let methods: Array<InterfaceMethodSchema>

    public init(
        name: String,
        iid: GUID,
        directBaseName: Option<String>,
        directBaseIid: Option<GUID>,
        ancestorInterfaceNames: Array<String>,
        ancestorIids: Array<GUID>,
        slotIndex: Int64,
        abiPrefixSlotCount: Int64,
        isComInterface: Bool,
        runtimeTypeContract: Option<RuntimeTypeContract>,
        vtableTypeName: String,
        wrapperTypeName: String,
        wrapperQualifiedTypeName: Option<String>,
        implSurfaceName: String,
        methods: Array<InterfaceMethodSchema>
    ) {
        this.name = name
        this.iid = iid
        this.directBaseName = directBaseName
        this.directBaseIid = directBaseIid
        this.ancestorInterfaceNames = ancestorInterfaceNames
        this.ancestorIids = ancestorIids
        this.slotIndex = slotIndex
        this.abiPrefixSlotCount = abiPrefixSlotCount
        this.isComInterface = isComInterface
        this.runtimeTypeContract = runtimeTypeContract
        this.vtableTypeName = vtableTypeName
        this.wrapperTypeName = wrapperTypeName
        this.wrapperQualifiedTypeName = wrapperQualifiedTypeName
        this.implSurfaceName = implSurfaceName
        this.methods = methods
    }

    public func withSlotIndex(slotIndex: Int64): ResolvedDescriptor {
        ResolvedDescriptor(
            name,
            iid,
            directBaseName,
            directBaseIid,
            ancestorInterfaceNames,
            ancestorIids,
            slotIndex,
            abiPrefixSlotCount,
            isComInterface,
            runtimeTypeContract,
            vtableTypeName,
            wrapperTypeName,
            wrapperQualifiedTypeName,
            implSurfaceName,
            methods
        )
    }

    public prop baseInterfaceName: Option<String> {
        get() {
            match (directBaseName) {
                case Some(name) => Some(name)
                case None =>
                    if (ancestorInterfaceNames.size == 0) {
                        return None
                    }
                    Some(ancestorInterfaceNames[0])
            }
        }
    }

    public prop baseIid: Option<GUID> {
        get() {
            match (directBaseIid) {
                case Some(iid) => Some(iid)
                case None =>
                    if (ancestorIids.size == 0) {
                        return None
                    }
                    Some(ancestorIids[0])
            }
        }
    }

    public func matches(candidate: GUID): Bool {
        if (iid == candidate) {
            return true
        }
        for (ancestor in ancestorIids) {
            if (ancestor == candidate) {
                return true
            }
        }
        false
    }

    public func matchesNonIdentity(candidate: GUID): Bool {
        if (candidate == IID_IUNKNOWN || candidate == IID_IINSPECTABLE) {
            return false
        }
        matches(candidate)
    }
}

func resolveSchemaCore(schema: InterfaceDescriptorSchema): ResolvedDescriptor {
    let abiPrefixSlotCount = abiPrefixSlotCountForSchema(schema)
    let methods = normalizeMethodSchemas(schema.interfaceName, schema.methods, abiPrefixSlotCount)
    ResolvedDescriptor(
        schema.interfaceName,
        schema.iid,
        schema.baseInterfaceName,
        schema.baseIid,
        schema.ancestorInterfaceNames,
        schema.ancestorIids,
        0,
        abiPrefixSlotCount,
        isComDescriptor(schema.iid, schema.ancestorIids),
        schema.runtimeTypeContract,
        schema.vtableTypeName,
        schema.wrapperTypeName,
        None,
        schema.implSurfaceName,
        methods
    )
}

func qualifiedWrapperTypeNameForDescriptor<I>(descriptor: InterfaceDescriptor<I>): Option<String> {
    let typeInfo = TypeInfo.of<I>()
    if (typeInfo.name != descriptor.name) {
        return None
    }
    Some(typeInfo.qualifiedName)
}

func resolveDescriptorCore<I>(descriptor: InterfaceDescriptor<I>): ResolvedDescriptor {
    let abiPrefixSlotCount = abiPrefixSlotCountForDescriptor(descriptor)
    let methods = normalizeMethodSchemas(descriptor.name, descriptor.methods, abiPrefixSlotCount)
    ResolvedDescriptor(
        descriptor.name,
        descriptor.iid,
        descriptor.directBaseName,
        directBaseIidFromDescriptor(descriptor),
        emptyStrings(),
        descriptor.ancestorIids,
        0,
        abiPrefixSlotCount,
        isComDescriptor(descriptor.iid, descriptor.ancestorIids),
        descriptor.runtimeTypeContract,
        "${descriptor.name}Vtbl",
        descriptor.name,
        qualifiedWrapperTypeNameForDescriptor(descriptor),
        "${descriptor.name}_Impl",
        methods
    )
}

func resolvedDescriptorKey(value: ResolvedDescriptor): String {
    value.iid.toString()
}

func findDirectChildIndex(values: Array<ResolvedDescriptor>, parentIid: GUID): Int64 {
    var index: Int64 = 0
    while (index < values.size) {
        match (values[index].directBaseIid) {
            case Some(baseIid) =>
                if (baseIid == parentIid) {
                    return index
                }
            case None => ()
        }
        index += 1
    }
    -1
}

func findChainLeafIndex(values: Array<ResolvedDescriptor>, startIndex: Int64): Int64 {
    var currentIndex = startIndex
    while (true) {
        let childIndex = findDirectChildIndex(values, values[currentIndex].iid)
        if (childIndex < 0) {
            return currentIndex
        }
        currentIndex = childIndex
    }
    return currentIndex
}

func assignSlotIndices(values: Array<ResolvedDescriptor>): Array<ResolvedDescriptor> {
    if (values.size == 0) {
        return values
    }

    let chainSlots = HashMap<String, Int64>()
    var nextSlotIndex: Int64 = 1
    var result = Array<ResolvedDescriptor>(values.size, { _ =>
        ResolvedDescriptor(
            "",
            GUID_ZERO,
            None,
            None,
            emptyStrings(),
            emptyGuids(),
            0,
            0,
            false,
            None,
            "",
            "",
            None,
            "",
            emptyMethodSchemas()
        )
    })

    var index: Int64 = 0
    while (index < values.size) {
        let value = values[index]
        if (!value.isComInterface || value.iid == IID_IUNKNOWN || value.iid == IID_IINSPECTABLE) {
            result[index] = value.withSlotIndex(0)
            index += 1
            continue
        }

        let leafIndex = findChainLeafIndex(values, index)
        let chainKey = resolvedDescriptorKey(values[leafIndex])
        let slotIndex = if (chainSlots.contains(chainKey)) {
            chainSlots[chainKey]
        } else {
            let assigned = nextSlotIndex
            chainSlots.add(chainKey, assigned)
            nextSlotIndex += 1
            assigned
        }
        result[index] = value.withSlotIndex(slotIndex)
        index += 1
    }

    result
}

public func resolveSchema(schema: InterfaceDescriptorSchema): ResolvedDescriptor {
    assignSlotIndices([resolveSchemaCore(schema)])[0]
}

public func resolveDescriptor<I>(descriptor: InterfaceDescriptor<I>): ResolvedDescriptor {
    assignSlotIndices([resolveDescriptorCore(descriptor)])[0]
}

public func resolveSchemas(schemas: Array<InterfaceDescriptorSchema>): Array<ResolvedDescriptor> {
    let provisional = Array<ResolvedDescriptor>(schemas.size, { index =>
        resolveSchemaCore(schemas[index])
    })
    assignSlotIndices(provisional)
}

public func resolveDescriptors<I>(descriptors: Array<InterfaceDescriptor<I>>): Array<ResolvedDescriptor> {
    let provisional = Array<ResolvedDescriptor>(descriptors.size, { index =>
        resolveDescriptorCore(descriptors[index])
    })
    assignSlotIndices(provisional)
}

public func resolveSupportedIids(supportedIids: Array<GUID>): Array<ResolvedDescriptor> {
    let result = ArrayList<ResolvedDescriptor>()
    var nextSlotIndex: Int64 = 1
    for (iid in supportedIids) {
        if (containsResolvedDescriptorIid(result, iid)) {
            continue
        }
        let slotIndex = slotIndexForIid(iid, nextSlotIndex)
        result.add(
            ResolvedDescriptor(
                iid.toString(),
                iid,
                None,
                None,
                emptyStrings(),
                emptyGuids(),
                slotIndex,
                if (iid == IID_IUNKNOWN) {
                    0
                } else if (iid == IID_IINSPECTABLE) {
                    3
                } else {
                    0
                },
                isComDescriptor(iid, emptyGuids()),
                None,
                "IUnknownVtbl",
                "IUnknown",
                None,
                "IUnknown_Impl",
                emptyMethodSchemas()
            )
        )
        if (slotIndex != 0) {
            nextSlotIndex += 1
        }
    }
    toResolvedDescriptorArray(result)
}

public func supportedIidsFromSchemas(schemas: Array<InterfaceDescriptorSchema>): Array<GUID> {
    let result = ArrayList<GUID>()
    for (schema in schemas) {
        appendResolvedIids(result, resolveSchemaCore(schema))
    }
    toGuidArray(result)
}

public func supportedIidsFromDescriptors<I>(descriptors: Array<InterfaceDescriptor<I>>): Array<GUID> {
    let result = ArrayList<GUID>()
    for (descriptor in descriptors) {
        appendResolvedIids(result, resolveDescriptorCore(descriptor))
    }
    toGuidArray(result)
}

func appendResolvedIids(result: ArrayList<GUID>, descriptor: ResolvedDescriptor): Unit {
    if (!containsGuid(result, descriptor.iid)) {
        result.add(descriptor.iid)
    }
    for (ancestor in descriptor.ancestorIids) {
        if (!containsGuid(result, ancestor)) {
            result.add(ancestor)
        }
    }
}

func slotIndexForIid(iid: GUID, nextSlotIndex: Int64): Int64 {
    if (iid == IID_IUNKNOWN || iid == IID_IINSPECTABLE) {
        return 0
    }
    nextSlotIndex
}

func containsResolvedDescriptorIid(values: ArrayList<ResolvedDescriptor>, candidate: GUID): Bool {
    for (value in values) {
        if (value.iid == candidate) {
            return true
        }
    }
    false
}

func containsGuid(values: ArrayList<GUID>, candidate: GUID): Bool {
    for (value in values) {
        if (value == candidate) {
            return true
        }
    }
    false
}

func toGuidArray(values: ArrayList<GUID>): Array<GUID> {
    var result = Array<GUID>(values.size, { _ => GUID_ZERO })
    var index: Int64 = 0
    for (value in values) {
        result[index] = value
        index += 1
    }
    result
}

func toResolvedDescriptorArray(values: ArrayList<ResolvedDescriptor>): Array<ResolvedDescriptor> {
    var result = Array<ResolvedDescriptor>(values.size, { _ =>
        ResolvedDescriptor("", GUID_ZERO, None, None, emptyStrings(), emptyGuids(), 0, 0, false, None, "", "", None, "", emptyMethodSchemas())
    })
    var index: Int64 = 0
    for (value in values) {
        result[index] = value
        index += 1
    }
    result
}
