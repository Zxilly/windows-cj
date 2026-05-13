package windows

import std.collection.*
import stdx.encoding.json.*

class ParameterPair {
    public let name: String
    public let typeName: String

    public init(name: String, typeName: String) {
        this.name = name
        this.typeName = typeName
    }
}

class RuntimeBorrowSpec {
    public let name: String
    public let typeName: String
    public let sourceName: String

    public init(name: String, typeName: String, sourceName: String) {
        this.name = name
        this.typeName = typeName
        this.sourceName = sourceName
    }
}

class RuntimeCallPlan {
    public let borrows: ArrayList<RuntimeBorrowSpec>
    public let args: ArrayList<String>

    public init(borrows: ArrayList<RuntimeBorrowSpec>, args: ArrayList<String>) {
        this.borrows = borrows
        this.args = args
    }
}

class RawStorageSpec {
    public let typeName: String
    public let count: Int64
    public let repeatValue: String

    public init(typeName: String, count: Int64, repeatValue: String) {
        this.typeName = typeName
        this.count = count
        this.repeatValue = repeatValue
    }
}

class NativeBitfieldSpec {
    public let name: String
    public let bitOffset: Int64
    public let bitWidth: Int64

    public init(name: String, bitOffset: Int64, bitWidth: Int64) {
        this.name = name
        this.bitOffset = bitOffset
        this.bitWidth = bitWidth
    }
}

class RuntimeClassInterfaceSpec {
    public let symbol: SymbolRecord
    public let typeName: String
    public let fullName: String
    public let accessorName: String

    public init(symbol: SymbolRecord, typeName: String) {
        this.symbol = symbol
        this.typeName = typeName
        this.fullName = symbol.fullName
        this.accessorName = cjIdentifier(symbol.name)
    }
}

public func renderSymbolImpl(symbol: SymbolRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    if (!symbol.implSource.isEmpty()) {
        return symbol.implSource
    }
    match (symbol.typeDef) {
        case Some(typeDef) =>
            let header = "// ${symbol.fullName} (${symbol.metadataToken})"
            match (win32TextPointerRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            match (eventRegistrationTokenRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            match (hresultRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            match (win32ScalarRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\n${renderRawAliasSymbol(symbol, typeDef, typeName)}"
                case None => ()
            }
            match (stringHandleRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            if (isEnumType(typeDef)) {
                return "${header}\n${renderEnumSymbol(symbol, typeDef, symbolsByName)}"
            }
            if (isDelegateType(typeDef)) {
                return "${header}\n${renderDelegateSymbol(symbol, typeDef, symbolsByName)}"
            }
            if (isValueType(typeDef)) {
                return "${header}\n${renderValueStructSymbol(symbol, typeDef, symbolsByName)}"
            }
            if (hasPInvokeMethods(typeDef)) {
                return "${header}\n${renderPInvokeSymbol(symbol, typeDef, symbolsByName)}"
            }
            if (isInterfaceType(typeDef)) {
                match (guidAttributeString(typeDef)) {
                    case Some(guidValue) =>
                        return "${header}\n${renderInterfaceSymbol(symbol, typeDef, symbolsByName, guidValue)}"
                    case None => ()
                }
                return "${header}\n${renderRawHandleSymbol(symbol, "interface")}"
            }
            if (isWinrtClassType(typeDef)) {
                match (renderWinrtRuntimeClassSymbol(symbol, typeDef, symbolsByName)) {
                    case Some(source) => return "${header}\n${source}"
                    case None => ()
                }
            }
            return "${header}\n${renderRawHandleSymbol(symbol, "class")}"
        case None =>
            return "// ${symbol.fullName}\n" +
                "public struct ${symbol.implName} {\n" +
                "    public init() {}\n" +
                "}"
    }
}

func isEnumType(typeDef: TypeDefinitionRecord): Bool {
    return typeDef.hasBaseType && typeDef.baseType == "System.Enum"
}

func isValueType(typeDef: TypeDefinitionRecord): Bool {
    if (typeDef.hasBaseType && typeDef.baseType == "System.ValueType") {
        return true
    }
    return contains(typeDef.attributes, "SequentialLayout") || contains(typeDef.attributes, "ExplicitLayout")
}

func isInterfaceType(typeDef: TypeDefinitionRecord): Bool {
    return contains(typeDef.attributes, "Interface")
}

func isDelegateType(typeDef: TypeDefinitionRecord): Bool {
    return typeDef.hasBaseType && typeDef.baseType == "System.MulticastDelegate"
}

func isWinrtClassType(typeDef: TypeDefinitionRecord): Bool {
    contains(typeDef.attributes, "Class") && contains(typeDef.attributes, "WindowsRuntime")
}

func isWinrtDelegateType(typeDef: TypeDefinitionRecord): Bool {
    return isDelegateType(typeDef) && contains(typeDef.attributes, "WindowsRuntime")
}

func hasPInvokeMethods(typeDef: TypeDefinitionRecord): Bool {
    for (method in typeDef.methods) {
        match (method.methodImport) {
            case Some(_) => return true
            case None => ()
        }
    }
    return false
}

func renderDelegateSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    if (isWinrtDelegateType(typeDef)) {
        return renderRawHandleSymbol(symbol, "delegate")
    }
    match (delegateCFuncType(typeDef, symbolsByName)) {
        case Some(typeName) => return "public type ${symbol.implName} = ${typeName}"
        case None => return renderRawHandleSymbol(symbol, "delegate")
    }
}

func renderValueStructSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    if (!hasPublicInstanceFields(typeDef) && hasLiteralFields(typeDef)) {
        return renderStaticLiteralStructSymbol(symbol, typeDef, symbolsByName)
    }
    if (contains(typeDef.attributes, "ExplicitLayout")) {
        return renderExplicitLayoutStructSymbol(symbol, typeDef, symbolsByName)
    }
    var content = "@C\npublic struct ${symbol.implName} {\n"
    var count: Int64 = 0
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldName = cjIdentifier(field.name)
            let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, symbol.fullName)
            content += "    public var ${fieldName}: ${fieldType} = ${cjDefaultValue(fieldType)}\n"
            content += renderBitfieldProperties(fieldName, fieldType, field)
            count += 1
        }
    }
    if (count == 0) {
        content += "    public var reserved: Int32 = 0\n"
    }
    content += renderLiteralFieldConstants(typeDef, symbolsByName, true)
    content += "}"
    return content
}

func renderStaticLiteralStructSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = "public struct ${symbol.implName} {\n"
    content += renderLiteralFieldConstants(typeDef, symbolsByName, false)
    content += "}"
    return content
}

func renderBitfieldProperties(fieldName: String, fieldType: String, field: FieldRecord): String {
    let specs = nativeBitfieldSpecs(field)
    if (specs.isEmpty()) {
        return ""
    }
    match (bitfieldReadHelper(fieldType)) {
        case Some(readHelper) =>
            let writeHelper = bitfieldWriteHelper(fieldType).getOrThrow()
            var content = ""
            for (spec in specs) {
                let propName = cjIdentifier(spec.name)
                if (!propName.isEmpty()) {
                    content += "\n"
                    content += "    public mut prop ${propName}: ${fieldType} {\n"
                    content += "        get() {\n"
                    content += "            return windows_polyfill.${readHelper}(${fieldName}, ${spec.bitOffset}, ${spec.bitWidth})\n"
                    content += "        }\n"
                    content += "        set(val) {\n"
                    content += "            ${fieldName} = windows_polyfill.${writeHelper}(${fieldName}, ${spec.bitOffset}, ${spec.bitWidth}, val)\n"
                    content += "        }\n"
                    content += "    }\n"
                }
            }
            return content
        case None => return ""
    }
}

func nativeBitfieldSpecs(field: FieldRecord): ArrayList<NativeBitfieldSpec> {
    let specs = ArrayList<NativeBitfieldSpec>()
    for (attr in field.customAttributes) {
        if (attr.typeName == "Windows.Win32.Foundation.Metadata.NativeBitfieldAttribute" &&
            attr.fixedArguments.size >= 3) {
            match (fixedArgumentString(attr.fixedArguments[0])) {
                case Some(name) =>
                    match (fixedArgumentInt64(attr.fixedArguments[1])) {
                        case Some(bitOffset) =>
                            match (fixedArgumentInt64(attr.fixedArguments[2])) {
                                case Some(bitWidth) => specs.add(NativeBitfieldSpec(name, bitOffset, bitWidth))
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }
    return specs
}

func fixedArgumentString(argument: CustomAttributeFixedArgumentRecord): Option<String> {
    match (argument.value) {
        case Some(value) =>
            match (value.kind()) {
                case JsonKind.JsString => return Some(value.asString().getValue())
                case _ => ()
            }
        case None => ()
    }
    return None
}

func fixedArgumentInt64(argument: CustomAttributeFixedArgumentRecord): Option<Int64> {
    match (argument.value) {
        case Some(value) =>
            match (value.kind()) {
                case JsonKind.JsInt => return Some(value.asInt().getValue())
                case _ => ()
            }
        case None => ()
    }
    return None
}

func renderExplicitLayoutStructSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let storage = rawStorageSpec(symbol.fullName, typeDef, symbolsByName)
    var content = "@C\npublic struct ${symbol.implName} {\n"
    content += "    public var _raw: VArray<${storage.typeName}, \$${storage.count}> = " +
        "VArray<${storage.typeName}, \$${storage.count}>(repeat: ${storage.repeatValue})\n"
    var count: Int64 = 0
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            content += "\n"
            content += renderExplicitLayoutProperty(symbol.fullName, field, symbolsByName)
            count += 1
        }
    }
    if (count == 0) {
        content += "\n    public mut prop reserved: UInt8 {\n" +
            "        get() { return 0 }\n" +
            "        set(_) { }\n" +
            "    }\n"
    }
    content += renderLiteralFieldConstants(typeDef, symbolsByName, true)
    content += "}"
    return content
}

func renderLiteralFieldConstants(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    insideCStruct: Bool
): String {
    var content = ""
    for (field in typeDef.fields) {
        if (isLiteralField(field)) {
            match (literalValue(field.defaultValue)) {
                case Some(value) =>
                    let fieldName = cjIdentifier(field.name)
                    let fieldType = cjConstantType(field.signature, symbolsByName)
                    if (literalFieldRequiresFunction(insideCStruct, fieldType)) {
                        content += "    public static func ${fieldName}(): ${fieldType} {\n"
                        content += "        return ${cjLiteral(value, fieldType)}\n"
                        content += "    }\n"
                    } else if (literalFieldRequiresRuntimeStorage(fieldType)) {
                        content += "    public static let ${fieldName}: ${fieldType} = ${cjLiteral(value, fieldType)}\n"
                    } else {
                        content += "    public static const ${fieldName}: ${fieldType} = ${cjLiteral(value, fieldType)}\n"
                    }
                case None => ()
            }
        }
    }
    return content
}

func literalFieldRequiresFunction(insideCStruct: Bool, fieldType: String): Bool {
    insideCStruct && (fieldType == "String" || literalFieldRequiresRuntimeStorage(fieldType))
}

func literalFieldRequiresRuntimeStorage(fieldType: String): Bool {
    fieldType == "windows_strings.WideStringFactory" ||
    fieldType == "windows_strings.NarrowStringFactory"
}

func renderExplicitLayoutProperty(
    ownerFullName: String,
    field: FieldRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let fieldName = cjIdentifier(field.name)
    let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName)
    var content = "    public mut prop ${fieldName}: ${fieldType} {\n"
    content += "        get() {\n"
    content += "            unsafe {\n"
    content += "                var rawStorage = _raw\n"
    content += "                let base = CPointer<UInt8>(inout rawStorage)\n"
    match (unionReadHelper(fieldType)) {
        case Some(helper) =>
            content += "                return windows_polyfill.${helper}(base, ${field.offset})\n"
        case None =>
            content += renderPointerViewRead(fieldType, field.offset)
    }
    content += "            }\n"
    content += "        }\n"
    content += "        set(val) {\n"
    content += "            unsafe {\n"
    content += "                var rawStorage = _raw\n"
    content += "                let base = CPointer<UInt8>(inout rawStorage)\n"
    match (unionWriteHelper(fieldType)) {
        case Some(helper) =>
            content += "                windows_polyfill.${helper}(base, ${field.offset}, val)\n"
        case None =>
            content += renderPointerViewWrite(fieldType, field.offset)
    }
    content += "                _raw = rawStorage\n"
    content += "            }\n"
    content += "        }\n"
    content += "    }\n"
    return content
}

