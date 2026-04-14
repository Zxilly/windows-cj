package windows_implement

func thunkName(descriptor: ResolvedDescriptor, method: InterfaceMethodSchema): String {
    "${descriptor.name}_${method.name}Thunk"
}

func appendThunkSignature(
    sb: StringBuilder,
    descriptor: ResolvedDescriptor,
    method: InterfaceMethodSchema
): Unit {
    sb.append(thunkName(descriptor, method))
    sb.append("(")
    sb.append("instanceRaw: CPointer<Unit>")
    for (parameter in method.parameters) {
        sb.append(", ")
        if (isResultBridgeParameter(parameter)) {
            sb.append("result__")
        } else {
            sb.append(parameter.name)
        }
        sb.append(": ")
        sb.append(parameter.abiType)
    }
    sb.append("): ")
    sb.append(method.returnType)
}

func appendThunkFuncType(sb: StringBuilder, method: InterfaceMethodSchema): Unit {
    sb.append("CFunc<(CPointer<Unit>")
    for (parameter in method.parameters) {
        sb.append(", ")
        sb.append(parameter.abiType)
    }
    sb.append(") -> ")
    sb.append(method.returnType)
    sb.append(">")
}

func appendGuidLiteral(sb: StringBuilder, guid: GUID): Unit {
    sb.append("GUID.parse(\"")
    sb.append(guid.toString())
    sb.append("\")")
}

func appendGuidArrayLiteral(sb: StringBuilder, values: Array<GUID>): Unit {
    sb.append("[")
    var index: Int64 = 0
    while (index < values.size) {
        if (index > 0) {
            sb.append(", ")
        }
        appendGuidLiteral(sb, values[index])
        index += 1
    }
    sb.append("]")
}

func appendRuntimeTypeLiteral(sb: StringBuilder, contract: RuntimeTypeContract): Unit {
    match (contract.defaultInterfaceIid) {
        case Some(defaultInterfaceIid) =>
            sb.append("RuntimeTypeContract(\"")
            sb.append(contract.runtimeName)
            sb.append("\", \"")
            sb.append(contract.signature)
            sb.append("\", ")
            appendGuidLiteral(sb, defaultInterfaceIid)
            sb.append(")")
        case None =>
            sb.append("RuntimeTypeContract(\"")
            sb.append(contract.runtimeName)
            sb.append("\", \"")
            sb.append(contract.signature)
            sb.append("\")")
    }
}

func bridgeKindLiteral(kind: InterfaceParameterBridgeKind): String {
    match (kind) {
        case InterfaceParameterBridgeKind.InParam => "InterfaceParameterBridgeKind.InParam"
        case InterfaceParameterBridgeKind.OutSlot => "InterfaceParameterBridgeKind.OutSlot"
        case InterfaceParameterBridgeKind.Value => "InterfaceParameterBridgeKind.Value"
    }
}

func appendMethodSchemaArrayLiteral(sb: StringBuilder, methods: Array<InterfaceMethodSchema>): Unit {
    sb.append("[")
    var index: Int64 = 0
    while (index < methods.size) {
        if (index > 0) {
            sb.append(", ")
        }
        let method = methods[index]
        sb.append("InterfaceMethodSchema(\"")
        sb.append(method.name)
        sb.append("\", ")
        sb.append(method.abiSlot.toString())
        sb.append(", [")
        var paramIndex: Int64 = 0
        while (paramIndex < method.parameters.size) {
            if (paramIndex > 0) {
                sb.append(", ")
            }
            let parameter = method.parameters[paramIndex]
            sb.append("InterfaceParameterSchema(\"")
            sb.append(parameter.name)
            sb.append("\", \"")
            sb.append(parameter.abiType)
            sb.append("\", \"")
            sb.append(parameter.callerType)
            sb.append("\", ")
            sb.append(bridgeKindLiteral(parameter.bridgeKind))
            sb.append(")")
            paramIndex += 1
        }
        sb.append("], \"")
        sb.append(method.returnType)
        sb.append("\")")
        index += 1
    }
    sb.append("]")
}

