package windows_interface

import std.collection.*

func containsString(values: ArrayList<String>, candidate: String): Bool {
    for (value in values) {
        if (value == candidate) {
            return true
        }
    }
    false
}

func containsSchemaGuid(values: ArrayList<GUID>, candidate: GUID): Bool {
    for (value in values) {
        if (value == candidate) {
            return true
        }
    }
    false
}

func appendUniqueString(values: ArrayList<String>, candidate: String): Unit {
    if (!containsString(values, candidate)) {
        values.add(candidate)
    }
}

func appendUniqueSchemaGuid(values: ArrayList<GUID>, candidate: GUID): Unit {
    if (!containsSchemaGuid(values, candidate)) {
        values.add(candidate)
    }
}

func expandedAncestorInterfaceNames(baseSchema: InterfaceDescriptorSchema): Array<String> {
    let values = ArrayList<String>()
    appendUniqueString(values, baseSchema.interfaceName)
    for (ancestorName in baseSchema.ancestorInterfaceNames) {
        appendUniqueString(values, ancestorName)
    }
    values.toArray()
}

func expandedAncestorSchemaIids(baseSchema: InterfaceDescriptorSchema): Array<GUID> {
    let values = ArrayList<GUID>()
    appendUniqueSchemaGuid(values, baseSchema.iid)
    for (ancestorIid in baseSchema.ancestorIids) {
        appendUniqueSchemaGuid(values, ancestorIid)
    }
    values.toArray()
}

// InterfaceMethodSchema is the authoring-side ABI contract that windows-implement
// will consume when it starts generating vtables and `_Impl` surfaces.
public enum InterfaceParameterBridgeKind {
    | Value
    | Ref
    | OutRef
}

public class InterfaceParameterSchema {
    public let name: String
    public let abiType: String
    public let callerType: String
    public let bridgeKind: InterfaceParameterBridgeKind

    public init(
        name: String,
        abiType: String,
        callerType: String,
        bridgeKind: InterfaceParameterBridgeKind
    ) {
        this.name = name
        this.abiType = abiType
        this.callerType = callerType
        this.bridgeKind = bridgeKind
    }
}

public class InterfaceMethodSchema {
    public let name: String
    public let abiSlot: Int64
    public let parameters: Array<InterfaceParameterSchema>
    public let returnType: String

    public init(
        name: String,
        abiSlot: Int64,
        parameters: Array<InterfaceParameterSchema>,
        returnType: String
    ) {
        this.name = name
        this.abiSlot = abiSlot
        this.parameters = parameters
        this.returnType = returnType
    }

    public init(name: String, parameters: Array<InterfaceParameterSchema>, returnType: String) {
        this.name = name
        this.abiSlot = -1
        this.parameters = parameters
        this.returnType = returnType
    }

    public init(name: String, abiSlot: Int64, parameterTypes: Array<String>, returnType: String) {
        this.name = name
        this.abiSlot = abiSlot
        this.parameters = Array<InterfaceParameterSchema>(parameterTypes.size, { index =>
            InterfaceParameterSchema(
                "arg${index}",
                parameterTypes[index],
                parameterTypes[index],
                InterfaceParameterBridgeKind.Value
            )
        })
        this.returnType = returnType
    }

    public init(name: String, parameterTypes: Array<String>, returnType: String) {
        this.name = name
        this.abiSlot = -1
        this.parameters = Array<InterfaceParameterSchema>(parameterTypes.size, { index =>
            InterfaceParameterSchema(
                "arg${index}",
                parameterTypes[index],
                parameterTypes[index],
                InterfaceParameterBridgeKind.Value
            )
        })
        this.returnType = returnType
    }

    public prop parameterTypes: Array<String> {
        get() {
            Array<String>(parameters.size, { index =>
                parameters[index].abiType
            })
        }
    }
}