func renderPointerViewRead(fieldType: String, offset: Int64): String {
    var content = ""
    if (offset == 0) {
        content += "                let p = base\n"
    } else {
        content += "                let p = base + ${offset}\n"
    }
    content += "                let ptr = CPointer<${fieldType}>(p)\n"
    content += "                return ptr.read()\n"
    return content
}

func renderPointerViewWrite(fieldType: String, offset: Int64): String {
    var content = ""
    if (offset == 0) {
        content += "                let p = base\n"
    } else {
        content += "                let p = base + ${offset}\n"
    }
    content += "                let ptr = CPointer<${fieldType}>(p)\n"
    content += "                ptr.write(val)\n"
    return content
}

func rawStorageSpec(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): RawStorageSpec {
    let size = layoutSize(ownerFullName, typeDef, symbolsByName)
    let alignment = layoutAlignment(ownerFullName, typeDef, symbolsByName)
    if (alignment >= 8 && size % 8 == 0) {
        return RawStorageSpec("UInt64", size / 8, "0u64")
    }
    if (alignment >= 4 && size % 4 == 0) {
        return RawStorageSpec("UInt32", size / 4, "0u32")
    }
    if (alignment >= 2 && size % 2 == 0) {
        return RawStorageSpec("UInt16", size / 2, "0u16")
    }
    return RawStorageSpec("UInt8", size, "0u8")
}

func layoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    var size = declaredLayoutSize(typeDef)
    var inferred: Int64 = 0
    if (contains(typeDef.attributes, "ExplicitLayout")) {
        inferred = explicitLayoutSize(ownerFullName, typeDef, symbolsByName)
    } else {
        inferred = sequentialLayoutSize(ownerFullName, typeDef, symbolsByName)
    }
    if (inferred > size) {
        size = inferred
    }
    if (size > 0) {
        return size
    }
    return 1
}

func declaredLayoutSize(typeDef: TypeDefinitionRecord): Int64 {
    match (typeDef.layout) {
        case Some(layout) =>
            if (layout.size > 0) {
                return layout.size
            }
        case None => ()
    }
    return 1
}

func explicitLayoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    var size: Int64 = 0
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName)
            let end = field.offset + abiTypeSize(fieldType, symbolsByName)
            if (end > size) {
                size = end
            }
        }
    }
    return size
}

func sequentialLayoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    var offset: Int64 = 0
    var maxAlignment: Int64 = 1
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName)
            let fieldAlignment = effectiveFieldAlignment(typeDef, abiTypeAlignment(fieldType, symbolsByName))
            if (fieldAlignment > maxAlignment) {
                maxAlignment = fieldAlignment
            }
            offset = alignUp(offset, fieldAlignment)
            offset += abiTypeSize(fieldType, symbolsByName)
        }
    }
    return alignUp(offset, maxAlignment)
}

func layoutAlignment(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    var alignment: Int64 = 1
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldAlignment = effectiveFieldAlignment(
                typeDef,
                abiTypeAlignment(cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName), symbolsByName)
            )
            if (fieldAlignment > alignment) {
                alignment = fieldAlignment
            }
        }
    }
    return alignment
}

func effectiveFieldAlignment(typeDef: TypeDefinitionRecord, fieldAlignment: Int64): Int64 {
    match (typeDef.layout) {
        case Some(layout) =>
            if (layout.packingSize > 0 && layout.packingSize < fieldAlignment) {
                return layout.packingSize
            }
        case None => ()
    }
    return fieldAlignment
}

func alignUp(value: Int64, alignment: Int64): Int64 {
    if (alignment <= 1) {
        return value
    }
    let remainder = value % alignment
    if (remainder == 0) {
        return value
    }
    return value + alignment - remainder
}

func abiTypeAlignment(typeName: String, symbolsByName: HashMap<String, SymbolRecord>): Int64 {
    if (typeName == "UInt64" || typeName == "Int64" || typeName == "Float64" ||
        typeName == "UIntNative" || typeName == "IntNative" ||
        startsWith(typeName, "CPointer<") || startsWith(typeName, "CFunc<")) {
        return 8
    }
    if (typeName == "UInt32" || typeName == "Int32" || typeName == "Float32") {
        return 4
    }
    if (typeName == "UInt16" || typeName == "Int16") {
        return 2
    }
    if (startsWith(typeName, "VArray<")) {
        match (vArrayElementTypeName(typeName)) {
            case Some(elementType) => return abiTypeAlignment(elementType, symbolsByName)
            case None => ()
        }
    }
    if (typeName == "Bool" || typeName == "UInt8" || typeName == "Int8") {
        return 1
    }
    for ((_, symbol) in symbolsByName) {
        if (symbol.implName == typeName) {
            match (symbol.typeDef) {
                case Some(typeDef) => return layoutAlignment(symbol.fullName, typeDef, symbolsByName)
                case None => return 1
            }
        }
    }
    return 1
}

func abiTypeSize(typeName: String, symbolsByName: HashMap<String, SymbolRecord>): Int64 {
    if (typeName == "Bool" || typeName == "UInt8" || typeName == "Int8") {
        return 1
    }
    if (typeName == "UInt16" || typeName == "Int16") {
        return 2
    }
    if (typeName == "UInt32" || typeName == "Int32" || typeName == "Float32") {
        return 4
    }
    if (typeName == "UInt64" || typeName == "Int64" || typeName == "Float64" ||
        typeName == "UIntNative" || typeName == "IntNative" ||
        startsWith(typeName, "CPointer<") || startsWith(typeName, "CFunc<")) {
        return 8
    }
    if (startsWith(typeName, "VArray<")) {
        match (vArrayElementTypeName(typeName)) {
            case Some(elementType) =>
                match (vArrayCount(typeName)) {
                    case Some(count) => return abiTypeSize(elementType, symbolsByName) * count
                    case None => ()
                }
            case None => ()
        }
    }
    for ((_, symbol) in symbolsByName) {
        if (symbol.implName == typeName) {
            match (symbol.typeDef) {
                case Some(typeDef) => return layoutSize(symbol.fullName, typeDef, symbolsByName)
                case None => return 1
            }
        }
    }
    return 1
}

func unionReadHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("unionReadUInt8")
        case "Int8" => return Some("unionReadInt8")
        case "UInt16" => return Some("unionReadUInt16")
        case "Int16" => return Some("unionReadInt16")
        case "UInt32" => return Some("unionReadUInt32")
        case "Int32" => return Some("unionReadInt32")
        case "UInt64" => return Some("unionReadUInt64")
        case "Int64" => return Some("unionReadInt64")
        case "Float32" => return Some("unionReadFloat32")
        case "Float64" => return Some("unionReadFloat64")
        case _ => return None
    }
}

func unionWriteHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("unionWriteUInt8")
        case "Int8" => return Some("unionWriteInt8")
        case "UInt16" => return Some("unionWriteUInt16")
        case "Int16" => return Some("unionWriteInt16")
        case "UInt32" => return Some("unionWriteUInt32")
        case "Int32" => return Some("unionWriteInt32")
        case "UInt64" => return Some("unionWriteUInt64")
        case "Int64" => return Some("unionWriteInt64")
        case "Float32" => return Some("unionWriteFloat32")
        case "Float64" => return Some("unionWriteFloat64")
        case _ => return None
    }
}

func bitfieldReadHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("bitfieldReadUInt8")
        case "UInt16" => return Some("bitfieldReadUInt16")
        case "UInt32" => return Some("bitfieldReadUInt32")
        case "UInt64" => return Some("bitfieldReadUInt64")
        case _ => return None
    }
}

func bitfieldWriteHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("bitfieldWriteUInt8")
        case "UInt16" => return Some("bitfieldWriteUInt16")
        case "UInt32" => return Some("bitfieldWriteUInt32")
        case "UInt64" => return Some("bitfieldWriteUInt64")
        case _ => return None
    }
}

func renderEnumSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let underlying = enumUnderlyingType(typeDef, symbolsByName)
    var content = "public struct ${symbol.implName} {\n" +
        "    public let value: ${underlying}\n" +
        "    public init() {\n" +
        "        this.value = ${cjLiteralInt("0", underlying)}\n" +
        "    }\n" +
        "    public init(value: ${underlying}) {\n" +
        "        this.value = value\n" +
        "    }\n"
    if (hasSystemFlagsAttribute(typeDef.customAttributes)) {
        content += renderFlagsEnumHelpers(symbol.implName)
    }
    content += "}"
    for (field in typeDef.fields) {
        if (isEnumLiteral(field)) {
            match (literalValue(field.defaultValue)) {
                case Some(value) =>
                    content += "\npublic let ${symbol.implName}_${cjIdentifier(field.name)} = " +
                        "${symbol.implName}(${cjLiteral(value, underlying)})"
                case None => ()
            }
        }
    }
    return content
}

func renderRawAliasSymbol(symbol: SymbolRecord, typeDef: TypeDefinitionRecord, rawType: String): String {
    var content = "public type ${symbol.implName} = ${rawType}"
    for (field in typeDef.fields) {
        if (isEnumLiteral(field)) {
            match (literalValue(field.defaultValue)) {
                case Some(value) =>
                    content += "\npublic let ${symbol.implName}_${cjIdentifier(field.name)}: ${symbol.implName} = " +
                        cjLiteral(value, rawType)
                case None => ()
            }
        }
    }
    return content
}

func hasSystemFlagsAttribute(attributes: ArrayList<CustomAttributeRecord>): Bool {
    for (attribute in attributes) {
        if (attribute.typeName == "System.FlagsAttribute" || attribute.typeName == "FlagsAttribute") {
            return true
        }
    }
    return false
}

func renderFlagsEnumHelpers(typeName: String): String {
    var content = "    public func contains(other: ${typeName}): Bool {\n"
    content += "        return (value & other.value) == other.value\n"
    content += "    }\n"
    content += "    public operator func |(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value | other.value)\n"
    content += "    }\n"
    content += "    public operator func &(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value & other.value)\n"
    content += "    }\n"
    content += "    public operator func ^(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value ^ other.value)\n"
    content += "    }\n"
    content += "    public operator func !(): ${typeName} {\n"
    content += "        return ${typeName}(!value)\n"
    content += "    }\n"
    return content
}

func renderPInvokeSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = "public struct ${symbol.implName} {\n"
    content += "    public init() {}\n"
    for (method in typeDef.methods) {
        match (method.methodImport) {
            case Some(methodImport) =>
                let params = methodParameterText(method, true, symbolsByName)
                let args = methodArgumentText(method, true, symbolsByName)
                let returnType = cjAbiType(method.signature.returnType, symbolsByName)
                let safeName = cjIdentifier(method.name)
                let procType = pinvokeCFuncType(method, returnType, symbolsByName)
                let moduleName = cjStringContent(methodImport.moduleName)
                let importName = cjStringContent(pinvokeImportName(method))
                content += "    public static func ${safeName}(${params}): ${returnType} {\n"
                content += "        let proc = ${procType}(windows_libloading.resolveProc(\"${moduleName}\", \"${importName}\"))\n"
                if (returnType == "Unit") {
                    content += "        unsafe { proc(${args}) }\n"
                } else {
                    content += "        return unsafe { proc(${args}) }\n"
                }
                content += "    }\n"
            case None => ()
        }
    }
    content += "}"
    return content
}

func pinvokeCFuncType(method: MethodRecord, returnType: String, symbolsByName: HashMap<String, SymbolRecord>): String {
    let pairs = methodParameterPairs(method, true, symbolsByName)
    if (pairs.isEmpty()) {
        return "CFunc<() -> ${returnType}>"
    }
    let params = ArrayList<String>()
    for (pair in pairs) {
        params.add(pair.typeName)
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>"
}

func renderInterfaceSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    guidValue: String
): String {
    var content = "@Interface[\"${guidValue}\", \"${cjStringContent(symbol.fullName)}\"]\n"
    content += "public interface ${symbol.implName} <: IInspectable {\n"
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        content += "    func ${slotName}(${interfaceMethodMacroParams(method, symbolsByName, symbol.fullName)}): Int32\n"
    }
    content += "}"
    return content
}

func interfaceMethodMacroParams(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, ownerFullName)
    let rendered = ArrayList<String>()
    for (pair in pairs) {
        rendered.add("${pair.name}: ${pair.typeName}")
    }
    joinStrings(rendered, ", ")
}

func interfaceMethodMacroParameterPairs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let pairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let parameterName = interfaceParameterName(parameter, index)
        if (isWinrtArraySignature(signature)) {
            addInterfaceArrayAbiPairs(pairs, parameterName, signature, isOutParameter(parameter), symbolsByName, ownerFullName)
        } else {
            pairs.add(ParameterPair(
                parameterName,
                interfaceParameterAbiType(signature, parameter, symbolsByName, ownerFullName)
            ))
        }
        index += 1
    }
    if (isWinrtArraySignature(method.signature.returnType)) {
        addInterfaceArrayAbiPairs(
            pairs,
            interfaceReturnParameterName(method),
            method.signature.returnType,
            true,
            symbolsByName,
            ownerFullName
        )
    } else {
        let returnType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
        if (returnType != "Unit") {
            pairs.add(ParameterPair(interfaceReturnParameterName(method), "CPointer<${returnType}>"))
        }
    }
    return pairs
}

func isWinrtArraySignature(signature: SignatureRecord): Bool {
    match (winrtArraySignature(signature)) {
        case Some(_) => return true
        case None => return false
    }
}

func winrtArraySignature(signature: SignatureRecord): Option<SignatureRecord> {
    if (signature.kind == "SZArray" || signature.kind == "Array") {
        return Some(signature)
    }
    if (signature.kind == "ByReference") {
        match (signature.typeSig) {
            case Some(nested) => return winrtArraySignature(nested)
            case None => ()
        }
    }
    return None
}

func addInterfaceArrayAbiPairs(
    pairs: ArrayList<ParameterPair>,
    name: String,
    signature: SignatureRecord,
    out: Bool,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Unit {
    let elementType = interfaceArrayElementAbiType(signature, symbolsByName, ownerFullName)
    if (out) {
        pairs.add(ParameterPair("${name}Size", "CPointer<UInt32>"))
        pairs.add(ParameterPair(name, "CPointer<CPointer<${elementType}>>"))
    } else {
        pairs.add(ParameterPair("${name}Size", "UInt32"))
        pairs.add(ParameterPair(name, "CPointer<${elementType}>"))
    }
}

func interfaceArrayElementAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (winrtArraySignature(signature)) {
        case Some(arraySignature) =>
            match (arraySignature.typeSig) {
                case Some(elementSignature) => return interfaceSlotAbiType(elementSignature, symbolsByName, ownerFullName)
                case None => ()
            }
        case None => ()
    }
    return "Unit"
}

func isOutParameter(parameter: Option<ParameterRecord>): Bool {
    match (parameter) {
        case Some(value) => return contains(value.attributes, "Out")
        case None => return false
    }
}

func interfaceParameterName(parameter: Option<ParameterRecord>, index: Int64): String {
    match (parameter) {
        case Some(value) =>
            let name = cjIdentifier(value.name)
            if (!name.isEmpty() && name != "_") {
                return name
            }
        case None => ()
    }
    "p${index}"
}

func interfaceReturnParameterName(method: MethodRecord): String {
    for (parameter in method.parameters) {
        if (parameter.sequenceNumber == 0) {
            let name = cjIdentifier(parameter.name)
            if (!name.isEmpty() && name != "_") {
                return name
            }
        }
    }
    "result"
}

func metadataMethodParameters(method: MethodRecord): ArrayList<ParameterRecord> {
    let metadataParameters = ArrayList<ParameterRecord>()
    for (parameter in method.parameters) {
        if (parameter.sequenceNumber > 0) {
            metadataParameters.add(parameter)
        }
    }
    return metadataParameters
}

func metadataParameterAt(parameters: ArrayList<ParameterRecord>, index: Int64): Option<ParameterRecord> {
    if (index < Int64(parameters.size)) {
        return Some(parameters[index])
    }
    return None
}

func interfaceParameterAbiType(
    signature: SignatureRecord,
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let typeName = interfaceSlotAbiType(signature, symbolsByName, ownerFullName)
    match (parameter) {
        case Some(metadata) =>
            if (contains(metadata.attributes, "Out")) {
                return "CPointer<${typeName}>"
            }
        case None => ()
    }
    return typeName
}

func interfaceSlotAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (win32TextPointerRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (eventRegistrationTokenRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (hresultRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (win32ScalarRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (stringHandleRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            if (fullName == "System.Guid") {
                return "GUID"
            }
            if (!startsWith(fullName, "System.")) {
                match (symbolsByName.get(fullName)) {
                    case Some(_) => ()
                    case None => return "CPointer<Unit>"
                }
            }
        case None => ()
    }
    return cjAbiTypeInContext(signature, symbolsByName, ownerFullName)
}

func uniqueInterfaceSlotName(method: MethodRecord, seen: ArrayList<String>): String {
    var base = projectedMethodBaseName(method)
    base = cjIdentifier(base)
    if (!containsExactString(seen, base)) {
        return base
    }
    var suffix: Int64 = 1
    var candidate = "${base}_${suffix}"
    while (containsExactString(seen, candidate)) {
        suffix += 1
        candidate = "${base}_${suffix}"
    }
    return candidate
}

func containsExactString(values: ArrayList<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    return false
}

func projectedMethodBaseName(method: MethodRecord): String {
    if (contains(method.attributes, "SpecialName")) {
        if (startsWith(method.name, "get_")) {
            return stripPrefix(method.name, 4)
        }
        if (startsWith(method.name, "put_")) {
            return "Set${stripPrefix(method.name, 4)}"
        }
        if (startsWith(method.name, "add_")) {
            return stripPrefix(method.name, 4)
        }
        if (startsWith(method.name, "remove_")) {
            return "Remove${stripPrefix(method.name, 7)}"
        }
        return method.name
    }
    match (methodOverloadProjectionName(method)) {
        case Some(name) => return name
        case None => return method.name
    }
}

func methodOverloadProjectionName(method: MethodRecord): Option<String> {
    for (attribute in method.customAttributes) {
        if (hasAttributeName(attribute, "OverloadAttribute") && attribute.fixedArguments.size > 0) {
            match (fixedArgumentString(attribute.fixedArguments[0])) {
                case Some(name) =>
                    if (isGeneratedOverloadName(method.name, name)) {
                        return Some(method.name)
                    }
                    return Some(name)
                case None => ()
            }
        }
    }
    return None
}

func isGeneratedOverloadName(methodName: String, overloadName: String): Bool {
    if (!startsWith(overloadName, methodName)) {
        return false
    }
    let suffix = stripPrefix(overloadName, Int64(methodName.toArray().size))
    return isAsciiDecimalDigits(suffix)
}

func isAsciiDecimalDigits(value: String): Bool {
    let bytes = value.toArray()
    if (bytes.isEmpty()) {
        return false
    }
    for (byte in bytes) {
        if (byte < b'0' || byte > b'9') {
            return false
        }
    }
    return true
}

func stripPrefix(value: String, count: Int64): String {
    let bytes = value.toArray()
    if (count >= Int64(bytes.size)) {
        return ""
    }
    return String.fromUtf8(bytes[count..Int64(bytes.size)])
}

func guidAttributeLiteral(typeDef: TypeDefinitionRecord): Option<String> {
    match (guidAttributeValues(typeDef)) {
        case Some(rawValues) =>
            let values = ArrayList<String>()
            var i: Int64 = 0
            while (i < 11) {
                values.add(guidLiteralPart(rawValues[i], i))
                i += 1
            }
            return Some("return windows_core.GUID.from_values(${joinStrings(values, ", ")})")
        case None => return None
    }
}

func guidAttributeString(typeDef: TypeDefinitionRecord): Option<String> {
    match (guidAttributeValues(typeDef)) {
        case Some(values) =>
            return Some(
                "${fixedWidthHex(values[0], 8)}-" +
                "${fixedWidthHex(values[1], 4)}-" +
                "${fixedWidthHex(values[2], 4)}-" +
                "${fixedWidthHex(values[3], 2)}${fixedWidthHex(values[4], 2)}-" +
                "${fixedWidthHex(values[5], 2)}${fixedWidthHex(values[6], 2)}" +
                "${fixedWidthHex(values[7], 2)}${fixedWidthHex(values[8], 2)}" +
                "${fixedWidthHex(values[9], 2)}${fixedWidthHex(values[10], 2)}"
            )
        case None => return None
    }
}

func guidAttributeValues(typeDef: TypeDefinitionRecord): Option<ArrayList<Int64>> {
    for (attr in typeDef.customAttributes) {
        if (attr.typeName == "Windows.Foundation.Metadata.GuidAttribute" &&
            attr.fixedArguments.size >= 11) {
            let rawValues = ArrayList<Int64>()
            var i: Int64 = 0
            while (i < 11) {
                match (fixedArgumentInt64(attr.fixedArguments[i])) {
                    case Some(value) => rawValues.add(value)
                    case None => return None
                }
                i += 1
            }
            return Some(rawValues)
        }
    }
    return None
}

func fixedWidthHex(value: Int64, width: Int64): String {
    var result = ""
    var remaining = value
    var cursor: Int64 = 0
    while (cursor < width) {
        result = hexDigit(remaining % 16) + result
        remaining /= 16
        cursor += 1
    }
    result
}

func hexDigit(value: Int64): String {
    match (value) {
        case 0 => return "0"
        case 1 => return "1"
        case 2 => return "2"
        case 3 => return "3"
        case 4 => return "4"
        case 5 => return "5"
        case 6 => return "6"
        case 7 => return "7"
        case 8 => return "8"
        case 9 => return "9"
        case 10 => return "a"
        case 11 => return "b"
        case 12 => return "c"
        case 13 => return "d"
        case 14 => return "e"
        case 15 => return "f"
        case _ => return "0"
    }
}

func guidLiteralPart(value: Int64, index: Int64): String {
    if (index == 0) {
        return "${value}u32"
    }
    if (index == 1 || index == 2) {
        return "${value}u16"
    }
    return "${value}u8"
}

func renderRawHandleSymbol(symbol: SymbolRecord, kind: String): String {
    return "public class ${symbol.implName} {\n" +
        "    private let raw: CPointer<Unit>\n" +
        "    public init(raw: CPointer<Unit>) {\n" +
        "        this.raw = raw\n" +
        "    }\n" +
        "    public func asRaw(): CPointer<Unit> {\n" +
        "        return raw\n" +
        "    }\n" +
        "    public static func runtimeName(): String {\n" +
        "        return \"${cjStringContent(symbol.fullName)}\"\n" +
        "    }\n" +
        "    public static func projectionKind(): String {\n" +
        "        return \"${kind}\"\n" +
        "    }\n" +
        "}"
}

func renderWinrtRuntimeClassSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    match (defaultWinrtClassInterfaceSpec(typeDef, symbolsByName, symbol.fullName)) {
        case Some(defaultInterface) =>
            let defaultInterfaceName = defaultInterface.typeName
            let interfaceSpecs = winrtClassInterfaceSpecs(typeDef, symbolsByName, symbol.fullName, defaultInterface)
            var content = "public class ${symbol.implName} <: windows_interface.InterfaceWrapperBase & " +
                "windows_interface.ComInterface & windows_interface.RuntimeName & windows_interface.RuntimeType & " +
                "windows_core.RuntimeName & windows_core.RuntimeType {\n"
            content += "    public init(raw: CPointer<Unit>) {\n"
            content += "        super(raw)\n"
            content += "    }\n\n"
            content += "    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {\n"
            content += "        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)\n"
            content += "    }\n\n"
            content += "    public static func fromAbiTake(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        ${symbol.implName}(raw, takeOwnership: true, allowManualRelease: false)\n"
            content += "    }\n\n"
            content += "    public static func viewOf(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        ${symbol.implName}(raw, takeOwnership: false, allowManualRelease: false)\n"
            content += "    }\n\n"
            content += "    public static func iid(): windows_interface.GUID {\n"
            content += "        ${defaultInterfaceName}.iid()\n"
            content += "    }\n\n"
            content += "    public static func descriptor(): windows_interface.InterfaceDescriptor<${symbol.implName}> {\n"
            content += "        let ancestors = [${runtimeClassAncestorIidExpressions(interfaceSpecs)}]\n"
            content += "        return windows_interface.InterfaceDescriptor<${symbol.implName}>(\"${cjStringContent(symbol.name)}\", " +
                "${defaultInterfaceName}.iid(), ancestors, { raw => ${symbol.implName}.fromAbiTake(raw) }, " +
                "{ raw => ${symbol.implName}.viewOf(raw) })\n"
            content += "    }\n\n"
            content += "    public func defaultInterface(): ${defaultInterfaceName} {\n"
            content += "        match (unsafe { query(${defaultInterfaceName}.descriptor()) }) {\n"
            content += "            case Some(value) => value\n"
            content += "            case None => throw windows_core.WindowsException(windows_core.E_NOINTERFACE)\n"
            content += "        }\n"
            content += "    }\n\n"
            content += "    public func asIInspectable(): windows_interface.IInspectable {\n"
            content += "        windows_interface.IInspectable.viewOf(asRaw())\n"
            content += "    }\n\n"
            for (interfaceSpec in interfaceSpecs) {
                content += renderRuntimeClassInterfaceAccessor(interfaceSpec, defaultInterface)
            }
            if (hasDefaultActivatableConstructor(typeDef)) {
                content += "    public static func new(): ${symbol.implName} {\n"
                content += "        var created__: Option<${symbol.implName}> = Option<${symbol.implName}>.None\n"
                content += "        try (factory__ = windows_core.factory<${symbol.implName}, windows_core.IGenericFactory>().unwrap()) {\n"
                content += "            created__ = Some(unsafe { factory__.ActivateInstance<${symbol.implName}>(${symbol.implName}.descriptor()).unwrap() })\n"
                content += "        }\n"
                content += "        match (created__) {\n"
                content += "            case Some(value) => return value\n"
                content += "            case None => throw IllegalStateException(\"Activation factory did not produce ${cjStringContent(symbol.name)}\")\n"
                content += "        }\n"
                content += "    }\n\n"
            }
            content += renderRuntimeClassFactoryMethods(symbol, typeDef, symbolsByName)
            content += "    public static func abiType(): String {\n"
            content += "        \"CPointer<Unit>\"\n"
            content += "    }\n\n"
            content += "    public static func runtimeName(): String {\n"
            content += "        \"${cjStringContent(symbol.fullName)}\"\n"
            content += "    }\n\n"
            content += "    public static func signature(): String {\n"
            content += "        return \"rc(${cjStringContent(symbol.fullName)};\" + ${defaultInterfaceName}.signature() + \")\"\n"
            content += "    }\n\n"
            content += "    public static func runtimeType(): windows_interface.RuntimeTypeContract {\n"
            content += "        windows_interface.RuntimeTypeContract(\"${cjStringContent(symbol.fullName)}\", " +
                "${symbol.implName}.signature(), ${defaultInterfaceName}.iid())\n"
            content += "    }\n"
            content += "}\n\n"
            content += "extend ${symbol.implName} <: windows_core.HandleWinrtType<${symbol.implName}> {\n"
            content += "    public static func intoWinrtHandle(value: ${symbol.implName}): CPointer<Unit> {\n"
            content += "        value.asRaw()\n"
            content += "    }\n\n"
            content += "    public static func fromAbiTakeWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        if (raw.isNull()) {\n"
            content += "            throw windows_core.WindowsException(windows_core.E_POINTER)\n"
            content += "        }\n"
            content += "        ${symbol.implName}.fromAbiTake(raw)\n"
            content += "    }\n\n"
            content += "    public static func viewWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        ${symbol.implName}.viewOf(raw)\n"
            content += "    }\n"
            content += "}"
            return Some(content)
        case None => return renderStaticOnlyWinrtRuntimeClassSymbol(symbol, typeDef, symbolsByName)
    }
}

func renderStaticOnlyWinrtRuntimeClassSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    let factoryMethods = renderRuntimeClassFactoryMethods(symbol, typeDef, symbolsByName)
    if (factoryMethods.isEmpty()) {
        return None
    }
    var content = "public struct ${symbol.implName} <: windows_interface.RuntimeName & windows_interface.RuntimeType & " +
        "windows_core.RuntimeName & windows_core.RuntimeType {\n"
    content += "    public init() {}\n\n"
    content += factoryMethods
    content += "    public static func abiType(): String {\n"
    content += "        \"CPointer<Unit>\"\n"
    content += "    }\n\n"
    content += "    public static func runtimeName(): String {\n"
    content += "        \"${cjStringContent(symbol.fullName)}\"\n"
    content += "    }\n\n"
    content += "    public static func signature(): String {\n"
    content += "        return \"rc(${cjStringContent(symbol.fullName)})\"\n"
    content += "    }\n\n"
    content += "    public static func runtimeType(): windows_interface.RuntimeTypeContract {\n"
    content += "        windows_interface.RuntimeTypeContract(\"${cjStringContent(symbol.fullName)}\", ${symbol.implName}.signature())\n"
    content += "    }\n"
    content += "}"
    return Some(content)
}

func renderRuntimeClassFactoryMethods(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let factories = runtimeClassFactoryInterfaceSpecs(typeDef, symbolsByName, symbol.fullName)
    var content = ""
    for (factorySpec in factories) {
        match (factorySpec.symbol.typeDef) {
            case Some(factoryTypeDef) =>
                let slotNames = ArrayList<String>()
                for (method in factoryTypeDef.methods) {
                    let methodName = uniqueInterfaceSlotName(method, slotNames)
                    slotNames.add(methodName)
                    content += renderRuntimeClassFactoryMethod(symbol, factorySpec, method, methodName, symbolsByName)
                }
            case None => ()
        }
    }
    return content
}

func renderRuntimeClassFactoryMethod(
    symbol: SymbolRecord,
    factorySpec: RuntimeClassInterfaceSpec,
    method: MethodRecord,
    methodName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    if (runtimeFactoryRequiresRawAbiShape(method)) {
        return renderRuntimeClassFactoryRawAbiMethod(symbol, factorySpec, method, methodName, symbolsByName)
    }
    let pairs = winrtProjectedMethodParameterPairs(method, symbolsByName, symbol.fullName)
    let params = parameterPairListText(pairs)
    let callPlan = runtimeClassFactoryCallPlan(method, pairs, symbolsByName, symbol.fullName)
    let returnType = winrtProjectedTypeName(method.signature.returnType, symbolsByName, symbol.fullName)
    var content = "    public static func ${methodName}(${params}): ${returnType} {\n"
    let returnAbiType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, symbol.fullName)
    if (returnType == "Unit") {
        content += "        var hr__ = windows_core.E_POINTER\n"
        content += renderRuntimeClassFactoryAbiCall(symbol, factorySpec, methodName, callPlan, "")
        content += "        hr__.ok()\n"
        content += "    }\n\n"
        return content
    }
    content += "        var result__ = ${cjDefaultValue(returnAbiType)}\n"
    content += "        var hr__ = windows_core.E_POINTER\n"
    content += renderRuntimeClassFactoryAbiCall(
        symbol,
        factorySpec,
        methodName,
        callPlan,
        "CPointer<${returnAbiType}>(inout result__)"
    )
    content += "        hr__.ok()\n"
    content += "        return ${runtimeProjectedReturnExpression(returnType, returnAbiType, "result__", method.signature.returnType, symbolsByName, symbol.fullName)}\n"
    content += "    }\n\n"
    return content
}

func runtimeFactoryRequiresRawAbiShape(method: MethodRecord): Bool {
    if (isWinrtArraySignature(method.signature.returnType)) {
        return true
    }
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        if (isWinrtArraySignature(signature) || signature.kind == "ByReference") {
            return true
        }
        if (isOutParameter(metadataParameterAt(metadataParameters, index))) {
            return true
        }
        index += 1
    }
    return false
}

