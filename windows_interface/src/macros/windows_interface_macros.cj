macro package windows_interface.macros

import std.ast.*
import std.collection.ArrayList

class AbiParam {
    let name: String
    let typeName: String
    let cleanupKind: String

    init(name: String, typeName: String, cleanupKind: String) {
        this.name = name
        this.typeName = typeName
        this.cleanupKind = cleanupKind
    }
}

class AbiMethod {
    let name: String
    let returnType: String
    let params: Array<AbiParam>

    init(name: String, returnType: String, params: Array<AbiParam>) {
        this.name = name
        this.returnType = returnType
        this.params = params
    }
}

func typeSource(typeNode: TypeNode): String {
    typeNode.toTokens().toString()
}

func parseInterfaceDecl(inputTokens: Tokens): InterfaceDecl {
    match (parseDecl(inputTokens) as InterfaceDecl) {
        case Some(value) => value
        case None =>
            diagReport(
                DiagReportLevel.ERROR,
                inputTokens,
                "@Interface can only be applied to an interface declaration",
                "Place @Interface on an interface declaration"
            )
            InterfaceDecl(quote(interface InvalidInterfaceMacroInput {}))
    }
}

func parseClassDecl(inputTokens: Tokens): ClassDecl {
    match (parseDecl(inputTokens) as ClassDecl) {
        case Some(value) => value
        case None =>
            diagReport(
                DiagReportLevel.ERROR,
                inputTokens,
                "@Implement can only be applied to a class declaration",
                "Place @Implement on a class declaration"
            )
            ClassDecl(quote(class InvalidImplementMacroInput {}))
    }
}

func directBaseName(interfaceDecl: InterfaceDecl): String {
    if (interfaceDecl.superTypes.size == 0) {
        return "IUnknown"
    }
    if (interfaceDecl.superTypes.size > 1) {
        diagReport(
            DiagReportLevel.ERROR,
            interfaceDecl.superTypes.toTokens(),
            "@Interface currently supports a single direct base interface",
            "Use one direct base interface"
        )
    }
    interfaceDecl.superTypes[0].toTokens().toString()
}

func interfaceCleanupValue(cleanupSpecs: String, methodName: String, paramName: String): String {
    let key = "${methodName}.${paramName}="
    let bytes = cleanupSpecs.toArray()
    let keyBytes = key.toArray()
    let keySize = Int64(keyBytes.size)
    var index: Int64 = 0
    while (index + keySize <= Int64(bytes.size)) {
        var matched = true
        var keyIndex: Int64 = 0
        while (keyIndex < keySize) {
            if (bytes[index + keyIndex] != keyBytes[keyIndex]) {
                matched = false
                break
            }
            keyIndex += 1
        }
        if (matched) {
            let valueStart = index + keySize
            var valueEnd = valueStart
            while (valueEnd < Int64(bytes.size) && bytes[valueEnd] != b';' && bytes[valueEnd] != b'"') {
                valueEnd += 1
            }
            return String.fromUtf8(bytes[valueStart..valueEnd])
        }
        index += 1
    }
    ""
}

func interfaceCleanupKind(cleanupSpecs: String, methodName: String, paramName: String): String {
    let cleanupValue = interfaceCleanupValue(cleanupSpecs, methodName, paramName)
    if (cleanupValue == "HString" || cleanupValue == "Com") {
        return cleanupValue
    }
    if (cleanupValue.startsWith("Array<") && cleanupValue.endsWith(">")) {
        return cleanupValue
    }
    ""
}

func parseMethod(funcDecl: FuncDecl, cleanupSpecs: String): AbiMethod {
    let params = ArrayList<AbiParam>()
    let methodName = funcDecl.identifier.value
    for (param in funcDecl.funcParams) {
        let paramName = param.identifier.value
        params.add(AbiParam(
            paramName,
            typeSource(param.paramType),
            interfaceCleanupKind(cleanupSpecs, methodName, paramName)
        ))
    }
    let returnType = typeSource(funcDecl.declType)
    if (returnType != "Int32") {
        diagReport(
            DiagReportLevel.ERROR,
            funcDecl.declType.toTokens(),
            "@Interface methods currently use raw ABI methods that return Int32",
            "Change the method return type to Int32"
        )
    }
    AbiMethod(methodName, returnType, params.toArray())
}

func parseMethods(interfaceDecl: InterfaceDecl, cleanupSpecs: String): Array<AbiMethod> {
    let methods = ArrayList<AbiMethod>()
    for (decl in interfaceDecl.body.decls) {
        match (decl as FuncDecl) {
            case Some(funcDecl) => methods.add(parseMethod(funcDecl, cleanupSpecs))
            case None =>
                diagReport(
                    DiagReportLevel.ERROR,
                    decl.toTokens(),
                    "@Interface bodies currently support function declarations only",
                    "Remove this declaration from the interface body"
                )
        }
    }
    methods.toArray()
}

