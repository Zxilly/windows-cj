package windows_bindgen

import std.collection.*
import std.fs.*
import stdx.encoding.json.*

public func loadWinmdJsonFiles(paths: Array<String>): ArrayList<WinmdFileRecord> {
    let list = ArrayList<String>()
    for (path in paths) {
        list.add(path)
    }
    return loadWinmdJsonFiles(list)
}

public func loadWinmdJsonFiles(paths: ArrayList<String>): ArrayList<WinmdFileRecord> {
    if (paths.isEmpty()) {
        throw Exception("at least one JSON path is required")
    }
    let files = ArrayList<WinmdFileRecord>()
    for (path in paths) {
        let text = String.fromUtf8(File.readFrom(path))
        files.add(parseWinmdJson(text, path))
    }
    return files
}

public func decodeWinmdFileJson(text: String): WinmdFileRecord {
    return parseWinmdJson(text, "<json>")
}

public func parseWinmdJson(text: String, sourceName: String): WinmdFileRecord {
    let root = JsonValue.fromStr(text).asObject()
    ensureKnownFields(root, sourceName, [
        "winmd_file",
        "winmd_sha256",
        "tool_version",
        "schema_version",
        "source_set",
        "types"
    ])
    return WinmdFileRecord(
        requiredString(root, "winmd_file", sourceName),
        requiredString(root, "winmd_sha256", sourceName),
        requiredString(root, "tool_version", sourceName),
        requiredString(root, "schema_version", sourceName),
        requiredString(root, "source_set", sourceName),
        parseTypeDefinitions(requiredArray(root, "types", sourceName), "${sourceName}.types")
    )
}

func parseTypeDefinitions(array: JsonArray, path: String): ArrayList<TypeDefinitionRecord> {
    let values = ArrayList<TypeDefinitionRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        values.add(parseTypeDefinition(array[i].asObject(), "${path}[${i}]"))
        i += 1
    }
    return values
}

func parseTypeDefinition(obj: JsonObject, path: String): TypeDefinitionRecord {
    ensureKnownFields(obj, path, [
        "Namespace",
        "Name",
        "MetadataToken",
        "BaseType",
        "IsNested",
        "Attributes",
        "CustomAttributes",
        "Fields",
        "InterfaceImplementations",
        "Layout",
        "Methods",
        "NestedTypes",
        "GenericParameters",
        "Events",
        "Properties",
        "SupportedArchitectures",
        "SupportedOsPlatform",
        "IsExperimental",
        "SourceSet"
    ])
    var layout: Option<TypeLayoutRecord> = None
    match (optionalObject(obj, "Layout", path)) {
        case Some(value) => layout = Some(parseTypeLayout(value, "${path}.Layout"))
        case None => ()
    }
    return TypeDefinitionRecord(
        requiredString(obj, "Namespace", path),
        requiredString(obj, "Name", path),
        metadataToken: optionalStringDefault(obj, "MetadataToken", path, ""),
        baseType: optionalStringDefault(obj, "BaseType", path, ""),
        hasBaseType: optionalString(obj, "BaseType", path).isSome(),
        isNested: optionalBoolDefault(obj, "IsNested", path, false),
        attributes: optionalStringList(obj, "Attributes", path),
        customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", path), "${path}.CustomAttributes"),
        fields: parseFields(optionalArrayDefault(obj, "Fields", path), "${path}.Fields"),
        interfaceImplementations: parseInterfaceImplementations(
            optionalArrayDefault(obj, "InterfaceImplementations", path),
            "${path}.InterfaceImplementations"
        ),
        layout: layout,
        methods: parseMethods(optionalArrayDefault(obj, "Methods", path), "${path}.Methods"),
        nestedTypes: parseTypeDefinitions(optionalArrayDefault(obj, "NestedTypes", path), "${path}.NestedTypes"),
        genericParameters: parseGenericParameters(
            optionalArrayDefault(obj, "GenericParameters", path),
            "${path}.GenericParameters"
        ),
        events: parseEvents(optionalArrayDefault(obj, "Events", path), "${path}.Events"),
        properties: parseProperties(optionalArrayDefault(obj, "Properties", path), "${path}.Properties"),
        supportedArchitectures: optionalStringList(obj, "SupportedArchitectures", path),
        supportedOsPlatform: optionalString(obj, "SupportedOsPlatform", path),
        isExperimental: optionalBoolDefault(obj, "IsExperimental", path, false),
        sourceSet: optionalStringDefault(obj, "SourceSet", path, "winmd_main")
    )
}