func renderRuntimeClassFactoryRawAbiMethod(
    symbol: SymbolRecord,
    factorySpec: RuntimeClassInterfaceSpec,
    method: MethodRecord,
    methodName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
    let params = parameterPairListText(pairs)
    let args = argumentPairListText(pairs)
    var content = "    public static func ${methodName}(${params}): Unit {\n"
    content += "        var hr__ = windows_core.E_POINTER\n"
    content += "        try (factory__ = windows_core.factory<${symbol.implName}, ${factorySpec.typeName}>().unwrap()) {\n"
    content += "            hr__ = unsafe { factory__.${methodName}(${args}) }\n"
    content += "        }\n"
    content += "        hr__.ok()\n"
    content += "    }\n\n"
    return content
}

func runtimeClassFactoryCallPlan(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): RuntimeCallPlan {
    let borrows = ArrayList<RuntimeBorrowSpec>()
    let args = ArrayList<String>()
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let pair = pairs[index]
        let abiType = interfaceSlotAbiType(signature, symbolsByName, ownerFullName)
        if (runtimeCallNeedsHandleBorrow(pair.typeName, abiType)) {
            let borrowName = "__argBorrow${borrows.size}"
            borrows.add(RuntimeBorrowSpec(borrowName, pair.typeName, pair.name))
            args.add("${borrowName}.asRaw()")
        } else {
            args.add(runtimeInputAbiExpression(pair.name, pair.typeName, abiType, signature, symbolsByName, ownerFullName))
        }
        index += 1
    }
    return RuntimeCallPlan(borrows, args)
}

func runtimeCallNeedsHandleBorrow(typeName: String, abiType: String): Bool {
    return abiType == "CPointer<Unit>" && typeName != "CPointer<Unit>"
}

func runtimeInputAbiExpression(
    name: String,
    typeName: String,
    abiType: String,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (typeName == "windows_core.GuidValue" && abiType == "GUID") {
        return "${name}.toRaw()"
    }
    if (isEnumSignature(signature, symbolsByName, ownerFullName)) {
        return "${name}.value"
    }
    return name
}

func renderRuntimeClassFactoryAbiCall(
    symbol: SymbolRecord,
    factorySpec: RuntimeClassInterfaceSpec,
    methodName: String,
    callPlan: RuntimeCallPlan,
    outputArg: String
): String {
    let callArgs = ArrayList<String>()
    for (arg in callPlan.args) {
        callArgs.add(arg)
    }
    if (!outputArg.isEmpty()) {
        callArgs.add(outputArg)
    }
    var content = ""
    var index: Int64 = 0
    while (index < Int64(callPlan.borrows.size)) {
        let borrow = callPlan.borrows[index]
        content += "${runtimeIndent(2 + index)}try (${borrow.name} = windows_core.winrtBorrowGenericIn<${borrow.typeName}>(${borrow.sourceName})) {\n"
        index += 1
    }
    let factoryIndentLevel = 2 + Int64(callPlan.borrows.size)
    content += "${runtimeIndent(factoryIndentLevel)}try (factory__ = windows_core.factory<${symbol.implName}, ${factorySpec.typeName}>().unwrap()) {\n"
    content += "${runtimeIndent(factoryIndentLevel + 1)}hr__ = unsafe { factory__.${methodName}(${joinStrings(callArgs, ", ")}) }\n"
    content += "${runtimeIndent(factoryIndentLevel)}}\n"
    var closeIndex = Int64(callPlan.borrows.size) - 1
    while (closeIndex >= 0) {
        content += "${runtimeIndent(2 + closeIndex)}}\n"
        closeIndex -= 1
    }
    return content
}

func runtimeProjectedReturnExpression(
    returnType: String,
    returnAbiType: String,
    resultName: String,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (returnType == returnAbiType) {
        return resultName
    }
    if (returnType == "windows_core.GuidValue" && returnAbiType == "GUID") {
        return "windows_core.GuidValue.fromRaw(${resultName})"
    }
    if (isEnumSignature(signature, symbolsByName, ownerFullName)) {
        return "${returnType}(${resultName})"
    }
    if (returnAbiType == "CPointer<Unit>") {
        return "${returnType}.fromAbiTakeWinrtHandle(${resultName})"
    }
    return resultName
}

