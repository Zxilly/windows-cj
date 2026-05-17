package windows

import std.collection.*

public class GeneratedNativeHelperFile {
    public let relativePath: String
    public let content: String

    public init(relativePath: String, content: String) {
        this.relativePath = relativePath
        this.content = content
    }
}

class NativeFunctionSpec {
    public let namespace: String
    public let ownerFullName: String
    public let method: MethodRecord
    public let dynamicModuleParameterName: String

    public init(
        namespace: String,
        ownerFullName: String,
        method: MethodRecord,
        dynamicModuleParameterName!: String = ""
    ) {
        this.namespace = namespace
        this.ownerFullName = ownerFullName
        this.method = method
        this.dynamicModuleParameterName = dynamicModuleParameterName
    }
}

class NativeArrayParameterInfo {
    public let index: Int64
    public let lengthIndex: Int64
    public let name: String
    public let elementType: String
    public let handleName: String
    public let fixedLength: Int64

    public init(index: Int64, lengthIndex: Int64, name: String, elementType: String, fixedLength!: Int64 = -1) {
        this.index = index
        this.lengthIndex = lengthIndex
        this.name = name
        this.elementType = elementType
        this.handleName = "__${name}ArrayHandle"
        this.fixedLength = fixedLength
    }
}

class NativeHStringArgumentInfo {
    public let index: Int64
    public let name: String
    public let handleName: String
    public let releaseAfterCall: Bool

    public init(index: Int64, name: String, releaseAfterCall: Bool) {
        this.index = index
        this.name = name
        this.handleName = nativeHStringArgumentHandleName(name)
        this.releaseAfterCall = releaseAfterCall
    }
}

public func commonNativeHelperFiles(
    nativeSymbols: ArrayList<SymbolRecord>,
    packageName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<GeneratedNativeHelperFile> {
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Native/mod.cj", renderNativeParentPackage(packageName)))
    files.add(GeneratedNativeHelperFile(
        "src/Native/AppRuntime/native_helpers.cj",
        renderNativeHelperNamespaceSource(packageName, "Native.AppRuntime", appRuntimeNativeFunctionSpecs(), symbolsByName)
    ))

    let namespaces = ArrayList<String>()
    let specsByNamespace = HashMap<String, ArrayList<NativeFunctionSpec>>()
    for (spec in syntheticCommonNativeFunctionSpecs()) {
        addNativeFunctionSpec(namespaces, specsByNamespace, spec)
    }
    for (spec in nativeFunctionSpecsFromSymbols(nativeSymbols)) {
        addNativeFunctionSpec(namespaces, specsByNamespace, spec)
    }
    sortStrings(namespaces)
    for (namespace in namespaces) {
        let specs = specsByNamespace[namespace]
        if (!specs.isEmpty()) {
            files.add(GeneratedNativeHelperFile(
                "${namespaceToDirectory(namespace)}/native_helpers.cj",
                renderNativeHelperNamespaceSource(packageName, namespace, specs, symbolsByName)
            ))
        }
    }
    return files
}

func addNativeFunctionSpec(
    namespaces: ArrayList<String>,
    specsByNamespace: HashMap<String, ArrayList<NativeFunctionSpec>>,
    spec: NativeFunctionSpec
): Unit {
    addUnique(namespaces, spec.namespace)
    if (!specsByNamespace.contains(spec.namespace)) {
        specsByNamespace.add(spec.namespace, ArrayList<NativeFunctionSpec>())
    }
    if (!containsNativeFunctionSpec(specsByNamespace[spec.namespace], spec.method.name)) {
        specsByNamespace[spec.namespace].add(spec)
    }
}

func containsNativeFunctionSpec(specs: ArrayList<NativeFunctionSpec>, methodName: String): Bool {
    for (spec in specs) {
        if (spec.method.name == methodName) {
            return true
        }
    }
    return false
}

func renderNativeParentPackage(packageName: String): String {
    "package ${packageName}.Native\n"
}

func nativeFunctionSpecsFromSymbols(symbols: ArrayList<SymbolRecord>): ArrayList<NativeFunctionSpec> {
    let specs = ArrayList<NativeFunctionSpec>()
    for (symbol in symbols) {
        match (symbol.typeDef) {
            case Some(typeDef) =>
                if (hasPInvokeMethods(typeDef)) {
                    for (method in typeDef.methods) {
                        match (method.methodImport) {
                            case Some(methodImport) =>
                                if (isResolvableNativeModule(methodImport.moduleName)) {
                                    specs.add(NativeFunctionSpec(symbol.namespace, symbol.fullName, method))
                                }
                            case None => ()
                        }
                    }
                }
            case None => ()
        }
    }
    return specs
}

func isResolvableNativeModule(moduleName: String): Bool {
    moduleName != "FORCEINLINE"
}

func syntheticCommonNativeFunctionSpecs(): ArrayList<NativeFunctionSpec> {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.SystemInformation",
        "Windows.Win32.System.SystemInformation.Apis",
        nativeMethod(
            "RtlGetVersion",
            "RtlGetVersion",
            "ntdll.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed(
                    "info",
                    pointerSignature(typeSignature("Windows.Win32.System.SystemInformation", "OSVERSIONINFOEXW"))
                )
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Kernel",
        "Windows.Win32.System.Kernel.Apis",
        nativeMethod(
            "CreateTransaction",
            "CreateTransaction",
            "ktmw32.dll",
            typeSignature("Windows.Win32.Foundation", "HANDLE"),
            [
                NativeParameterSeed(
                    "lpTransactionAttributes",
                    pointerSignature(typeSignature("Windows.Win32.Security", "SECURITY_ATTRIBUTES"))
                ),
                NativeParameterSeed("uow", pointerSignature(voidSignature())),
                NativeParameterSeed("createOptions", primitiveSignature("UInt32")),
                NativeParameterSeed("isolationLevel", primitiveSignature("UInt32")),
                NativeParameterSeed("isolationFlags", primitiveSignature("UInt32")),
                NativeParameterSeed("timeout", primitiveSignature("UInt32")),
                NativeParameterSeed("description", typeSignature("Windows.Win32.Foundation", "PWSTR"))
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Kernel",
        "Windows.Win32.System.Kernel.Apis",
        nativeMethod(
            "CommitTransaction",
            "CommitTransaction",
            "ktmw32.dll",
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            [
                NativeParameterSeed("transactionHandle", typeSignature("Windows.Win32.Foundation", "HANDLE"))
            ]
        )
    ))
    return specs
}

func appRuntimeNativeFunctionSpecs(): ArrayList<NativeFunctionSpec> {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Native.AppRuntime",
        "Native.AppRuntime.MddBootstrap",
        nativeMethod(
            "MddBootstrapInitialize2",
            "MddBootstrapInitialize2",
            "",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("majorMinorVersion", primitiveSignature("UInt32")),
                NativeParameterSeed("versionTag", pointerSignature(primitiveSignature("UInt16"))),
                NativeParameterSeed("minVersion", primitiveSignature("UInt64")),
                NativeParameterSeed("options", primitiveSignature("UInt32"))
            ]
        ),
        dynamicModuleParameterName: "bootstrapDllPath"
    ))
    specs.add(NativeFunctionSpec(
        "Native.AppRuntime",
        "Native.AppRuntime.MddBootstrap",
        nativeMethod(
            "MddBootstrapShutdown",
            "MddBootstrapShutdown",
            "",
            voidSignature(),
            []
        ),
        dynamicModuleParameterName: "bootstrapDllPath"
    ))
    return specs
}

