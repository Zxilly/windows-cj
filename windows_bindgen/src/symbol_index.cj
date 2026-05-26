package windows_bindgen

import std.collection.*

let CANGJIE_RESERVED_IDENTIFIERS: Array<String> = [
    "Bool", "Float16", "Float32", "Float64", "Int16", "Int32", "Int64", "Int8",
    "Rune", "String", "UInt16", "UInt32", "UInt64", "UInt8", "Unit",
    "abstract", "as", "break", "case", "catch", "class", "const", "continue",
    "do", "else", "enum", "extend", "false", "finally", "foreign", "for",
    "func", "if", "import", "in", "init", "interface", "is", "let", "macro",
    "main", "match", "mut", "open", "operator", "override", "package",
    "private", "protected", "public", "redef", "return", "sealed", "spawn",
    "static", "struct", "super", "synchronized", "this", "throw", "true",
    "try", "type", "unsafe", "var", "where", "while"
]

public func buildSymbolRecords(winmdFiles: ArrayList<WinmdFileRecord>): ArrayList<SymbolRecord> {
    let symbols = ArrayList<SymbolRecord>()
    let symbolsByName = HashMap<String, SymbolRecord>()
    let implNames = HashMap<String, String>()
    for (winmdFile in winmdFiles) {
        let nestedTokens = HashSet<String>()
        collectNestedMetadataTokens(winmdFile.types, nestedTokens)
        for (typeDef in winmdFile.types) {
            addTypeSymbol(
                typeDef,
                nestedTokens,
                "",
                "",
                "",
                false,
                symbols,
                symbolsByName,
                implNames
            )
        }
    }
    sortSymbolsByFullName(symbols)
    for (symbol in symbols) {
        sortStrings(symbol.dependencies)
    }
    return symbols
}

public func featureNamesFromRecords(records: ArrayList<SymbolRecord>): Array<String> {
    let features = ArrayList<String>()
    for (record in records) {
        if (!record.namespace.isEmpty()) {
            addUnique(features, record.namespace)
        }
    }
    sortStrings(features)
    let result = Array<String>(features.size, repeat: "")
    var i: Int64 = 0
    while (i < Int64(features.size)) {
        result[i] = features[i]
        i += 1
    }
    return result
}

func collectNestedMetadataTokens(types: ArrayList<TypeDefinitionRecord>, tokens: HashSet<String>): Unit {
    for (typeDef in types) {
        for (nested in typeDef.nestedTypes) {
            if (!nested.metadataToken.isEmpty()) {
                tokens.add(nested.metadataToken)
            }
        }
        collectNestedMetadataTokens(typeDef.nestedTypes, tokens)
    }
}

func addTypeSymbol(
    typeDef: TypeDefinitionRecord,
    nestedTokens: HashSet<String>,
    parentFullName: String,
    parentNamespace: String,
    parentName: String,
    hasParent: Bool,
    symbols: ArrayList<SymbolRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    implNames: HashMap<String, String>
): Unit {
    if (!hasParent && typeDef.isNested) {
        return
    }
    if (!hasParent && !typeDef.metadataToken.isEmpty() && nestedTokens.contains(typeDef.metadataToken)) {
        return
    }

    var fullName = typeDef.fullName()
    var namespace = typeDef.namespace
    var name = facadeShortName(typeDef.name)
    if (hasParent) {
        fullName = "${parentFullName}.${typeDef.name}"
        namespace = parentNamespace
        let nestedName = facadeShortName(typeDef.name)
        if (parentName.isEmpty()) {
            name = nestedName
        } else {
            name = "${parentName}_${nestedName}"
        }
    }

    if (typeDef.namespace == "" && typeDef.name == "<Module>") {
        return
    }

    let implName = mangleFullName(fullName)
    match (implNames.get(implName)) {
        case Some(previous) =>
            if (previous != fullName) {
                throw Exception("impl name collision for ${implName}: ${previous} and ${fullName}")
            }
        case None => implNames.add(implName, fullName)
    }

    let dependencies = typeDependencies(typeDef, fullName)
    match (symbolsByName.get(fullName)) {
        case Some(previous) =>
            for (dependency in dependencies) {
                addUnique(previous.dependencies, dependency)
            }
        case None =>
            let symbol = SymbolRecord(
                fullName,
                namespace,
                name,
                implName,
                dependencies,
                metadataToken: symbolMetadataToken(typeDef, fullName),
                typeDef: Some(typeDef)
            )
            symbols.add(symbol)
            symbolsByName.add(fullName, symbol)
    }

    for (nested in typeDef.nestedTypes) {
        addTypeSymbol(
            nested,
            nestedTokens,
            fullName,
            namespace,
            name,
            true,
            symbols,
            symbolsByName,
            implNames
        )
    }
}