func appendComma(sb: StringBuilder, index: Int64): Unit {
    if (index > 0) {
        sb.append(", ")
    }
}

func appendParamDecls(sb: StringBuilder, params: Array<AbiParam>): Unit {
    var index: Int64 = 0
    while (index < params.size) {
        appendComma(sb, index)
        sb.append(params[index].name)
        sb.append(": ")
        sb.append(params[index].typeName)
        index += 1
    }
}

func appendParamTypes(sb: StringBuilder, params: Array<AbiParam>, includeInstance: Bool): Unit {
    var written: Int64 = 0
    if (includeInstance) {
        sb.append("CPointer<Unit>")
        written = 1
    }
    var index: Int64 = 0
    while (index < params.size) {
        appendComma(sb, written)
        sb.append(params[index].typeName)
        written += 1
        index += 1
    }
}

func appendClosurePlaceholders(sb: StringBuilder, params: Array<AbiParam>): Unit {
    sb.append("_")
    var index: Int64 = 0
    while (index < params.size) {
        sb.append(", _")
        index += 1
    }
}

func appendDefaultVtblClosureParams(sb: StringBuilder, params: Array<AbiParam>): Unit {
    sb.append("_")
    for (param in params) {
        sb.append(", ")
        sb.append(param.name)
    }
}

func appendThunkArgs(sb: StringBuilder, params: Array<AbiParam>): Unit {
    var index: Int64 = 0
    while (index < params.size) {
        appendComma(sb, index)
        sb.append(params[index].name)
        index += 1
    }
}

func substringBetween(value: String, start: Int64, end: Int64): String {
    let arr = value.toArray()
    let boundedEnd = if (end > Int64(arr.size)) {
        Int64(arr.size)
    } else {
        end
    }
    if (start >= boundedEnd) {
        return ""
    }
    String.fromUtf8(arr[start..boundedEnd])
}

func compactTypeName(value: String): String {
    let compact = ArrayList<Byte>()
    for (byte in value.toArray()) {
        if (!isAttrWhitespace(byte)) {
            compact.add(byte)
        }
    }
    String.fromUtf8(compact.toArray())
}

func unwrapGenericType(value: String, wrapperName: String): Option<String> {
    let compactValue = compactTypeName(value)
    let prefix = "${wrapperName}<"
    if (!compactValue.startsWith(prefix) || !compactValue.endsWith(">")) {
        return None
    }
    let prefixLen = Int64(prefix.toArray().size)
    let end = Int64(compactValue.toArray().size) - 1
    Some(substringBetween(compactValue, prefixLen, end))
}

func defaultOutSlotValueExpr(typeName: String): String {
    if (typeName == "Bool") {
        return "false"
    }
    if (typeName == "Int8") {
        return "0i8"
    }
    if (typeName == "Int16") {
        return "0i16"
    }
    if (typeName == "Int32") {
        return "0i32"
    }
    if (typeName == "Int64") {
        return "0i64"
    }
    if (typeName == "UInt8" || typeName == "Byte") {
        return "0u8"
    }
    if (typeName == "UInt16") {
        return "0u16"
    }
    if (typeName == "UInt32") {
        return "0u32"
    }
    if (typeName == "UInt64") {
        return "0u64"
    }
    if (typeName == "Float32") {
        return "0.0f32"
    }
    if (typeName == "Float64") {
        return "0.0"
    }
    "${typeName}()"
}

func hasPointerSizeOutParam(method: AbiMethod, paramName: String): Bool {
    for (candidate in method.params) {
        if (candidate.name == "${paramName}Size" && candidate.typeName == "CPointer<UInt32>") {
            return true
        }
    }
    false
}

func isLikelyOutSlotParam(method: AbiMethod, param: AbiParam, valueType: String): Bool {
    if (valueType == "Unit") {
        return false
    }
    if (!param.cleanupKind.isEmpty()) {
        return true
    }
    let name = param.name
    if (
        name == "result" ||
        name == "value" ||
        name == "innerInterface" ||
        name == "object" ||
        name == "instance" ||
        name == "className" ||
        name == "trustLevel" ||
        name == "iidCount" ||
        name == "iids" ||
        name == "index" ||
        name == "cookie" ||
        name == "token" ||
        name == "first" ||
        name == "second"
    ) {
        return true
    }
    if (name.endsWith("Size") && param.typeName == "CPointer<UInt32>") {
        return true
    }
    if (hasPointerSizeOutParam(method, name)) {
        return true
    }
    false
}