class NativeParameterSeed {
    public let name: String
    public let signature: SignatureRecord

    public init(name: String, signature: SignatureRecord) {
        this.name = name
        this.signature = signature
    }
}

func nativeMethod(
    methodName: String,
    importName: String,
    moduleName: String,
    returnType: SignatureRecord,
    parameters: Array<NativeParameterSeed>
): MethodRecord {
    let signatureParameters = ArrayList<SignatureRecord>()
    let metadataParameters = ArrayList<ParameterRecord>()
    var index: Int64 = 0
    while (index < Int64(parameters.size)) {
        signatureParameters.add(parameters[index].signature)
        metadataParameters.add(ParameterRecord(parameters[index].name, sequenceNumber: index + 1))
        index += 1
    }
    return MethodRecord(
        methodName,
        MethodSignatureRecord(returnType, parameters: signatureParameters, requiredParameterCount: Int64(parameters.size)),
        parameters: metadataParameters,
        methodImport: Some(MethodImportRecord(importName, moduleName))
    )
}

func primitiveSignature(name: String): SignatureRecord {
    return SignatureRecord("Primitive", name: name)
}

func voidSignature(): SignatureRecord {
    return SignatureRecord("Void")
}

func typeSignature(namespace: String, name: String): SignatureRecord {
    return SignatureRecord("Type", namespace: namespace, name: name, hasNamespace: true)
}

func pointerSignature(inner: SignatureRecord): SignatureRecord {
    return SignatureRecord("Pointer", typeSig: Some(inner))
}

func renderNativeHelperNamespaceSource(
    packageName: String,
    namespace: String,
    specs: ArrayList<NativeFunctionSpec>,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = "package ${namespaceToPackage(namespace, packageName)}\n\n"
    content += "import windows_libloading as windows_libloading\n"
    let imports = nativeHelperImports(packageName, namespace, specs, symbolsByName)
    for (importPath in imports) {
        content += "import ${importPath}\n"
    }
    content += "\n"
    for (spec in specs) {
        content += renderNativeFunction(spec, symbolsByName)
        content += "\n"
    }
    return content
}

func nativeHelperImports(
    packageName: String,
    namespace: String,
    specs: ArrayList<NativeFunctionSpec>,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<String> {
    let imports = ArrayList<String>()
    for (spec in specs) {
        collectNativeTypeImports(packageName, namespace, spec.ownerFullName, spec.method.signature.returnType, symbolsByName, imports)
        for (parameter in spec.method.signature.parameters) {
            collectNativeTypeImports(packageName, namespace, spec.ownerFullName, parameter, symbolsByName, imports)
        }
        let metadataParameters = metadataMethodParameters(spec.method)
        var index: Int64 = 0
        while (index < Int64(spec.method.signature.parameters.size)) {
            collectNativeParameterAttributeImports(
                packageName,
                namespace,
                spec.ownerFullName,
                metadataParameterAt(metadataParameters, index),
                symbolsByName,
                imports
            )
            index += 1
        }
        if (nativeMethodNeedsSetLastErrorCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName)) {
            addUnique(imports, "windows_core as windows_core")
        }
    }
    sortStrings(imports)
    return imports
}

func collectNativeParameterAttributeImports(
    packageName: String,
    namespace: String,
    ownerFullName: String,
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    imports: ArrayList<String>
): Unit {
    match (nativeAssociatedEnumParameterSymbol(parameter, symbolsByName, ownerFullName)) {
        case Some(symbol) =>
            if (symbol.namespace != namespace) {
                addUnique(imports, "${namespaceToPackage(symbol.namespace, packageName)}.${symbol.name}")
            }
        case None => ()
    }
}

func collectNativeTypeImports(
    packageName: String,
    namespace: String,
    ownerFullName: String,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    imports: ArrayList<String>,
    pointerDepth!: Int64 = 0
): Unit {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (nativeBStrPublicType(fullName)) {
                case Some(_) =>
                    if (pointerDepth == 0) {
                        addUnique(imports, "windows_strings as windows_strings")
                    }
                case None => ()
            }
            match (nativeHStringPublicType(fullName)) {
                case Some(_) =>
                    if (pointerDepth == 0) {
                        addUnique(imports, "windows_core as windows_core")
                    }
                case None => ()
            }
            match (nativeComInterfacePublicType(fullName)) {
                case Some(_) =>
                    if (pointerDepth == 0) {
                        addUnique(imports, "windows_interface as windows_interface")
                    }
                case None => ()
            }
            match (nativeTextPointerPublicType(fullName)) {
                case Some(_) =>
                    if (pointerDepth == 0) {
                        addUnique(imports, "windows_strings as windows_strings")
                    }
                case None => ()
            }
            if (isSystemGuidType(fullName)) {
                addUnique(imports, "windows_interface.GUID")
            }
            match (symbolsByName.get(fullName)) {
                case Some(symbol) =>
                    if (symbol.namespace != namespace && nativeNamedTypeUsesFacadeAlias(symbol, symbolsByName)) {
                        addUnique(imports, "${namespaceToPackage(symbol.namespace, packageName)}.${symbol.name}")
                    }
                case None => ()
            }
        case None => ()
    }
    match (signature.typeSig) {
        case Some(nested) =>
            var nextPointerDepth = pointerDepth
            if (signature.kind == "Pointer" || signature.kind == "ByReference") {
                nextPointerDepth += 1
            }
            collectNativeTypeImports(
                packageName,
                namespace,
                ownerFullName,
                nested,
                symbolsByName,
                imports,
                pointerDepth: nextPointerDepth
            )
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) => collectNativeTypeImports(packageName, namespace, ownerFullName, nested, symbolsByName, imports, pointerDepth: pointerDepth)
        case None => ()
    }
    for (argument in signature.typeArguments) {
        collectNativeTypeImports(packageName, namespace, ownerFullName, argument, symbolsByName, imports, pointerDepth: pointerDepth)
    }
}