func parseTypeLayout(obj: JsonObject, path: String): TypeLayoutRecord {
    ensureKnownFields(obj, path, ["IsDefault", "PackingSize", "Size"])
    return TypeLayoutRecord(
        requiredBool(obj, "IsDefault", path),
        requiredInt(obj, "PackingSize", path),
        requiredInt(obj, "Size", path)
    )
}

func parseFields(array: JsonArray, path: String): ArrayList<FieldRecord> {
    let values = ArrayList<FieldRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let fieldPath = "${path}[${i}]"
        ensureKnownFields(obj, fieldPath, [
            "Name",
            "Signature",
            "Attributes",
            "CustomAttributes",
            "DefaultValue",
            "Offset",
            "RelativeVirtualAddress"
        ])
        values.add(FieldRecord(
            requiredString(obj, "Name", fieldPath),
            parseSignature(requiredObject(obj, "Signature", fieldPath), "${fieldPath}.Signature"),
            attributes: optionalStringList(obj, "Attributes", fieldPath),
            customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", fieldPath), "${fieldPath}.CustomAttributes"),
            defaultValue: optionalJsonValue(obj, "DefaultValue"),
            offset: optionalIntDefault(obj, "Offset", fieldPath, 0),
            relativeVirtualAddress: optionalIntDefault(obj, "RelativeVirtualAddress", fieldPath, 0)
        ))
        i += 1
    }
    return values
}

func parseParameters(array: JsonArray, path: String): ArrayList<ParameterRecord> {
    let values = ArrayList<ParameterRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let parameterPath = "${path}[${i}]"
        ensureKnownFields(obj, parameterPath, [
            "Name",
            "SequenceNumber",
            "Attributes",
            "CustomAttributes",
            "DefaultValue",
            "Signature"
        ])
        var signature: Option<SignatureRecord> = None
        match (optionalObject(obj, "Signature", parameterPath)) {
            case Some(sigObj) => signature = Some(parseSignature(sigObj, "${parameterPath}.Signature"))
            case None => ()
        }
        values.add(ParameterRecord(
            requiredString(obj, "Name", parameterPath),
            sequenceNumber: optionalIntDefault(obj, "SequenceNumber", parameterPath, 0),
            attributes: optionalStringList(obj, "Attributes", parameterPath),
            customAttributes: parseCustomAttributes(
                optionalArrayDefault(obj, "CustomAttributes", parameterPath),
                "${parameterPath}.CustomAttributes"
            ),
            defaultValue: optionalJsonValue(obj, "DefaultValue"),
            signature: signature
        ))
        i += 1
    }
    return values
}

func parseMethodSignature(obj: JsonObject, path: String): MethodSignatureRecord {
    ensureKnownFields(obj, path, [
        "ReturnType",
        "Parameters",
        "ParameterTypes",
        "RequiredParameterCount",
        "GenericParameterCount",
        "Header"
    ])
    var parameters = ArrayList<SignatureRecord>()
    match (optionalArray(obj, "Parameters", path)) {
        case Some(items) => parameters = parseSignatures(items, "${path}.Parameters")
        case None =>
            match (optionalArray(obj, "ParameterTypes", path)) {
                case Some(items) => parameters = parseSignatures(items, "${path}.ParameterTypes")
                case None => ()
            }
    }
    return MethodSignatureRecord(
        parseSignature(requiredObject(obj, "ReturnType", path), "${path}.ReturnType"),
        parameters: parameters,
        requiredParameterCount: optionalIntDefault(obj, "RequiredParameterCount", path, 0),
        genericParameterCount: optionalIntDefault(obj, "GenericParameterCount", path, 0),
        header: optionalObjectFieldsDefault(obj, "Header", path)
    )
}