// InterfaceDescriptorSchema is the canonical schema handoff from windows-interface
// to windows-implement. Vtable generation must preserve the declared base prefix,
// method slot order, and `_Impl` surface name exactly.
public class InterfaceDescriptorSchema {
    public let interfaceName: String
    public let iid: GUID
    public var runtimeTypeContract: Option<RuntimeTypeContract> = None
    public let baseInterfaceName: Option<String>
    public let baseIid: Option<GUID>
    public let directBaseSchema: Option<InterfaceDescriptorSchema>
    public let ancestorInterfaceNames: Array<String>
    public let ancestorIids: Array<GUID>
    public let vtableTypeName: String
    public let wrapperTypeName: String
    public let implSurfaceName: String
    public let methods: Array<InterfaceMethodSchema>

    public init(
        interfaceName: String,
        iid: GUID,
        vtableTypeName: String,
        wrapperTypeName: String,
        implSurfaceName: String,
        methods: Array<InterfaceMethodSchema>
    ) {
        this.interfaceName = interfaceName
        this.iid = iid
        this.baseInterfaceName = None
        this.baseIid = None
        this.directBaseSchema = None
        this.ancestorInterfaceNames = []
        this.ancestorIids = []
        this.vtableTypeName = vtableTypeName
        this.wrapperTypeName = wrapperTypeName
        this.implSurfaceName = implSurfaceName
        this.methods = methods
    }

    public init(
        interfaceName: String,
        iid: GUID,
        baseInterfaceName: String,
        baseIid: GUID,
        vtableTypeName: String,
        wrapperTypeName: String,
        implSurfaceName: String,
        methods: Array<InterfaceMethodSchema>
    ) {
        this.interfaceName = interfaceName
        this.iid = iid
        this.baseInterfaceName = Some(baseInterfaceName)
        this.baseIid = Some(baseIid)
        this.directBaseSchema = None
        this.ancestorInterfaceNames = [baseInterfaceName]
        this.ancestorIids = [baseIid]
        this.vtableTypeName = vtableTypeName
        this.wrapperTypeName = wrapperTypeName
        this.implSurfaceName = implSurfaceName
        this.methods = methods
    }

    public init(
        interfaceName: String,
        iid: GUID,
        baseSchema: InterfaceDescriptorSchema,
        vtableTypeName: String,
        wrapperTypeName: String,
        implSurfaceName: String,
        methods: Array<InterfaceMethodSchema>
    ) {
        this.interfaceName = interfaceName
        this.iid = iid
        this.baseInterfaceName = Some(baseSchema.interfaceName)
        this.baseIid = Some(baseSchema.iid)
        this.directBaseSchema = Some(baseSchema)
        this.ancestorInterfaceNames = expandedAncestorInterfaceNames(baseSchema)
        this.ancestorIids = expandedAncestorSchemaIids(baseSchema)
        this.vtableTypeName = vtableTypeName
        this.wrapperTypeName = wrapperTypeName
        this.implSurfaceName = implSurfaceName
        this.methods = methods
    }

    public init(
        interfaceName: String,
        iid: GUID,
        ancestorInterfaceNames: Array<String>,
        ancestorIids: Array<GUID>,
        vtableTypeName: String,
        wrapperTypeName: String,
        implSurfaceName: String,
        methods: Array<InterfaceMethodSchema>
    ) {
        this.interfaceName = interfaceName
        this.iid = iid
        if (ancestorInterfaceNames.size == 0) {
            this.baseInterfaceName = None
        } else {
            this.baseInterfaceName = Some(ancestorInterfaceNames[0])
        }
        if (ancestorIids.size == 0) {
            this.baseIid = None
        } else {
            this.baseIid = Some(ancestorIids[0])
        }
        this.directBaseSchema = None
        this.ancestorInterfaceNames = ancestorInterfaceNames
        this.ancestorIids = ancestorIids
        this.vtableTypeName = vtableTypeName
        this.wrapperTypeName = wrapperTypeName
        this.implSurfaceName = implSurfaceName
        this.methods = methods
    }
}

public interface DescriptorSchemaProvider {
    static func descriptorSchema(): InterfaceDescriptorSchema
}