func nativeNamedTypeUsesFacadeAlias(symbol: SymbolRecord, symbolsByName: HashMap<String, SymbolRecord>): Bool {
    match (nativeTextPointerRawType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (nativeEventRegistrationTokenType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (nativeHResultType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (nativeBStrRawType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (nativeHStringRawType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (nativeComInterfaceRawType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (nativeFoundationCharType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (nativeBooleanRawType(symbol.fullName)) {
        case Some(_) => return false
        case None => ()
    }
    match (symbol.typeDef) {
        case Some(typeDef) =>
            if (isEnumType(typeDef)) {
                return false
            }
            if (isDelegateType(typeDef)) {
                return false
            }
            match (nativeTransparentScalarType(typeDef, symbolsByName, symbol.fullName)) {
                case Some(_) => return false
                case None => ()
            }
            return isValueType(typeDef)
        case None => return true
    }
}

func renderNativeFunction(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let method = spec.method
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, spec.ownerFullName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, spec.ownerFullName)
    let procType = nativeCFuncType(spec, rawReturnType, symbolsByName)
    var content = "public func ${cjIdentifier(method.name)}(${publicParams}): ${returnType} {\n"
    content += "    let proc = ${procType}(${nativeResolveExpression(spec)})\n"
    let args = nativeFunctionArgumentText(spec, symbolsByName)
    let arrayInfos = nativeArrayParameterInfos(spec, symbolsByName)
    let hStringInfos = nativeHStringArgumentInfos(spec, symbolsByName)
    if (arrayInfos.isEmpty() && hStringInfos.isEmpty()) {
        content += renderNativeProcInvocation(returnType, rawReturnType, args, "    ", false)
    } else {
        content += renderNativeArrayLengthChecks(arrayInfos, "    ")
        content += renderNativeHStringArgumentDeclarations(hStringInfos, "    ")
        content += renderNativeArrayAcquisitions(arrayInfos, "    ")
        content += "    try {\n"
        content += renderNativeHStringArgumentAcquisitions(hStringInfos, "        ")
        content += renderNativeProcInvocation(returnType, rawReturnType, args, "        ", true)
        content += "    } finally {\n"
        for (arrayInfo in arrayInfos) {
            content += "        unsafe { releaseArrayRawData(${arrayInfo.handleName}) }\n"
        }
        for (hStringInfo in hStringInfos) {
            if (hStringInfo.releaseAfterCall) {
                content += "        windows_core.releaseSystemHStringHandle(${hStringInfo.handleName})\n"
            }
        }
        content += "    }\n"
    }
    content += "}\n"
    if (nativeMethodNeedsSetLastErrorCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n"
        content += renderNativeSetLastErrorCheckedWrapper(spec, symbolsByName)
    }
    return content
}

func renderNativeSetLastErrorCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): Result<Unit> {\n"
    content += "    if (${methodName}(${args})) {\n"
    content += "        return Result<Unit>.Ok(())\n"
    content += "    }\n"
    content += "    Result<Unit>.Err(windows_core.errorFromThread())\n"
    content += "}\n"
    return content
}

func nativeMethodNeedsSetLastErrorCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, ownerFullName)
    return returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)
}

func nativeMethodSetsLastError(method: MethodRecord): Bool {
    match (method.methodImport) {
        case Some(methodImport) => return contains(methodImport.attributes, "SetLastError")
        case None => return false
    }
}

func renderNativeArrayLengthChecks(infos: ArrayList<NativeArrayParameterInfo>, indent: String): String {
    var content = ""
    for (info in infos) {
        if (info.fixedLength >= 0) {
            content += "${indent}if (${info.name}.size != ${info.fixedLength}) {\n"
            content += "${indent}    throw IllegalArgumentException(\"${info.name} must contain ${info.fixedLength} elements\")\n"
            content += "${indent}}\n"
        }
    }
    return content
}

func renderNativeHStringArgumentDeclarations(infos: ArrayList<NativeHStringArgumentInfo>, indent: String): String {
    var content = ""
    for (info in infos) {
        content += "${indent}var ${info.handleName} = CPointer<Unit>()\n"
    }
    return content
}

func renderNativeArrayAcquisitions(infos: ArrayList<NativeArrayParameterInfo>, indent: String): String {
    var content = ""
    for (info in infos) {
        content += "${indent}let ${info.handleName} = unsafe { acquireArrayRawData(${info.name}) }\n"
    }
    return content
}

func renderNativeHStringArgumentAcquisitions(infos: ArrayList<NativeHStringArgumentInfo>, indent: String): String {
    var content = ""
    for (info in infos) {
        content += "${indent}${info.handleName} = ${info.name}.toSystemHandleCopy()\n"
    }
    return content
}

func renderNativeProcInvocation(
    returnType: String,
    rawReturnType: String,
    args: String,
    indent: String,
    explicitReturn: Bool
): String {
    var content = ""
    if (returnType == "Unit") {
        content += "${indent}unsafe { proc(${args}) }\n"
    } else if (returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)) {
        content += "${indent}return unsafe { proc(${args}) } != ${nativeBoolFalseLiteral(rawReturnType)}\n"
    } else if (returnType == "windows_strings.BSTR" && rawReturnType == "CPointer<Unit>") {
        content += "${indent}return windows_strings.BSTR.fromRawTake(CPointer<UInt16>(unsafe { proc(${args}) }))\n"
    } else if (returnType == "windows_core.HString" && rawReturnType == "CPointer<Unit>") {
        content += "${indent}return windows_core.HString.fromSystemHandleTake(unsafe { proc(${args}) })\n"
    } else if (nativeIsComInterfacePublicType(returnType) && rawReturnType == "CPointer<Unit>") {
        content += "${indent}return ${returnType}.fromAbiTake(unsafe { proc(${args}) })\n"
    } else if (nativeIsTextPointerPublicType(returnType)) {
        content += "${indent}return ${returnType}.fromRaw(unsafe { proc(${args}) })\n"
    } else if (returnType != rawReturnType) {
        content += "${indent}var result = ${returnType}()\n"
        content += "${indent}result.Value = unsafe { proc(${args}) }\n"
        if (explicitReturn) {
            content += "${indent}return result\n"
        } else {
            content += "${indent}result\n"
        }
    } else {
        content += "${indent}return unsafe { proc(${args}) }\n"
    }
    return content
}

func nativeResolveExpression(spec: NativeFunctionSpec): String {
    let method = spec.method
    let importName = cjStringContent(pinvokeImportName(method))
    if (!spec.dynamicModuleParameterName.isEmpty()) {
        return "windows_libloading.resolveProcFromSearchPath(${spec.dynamicModuleParameterName}, \"${importName}\")"
    }
    match (method.methodImport) {
        case Some(methodImport) =>
            return "windows_libloading.resolveProc(\"${cjStringContent(methodImport.moduleName)}\", \"${importName}\")"
        case None => return "windows_libloading.resolveProc(\"\", \"${importName}\")"
    }
}

func nativeFunctionParameterText(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let parts = ArrayList<String>()
    if (!spec.dynamicModuleParameterName.isEmpty()) {
        parts.add("${spec.dynamicModuleParameterName}: String")
    }
    let metadataParameters = metadataMethodParameters(spec.method)
    let arrayInfos = nativeArrayParameterInfos(spec, symbolsByName)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let name = interfaceParameterName(parameter, index)
        match (nativeArrayInfoForLengthIndex(arrayInfos, index)) {
            case Some(_) =>
                index += 1
                continue
            case None => ()
        }
        if (nativeReservedParameterCanBeDefaulted(parameter)) {
            index += 1
            continue
        }
        match (nativeArrayInfoAtIndex(arrayInfos, index)) {
            case Some(arrayInfo) =>
                parts.add("${name}: Array<${arrayInfo.elementType}>")
            case None =>
                match (nativeAssociatedEnumParameterType(parameter, symbolsByName, spec.ownerFullName)) {
                    case Some(typeName) => parts.add("${name}: ${typeName}")
                    case None =>
                        let typeName = nativePublicType(signature, symbolsByName, spec.ownerFullName)
                        parts.add("${name}: ${typeName}")
                }
        }
        index += 1
    }
    return joinStrings(parts, ", ")
}