func parseMethods(array: JsonArray, path: String): ArrayList<MethodRecord> {
    let values = ArrayList<MethodRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let methodPath = "${path}[${i}]"
        ensureKnownFields(obj, methodPath, [
            "Name",
            "Signature",
            "Parameters",
            "Attributes",
            "ImplAttributes",
            "CustomAttributes",
            "RelativeVirtualAddress",
            "MethodImport",
            "Import",
            "GenericParameters"
        ])
        var methodImport: Option<MethodImportRecord> = None
        match (optionalObject(obj, "MethodImport", methodPath)) {
            case Some(importObj) => methodImport = Some(parseMethodImport(importObj, "${methodPath}.MethodImport"))
            case None =>
                match (optionalObject(obj, "Import", methodPath)) {
                    case Some(importObj) => methodImport = Some(parseMethodImport(importObj, "${methodPath}.Import"))
                    case None => ()
                }
        }
        values.add(MethodRecord(
            requiredString(obj, "Name", methodPath),
            parseMethodSignature(requiredObject(obj, "Signature", methodPath), "${methodPath}.Signature"),
            parameters: parseParameters(optionalArrayDefault(obj, "Parameters", methodPath), "${methodPath}.Parameters"),
            attributes: optionalStringList(obj, "Attributes", methodPath),
            implAttributes: optionalStringList(obj, "ImplAttributes", methodPath),
            customAttributes: parseCustomAttributes(
                optionalArrayDefault(obj, "CustomAttributes", methodPath),
                "${methodPath}.CustomAttributes"
            ),
            relativeVirtualAddress: optionalIntDefault(obj, "RelativeVirtualAddress", methodPath, 0),
            methodImport: methodImport,
            genericParameters: parseGenericParameters(
                optionalArrayDefault(obj, "GenericParameters", methodPath),
                "${methodPath}.GenericParameters"
            )
        ))
        i += 1
    }
    return values
}

func parseMethodImport(obj: JsonObject, path: String): MethodImportRecord {
    ensureKnownFields(obj, path, [
        "Name",
        "Module",
        "Attributes",
        "CallingConvention",
        "CustomAttributes"
    ])
    var moduleName = ""
    var moduleReference: Option<ModuleReferenceRecord> = None
    let moduleValue = requiredValue(obj, "Module", path)
    match (moduleValue.kind()) {
        case JsonKind.JsString => moduleName = moduleValue.asString().getValue()
        case JsonKind.JsObject =>
            let module = parseModuleReference(moduleValue.asObject(), "${path}.Module")
            moduleName = module.name
            moduleReference = Some(module)
        case _ => throw Exception("${path}.Module must be a string or object")
    }
    let attributes = optionalStringList(obj, "Attributes", path)
    return MethodImportRecord(
        requiredString(obj, "Name", path),
        moduleName,
        moduleReference: moduleReference,
        attributes: attributes,
        customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", path), "${path}.CustomAttributes"),
        callingConvention: optionalStringDefault(obj, "CallingConvention", path, "")
    )
}

func parseModuleReference(obj: JsonObject, path: String): ModuleReferenceRecord {
    ensureKnownFields(obj, path, ["Name", "CustomAttributes"])
    return ModuleReferenceRecord(
        requiredString(obj, "Name", path),
        customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", path), "${path}.CustomAttributes")
    )
}