func outSlotDefaultExpr(method: AbiMethod, param: AbiParam): Option<String> {
    match (unwrapGenericType(param.typeName, "CPointer")) {
        case Some(valueType) =>
            if (isLikelyOutSlotParam(method, param, valueType)) {
                return Some(defaultOutSlotValueExpr(valueType))
            }
        case None => ()
    }
    None
}

func methodParamType(method: AbiMethod, paramName: String): Option<String> {
    for (candidate in method.params) {
        if (candidate.name == paramName) {
            return Some(candidate.typeName)
        }
    }
    None
}

func appendVtblNoneBranchOutSlotClears(sb: StringBuilder, method: AbiMethod): Unit {
    appendVtblOutSlotClears(sb, method, "                    ")
}

func appendVtblOutSlotClears(sb: StringBuilder, method: AbiMethod, indent: String): Unit {
    for (param in method.params) {
        match (outSlotDefaultExpr(method, param)) {
            case Some(defaultExpr) =>
                sb.append(indent)
                sb.append("if (")
                sb.append(param.name)
                sb.append(".isNotNull()) {\n")
                sb.append(indent)
                sb.append("    unsafe { ")
                sb.append(param.name)
                sb.append(".write(")
                sb.append(defaultExpr)
                sb.append(") }\n")
                sb.append(indent)
                sb.append("}\n")
            case None => ()
        }
    }
}

func methodHasVtblOutSlots(method: AbiMethod): Bool {
    for (param in method.params) {
        match (outSlotDefaultExpr(method, param)) {
            case Some(_) => return true
            case None => ()
        }
    }
    false
}

func appendVtblSomeBranchOutSlotGuard(sb: StringBuilder, method: AbiMethod): Bool {
    var hasOutSlot = false
    for (param in method.params) {
        match (outSlotDefaultExpr(method, param)) {
            case Some(_) =>
                if (hasOutSlot) {
                    sb.append(" || ")
                } else {
                    sb.append("                    if (")
                }
                sb.append(param.name)
                sb.append(".isNull()")
                hasOutSlot = true
            case None => ()
        }
    }
    if (hasOutSlot) {
        sb.append(") {\n")
        appendVtblOutSlotClears(sb, method, "                        ")
        sb.append("                        windows_core.E_POINTER.value\n")
        sb.append("                    } else {\n")
    }
    hasOutSlot
}

func appendVtblFailureArrayOutSlotCleanup(
    sb: StringBuilder,
    method: AbiMethod,
    param: AbiParam,
    elementProjectedType: String,
    indent: String
): Unit {
    let sizeParamName = "${param.name}Size"
    match (methodParamType(method, sizeParamName)) {
        case Some(sizeType) =>
            if (compactTypeName(sizeType) != "CPointer<UInt32>") {
                return
            }
        case None => return
    }
    match (unwrapGenericType(param.typeName, "CPointer")) {
        case Some(dataPointerType) =>
            match (unwrapGenericType(dataPointerType, "CPointer")) {
                case Some(elementAbiType) =>
                    sb.append(indent)
                    sb.append("if (")
                    sb.append(param.name)
                    sb.append(".isNotNull()) {\n")
                    sb.append(indent)
                    sb.append("    var rawSize__ = 0u32\n")
                    sb.append(indent)
                    sb.append("    if (")
                    sb.append(sizeParamName)
                    sb.append(".isNotNull()) {\n")
                    sb.append(indent)
                    sb.append("        rawSize__ = unsafe { ")
                    sb.append(sizeParamName)
                    sb.append(".read() }\n")
                    sb.append(indent)
                    sb.append("    }\n")
                    sb.append(indent)
                    sb.append("    let rawArray__ = unsafe { ")
                    sb.append(param.name)
                    sb.append(".read() }\n")
                    sb.append(indent)
                    sb.append("    if (rawArray__.isNotNull()) {\n")
                    if (elementAbiType == "CPointer<Unit>" && elementProjectedType != "CPointer<Unit>") {
                        sb.append(indent)
                        sb.append("        windows_core.winrtReleaseGenericArrayOut<")
                        sb.append(elementProjectedType)
                        sb.append(">(CPointer<Unit>(rawArray__), rawSize__)\n")
                    } else {
                        sb.append(indent)
                        sb.append("        windows_core.coTaskMemFree(CPointer<Unit>(rawArray__))\n")
                    }
                    sb.append(indent)
                    sb.append("    }\n")
                    sb.append(indent)
                    sb.append("    unsafe { ")
                    sb.append(param.name)
                    sb.append(".write(")
                    sb.append(dataPointerType)
                    sb.append("()) }\n")
                    sb.append(indent)
                    sb.append("}\n")
                    sb.append(indent)
                    sb.append("if (")
                    sb.append(sizeParamName)
                    sb.append(".isNotNull()) {\n")
                    sb.append(indent)
                    sb.append("    unsafe { ")
                    sb.append(sizeParamName)
                    sb.append(".write(0u32) }\n")
                    sb.append(indent)
                    sb.append("}\n")
                case None => ()
            }
        case None => ()
    }
}