func nativeFunctionPublicArgumentText(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let args = ArrayList<String>()
    if (!spec.dynamicModuleParameterName.isEmpty()) {
        args.add(spec.dynamicModuleParameterName)
    }
    let metadataParameters = metadataMethodParameters(spec.method)
    let arrayInfos = nativeArrayParameterInfos(spec, symbolsByName)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let parameter = metadataParameterAt(metadataParameters, index)
        let name = interfaceParameterName(parameter, index)
        match (nativeArrayInfoForLengthIndex(arrayInfos, index)) {
            case Some(_) =>
                index += 1
                continue
            case None => ()
        }
        if (nativeReservedParameterCanBeDefaulted(parameter)) {
            index += 1
            continue
        }
        args.add(name)
        index += 1
    }
    return joinStrings(args, ", ")
}

func nativeFunctionArgumentText(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let args = ArrayList<String>()
    let metadataParameters = metadataMethodParameters(spec.method)
    let arrayInfos = nativeArrayParameterInfos(spec, symbolsByName)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let name = interfaceParameterName(parameter, index)
        match (nativeArrayInfoForLengthIndex(arrayInfos, index)) {
            case Some(arrayInfo) =>
                args.add(nativeArrayLengthArgumentExpression(signature, arrayInfo.name, symbolsByName, spec.ownerFullName))
            case None =>
                if (nativeReservedParameterCanBeDefaulted(parameter)) {
                    args.add(nativeReservedDefaultArgumentExpression(signature, symbolsByName, spec.ownerFullName))
                } else {
                    match (nativeArrayInfoAtIndex(arrayInfos, index)) {
                        case Some(arrayInfo) =>
                            args.add("${arrayInfo.handleName}.pointer")
                        case None =>
                            match (nativeAssociatedEnumParameterType(parameter, symbolsByName, spec.ownerFullName)) {
                                case Some(_) =>
                                    args.add(nativeAssociatedEnumArgumentExpression(signature, name, parameter, symbolsByName, spec.ownerFullName))
                                case None =>
                                    args.add(nativeArgumentExpression(signature, name, symbolsByName, spec.ownerFullName, pinvokeImportName(spec.method)))
                            }
                    }
                }
        }
        index += 1
    }
    return joinStrings(args, ", ")
}

func nativeArrayLengthArgumentExpression(
    signature: SignatureRecord,
    arrayName: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let lengthType = nativeRawType(signature, symbolsByName, ownerFullName)
    return "${lengthType}(${arrayName}.size)"
}

func nativeReservedDefaultArgumentExpression(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    return cjDefaultValue(nativeRawType(signature, symbolsByName, ownerFullName))
}

func nativeReservedParameterCanBeDefaulted(parameter: Option<ParameterRecord>): Bool {
    match (parameter) {
        case Some(value) =>
            if (contains(value.attributes, "Out")) {
                return false
            }
            for (attribute in value.customAttributes) {
                if (hasAttributeName(attribute, "ReservedAttribute")) {
                    return true
                }
            }
        case None => ()
    }
    return false
}

func nativeAssociatedEnumParameterType(
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (nativeAssociatedEnumParameterSymbol(parameter, symbolsByName, ownerFullName)) {
        case Some(symbol) => return Some(symbol.name)
        case None => return None
    }
}