func parseGenericParameters(array: JsonArray, path: String): ArrayList<GenericParameterRecord> {
    let values = ArrayList<GenericParameterRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let itemPath = "${path}[${i}]"
        ensureKnownFields(obj, itemPath, [
            "Name",
            "SequenceNumber",
            "Index",
            "Attributes",
            "CustomAttributes",
            "Constraints"
        ])
        values.add(GenericParameterRecord(
            requiredString(obj, "Name", itemPath),
            sequenceNumber: optionalIntDefault(obj, "SequenceNumber", itemPath, 0),
            index: optionalInt(obj, "Index", itemPath),
            attributes: optionalStringList(obj, "Attributes", itemPath),
            customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", itemPath), "${itemPath}.CustomAttributes"),
            constraints: optionalJsonArrayValues(obj, "Constraints", itemPath)
        ))
        i += 1
    }
    return values
}

func parseInterfaceImplementations(array: JsonArray, path: String): ArrayList<InterfaceImplementationRecord> {
    let values = ArrayList<InterfaceImplementationRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let implPath = "${path}[${i}]"
        ensureKnownFields(obj, implPath, [
            "Interface",
            "TypeDefinition",
            "TypeReference",
            "TypeSpecification",
            "CustomAttributes"
        ])
        var interfaceSignature: Option<SignatureRecord> = None
        match (optionalObject(obj, "Interface", implPath)) {
            case Some(sigObj) => interfaceSignature = Some(parseSignature(sigObj, "${implPath}.Interface"))
            case None => ()
        }
        var typeDefinition: Option<MetadataTypeRecord> = None
        var typeReference: Option<MetadataTypeRecord> = None
        match (optionalObject(obj, "TypeDefinition", implPath)) {
            case Some(typeObj) =>
                if (typeObj.containsKey("Name") && typeObj.containsKey("Namespace")) {
                    typeDefinition = Some(parseMetadataType(typeObj, "${implPath}.TypeDefinition"))
                }
            case None => ()
        }
        match (optionalObject(obj, "TypeReference", implPath)) {
            case Some(typeObj) =>
                if (typeObj.containsKey("Name") && typeObj.containsKey("Namespace")) {
                    typeReference = Some(parseMetadataType(typeObj, "${implPath}.TypeReference"))
                }
            case None => ()
        }
        var typeSpecification: Option<TypeSpecificationRecord> = None
        match (optionalObject(obj, "TypeSpecification", implPath)) {
            case Some(typeObj) => typeSpecification = Some(parseTypeSpecification(typeObj, "${implPath}.TypeSpecification"))
            case None => ()
        }
        values.add(InterfaceImplementationRecord(
            interfaceSignature: interfaceSignature,
            typeDefinition: typeDefinition,
            typeReference: typeReference,
            typeSpecification: typeSpecification,
            customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", implPath), "${implPath}.CustomAttributes")
        ))
        i += 1
    }
    return values
}

func parseEvents(array: JsonArray, path: String): ArrayList<EventRecord> {
    let values = ArrayList<EventRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let eventPath = "${path}[${i}]"
        ensureKnownFields(obj, eventPath, [
            "Name",
            "Type",
            "Attributes",
            "CustomAttributes",
            "Accessors"
        ])
        values.add(EventRecord(
            requiredString(obj, "Name", eventPath),
            parseSignature(requiredObject(obj, "Type", eventPath), "${eventPath}.Type"),
            attributes: optionalStringList(obj, "Attributes", eventPath),
            customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", eventPath), "${eventPath}.CustomAttributes"),
            accessors: optionalObjectFieldsDefault(obj, "Accessors", eventPath)
        ))
        i += 1
    }
    return values
}

func parseProperties(array: JsonArray, path: String): ArrayList<PropertyRecord> {
    let values = ArrayList<PropertyRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let propertyPath = "${path}[${i}]"
        ensureKnownFields(obj, propertyPath, [
            "Name",
            "Signature",
            "Attributes",
            "CustomAttributes",
            "Accessors",
            "DefaultValue"
        ])
        values.add(PropertyRecord(
            requiredString(obj, "Name", propertyPath),
            parseMethodSignature(requiredObject(obj, "Signature", propertyPath), "${propertyPath}.Signature"),
            attributes: optionalStringList(obj, "Attributes", propertyPath),
            customAttributes: parseCustomAttributes(
                optionalArrayDefault(obj, "CustomAttributes", propertyPath),
                "${propertyPath}.CustomAttributes"
            ),
            accessors: optionalObjectFieldsDefault(obj, "Accessors", propertyPath),
            defaultValue: optionalJsonValue(obj, "DefaultValue")
        ))
        i += 1
    }
    return values
}