func appendVtblFailureOutSlotCleanup(sb: StringBuilder, method: AbiMethod, indent: String): Unit {
    for (param in method.params) {
        match (unwrapGenericType(param.cleanupKind, "Array")) {
            case Some(elementProjectedType) =>
                appendVtblFailureArrayOutSlotCleanup(sb, method, param, elementProjectedType, indent)
            case None => ()
        }
    }
    for (param in method.params) {
        match (unwrapGenericType(param.cleanupKind, "Array")) {
            case Some(_) => ()
            case None =>
                match (outSlotDefaultExpr(method, param)) {
                    case Some(defaultExpr) =>
                        match (unwrapGenericType(param.typeName, "CPointer")) {
                            case Some(valueType) =>
                                if (valueType == "CPointer<Unit>") {
                                    if (param.cleanupKind == "HString" || (param.cleanupKind.isEmpty() && param.name == "className")) {
                                        sb.append(indent)
                                        sb.append("if (")
                                        sb.append(param.name)
                                        sb.append(".isNotNull()) {\n")
                                        sb.append(indent)
                                        sb.append("    let raw__ = unsafe { ")
                                        sb.append(param.name)
                                        sb.append(".read() }\n")
                                        sb.append(indent)
                                        sb.append("    if (raw__.isNotNull()) {\n")
                                        sb.append(indent)
                                        sb.append("        windows_core.releaseSystemHStringHandle(raw__)\n")
                                        sb.append(indent)
                                        sb.append("        unsafe { ")
                                        sb.append(param.name)
                                        sb.append(".write(CPointer<Unit>()) }\n")
                                        sb.append(indent)
                                        sb.append("    }\n")
                                        sb.append(indent)
                                        sb.append("}\n")
                                    } else {
                                        sb.append(indent)
                                        sb.append("windows_core.releaseFailedComOutSlot(")
                                        sb.append(param.name)
                                        sb.append(")\n")
                                    }
                                } else {
                                    sb.append(indent)
                                    sb.append("if (")
                                    sb.append(param.name)
                                    sb.append(".isNotNull()) {\n")
                                    sb.append(indent)
                                    sb.append("    unsafe { ")
                                    sb.append(param.name)
                                    sb.append(".write(")
                                    sb.append(defaultExpr)
                                    sb.append(") }\n")
                                    sb.append(indent)
                                    sb.append("}\n")
                                }
                            case None => ()
                        }
                    case None => ()
                }
        }
    }
}

func isAttrWhitespace(byte: Byte): Bool {
    byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
}

func trimAttrSource(value: String): String {
    let bytes = value.toArray()
    var start: Int64 = 0
    var end = Int64(bytes.size)
    while (start < end && isAttrWhitespace(bytes[start])) {
        start += 1
    }
    while (end > start && isAttrWhitespace(bytes[end - 1])) {
        end -= 1
    }
    String.fromUtf8(bytes[start..end])
}

func attrSourcePart(attrTokens: Tokens, index: Int64): String {
    let bytes = attrTokens.toString().toArray()
    var start: Int64 = 0
    var cursor: Int64 = 0
    var part: Int64 = 0
    var inString = false
    while (cursor < Int64(bytes.size)) {
        let byte = bytes[cursor]
        if (byte == b'"') {
            inString = !inString
        } else if (!inString && byte == b',') {
            if (part == index) {
                return trimAttrSource(String.fromUtf8(bytes[start..cursor]))
            }
            part += 1
            start = cursor + 1
        }
        cursor += 1
    }
    if (part == index) {
        return trimAttrSource(String.fromUtf8(bytes[start..Int64(bytes.size)]))
    }
    ""
}

func attrSourceParts(attrTokens: Tokens): ArrayList<String> {
    let parts = ArrayList<String>()
    let bytes = attrTokens.toString().toArray()
    var start: Int64 = 0
    var cursor: Int64 = 0
    var inString = false
    while (cursor < Int64(bytes.size)) {
        let byte = bytes[cursor]
        if (byte == b'"') {
            inString = !inString
        } else if (!inString && byte == b',') {
            let part = trimAttrSource(String.fromUtf8(bytes[start..cursor]))
            if (!part.isEmpty()) {
                parts.add(part)
            }
            start = cursor + 1
        }
        cursor += 1
    }
    let finalPart = trimAttrSource(String.fromUtf8(bytes[start..Int64(bytes.size)]))
    if (!finalPart.isEmpty()) {
        parts.add(finalPart)
    }
    parts
}