func defaultFailureReturn(returnType: String): String {
    if (returnType == "Int32") {
        return "E_NOINTERFACE"
    }
    if (returnType == "UInt32") {
        return "0u32"
    }
    if (returnType == "Unit") {
        return "()"
    }
    if (returnType.startsWith("CPointer")) {
        return "${returnType}()"
    }
    "0"
}

func baseVtableTypeName(descriptor: ResolvedDescriptor): String {
    match (descriptor.baseInterfaceName) {
        case Some(name) => "${name}Vtbl"
        case None =>
            if (descriptor.isComInterface) {
                "IUnknownVtbl"
            } else {
                ""
            }
    }
}

func baseVtableBuilderName(descriptor: ResolvedDescriptor): String {
    match (descriptor.baseInterfaceName) {
        case Some(name) => "build${name}Vtbl"
        case None =>
            if (descriptor.isComInterface) {
                "buildIUnknownVtbl"
            } else {
                ""
            }
    }
}

func bridgeArgumentExpr(parameter: InterfaceParameterSchema): String {
    match (parameter.bridgeKind) {
        case InterfaceParameterBridgeKind.InParam => "${parameter.name}.borrow()"
        case InterfaceParameterBridgeKind.OutSlot => "${parameter.name}.borrowMut()"
        case InterfaceParameterBridgeKind.Value => parameter.name
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

func unwrapGenericType(value: String, wrapperName: String): Option<String> {
    let prefix = "${wrapperName}<"
    if (!value.startsWith(prefix) || !value.endsWith(">")) {
        return None
    }
    let prefixLen = Int64(prefix.toArray().size)
    let end = Int64(value.toArray().size) - 1
    Some(substringBetween(value, prefixLen, end))
}

func isResultBridgeParameter(parameter: InterfaceParameterSchema): Bool {
    match (parameter.bridgeKind) {
        case InterfaceParameterBridgeKind.OutSlot => parameter.name == "result"
        case _ => false
    }
}

func resultBridgeParameter(method: InterfaceMethodSchema): Option<InterfaceParameterSchema> {
    if (method.returnType != "Int32" || method.parameters.size == 0) {
        return None
    }
    let candidate = method.parameters[method.parameters.size - 1]
    if (!isResultBridgeParameter(candidate)) {
        return None
    }
    Some(candidate)
}

func hasResultReturnBridge(method: InterfaceMethodSchema): Bool {
    resultBridgeParameter(method).isSome()
}

func visibleParameterCount(method: InterfaceMethodSchema): Int64 {
    if (hasResultReturnBridge(method)) {
        return method.parameters.size - 1
    }
    method.parameters.size
}

func visibleCallerReturnType(method: InterfaceMethodSchema): String {
    match (resultBridgeParameter(method)) {
        case Some(parameter) =>
            match (unwrapGenericType(parameter.callerType, "OutSlot")) {
                case Some(inner) => inner
                case None => method.returnType
            }
        case None => method.returnType
    }
}

func implSurfaceReturnType(method: InterfaceMethodSchema): String {
    match (resultBridgeParameter(method)) {
        case Some(parameter) =>
            match (unwrapGenericType(parameter.callerType, "OutSlot")) {
                case Some(inner) => "windows_result.Result<${inner}>"
                case None => method.returnType
            }
        case None => method.returnType
    }
}

func resultAbiValueType(method: InterfaceMethodSchema): Option<String> {
    match (resultBridgeParameter(method)) {
        case Some(parameter) => unwrapGenericType(parameter.abiType, "CPointer")
        case None => None
    }
}

func resultCallerValueType(method: InterfaceMethodSchema): Option<String> {
    match (resultBridgeParameter(method)) {
        case Some(parameter) => unwrapGenericType(parameter.callerType, "OutSlot")
        case None => None
    }
}

func defaultLocalValueExpr(typeName: String): String {
    if (typeName == "Bool") {
        return "false"
    }
    if (typeName == "Int32") {
        return "0i32"
    }
    if (typeName == "UInt32") {
        return "0u32"
    }
    if (typeName == "Int64") {
        return "0i64"
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
    if (typeName.startsWith("CPointer")) {
        return "${typeName}()"
    }
    "${typeName}()"
}

func callerResultReturnExpr(method: InterfaceMethodSchema, abiValueType: String, valueName: String): String {
    match (resultCallerValueType(method)) {
        case Some(callerType) =>
            if (callerType == abiValueType || callerType.startsWith("CPointer")) {
                return valueName
            }
            if (abiValueType == "CPointer<Unit>") {
                return "${callerType}.fromAbiTake(${valueName})"
            }
            valueName
        case None => valueName
    }
}

func thunkResultWriteExpr(method: InterfaceMethodSchema, abiValueType: String): String {
    match (resultCallerValueType(method)) {
        case Some(callerType) =>
            if (callerType == abiValueType || callerType.startsWith("CPointer")) {
                return "value"
            }
            if (abiValueType == "CPointer<Unit>") {
                return "value.asAbiPointer()"
            }
            "value"
        case None => "value"
    }
}

func appendImplMethodCall(
    sb: StringBuilder,
    receiverName: String,
    method: InterfaceMethodSchema,
    visibleOnly!: Bool = false
): Unit {
    sb.append(receiverName)
    sb.append(".")
    sb.append(method.name)
    sb.append("(")
    let parameterCount = if (visibleOnly) {
        visibleParameterCount(method)
    } else {
        method.parameters.size
    }
    var index: Int64 = 0
    while (index < parameterCount) {
        if (index > 0) {
            sb.append(", ")
        }
        sb.append(method.parameters[index].name)
        index += 1
    }
    sb.append(")")
}

func appendQualifiedImplDispatchOpen(sb: StringBuilder, descriptor: ResolvedDescriptor): Unit {
    sb.append("            match (impl as ")
    sb.append(descriptor.implSurfaceName)
    sb.append(") {\n")
    sb.append("                case Some(qualifiedImpl) =>\n")
}

func appendQualifiedImplDispatchClose(sb: StringBuilder, method: InterfaceMethodSchema): Unit {
    sb.append("                case None =>\n")
    sb.append("                    ")
    sb.append(defaultFailureReturn(method.returnType))
    sb.append("\n")
    sb.append("            }\n")
}

func appendVtblDefinition(sb: StringBuilder, descriptor: ResolvedDescriptor): Unit {
    sb.append("@C\n")
    sb.append("public struct ")
    sb.append(descriptor.vtableTypeName)
    sb.append(" {\n")
    if (descriptor.isComInterface) {
        sb.append("    public var base_: ")
        sb.append(baseVtableTypeName(descriptor))
        sb.append(" = ")
        sb.append(baseVtableTypeName(descriptor))
        sb.append("()\n")
    }
    for (method in descriptor.methods) {
        sb.append("    public var ")
        sb.append(method.name)
        sb.append(": ")
        appendThunkFuncType(sb, method)
        sb.append(" = ")
        sb.append(thunkName(descriptor, method))
        sb.append("\n")
    }
    sb.append("\n")
    sb.append("    public init() {}\n")
    sb.append("}\n")
}

func appendVtblBuilder(sb: StringBuilder, descriptor: ResolvedDescriptor): Unit {
    sb.append("public func build")
    sb.append(descriptor.vtableTypeName)
    sb.append("(): ")
    sb.append(descriptor.vtableTypeName)
    sb.append(" {\n")
    sb.append("    var vtbl = ")
    sb.append(descriptor.vtableTypeName)
    sb.append("()\n")
    if (descriptor.isComInterface) {
        sb.append("    vtbl.base_ = ")
        sb.append(baseVtableBuilderName(descriptor))
        sb.append("()\n")
    }
    for (method in descriptor.methods) {
        sb.append("    vtbl.")
        sb.append(method.name)
        sb.append(" = ")
        sb.append(thunkName(descriptor, method))
        sb.append("\n")
    }
    sb.append("    vtbl\n")
    sb.append("}\n")
}

func appendCallerMethod(sb: StringBuilder, _: ResolvedDescriptor, method: InterfaceMethodSchema): Unit {
    sb.append("    public unsafe func ")
    sb.append(method.name)
    sb.append("(")
    var index: Int64 = 0
    while (index < visibleParameterCount(method)) {
        if (index > 0) {
            sb.append(", ")
        }
        let parameter = method.parameters[index]
        sb.append(parameter.name)
        sb.append(": ")
        sb.append(parameter.callerType)
        index += 1
    }
    sb.append("): ")
    sb.append(visibleCallerReturnType(method))
    sb.append(" {\n")
    sb.append("        let v = vtbl()\n")
    if (hasResultReturnBridge(method)) {
        match (resultAbiValueType(method)) {
            case Some(abiValueType) =>
                sb.append("        var result = ")
                sb.append(defaultLocalValueExpr(abiValueType))
                sb.append("\n")
                sb.append("        let hr = v.")
                sb.append(method.name)
                sb.append("(asRaw()")
                var argIndex: Int64 = 0
                while (argIndex < visibleParameterCount(method)) {
                    sb.append(", ")
                    sb.append(bridgeArgumentExpr(method.parameters[argIndex]))
                    argIndex += 1
                }
                sb.append(", CPointer<")
                sb.append(abiValueType)
                sb.append(">(inout result))\n")
                sb.append("        windows_result.HRESULT(hr).ok()\n")
                sb.append("        return ")
                sb.append(callerResultReturnExpr(method, abiValueType, "result"))
                sb.append("\n")
            case None =>
                sb.append("        return v.")
                sb.append(method.name)
                sb.append("(asRaw())\n")
        }
        sb.append("    }\n\n")
        return
    }
    if (method.returnType == "Unit") {
        sb.append("        v.")
    } else {
        sb.append("        return v.")
    }
    sb.append(method.name)
    sb.append("(asRaw()")
    var argIndex: Int64 = 0
    while (argIndex < method.parameters.size) {
        let parameter = method.parameters[argIndex]
        sb.append(", ")
        sb.append(bridgeArgumentExpr(parameter))
        argIndex += 1
    }
    sb.append(")\n")
    sb.append("    }\n\n")
}

func appendWrapperClass(sb: StringBuilder, descriptor: ResolvedDescriptor): Unit {
    sb.append("public class ")
    sb.append(descriptor.wrapperTypeName)
    sb.append(" <: InterfaceWrapperBase & ComInterface")
    match (descriptor.runtimeTypeContract) {
        case Some(contract) =>
            if (!contract.runtimeName.isEmpty()) {
                sb.append(" & RuntimeName")
            }
        case None => ()
    }
    sb.append(" {\n")
    sb.append("    public init(raw: CPointer<Unit>) {\n")
    sb.append("        super(raw)\n")
    sb.append("    }\n\n")

    sb.append("    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {\n")
    sb.append("        super(raw, takeOwnership: takeOwnership)\n")
    sb.append("    }\n\n")

    sb.append("    public static func viewOf(raw: CPointer<Unit>): ")
    sb.append(descriptor.wrapperTypeName)
    sb.append(" {\n")
    sb.append("        ")
    sb.append(descriptor.wrapperTypeName)
    sb.append("(raw)\n")
    sb.append("    }\n\n")

    sb.append("    public static func fromAbiTake(raw: CPointer<Unit>): ")
    sb.append(descriptor.wrapperTypeName)
    sb.append(" {\n")
    sb.append("        ")
    sb.append(descriptor.wrapperTypeName)
    sb.append("(raw, takeOwnership: true)\n")
    sb.append("    }\n\n")

    sb.append("    public static func iid(): GUID {\n")
    sb.append("        ")
    appendGuidLiteral(sb, descriptor.iid)
    sb.append("\n")
    sb.append("    }\n\n")

    match (descriptor.runtimeTypeContract) {
        case Some(contract) =>
            if (!contract.runtimeName.isEmpty()) {
                sb.append("    public static func runtimeName(): String {\n")
                sb.append("        \"")
                sb.append(contract.runtimeName)
                sb.append("\"\n")
                sb.append("    }\n\n")

                sb.append("    public static func signature(): String {\n")
                sb.append("        \"")
                sb.append(contract.signature)
                sb.append("\"\n")
                sb.append("    }\n\n")

                sb.append("    public static func runtimeType(): RuntimeTypeContract {\n")
                sb.append("        ")
                match (contract.defaultInterfaceIid) {
                    case Some(defaultInterfaceIid) =>
                        sb.append("RuntimeTypeContract(\"")
                        sb.append(contract.runtimeName)
                        sb.append("\", ")
                        sb.append(descriptor.wrapperTypeName)
                        sb.append(".signature(), ")
                        appendGuidLiteral(sb, defaultInterfaceIid)
                        sb.append(")\n")
                    case None =>
                        sb.append("RuntimeTypeContract(\"")
                        sb.append(contract.runtimeName)
                        sb.append("\", ")
                        sb.append(descriptor.wrapperTypeName)
                        sb.append(".signature())\n")
                }
                sb.append("    }\n\n")
            }
        case None => ()
    }

    sb.append("    public static func matches(iid: GUID): Bool {\n")
    sb.append("        if (iid == ")
    sb.append(descriptor.wrapperTypeName)
    sb.append(".iid()) {\n")
    sb.append("            return true\n")
    sb.append("        }\n")
    if (descriptor.ancestorIids.size > 0) {
        sb.append("        for (ancestor in ")
        appendGuidArrayLiteral(sb, descriptor.ancestorIids)
        sb.append(") {\n")
        sb.append("            if (ancestor == iid) {\n")
        sb.append("                return true\n")
        sb.append("            }\n")
        sb.append("        }\n")
    }
    sb.append("        false\n")
    sb.append("    }\n\n")

    sb.append("    public static func descriptor(): InterfaceDescriptor<")
    sb.append(descriptor.wrapperTypeName)
    sb.append("> {\n")
    sb.append("        let methods = ")
    appendMethodSchemaArrayLiteral(sb, descriptor.methods)
    sb.append("\n")
    match (descriptor.baseInterfaceName) {
        case Some(name) =>
            sb.append("        var descriptor = InterfaceDescriptor<")
            sb.append(descriptor.wrapperTypeName)
            sb.append(">(\"")
            sb.append(descriptor.name)
            sb.append("\", ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".iid(), ")
            sb.append(name)
            sb.append(".descriptor(), { raw => ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".fromAbiTake(raw) }, { raw => ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".viewOf(raw) })\n")
        case None =>
            sb.append("        var descriptor = InterfaceDescriptor<")
            sb.append(descriptor.wrapperTypeName)
            sb.append(">(\"")
            sb.append(descriptor.name)
            sb.append("\", ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".iid(), ")
            appendGuidArrayLiteral(sb, descriptor.ancestorIids)
            sb.append(", { raw => ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".fromAbiTake(raw) }, { raw => ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".viewOf(raw) })\n")
    }
    sb.append("        descriptor.methods = methods\n")
    match (descriptor.runtimeTypeContract) {
        case Some(contract) =>
            sb.append("        descriptor.runtimeTypeContract = Some(")
            appendRuntimeTypeLiteral(sb, contract)
            sb.append(")\n")
        case None => ()
    }
    sb.append("        descriptor\n")
    sb.append("    }\n\n")

    sb.append("    public static func descriptorSchema(): InterfaceDescriptorSchema {\n")
    sb.append("        let methods = ")
    appendMethodSchemaArrayLiteral(sb, descriptor.methods)
    sb.append("\n")
    match (descriptor.baseInterfaceName) {
        case Some(name) =>
            sb.append("        var schema = InterfaceDescriptorSchema(\"")
            sb.append(descriptor.name)
            sb.append("\", ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".iid(), ")
            sb.append(name)
            sb.append(".descriptorSchema(), \"")
            sb.append(descriptor.vtableTypeName)
            sb.append("\", \"")
            sb.append(descriptor.wrapperTypeName)
            sb.append("\", \"")
            sb.append(descriptor.implSurfaceName)
            sb.append("\", methods)\n")
        case None =>
            sb.append("        var schema = InterfaceDescriptorSchema(\"")
            sb.append(descriptor.name)
            sb.append("\", ")
            sb.append(descriptor.wrapperTypeName)
            sb.append(".iid(), \"")
            sb.append(descriptor.vtableTypeName)
            sb.append("\", \"")
            sb.append(descriptor.wrapperTypeName)
            sb.append("\", \"")
            sb.append(descriptor.implSurfaceName)
            sb.append("\", methods)\n")
    }
    match (descriptor.runtimeTypeContract) {
        case Some(contract) =>
            sb.append("        schema.runtimeTypeContract = Some(")
            appendRuntimeTypeLiteral(sb, contract)
            sb.append(")\n")
        case None => ()
    }
    sb.append("        schema\n")
    sb.append("    }\n\n")

    sb.append("    public static let VTABLE: ")
    sb.append(descriptor.vtableTypeName)
    sb.append(" = build")
    sb.append(descriptor.vtableTypeName)
    sb.append("()\n\n")

    sb.append("    public static let VTABLE_HANDLE: CPointerHandle<")
    sb.append(descriptor.vtableTypeName)
    sb.append("> = unsafe { acquireArrayRawData(Array<")
    sb.append(descriptor.vtableTypeName)
    sb.append(">(1, { _ => VTABLE })) }\n\n")

    sb.append("    public static func vtablePtr(): CPointer<Unit> {\n")
    sb.append("        CPointer<Unit>(VTABLE_HANDLE.pointer)\n")
    sb.append("    }\n\n")

    if (!descriptor.isComInterface) {
        sb.append("    public static func new<T>(this: T): InterfaceResource<")
        sb.append(descriptor.wrapperTypeName)
        sb.append("> where T <: Object & ")
        sb.append(descriptor.implSurfaceName)
        sb.append(" {\n")
        sb.append("        unsafe {\n")
        sb.append("            createInterfaceResourceFromTarget(descriptor(), this, ")
        sb.append(descriptor.wrapperTypeName)
        sb.append(".vtablePtr())\n")
        sb.append("        }\n")
        sb.append("    }\n\n")
    }

    sb.append("    public unsafe func vtbl(): ")
    sb.append(descriptor.vtableTypeName)
    sb.append(" {\n")
    sb.append("        readVtbl<")
    sb.append(descriptor.vtableTypeName)
    sb.append(">(")
    sb.append(descriptor.vtableTypeName)
    sb.append("())\n")
    sb.append("    }\n\n")

    match (descriptor.baseInterfaceName) {
        case Some(name) =>
            sb.append("    public func as")
            sb.append(name)
            sb.append("(): ")
            sb.append(name)
            sb.append(" {\n")
            sb.append("        ")
            sb.append(name)
            sb.append("(asRaw())\n")
            sb.append("    }\n\n")
        case None => ()
    }

    for (method in descriptor.methods) {
        appendCallerMethod(sb, descriptor, method)
    }

    sb.append("    public func clone(): ")
    sb.append(descriptor.wrapperTypeName)
    sb.append(" {\n")
    sb.append("        let raw = asRaw()\n")
    sb.append("        if (raw.isNotNull()) {\n")
    sb.append("            addRef()\n")
    sb.append("        }\n")
    sb.append("        ")
    sb.append(descriptor.wrapperTypeName)
    sb.append(".fromAbiTake(raw)\n")
    sb.append("    }\n\n")

    sb.append("    public operator func ==(right: ")
    sb.append(descriptor.wrapperTypeName)
    sb.append("): Bool {\n")
    sb.append("        asRaw().toUIntNative() == right.asRaw().toUIntNative()\n")
    sb.append("    }\n\n")

    sb.append("    public func toString(): String {\n")
    sb.append("        \"")
    sb.append(descriptor.wrapperTypeName)
    sb.append("(0x")
    sb.append("$")
    sb.append("{")
    sb.append("asRaw().toUIntNative().toString()")
    sb.append("})\"\n")
    sb.append("    }\n")
    sb.append("}\n")
}

func appendDispatchThunk(sb: StringBuilder, descriptor: ResolvedDescriptor, method: InterfaceMethodSchema): Unit {
    sb.append("@C\n")
    sb.append("public func ")
    appendThunkSignature(sb, descriptor, method)
    sb.append(" {\n")
    if (hasResultReturnBridge(method)) {
        sb.append("    if (result__.isNull()) {\n")
        sb.append("        return E_POINTER\n")
        sb.append("    }\n")
    }
    sb.append("    match (unsafe { asImplFromRaw<")
    sb.append(descriptor.implSurfaceName)
    sb.append(">(instanceRaw")
    if (descriptor.slotIndex > 0) {
        sb.append(", slotOffset: ")
        sb.append(descriptor.slotIndex.toString())
    }
    sb.append(") }) {\n")
    sb.append("        case Some(impl) =>\n")
    if (hasResultReturnBridge(method)) {
        appendQualifiedImplDispatchOpen(sb, descriptor)
        sb.append("                    match (")
        appendImplMethodCall(sb, "qualifiedImpl", method, visibleOnly: true)
        sb.append(") {\n")
        match (resultAbiValueType(method)) {
            case Some(abiValueType) =>
                match (resultCallerValueType(method)) {
                    case Some(callerType) =>
                        sb.append("                        case windows_result.Result<")
                        sb.append(callerType)
                        sb.append(">.Ok(value) =>\n")
                        if (callerType == abiValueType || callerType.startsWith("CPointer")) {
                            sb.append("                            unsafe { result__.write(")
                            sb.append(thunkResultWriteExpr(method, abiValueType))
                            sb.append(") }\n")
                            sb.append("                            S_OK\n")
                        } else if (abiValueType == "CPointer<Unit>") {
                            sb.append("                            let raw = ")
                            sb.append(thunkResultWriteExpr(method, abiValueType))
                            sb.append("\n")
                            sb.append("                            if (raw.isNull()) {\n")
                            sb.append("                                E_POINTER\n")
                            sb.append("                            } else {\n")
                            sb.append("                                unsafe { result__.write(raw) }\n")
                            sb.append("                                S_OK\n")
                            sb.append("                            }\n")
                        } else {
                            sb.append("                            unsafe { result__.write(")
                            sb.append(thunkResultWriteExpr(method, abiValueType))
                            sb.append(") }\n")
                            sb.append("                            S_OK\n")
                        }
                        sb.append("                        case windows_result.Result<")
                        sb.append(callerType)
                        sb.append(">.Err(error) =>\n")
                        sb.append("                            error.code().value\n")
                    case None =>
                        sb.append("                        E_NOINTERFACE\n")
                }
            case None =>
                sb.append("                        E_NOINTERFACE\n")
        }
        sb.append("                    }\n")
        appendQualifiedImplDispatchClose(sb, method)
    } else {
        appendQualifiedImplDispatchOpen(sb, descriptor)
        sb.append("                    ")
        appendImplMethodCall(sb, "qualifiedImpl", method)
        sb.append("\n")
        appendQualifiedImplDispatchClose(sb, method)
    }
    sb.append("        case None =>\n")
    sb.append("            ")
    sb.append(defaultFailureReturn(method.returnType))
    sb.append("\n")
    sb.append("    }\n")
    sb.append("}\n")
}

public func renderDescriptor(descriptor: ResolvedDescriptor): String {
    var sb = StringBuilder()
    sb.append(renderImplSurface(descriptor))
    sb.append("\n\n")
    appendVtblDefinition(sb, descriptor)
    sb.append("\n")
    appendVtblBuilder(sb, descriptor)
    sb.append("\n")
    appendWrapperClass(sb, descriptor)
    for (method in descriptor.methods) {
        sb.append("\n")
        appendDispatchThunk(sb, descriptor, method)
    }
    sb.toString()
}
