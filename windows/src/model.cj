package windows

import std.collection.*
import stdx.encoding.json.*

public class MetadataTypeRecord {
    public let name: String
    public let namespace: String

    public init(name: String, namespace: String) {
        this.name = name
        this.namespace = namespace
    }

    public func fullName(): String {
        if (namespace.isEmpty()) {
            return name
        }
        return "${namespace}.${name}"
    }
}

public class SignatureRecord {
    public let kind: String
    public let name: String
    public let namespace: String
    public let hasNamespace: Bool
    public var typeSig: Option<SignatureRecord> = None
    public let typeArguments: ArrayList<SignatureRecord>
    public var modifierType: Option<SignatureRecord> = None
    public var unmodifiedType: Option<SignatureRecord> = None
    public var typeReference: Option<MetadataTypeRecord> = None
    public var typeDefinition: Option<MetadataTypeRecord> = None
    public var typeSpecification: Option<TypeSpecificationRecord> = None
    public var isRequired: Option<Bool> = None
    public var lowerBounds: Option<ArrayList<Int64>> = None
    public var rank: Option<Int64> = None
    public var sizes: Option<ArrayList<Int64>> = None
    public var comment: Option<String> = None

    public init(
        kind: String,
        name!: String = "",
        namespace!: String = "",
        hasNamespace!: Bool = false,
        typeSig!: Option<SignatureRecord> = None,
        typeArguments!: ArrayList<SignatureRecord> = ArrayList<SignatureRecord>(),
        modifierType!: Option<SignatureRecord> = None,
        unmodifiedType!: Option<SignatureRecord> = None,
        typeReference!: Option<MetadataTypeRecord> = None,
        typeDefinition!: Option<MetadataTypeRecord> = None,
        typeSpecification!: Option<TypeSpecificationRecord> = None,
        isRequired!: Option<Bool> = None,
        lowerBounds!: Option<ArrayList<Int64>> = None,
        rank!: Option<Int64> = None,
        sizes!: Option<ArrayList<Int64>> = None,
        comment!: Option<String> = None
    ) {
        this.kind = kind
        this.name = name
        this.namespace = namespace
        this.hasNamespace = hasNamespace
        this.typeSig = typeSig
        this.typeArguments = typeArguments
        this.modifierType = modifierType
        this.unmodifiedType = unmodifiedType
        this.typeReference = typeReference
        this.typeDefinition = typeDefinition
        this.typeSpecification = typeSpecification
        this.isRequired = isRequired
        this.lowerBounds = lowerBounds
        this.rank = rank
        this.sizes = sizes
        this.comment = comment
    }
}

public class CustomAttributeFixedArgumentRecord {
    public let typeSig: SignatureRecord
    public let value: Option<JsonValue>

    public init(typeSig: SignatureRecord, value!: Option<JsonValue> = None) {
        this.typeSig = typeSig
        this.value = value
    }
}

public class CustomAttributeNamedArgumentRecord {
    public let name: String
    public let typeSig: SignatureRecord
    public let kind: String
    public let value: Option<JsonValue>

    public init(name: String, typeSig: SignatureRecord, kind: String, value!: Option<JsonValue> = None) {
        this.name = name
        this.typeSig = typeSig
        this.kind = kind
        this.value = value
    }
}

public class CustomAttributeRecord {
    public let typeName: String
    public let fixedArguments: ArrayList<CustomAttributeFixedArgumentRecord>
    public let namedArguments: ArrayList<CustomAttributeNamedArgumentRecord>

    public init(
        typeName: String,
        fixedArguments!: ArrayList<CustomAttributeFixedArgumentRecord> = ArrayList<CustomAttributeFixedArgumentRecord>(),
        namedArguments!: ArrayList<CustomAttributeNamedArgumentRecord> = ArrayList<CustomAttributeNamedArgumentRecord>()
    ) {
        this.typeName = typeName
        this.fixedArguments = fixedArguments
        this.namedArguments = namedArguments
    }
}