func interfaceRuntimeNameSource(interfaceName: String, attrTokens: Tokens): String {
    let runtimeName = attrSourcePart(attrTokens, 1)
    if (!runtimeName.isEmpty()) {
        return runtimeName
    }
    "\"${interfaceName}\""
}

func runtimeInterfaceName(baseName: String): String {
    if (baseName == "IUnknown" || baseName == "IInspectable") {
        return "windows_interface.${baseName}"
    }
    baseName
}

func runtimeVtblName(baseName: String): String {
    if (baseName == "IUnknown" || baseName == "IInspectable") {
        return "windows_interface.${baseName}Vtbl"
    }
    "${baseName}Vtbl"
}

func appendMethodSchemas(sb: StringBuilder, methods: Array<AbiMethod>): Unit {
    if (methods.size == 0) {
        sb.append("Array<windows_interface.InterfaceMethodSchema>(0, { _ => windows_interface.InterfaceMethodSchema(\"\", 0, Array<windows_interface.InterfaceParameterSchema>(0, { _ => windows_interface.InterfaceParameterSchema(\"\", \"\", \"\", windows_interface.InterfaceParameterBridgeKind.Value) }), \"\") })")
        return
    }

    sb.append("[")
    var methodIndex: Int64 = 0
    while (methodIndex < methods.size) {
        appendComma(sb, methodIndex)
        let method = methods[methodIndex]
        sb.append("windows_interface.InterfaceMethodSchema(\"")
        sb.append(method.name)
        sb.append("\", ")
        appendParamSchemas(sb, method)
        sb.append(", \"")
        sb.append(method.returnType)
        sb.append("\")")
        methodIndex += 1
    }
    sb.append("]")
}

func appendParamSchemas(sb: StringBuilder, method: AbiMethod): Unit {
    let params = method.params
    if (params.size == 0) {
        sb.append("Array<windows_interface.InterfaceParameterSchema>(0, { _ => windows_interface.InterfaceParameterSchema(\"\", \"\", \"\", windows_interface.InterfaceParameterBridgeKind.Value) })")
        return
    }

    sb.append("[")
    var index: Int64 = 0
    while (index < params.size) {
        appendComma(sb, index)
        let param = params[index]
        sb.append("windows_interface.InterfaceParameterSchema(\"")
        sb.append(param.name)
        sb.append("\", \"")
        sb.append(param.typeName)
        sb.append("\", \"")
        sb.append(param.typeName)
        sb.append("\", ")
        match (outSlotDefaultExpr(method, param)) {
            case Some(_) => sb.append("windows_interface.InterfaceParameterBridgeKind.OutSlot")
            case None => sb.append("windows_interface.InterfaceParameterBridgeKind.Value")
        }
        sb.append(")")
        index += 1
    }
    sb.append("]")
}