func symbolMetadataToken(typeDef: TypeDefinitionRecord, fullName: String): String {
    if (!typeDef.metadataToken.isEmpty()) {
        return typeDef.metadataToken
    }
    return "synthetic:${mangleFullName(fullName)}"
}

func typeDependencies(typeDef: TypeDefinitionRecord, selfFullName: String): ArrayList<String> {
    let dependencies = ArrayList<String>()
    if (typeDef.hasBaseType) {
        addUnique(dependencies, typeDef.baseType)
    }
    addCustomAttributeTypeDependencies(dependencies, selfFullName, typeDef.customAttributes)
    for (field in typeDef.fields) {
        addSignatureDependencies(dependencies, field.signature, selfFullName)
        addCustomAttributeTypeDependencies(dependencies, selfFullName, field.customAttributes)
    }
    for (method in typeDef.methods) {
        addMethodSignatureDependencies(dependencies, method.signature, selfFullName)
        addCustomAttributeTypeDependencies(dependencies, selfFullName, method.customAttributes)
        for (parameter in method.parameters) {
            match (parameter.signature) {
                case Some(signature) => addSignatureDependencies(dependencies, signature, selfFullName)
                case None => ()
            }
            addCustomAttributeTypeDependencies(dependencies, selfFullName, parameter.customAttributes)
        }
    }
    for (property in typeDef.properties) {
        addMethodSignatureDependencies(dependencies, property.signature, selfFullName)
        addCustomAttributeTypeDependencies(dependencies, selfFullName, property.customAttributes)
    }
    for (event in typeDef.events) {
        addSignatureDependencies(dependencies, event.typeSig, selfFullName)
        addCustomAttributeTypeDependencies(dependencies, selfFullName, event.customAttributes)
    }
    for (impl in typeDef.interfaceImplementations) {
        match (impl.interfaceSignature) {
            case Some(signature) => addSignatureDependencies(dependencies, signature, selfFullName)
            case None => ()
        }
        match (impl.typeDefinition) {
            case Some(metadataType) => addMetadataTypeDependency(dependencies, metadataType, selfFullName)
            case None => ()
        }
        match (impl.typeReference) {
            case Some(metadataType) => addMetadataTypeDependency(dependencies, metadataType, selfFullName)
            case None => ()
        }
        match (impl.typeSpecification) {
            case Some(typeSpecification) => addSignatureDependencies(dependencies, typeSpecification.signature, selfFullName)
            case None => ()
        }
        addCustomAttributeTypeDependencies(dependencies, selfFullName, impl.customAttributes)
    }
    let filtered = ArrayList<String>()
    for (dependency in dependencies) {
        if (dependency != typeDef.fullName() && dependency != selfFullName) {
            addUnique(filtered, dependency)
        }
    }
    sortStrings(filtered)
    return filtered
}

func addCustomAttributeTypeDependencies(
    dependencies: ArrayList<String>,
    ownerFullName: String,
    attributes: ArrayList<CustomAttributeRecord>
): Unit {
    for (attribute in attributes) {
        for (fullName in customAttributeTypeNameArgumentFullNames(attribute)) {
            addCustomAttributeTypeDependency(dependencies, ownerFullName, fullName)
        }
        addAssociatedEnumStringAttributeDependency(dependencies, ownerFullName, attribute)
    }
}

func addAssociatedEnumStringAttributeDependency(
    dependencies: ArrayList<String>,
    ownerFullName: String,
    attribute: CustomAttributeRecord
): Unit {
    if (!hasAttributeName(attribute, "AssociatedEnumAttribute")) {
        return
    }
    for (argument in attribute.fixedArguments) {
        if (isStringSignature(argument.typeSig)) {
            match (fixedArgumentString(argument)) {
                case Some(fullName) => addCustomAttributeTypeDependency(dependencies, ownerFullName, fullName)
                case None => ()
            }
        }
    }
}

func isStringSignature(signature: SignatureRecord): Bool {
    if (signature.kind == "Primitive" && signature.name == "String") {
        return true
    }
    return signature.kind == "Type" && signature.namespace == "System" && signature.name == "String"
}

func addMethodSignatureDependencies(
    dependencies: ArrayList<String>,
    signature: MethodSignatureRecord,
    ownerFullName: String
): Unit {
    addSignatureDependencies(dependencies, signature.returnType, ownerFullName)
    for (parameter in signature.parameters) {
        addSignatureDependencies(dependencies, parameter, ownerFullName)
    }
}