func nativeAssociatedEnumArgumentExpression(
    signature: SignatureRecord,
    name: String,
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let rawType = nativeRawType(signature, symbolsByName, ownerFullName)
    match (nativeAssociatedEnumFullName(parameter, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (win32ScalarRawAbiTypeByFullName(fullName)) {
                case Some(aliasRawType) =>
                    if (aliasRawType == rawType) {
                        return name
                    }
                    return "${rawType}(${name})"
                case None => ()
            }
        case None => ()
    }
    return "${rawType}(${name}.value)"
}

func nativeAssociatedEnumParameterSymbol(
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<SymbolRecord> {
    match (nativeAssociatedEnumFullName(parameter, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (symbolsByName.get(fullName)) {
                case Some(symbol) =>
                    match (symbol.typeDef) {
                        case Some(typeDef) =>
                            if (isEnumType(typeDef)) {
                                return Some(symbol)
                            }
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    return None
}

func nativeAssociatedEnumFullName(
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (parameter) {
        case Some(value) =>
            for (attribute in value.customAttributes) {
                if (hasAttributeName(attribute, "AssociatedEnumAttribute")) {
                    for (argument in attribute.fixedArguments) {
                        match (nativeAssociatedEnumArgumentName(argument)) {
                            case Some(typeName) =>
                                match (nativeResolveAssociatedEnumFullName(typeName, symbolsByName, ownerFullName)) {
                                    case Some(fullName) => return Some(fullName)
                                    case None => ()
                                }
                            case None => ()
                        }
                    }
                }
            }
        case None => ()
    }
    return None
}

func nativeAssociatedEnumArgumentName(argument: CustomAttributeFixedArgumentRecord): Option<String> {
    match (fixedArgumentTypeFullName(argument)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    return fixedArgumentString(argument)
}

func nativeResolveAssociatedEnumFullName(
    typeName: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (symbolsByName.get(typeName)) {
        case Some(_) => return Some(typeName)
        case None => ()
    }
    match (resolveRelativeTypeFullName(ownerFullName, typeName, symbolsByName)) {
        case Some(fullName) => return Some(fullName)
        case None => return None
    }
}

func nativeArrayParameterInfos(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<NativeArrayParameterInfo> {
    let infos = ArrayList<NativeArrayParameterInfo>()
    let metadataParameters = metadataMethodParameters(spec.method)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        if (nativeReservedParameterCanBeDefaulted(parameter)) {
            index += 1
            continue
        }
        match (nativeFixedElementArrayLength(parameter)) {
            case Some(fixedLength) =>
                match (nativeArrayPointerElementType(signature, symbolsByName, spec.ownerFullName)) {
                    case Some(elementType) =>
                        let name = interfaceParameterName(parameter, index)
                        infos.add(NativeArrayParameterInfo(index, -1, name, elementType, fixedLength: fixedLength))
                    case None => ()
                }
                index += 1
                continue
            case None => ()
        }
        let elementLengthHint = nativeRelativeElementArrayLengthIndex(parameter)
        match (elementLengthHint) {
            case Some(lengthIndex) =>
                if (nativeArrayLengthParameterCanBeInferred(spec.method, metadataParameters, index, lengthIndex) &&
                    nativeArrayRawLengthReferenceCount(spec.method, metadataParameters, lengthIndex) == 1) {
                    match (nativeArrayPointerElementType(signature, symbolsByName, spec.ownerFullName)) {
                        case Some(elementType) =>
                            let name = interfaceParameterName(parameter, index)
                            infos.add(NativeArrayParameterInfo(index, lengthIndex, name, elementType))
                        case None => ()
                    }
                }
            case None => ()
        }
        match (elementLengthHint) {
            case Some(_) => ()
            case None =>
                match (nativeRelativeByteArrayLengthIndex(parameter)) {
                    case Some(lengthIndex) =>
                        if (nativeArrayLengthParameterCanBeInferred(spec.method, metadataParameters, index, lengthIndex) &&
                            nativeArrayRawLengthReferenceCount(spec.method, metadataParameters, lengthIndex) == 1) {
                            match (nativeArrayPointerElementType(signature, symbolsByName, spec.ownerFullName)) {
                                case Some(elementType) =>
                                    if (nativeArrayElementTypeIsByteSized(elementType)) {
                                        let name = interfaceParameterName(parameter, index)
                                        infos.add(NativeArrayParameterInfo(index, lengthIndex, name, elementType))
                                    }
                                case None => ()
                            }
                        }
                    case None => ()
                }
        }
        index += 1
    }
    return infos
}

func nativeHStringArgumentInfos(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<NativeHStringArgumentInfo> {
    let infos = ArrayList<NativeHStringArgumentInfo>()
    let metadataParameters = metadataMethodParameters(spec.method)
    let arrayInfos = nativeArrayParameterInfos(spec, symbolsByName)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        if (nativeReservedParameterCanBeDefaulted(parameter)) {
            index += 1
            continue
        }
        match (nativeArrayInfoForLengthIndex(arrayInfos, index)) {
            case Some(_) =>
                index += 1
                continue
            case None => ()
        }
        match (nativeArrayInfoAtIndex(arrayInfos, index)) {
            case Some(_) =>
                index += 1
                continue
            case None => ()
        }
        let publicType = nativePublicType(signature, symbolsByName, spec.ownerFullName)
        let rawType = nativeRawType(signature, symbolsByName, spec.ownerFullName)
        if (publicType == "windows_core.HString" && rawType == "CPointer<Unit>") {
            let name = interfaceParameterName(parameter, index)
            infos.add(NativeHStringArgumentInfo(
                index,
                name,
                !nativeHStringArgumentTransfersOwnership(pinvokeImportName(spec.method))
            ))
        }
        index += 1
    }
    return infos
}

func nativeArrayLengthParameterCanBeInferred(
    method: MethodRecord,
    metadataParameters: ArrayList<ParameterRecord>,
    arrayIndex: Int64,
    lengthIndex: Int64
): Bool {
    if (lengthIndex < 0 || lengthIndex >= Int64(method.signature.parameters.size) || lengthIndex == arrayIndex) {
        return false
    }
    match (metadataParameterAt(metadataParameters, lengthIndex)) {
        case Some(parameter) =>
            if (nativeReservedParameterCanBeDefaulted(Some(parameter))) {
                return false
            }
            if (contains(parameter.attributes, "Out")) {
                return false
            }
        case None => return false
    }
    let lengthSignature = method.signature.parameters[lengthIndex]
    return lengthSignature.kind != "Pointer" && lengthSignature.kind != "ByReference"
}

func nativeArrayRawLengthReferenceCount(
    method: MethodRecord,
    metadataParameters: ArrayList<ParameterRecord>,
    lengthIndex: Int64
): Int64 {
    var count: Int64 = 0
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let parameter = metadataParameterAt(metadataParameters, index)
        if (!nativeReservedParameterCanBeDefaulted(parameter)) {
            match (nativeRelativeArrayLengthIndex(parameter)) {
                case Some(value) =>
                    if (value == lengthIndex) {
                        count += 1
                    }
                case None => ()
            }
        }
        index += 1
    }
    return count
}

func nativeArrayInfoAtIndex(infos: ArrayList<NativeArrayParameterInfo>, index: Int64): Option<NativeArrayParameterInfo> {
    for (info in infos) {
        if (info.index == index) {
            return Some(info)
        }
    }
    return None
}

func nativeArrayInfoForLengthIndex(
    infos: ArrayList<NativeArrayParameterInfo>,
    lengthIndex: Int64
): Option<NativeArrayParameterInfo> {
    for (info in infos) {
        if (info.lengthIndex == lengthIndex) {
            return Some(info)
        }
    }
    return None
}

func nativeRelativeArrayLengthIndex(parameter: Option<ParameterRecord>): Option<Int64> {
    match (nativeRelativeElementArrayLengthIndex(parameter)) {
        case Some(value) => return Some(value)
        case None => ()
    }
    return nativeRelativeByteArrayLengthIndex(parameter)
}

func nativeFixedElementArrayLength(parameter: Option<ParameterRecord>): Option<Int64> {
    match (parameter) {
        case Some(value) =>
            for (attribute in value.customAttributes) {
                if (hasAttributeName(attribute, "NativeArrayInfoAttribute")) {
                    for (argument in attribute.fixedArguments) {
                        if (argument.typeSig.kind == "Primitive" && argument.typeSig.name == "Int32") {
                            match (fixedArgumentInt64(argument)) {
                                case Some(length) => return Some(length)
                                case None => ()
                            }
                        }
                    }
                }
            }
        case None => ()
    }
    return None
}

func nativeRelativeElementArrayLengthIndex(parameter: Option<ParameterRecord>): Option<Int64> {
    match (parameter) {
        case Some(value) =>
            for (attribute in value.customAttributes) {
                if (hasAttributeName(attribute, "NativeArrayInfoAttribute")) {
                    for (argument in attribute.fixedArguments) {
                        if (argument.typeSig.kind == "Primitive" && argument.typeSig.name == "Int16") {
                            match (fixedArgumentInt64(argument)) {
                                case Some(index) => return Some(index)
                                case None => ()
                            }
                        }
                    }
                }
            }
        case None => ()
    }
    return None
}

func nativeRelativeByteArrayLengthIndex(parameter: Option<ParameterRecord>): Option<Int64> {
    match (parameter) {
        case Some(value) =>
            for (attribute in value.customAttributes) {
                if (hasAttributeName(attribute, "MemorySizeAttribute")) {
                    for (argument in attribute.fixedArguments) {
                        if (argument.typeSig.kind == "Primitive" && argument.typeSig.name == "Int16") {
                            match (fixedArgumentInt64(argument)) {
                                case Some(index) => return Some(index)
                                case None => ()
                            }
                        }
                    }
                }
            }
        case None => ()
    }
    return None
}

func nativeArrayElementTypeIsByteSized(typeName: String): Bool {
    return typeName == "UInt8" || typeName == "Int8"
}

func nativeArrayPointerElementType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    if (signature.kind == "Pointer" || signature.kind == "ByReference") {
        match (signature.typeSig) {
            case Some(inner) => return Some(nativePublicPointerElementType(inner, symbolsByName, ownerFullName))
            case None => ()
        }
    }
    return None
}

func nativeCFuncType(
    spec: NativeFunctionSpec,
    rawReturnType: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let params = ArrayList<String>()
    for (parameter in spec.method.signature.parameters) {
        params.add(nativeRawType(parameter, symbolsByName, spec.ownerFullName))
    }
    if (params.isEmpty()) {
        return "CFunc<() -> ${rawReturnType}>"
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${rawReturnType}>"
}

func nativeDelegateCFuncType(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    for (method in typeDef.methods) {
        if (method.name == "Invoke") {
            let params = ArrayList<String>()
            for (parameter in method.signature.parameters) {
                params.add(nativeRawType(parameter, symbolsByName, ownerFullName))
            }
            let returnType = nativeRawType(method.signature.returnType, symbolsByName, ownerFullName)
            if (params.isEmpty()) {
                return Some("CFunc<() -> ${returnType}>")
            }
            return Some("CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>")
        }
    }
    return None
}

func nativeArgumentExpression(
    signature: SignatureRecord,
    name: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    importName: String
): String {
    let publicType = nativePublicType(signature, symbolsByName, ownerFullName)
    let rawType = nativeRawType(signature, symbolsByName, ownerFullName)
    if (publicType == "Bool" && nativeIsIntegerBoolAbiType(rawType)) {
        return "if (${name}) { ${nativeBoolTrueLiteral(rawType)} } else { ${nativeBoolFalseLiteral(rawType)} }"
    }
    if (publicType == "windows_strings.BSTR" && rawType == "CPointer<Unit>") {
        if (nativeBStrArgumentTransfersOwnership(importName)) {
            return "CPointer<Unit>(${name}.intoRaw())"
        }
        return "CPointer<Unit>(${name}.asPtr())"
    }
    if (publicType == "windows_core.HString" && rawType == "CPointer<Unit>") {
        return nativeHStringArgumentHandleName(name)
    }
    if (nativeIsComInterfacePublicType(publicType) && rawType == "CPointer<Unit>") {
        return "${name}.asRaw()"
    }
    if (nativeIsTextPointerPublicType(publicType)) {
        return "${name}.asPtr()"
    }
    if ((signature.kind == "Pointer" || signature.kind == "ByReference") &&
        startsWithString(publicType, "CPointer<") &&
        startsWithString(rawType, "CPointer<") &&
        publicType != rawType) {
        return "${rawType}(${name})"
    }
    if (publicType != rawType) {
        return "${name}.Value"
    }
    return name
}

func nativeBStrArgumentTransfersOwnership(methodName: String): Bool {
    return methodName == "SysFreeString" || methodName == "SysReleaseString"
}

func nativeHStringArgumentHandleName(name: String): String {
    "__${name}HStringHandle"
}

func nativeHStringArgumentTransfersOwnership(methodName: String): Bool {
    return methodName == "WindowsDeleteString"
}

func nativePublicType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (signature.kind == "Pointer" || signature.kind == "ByReference") {
        match (signature.typeSig) {
            case Some(inner) =>
                let innerType = nativePublicPointerElementType(inner, symbolsByName, ownerFullName)
                return "CPointer<${innerType}>"
            case None => return "CPointer<Unit>"
        }
    }
    return nativeNonPointerPublicType(signature, symbolsByName, ownerFullName)
}

func nativeRawType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (signature.kind == "Pointer" || signature.kind == "ByReference") {
        match (signature.typeSig) {
            case Some(inner) =>
                let innerType = nativeRawPointerElementType(inner, symbolsByName, ownerFullName)
                return "CPointer<${innerType}>"
            case None => return "CPointer<Unit>"
        }
    }
    return nativeNonPointerRawType(signature, symbolsByName, ownerFullName)
}

func nativePublicPointerElementType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    if (signature.kind == "Pointer" || signature.kind == "ByReference") {
        return nativePublicType(signature, symbolsByName, ownerFullName)
    }
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (nativeBStrRawType(fullName)) {
                case Some(typeName) => return typeName
                case None => ()
            }
            match (nativeHStringRawType(fullName)) {
                case Some(typeName) => return typeName
                case None => ()
            }
            match (nativeComInterfaceRawType(fullName)) {
                case Some(typeName) => return typeName
                case None => ()
            }
            match (nativeTextPointerRawType(fullName)) {
                case Some(typeName) => return typeName
                case None => ()
            }
            match (nativeBooleanRawType(fullName)) {
                case Some(typeName) => return typeName
                case None => ()
            }
        case None => ()
    }
    return nativeNonPointerPublicType(signature, symbolsByName, ownerFullName)
}

func nativeRawPointerElementType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    if (signature.kind == "Pointer" || signature.kind == "ByReference") {
        return nativeRawType(signature, symbolsByName, ownerFullName)
    }
    return nativeNonPointerRawType(signature, symbolsByName, ownerFullName)
}

func nativeNonPointerPublicType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (signature.kind == "Primitive") {
        return nativePrimitiveCjType(signature.name)
    }
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    if (signature.kind == "Array" || signature.kind == "SZArray") {
        return "CPointer<Unit>"
    }
    if (signature.kind == "Type" || signature.kind == "TypeReference" || signature.kind == "TypeDefinition") {
        match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
            case Some(fullName) => return nativeNamedPublicType(fullName, symbolsByName)
            case None => ()
        }
    }
    match (signature.typeSig) {
        case Some(nested) => return nativePublicType(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) => return nativePublicType(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    return cjAbiTypeInContext(signature, symbolsByName, ownerFullName)
}

func nativeNonPointerRawType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (signature.kind == "Primitive") {
        return nativePrimitiveCjType(signature.name)
    }
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    if (signature.kind == "Array" || signature.kind == "SZArray") {
        return "CPointer<Unit>"
    }
    if (signature.kind == "Type" || signature.kind == "TypeReference" || signature.kind == "TypeDefinition") {
        match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
            case Some(fullName) => return nativeNamedRawType(fullName, symbolsByName)
            case None => ()
        }
    }
    match (signature.typeSig) {
        case Some(nested) => return nativeRawType(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) => return nativeRawType(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    return cjAbiTypeInContext(signature, symbolsByName, ownerFullName)
}

func nativePrimitiveCjType(name: String): String {
    if (name == "UIntPtr") {
        return "UIntNative"
    }
    if (name == "IntPtr") {
        return "IntNative"
    }
    return primitiveCjType(name)
}

func nativeNamedPublicType(fullName: String, symbolsByName: HashMap<String, SymbolRecord>): String {
    match (nativeSystemType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativePointerSizedIntegerType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeEventRegistrationTokenType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeHResultType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeBStrPublicType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeHStringPublicType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeComInterfacePublicType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeTextPointerPublicType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeFoundationCharType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeBooleanRawType(fullName)) {
        case Some(_) => return "Bool"
        case None => ()
    }
    match (symbolsByName.get(fullName)) {
        case Some(symbol) =>
            match (symbol.typeDef) {
                case Some(typeDef) =>
                    if (isEnumType(typeDef)) {
                        return enumUnderlyingType(typeDef, symbolsByName)
                    }
                    if (isDelegateType(typeDef)) {
                        match (nativeDelegateCFuncType(typeDef, symbolsByName, fullName)) {
                            case Some(typeName) => return typeName
                            case None => return "CPointer<Unit>"
                        }
                    }
                    match (nativeTransparentScalarType(typeDef, symbolsByName, fullName)) {
                        case Some(typeName) => return typeName
                        case None => ()
                    }
                    if (!isValueType(typeDef)) {
                        return "CPointer<Unit>"
                    }
                    return symbol.name
                case None => return symbol.name
            }
        case None => return "CPointer<Unit>"
    }
}

func nativeNamedRawType(fullName: String, symbolsByName: HashMap<String, SymbolRecord>): String {
    match (nativeSystemType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativePointerSizedIntegerType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeEventRegistrationTokenType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeHResultType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeBStrRawType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeHStringRawType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeComInterfaceRawType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeTextPointerRawType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeFoundationCharType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (nativeBooleanRawType(fullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (symbolsByName.get(fullName)) {
        case Some(symbol) =>
            match (symbol.typeDef) {
                case Some(typeDef) =>
                    if (isEnumType(typeDef)) {
                        return enumUnderlyingType(typeDef, symbolsByName)
                    }
                    if (isDelegateType(typeDef)) {
                        match (nativeDelegateCFuncType(typeDef, symbolsByName, fullName)) {
                            case Some(typeName) => return typeName
                            case None => return "CPointer<Unit>"
                        }
                    }
                    match (nativeTransparentValueType(typeDef, symbolsByName, fullName)) {
                        case Some(typeName) => return typeName
                        case None => ()
                    }
                    if (!isValueType(typeDef)) {
                        return "CPointer<Unit>"
                    }
                    return symbol.name
                case None => return symbol.name
            }
        case None => return "CPointer<Unit>"
    }
}

func nativeSystemType(fullName: String): Option<String> {
    if (fullName == "System.UIntPtr") {
        return Some("UIntNative")
    }
    if (fullName == "System.IntPtr") {
        return Some("IntNative")
    }
    if (isSystemGuidType(fullName)) {
        return Some("GUID")
    }
    return None
}

func isSystemGuidType(fullName: String): Bool {
    fullName == "System.Guid"
}

func nativeFoundationCharType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.CHAR") {
        return Some("Int8")
    }
    return None
}

func nativeBooleanRawType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.BOOL") {
        return Some("Int32")
    }
    if (fullName == "Windows.Win32.Foundation.BOOLEAN") {
        return Some("UInt8")
    }
    return None
}