func appendVtblStruct(sb: StringBuilder, interfaceName: String, baseName: String, methods: Array<AbiMethod>): Unit {
    let baseVtblName = runtimeVtblName(baseName)
    let exceptionAlias = "${interfaceName}_ExceptionBase"
    sb.append("type ")
    sb.append(exceptionAlias)
    sb.append(" = Exception\n\n")
    sb.append("@C\n")
    sb.append("public struct ")
    sb.append(interfaceName)
    sb.append("Vtbl {\n")
    sb.append("    public var base_: ")
    sb.append(baseVtblName)
    sb.append(" = ")
    sb.append(baseVtblName)
    sb.append("()\n")

    for (method in methods) {
        sb.append("    public var ")
        sb.append(method.name)
        sb.append(": CFunc<(")
        appendParamTypes(sb, method.params, true)
        sb.append(") -> Int32> = ")
        if (methodHasVtblOutSlots(method)) {
            sb.append("{ ")
            appendDefaultVtblClosureParams(sb, method.params)
            sb.append(" =>\n")
            appendVtblOutSlotClears(sb, method, "        ")
            sb.append("        windows_core.E_NOTIMPL.value\n")
            sb.append("    }\n")
        } else {
            sb.append("{ ")
            appendClosurePlaceholders(sb, method.params)
            sb.append(" => windows_core.E_NOTIMPL.value }\n")
        }
    }

    sb.append("\n    public init() {}\n\n")
    sb.append("    public static func new(offset!: Int64 = 0): ")
    sb.append(interfaceName)
    sb.append("Vtbl {\n")
    sb.append("        let _ = offset\n")
    sb.append("        var vtbl = ")
    sb.append(interfaceName)
    sb.append("Vtbl()\n")
    sb.append("        vtbl.base_ = ")
    if (baseName == "IUnknown") {
        sb.append("windows_core.buildIUnknownVtbl()")
    } else if (baseName == "IInspectable") {
        sb.append("windows_core.buildIInspectableVtbl()")
    } else {
        sb.append(baseName)
        sb.append("Vtbl.new()")
    }
    sb.append("\n")

    for (method in methods) {
        sb.append("        vtbl.")
        sb.append(method.name)
        sb.append(" = { instanceRaw")
        for (param in method.params) {
            sb.append(", ")
            sb.append(param.name)
        }
        sb.append(" =>\n")
        sb.append("            match (unsafe { windows_core.asImplFromRaw<")
        sb.append(interfaceName)
        sb.append("_ImplErased>(instanceRaw) }) {\n")
        sb.append("                case Some(impl) =>\n")
        let hasOutSlotGuard = appendVtblSomeBranchOutSlotGuard(sb, method)
        let bodyIndent = if (hasOutSlotGuard) {
            "                        "
        } else {
            "                    "
        }
        appendVtblOutSlotClears(sb, method, bodyIndent)
        sb.append(bodyIndent)
        sb.append("try {\n")
        sb.append(bodyIndent)
        sb.append("    let resultHr__ = impl.__winrtThunk_")
        sb.append(method.name)
        sb.append("(")
        appendThunkArgs(sb, method.params)
        sb.append(")\n")
        sb.append(bodyIndent)
        sb.append("    if (windows_core.HRESULT(resultHr__).failed()) {\n")
        appendVtblFailureOutSlotCleanup(sb, method, bodyIndent + "        ")
        sb.append(bodyIndent)
        sb.append("    }\n")
        sb.append(bodyIndent)
        sb.append("    resultHr__\n")
        sb.append(bodyIndent)
        sb.append("} catch (error: windows_core.WindowsException) {\n")
        appendVtblFailureOutSlotCleanup(sb, method, bodyIndent + "    ")
        sb.append(bodyIndent)
        sb.append("    error.code().value\n")
        sb.append(bodyIndent)
        sb.append("} catch (_: ")
        sb.append(exceptionAlias)
        sb.append(") {\n")
        appendVtblFailureOutSlotCleanup(sb, method, bodyIndent + "    ")
        sb.append(bodyIndent)
        sb.append("    windows_core.E_FAIL.value\n")
        sb.append(bodyIndent)
        sb.append("}\n")
        if (hasOutSlotGuard) {
            sb.append("                    }\n")
        }
        sb.append("                case None =>\n")
        appendVtblNoneBranchOutSlotClears(sb, method)
        sb.append("                    windows_core.E_NOINTERFACE.value\n")
        sb.append("            }\n")
        sb.append("        }\n")
    }

    sb.append("        vtbl\n")
    sb.append("    }\n\n")
    sb.append("}\n\n")
}

func appendImplSurfaces(sb: StringBuilder, interfaceName: String, baseName: String, methods: Array<AbiMethod>): Unit {
    sb.append("public interface ")
    sb.append(interfaceName)
    sb.append("_ImplErased {\n")
    for (method in methods) {
        sb.append("    func ")
        sb.append(method.name)
        sb.append("(")
        appendParamDecls(sb, method.params)
        sb.append("): Int32\n")
        sb.append("    func __winrtThunk_")
        sb.append(method.name)
        sb.append("(")
        appendParamDecls(sb, method.params)
        sb.append("): Int32 {\n")
        sb.append("        this.")
        sb.append(method.name)
        sb.append("(")
        appendThunkArgs(sb, method.params)
        sb.append(")\n")
        sb.append("    }\n")
    }
    sb.append("}\n\n")

    sb.append("public interface ")
    sb.append(interfaceName)
    sb.append("_Impl <: ")
    sb.append(interfaceName)
    sb.append("_ImplErased")
    if (baseName != "IUnknown" && baseName != "IInspectable") {
        sb.append(" & ")
        sb.append(baseName)
        sb.append("_Impl")
    }
    sb.append(" {}\n\n")
}