func parseCustomAttributes(array: JsonArray, path: String): ArrayList<CustomAttributeRecord> {
    let values = ArrayList<CustomAttributeRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let attrPath = "${path}[${i}]"
        ensureKnownFields(obj, attrPath, ["Type", "FixedArguments", "NamedArguments"])
        values.add(CustomAttributeRecord(
            requiredString(obj, "Type", attrPath),
            fixedArguments: parseCustomAttributeFixedArguments(
                optionalArrayDefault(obj, "FixedArguments", attrPath),
                "${attrPath}.FixedArguments"
            ),
            namedArguments: parseCustomAttributeNamedArguments(
                optionalArrayDefault(obj, "NamedArguments", attrPath),
                "${attrPath}.NamedArguments"
            )
        ))
        i += 1
    }
    return values
}

func parseCustomAttributeFixedArguments(
    array: JsonArray,
    path: String
): ArrayList<CustomAttributeFixedArgumentRecord> {
    let values = ArrayList<CustomAttributeFixedArgumentRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let argPath = "${path}[${i}]"
        ensureKnownFields(obj, argPath, ["Type", "Value"])
        values.add(CustomAttributeFixedArgumentRecord(
            parseSignature(requiredObject(obj, "Type", argPath), "${argPath}.Type"),
            value: optionalJsonValue(obj, "Value")
        ))
        i += 1
    }
    return values
}

func parseCustomAttributeNamedArguments(
    array: JsonArray,
    path: String
): ArrayList<CustomAttributeNamedArgumentRecord> {
    let values = ArrayList<CustomAttributeNamedArgumentRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        let obj = array[i].asObject()
        let argPath = "${path}[${i}]"
        ensureKnownFields(obj, argPath, ["Name", "Type", "Kind", "Value"])
        values.add(CustomAttributeNamedArgumentRecord(
            requiredString(obj, "Name", argPath),
            parseSignature(requiredObject(obj, "Type", argPath), "${argPath}.Type"),
            requiredString(obj, "Kind", argPath),
            value: optionalJsonValue(obj, "Value")
        ))
        i += 1
    }
    return values
}

func parseSignatures(array: JsonArray, path: String): ArrayList<SignatureRecord> {
    let values = ArrayList<SignatureRecord>()
    var i: Int64 = 0
    while (i < array.size()) {
        values.add(parseSignature(array[i].asObject(), "${path}[${i}]"))
        i += 1
    }
    return values
}

