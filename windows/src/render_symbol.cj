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

public func renderSymbolImpl(symbol: SymbolRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    if (!symbol.implSource.isEmpty()) {
        return symbol.implSource
    }
    match (symbol.typeDef) {
        case Some(typeDef) =>
            let header = "// ${symbol.fullName} (${symbol.metadataToken})"
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
                match (guidAttributeLiteral(typeDef)) {
                    case Some(guidLiteral) =>
                        return "${header}\n${renderInterfaceSymbol(symbol, typeDef, symbolsByName, guidLiteral)}"
                    case None => ()
                }
                return "${header}\n${renderRawHandleSymbol(symbol, "interface")}"
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
    content += "}"
    return content
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
        "    }\n" +
        "}"
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
    guidLiteral: String
): String {
    var content = renderInterfaceVtblSymbol(symbol, typeDef, symbolsByName)
    content += "\n\n"
    content += "func take${symbol.implName}FromAbi(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "    ${symbol.implName}.fromAbiTake(raw)\n" +
        "}\n\n"
    content += "func view${symbol.implName}(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "    ${symbol.implName}.viewOf(raw)\n" +
        "}\n\n"
    content += "public open class ${symbol.implName} <: windows_core.InterfaceWrapperBase & windows_core.ComInterface & windows_core.RuntimeName {\n"
    content += "    public init(raw: CPointer<Unit>) {\n" +
        "        super(raw)\n" +
        "    }\n\n"
    content += "    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {\n" +
        "        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)\n" +
        "    }\n\n"
    content += "    public static func fromAbiTake(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "        ${symbol.implName}(raw, takeOwnership: true, allowManualRelease: false)\n" +
        "    }\n\n"
    content += "    public static func viewOf(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "        ${symbol.implName}(raw, takeOwnership: false, allowManualRelease: false)\n" +
        "    }\n\n"
    content += "    public static func iid(): windows_core.GUID {\n" +
        "        ${guidLiteral}\n" +
        "    }\n\n"
    content += "    public static func descriptor(): windows_core.InterfaceDescriptor<${symbol.implName}> {\n" +
        "        windows_core.InterfaceDescriptor<${symbol.implName}>(\"${cjStringContent(symbol.fullName)}\", iid(), windows_core.IInspectable.descriptor(), take${symbol.implName}FromAbi, view${symbol.implName})\n" +
        "    }\n\n"
    content += "    public static func runtimeName(): String {\n" +
        "        return \"${cjStringContent(symbol.fullName)}\"\n" +
        "    }\n\n"
    content += "    public static func projectionKind(): String {\n" +
        "        return \"interface\"\n" +
        "    }\n\n"
    content += "    public unsafe func vtbl(): ${symbol.implName}Vtbl {\n" +
        "        readVtbl<${symbol.implName}Vtbl>(${symbol.implName}Vtbl())\n" +
        "    }\n" +
        "}\n\n"
    content += "extend ${symbol.implName} <: windows_core.Interface<${symbol.implName}> {}"
    return content
}

func renderInterfaceVtblSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = "@C\npublic struct ${symbol.implName}Vtbl {\n"
    content += "    public var base_: windows_core.IInspectableVtbl = windows_core.IInspectableVtbl()\n"
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method.name, slotNames)
        slotNames.add(slotName)
        let signature = interfaceMethodCFuncSignature(method, symbolsByName, symbol.fullName)
        let fallback = cFuncFallback(interfaceMethodCFuncArity(method, symbolsByName, symbol.fullName))
        content += "    public var ${slotName}: ${signature} = ${fallback}\n"
    }
    content += "    public init() {}\n" +
        "}"
    return content
}

func interfaceMethodCFuncSignature(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let params = ArrayList<String>()
    params.add("CPointer<Unit>")
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        params.add(interfaceParameterAbiType(signature, metadataParameterAt(metadataParameters, index), symbolsByName, ownerFullName))
        index += 1
    }
    let returnType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
    if (returnType != "Unit") {
        params.add("CPointer<${returnType}>")
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> Int32>"
}