public class TypeSpecificationRecord {
    public let signature: SignatureRecord
    public let customAttributes: ArrayList<CustomAttributeRecord>

    public init(
        signature: SignatureRecord,
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>()
    ) {
        this.signature = signature
        this.customAttributes = customAttributes
    }
}

public class TypeLayoutRecord {
    public let isDefault: Bool
    public let packingSize: Int64
    public let size: Int64

    public init(isDefault: Bool, packingSize: Int64, size: Int64) {
        this.isDefault = isDefault
        this.packingSize = packingSize
        this.size = size
    }
}

public class FieldRecord {
    public let name: String
    public let signature: SignatureRecord
    public let attributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>
    public let defaultValue: Option<JsonValue>
    public let offset: Int64
    public let relativeVirtualAddress: Int64

    public init(
        name: String,
        signature: SignatureRecord,
        attributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>(),
        defaultValue!: Option<JsonValue> = None,
        offset!: Int64 = 0,
        relativeVirtualAddress!: Int64 = 0
    ) {
        this.name = name
        this.signature = signature
        this.attributes = attributes
        this.customAttributes = customAttributes
        this.defaultValue = defaultValue
        this.offset = offset
        this.relativeVirtualAddress = relativeVirtualAddress
    }
}

public class ParameterRecord {
    public let name: String
    public let sequenceNumber: Int64
    public let attributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>
    public let defaultValue: Option<JsonValue>
    public let signature: Option<SignatureRecord>

    public init(
        name: String,
        sequenceNumber!: Int64 = 0,
        attributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>(),
        defaultValue!: Option<JsonValue> = None,
        signature!: Option<SignatureRecord> = None
    ) {
        this.name = name
        this.sequenceNumber = sequenceNumber
        this.attributes = attributes
        this.customAttributes = customAttributes
        this.defaultValue = defaultValue
        this.signature = signature
    }
}

public class MethodSignatureRecord {
    public let returnType: SignatureRecord
    public let parameters: ArrayList<SignatureRecord>
    public let requiredParameterCount: Int64
    public let genericParameterCount: Int64
    public let header: HashMap<String, JsonValue>

    public init(
        returnType: SignatureRecord,
        parameters!: ArrayList<SignatureRecord> = ArrayList<SignatureRecord>(),
        requiredParameterCount!: Int64 = 0,
        genericParameterCount!: Int64 = 0,
        header!: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    ) {
        this.returnType = returnType
        this.parameters = parameters
        this.requiredParameterCount = requiredParameterCount
        this.genericParameterCount = genericParameterCount
        this.header = header
    }
}

public class ModuleReferenceRecord {
    public let name: String
    public let customAttributes: ArrayList<CustomAttributeRecord>

    public init(name: String, customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>()) {
        this.name = name
        this.customAttributes = customAttributes
    }
}

public class MethodImportRecord {
    public let name: String
    public let moduleName: String
    public let moduleReference: Option<ModuleReferenceRecord>
    public let attributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>

    public init(
        name: String,
        moduleName: String,
        moduleReference!: Option<ModuleReferenceRecord> = None,
        attributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>()
    ) {
        this.name = name
        this.moduleName = moduleName
        this.moduleReference = moduleReference
        this.attributes = attributes
        this.customAttributes = customAttributes
    }
}

public class GenericParameterRecord {
    public let name: String
    public let sequenceNumber: Int64
    public let index: Option<Int64>
    public let attributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>
    public let constraints: ArrayList<JsonValue>

    public init(
        name: String,
        sequenceNumber!: Int64 = 0,
        index!: Option<Int64> = None,
        attributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>(),
        constraints!: ArrayList<JsonValue> = ArrayList<JsonValue>()
    ) {
        this.name = name
        this.sequenceNumber = sequenceNumber
        this.index = index
        this.attributes = attributes
        this.customAttributes = customAttributes
        this.constraints = constraints
    }
}

public class MethodRecord {
    public let name: String
    public let signature: MethodSignatureRecord
    public let parameters: ArrayList<ParameterRecord>
    public let attributes: ArrayList<String>
    public let implAttributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>
    public let relativeVirtualAddress: Int64
    public let methodImport: Option<MethodImportRecord>
    public let genericParameters: ArrayList<GenericParameterRecord>