func isEnumSignature(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (symbolsByName.get(fullName)) {
                case Some(symbol) =>
                    match (symbol.typeDef) {
                        case Some(typeDef) => return isEnumType(typeDef)
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    return false
}

func runtimeIndent(level: Int64): String {
    var result = ""
    var index: Int64 = 0
    while (index < level) {
        result += "    "
        index += 1
    }
    return result
}

func runtimeClassFactoryInterfaceSpecs(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<RuntimeClassInterfaceSpec> {
    let values = ArrayList<RuntimeClassInterfaceSpec>()
    for (attribute in typeDef.customAttributes) {
        if (isRuntimeClassFactoryAttribute(attribute)) {
            for (fullName in customAttributeTypeNameArgumentFullNames(attribute)) {
                match (symbolsByName.get(fullName)) {
                    case Some(symbol) =>
                        addRuntimeClassFactoryInterfaceSpec(values, symbol)
                    case None =>
                        match (resolveRelativeTypeFullName(ownerFullName, fullName, symbolsByName)) {
                            case Some(relativeFullName) =>
                                match (symbolsByName.get(relativeFullName)) {
                                    case Some(symbol) => addRuntimeClassFactoryInterfaceSpec(values, symbol)
                                    case None => ()
                                }
                            case None => ()
                        }
                }
            }
        }
    }
    return values
}

func addRuntimeClassFactoryInterfaceSpec(values: ArrayList<RuntimeClassInterfaceSpec>, symbol: SymbolRecord): Unit {
    match (symbol.typeDef) {
        case Some(typeDef) =>
            if (isInterfaceType(typeDef)) {
                addUniqueInterfaceSpec(values, RuntimeClassInterfaceSpec(symbol, symbol.implName))
            }
        case None => ()
    }
}

func isRuntimeClassFactoryAttribute(attribute: CustomAttributeRecord): Bool {
    return hasAttributeName(attribute, "StaticAttribute") ||
        hasAttributeName(attribute, "ActivatableAttribute") ||
        hasAttributeName(attribute, "ComposableAttribute")
}

func hasAttributeName(attribute: CustomAttributeRecord, shortName: String): Bool {
    return attribute.typeName == shortName || endsWith(attribute.typeName, ".${shortName}")
}

func winrtProjectedMethodParameterPairs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let pairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        pairs.add(ParameterPair(
            interfaceParameterName(parameter, index),
            winrtProjectedTypeName(signature, symbolsByName, ownerFullName)
        ))
        index += 1
    }
    return pairs
}

func parameterPairListText(pairs: ArrayList<ParameterPair>): String {
    let rendered = ArrayList<String>()
    for (pair in pairs) {
        rendered.add("${pair.name}: ${pair.typeName}")
    }
    return joinStrings(rendered, ", ")
}

func argumentPairListText(pairs: ArrayList<ParameterPair>): String {
    let rendered = ArrayList<String>()
    for (pair in pairs) {
        rendered.add(pair.name)
    }
    return joinStrings(rendered, ", ")
}

func winrtClassInterfaceSpecs(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    defaultInterface: RuntimeClassInterfaceSpec
): ArrayList<RuntimeClassInterfaceSpec> {
    let values = ArrayList<RuntimeClassInterfaceSpec>()
    addUniqueInterfaceSpec(values, defaultInterface)
    for (implementation in typeDef.interfaceImplementations) {
        match (runtimeClassInterfaceSpec(implementation, symbolsByName, ownerFullName)) {
            case Some(spec) =>
                addUniqueInterfaceSpec(values, spec)
            case None => ()
        }
    }
    return values
}

func addUniqueInterfaceSpec(values: ArrayList<RuntimeClassInterfaceSpec>, spec: RuntimeClassInterfaceSpec): Unit {
    for (value in values) {
        if (value.typeName == spec.typeName) {
            return
        }
    }
    values.add(spec)
}

func runtimeClassAncestorIidExpressions(interfaceSpecs: ArrayList<RuntimeClassInterfaceSpec>): String {
    let values = ArrayList<String>()
    for (interfaceSpec in interfaceSpecs) {
        values.add("${interfaceSpec.typeName}.iid()")
    }
    values.add("windows_interface.IInspectable.iid()")
    values.add("windows_interface.IUnknown.iid()")
    joinStrings(values, ", ")
}

func renderRuntimeClassInterfaceAccessor(
    interfaceSpec: RuntimeClassInterfaceSpec,
    defaultInterface: RuntimeClassInterfaceSpec
): String {
    var content = "    public func as${interfaceSpec.accessorName}(): ${interfaceSpec.typeName} {\n"
    if (interfaceSpec.typeName == defaultInterface.typeName) {
        content += "        defaultInterface()\n"
    } else {
        content += "        match (unsafe { query<${interfaceSpec.typeName}>(${interfaceSpec.typeName}.descriptor()) }) {\n"
        content += "            case Some(value) => value\n"
        content += "            case None => throw windows_core.WindowsException(windows_core.E_NOINTERFACE)\n"
        content += "        }\n"
    }
    content += "    }\n\n"
    content
}

func defaultWinrtClassInterfaceSpec(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<RuntimeClassInterfaceSpec> {
    for (implementation in typeDef.interfaceImplementations) {
        if (hasCustomAttribute(implementation.customAttributes, "DefaultAttribute")) {
            match (runtimeClassInterfaceSpec(implementation, symbolsByName, ownerFullName)) {
                case Some(spec) => return Some(spec)
                case None => ()
            }
        }
    }
    return None
}

func runtimeClassInterfaceSpec(
    implementation: InterfaceImplementationRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<RuntimeClassInterfaceSpec> {
    match (implementation.interfaceSignature) {
        case Some(signature) =>
            match (interfaceImplementationFullName(implementation, symbolsByName, ownerFullName)) {
                case Some(fullName) =>
                    match (symbolsByName.get(fullName)) {
                        case Some(symbol) =>
                            return Some(RuntimeClassInterfaceSpec(
                                symbol,
                                closedWinrtTypeName(signature, symbol, symbolsByName, ownerFullName)
                            ))
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    match (interfaceImplementationFullName(implementation, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (symbolsByName.get(fullName)) {
                case Some(symbol) => return Some(RuntimeClassInterfaceSpec(symbol, symbol.implName))
                case None => ()
            }
        case None => ()
    }
    return None
}

func closedWinrtTypeName(
    signature: SignatureRecord,
    symbol: SymbolRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let typeArguments = signatureTypeArguments(signature)
    if (typeArguments.isEmpty()) {
        return symbol.implName
    }
    let rendered = ArrayList<String>()
    for (argument in typeArguments) {
        rendered.add(winrtProjectedTypeName(argument, symbolsByName, ownerFullName))
    }
    "${symbol.implName}<${joinStrings(rendered, ", ")}>"
}

func signatureTypeArguments(signature: SignatureRecord): ArrayList<SignatureRecord> {
    match (signature.typeSpecification) {
        case Some(typeSpec) => return signatureTypeArguments(typeSpec.signature)
        case None => ()
    }
    if (!signature.typeArguments.isEmpty()) {
        return signature.typeArguments
    }
    match (signature.typeSig) {
        case Some(nested) => return signatureTypeArguments(nested)
        case None => return ArrayList<SignatureRecord>()
    }
}

func winrtProjectedTypeName(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (signature.typeSpecification) {
        case Some(typeSpec) => return winrtProjectedTypeName(typeSpec.signature, symbolsByName, ownerFullName)
        case None => ()
    }
    if (signature.kind == "Primitive") {
        return primitiveCjType(signature.name)
    }
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            if (fullName == "System.String") {
                return "windows_core.HString"
            }
            if (fullName == "System.Guid") {
                return "windows_core.GuidValue"
            }
            if (fullName == "System.Object") {
                return "windows_interface.IInspectable"
            }
            if (startsWith(fullName, "System.")) {
                return systemType(fullName)
            }
            match (symbolsByName.get(fullName)) {
                case Some(symbol) => return closedWinrtTypeName(signature, symbol, symbolsByName, ownerFullName)
                case None => return mangleFullName(fullName)
            }
        case None => ()
    }
    match (signature.typeSig) {
        case Some(nested) => return winrtProjectedTypeName(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    return "CPointer<Unit>"
}

func interfaceImplementationFullName(
    implementation: InterfaceImplementationRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (implementation.interfaceSignature) {
        case Some(signature) =>
            match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
                case Some(fullName) => return Some(fullName)
                case None => ()
            }
        case None => ()
    }
    match (implementation.typeDefinition) {
        case Some(metadataType) => return Some(metadataType.fullName())
        case None => ()
    }
    match (implementation.typeReference) {
        case Some(metadataType) => return Some(metadataType.fullName())
        case None => ()
    }
    return None
}

func hasCustomAttribute(attributes: ArrayList<CustomAttributeRecord>, shortName: String): Bool {
    for (attribute in attributes) {
        if (attribute.typeName == shortName || endsWith(attribute.typeName, ".${shortName}")) {
            return true
        }
    }
    return false
}

func hasDefaultActivatableConstructor(typeDef: TypeDefinitionRecord): Bool {
    for (attribute in typeDef.customAttributes) {
        if ((attribute.typeName == "ActivatableAttribute" || endsWith(attribute.typeName, ".ActivatableAttribute")) &&
            !customAttributeHasTypeNameArgument(attribute)) {
            return true
        }
    }
    return false
}

func customAttributeHasTypeNameArgument(attribute: CustomAttributeRecord): Bool {
    for (argument in attribute.fixedArguments) {
        if (isSystemTypeSignature(argument.typeSig)) {
            return true
        }
    }
    return false
}

func customAttributeTypeNameArgumentFullNames(attribute: CustomAttributeRecord): ArrayList<String> {
    let values = ArrayList<String>()
    for (argument in attribute.fixedArguments) {
        if (isSystemTypeSignature(argument.typeSig)) {
            match (fixedArgumentTypeFullName(argument)) {
                case Some(fullName) => values.add(fullName)
                case None => ()
            }
        }
    }
    return values
}

func fixedArgumentTypeFullName(argument: CustomAttributeFixedArgumentRecord): Option<String> {
    match (literalValue(argument.value)) {
        case Some(value) => return jsonTypeFullName(value)
        case None => return None
    }
}

func jsonTypeFullName(value: JsonValue): Option<String> {
    match (value.kind()) {
        case JsonKind.JsString => return Some(value.asString().getValue())
        case JsonKind.JsObject =>
            let obj = value.asObject()
            match (jsonObjectStringMember(obj, "FullName")) {
                case Some(fullName) => return Some(fullName)
                case None => ()
            }
            let namespaceName = jsonObjectStringMember(obj, "Namespace") ?? ""
            let shortName = jsonObjectStringMember(obj, "Name") ?? ""
            if (!shortName.isEmpty()) {
                if (namespaceName.isEmpty()) {
                    return Some(shortName)
                }
                return Some("${namespaceName}.${shortName}")
            }
        case _ => ()
    }
    return None
}

func jsonObjectStringMember(obj: JsonObject, name: String): Option<String> {
    match (obj.get(name)) {
        case Some(value) =>
            match (value.kind()) {
                case JsonKind.JsString => return Some(value.asString().getValue())
                case _ => ()
            }
        case None => ()
    }
    return None
}

func isSystemTypeSignature(signature: SignatureRecord): Bool {
    if (signature.kind == "Type" && signature.namespace == "System" && signature.name == "Type") {
        return true
    }
    match (signatureFullNameInContext(signature, HashMap<String, SymbolRecord>(), "")) {
        case Some(fullName) => return fullName == "System.Type"
        case None => return false
    }
}

func isPublicInstanceField(field: FieldRecord): Bool {
    return contains(field.attributes, "Public") &&
        !contains(field.attributes, "Static") &&
        !contains(field.attributes, "Literal")
}

func hasPublicInstanceFields(typeDef: TypeDefinitionRecord): Bool {
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            return true
        }
    }
    return false
}

func isLiteralField(field: FieldRecord): Bool {
    return contains(field.attributes, "Public") &&
        contains(field.attributes, "Static") &&
        contains(field.attributes, "Literal")
}

func hasLiteralFields(typeDef: TypeDefinitionRecord): Bool {
    for (field in typeDef.fields) {
        if (isLiteralField(field)) {
            return true
        }
    }
    return false
}

func isEnumLiteral(field: FieldRecord): Bool {
    return isLiteralField(field)
}

func enumUnderlyingType(typeDef: TypeDefinitionRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    for (field in typeDef.fields) {
        if (field.name == "value__") {
            return cjAbiType(field.signature, symbolsByName)
        }
    }
    return "Int32"
}

func methodParameterText(method: MethodRecord, abi: Bool, symbolsByName: HashMap<String, SymbolRecord>): String {
    let pairs = methodParameterPairs(method, abi, symbolsByName)
    var content = ""
    var first = true
    for (pair in pairs) {
        if (!first) {
            content += ", "
        }
        content += "${pair.name}: ${pair.typeName}"
        first = false
    }
    return content
}

func methodArgumentText(method: MethodRecord, abi: Bool, symbolsByName: HashMap<String, SymbolRecord>): String {
    let pairs = methodParameterPairs(method, abi, symbolsByName)
    var content = ""
    var first = true
    for (pair in pairs) {
        if (!first) {
            content += ", "
        }
        content += pair.name
        first = false
    }
    return content
}

func methodParameterPairs(
    method: MethodRecord,
    abi: Bool,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<ParameterPair> {
    let metadataParameters = ArrayList<ParameterRecord>()
    for (parameter in method.parameters) {
        if (parameter.sequenceNumber > 0) {
            metadataParameters.add(parameter)
        }
    }
    let pairs = ArrayList<ParameterPair>()
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        var name = "p${index}"
        if (index < Int64(metadataParameters.size)) {
            let parameterName = cjIdentifier(metadataParameters[index].name)
            if (!parameterName.isEmpty() && parameterName != "_") {
                name = parameterName
            }
        }
        var typeName = cjAbiType(signature, symbolsByName)
        if (!abi) {
            typeName = cjProjectedType(signature, symbolsByName)
        }
        pairs.add(ParameterPair(name, typeName))
        index += 1
    }
    return pairs
}

func pinvokeImportName(method: MethodRecord): String {
    match (method.methodImport) {
        case Some(methodImport) => return methodImport.name
        case None => return method.name
    }
}

func cjProjectedType(signature: SignatureRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    return cjAbiType(signature, symbolsByName)
}

func cjConstantType(signature: SignatureRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    if (signature.kind == "Primitive" && signature.name == "String") {
        return "String"
    }
    match (win32StringPointerLiteralFactoryType(signature, symbolsByName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (signatureFullNameInContext(signature, symbolsByName, "")) {
        case Some(fullName) =>
            if (fullName == "System.String") {
                return "String"
            }
        case None => ()
    }
    return cjAbiType(signature, symbolsByName)
}

func win32StringPointerLiteralFactoryType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, "")) {
        case Some(fullName) =>
            if (fullName == "Windows.Win32.Foundation.PCWSTR") {
                return Some("windows_strings.WideStringFactory")
            }
            if (fullName == "Windows.Win32.Foundation.PCSTR") {
                return Some("windows_strings.NarrowStringFactory")
            }
        case None => ()
    }
    return None
}

func win32TextPointerRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return win32TextPointerRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func win32TextPointerRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.PWSTR" ||
        fullName == "Windows.Win32.Foundation.PCWSTR") {
        return Some("CPointer<UInt16>")
    }
    if (fullName == "Windows.Win32.Foundation.PSTR" ||
        fullName == "Windows.Win32.Foundation.PCSTR") {
        return Some("CPointer<UInt8>")
    }
    return None
}

func eventRegistrationTokenRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return eventRegistrationTokenRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func eventRegistrationTokenRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Foundation.EventRegistrationToken" ||
        fullName == "Windows.Win32.System.WinRT.EventRegistrationToken") {
        return Some("Int64")
    }
    return None
}

func hresultRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return hresultRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func hresultRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Foundation.HResult" ||
        fullName == "Windows.Win32.Foundation.HRESULT") {
        return Some("Int32")
    }
    return None
}