func interfaceMethodCFuncArity(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Int64 {
    var arity: Int64 = 1
    arity += Int64(method.signature.parameters.size)
    let returnType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
    if (returnType != "Unit") {
        arity += 1
    }
    return arity
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
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
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

func cFuncFallback(arity: Int64): String {
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < arity) {
        args.add("_")
        i += 1
    }
    return "{ ${joinStrings(args, ", ")} => -2147467263i32 }"
}

func uniqueInterfaceSlotName(methodName: String, seen: ArrayList<String>): String {
    var base = methodName
    if (startsWith(base, "get_") || startsWith(base, "put_")) {
        base = stripPrefix(base, 4)
    }
    base = cjIdentifier(base)
    var count: Int64 = 0
    for (value in seen) {
        if (value == base || startsWith(value, "${base}_")) {
            count += 1
        }
    }
    if (count == 0) {
        return base
    }
    return "${base}_${count}"
}

func stripPrefix(value: String, count: Int64): String {
    let bytes = value.toArray()
    if (count >= Int64(bytes.size)) {
        return ""
    }
    return String.fromUtf8(bytes[count..Int64(bytes.size)])
}

func guidAttributeLiteral(typeDef: TypeDefinitionRecord): Option<String> {
    for (attr in typeDef.customAttributes) {
        if (attr.typeName == "Windows.Foundation.Metadata.GuidAttribute" &&
            attr.fixedArguments.size >= 11) {
            let values = ArrayList<String>()
            var i: Int64 = 0
            while (i < 11) {
                match (fixedArgumentInt64(attr.fixedArguments[i])) {
                    case Some(value) => values.add(guidLiteralPart(value, i))
                    case None => return None
                }
                i += 1
            }
            return Some("return windows_core.GUID.from_values(${joinStrings(values, ", ")})")
        }
    }
    return None
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

func isPublicInstanceField(field: FieldRecord): Bool {
    return contains(field.attributes, "Public") &&
        !contains(field.attributes, "Static") &&
        !contains(field.attributes, "Literal")
}

func isEnumLiteral(field: FieldRecord): Bool {
    return contains(field.attributes, "Public") &&
        contains(field.attributes, "Static") &&
        contains(field.attributes, "Literal")
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

func cjAbiType(signature: SignatureRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    return cjAbiTypeInContext(signature, symbolsByName, "")
}

func cjAbiTypeInContext(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
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

func signatureFullName(signature: SignatureRecord): Option<String> {
    return signatureFullNameInContext(signature, HashMap<String, SymbolRecord>(), "")
}

func signatureFullNameInContext(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    if (!signature.name.isEmpty() && signature.hasNamespace) {
        if (signature.namespace.isEmpty()) {
            match (resolveRelativeTypeFullName(ownerFullName, signature.name, symbolsByName)) {
                case Some(fullName) => return Some(fullName)
                case None => ()
            }
            return Some(signature.name)
        }
        return Some("${signature.namespace}.${signature.name}")
    }
    match (signature.typeReference) {
        case Some(metadataType) =>
            if (metadataType.namespace.isEmpty()) {
                match (resolveRelativeTypeFullName(ownerFullName, metadataType.name, symbolsByName)) {
                    case Some(fullName) => return Some(fullName)
                    case None => ()
                }
            }
            return Some(metadataType.fullName())
        case None => ()
    }
    match (signature.typeDefinition) {
        case Some(metadataType) =>
            if (metadataType.namespace.isEmpty()) {
                match (resolveRelativeTypeFullName(ownerFullName, metadataType.name, symbolsByName)) {
                    case Some(fullName) => return Some(fullName)
                    case None => ()
                }
            }
            return Some(metadataType.fullName())
        case None => ()
    }
    return None
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
        typeName != "Int64" && typeName != "UInt8" && typeName != "UInt16" &&
        typeName != "UInt32" && typeName != "UInt64") {
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
        case "Int8" => return "0i8"
        case "Int16" => return "0i16"
        case "Int32" => return "0i32"
        case "Int64" => return "0i64"
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
        case JsonKind.JsInt => return "${value.asInt().getValue()}"
        case JsonKind.JsFloat => return "${value.asFloat().getValue()}"
        case JsonKind.JsString =>
            if (typeName == "String") {
                return "\"${cjStringContent(value.asString().getValue())}\""
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