    public init(
        name: String,
        signature: MethodSignatureRecord,
        parameters!: ArrayList<ParameterRecord> = ArrayList<ParameterRecord>(),
        attributes!: ArrayList<String> = ArrayList<String>(),
        implAttributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>(),
        relativeVirtualAddress!: Int64 = 0,
        methodImport!: Option<MethodImportRecord> = None,
        genericParameters!: ArrayList<GenericParameterRecord> = ArrayList<GenericParameterRecord>()
    ) {
        this.name = name
        this.signature = signature
        this.parameters = parameters
        this.attributes = attributes
        this.implAttributes = implAttributes
        this.customAttributes = customAttributes
        this.relativeVirtualAddress = relativeVirtualAddress
        this.methodImport = methodImport
        this.genericParameters = genericParameters
    }
}

public class InterfaceImplementationRecord {
    public let interfaceSignature: Option<SignatureRecord>
    public let typeDefinition: Option<MetadataTypeRecord>
    public let typeReference: Option<MetadataTypeRecord>
    public let typeSpecification: Option<TypeSpecificationRecord>
    public let customAttributes: ArrayList<CustomAttributeRecord>

    public init(
        interfaceSignature!: Option<SignatureRecord> = None,
        typeDefinition!: Option<MetadataTypeRecord> = None,
        typeReference!: Option<MetadataTypeRecord> = None,
        typeSpecification!: Option<TypeSpecificationRecord> = None,
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>()
    ) {
        this.interfaceSignature = interfaceSignature
        this.typeDefinition = typeDefinition
        this.typeReference = typeReference
        this.typeSpecification = typeSpecification
        this.customAttributes = customAttributes
    }
}

public class EventRecord {
    public let name: String
    public let typeSig: SignatureRecord
    public let attributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>
    public let accessors: HashMap<String, JsonValue>

    public init(
        name: String,
        typeSig: SignatureRecord,
        attributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>(),
        accessors!: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    ) {
        this.name = name
        this.typeSig = typeSig
        this.attributes = attributes
        this.customAttributes = customAttributes
        this.accessors = accessors
    }
}

public class PropertyRecord {
    public let name: String
    public let signature: MethodSignatureRecord
    public let attributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>
    public let accessors: HashMap<String, JsonValue>
    public let defaultValue: Option<JsonValue>

    public init(
        name: String,
        signature: MethodSignatureRecord,
        attributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>(),
        accessors!: HashMap<String, JsonValue> = HashMap<String, JsonValue>(),
        defaultValue!: Option<JsonValue> = None
    ) {
        this.name = name
        this.signature = signature
        this.attributes = attributes
        this.customAttributes = customAttributes
        this.accessors = accessors
        this.defaultValue = defaultValue
    }
}

public class TypeDefinitionRecord {
    public let namespace: String
    public let name: String
    public let metadataToken: String
    public let baseType: String
    public let hasBaseType: Bool
    public let isNested: Bool
    public let attributes: ArrayList<String>
    public let customAttributes: ArrayList<CustomAttributeRecord>
    public let fields: ArrayList<FieldRecord>
    public let interfaceImplementations: ArrayList<InterfaceImplementationRecord>
    public let layout: Option<TypeLayoutRecord>
    public let methods: ArrayList<MethodRecord>
    public let nestedTypes: ArrayList<TypeDefinitionRecord>
    public let genericParameters: ArrayList<GenericParameterRecord>
    public let events: ArrayList<EventRecord>
    public let properties: ArrayList<PropertyRecord>
    public let supportedArchitectures: ArrayList<String>
    public let supportedOsPlatform: Option<String>
    public let isExperimental: Bool
    public let sourceSet: String