func win32ScalarRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return win32ScalarRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func win32ScalarRawAbiTypeByFullName(fullName: String): Option<String> {
    match (fullName) {
        case "Windows.Win32.Foundation.BOOL" => return Some("Int32")
        case "Windows.Win32.Foundation.BOOLEAN" => return Some("UInt8")
        case "Windows.Win32.Foundation.CHAR" => return Some("Int8")
        case "Windows.Win32.Foundation.COLORREF" => return Some("UInt32")
        case "Windows.Win32.Foundation.DWORD_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.DUPLICATE_HANDLE_OPTIONS" => return Some("UInt32")
        case "Windows.Win32.Foundation.GENERIC_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.Foundation.HANDLE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Foundation.HANDLE_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.INT_PTR" => return Some("IntNative")
        case "Windows.Win32.Foundation.LONG_PTR" => return Some("IntNative")
        case "Windows.Win32.Foundation.LPARAM" => return Some("IntNative")
        case "Windows.Win32.Foundation.LRESULT" => return Some("IntNative")
        case "Windows.Win32.Foundation.NTSTATUS" => return Some("Int32")
        case "Windows.Win32.Foundation.NTSTATUS_FACILITY_CODE" => return Some("UInt32")
        case "Windows.Win32.Foundation.NTSTATUS_SEVERITY_CODE" => return Some("UInt32")
        case "Windows.Win32.Foundation.OBJECT_ATTRIBUTE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Foundation.SHANDLE_PTR" => return Some("IntNative")
        case "Windows.Win32.Foundation.SIZE_T" => return Some("UIntNative")
        case "Windows.Win32.Foundation.SSIZE_T" => return Some("IntNative")
        case "Windows.Win32.Foundation.UINT_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.ULONG_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.VARIANT_BOOL" => return Some("Int16")
        case "Windows.Win32.Foundation.WAIT_EVENT" => return Some("UInt32")
        case "Windows.Win32.Foundation.WIN32_ERROR" => return Some("UInt32")
        case "Windows.Win32.Foundation.WPARAM" => return Some("UIntNative")
        case "Windows.Win32.Security.ACE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.ACE_REVISION" => return Some("UInt32")
        case "Windows.Win32.Security.ACL_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.Security.AUDIT_EVENT_TYPE" => return Some("Int32")
        case "Windows.Win32.Security.CLAIM_SECURITY_ATTRIBUTE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE" => return Some("UInt16")
        case "Windows.Win32.Security.CREATE_RESTRICTED_TOKEN_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.ENUM_PERIOD" => return Some("Int32")
        case "Windows.Win32.Security.LOGON32_LOGON" => return Some("UInt32")
        case "Windows.Win32.Security.LOGON32_PROVIDER" => return Some("UInt32")
        case "Windows.Win32.Security.MANDATORY_LEVEL" => return Some("Int32")
        case "Windows.Win32.Security.OBJECT_SECURITY_INFORMATION" => return Some("UInt32")
        case "Windows.Win32.Security.SECURITY_AUTO_INHERIT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.SECURITY_DESCRIPTOR_CONTROL" => return Some("UInt16")
        case "Windows.Win32.Security.SECURITY_IMPERSONATION_LEVEL" => return Some("Int32")
        case "Windows.Win32.Security.SID_NAME_USE" => return Some("Int32")
        case "Windows.Win32.Security.SYSTEM_AUDIT_OBJECT_ACE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_ACCESS_MASK" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_ELEVATION_TYPE" => return Some("Int32")
        case "Windows.Win32.Security.TOKEN_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.Security.TOKEN_MANDATORY_POLICY_ID" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_PRIVILEGES_ATTRIBUTES" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_TYPE" => return Some("Int32")
        case "Windows.Win32.Security.WELL_KNOWN_SID_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.ADVANCED_FEATURE_FLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.ADVF" => return Some("Int32")
        case "Windows.Win32.System.Com.APTTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.APTTYPEQUALIFIER" => return Some("Int32")
        case "Windows.Win32.System.Com.ApplicationType" => return Some("Int32")
        case "Windows.Win32.System.Com.BINDINFOF" => return Some("Int32")
        case "Windows.Win32.System.Com.BIND_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.CALLCONV" => return Some("Int32")
        case "Windows.Win32.System.Com.CALLTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.CLSCTX" => return Some("UInt32")
        case "Windows.Win32.System.Com.COINIT" => return Some("Int32")
        case "Windows.Win32.System.Com.COINITBASE" => return Some("Int32")
        case "Windows.Win32.System.Com.COMSD" => return Some("Int32")
        case "Windows.Win32.System.Com.COWAIT_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.CWMO_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.CO_MARSHALING_CONTEXT_ATTRIBUTES" => return Some("Int32")
        case "Windows.Win32.System.Com.DATADIR" => return Some("Int32")
        case "Windows.Win32.System.Com.DCOM_CALL_STATE" => return Some("Int32")
        case "Windows.Win32.System.Com.DESCKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.DISPATCH_FLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.DVASPECT" => return Some("UInt32")
        case "Windows.Win32.System.Com.EOLE_AUTHENTICATION_CAPABILITIES" => return Some("Int32")
        case "Windows.Win32.System.Com.EXTCONN" => return Some("Int32")
        case "Windows.Win32.System.Com.FUNCFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.FUNCKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_EH_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_PROPERTIES" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_RO_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_RPCTP_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_UNMARSHALING_POLICY_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.IDLFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.IMPLTYPEFLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.INVOKEKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.LOCKTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.MEMCTX" => return Some("Int32")
        case "Windows.Win32.System.Com.MKRREDUCE" => return Some("Int32")
        case "Windows.Win32.System.Com.MKSYS" => return Some("Int32")
        case "Windows.Win32.System.Com.MSHCTX" => return Some("Int32")
        case "Windows.Win32.System.Com.MSHLFLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.PENDINGMSG" => return Some("Int32")
        case "Windows.Win32.System.Com.PENDINGTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.REGCLS" => return Some("Int32")
        case "Windows.Win32.System.Com.ROT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Com.RPCOPT_PROPERTIES" => return Some("Int32")
        case "Windows.Win32.System.Com.RPCOPT_SERVER_LOCALITY_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.RPC_C_AUTHN_LEVEL" => return Some("UInt32")
        case "Windows.Win32.System.Com.RPC_C_IMP_LEVEL" => return Some("UInt32")
        case "Windows.Win32.System.Com.SERVERCALL" => return Some("Int32")
        case "Windows.Win32.System.Com.ShutdownType" => return Some("Int32")
        case "Windows.Win32.System.Com.STATFLAG" => return Some("Int32")
        case "Windows.Win32.System.Com.STGC" => return Some("Int32")
        case "Windows.Win32.System.Com.STGM" => return Some("UInt32")
        case "Windows.Win32.System.Com.STGTY" => return Some("Int32")
        case "Windows.Win32.System.Com.STREAM_SEEK" => return Some("UInt32")
        case "Windows.Win32.System.Com.SYSKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.THDTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.TYMED" => return Some("Int32")
        case "Windows.Win32.System.Com.TYPEKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.TYSPEC" => return Some("Int32")
        case "Windows.Win32.System.Com.URI_CREATE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Com.Uri_PROPERTY" => return Some("Int32")
        case "Windows.Win32.System.Com.VARFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.VARKIND" => return Some("Int32")
        case "Windows.Win32.System.Diagnostics.Debug.CONTEXT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Kernel.COMPARTMENT_ID" => return Some("Int32")
        case "Windows.Win32.System.Kernel.EVENT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.EXCEPTION_DISPOSITION" => return Some("Int32")
        case "Windows.Win32.System.Kernel.NT_PRODUCT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.SUITE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.TIMER_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.WAIT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Ole.PARAMFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Registry.REG_CREATE_KEY_DISPOSITION" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_NOTIFY_FILTER" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_OPEN_CREATE_OPTIONS" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_RESTORE_KEY_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Registry.REG_ROUTINE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_SAM_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_SAVE_FORMAT" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_VALUE_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.ENUM_SERVICE_STATE" => return Some("UInt32")
        case "Windows.Win32.System.Services.ENUM_SERVICE_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SC_ACTION_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SC_ENUM_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SC_EVENT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SC_STATUS_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_CONFIG" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_DIRECTORY_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_ERROR" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_NOTIFY" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_REGISTRY_STATE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_RUNS_IN_PROCESS" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_SHARED_DIRECTORY_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_SHARED_REGISTRY_STATE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_START_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_STATUS_CURRENT_STATE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_TRIGGER_ACTION" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_TRIGGER_SPECIFIC_DATA_ITEM_DATA_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_TRIGGER_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.COMPUTER_NAME_FORMAT" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.CPU_SET_INFORMATION_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.DEP_SYSTEM_POLICY_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.DEVELOPER_DRIVE_ENABLEMENT_STATE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.DEVICEFAMILYDEVICEFORM" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.DEVICEFAMILYINFOENUM" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.FIRMWARE_TABLE_PROVIDER" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.FIRMWARE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.IMAGE_FILE_MACHINE" => return Some("UInt16")
        case "Windows.Win32.System.SystemInformation.LOGICAL_PROCESSOR_RELATIONSHIP" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.OS_DEPLOYEMENT_STATE_VALUES" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.OS_PRODUCT_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.PROCESSOR_ARCHITECTURE" => return Some("UInt16")
        case "Windows.Win32.System.SystemInformation.PROCESSOR_CACHE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.RTL_SYSTEM_GLOBAL_DATA_ID" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.USER_CET_ENVIRONMENT" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.VER_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.SystemServices.RTL_UMS_SCHEDULER_REASON" => return Some("Int32")
        case "Windows.Win32.System.Threading.AVRT_PRIORITY" => return Some("Int32")
        case "Windows.Win32.System.Threading.CREATE_EVENT" => return Some("UInt32")
        case "Windows.Win32.System.Threading.CREATE_PROCESS_LOGON_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.GET_GUI_RESOURCES_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.MACHINE_ATTRIBUTES" => return Some("Int32")
        case "Windows.Win32.System.Threading.MEMORY_PRIORITY" => return Some("UInt32")
        case "Windows.Win32.System.Threading.OVERRIDE_PREFETCH_PARAMETER" => return Some("UInt32")
        case "Windows.Win32.System.Threading.POWER_REQUEST_CONTEXT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESSOR_FEATURE_ID" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_AFFINITY_AUTO_UPDATE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_CREATION_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_DEP_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.System.Threading.PROCESS_MEMORY_EXHAUSTION_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Threading.PROCESS_MITIGATION_POLICY" => return Some("Int32")
        case "Windows.Win32.System.Threading.PROCESS_NAME_FORMAT" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_PROTECTION_LEVEL" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROC_THREAD_ATTRIBUTE_NUM" => return Some("UInt32")
        case "Windows.Win32.System.Threading.QUEUE_USER_APC_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Threading.RTWQ_WORKQUEUE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Threading.STARTUPINFOW_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.SYNCHRONIZATION_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.THREAD_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.THREAD_CREATION_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.THREAD_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.System.Threading.THREAD_PRIORITY" => return Some("Int32")
        case "Windows.Win32.System.Threading.TP_CALLBACK_PRIORITY" => return Some("Int32")
        case "Windows.Win32.System.Threading.UMS_THREAD_INFO_CLASS" => return Some("Int32")
        case "Windows.Win32.System.Threading.WORKER_THREAD_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Variant.VARENUM" => return Some("UInt16")
        case _ => return None
    }
}

func stringHandleRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return stringHandleRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func stringHandleRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.BSTR" ||
        fullName == "Windows.Win32.System.WinRT.HSTRING") {
        return Some("CPointer<Unit>")
    }
    return None
}

func knownRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (win32TextPointerRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (eventRegistrationTokenRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (hresultRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (win32ScalarRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (stringHandleRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    return None
}

func rawPointerAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    if (signature.kind != "Pointer" && signature.kind != "ByReference" &&
        signature.kind != "SZArray") {
        return None
    }
    match (signature.typeSig) {
        case Some(nested) =>
            match (knownRawAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
            match (rawPointerAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) =>
            match (knownRawAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
            match (rawPointerAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
        case None => ()
    }
    return None
}

func cjAbiType(signature: SignatureRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    return cjAbiTypeInContext(signature, symbolsByName, "")
}

func cjAbiTypeInContext(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (win32TextPointerRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (eventRegistrationTokenRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (hresultRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (win32ScalarRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (stringHandleRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    if (signature.kind == "Primitive") {
        return primitiveCjType(signature.name)
    }
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    if (signature.kind == "Array") {
        match (fixedArrayCjType(signature, symbolsByName, ownerFullName)) {
            case Some(typeName) => return typeName
            case None => return "CPointer<Unit>"
        }
    }
    if (signature.kind == "Pointer" || signature.kind == "ByReference" ||
        signature.kind == "SZArray") {
        match (rawPointerAbiType(signature, symbolsByName, ownerFullName)) {
            case Some(typeName) => return typeName
            case None => ()
        }
        return "CPointer<Unit>"
    }
    if (signature.kind == "Type" || signature.kind == "TypeReference" || signature.kind == "TypeDefinition") {
        match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
            case Some(fullName) =>
                if (startsWith(fullName, "System.")) {
                    return systemType(fullName)
                }
                match (symbolsByName.get(fullName)) {
                    case Some(symbol) =>
                        match (symbol.typeDef) {
                            case Some(typeDef) =>
                                if (isEnumType(typeDef)) {
                                    return enumUnderlyingType(typeDef, symbolsByName)
                                }
                                if (isWinrtDelegateType(typeDef)) {
                                    return "CPointer<Unit>"
                                }
                                if (isDelegateType(typeDef)) {
                                    match (delegateCFuncType(typeDef, symbolsByName)) {
                                        case Some(typeName) => return typeName
                                        case None => ()
                                    }
                                }
                                if (!isValueType(typeDef)) {
                                    return "CPointer<Unit>"
                                }
                            case None => ()
                        }
                    case None => ()
                }
                return mangleFullName(fullName)
            case None => ()
        }
    }
    match (signature.typeSpecification) {
        case Some(_) => return "CPointer<Unit>"
        case None => ()
    }
    match (signature.typeSig) {
        case Some(nested) => return cjAbiTypeInContext(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) => return cjAbiTypeInContext(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    return "CPointer<Unit>"
}

func delegateCFuncType(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    for (method in typeDef.methods) {
        if (method.name == "Invoke") {
            let params = ArrayList<String>()
            for (parameter in method.signature.parameters) {
                params.add(cjAbiType(parameter, symbolsByName))
            }
            let returnType = cjAbiType(method.signature.returnType, symbolsByName)
            if (params.isEmpty()) {
                return Some("CFunc<() -> ${returnType}>")
            }
            return Some("CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>")
        }
    }
    return None
}

func fixedArrayCjType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signature.rank) {
        case Some(rank) =>
            if (rank != 1) {
                return None
            }
        case None => return None
    }
    match (signature.sizes) {
        case Some(sizes) =>
            if (sizes.size != 1 || sizes[0] <= 0) {
                return None
            }
            match (signature.typeSig) {
                case Some(elementSignature) =>
                    let elementType = cjAbiTypeInContext(elementSignature, symbolsByName, ownerFullName)
                    return Some("VArray<${elementType}, \$${sizes[0]}>")
                case None => return None
            }
        case None => return None
    }
}

func signatureFullNameInContext(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signature.typeSpecification) {
        case Some(typeSpec) => return signatureFullNameInContext(typeSpec.signature, symbolsByName, ownerFullName)
        case None => ()
    }
    if (!signature.name.isEmpty() && signature.hasNamespace) {
        if (signature.namespace.isEmpty()) {
            match (resolveRelativeTypeFullName(ownerFullName, signature.name, symbolsByName)) {
                case Some(fullName) => return Some(remapKnownTypeFullName(fullName))
                case None => ()
            }
            return Some(signature.name)
        }
        return Some(remapKnownTypeFullName("${signature.namespace}.${signature.name}"))
    }
    match (signature.typeReference) {
        case Some(metadataType) =>
            if (metadataType.namespace.isEmpty()) {
                match (resolveRelativeTypeFullName(ownerFullName, metadataType.name, symbolsByName)) {
                    case Some(fullName) => return Some(remapKnownTypeFullName(fullName))
                    case None => ()
                }
            }
            return Some(remapKnownTypeFullName(metadataType.fullName()))
        case None => ()
    }
    match (signature.typeDefinition) {
        case Some(metadataType) =>
            if (metadataType.namespace.isEmpty()) {
                match (resolveRelativeTypeFullName(ownerFullName, metadataType.name, symbolsByName)) {
                    case Some(fullName) => return Some(remapKnownTypeFullName(fullName))
                    case None => ()
                }
            }
            return Some(remapKnownTypeFullName(metadataType.fullName()))
        case None => ()
    }
    return None
}

func remapKnownTypeFullName(fullName: String): String {
    match (fullName) {
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_MATRIX_3X2_F" =>
            return "Windows.Foundation.Numerics.Matrix3x2"
        case "Windows.Win32.Graphics.Direct3D.D3DMATRIX" =>
            return "Windows.Foundation.Numerics.Matrix4x4"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_MATRIX_4X4_F" =>
            return "Windows.Foundation.Numerics.Matrix4x4"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_POINT_2F" =>
            return "Windows.Foundation.Numerics.Vector2"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_VECTOR_2F" =>
            return "Windows.Foundation.Numerics.Vector2"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_VECTOR_4F" =>
            return "Windows.Foundation.Numerics.Vector4"
        case _ => return fullName
    }
}

func resolveRelativeTypeFullName(
    ownerFullName: String,
    name: String,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    var current = ownerFullName
    while (!current.isEmpty()) {
        let candidate = "${current}.${name}"
        match (symbolsByName.get(candidate)) {
            case Some(_) => return Some(candidate)
            case None => ()
        }
        current = parentFullName(current)
    }
    return None
}

func parentFullName(fullName: String): String {
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

func primitiveCjType(name: String): String {
    match (name) {
        case "Boolean" => return "Bool"
        case "Bool" => return "Bool"
        case "Byte" => return "UInt8"
        case "Char" => return "UInt16"
        case "Double" => return "Float64"
        case "Float" => return "Float32"
        case "Float32" => return "Float32"
        case "Float64" => return "Float64"
        case "Int8" => return "Int8"
        case "Int16" => return "Int16"
        case "Int32" => return "Int32"
        case "Int64" => return "Int64"
        case "SByte" => return "Int8"
        case "Single" => return "Float32"
        case "String" => return "CPointer<Unit>"
        case "UInt8" => return "UInt8"
        case "UInt16" => return "UInt16"
        case "UInt32" => return "UInt32"
        case "UInt64" => return "UInt64"
        case "Void" => return "Unit"
        case _ => return "CPointer<Unit>"
    }
}

func systemType(fullName: String): String {
    match (fullName) {
        case "System.Boolean" => return "Bool"
        case "System.Byte" => return "UInt8"
        case "System.Char" => return "UInt16"
        case "System.Double" => return "Float64"
        case "System.Int16" => return "Int16"
        case "System.Int32" => return "Int32"
        case "System.Int64" => return "Int64"
        case "System.IntPtr" => return "CPointer<Unit>"
        case "System.Object" => return "CPointer<Unit>"
        case "System.SByte" => return "Int8"
        case "System.Single" => return "Float32"
        case "System.String" => return "CPointer<Unit>"
        case "System.UInt16" => return "UInt16"
        case "System.UInt32" => return "UInt32"
        case "System.UInt64" => return "UInt64"
        case "System.UIntPtr" => return "CPointer<Unit>"
        case "System.Void" => return "Unit"
        case _ => return "CPointer<Unit>"
    }
}

func cjDefaultValue(typeName: String): String {
    if (typeName == "Bool") {
        return "false"
    }
    if (typeName == "Float32" || typeName == "Float64") {
        return "0.0"
    }
    if (startsWith(typeName, "CPointer<")) {
        return "${typeName}()"
    }
    if (startsWith(typeName, "CFunc<")) {
        return "${typeName}(CPointer<Unit>())"
    }
    if (startsWith(typeName, "VArray<")) {
        match (vArrayElementTypeName(typeName)) {
            case Some(elementType) => return "${typeName}(repeat: ${vArrayRepeatValue(elementType)})"
            case None => return "${typeName}()"
        }
    }
    if (typeName != "Int8" && typeName != "Int16" && typeName != "Int32" &&
        typeName != "Int64" && typeName != "IntNative" && typeName != "UInt8" &&
        typeName != "UInt16" && typeName != "UInt32" && typeName != "UInt64" &&
        typeName != "UIntNative") {
        return "${typeName}()"
    }
    return "0"
}

func vArrayRepeatValue(elementType: String): String {
    match (elementType) {
        case "UInt8" => return "0u8"
        case "UInt16" => return "0u16"
        case "UInt32" => return "0u32"
        case "UInt64" => return "0u64"
        case "UIntNative" => return "0"
        case "Int8" => return "0i8"
        case "Int16" => return "0i16"
        case "Int32" => return "0i32"
        case "Int64" => return "0i64"
        case "IntNative" => return "0"
        case _ => return cjDefaultValue(elementType)
    }
}

func vArrayElementTypeName(typeName: String): Option<String> {
    let bytes = typeName.toArray()
    let prefix = "VArray<"
    let prefixBytes = prefix.toArray()
    if (!startsWith(typeName, prefix)) {
        return None
    }
    var i = Int64(prefixBytes.size)
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b',') {
            return Some(String.fromUtf8(bytes[Int64(prefixBytes.size)..i]))
        }
        i += 1
    }
    return None
}

func vArrayCount(typeName: String): Option<Int64> {
    let bytes = typeName.toArray()
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'$') {
            let start = i + 1
            var end = start
            while (end < Int64(bytes.size) && bytes[end] >= b'0' && bytes[end] <= b'9') {
                end += 1
            }
            if (end > start) {
                return parseDecimalInt64(String.fromUtf8(bytes[start..end]))
            }
            return None
        }
        i += 1
    }
    return None
}

func parseDecimalInt64(value: String): Option<Int64> {
    let bytes = value.toArray()
    if (bytes.isEmpty()) {
        return None
    }
    var result: Int64 = 0
    for (byte in bytes) {
        if (byte < b'0' || byte > b'9') {
            return None
        }
        result = result * 10 + Int64(byte - b'0')
    }
    return Some(result)
}

func literalValue(value: Option<JsonValue>): Option<JsonValue> {
    match (value) {
        case Some(jsonValue) =>
            match (jsonValue.kind()) {
                case JsonKind.JsObject =>
                    match (jsonValue.asObject().get("Value")) {
                        case Some(inner) => return Some(inner)
                        case None => return Some(jsonValue)
                    }
                case _ => return Some(jsonValue)
            }
        case None => return None
    }
}

func cjLiteral(value: JsonValue, typeName: String): String {
    match (value.kind()) {
        case JsonKind.JsBool =>
            if (value.asBool().getValue()) {
                return "true"
            }
            return "false"
        case JsonKind.JsInt =>
            if (typeName == "Bool") {
                if (value.asInt().getValue() == 0) {
                    return "false"
                }
                return "true"
            }
            return "${value.asInt().getValue()}"
        case JsonKind.JsFloat => return "${value.asFloat().getValue()}"
        case JsonKind.JsString =>
            if (typeName == "String") {
                return "\"${cjStringContent(value.asString().getValue())}\""
            }
            if (typeName == "windows_strings.WideStringFactory") {
                return "windows_strings.wideStringFactory(\"${cjStringContent(value.asString().getValue())}\")"
            }
            if (typeName == "windows_strings.NarrowStringFactory") {
                return "windows_strings.pcstrLiteral(\"${cjStringContent(value.asString().getValue())}\")"
            }
            return value.asString().getValue()
        case _ => return cjDefaultValue(typeName)
    }
}

func cjLiteralInt(value: String, typeName: String): String {
    return value
}

func cjIdentifier(value: String): String {
    return facadeShortName(value)
}

func cjStringContent(value: String): String {
    let bytes = value.toArray()
    var result = ""
    for (byte in bytes) {
        if (byte == b'\\') {
            result += "\\\\"
        } else if (byte == b'"') {
            result += "\\\""
        } else if (byte == b'$') {
            result += "\\$"
        } else if (byte == b'\n') {
            result += "\\n"
        } else if (byte == b'\r') {
            result += "\\r"
        } else {
            result += String.fromUtf8([byte])
        }
    }
    return result
}

func startsWith(value: String, prefix: String): Bool {
    let valueBytes = value.toArray()
    let prefixBytes = prefix.toArray()
    if (prefixBytes.size > valueBytes.size) {
        return false
    }
    var i: Int64 = 0
    while (i < Int64(prefixBytes.size)) {
        if (valueBytes[i] != prefixBytes[i]) {
            return false
        }
        i += 1
    }
    return true
}