func parseSignature(obj: JsonObject, path: String): SignatureRecord {
    ensureKnownFields(obj, path, [
        "Kind",
        "Name",
        "Namespace",
        "Type",
        "TypeArguments",
        "ModifierType",
        "UnmodifiedType",
        "TypeReference",
        "TypeDefinition",
        "TypeSpecification",
        "IsRequired",
        "LowerBounds",
        "Rank",
        "Sizes",
        "Signature",
        "Comment"
    ])
    var typeSig: Option<SignatureRecord> = None
    var modifierType: Option<SignatureRecord> = None
    var unmodifiedType: Option<SignatureRecord> = None
    var typeReference: Option<MetadataTypeRecord> = None
    var typeDefinition: Option<MetadataTypeRecord> = None
    var typeSpecification: Option<TypeSpecificationRecord> = None
    var functionPointerSignature: Option<MethodSignatureRecord> = None
    var name = ""
    var namespace = ""
    var hasNamespace = false
    match (optionalString(obj, "Name", path)) {
        case Some(value) => name = value
        case None => ()
    }
    match (optionalString(obj, "Namespace", path)) {
        case Some(value) =>
            namespace = value
            hasNamespace = true
        case None => ()
    }
    match (optionalObject(obj, "Type", path)) {
        case Some(value) => typeSig = Some(parseSignature(value, "${path}.Type"))
        case None => ()
    }
    match (optionalObject(obj, "ModifierType", path)) {
        case Some(value) => modifierType = Some(parseSignature(value, "${path}.ModifierType"))
        case None => ()
    }
    match (optionalObject(obj, "UnmodifiedType", path)) {
        case Some(value) => unmodifiedType = Some(parseSignature(value, "${path}.UnmodifiedType"))
        case None => ()
    }
    match (optionalObject(obj, "TypeReference", path)) {
        case Some(value) => typeReference = Some(parseMetadataType(value, "${path}.TypeReference"))
        case None => ()
    }
    match (optionalObject(obj, "TypeDefinition", path)) {
        case Some(value) => typeDefinition = Some(parseMetadataType(value, "${path}.TypeDefinition"))
        case None => ()
    }
    match (optionalObject(obj, "TypeSpecification", path)) {
        case Some(value) => typeSpecification = Some(parseTypeSpecification(value, "${path}.TypeSpecification"))
        case None => ()
    }
    match (optionalObject(obj, "Signature", path)) {
        case Some(value) => functionPointerSignature = Some(parseMethodSignature(value, "${path}.Signature"))
        case None => ()
    }
    return SignatureRecord(
        requiredString(obj, "Kind", path),
        name: name,
        namespace: namespace,
        hasNamespace: hasNamespace,
        typeSig: typeSig,
        typeArguments: parseSignatures(optionalArrayDefault(obj, "TypeArguments", path), "${path}.TypeArguments"),
        modifierType: modifierType,
        unmodifiedType: unmodifiedType,
        typeReference: typeReference,
        typeDefinition: typeDefinition,
        typeSpecification: typeSpecification,
        isRequired: optionalBool(obj, "IsRequired", path),
        lowerBounds: optionalIntList(obj, "LowerBounds", path),
        rank: optionalInt(obj, "Rank", path),
        sizes: optionalIntList(obj, "Sizes", path),
        functionPointerSignature: functionPointerSignature,
        comment: optionalString(obj, "Comment", path)
    )
}

func parseTypeSpecification(obj: JsonObject, path: String): TypeSpecificationRecord {
    ensureKnownFields(obj, path, ["Signature", "CustomAttributes"])
    return TypeSpecificationRecord(
        parseSignature(requiredObject(obj, "Signature", path), "${path}.Signature"),
        customAttributes: parseCustomAttributes(optionalArrayDefault(obj, "CustomAttributes", path), "${path}.CustomAttributes")
    )
}

func parseMetadataType(obj: JsonObject, path: String): MetadataTypeRecord {
    ensureKnownFields(obj, path, ["Name", "Namespace"])
    return MetadataTypeRecord(requiredString(obj, "Name", path), requiredString(obj, "Namespace", path))
}

func requiredValue(obj: JsonObject, key: String, path: String): JsonValue {
    match (obj.get(key)) {
        case Some(value) =>
            if (isJsonNull(value)) {
                throw Exception("${path}.${key} is required")
            }
            return value
        case None => throw Exception("${path}.${key} is required")
    }
}

func requiredObject(obj: JsonObject, key: String, path: String): JsonObject {
    return requiredValue(obj, key, path).asObject()
}

func requiredArray(obj: JsonObject, key: String, path: String): JsonArray {
    return requiredValue(obj, key, path).asArray()
}

func requiredString(obj: JsonObject, key: String, path: String): String {
    return requiredValue(obj, key, path).asString().getValue()
}

func requiredBool(obj: JsonObject, key: String, path: String): Bool {
    return requiredValue(obj, key, path).asBool().getValue()
}

func requiredInt(obj: JsonObject, key: String, path: String): Int64 {
    return requiredValue(obj, key, path).asInt().getValue()
}

func optionalJsonValue(obj: JsonObject, key: String): Option<JsonValue> {
    match (obj.get(key)) {
        case Some(value) =>
            if (isJsonNull(value)) {
                return None
            }
            return Some(value)
        case None => return None
    }
}