func addSignatureDependencies(
    dependencies: ArrayList<String>,
    signature: SignatureRecord,
    ownerFullName: String
): Unit {
    if (signature.kind == "Type" && !signature.name.isEmpty()) {
        if (signature.hasNamespace && !signature.namespace.isEmpty()) {
            addUnique(dependencies, remapKnownTypeFullName("${signature.namespace}.${signature.name}"))
        } else {
            addRelativeDependencyCandidates(dependencies, ownerFullName, signature.name)
        }
    }
    match (signature.typeReference) {
        case Some(metadataType) => addMetadataTypeDependency(dependencies, metadataType, ownerFullName)
        case None => ()
    }
    match (signature.typeDefinition) {
        case Some(metadataType) => addMetadataTypeDependency(dependencies, metadataType, ownerFullName)
        case None => ()
    }
    match (signature.typeSpecification) {
        case Some(typeSpecification) => addSignatureDependencies(dependencies, typeSpecification.signature, ownerFullName)
        case None => ()
    }
    match (signature.typeSig) {
        case Some(nested) => addSignatureDependencies(dependencies, nested, ownerFullName)
        case None => ()
    }
    match (signature.modifierType) {
        case Some(nested) => addSignatureDependencies(dependencies, nested, ownerFullName)
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) => addSignatureDependencies(dependencies, nested, ownerFullName)
        case None => ()
    }
    for (argument in signature.typeArguments) {
        addSignatureDependencies(dependencies, argument, ownerFullName)
    }
}

func addCustomAttributeTypeDependency(
    dependencies: ArrayList<String>,
    ownerFullName: String,
    fullName: String
): Unit {
    if (containsByte(fullName, b'.')) {
        addUnique(dependencies, remapKnownTypeFullName(fullName))
    } else {
        addRelativeDependencyCandidates(dependencies, ownerFullName, fullName)
    }
}

func addMetadataTypeDependency(
    dependencies: ArrayList<String>,
    metadataType: MetadataTypeRecord,
    ownerFullName: String
): Unit {
    if (metadataType.namespace.isEmpty()) {
        addRelativeDependencyCandidates(dependencies, ownerFullName, metadataType.name)
    } else {
        addUnique(dependencies, remapKnownTypeFullName(metadataType.fullName()))
    }
}

func addRelativeDependencyCandidates(dependencies: ArrayList<String>, ownerFullName: String, name: String): Unit {
    var current = ownerFullName
    while (!current.isEmpty()) {
        addUnique(dependencies, remapKnownTypeFullName("${current}.${name}"))
        current = parentFullNameForDependencies(current)
    }
    addUnique(dependencies, remapKnownTypeFullName(name))
}

func parentFullNameForDependencies(fullName: String): String {
    let bytes = fullName.toArray()
    var i = Int64(bytes.size) - 1
    while (i >= 0) {
        if (bytes[i] == b'.') {
            return String.fromUtf8(bytes[0..i])
        }
        i -= 1
    }
    return ""
}

func sortSymbolsByFullName(values: ArrayList<SymbolRecord>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let value = values[i]
        var j = i - 1
        while (j >= 0 && values[j].fullName > value.fullName) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = value
        i += 1
    }
}

public func mangleFullName(fullName: String): String {
    let bytes = fullName.toArray()
    var result = ""
    for (byte in bytes) {
        if (isAsciiAlphaNumeric(byte)) {
            result += String.fromUtf8([byte])
        } else {
            result += "_"
        }
    }
    if (result.isEmpty() || isAsciiDigit(result.toArray()[0])) {
        result = "_${result}"
    }
    return result
}

public func facadeShortName(name: String): String {
    let stripped = stripGenericArity(name)
    let bytes = stripped.toArray()
    var result = ""
    for (byte in bytes) {
        if (isAsciiAlphaNumeric(byte) || byte == b'_') {
            result += String.fromUtf8([byte])
        } else {
            result += "_"
        }
    }
    if (result.isEmpty() || isAsciiDigit(result.toArray()[0])) {
        result = "_${result}"
    }
    if (containsArray(CANGJIE_RESERVED_IDENTIFIERS, result)) {
        result += "_"
    }
    return result
}

func stripGenericArity(name: String): String {
    let bytes = name.toArray()
    var i = Int64(bytes.size) - 1
    if (i < 0 || !isAsciiDigit(bytes[i])) {
        return name
    }
    while (i >= 0 && isAsciiDigit(bytes[i])) {
        i -= 1
    }
    if (i >= 0 && bytes[i] == b'`') {
        return String.fromUtf8(bytes[0..i])
    }
    return name
}

func isAsciiAlphaNumeric(byte: Byte): Bool {
    return isAsciiDigit(byte) ||
        (byte >= b'A' && byte <= b'Z') ||
        (byte >= b'a' && byte <= b'z')
}

func isAsciiDigit(byte: Byte): Bool {
    return byte >= b'0' && byte <= b'9'
}
