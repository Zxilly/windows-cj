package windows_bindgen

import std.collection.*

let CANGJIE_RESERVED_IDENTIFIERS: Array<String> = [
    "Bool", "Float16", "Float32", "Float64", "Int16", "Int32", "Int64", "Int8",
    "Rune", "String", "UInt16", "UInt32", "UInt64", "UInt8", "Unit",
    "abstract", "as", "break", "case", "catch", "class", "const", "continue",
    "do", "else", "enum", "extend", "false", "finally", "foreign", "for",
    "func", "if", "import", "in", "init", "interface", "is", "let", "macro",
    "main", "match", "mut", "open", "operator", "override", "package",
    "private", "prop", "protected", "public", "redef", "return", "sealed", "spawn",
    "static", "struct", "super", "synchronized", "this", "throw", "true",
    "try", "type", "unsafe", "var", "where", "while", "This"
]

// Minimal closure-truncation mode (`--minimal`).
//
// When enabled, a COM/WinRT INTERFACE contributes only its structural
// dependencies to the selection closure -- its base interface, the types named by
// its custom attributes (IID etc.), and the interfaces it implements -- and NOT
// the high-level projected types named in its method/property/event signatures
// (e.g. FlyoutBase). This is sound because an interface's vtable is rendered with
// raw ABI types (CPointer<Unit>, scalars) and never references those high-level
// types unless they happen to be selected by another path: interfaceSlotAbiType
// projects an unselected non-System type to CPointer<Unit>, and the runtime-class
// projection of an interface method projects an unselected type to
// windows_interface.IInspectable -- both ABI-equivalent object handles. So the
// interface vtable stays full-slot/correct-order (ABI preserved) while the
// dependency closure stops cascading through every method signature.
//
// Value types (struct/enum/delegate) are unaffected -- their full signature
// recursion is required so their byte layout is complete. Left disabled (the
// default) the closure is the full transitive graph, so every existing test and
// non-minimal generation mode is unchanged.
var minimalInterfaceTruncation: Bool = false

public func setMinimalInterfaceTruncation(enabled: Bool): Unit {
    minimalInterfaceTruncation = enabled
}

public func clearMinimalInterfaceTruncation(): Unit {
    minimalInterfaceTruncation = false
}

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
    // In --minimal mode an interface contributes no member-signature dependencies:
    // its vtable is raw ABI, so the high-level method/property/event signature
    // types are not needed to render it, and skipping them is what truncates the
    // selection closure at every interface boundary. The base interface, IID/custom-
    // attribute types, and implemented interfaces below are still collected, so the
    // interface's structural identity is preserved.
    //
    // A WinRT runtime CLASS is treated the same way for its member signatures: it
    // projects its default interface's high-level members (e.g.
    // DependencyObject.Dispatcher: CoreDispatcher) and the class metadata duplicates
    // those member signatures onto the class, so without truncation the class drags
    // every projected member's high-level type into the closure. Those projected
    // members reference other runtime classes / interfaces (object handles), which
    // the renderer degrades to windows_interface.IInspectable when unselected -- an
    // ABI-equivalent object handle -- so dropping them from the closure is sound.
    // The class still pulls its base class and every implemented interface (kept
    // below), which the ancestor-IID / QueryInterface routing requires, and keeps
    // all its custom attributes (the Composable/Activatable factory interfaces a
    // `new()` needs live there). Member signature types a SEEDED method actually
    // uses are re-added by the seeded-dependency path in filterRecordMembers.
    // Only WinRT interfaces are truncated. A native (non-WindowsRuntime) COM
    // interface renders its vtable CFunc parameters with the REAL projected types
    // of the interface it points at (e.g. ISwapChainPanelNative.SetSwapChain takes
    // IDXGISwapChain), so dropping those signature dependencies would leave the
    // vtable referencing an undeclared type. Such interfaces keep full closures.
    //
    // A value type is never truncated even if it also carries Class/WindowsRuntime
    // attributes: some WinRT structs (e.g. Windows.UI.Xaml.Interop.TypeName) are
    // marked Class+WindowsRuntime yet render as a @C value struct, and a @C struct
    // field must name its real CType (its enum/struct field types), not a degraded
    // object handle. renderSymbolImplWithGate dispatches value types before the
    // runtime-class path, so the truncation classification mirrors that precedence.
    let truncateInterface = minimalInterfaceTruncation && isWinrtInterfaceType(typeDef) && !isValueType(typeDef)
    let truncateClassMembers = minimalInterfaceTruncation && isWinrtClassType(typeDef) && !isValueType(typeDef)
    let truncateMembers = truncateInterface || truncateClassMembers
    // An interface's type-level custom attributes include ExclusiveToAttribute,
    // whose type argument is the runtime CLASS the interface is exclusive to (e.g.
    // IButton -> Button). Following that back-edge would drag the entire class --
    // its base-class chain and every interface it implements -- into the closure,
    // which is the dominant source of the closure explosion. The interface's vtable
    // never references its exclusive class, so in minimal mode that one attribute's
    // dependency is dropped while every other attribute (notably the GUID/IID) is
    // still collected. A runtime class keeps ALL its attributes (factory back-edges
    // are needed), so only the interface path skips ExclusiveTo.
    if (truncateInterface) {
        addInterfaceTypeAttributeDependencies(dependencies, selfFullName, typeDef.customAttributes)
    } else {
        addCustomAttributeTypeDependencies(dependencies, selfFullName, typeDef.customAttributes)
    }
    if (!truncateMembers) {
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

// Minimal-mode variant for an INTERFACE's type-level custom attributes: identical
// to addCustomAttributeTypeDependencies except it drops ExclusiveToAttribute's
// type-argument dependency (the runtime class the interface is exclusive to). That
// back-edge is what otherwise pulls the whole exclusive class -- and transitively
// its base chain and every interface it implements -- into the selection closure.
// All other attributes (GUID/IID, AssociatedEnum string targets, etc.) are kept.
func addInterfaceTypeAttributeDependencies(
    dependencies: ArrayList<String>,
    ownerFullName: String,
    attributes: ArrayList<CustomAttributeRecord>
): Unit {
    for (attribute in attributes) {
        if (!hasAttributeName(attribute, "ExclusiveToAttribute")) {
            for (fullName in customAttributeTypeNameArgumentFullNames(attribute)) {
                addCustomAttributeTypeDependency(dependencies, ownerFullName, fullName)
            }
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