func optionalString(obj: JsonObject, key: String, path: String): Option<String> {
    match (optionalJsonValue(obj, key)) {
        case Some(value) => return Some(value.asString().getValue())
        case None => return None
    }
}

func optionalStringDefault(obj: JsonObject, key: String, path: String, defaultValue: String): String {
    match (optionalString(obj, key, path)) {
        case Some(value) => return value
        case None => return defaultValue
    }
}

func optionalBool(obj: JsonObject, key: String, path: String): Option<Bool> {
    match (optionalJsonValue(obj, key)) {
        case Some(value) => return Some(value.asBool().getValue())
        case None => return None
    }
}

func optionalBoolDefault(obj: JsonObject, key: String, path: String, defaultValue: Bool): Bool {
    match (optionalBool(obj, key, path)) {
        case Some(value) => return value
        case None => return defaultValue
    }
}

func optionalInt(obj: JsonObject, key: String, path: String): Option<Int64> {
    match (optionalJsonValue(obj, key)) {
        case Some(value) => return Some(value.asInt().getValue())
        case None => return None
    }
}

func optionalIntDefault(obj: JsonObject, key: String, path: String, defaultValue: Int64): Int64 {
    match (optionalInt(obj, key, path)) {
        case Some(value) => return value
        case None => return defaultValue
    }
}

func optionalObject(obj: JsonObject, key: String, path: String): Option<JsonObject> {
    match (optionalJsonValue(obj, key)) {
        case Some(value) => return Some(value.asObject())
        case None => return None
    }
}

func optionalArray(obj: JsonObject, key: String, path: String): Option<JsonArray> {
    match (optionalJsonValue(obj, key)) {
        case Some(value) => return Some(value.asArray())
        case None => return None
    }
}

func optionalArrayDefault(obj: JsonObject, key: String, path: String): JsonArray {
    match (optionalArray(obj, key, path)) {
        case Some(value) => return value
        case None => return JsonArray()
    }
}

func optionalObjectFieldsDefault(obj: JsonObject, key: String, path: String): HashMap<String, JsonValue> {
    match (optionalObject(obj, key, path)) {
        case Some(value) => return value.getFields()
        case None => return HashMap<String, JsonValue>()
    }
}

func optionalStringList(obj: JsonObject, key: String, path: String): ArrayList<String> {
    let values = ArrayList<String>()
    match (optionalArray(obj, key, path)) {
        case Some(array) =>
            var i: Int64 = 0
            while (i < array.size()) {
                values.add(array[i].asString().getValue())
                i += 1
            }
        case None => ()
    }
    return values
}

func optionalIntList(obj: JsonObject, key: String, path: String): Option<ArrayList<Int64>> {
    match (optionalArray(obj, key, path)) {
        case Some(array) =>
            let values = ArrayList<Int64>()
            var i: Int64 = 0
            while (i < array.size()) {
                values.add(array[i].asInt().getValue())
                i += 1
            }
            return Some(values)
        case None => return None
    }
}

func optionalJsonArrayValues(obj: JsonObject, key: String, path: String): ArrayList<JsonValue> {
    let values = ArrayList<JsonValue>()
    match (optionalArray(obj, key, path)) {
        case Some(array) =>
            var i: Int64 = 0
            while (i < array.size()) {
                values.add(array[i])
                i += 1
            }
        case None => ()
    }
    return values
}

func isJsonNull(value: JsonValue): Bool {
    match (value.kind()) {
        case JsonKind.JsNull => return true
        case _ => return false
    }
}

func ensureKnownFields(obj: JsonObject, path: String, allowed: Array<String>): Unit {
    for ((key, _) in obj.getFields()) {
        if (!containsArray(allowed, key)) {
            throw Exception("${path} contains unsupported field: ${key}")
        }
    }
}

func containsArray(values: Array<String>, value: String): Bool {
    for (item in values) {
        if (item == value) {
            return true
        }
    }
    return false
}