func appendWrapperClass(
    sb: StringBuilder,
    interfaceName: String,
    baseName: String,
    iidSource: String,
    runtimeNameSource: String,
    methods: Array<AbiMethod>
): Unit {
    let baseInterfaceName = runtimeInterfaceName(baseName)
    sb.append("func take")
    sb.append(interfaceName)
    sb.append("FromAbi(raw: CPointer<Unit>): ")
    sb.append(interfaceName)
    sb.append(" {\n")
    sb.append("    ")
    sb.append(interfaceName)
    sb.append(".fromAbiTake(raw)\n")
    sb.append("}\n\n")

    sb.append("func view")
    sb.append(interfaceName)
    sb.append("(raw: CPointer<Unit>): ")
    sb.append(interfaceName)
    sb.append(" {\n")
    sb.append("    ")
    sb.append(interfaceName)
    sb.append(".viewOf(raw)\n")
    sb.append("}\n\n")

    sb.append("public open class ")
    sb.append(interfaceName)
    sb.append(" <: windows_interface.InterfaceWrapperBase & windows_interface.ComInterface & windows_core.RuntimeName & windows_interface.DescriptorSchemaProvider {\n")
    sb.append("    public init(raw: CPointer<Unit>) {\n")
    sb.append("        super(raw)\n")
    sb.append("    }\n\n")
    sb.append("    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {\n")
    sb.append("        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)\n")
    sb.append("    }\n\n")
    sb.append("    public static func fromAbiTake(raw: CPointer<Unit>): ")
    sb.append(interfaceName)
    sb.append(" {\n")
    sb.append("        Owned")
    sb.append(interfaceName)
    sb.append("(raw)\n")
    sb.append("    }\n\n")
    sb.append("    public static func viewOf(raw: CPointer<Unit>): ")
    sb.append(interfaceName)
    sb.append(" {\n")
    sb.append("        ")
    sb.append(interfaceName)
    sb.append("(raw, takeOwnership: false, allowManualRelease: false)\n")
    sb.append("    }\n\n")
    sb.append("    public static func iid(): windows_interface.GUID {\n")
    sb.append("        windows_interface.GUID.parse(")
    sb.append(iidSource)
    sb.append(")\n")
    sb.append("    }\n\n")
    sb.append("    public static func descriptor(): windows_interface.InterfaceDescriptor<")
    sb.append(interfaceName)
    sb.append("> {\n")
    sb.append("        windows_interface.InterfaceDescriptor<")
    sb.append(interfaceName)
    sb.append(">(")
    sb.append(runtimeNameSource)
    sb.append(", iid(), ")
    sb.append(baseInterfaceName)
    sb.append(".descriptor(), take")
    sb.append(interfaceName)
    sb.append("FromAbi, view")
    sb.append(interfaceName)
    sb.append(", ownMethodCount: ")
    sb.append(methods.size.toString())
    sb.append(")\n")
    sb.append("    }\n\n")
    sb.append("    public static func descriptorSchema(): windows_interface.InterfaceDescriptorSchema {\n")
    sb.append("        windows_interface.InterfaceDescriptorSchema(")
    sb.append(runtimeNameSource)
    sb.append(", iid(), ")
    sb.append(baseInterfaceName)
    sb.append(".descriptorSchema(), \"")
    sb.append(interfaceName)
    sb.append("Vtbl\", \"")
    sb.append(interfaceName)
    sb.append("\", \"")
    sb.append(interfaceName)
    sb.append("_Impl\", ")
    appendMethodSchemas(sb, methods)
    sb.append(")\n")
    sb.append("    }\n\n")
    sb.append("    public static let VTABLE: ")
    sb.append(interfaceName)
    sb.append("Vtbl = ")
    sb.append(interfaceName)
    sb.append("Vtbl.new()\n\n")
    sb.append("    public static let VTABLE_HANDLE: CPointer<")
    sb.append(interfaceName)
    sb.append("Vtbl> = unsafe { windows_interface.allocateNativeValue<")
    sb.append(interfaceName)
    sb.append("Vtbl>(VTABLE) }\n\n")
    sb.append("    public static func vtablePtr(): CPointer<Unit> {\n")
    sb.append("        CPointer<Unit>(VTABLE_HANDLE)\n")
    sb.append("    }\n\n")
    sb.append("    public static func runtimeName(): String {\n")
    sb.append("        return ")
    sb.append(runtimeNameSource)
    sb.append("\n")
    sb.append("    }\n\n")
    sb.append("    public static func projectionKind(): String {\n")
    sb.append("        return \"interface\"\n")
    sb.append("    }\n\n")
    sb.append("    public unsafe func vtbl(): ")
    sb.append(interfaceName)
    sb.append("Vtbl {\n")
    sb.append("        readVtbl<")
    sb.append(interfaceName)
    sb.append("Vtbl>(")
    sb.append(interfaceName)
    sb.append("Vtbl())\n")
    sb.append("    }\n\n")

    for (method in methods) {
        sb.append("    public unsafe func ")
        sb.append(method.name)
        sb.append("(")
        appendParamDecls(sb, method.params)
        sb.append("): windows_core.HRESULT {\n")
        sb.append("        let liveRaw__ = asRaw()\n")
        sb.append("        if (liveRaw__.isNull()) {\n")
        sb.append("            return windows_core.E_POINTER\n")
        sb.append("        }\n")
        sb.append("        let vt__ = vtbl()\n")
        sb.append("        windows_core.HRESULT(vt__.")
        sb.append(method.name)
        sb.append("(liveRaw__")
        if (method.params.size > 0) {
            sb.append(", ")
            appendThunkArgs(sb, method.params)
        }
        sb.append("))\n")
        sb.append("    }\n\n")
    }

    if (baseName != "IUnknown") {
        sb.append("    public func as")
        sb.append(baseName)
        sb.append("(): ")
        sb.append(baseInterfaceName)
        sb.append(" {\n")
        sb.append("        ")
        sb.append(baseInterfaceName)
        sb.append(".viewOf(asRaw())\n")
        sb.append("    }\n\n")
    }
    sb.append("}\n\n")

    sb.append("extend ")
    sb.append(interfaceName)
    sb.append(" <: windows_core.Interface<")
    sb.append(interfaceName)
    sb.append("> {}\n\n")

    sb.append("private class Owned")
    sb.append(interfaceName)
    sb.append(" <: ")
    sb.append(interfaceName)
    sb.append(" {\n")
    sb.append("    public init(raw: CPointer<Unit>) {\n")
    sb.append("        super(raw, takeOwnership: true, allowManualRelease: false)\n")
    sb.append("    }\n")
    sb.append("}\n\n")
}