func nativeIsIntegerBoolAbiType(typeName: String): Bool {
    return typeName == "Int32" || typeName == "UInt8"
}

func nativeBoolTrueLiteral(typeName: String): String {
    if (typeName == "UInt8") {
        return "1u8"
    }
    return "1"
}

func nativeBoolFalseLiteral(typeName: String): String {
    if (typeName == "UInt8") {
        return "0u8"
    }
    return "0"
}

func nativeTextPointerPublicType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.PWSTR") {
        return Some("windows_strings.PWSTR")
    }
    if (fullName == "Windows.Win32.Foundation.PSTR") {
        return Some("windows_strings.PSTR")
    }
    if (fullName == "Windows.Win32.Foundation.PCWSTR") {
        return Some("windows_strings.PCWSTR")
    }
    if (fullName == "Windows.Win32.Foundation.PCSTR") {
        return Some("windows_strings.PCSTR")
    }
    return None
}

func nativeTextPointerRawType(fullName: String): Option<String> {
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

func nativeIsTextPointerPublicType(typeName: String): Bool {
    return typeName == "windows_strings.PWSTR" ||
        typeName == "windows_strings.PSTR" ||
        typeName == "windows_strings.PCWSTR" ||
        typeName == "windows_strings.PCSTR"
}

func nativePointerSizedIntegerType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.SIZE_T" ||
        fullName == "Windows.Win32.Foundation.UINT_PTR" ||
        fullName == "Windows.Win32.Foundation.ULONG_PTR" ||
        fullName == "Windows.Win32.Foundation.DWORD_PTR" ||
        fullName == "Windows.Win32.Foundation.HANDLE_PTR" ||
        fullName == "Windows.Win32.Foundation.WPARAM") {
        return Some("UIntNative")
    }
    if (fullName == "Windows.Win32.Foundation.SSIZE_T" ||
        fullName == "Windows.Win32.Foundation.INT_PTR" ||
        fullName == "Windows.Win32.Foundation.LONG_PTR" ||
        fullName == "Windows.Win32.Foundation.LPARAM" ||
        fullName == "Windows.Win32.Foundation.LRESULT" ||
        fullName == "Windows.Win32.Foundation.SHANDLE_PTR") {
        return Some("IntNative")
    }
    return None
}