    public init(
        namespace: String,
        name: String,
        metadataToken!: String = "",
        baseType!: String = "",
        hasBaseType!: Bool = false,
        isNested!: Bool = false,
        attributes!: ArrayList<String> = ArrayList<String>(),
        customAttributes!: ArrayList<CustomAttributeRecord> = ArrayList<CustomAttributeRecord>(),
        fields!: ArrayList<FieldRecord> = ArrayList<FieldRecord>(),
        interfaceImplementations!: ArrayList<InterfaceImplementationRecord> = ArrayList<InterfaceImplementationRecord>(),
        layout!: Option<TypeLayoutRecord> = None,
        methods!: ArrayList<MethodRecord> = ArrayList<MethodRecord>(),
        nestedTypes!: ArrayList<TypeDefinitionRecord> = ArrayList<TypeDefinitionRecord>(),
        genericParameters!: ArrayList<GenericParameterRecord> = ArrayList<GenericParameterRecord>(),
        events!: ArrayList<EventRecord> = ArrayList<EventRecord>(),
        properties!: ArrayList<PropertyRecord> = ArrayList<PropertyRecord>(),
        supportedArchitectures!: ArrayList<String> = ArrayList<String>(),
        supportedOsPlatform!: Option<String> = None,
        isExperimental!: Bool = false,
        sourceSet!: String = "winmd_main"
    ) {
        this.namespace = namespace
        this.name = name
        this.metadataToken = metadataToken
        this.baseType = baseType
        this.hasBaseType = hasBaseType
        this.isNested = isNested
        this.attributes = attributes
        this.customAttributes = customAttributes
        this.fields = fields
        this.interfaceImplementations = interfaceImplementations
        this.layout = layout
        this.methods = methods
        this.nestedTypes = nestedTypes
        this.genericParameters = genericParameters
        this.events = events
        this.properties = properties
        this.supportedArchitectures = supportedArchitectures
        this.supportedOsPlatform = supportedOsPlatform
        this.isExperimental = isExperimental
        this.sourceSet = sourceSet
    }

    public func fullName(): String {
        if (namespace.isEmpty()) {
            return name
        }
        return "${namespace}.${name}"
    }
}

public class WinmdFileRecord {
    public let winmdFile: String
    public let winmdSha256: String
    public let toolVersion: String
    public let schemaVersion: String
    public let sourceSet: String
    public let types: ArrayList<TypeDefinitionRecord>

    public init(
        winmdFile: String,
        winmdSha256: String,
        toolVersion: String,
        schemaVersion: String,
        sourceSet: String,
        types: ArrayList<TypeDefinitionRecord>
    ) {
        this.winmdFile = winmdFile
        this.winmdSha256 = winmdSha256
        this.toolVersion = toolVersion
        this.schemaVersion = schemaVersion
        this.sourceSet = sourceSet
        this.types = types
    }
}

public class SymbolRecord {
    public let fullName: String
    public let namespace: String
    public let name: String
    public let implName: String
    public let metadataToken: String
    public let dependencies: ArrayList<String>
    public let implSource: String
    public let typeDef: Option<TypeDefinitionRecord>

    public init(
        fullName: String,
        namespace: String,
        name: String,
        implName: String,
        dependencies: Array<String>,
        implSource!: String = "",
        metadataToken!: String = "",
        typeDef!: Option<TypeDefinitionRecord> = None
    ) {
        this.fullName = fullName
        this.namespace = namespace
        this.name = name
        this.implName = implName
        this.metadataToken = metadataToken
        this.dependencies = ArrayList<String>()
        for (dependency in dependencies) {
            this.dependencies.add(dependency)
        }
        this.implSource = implSource
        this.typeDef = typeDef
    }

    public init(
        fullName: String,
        namespace: String,
        name: String,
        implName: String,
        dependencies: ArrayList<String>,
        implSource!: String = "",
        metadataToken!: String = "",
        typeDef!: Option<TypeDefinitionRecord> = None
    ) {
        this.fullName = fullName
        this.namespace = namespace
        this.name = name
        this.implName = implName
        this.metadataToken = metadataToken
        this.dependencies = dependencies
        this.implSource = implSource
        this.typeDef = typeDef
    }
}