public macro Interface(attrTokens: Tokens, inputTokens: Tokens): Tokens {
    if (attrTokens.size == 0) {
        diagReport(
            DiagReportLevel.ERROR,
            inputTokens,
            "@Interface requires an IID string in square brackets",
            "Use @Interface[\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"]"
        )
        return inputTokens
    }

    let interfaceDecl = parseInterfaceDecl(inputTokens)
    let interfaceName = interfaceDecl.identifier.value
    let baseName = directBaseName(interfaceDecl)
    let iidSource = attrSourcePart(attrTokens, 0)
    let runtimeNameSource = interfaceRuntimeNameSource(interfaceName, attrTokens)
    let cleanupSpecs = attrSourcePart(attrTokens, 2)
    let methods = parseMethods(interfaceDecl, cleanupSpecs)

    let sb = StringBuilder()
    appendVtblStruct(sb, interfaceName, baseName, methods)
    appendImplSurfaces(sb, interfaceName, baseName, methods)
    appendWrapperClass(sb, interfaceName, baseName, iidSource, runtimeNameSource, methods)
    cangjieLex(sb.toString())
}

public macro Implement(attrTokens: Tokens, inputTokens: Tokens): Tokens {
    if (attrTokens.size == 0) {
        diagReport(
            DiagReportLevel.ERROR,
            inputTokens,
            "@Implement requires one interface type in square brackets",
            "Use @Implement[IMyInterface]"
        )
        return inputTokens
    }

    let interfaceNames = attrSourceParts(attrTokens)
    let classDecl = parseClassDecl(inputTokens)
    let className = classDecl.identifier.value

    if (interfaceNames.size == 0) {
        diagReport(
            DiagReportLevel.ERROR,
            attrTokens,
            "@Implement requires at least one interface type",
            "Use @Implement[IMyInterface]"
        )
        return inputTokens
    }

    if (classDecl.superTypes.size == 0) {
        classDecl.upperBound = Token(TokenKind.UPPERBOUND, "<:")
    }
    for (interfaceName in interfaceNames) {
        classDecl.superTypes.add(RefType(cangjieLex(interfaceName + "_Impl")))
    }

    let sb = StringBuilder()
    sb.append("\nextend ")
    sb.append(className)
    sb.append(" {\n")
    sb.append("    public func toComObject(agile!: Bool = true): windows_core.ComObject<")
    sb.append(className)
    sb.append("> {\n")
    sb.append("        windows_core.createImplementedComObject(this, ")
    if (interfaceNames.size == 1) {
        let interfaceName = interfaceNames[0]
        sb.append(interfaceName)
        sb.append(".descriptorSchema(), ")
        sb.append(interfaceName)
        sb.append(".vtablePtr(), agile: agile)\n")
    } else {
        sb.append("[")
        var index: Int64 = 0
        while (index < Int64(interfaceNames.size)) {
            appendComma(sb, index)
            sb.append(interfaceNames[index])
            sb.append(".descriptorSchema()")
            index += 1
        }
        sb.append("], [")
        index = 0
        while (index < Int64(interfaceNames.size)) {
            appendComma(sb, index)
            sb.append(interfaceNames[index])
            sb.append(".vtablePtr()")
            index += 1
        }
        sb.append("], agile: agile)\n")
    }
    sb.append("    }\n")
    sb.append("}\n")

    classDecl.toTokens() + cangjieLex(sb.toString())
}