func nativeEventRegistrationTokenType(fullName: String): Option<String> {
    if (fullName == "Windows.Foundation.EventRegistrationToken" ||
        fullName == "Windows.Win32.System.WinRT.EventRegistrationToken") {
        return Some("Int64")
    }
    return None
}

func nativeHResultType(fullName: String): Option<String> {
    if (fullName == "Windows.Foundation.HResult" ||
        fullName == "Windows.Win32.Foundation.HRESULT") {
        return Some("Int32")
    }
    return None
}

func nativeBStrPublicType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.BSTR") {
        return Some("windows_strings.BSTR")
    }
    return None
}

func nativeBStrRawType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.BSTR") {
        return Some("CPointer<Unit>")
    }
    return None
}

func nativeHStringPublicType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.System.WinRT.HSTRING") {
        return Some("windows_core.HString")
    }
    return None
}

func nativeHStringRawType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.System.WinRT.HSTRING") {
        return Some("CPointer<Unit>")
    }
    return None
}

func nativeComInterfacePublicType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.System.Com.IUnknown") {
        return Some("windows_interface.IUnknown")
    }
    if (fullName == "Windows.Win32.System.WinRT.IInspectable") {
        return Some("windows_interface.IInspectable")
    }
    return None
}

func nativeComInterfaceRawType(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.System.Com.IUnknown" ||
        fullName == "Windows.Win32.System.WinRT.IInspectable") {
        return Some("CPointer<Unit>")
    }
    return None
}

func nativeIsComInterfacePublicType(typeName: String): Bool {
    return typeName == "windows_interface.IUnknown" ||
        typeName == "windows_interface.IInspectable"
}

func nativeShortTypeName(fullName: String): String {
    let bytes = fullName.toArray()
    var lastDot: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'.') {
            lastDot = i
        }
        i += 1
    }
    if (lastDot >= 0 && lastDot + 1 < Int64(bytes.size)) {
        return String.fromUtf8(bytes[(lastDot + 1)..Int64(bytes.size)])
    }
    return fullName
}

func nativeTransparentScalarType(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (nativeTransparentValueType(typeDef, symbolsByName, ownerFullName)) {
        case Some(typeName) =>
            if (!startsWithString(typeName, "CPointer<")) {
                return Some(typeName)
            }
        case None => ()
    }
    return None
}

func nativeTransparentValueType(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    if (!isValueType(typeDef)) {
        return None
    }
    var valueFields = ArrayList<FieldRecord>()
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            valueFields.add(field)
        }
    }
    if (valueFields.size != 1 || valueFields[0].name != "Value") {
        return None
    }
    return Some(cjAbiTypeInContext(valueFields[0].signature, symbolsByName, ownerFullName))
}
