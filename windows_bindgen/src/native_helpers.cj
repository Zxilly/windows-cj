package windows_bindgen

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

class NativeHResultStringOutSlot {
    public let pair: ParameterPair
    public let allocator: String
    public let allowNullSlot: Bool

    public init(pair: ParameterPair, allocator: String, allowNullSlot!: Bool = false) {
        this.pair = pair
        this.allocator = allocator
        this.allowNullSlot = allowNullSlot
    }
}

class NativeHResultOwnedPointerOutSlot {
    public let pair: ParameterPair
    public let allocator: String

    public init(pair: ParameterPair, allocator: String) {
        this.pair = pair
        this.allocator = allocator
    }
}

class NativeHResultBorrowedOptionalOutSlot {
    public let pair: ParameterPair

    public init(pair: ParameterPair) {
        this.pair = pair
    }
}

class NativeHResultOptionalScalarOutSlot {
    public let pair: ParameterPair
    public let defaultValue: String

    public init(pair: ParameterPair, defaultValue: String) {
        this.pair = pair
        this.defaultValue = defaultValue
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

// Namespaces used by the common native helper files. These include the synthetic
// app-runtime namespace and any namespace carrying P/Invoke wrappers; their cfg
// variables must be defined in every package cfg.toml since native helpers are
// `@When`-gated by namespace.
public func commonNativeHelperNamespaces(nativeSymbols: ArrayList<SymbolRecord>): ArrayList<String> {
    let namespaces = ArrayList<String>()
    addUnique(namespaces, "Native.AppRuntime")
    for (spec in syntheticCommonNativeFunctionSpecs()) {
        addUnique(namespaces, spec.namespace)
    }
    for (spec in nativeFunctionSpecsFromSymbols(nativeSymbols)) {
        addUnique(namespaces, spec.namespace)
    }
    sortStrings(namespaces)
    return namespaces
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
    // All native helper functions in this file belong to `namespace`, and the
    // impl types they reference (plus any cross-namespace imports) are part of
    // that namespace's dependency closure. The whole file is therefore gated by
    // the one namespace cfg variable: when it is off, the functions and their
    // impl imports are removed together (no dangling import of a gated-off type).
    let gate = cfgGateAnnotation(namespace)
    var content = "package ${namespaceToPackage(namespace, packageName)}\n\n"
    content += "${gate}\nimport windows_libloading as windows_libloading\n"
    let imports = nativeHelperImports(packageName, namespace, specs, symbolsByName)
    // Native helper functions import specific symbols from sibling facade packages
    // (e.g. Windows.Win32.Foundation.HANDLE), but those imports are `@When`-gated
    // and so are soft edges for cjpm's build scheduler. Emit an unconditional
    // package-alias edge to each distinct sibling facade package so cjpm always
    // builds it first; otherwise the package scheduler can compile this helper
    // package before the sibling facade has produced its `.cjo`.
    content += renderNativeHelperPackageEdges(packageName, namespace, imports)
    for (importPath in imports) {
        content += "${gate}\nimport ${importPath}\n"
    }
    content += "\n"
    for (spec in specs) {
        content += renderNativeFunction(spec, symbolsByName, gate) + "\n"
    }
    return content
}

// Emit unconditional package-alias edges for the distinct sibling facade packages
// a native helper file imports specific symbols from. Support packages
// (windows_core, windows_strings, ...) are real cjpm.toml dependencies and always
// built, so they need no extra edge; only generated `${packageName}.*` facade
// packages do. The helper's own package is excluded.
func renderNativeHelperPackageEdges(
    packageName: String,
    namespace: String,
    imports: ArrayList<String>
): String {
    let selfPackage = namespaceToPackage(namespace, packageName)
    let edgePackages = ArrayList<String>()
    for (importPath in imports) {
        match (nativeHelperImportPackage(importPath, packageName)) {
            case Some(pkg) =>
                if (pkg != selfPackage) {
                    addUnique(edgePackages, pkg)
                }
            case None => ()
        }
    }
    sortStrings(edgePackages)
    var content = ""
    var index: Int64 = 0
    for (pkg in edgePackages) {
        content += "import ${pkg} as native_helper_edge_${index}\n"
        index += 1
    }
    return content
}

// Extract the generated facade package from a native helper import entry, or None
// for support-package aliases. Entries are either `pkg.Symbol` (a specific facade
// symbol import) or `support as support` (a package alias). Only the former,
// rooted at `${packageName}.`, yields a facade package (its symbol component is
// dropped).
func nativeHelperImportPackage(importPath: String, packageName: String): Option<String> {
    if (importPath.contains(" as ")) {
        return None
    }
    let prefix = "${packageName}."
    if (!startsWithString(importPath, prefix)) {
        return None
    }
    let parts = splitString(importPath, b'.')
    if (Int64(parts.size) < 2) {
        return None
    }
    let pkgParts = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(parts.size) - 1) {
        pkgParts.add(parts[i])
        i += 1
    }
    return Some(joinStrings(pkgParts, "."))
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
        if (nativeMethodNeedsSetLastErrorCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorBoolStatusCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorBoolFalseSuccessCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockBoolCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockNullHandleCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockInvalidEventCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorHandleCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorInvalidHandleCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorNullSuccessHandleCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorWaitEventCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockWaitEventCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockNullPointerCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorPointerCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorTlsValueCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorUInt32MinusOneCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorUInt32ZeroLastErrorCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorUInt32ZeroCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorUIntNativeZeroCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorIntNativeZeroLastErrorCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorInt32MaxCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsSetLastErrorInt32MinusOneCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockInvalidSocketCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsMswsockGetLastErrorSocketErrorInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockSocketErrorInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockDirectErrorInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockPendingStatusInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockLpErrnoInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWaitFailedUInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsDirectWin32ErrorCodeInt32StatusCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsDirectWin32ErrorCodeInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsDirectWin32ErrorCodeUInt32StatusCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsDirectWin32ErrorCodeUInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsUInt32LessThanOrEqualCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsHResultCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName)) {
            addUnique(imports, "windows_core as windows_core")
        }
        if (nativeMethodNeedsSetLastErrorInvalidHandleCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockInvalidSocketCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName)) {
            addUnique(imports, "windows_polyfill as windows_polyfill")
        }
        if ((nativeMethodNeedsSetLastErrorWaitEventCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWinSockWaitEventCheckedWrapper(spec.method, symbolsByName, spec.ownerFullName) ||
            nativeMethodNeedsWaitFailedUInt32CheckedWrapper(spec.method, symbolsByName, spec.ownerFullName)) &&
            namespace != "Windows.Win32.Foundation") {
            let waitEventPackage = namespaceToPackage("Windows.Win32.Foundation", packageName)
            addUnique(imports, "${waitEventPackage}.WAIT_EVENT")
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
                    // A delegate parameter is rendered inline as a `CFunc<...>` whose own
                    // parameter/return types (e.g. a cross-namespace `IO_STATUS_BLOCK` inside
                    // an APC routine) must also be imported. The delegate type itself uses no
                    // facade alias (handled above), so without this its nested type references
                    // would be left undeclared. Recurse in raw (pointerDepth > 0) context: the
                    // CFunc body renders these types raw, so only named value-type facade
                    // imports apply — support-package imports (BSTR/HSTRING/COM) stay suppressed.
                    match (symbol.typeDef) {
                        case Some(typeDef) =>
                            if (isDelegateType(typeDef)) {
                                for (method in typeDef.methods) {
                                    if (method.name == "Invoke") {
                                        collectNativeTypeImports(packageName, namespace, fullName, method.signature.returnType, symbolsByName, imports, pointerDepth: 1)
                                        for (parameter in method.signature.parameters) {
                                            collectNativeTypeImports(packageName, namespace, fullName, parameter, symbolsByName, imports, pointerDepth: 1)
                                        }
                                    }
                                }
                            }
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    // A bare function-pointer signature is likewise expanded inline as a `CFunc<...>`;
    // its parameter/return types must be imported even though the outer signature has
    // no resolvable named type of its own.
    if (signature.kind == "FunctionPointer") {
        match (signature.functionPointerSignature) {
            case Some(methodSignature) =>
                collectNativeTypeImports(packageName, namespace, ownerFullName, methodSignature.returnType, symbolsByName, imports, pointerDepth: 1)
                for (parameter in methodSignature.parameters) {
                    collectNativeTypeImports(packageName, namespace, ownerFullName, parameter, symbolsByName, imports, pointerDepth: 1)
                }
            case None => ()
        }
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

// Render a native helper function (and any error-checking wrapper variants),
// structurally prefixing each top-level `public func` with `gate` — the
// `@When[<ns> == "on"]` annotation (without trailing newline, matching the
// convention used elsewhere in this file). The main function and every wrapper
// are independent top-level declarations, so each receives its own gate.
func renderNativeFunction(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>, gate: String): String {
    let gatePrefix = if (gate.isEmpty()) { "" } else { "${gate}\n" }
    let method = spec.method
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, spec.ownerFullName)
    let defaultReturnType = nativePublicType(method.signature.returnType, symbolsByName, spec.ownerFullName)
    let returnType = if (nativeMethodPreservesBoolReturnStatus(method, symbolsByName, spec.ownerFullName)) {
        rawReturnType
    } else {
        defaultReturnType
    }
    let procType = nativeCFuncType(spec, rawReturnType, symbolsByName)
    var content = "${gatePrefix}public func ${cjIdentifier(method.name)}(${publicParams}): ${returnType} {\n"
    // Use a reserved `__`-suffixed local so it never collides with a Win32 parameter named
    // `proc` (e.g. the callback parameter of EnumMetaFile/EnumEnhMetaFile); Cangjie `let` does
    // not allow same-scope shadowing, so a bare `proc` local would be a redefinition.
    content += "    let proc__ = ${procType}(${nativeResolveExpression(spec)})\n"
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
    if (nativeMethodNeedsWinSockBoolCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockBoolCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorBoolStatusCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorBoolStatusCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorBoolFalseSuccessCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorBoolFalseSuccessCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockNullHandleCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockNullCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockInvalidEventCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockNullCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorHandleCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorHandleCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorInvalidHandleCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorInvalidHandleCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorNullSuccessHandleCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorNullSuccessHandleCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorWaitEventCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorWaitEventCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockWaitEventCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockWaitEventCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockNullPointerCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockNullCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorPointerCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorPointerCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorTlsValueCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorTlsValueCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorUInt32MinusOneCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorUInt32MinusOneCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorUInt32ZeroLastErrorCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorUInt32ZeroLastErrorCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorUInt32ZeroCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorUInt32ZeroCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorUIntNativeZeroCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorUIntNativeZeroCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorIntNativeZeroLastErrorCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorIntNativeZeroLastErrorCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorInt32MaxCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorInt32MaxCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsSetLastErrorInt32MinusOneCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeSetLastErrorInt32MinusOneCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockInvalidSocketCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockInvalidSocketCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsMswsockGetLastErrorSocketErrorInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeMswsockGetLastErrorSocketErrorInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockSocketErrorInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockSocketErrorInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockDirectErrorInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockDirectErrorInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockPendingStatusInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockPendingStatusInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWinSockLpErrnoInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWinSockLpErrnoInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsWaitFailedUInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeWaitFailedUInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsDirectWin32ErrorCodeInt32StatusCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeDirectWin32ErrorCodeInt32StatusCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsDirectWin32ErrorCodeInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeDirectWin32ErrorCodeInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsDirectWin32ErrorCodeUInt32StatusCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeDirectWin32ErrorCodeUInt32StatusCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsDirectWin32ErrorCodeUInt32CheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeDirectWin32ErrorCodeUInt32CheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsUInt32LessThanOrEqualCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeUInt32LessThanOrEqualCheckedWrapper(spec, symbolsByName)
    }
    if (nativeMethodNeedsHResultCheckedWrapper(method, symbolsByName, spec.ownerFullName)) {
        content += "\n${gatePrefix}"
        content += renderNativeHResultCheckedWrapper(spec, symbolsByName)
    }
    return content
}

func renderNativeGetLastErrorStatements(indent: String): String {
    var content = "${indent}let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n"
    content += "${indent}let lastError__ = unsafe { getLastErrorProc__() }\n"
    return content
}

func renderNativeSetLastErrorZeroStatements(indent: String): String {
    var content = "${indent}let setLastErrorProc__ = CFunc<(UInt32) -> Unit>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"SetLastError\"))\n"
    content += "${indent}unsafe { setLastErrorProc__(0u32) }\n"
    return content
}

func renderNativeSetLastErrorCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Unit> {\n"
    content += "    if (${methodName}(${args})) {\n"
    content += "        return windows_core.Result<Unit>.Ok(())\n"
    content += "    }\n"
    content += "    windows_core.Result<Unit>.Err(windows_core.errorFromThread())\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorBoolStatusCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var statusCondition = "lastError__ == 0u32"
    match (nativeSetLastErrorBoolStatusSuccessCondition(spec.method, "lastError__")) {
        case Some(condition) => statusCondition = condition
        case None => ()
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<UInt32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__) {\n"
    content += "        return windows_core.Result<UInt32>.Ok(0u32)\n"
    content += "    }\n"
    content += renderNativeGetLastErrorStatements("    ")
    content += "    if (${statusCondition}) {\n"
    content += "        return windows_core.Result<UInt32>.Ok(lastError__)\n"
    content += "    }\n"
    content += "    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(lastError__))\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorBoolFalseSuccessCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let falseSuccessStatuses = nativeBoolReturnFalseSuccessStatuses(spec.method.name)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Bool> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__) {\n"
    content += "        return windows_core.Result<Bool>.Ok(true)\n"
    content += "    }\n"
    content += renderNativeGetLastErrorStatements("    ")
    for (falseSuccessStatus in falseSuccessStatuses) {
        content += "    if (lastError__ == ${falseSuccessStatus}) {\n"
        content += "        return windows_core.Result<Bool>.Ok(false)\n"
        content += "    }\n"
    }
    content += "    windows_core.Result<Bool>.Err(windows_core.errorFromWin32(lastError__))\n"
    content += "}\n"
    return content
}

func renderNativeWinSockBoolCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    match (nativeWinSockBoolPendingSuccessStatus(spec.method.name)) {
        case Some(status) =>
            var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Bool> {\n"
            content += "    let result__ = ${methodName}(${args})\n"
            content += "    if (result__) {\n"
            content += "        return windows_core.Result<Bool>.Ok(true)\n"
            content += "    }\n"
            content += "    let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n"
            content += "    let error__ = unsafe { errorProc__() }\n"
            content += "    if (error__ == ${status}) {\n"
            content += "        return windows_core.Result<Bool>.Ok(false)\n"
            content += "    }\n"
            content += "    windows_core.Result<Bool>.Err(windows_core.errorFromWin32(UInt32(error__)))\n"
            content += "}\n"
            return content
        case None => ()
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Unit> {\n"
    content += "    if (${methodName}(${args})) {\n"
    content += "        return windows_core.Result<Unit>.Ok(())\n"
    content += "    }\n"
    content += "    let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n"
    content += "    let error__ = unsafe { errorProc__() }\n"
    content += "    windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(error__)))\n"
    content += "}\n"
    return content
}

func renderNativeWinSockNullCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let returnType = nativePublicType(spec.method.signature.returnType, symbolsByName, spec.ownerFullName)
    let nullCheck = if (startsWithString(returnType, "CPointer<")) {
        "result__.isNull()"
    } else {
        "result__.Value.isNull()"
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${returnType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (${nullCheck}) {\n"
    content += "        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n"
    content += "        let error__ = unsafe { errorProc__() }\n"
    content += "        return windows_core.Result<${returnType}>.Err(windows_core.errorFromWin32(UInt32(error__)))\n"
    content += "    }\n"
    content += "    windows_core.Result<${returnType}>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorHandleCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let returnType = nativePublicType(spec.method.signature.returnType, symbolsByName, spec.ownerFullName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${returnType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__.Value.isNull()) {\n"
    content += "        return windows_core.Result<${returnType}>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<${returnType}>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorInvalidHandleCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let returnType = nativePublicType(spec.method.signature.returnType, symbolsByName, spec.ownerFullName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${returnType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (windows_polyfill.handlePointerIsMinusOne(result__.Value)) {\n"
    content += "        return windows_core.Result<${returnType}>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<${returnType}>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorNullSuccessHandleCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Unit> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__.Value.isNotNull()) {\n"
    content += "        return windows_core.Result<Unit>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<Unit>.Ok(())\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorWaitEventCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<WAIT_EVENT> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == 0xFFFFFFFFu32) {\n"
    content += "        return windows_core.Result<WAIT_EVENT>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<WAIT_EVENT>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeWinSockWaitEventCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<WAIT_EVENT> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == 0xFFFFFFFFu32) {\n"
    content += "        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n"
    content += "        let error__ = unsafe { errorProc__() }\n"
    content += "        return windows_core.Result<WAIT_EVENT>.Err(windows_core.errorFromWin32(UInt32(error__)))\n"
    content += "    }\n"
    content += "    windows_core.Result<WAIT_EVENT>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorPointerCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let returnType = nativePublicType(spec.method.signature.returnType, symbolsByName, spec.ownerFullName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${returnType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__.isNull()) {\n"
    content += "        return windows_core.Result<${returnType}>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<${returnType}>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorTlsValueCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<CPointer<Unit>> {\n"
    content += renderNativeSetLastErrorZeroStatements("    ")
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__.isNotNull()) {\n"
    content += "        return windows_core.Result<CPointer<Unit>>.Ok(result__)\n"
    content += "    }\n"
    content += renderNativeGetLastErrorStatements("    ")
    content += "    if (lastError__ == 0u32) {\n"
    content += "        return windows_core.Result<CPointer<Unit>>.Ok(result__)\n"
    content += "    }\n"
    content += "    windows_core.Result<CPointer<Unit>>.Err(windows_core.errorFromWin32(lastError__))\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorUInt32MinusOneCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<UInt32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == 0xFFFFFFFFu32) {\n"
    content += "        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<UInt32>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorUInt32ZeroLastErrorCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<UInt32> {\n"
    content += renderNativeSetLastErrorZeroStatements("    ")
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ != 0u32) {\n"
    content += "        return windows_core.Result<UInt32>.Ok(result__)\n"
    content += "    }\n"
    content += renderNativeGetLastErrorStatements("    ")
    content += "    if (lastError__ == 0u32) {\n"
    content += "        return windows_core.Result<UInt32>.Ok(result__)\n"
    content += "    }\n"
    content += "    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(lastError__))\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorUInt32ZeroCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<UInt32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == 0u32) {\n"
    content += "        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<UInt32>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorUIntNativeZeroCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<UIntNative> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == 0) {\n"
    content += "        return windows_core.Result<UIntNative>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<UIntNative>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorIntNativeZeroLastErrorCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<IntNative> {\n"
    content += renderNativeSetLastErrorZeroStatements("    ")
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ != 0) {\n"
    content += "        return windows_core.Result<IntNative>.Ok(result__)\n"
    content += "    }\n"
    content += renderNativeGetLastErrorStatements("    ")
    content += "    if (lastError__ == 0u32) {\n"
    content += "        return windows_core.Result<IntNative>.Err(windows_core.errorFromHRESULT(windows_core.E_FAIL))\n"
    content += "    }\n"
    content += "    windows_core.Result<IntNative>.Err(windows_core.errorFromWin32(lastError__))\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorInt32MaxCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Int32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == 2147483647) {\n"
    content += "        return windows_core.Result<Int32>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<Int32>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeSetLastErrorInt32MinusOneCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Int32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == -1) {\n"
    content += "        return windows_core.Result<Int32>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<Int32>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeWinSockSocketErrorInt32CheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let returnsUnit = nativeWinSockInt32ReturnUsesSocketErrorUnit(spec.method.name)
    let pendingSuccessStatus = nativeWinSockSocketErrorPendingSuccessStatus(spec.method.name)
    let resultType = if (returnsUnit) {
        "Unit"
    } else {
        "Int32"
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${resultType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == -1) {\n"
    content += "        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n"
    content += "        let error__ = unsafe { errorProc__() }\n"
    match (pendingSuccessStatus) {
        case Some(status) =>
            content += "        if (error__ == ${status}) {\n"
            content += "            return windows_core.Result<Unit>.Ok(())\n"
            content += "        }\n"
        case None => ()
    }
    content += "        return windows_core.Result<${resultType}>.Err(windows_core.errorFromWin32(UInt32(error__)))\n"
    content += "    }\n"
    if (returnsUnit) {
        content += "    windows_core.Result<Unit>.Ok(())\n"
    } else {
        content += "    windows_core.Result<Int32>.Ok(result__)\n"
    }
    content += "}\n"
    return content
}

func renderNativeMswsockGetLastErrorSocketErrorInt32CheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let returnsUnit = nativeMswsockInt32ReturnUsesGetLastErrorSocketErrorUnit(spec.method.name)
    let resultType = if (returnsUnit) {
        "Unit"
    } else {
        "Int32"
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${resultType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == -1) {\n"
    content += "        return windows_core.Result<${resultType}>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    if (returnsUnit) {
        content += "    windows_core.Result<Unit>.Ok(())\n"
    } else {
        content += "    windows_core.Result<Int32>.Ok(result__)\n"
    }
    content += "}\n"
    return content
}

func renderNativeWinSockDirectErrorInt32CheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Unit> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ != 0) {\n"
    content += "        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n"
    content += "    }\n"
    content += "    windows_core.Result<Unit>.Ok(())\n"
    content += "}\n"
    return content
}

func renderNativeWinSockPendingStatusInt32CheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let pendingStatus = nativeWinSockInt32ReturnPendingStatus(spec.method.name).getOrThrow()
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Int32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ != 0 && result__ != ${pendingStatus}) {\n"
    content += "        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))\n"
    content += "    }\n"
    content += "    windows_core.Result<Int32>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeWinSockLpErrnoInt32CheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let lpErrnoName = nativeWinSockLpErrnoParameterName(spec.method)
    let preservesStatus = nativeWinSockInt32ReturnUsesLpErrnoStatus(spec.method.name)
    let resultType = if (preservesStatus) {
        "Int32"
    } else {
        "Unit"
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${resultType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == -1) {\n"
    content += "        if (${lpErrnoName}.isNull()) {\n"
    content += "            return windows_core.Result<${resultType}>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n"
    content += "        }\n"
    content += "        let error__ = unsafe { ${lpErrnoName}.read() }\n"
    content += "        return windows_core.Result<${resultType}>.Err(windows_core.errorFromWin32(UInt32(error__)))\n"
    content += "    }\n"
    if (preservesStatus) {
        content += "    windows_core.Result<Int32>.Ok(result__)\n"
    } else {
        content += "    windows_core.Result<Unit>.Ok(())\n"
    }
    content += "}\n"
    return content
}

func renderNativeWinSockInvalidSocketCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let returnType = nativePublicType(spec.method.signature.returnType, symbolsByName, spec.ownerFullName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${returnType}> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (windows_polyfill.handlePointerIsMinusOne(result__.Value)) {\n"
    content += "        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n"
    content += "        let error__ = unsafe { errorProc__() }\n"
    content += "        return windows_core.Result<${returnType}>.Err(windows_core.errorFromWin32(UInt32(error__)))\n"
    content += "    }\n"
    content += "    windows_core.Result<${returnType}>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeWaitFailedUInt32CheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<WAIT_EVENT> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ == 0xFFFFFFFFu32) {\n"
    content += "        return windows_core.Result<WAIT_EVENT>.Err(windows_core.errorFromThread())\n"
    content += "    }\n"
    content += "    windows_core.Result<WAIT_EVENT>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeDirectWin32ErrorCodeUInt32CheckedWrapper(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Unit> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ != 0u32) {\n"
    content += "        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n"
    content += "    }\n"
    content += "    windows_core.Result<Unit>.Ok(())\n"
    content += "}\n"
    return content
}

func renderNativeDirectWin32ErrorCodeInt32CheckedWrapper(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Unit> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ != 0) {\n"
    content += "        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n"
    content += "    }\n"
    content += "    windows_core.Result<Unit>.Ok(())\n"
    content += "}\n"
    return content
}

func renderNativeDirectWin32ErrorCodeInt32StatusCheckedWrapper(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var successCondition = "result__ == 0"
    match (nativeDirectWin32ErrorCodeInt32StatusSuccessCondition(spec.method, "result__")) {
        case Some(condition) => successCondition = condition
        case None => ()
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<Int32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (${successCondition}) {\n"
    content += "        return windows_core.Result<Int32>.Ok(result__)\n"
    content += "    }\n"
    content += "    windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))\n"
    content += "}\n"
    return content
}

func renderNativeDirectWin32ErrorCodeUInt32StatusCheckedWrapper(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var successCondition = "result__ == 0u32"
    match (nativeDirectWin32ErrorCodeUInt32StatusSuccessCondition(spec.method, "result__")) {
        case Some(condition) => successCondition = condition
        case None => ()
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<UInt32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (${successCondition}) {\n"
    content += "        return windows_core.Result<UInt32>.Ok(result__)\n"
    content += "    }\n"
    content += "    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))\n"
    content += "}\n"
    return content
}

func renderNativeUInt32LessThanOrEqualCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    var threshold = "0u32"
    match (nativeUInt32ReturnLessThanOrEqualFailureThreshold(spec.method.name)) {
        case Some(value) => threshold = value
        case None => ()
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<UInt32> {\n"
    content += "    let result__ = ${methodName}(${args})\n"
    content += "    if (result__ <= ${threshold}) {\n"
    content += "        return windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))\n"
    content += "    }\n"
    content += "    windows_core.Result<UInt32>.Ok(result__)\n"
    content += "}\n"
    return content
}

func renderNativeHResultCheckedWrapper(spec: NativeFunctionSpec, symbolsByName: HashMap<String, SymbolRecord>): String {
    let methodName = cjIdentifier(spec.method.name)
    let publicParams = nativeFunctionParameterText(spec, symbolsByName)
    let args = nativeFunctionPublicArgumentText(spec, symbolsByName)
    let comOutSlots = nativeHResultComOutSlots(spec, symbolsByName)
    let stringOutSlots = nativeHResultStringOutSlots(spec, symbolsByName)
    let ownedPointerOutSlots = nativeHResultOwnedPointerOutSlots(spec, symbolsByName)
    let borrowedOptionalOutSlots = nativeHResultBorrowedOptionalOutSlots(spec, symbolsByName)
    let optionalScalarOutSlots = nativeHResultOptionalScalarOutSlots(spec, symbolsByName)
    let requiredOutSlotCount = comOutSlots.size + nativeRequiredStringOutSlotCount(stringOutSlots) +
        ownedPointerOutSlots.size
    let cleanupOutSlotCount = comOutSlots.size + stringOutSlots.size + ownedPointerOutSlots.size +
        borrowedOptionalOutSlots.size + optionalScalarOutSlots.size
    let preserveStatus = nativeMethodCanReturnMultipleSuccessValues(spec.method)
    let resultType = if (preserveStatus) {
        "windows_core.HRESULT"
    } else {
        "Unit"
    }
    let hresultFailureResult = nativeHResultFailureResultExpression(resultType, "resultHr__")
    let nullSlotFlagName = if (stringOutSlots.isEmpty()) {
        "nullComOutSlot__"
    } else {
        "nullOutSlot__"
    }
    var content = "public func ${methodName}Checked(${publicParams}): windows_core.Result<${resultType}> {\n"
    if (requiredOutSlotCount > 1) {
        content += "    var ${nullSlotFlagName} = false\n"
        for (slot in comOutSlots) {
            content += "    if (${nativeComOutSlotExpression(slot)}.isNull()) {\n"
            content += "        ${nullSlotFlagName} = true\n"
            content += "    } else {\n"
            content += "        unsafe { ${nativeComOutSlotExpression(slot)}.write(CPointer<Unit>()) }\n"
            content += "    }\n"
        }
        for (slot in stringOutSlots) {
            if (!slot.allowNullSlot) {
                content += "    if (${nativeStringOutSlotExpression(slot)}.isNull()) {\n"
                content += "        ${nullSlotFlagName} = true\n"
                content += "    } else {\n"
                content += "        unsafe { ${nativeStringOutSlotExpression(slot)}.write(CPointer<Unit>()) }\n"
                content += "    }\n"
            }
        }
        for (slot in ownedPointerOutSlots) {
            content += "    if (${nativeOwnedPointerOutSlotExpression(slot)}.isNull()) {\n"
            content += "        ${nullSlotFlagName} = true\n"
            content += "    } else {\n"
            content += "        unsafe { ${nativeOwnedPointerOutSlotExpression(slot)}.write(CPointer<Unit>()) }\n"
            content += "    }\n"
        }
        content += "    if (${nullSlotFlagName}) {\n"
        content += "        return ${nativeEPointerResultExpression(resultType)}\n"
        content += "    }\n"
    } else {
        for (slot in comOutSlots) {
            content += "    if (${nativeComOutSlotExpression(slot)}.isNull()) {\n"
            content += "        return ${nativeEPointerResultExpression(resultType)}\n"
            content += "    }\n"
            content += "    unsafe { ${nativeComOutSlotExpression(slot)}.write(CPointer<Unit>()) }\n"
        }
        for (slot in stringOutSlots) {
            if (!slot.allowNullSlot) {
                content += "    if (${nativeStringOutSlotExpression(slot)}.isNull()) {\n"
                content += "        return ${nativeEPointerResultExpression(resultType)}\n"
                content += "    }\n"
                content += "    unsafe { ${nativeStringOutSlotExpression(slot)}.write(CPointer<Unit>()) }\n"
            }
        }
        for (slot in ownedPointerOutSlots) {
            content += "    if (${nativeOwnedPointerOutSlotExpression(slot)}.isNull()) {\n"
            content += "        return ${nativeEPointerResultExpression(resultType)}\n"
            content += "    }\n"
            content += "    unsafe { ${nativeOwnedPointerOutSlotExpression(slot)}.write(CPointer<Unit>()) }\n"
        }
    }
    content += nativePreclearOptionalHResultOutSlots(
        stringOutSlots,
        borrowedOptionalOutSlots,
        optionalScalarOutSlots,
        "    "
    )
    if (cleanupOutSlotCount == 0) {
        if (preserveStatus) {
            content += "    let resultHr__ = windows_core.HRESULT(${methodName}(${args}))\n"
            content += "    if (resultHr__.failed()) {\n"
            content += "        return ${hresultFailureResult}\n"
            content += "    }\n"
            content += "    windows_core.Result<${resultType}>.Ok(resultHr__)\n"
        } else {
            content += "    windows_core.HRESULT(${methodName}(${args})).ok()\n"
        }
    } else {
        content += "    let resultHr__ = windows_core.HRESULT(${methodName}(${args}))\n"
        content += "    if (resultHr__.failed()) {\n"
        content += nativeReleaseFailedHResultOutSlots(
            comOutSlots,
            stringOutSlots,
            ownedPointerOutSlots,
            borrowedOptionalOutSlots,
            optionalScalarOutSlots,
            "        "
        )
        content += "        return ${hresultFailureResult}\n"
        content += "    }\n"
        for (slot in comOutSlots) {
            content += "    if (unsafe { ${nativeComOutSlotExpression(slot)}.read() }.isNull()) {\n"
            content += nativeReleaseFailedHResultOutSlots(
                comOutSlots,
                stringOutSlots,
                ownedPointerOutSlots,
                borrowedOptionalOutSlots,
                optionalScalarOutSlots,
                "        "
            )
            content += "        return ${nativeEPointerResultExpression(resultType)}\n"
            content += "    }\n"
        }
        for (slot in stringOutSlots) {
            if (!slot.allowNullSlot) {
                content += "    if (unsafe { ${nativeStringOutSlotExpression(slot)}.read() }.isNull()) {\n"
                content += nativeReleaseFailedHResultOutSlots(
                    comOutSlots,
                    stringOutSlots,
                    ownedPointerOutSlots,
                    borrowedOptionalOutSlots,
                    optionalScalarOutSlots,
                    "        "
                )
                content += "        return ${nativeEPointerResultExpression(resultType)}\n"
                content += "    }\n"
            }
        }
        for (slot in ownedPointerOutSlots) {
            content += "    if (unsafe { ${nativeOwnedPointerOutSlotExpression(slot)}.read() }.isNull()) {\n"
            content += nativeReleaseFailedHResultOutSlots(
                comOutSlots,
                stringOutSlots,
                ownedPointerOutSlots,
                borrowedOptionalOutSlots,
                optionalScalarOutSlots,
                "        "
            )
            content += "        return ${nativeEPointerResultExpression(resultType)}\n"
            content += "    }\n"
        }
        if (preserveStatus) {
            content += "    windows_core.Result<${resultType}>.Ok(resultHr__)\n"
        } else {
            content += "    windows_core.Result<Unit>.Ok(())\n"
        }
    }
    content += "}\n"
    return content
}

func nativeMethodNeedsHResultCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    nativeSignatureIsHResult(method.signature.returnType, symbolsByName, ownerFullName)
}

func nativeSignatureIsHResult(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return nativeHResultType(fullName).isSome()
        case None => return false
    }
}

func nativeHResultComOutSlots(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<ParameterPair> {
    let slots = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(spec.method)
    let arrayInfos = nativeArrayParameterInfos(spec, symbolsByName)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
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
            case Some(_) =>
                index += 1
                continue
            case None => ()
        }
        match (parameter) {
            case Some(value) =>
                if (nativeHResultParameterIsComOutSlot(
                    value,
                    signature,
                    symbolsByName,
                    spec.ownerFullName
                )) {
                    let name = interfaceParameterName(parameter, index)
                    let typeName = nativePublicType(signature, symbolsByName, spec.ownerFullName)
                    slots.add(ParameterPair(name, typeName))
                }
            case None => ()
        }
        index += 1
    }
    return slots
}

func nativeHResultStringOutSlots(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<NativeHResultStringOutSlot> {
    let slots = ArrayList<NativeHResultStringOutSlot>()
    let metadataParameters = metadataMethodParameters(spec.method)
    let arrayInfos = nativeArrayParameterInfos(spec, symbolsByName)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
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
            case Some(_) =>
                index += 1
                continue
            case None => ()
        }
        match (nativeHResultStringOutAllocator(spec.method, parameter, signature, symbolsByName, spec.ownerFullName)) {
            case Some(allocator) =>
                let name = interfaceParameterName(parameter, index)
                let typeName = nativePublicType(signature, symbolsByName, spec.ownerFullName)
                slots.add(NativeHResultStringOutSlot(
                    ParameterPair(name, typeName),
                    allocator,
                    allowNullSlot: nativeHResultStringOutSlotAllowsNull(spec.method, parameter)
                ))
            case None => ()
        }
        index += 1
    }
    return slots
}

func nativeHResultOwnedPointerOutSlots(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<NativeHResultOwnedPointerOutSlot> {
    let slots = ArrayList<NativeHResultOwnedPointerOutSlot>()
    let metadataParameters = metadataMethodParameters(spec.method)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        match (nativeHResultOwnedPointerOutAllocator(
            spec.method,
            parameter,
            signature,
            symbolsByName,
            spec.ownerFullName
        )) {
            case Some(allocator) =>
                let name = interfaceParameterName(parameter, index)
                let typeName = nativePublicType(signature, symbolsByName, spec.ownerFullName)
                slots.add(NativeHResultOwnedPointerOutSlot(ParameterPair(name, typeName), allocator))
            case None => ()
        }
        index += 1
    }
    return slots
}

func nativeHResultBorrowedOptionalOutSlots(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<NativeHResultBorrowedOptionalOutSlot> {
    let slots = ArrayList<NativeHResultBorrowedOptionalOutSlot>()
    let metadataParameters = metadataMethodParameters(spec.method)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        match (parameter) {
            case Some(value) =>
                if (nativeHResultParameterIsBorrowedOptionalOutSlot(spec.method, value, signature)) {
                    let name = interfaceParameterName(parameter, index)
                    let typeName = nativePublicType(signature, symbolsByName, spec.ownerFullName)
                    slots.add(NativeHResultBorrowedOptionalOutSlot(ParameterPair(name, typeName)))
                }
            case None => ()
        }
        index += 1
    }
    return slots
}

func nativeHResultOptionalScalarOutSlots(
    spec: NativeFunctionSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<NativeHResultOptionalScalarOutSlot> {
    let slots = ArrayList<NativeHResultOptionalScalarOutSlot>()
    let metadataParameters = metadataMethodParameters(spec.method)
    var index: Int64 = 0
    while (index < Int64(spec.method.signature.parameters.size)) {
        let signature = spec.method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        match (parameter) {
            case Some(value) =>
                match (nativeHResultOptionalScalarOutSlotDefaultValue(
                    spec.method,
                    value,
                    signature,
                    symbolsByName,
                    spec.ownerFullName
                )) {
                    case Some(defaultValue) =>
                        let name = interfaceParameterName(parameter, index)
                        let typeName = nativePublicType(signature, symbolsByName, spec.ownerFullName)
                        slots.add(NativeHResultOptionalScalarOutSlot(ParameterPair(name, typeName), defaultValue))
                    case None => ()
                }
            case None => ()
        }
        index += 1
    }
    return slots
}

func nativeHResultParameterIsComOutSlot(
    parameter: ParameterRecord,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!contains(parameter.attributes, "Out")) {
        return false
    }
    if (signaturePointerTarget(signature).isNone()) {
        return false
    }
    if (parameterHasComOutPtrAttribute(parameter)) {
        return true
    }
    return nativeSignaturePointerTargetsComInterface(signature, symbolsByName, ownerFullName)
}

func nativeHResultParameterIsBorrowedOptionalOutSlot(
    method: MethodRecord,
    parameter: ParameterRecord,
    signature: SignatureRecord
): Bool {
    if (!contains(parameter.attributes, "Out") || !contains(parameter.attributes, "Optional")) {
        return false
    }
    if (contains(parameter.attributes, "In")) {
        return false
    }
    if (!nativeSignatureIsPointerToPointer(signature)) {
        return false
    }
    let importName = pinvokeImportName(method)
    if (importName == "CoQueryProxyBlanket") {
        return parameter.name == "pAuthInfo"
    }
    if (importName == "CoQueryClientBlanket") {
        return parameter.name == "pPrivs"
    }
    return false
}

func nativeHResultOptionalScalarOutSlotDefaultValue(
    method: MethodRecord,
    parameter: ParameterRecord,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    if (!contains(parameter.attributes, "Out") || !contains(parameter.attributes, "Optional")) {
        return None
    }
    if (contains(parameter.attributes, "In") || nativeSignatureIsPointerToPointer(signature)) {
        return None
    }
    if (signaturePointerTarget(signature).isNone()) {
        return None
    }
    match (nativeHResultOptionalScalarOutSlotExpectedType(method, parameter)) {
        case Some(expectedType) =>
            match (signaturePointerTarget(signature)) {
                case Some(target) =>
                    let elementType = nativePublicPointerElementType(target, symbolsByName, ownerFullName)
                    if (elementType == expectedType) {
                        return Some(cjDefaultValue(elementType))
                    }
                case None => ()
            }
        case None => ()
    }
    return None
}

func nativeHResultOptionalScalarOutSlotExpectedType(
    method: MethodRecord,
    parameter: ParameterRecord
): Option<String> {
    if (parameter.name != "key") {
        return None
    }
    let importName = pinvokeImportName(method)
    if (importName == "RtwqPutWaitingWorkItem" || importName == "RtwqScheduleWorkItem") {
        return Some("UInt64")
    }
    if (importName == "RtwqAddPeriodicCallback") {
        return Some("UInt32")
    }
    return None
}

func nativeHResultStringOutAllocator(
    method: MethodRecord,
    parameter: Option<ParameterRecord>,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (parameter) {
        case Some(value) =>
            if (!contains(value.attributes, "Out")) {
                return None
            }
        case None => return None
    }
    if (!nativeSignaturePointerTargetsOwnedPwstr(signature, symbolsByName, ownerFullName)) {
        return None
    }
    let importName = pinvokeImportName(method)
    if (importName == "GetThreadDescription") {
        return Some("LocalFree")
    }
    if (importName == "StringFromCLSID" || importName == "StringFromIID" ||
        importName == "ProgIDFromCLSID") {
        return Some("CoTaskMemFree")
    }
    if (importName == "CoQueryProxyBlanket" || importName == "CoQueryClientBlanket") {
        return Some("CoTaskMemFree")
    }
    return None
}

func nativeHResultOwnedPointerOutAllocator(
    method: MethodRecord,
    parameter: Option<ParameterRecord>,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (parameter) {
        case Some(value) =>
            if (!contains(value.attributes, "Out")) {
                return None
            }
            let importName = pinvokeImportName(method)
            if (importName == "CoGetSystemSecurityPermissions" && value.name == "ppSD") {
                match (nativeSignaturePointerTargetFullName(signature, symbolsByName, ownerFullName)) {
                    case Some(fullName) =>
                        if (fullName == "Windows.Win32.Security.PSECURITY_DESCRIPTOR") {
                            return Some("LocalFree")
                        }
                    case None => ()
                }
            }
            if (importName == "CoQueryAuthenticationServices" && value.name == "asAuthSvc") {
                match (nativeSignaturePointerPointerTargetFullName(signature, symbolsByName, ownerFullName)) {
                    case Some(fullName) =>
                        if (fullName == "Windows.Win32.System.Com.SOLE_AUTHENTICATION_SERVICE") {
                            return Some("CoTaskMemFree")
                        }
                    case None => ()
                }
            }
        case None => ()
    }
    return None
}

func nativeHResultStringOutSlotAllowsNull(method: MethodRecord, parameter: Option<ParameterRecord>): Bool {
    match (parameter) {
        case Some(value) =>
            if (!contains(value.attributes, "Optional") || value.name != "pServerPrincName") {
                return false
            }
            let importName = pinvokeImportName(method)
            return importName == "CoQueryProxyBlanket" || importName == "CoQueryClientBlanket"
        case None => return false
    }
}

func nativeSignaturePointerTargetFullName(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signaturePointerTarget(signature)) {
        case Some(target) => return signatureFullNameInContext(target, symbolsByName, ownerFullName)
        case None => return None
    }
}

func nativeSignaturePointerPointerTargetFullName(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signaturePointerTarget(signature)) {
        case Some(target) => return nativeSignaturePointerTargetFullName(target, symbolsByName, ownerFullName)
        case None => return None
    }
}

func nativeSignaturePointerTargetsOwnedPwstr(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    match (signaturePointerTarget(signature)) {
        case Some(target) =>
            match (signatureFullNameInContext(target, symbolsByName, ownerFullName)) {
                case Some(fullName) => return fullName == "Windows.Win32.Foundation.PWSTR"
                case None => return false
            }
        case None => return false
    }
}

func nativeSignaturePointerTargetsComInterface(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    match (signaturePointerTarget(signature)) {
        case Some(target) =>
            match (signatureFullNameInContext(target, symbolsByName, ownerFullName)) {
                case Some(fullName) =>
                    if (nativeComInterfaceRawType(fullName).isSome()) {
                        return true
                    }
                    match (symbolsByName.get(fullName)) {
                        case Some(symbol) =>
                            match (symbol.typeDef) {
                                case Some(typeDef) => return isInterfaceType(typeDef)
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    return false
}

func nativeSignatureIsPointerToPointer(signature: SignatureRecord): Bool {
    match (signaturePointerTarget(signature)) {
        case Some(target) =>
            return target.kind == "Pointer" || isByReferenceSignature(target)
        case None => return false
    }
}

func nativeComOutSlotExpression(slot: ParameterPair): String {
    if (slot.typeName == "CPointer<CPointer<Unit>>") {
        return slot.name
    }
    return "CPointer<CPointer<Unit>>(${slot.name})"
}

func nativeStringOutSlotExpression(slot: NativeHResultStringOutSlot): String {
    if (slot.pair.typeName == "CPointer<CPointer<Unit>>") {
        return slot.pair.name
    }
    return "CPointer<CPointer<Unit>>(${slot.pair.name})"
}

func nativeOwnedPointerOutSlotExpression(slot: NativeHResultOwnedPointerOutSlot): String {
    if (slot.pair.typeName == "CPointer<CPointer<Unit>>") {
        return slot.pair.name
    }
    return "CPointer<CPointer<Unit>>(${slot.pair.name})"
}

func nativeBorrowedOptionalOutSlotExpression(slot: NativeHResultBorrowedOptionalOutSlot): String {
    return nativeComOutSlotExpression(slot.pair)
}

func nativeOptionalScalarOutSlotExpression(slot: NativeHResultOptionalScalarOutSlot): String {
    return slot.pair.name
}

func nativeRequiredStringOutSlotCount(slots: ArrayList<NativeHResultStringOutSlot>): Int64 {
    var count: Int64 = 0
    for (slot in slots) {
        if (!slot.allowNullSlot) {
            count += 1
        }
    }
    return count
}

func nativePreclearOptionalOutSlotExpression(slotExpr: String, indent: String): String {
    var content = "${indent}if (${slotExpr}.isNotNull()) {\n"
    content += "${indent}    unsafe { ${slotExpr}.write(CPointer<Unit>()) }\n"
    content += "${indent}}\n"
    return content
}

func nativePreclearOptionalHResultOutSlots(
    stringOutSlots: ArrayList<NativeHResultStringOutSlot>,
    borrowedOptionalOutSlots: ArrayList<NativeHResultBorrowedOptionalOutSlot>,
    optionalScalarOutSlots: ArrayList<NativeHResultOptionalScalarOutSlot>,
    indent: String
): String {
    var content = ""
    for (slot in stringOutSlots) {
        if (slot.allowNullSlot) {
            content += nativePreclearOptionalOutSlotExpression(nativeStringOutSlotExpression(slot), indent)
        }
    }
    for (slot in borrowedOptionalOutSlots) {
        content += nativePreclearOptionalOutSlotExpression(nativeBorrowedOptionalOutSlotExpression(slot), indent)
    }
    for (slot in optionalScalarOutSlots) {
        content += nativePreclearOptionalScalarOutSlotExpression(slot, indent)
    }
    return content
}

func nativePreclearOptionalScalarOutSlotExpression(
    slot: NativeHResultOptionalScalarOutSlot,
    indent: String
): String {
    let slotExpr = nativeOptionalScalarOutSlotExpression(slot)
    var content = "${indent}if (${slotExpr}.isNotNull()) {\n"
    content += "${indent}    unsafe { ${slotExpr}.write(${slot.defaultValue}) }\n"
    content += "${indent}}\n"
    return content
}

func nativeReleaseFailedComOutSlots(slots: ArrayList<ParameterPair>, indent: String): String {
    var content = ""
    for (slot in slots) {
        content += "${indent}windows_core.releaseFailedComOutSlot(${nativeComOutSlotExpression(slot)})\n"
    }
    return content
}

func nativeReleaseFailedHResultOutSlots(
    comOutSlots: ArrayList<ParameterPair>,
    stringOutSlots: ArrayList<NativeHResultStringOutSlot>,
    ownedPointerOutSlots: ArrayList<NativeHResultOwnedPointerOutSlot>,
    borrowedOptionalOutSlots: ArrayList<NativeHResultBorrowedOptionalOutSlot>,
    optionalScalarOutSlots: ArrayList<NativeHResultOptionalScalarOutSlot>,
    indent: String
): String {
    var content = nativeReleaseFailedComOutSlots(comOutSlots, indent)
    for (slot in stringOutSlots) {
        content += nativeReleaseFailedStringOutSlot(slot, indent)
    }
    for (slot in ownedPointerOutSlots) {
        content += nativeReleaseFailedOwnedPointerOutSlot(slot, indent)
    }
    content += nativeReleaseFailedBorrowedOptionalOutSlots(borrowedOptionalOutSlots, indent)
    content += nativeReleaseFailedOptionalScalarOutSlots(optionalScalarOutSlots, indent)
    return content
}

func nativeReleaseFailedBorrowedOptionalOutSlots(
    slots: ArrayList<NativeHResultBorrowedOptionalOutSlot>,
    indent: String
): String {
    var content = ""
    for (slot in slots) {
        content += nativePreclearOptionalOutSlotExpression(nativeBorrowedOptionalOutSlotExpression(slot), indent)
    }
    return content
}

func nativeReleaseFailedOptionalScalarOutSlots(
    slots: ArrayList<NativeHResultOptionalScalarOutSlot>,
    indent: String
): String {
    var content = ""
    for (slot in slots) {
        content += nativePreclearOptionalScalarOutSlotExpression(slot, indent)
    }
    return content
}

func nativeReleaseFailedStringOutSlot(slot: NativeHResultStringOutSlot, indent: String): String {
    let slotExpr = nativeStringOutSlotExpression(slot)
    var content = "${indent}if (${slotExpr}.isNotNull()) {\n"
    content += "${indent}    let failedString__ = unsafe { ${slotExpr}.read() }\n"
    content += "${indent}    if (failedString__.isNotNull()) {\n"
    if (slot.allocator == "LocalFree") {
        content += "${indent}        let localFreeString__ = CFunc<(CPointer<Unit>) -> CPointer<Unit>>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"LocalFree\"))\n"
        content += "${indent}        let _ = unsafe { localFreeString__(failedString__) }\n"
    } else if (slot.allocator == "CoTaskMemFree") {
        content += "${indent}        let coTaskMemFreeString__ = CFunc<(CPointer<Unit>) -> Unit>(windows_libloading.resolveProc(\"OLE32.dll\", \"CoTaskMemFree\"))\n"
        content += "${indent}        unsafe { coTaskMemFreeString__(failedString__) }\n"
    }
    content += "${indent}        unsafe { ${slotExpr}.write(CPointer<Unit>()) }\n"
    content += "${indent}    }\n"
    content += "${indent}}\n"
    return content
}

func nativeReleaseFailedOwnedPointerOutSlot(slot: NativeHResultOwnedPointerOutSlot, indent: String): String {
    let slotExpr = nativeOwnedPointerOutSlotExpression(slot)
    var content = "${indent}if (${slotExpr}.isNotNull()) {\n"
    content += "${indent}    let failedPointer__ = unsafe { ${slotExpr}.read() }\n"
    content += "${indent}    if (failedPointer__.isNotNull()) {\n"
    if (slot.allocator == "LocalFree") {
        content += "${indent}        let localFreePointer__ = CFunc<(CPointer<Unit>) -> CPointer<Unit>>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"LocalFree\"))\n"
        content += "${indent}        let _ = unsafe { localFreePointer__(failedPointer__) }\n"
    } else if (slot.allocator == "CoTaskMemFree") {
        content += "${indent}        let coTaskMemFreePointer__ = CFunc<(CPointer<Unit>) -> Unit>(windows_libloading.resolveProc(\"OLE32.dll\", \"CoTaskMemFree\"))\n"
        content += "${indent}        unsafe { coTaskMemFreePointer__(failedPointer__) }\n"
    }
    content += "${indent}        unsafe { ${slotExpr}.write(CPointer<Unit>()) }\n"
    content += "${indent}    }\n"
    content += "${indent}}\n"
    return content
}

func nativeEPointerResultExpression(resultType: String): String {
    "windows_core.Result<${resultType}>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))"
}

func nativeHResultFailureResultExpression(resultType: String, hresultName: String): String {
    if (resultType == "Unit") {
        return "${hresultName}.ok()"
    }
    "windows_core.Result<${resultType}>.Err(windows_core.errorFromHRESULT(${hresultName}))"
}

func nativeMethodNeedsSetLastErrorCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (nativeMethodNeedsWinSockBoolCheckedWrapper(method, symbolsByName, ownerFullName)) {
        return false
    }
    if (nativeMethodNeedsSetLastErrorBoolStatusCheckedWrapper(method, symbolsByName, ownerFullName)) {
        return false
    }
    if (nativeMethodNeedsSetLastErrorBoolFalseSuccessCheckedWrapper(method, symbolsByName, ownerFullName)) {
        return false
    }
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (nativeMethodCanReturnMultipleSuccessValues(method) &&
        !nativeMultipleSuccessBoolUsesZeroFailure(method.name)) {
        return false
    }
    if (nativeBoolReturnCannotUseCheckedWrapper(method.name)) {
        return false
    }
    if (nativeMethodReturnsSemanticBool(method)) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, ownerFullName)
    return returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)
}

func nativeMethodNeedsSetLastErrorBoolStatusCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (nativeSetLastErrorBoolStatusSuccessCondition(method, "lastError__").isNone()) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, ownerFullName)
    return returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)
}

func nativeMethodNeedsSetLastErrorBoolFalseSuccessCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (nativeBoolReturnFalseSuccessStatuses(method.name).isEmpty()) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, ownerFullName)
    return returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)
}

func nativeMethodNeedsWinSockBoolCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (nativeMethodNeedsWinSockWaitEventCheckedWrapper(method, symbolsByName, ownerFullName)) {
        return false
    }
    if (!nativeMethodSetsLastError(method)) {
        if (nativeWinSockBoolPendingSuccessStatus(method.name).isNone()) {
            return false
        }
    }
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll") &&
        !nativeMethodImportsFromModule(method, "MSWSOCK.dll")) {
        return false
    }
    if (!nativeWinSockBoolReturnUsesSocketError(method.name)) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, ownerFullName)
    return returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)
}

func nativeMethodNeedsSetLastErrorHandleCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (nativeMethodNeedsWinSockNullHandleCheckedWrapper(method, symbolsByName, ownerFullName)) {
        return false
    }
    if (nativeMethodCanReturnMultipleSuccessValues(method)) {
        return false
    }
    if (!nativeHandleReturnUsesNullFailure(method.name)) {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return nativeSetLastErrorNullHandleReturnType(fullName)
        case None => return false
    }
}

func nativeMethodNeedsWinSockNullHandleCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (!nativeWinSockHandleReturnUsesNullFailure(method.name)) {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return fullName == "Windows.Win32.Foundation.HANDLE"
        case None => return false
    }
}

func nativeMethodNeedsWinSockInvalidEventCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (!nativeWinSockEventReturnUsesInvalidEvent(method.name)) {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return fullName == "Windows.Win32.Networking.WinSock.WSAEVENT"
        case None => return false
    }
}

func nativeMethodNeedsSetLastErrorInvalidHandleCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeHandleReturnUsesInvalidHandleFailure(method.name)) {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return fullName == "Windows.Win32.Foundation.HANDLE"
        case None => return false
    }
}

func nativeMethodNeedsSetLastErrorNullSuccessHandleCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return nativeSetLastErrorNullSuccessHandleReturnType(method.name, fullName)
        case None => return false
    }
}

func nativeMethodNeedsSetLastErrorWaitEventCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (nativeMethodNeedsWinSockWaitEventCheckedWrapper(method, symbolsByName, ownerFullName)) {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return fullName == "Windows.Win32.Foundation.WAIT_EVENT"
        case None => return false
    }
}

func nativeMethodNeedsWinSockWaitEventCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (method.name != "WSAWaitForMultipleEvents") {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return fullName == "Windows.Win32.Foundation.WAIT_EVENT"
        case None => return false
    }
}

func nativeMethodNeedsSetLastErrorPointerCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (nativeMethodNeedsWinSockNullPointerCheckedWrapper(method, symbolsByName, ownerFullName)) {
        return false
    }
    if (!nativePointerReturnUsesNullFailure(method.name)) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    return method.signature.returnType.kind == "Pointer" && startsWithString(returnType, "CPointer<")
}

func nativeMethodNeedsWinSockNullPointerCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (!nativeWinSockPointerReturnUsesNullFailure(method.name)) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    return method.signature.returnType.kind == "Pointer" && startsWithString(returnType, "CPointer<")
}

func nativeMethodNeedsSetLastErrorTlsValueCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (method.name != "TlsGetValue" && method.name != "FlsGetValue") {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "CPointer<Unit>"
}

func nativeMethodNeedsSetLastErrorUInt32MinusOneCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeUInt32ReturnUsesMinusOneFailure(method.name)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UInt32"
}

func nativeMethodNeedsSetLastErrorUInt32ZeroLastErrorCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (method.name != "GetGuiResources") {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UInt32"
}

func nativeMethodNeedsSetLastErrorUInt32ZeroCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeUInt32ReturnUsesZeroFailure(method.name)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UInt32"
}

func nativeMethodNeedsSetLastErrorUIntNativeZeroCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (method.name != "SetThreadAffinityMask") {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UIntNative"
}

func nativeMethodNeedsSetLastErrorIntNativeZeroLastErrorCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeIntNativeReturnUsesZeroLastErrorFailure(method.name)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "IntNative"
}

func nativeMethodNeedsSetLastErrorInt32MaxCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (method.name != "GetThreadPriority") {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsSetLastErrorInt32MinusOneCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeBoolReturnUsesMinusOneFailure(method.name)) {
        return false
    }
    return nativeRawType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsWinSockInvalidSocketCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (!nativeWinSockReturnUsesInvalidSocket(method.name)) {
        return false
    }
    match (signatureFullNameInContext(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(fullName) => return fullName == "Windows.Win32.Networking.WinSock.SOCKET"
        case None => return false
    }
}

func nativeMethodNeedsWinSockSocketErrorInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll") &&
        !nativeMethodImportsFromModule(method, "MSWSOCK.dll")) {
        return false
    }
    if (!nativeWinSockInt32ReturnUsesSocketError(method.name)) {
        return false
    }
    if (!nativeMethodSetsLastError(method) && !nativeWinSockInt32CanUseWSAGetLastErrorWithoutMetadata(method.name)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsMswsockGetLastErrorSocketErrorInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodSetsLastError(method)) {
        return false
    }
    if (!nativeMethodImportsFromModule(method, "MSWSOCK.dll")) {
        return false
    }
    if (!nativeMswsockInt32ReturnUsesGetLastErrorSocketError(method.name)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsWinSockDirectErrorInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (!nativeWinSockInt32ReturnUsesDirectError(method.name)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsWinSockPendingStatusInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (nativeWinSockInt32ReturnPendingStatus(method.name).isNone()) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsWinSockLpErrnoInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return false
    }
    if (!nativeWinSockInt32ReturnUsesLpErrno(method.name)) {
        return false
    }
    if (nativeWinSockLpErrnoParameterName(method).isEmpty()) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsWaitFailedUInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (method.name != "WaitForInputIdle") {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UInt32"
}

func nativeMethodNeedsDirectWin32ErrorCodeInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeDirectWin32ErrorCodeInt32ReturnUsesUnit(method)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsDirectWin32ErrorCodeInt32StatusCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (nativeDirectWin32ErrorCodeInt32StatusSuccessCondition(method, "result__").isNone()) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "Int32"
}

func nativeMethodNeedsDirectWin32ErrorCodeUInt32CheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeDirectWin32ErrorCodeUInt32ReturnUsesUnit(method)) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UInt32"
}

func nativeMethodNeedsDirectWin32ErrorCodeUInt32StatusCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (nativeDirectWin32ErrorCodeUInt32StatusSuccessCondition(method, "result__").isNone()) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UInt32"
}

func nativeMethodNeedsUInt32LessThanOrEqualCheckedWrapper(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (nativeUInt32ReturnLessThanOrEqualFailureThreshold(method.name).isNone()) {
        return false
    }
    return nativePublicType(method.signature.returnType, symbolsByName, ownerFullName) == "UInt32"
}

func nativeSetLastErrorNullSuccessHandleReturnType(name: String, fullName: String): Bool {
    return (name == "GlobalFree" && fullName == "Windows.Win32.Foundation.HGLOBAL") ||
        (name == "LocalFree" && fullName == "Windows.Win32.Foundation.HLOCAL")
}

func nativeSetLastErrorNullHandleReturnType(fullName: String): Bool {
    return fullName == "Windows.Win32.Foundation.HANDLE" ||
        fullName == "Windows.Win32.System.Services.SC_HANDLE" ||
        fullName == "Windows.Win32.System.Services.SERVICE_STATUS_HANDLE" ||
        fullName == "Windows.Win32.System.Threading.AVRT_TASK_HANDLE" ||
        fullName == "Windows.Win32.System.Threading.PTP_CLEANUP_GROUP" ||
        fullName == "Windows.Win32.System.Threading.PTP_IO" ||
        fullName == "Windows.Win32.System.Threading.PTP_POOL" ||
        fullName == "Windows.Win32.System.Threading.PTP_TIMER" ||
        fullName == "Windows.Win32.System.Threading.PTP_WAIT" ||
        fullName == "Windows.Win32.System.Threading.PTP_WORK"
}

func nativeHandleReturnUsesNullFailure(name: String): Bool {
    return !nativeHandleReturnUsesInvalidHandleFailure(name)
}

func nativeHandleReturnUsesInvalidHandleFailure(name: String): Bool {
    return name == "CreateFileA" || name == "CreateFileW" ||
        name == "FindFirstChangeNotificationA" ||
        name == "FindFirstChangeNotificationW" ||
        name == "FindFirstFileA" ||
        name == "FindFirstFileW" ||
        name == "FindFirstFileExA" ||
        name == "FindFirstFileExW" ||
        name == "FindFirstFileNameW" ||
        name == "FindFirstFileNameTransactedW" ||
        name == "FindFirstFileTransactedA" ||
        name == "FindFirstFileTransactedW" ||
        name == "FindFirstStreamW" ||
        name == "FindFirstStreamTransactedW" ||
        name == "FindFirstVolumeA" ||
        name == "FindFirstVolumeW" ||
        name == "FindFirstVolumeMountPointA" ||
        name == "FindFirstVolumeMountPointW"
}

func nativePointerReturnUsesNullFailure(name: String): Bool {
    return name == "LockServiceDatabase" ||
        name == "CreateFiberEx" ||
        name == "ConvertThreadToFiberEx" ||
        name == "CreateFiber" ||
        name == "ConvertThreadToFiber" ||
        name == "CertCreateCertificateContext"
}

func nativeWinSockHandleReturnUsesNullFailure(name: String): Bool {
    return name == "WSAAsyncGetServByName" ||
        name == "WSAAsyncGetServByPort" ||
        name == "WSAAsyncGetProtoByName" ||
        name == "WSAAsyncGetProtoByNumber" ||
        name == "WSAAsyncGetHostByName" ||
        name == "WSAAsyncGetHostByAddr"
}

func nativeWinSockEventReturnUsesInvalidEvent(name: String): Bool {
    return name == "WSACreateEvent"
}

func nativeWinSockPointerReturnUsesNullFailure(name: String): Bool {
    return name == "gethostbyaddr" ||
        name == "gethostbyname" ||
        name == "getservbyport" ||
        name == "getservbyname" ||
        name == "getprotobynumber" ||
        name == "getprotobyname"
}

func nativeUInt32ReturnUsesMinusOneFailure(name: String): Bool {
    return name == "FlsAlloc" ||
        name == "TlsAlloc" ||
        name == "SuspendThread" ||
        name == "ResumeThread" ||
        name == "SetThreadIdealProcessor" ||
        name == "Wow64SuspendThread" ||
        name == "GetFileAttributesA" ||
        name == "GetFileAttributesW"
}

func nativeUInt32ReturnUsesZeroFailure(name: String): Bool {
    return name == "GetSystemDirectoryA" ||
        name == "GetSystemDirectoryW" ||
        name == "GetWindowsDirectoryA" ||
        name == "GetWindowsDirectoryW" ||
        name == "GetSystemWindowsDirectoryA" ||
        name == "GetSystemWindowsDirectoryW" ||
        name == "EnumSystemFirmwareTables" ||
        name == "GetSystemFirmwareTable" ||
        name == "GetSystemWow64DirectoryA" ||
        name == "GetSystemWow64DirectoryW" ||
        name == "GetSystemWow64Directory2A" ||
        name == "GetSystemWow64Directory2W" ||
        name == "QueueUserAPC" ||
        name == "GetProcessVersion" ||
        name == "GetPriorityClass" ||
        name == "GetProcessId" ||
        name == "GetThreadId" ||
        name == "GetProcessIdOfThread" ||
        name == "GetActiveProcessorCount" ||
        name == "GetMaximumProcessorCount" ||
        name == "GetFileVersionInfoSizeA" ||
        name == "GetFileVersionInfoSizeW" ||
        name == "QueryDosDeviceA" ||
        name == "QueryDosDeviceW"
}

func nativeUInt32ReturnLessThanOrEqualFailureThreshold(name: String): Option<String> {
    if (name == "WinExec") {
        return Some("31u32")
    }
    return None
}

func nativeDirectWin32ErrorCodeUInt32ReturnUsesUnit(method: MethodRecord): Bool {
    if (nativeMethodImportsFromModule(method, "HTTPAPI.dll")) {
        return nativeHttpApiUInt32ReturnUsesDirectErrorCodeUnit(method.name)
    }
    if (nativeMethodImportsFromModule(method, "WINHTTP.dll")) {
        return nativeWinHttpUInt32ReturnUsesDirectErrorCodeUnit(method.name)
    }
    if (nativeMethodImportsFromModule(method, "DNSAPI.dll")) {
        return nativeDnsApiUInt32ReturnUsesDirectErrorCodeUnit(method.name)
    }
    return false
}

func nativeDirectWin32ErrorCodeInt32ReturnUsesUnit(method: MethodRecord): Bool {
    if (nativeMethodImportsFromModule(method, "DNSAPI.dll")) {
        return nativeDnsApiInt32ReturnUsesDirectErrorCodeUnit(method.name)
    }
    return false
}

func nativeDirectWin32ErrorCodeUInt32StatusSuccessCondition(method: MethodRecord, resultName: String): Option<String> {
    if (nativeMethodImportsFromModule(method, "HTTPAPI.dll")) {
        return nativeHttpApiUInt32ReturnUsesDirectErrorCodeStatus(method.name, resultName)
    }
    if (nativeMethodImportsFromModule(method, "WINHTTP.dll")) {
        return nativeWinHttpUInt32ReturnUsesDirectErrorCodeStatus(method.name, resultName)
    }
    if (nativeMethodImportsFromModule(method, "WS2_32.dll")) {
        return nativeWinSockUInt32ReturnUsesDirectErrorCodeStatus(method.name, resultName)
    }
    if (nativeMethodImportsFromModule(method, "DNSAPI.dll")) {
        return nativeDnsApiUInt32ReturnUsesDirectErrorCodeStatus(method.name, resultName)
    }
    return None
}

func nativeDirectWin32ErrorCodeInt32StatusSuccessCondition(method: MethodRecord, resultName: String): Option<String> {
    if (nativeMethodImportsFromModule(method, "DNSAPI.dll")) {
        return nativeDnsApiInt32ReturnUsesDirectErrorCodeStatus(method.name, resultName)
    }
    return None
}

func nativeSetLastErrorBoolStatusSuccessCondition(method: MethodRecord, lastErrorName: String): Option<String> {
    if (nativeMethodImportsFromModule(method, "WINHTTP.dll")) {
        return nativeWinHttpBoolSetLastErrorStatus(method.name, lastErrorName)
    }
    return None
}

func nativeHttpApiUInt32ReturnUsesDirectErrorCodeUnit(name: String): Bool {
    return name == "HttpInitialize" ||
        name == "HttpTerminate" ||
        name == "HttpCreateHttpHandle" ||
        name == "HttpCreateRequestQueue" ||
        name == "HttpCloseRequestQueue" ||
        name == "HttpSetRequestQueueProperty" ||
        name == "HttpCancelHttpRequest" ||
        name == "HttpShutdownRequestQueue" ||
        name == "HttpCreateServerSession" ||
        name == "HttpCloseServerSession" ||
        name == "HttpSetServerSessionProperty" ||
        name == "HttpAddUrl" ||
        name == "HttpRemoveUrl" ||
        name == "HttpCreateUrlGroup" ||
        name == "HttpCloseUrlGroup" ||
        name == "HttpAddUrlToUrlGroup" ||
        name == "HttpRemoveUrlFromUrlGroup" ||
        name == "HttpSetUrlGroupProperty" ||
        name == "HttpPrepareUrl" ||
        name == "HttpDeclarePush" ||
        name == "HttpDelegateRequestEx" ||
        name == "HttpFindUrlGroupId" ||
        name == "HttpSetServiceConfiguration" ||
        name == "HttpUpdateServiceConfiguration" ||
        name == "HttpDeleteServiceConfiguration"
}

func nativeHttpApiUInt32ReturnUsesDirectErrorCodeStatus(name: String, resultName: String): Option<String> {
    if (name == "HttpQueryRequestQueueProperty" ||
        name == "HttpQueryServerSessionProperty" ||
        name == "HttpQueryUrlGroupProperty") {
        return Some("${resultName} == 0u32 || ${resultName} == 234u32")
    }
    if (name == "HttpSetRequestProperty" ||
        name == "HttpWaitForDisconnect" ||
        name == "HttpWaitForDisconnectEx" ||
        name == "HttpWaitForDemandStart" ||
        name == "HttpFlushResponseCache" ||
        name == "HttpAddFragmentToCache") {
        return Some("${resultName} == 0u32 || ${resultName} == 997u32")
    }
    if (name == "HttpQueryRequestProperty") {
        return Some("${resultName} == 0u32 || ${resultName} == 997u32 || ${resultName} == 234u32")
    }
    if (name == "HttpReceiveClientCertificate" ||
        name == "HttpReadFragmentFromCache") {
        return Some("${resultName} == 0u32 || ${resultName} == 997u32 || ${resultName} == 122u32 || ${resultName} == 234u32")
    }
    if (name == "HttpQueryServiceConfiguration") {
        return Some("${resultName} == 0u32 || ${resultName} == 122u32 || ${resultName} == 234u32 || ${resultName} == 259u32")
    }
    if (name == "HttpReceiveHttpRequest") {
        return Some("${resultName} == 0u32 || ${resultName} == 997u32 || ${resultName} == 234u32 || ${resultName} == 38u32")
    }
    if (name == "HttpReceiveRequestEntityBody") {
        return Some("${resultName} == 0u32 || ${resultName} == 997u32 || ${resultName} == 38u32")
    }
    if (name == "HttpSendHttpResponse" || name == "HttpSendResponseEntityBody") {
        return Some("${resultName} == 0u32 || ${resultName} == 997u32")
    }
    return None
}

func nativeWinHttpUInt32ReturnUsesDirectErrorCodeUnit(name: String): Bool {
    return name == "WinHttpCreateProxyResolver" ||
        name == "WinHttpGetProxyResult" ||
        name == "WinHttpGetProxyResultEx" ||
        name == "WinHttpResetAutoProxy" ||
        name == "WinHttpWriteProxySettings" ||
        name == "WinHttpReadProxySettings" ||
        name == "WinHttpGetProxySettingsVersion" ||
        name == "WinHttpSetProxySettingsPerUser" ||
        name == "WinHttpReadDataEx" ||
        name == "WinHttpAddRequestHeadersEx" ||
        name == "WinHttpWebSocketSend" ||
        name == "WinHttpWebSocketReceive" ||
        name == "WinHttpWebSocketShutdown" ||
        name == "WinHttpWebSocketClose" ||
        name == "WinHttpRegisterProxyChangeNotification" ||
        name == "WinHttpUnregisterProxyChangeNotification" ||
        name == "WinHttpGetProxySettingsResultEx" ||
        name == "WinHttpFreeProxySettingsEx"
}

func nativeWinHttpUInt32ReturnUsesDirectErrorCodeStatus(name: String, resultName: String): Option<String> {
    if (name == "WinHttpGetProxyForUrlEx" ||
        name == "WinHttpGetProxyForUrlEx2" ||
        name == "WinHttpGetProxySettingsEx") {
        return Some("${resultName} == 997u32")
    }
    if (name == "WinHttpQueryHeadersEx") {
        return Some("${resultName} == 0u32 || ${resultName} == 122u32 || ${resultName} == 12150u32")
    }
    if (name == "WinHttpWebSocketQueryCloseStatus") {
        return Some("${resultName} == 0u32 || ${resultName} == 122u32")
    }
    return None
}

func nativeWinSockUInt32ReturnUsesDirectErrorCodeStatus(name: String, resultName: String): Option<String> {
    if (name == "ProcessSocketNotifications") {
        return Some("${resultName} == 0u32 || ${resultName} == 258u32")
    }
    return None
}

func nativeWinHttpBoolSetLastErrorStatus(name: String, lastErrorName: String): Option<String> {
    if (name == "WinHttpReceiveResponse" || name == "WinHttpSendRequest") {
        return Some("${lastErrorName} == 12032u32")
    }
    if (name == "WinHttpQueryHeaders") {
        return Some("${lastErrorName} == 122u32 || ${lastErrorName} == 12150u32")
    }
    if (name == "WinHttpCrackUrl" ||
        name == "WinHttpCreateUrl" ||
        name == "WinHttpQueryOption") {
        return Some("${lastErrorName} == 122u32")
    }
    return None
}

func nativeDnsApiUInt32ReturnUsesDirectErrorCodeUnit(name: String): Bool {
    return name == "DnsSetApplicationSettings" ||
        name == "DnsGetApplicationSettings" ||
        name == "DnsGetProxyInformation" ||
        name == "DnsConnectionSetProxyInfo" ||
        name == "DnsConnectionDeleteProxyInfo" ||
        name == "DnsConnectionUpdateIfIndexTable" ||
        name == "DnsConnectionSetPolicyEntries" ||
        name == "DnsConnectionDeletePolicyEntries" ||
        name == "DnsServiceRegisterCancel"
}

func nativeDnsApiUInt32ReturnUsesDirectErrorCodeStatus(name: String, resultName: String): Option<String> {
    if (name == "DnsQuery_A" || name == "DnsQuery_UTF8" || name == "DnsQuery_W") {
        return Some("${resultName} == 0u32 || ${resultName} == 9501u32")
    }
    if (name == "DnsServiceRegister" || name == "DnsServiceDeRegister") {
        return Some("${resultName} == 0u32 || ${resultName} == 9506u32")
    }
    return None
}

func nativeDnsApiInt32ReturnUsesDirectErrorCodeUnit(name: String): Bool {
    return name == "DnsCancelQuery" ||
        name == "DnsCancelQueryRaw" ||
        name == "DnsAcquireContextHandle_W" ||
        name == "DnsAcquireContextHandle_A" ||
        name == "DnsModifyRecordsInSet_W" ||
        name == "DnsModifyRecordsInSet_A" ||
        name == "DnsModifyRecordsInSet_UTF8" ||
        name == "DnsReplaceRecordSetW" ||
        name == "DnsReplaceRecordSetA" ||
        name == "DnsReplaceRecordSetUTF8" ||
        name == "DnsExtractRecordsFromMessage_W" ||
        name == "DnsExtractRecordsFromMessage_UTF8" ||
        name == "DnsIsFlatRecord" ||
        name == "DnsServiceBrowseCancel" ||
        name == "DnsServiceResolveCancel" ||
        name == "DnsStartMulticastQuery" ||
        name == "DnsStopMulticastQuery"
}

func nativeDnsApiInt32ReturnUsesDirectErrorCodeStatus(name: String, resultName: String): Option<String> {
    if (name == "DnsQueryConfig") {
        return Some("${resultName} == 0 || ${resultName} == 234")
    }
    if (name == "DnsQueryEx") {
        return Some("${resultName} == 0 || ${resultName} == 9501 || ${resultName} == 9506")
    }
    if (name == "DnsQueryRaw") {
        return Some("${resultName} == 0 || ${resultName} == 9506")
    }
    if (name == "DnsValidateName_W" ||
        name == "DnsValidateName_A" ||
        name == "DnsValidateName_UTF8") {
        return Some("${resultName} == 0 || ${resultName} == 9556")
    }
    if (name == "DnsServiceBrowse" || name == "DnsServiceResolve") {
        return Some("${resultName} == 9506")
    }
    return None
}

func nativeIntNativeReturnUsesZeroLastErrorFailure(name: String): Bool {
    return name == "SendMessageTimeoutA" || name == "SendMessageTimeoutW"
}

func nativeMethodPreservesBoolReturnStatus(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!nativeBoolReturnPreservesStatus(method.name)) {
        return false
    }
    let returnType = nativePublicType(method.signature.returnType, symbolsByName, ownerFullName)
    let rawReturnType = nativeRawType(method.signature.returnType, symbolsByName, ownerFullName)
    return returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)
}

func nativeBoolReturnPreservesStatus(name: String): Bool {
    return name == "GetMessageA" || name == "GetMessageW" ||
        name == "TrackPopupMenu" || name == "TrackPopupMenuEx"
}

func nativeBoolReturnUsesMinusOneFailure(name: String): Bool {
    return name == "GetMessageA" || name == "GetMessageW"
}

func nativeBoolReturnCannotUseCheckedWrapper(name: String): Bool {
    return name == "GetQueuedCompletionStatus"
}

func nativeBoolReturnFalseSuccessStatuses(name: String): ArrayList<String> {
    let statuses = ArrayList<String>()
    if (name == "SleepConditionVariableCS" ||
        name == "SleepConditionVariableSRW" ||
        name == "WaitOnAddress") {
        statuses.add("1460u32")
        return statuses
    }
    if (name == "DeleteTimerQueueTimer" ||
        name == "UnregisterWait" ||
        name == "UnregisterWaitEx") {
        statuses.add("997u32")
        return statuses
    }
    if (name == "ConnectNamedPipe") {
        statuses.add("997u32")
        statuses.add("535u32")
        return statuses
    }
    if (name == "DeviceIoControl" ||
        name == "GetThreadWaitChain" ||
        name == "HandleLogFull" ||
        name == "LockFileEx" ||
        name == "ReadFile" ||
        name == "ReadFileScatter" ||
        name == "TransactNamedPipe" ||
        name == "WaitCommEvent" ||
        name == "WinUsb_ReadPipe" ||
        name == "WinUsb_WritePipe" ||
        name == "WriteFile" ||
        name == "WriteFileGather") {
        statuses.add("997u32")
        return statuses
    }
    if (name == "GetOverlappedResult") {
        statuses.add("996u32")
        return statuses
    }
    if (name == "GetOverlappedResultEx") {
        statuses.add("996u32")
        statuses.add("192u32")
        statuses.add("258u32")
        return statuses
    }
    if (name == "GetQueuedCompletionStatusEx") {
        statuses.add("258u32")
        return statuses
    }
    return statuses
}

func nativeWinSockInt32ReturnUsesSocketError(name: String): Bool {
    return name == "bind" ||
        name == "closesocket" ||
        name == "connect" ||
        name == "getpeername" ||
        name == "getsockname" ||
        name == "getsockopt" ||
        name == "ioctlsocket" ||
        name == "listen" ||
        name == "recv" ||
        name == "recvfrom" ||
        name == "select" ||
        name == "send" ||
        name == "sendto" ||
        name == "setsockopt" ||
        name == "shutdown" ||
        name == "gethostname" ||
        name == "GetHostNameW" ||
        name == "WSACleanup" ||
        name == "WSAUnhookBlockingHook" ||
        name == "WSACancelBlockingCall" ||
        name == "WSACancelAsyncRequest" ||
        name == "WSAAsyncSelect" ||
        name == "WSAConnect" ||
        name == "WSADuplicateSocketA" ||
        name == "WSADuplicateSocketW" ||
        name == "WSAEnumNetworkEvents" ||
        name == "WSAEnumProtocolsA" ||
        name == "WSAEnumProtocolsW" ||
        name == "WSAEventSelect" ||
        name == "WSAHtonl" ||
        name == "WSAHtons" ||
        name == "WSAIoctl" ||
        name == "WSANtohl" ||
        name == "WSANtohs" ||
        name == "WSARecv" ||
        name == "WSARecvEx" ||
        name == "WSARecvDisconnect" ||
        name == "WSARecvFrom" ||
        name == "WSASend" ||
        name == "WSASendMsg" ||
        name == "WSASendDisconnect" ||
        name == "WSASendTo" ||
        name == "WSAAddressToStringA" ||
        name == "WSAAddressToStringW" ||
        name == "WSAStringToAddressA" ||
        name == "WSAStringToAddressW" ||
        name == "WSALookupServiceBeginA" ||
        name == "WSALookupServiceBeginW" ||
        name == "WSALookupServiceNextA" ||
        name == "WSALookupServiceNextW" ||
        name == "WSANSPIoctl" ||
        name == "WSALookupServiceEnd" ||
        name == "WSAInstallServiceClassA" ||
        name == "WSAInstallServiceClassW" ||
        name == "WSARemoveServiceClass" ||
        name == "WSAGetServiceClassInfoA" ||
        name == "WSAGetServiceClassInfoW" ||
        name == "WSAEnumNameSpaceProvidersA" ||
        name == "WSAEnumNameSpaceProvidersW" ||
        name == "WSAEnumNameSpaceProvidersExA" ||
        name == "WSAEnumNameSpaceProvidersExW" ||
        name == "WSAGetServiceClassNameByClassIdA" ||
        name == "WSAGetServiceClassNameByClassIdW" ||
        name == "WSASetServiceA" ||
        name == "WSASetServiceW" ||
        name == "WSAProviderConfigChange" ||
        name == "WSAPoll" ||
        name == "WSAAdvertiseProvider" ||
        name == "WSAUnadvertiseProvider" ||
        name == "WSAProviderCompleteAsyncCall" ||
        name == "inet_pton" ||
        name == "InetPtonW" ||
        name == "WSCEnumNameSpaceProviders32" ||
        name == "WSCEnumNameSpaceProvidersEx32" ||
        name == "WSCInstallNameSpace" ||
        name == "WSCInstallNameSpace32" ||
        name == "WSCInstallNameSpaceEx" ||
        name == "WSCInstallNameSpaceEx32" ||
        name == "WSCUnInstallNameSpace" ||
        name == "WSCUnInstallNameSpace32" ||
        name == "WSCEnableNSProvider" ||
        name == "WSCEnableNSProvider32"
}

func nativeWinSockInt32ReturnUsesSocketErrorUnit(name: String): Bool {
    return name == "bind" ||
        name == "closesocket" ||
        name == "connect" ||
        name == "getpeername" ||
        name == "getsockname" ||
        name == "getsockopt" ||
        name == "ioctlsocket" ||
        name == "listen" ||
        name == "setsockopt" ||
        name == "shutdown" ||
        name == "gethostname" ||
        name == "GetHostNameW" ||
        name == "WSACleanup" ||
        name == "WSAUnhookBlockingHook" ||
        name == "WSACancelBlockingCall" ||
        name == "WSACancelAsyncRequest" ||
        name == "WSAAsyncSelect" ||
        name == "WSAConnect" ||
        name == "WSADuplicateSocketA" ||
        name == "WSADuplicateSocketW" ||
        name == "WSAEnumNetworkEvents" ||
        name == "WSAEventSelect" ||
        name == "WSAHtonl" ||
        name == "WSAHtons" ||
        name == "WSAIoctl" ||
        name == "WSANtohl" ||
        name == "WSANtohs" ||
        name == "WSARecv" ||
        name == "WSARecvDisconnect" ||
        name == "WSARecvFrom" ||
        name == "WSASend" ||
        name == "WSASendMsg" ||
        name == "WSASendDisconnect" ||
        name == "WSASendTo" ||
        name == "WSAAddressToStringA" ||
        name == "WSAAddressToStringW" ||
        name == "WSAStringToAddressA" ||
        name == "WSAStringToAddressW" ||
        name == "WSALookupServiceBeginA" ||
        name == "WSALookupServiceBeginW" ||
        name == "WSALookupServiceNextA" ||
        name == "WSALookupServiceNextW" ||
        name == "WSALookupServiceEnd" ||
        name == "WSANSPIoctl" ||
        name == "WSAInstallServiceClassA" ||
        name == "WSAInstallServiceClassW" ||
        name == "WSARemoveServiceClass" ||
        name == "WSAGetServiceClassInfoA" ||
        name == "WSAGetServiceClassInfoW" ||
        name == "WSAGetServiceClassNameByClassIdA" ||
        name == "WSAGetServiceClassNameByClassIdW" ||
        name == "WSASetServiceA" ||
        name == "WSASetServiceW" ||
        name == "WSAProviderConfigChange" ||
        name == "WSAAdvertiseProvider" ||
        name == "WSAUnadvertiseProvider" ||
        name == "WSAProviderCompleteAsyncCall" ||
        name == "WSCInstallNameSpace" ||
        name == "WSCInstallNameSpace32" ||
        name == "WSCInstallNameSpaceEx" ||
        name == "WSCInstallNameSpaceEx32" ||
        name == "WSCUnInstallNameSpace" ||
        name == "WSCUnInstallNameSpace32" ||
        name == "WSCEnableNSProvider" ||
        name == "WSCEnableNSProvider32"
}

func nativeWinSockSocketErrorPendingSuccessStatus(name: String): Option<String> {
    if (name == "WSAIoctl" ||
        name == "WSARecv" ||
        name == "WSARecvFrom" ||
        name == "WSASend" ||
        name == "WSASendMsg" ||
        name == "WSASendTo" ||
        name == "WSAProviderConfigChange") {
        return Some("997")
    }
    return None
}

func nativeWinSockInt32ReturnUsesDirectError(name: String): Bool {
    return name == "WSAStartup" ||
        name == "getaddrinfo" ||
        name == "getnameinfo" ||
        name == "GetAddrInfoW" ||
        name == "GetNameInfoW" ||
        name == "GetAddrInfoExA" ||
        name == "GetAddrInfoExCancel" ||
        name == "SetAddrInfoExA" ||
        name == "SetAddrInfoExW" ||
        name == "WSCWriteProviderOrder" ||
        name == "WSCWriteProviderOrder32" ||
        name == "WSCWriteNameSpaceOrder" ||
        name == "WSCWriteNameSpaceOrder32"
}

func nativeWinSockInt32CanUseWSAGetLastErrorWithoutMetadata(name: String): Bool {
    return name == "InetPtonW" ||
        name == "WSCEnumNameSpaceProviders32" ||
        name == "WSCEnumNameSpaceProvidersEx32" ||
        name == "WSCInstallNameSpace" ||
        name == "WSCInstallNameSpace32" ||
        name == "WSCInstallNameSpaceEx" ||
        name == "WSCInstallNameSpaceEx32" ||
        name == "WSCUnInstallNameSpace" ||
        name == "WSCUnInstallNameSpace32" ||
        name == "WSCEnableNSProvider" ||
        name == "WSCEnableNSProvider32"
}

func nativeMswsockInt32ReturnUsesGetLastErrorSocketError(name: String): Bool {
    return name == "EnumProtocolsA" ||
        name == "EnumProtocolsW" ||
        name == "GetAddressByNameA" ||
        name == "GetAddressByNameW" ||
        name == "GetNameByTypeA" ||
        name == "GetNameByTypeW" ||
        name == "GetServiceA" ||
        name == "GetServiceW" ||
        name == "GetTypeByNameA" ||
        name == "GetTypeByNameW" ||
        name == "SetServiceA" ||
        name == "SetServiceW"
}

func nativeMswsockInt32ReturnUsesGetLastErrorSocketErrorUnit(name: String): Bool {
    return name == "GetTypeByNameA" ||
        name == "GetTypeByNameW" ||
        name == "SetServiceA" ||
        name == "SetServiceW"
}

func nativeWinSockInt32ReturnUsesLpErrnoStatus(name: String): Bool {
    return name == "WSCEnumProtocols" ||
        name == "WSCEnumProtocols32"
}

func nativeWinSockInt32ReturnUsesLpErrnoUnit(name: String): Bool {
    return name == "WSCDeinstallProvider" ||
        name == "WSCDeinstallProvider32" ||
        name == "WSCInstallProvider" ||
        name == "WSCInstallProvider64_32" ||
        name == "WSCInstallProviderAndChains64_32" ||
        name == "WSCGetProviderPath" ||
        name == "WSCGetProviderPath32" ||
        name == "WSCUpdateProvider" ||
        name == "WSCUpdateProvider32" ||
        name == "WSCSetProviderInfo" ||
        name == "WSCSetProviderInfo32" ||
        name == "WSCGetProviderInfo" ||
        name == "WSCGetProviderInfo32" ||
        name == "WSCSetApplicationCategory" ||
        name == "WSCGetApplicationCategory" ||
        name == "WPUCompleteOverlappedRequest"
}

func nativeWinSockInt32ReturnUsesLpErrno(name: String): Bool {
    return nativeWinSockInt32ReturnUsesLpErrnoStatus(name) ||
        nativeWinSockInt32ReturnUsesLpErrnoUnit(name)
}

func nativeWinSockLpErrnoParameterName(method: MethodRecord): String {
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(metadataParameters.size)) {
        let parameterName = cjIdentifier(metadataParameters[index].name)
        if (parameterName == "lpErrno") {
            return parameterName
        }
        index += 1
    }
    return ""
}

func nativeWinSockInt32ReturnPendingStatus(name: String): Option<String> {
    if (name == "GetAddrInfoExW") {
        return Some("997")
    }
    if (name == "GetAddrInfoExOverlappedResult") {
        return Some("10036")
    }
    return None
}

func nativeWinSockBoolPendingSuccessStatus(name: String): Option<String> {
    if (name == "AcceptEx" || name == "TransmitFile") {
        return Some("997")
    }
    return None
}

func nativeWinSockReturnUsesInvalidSocket(name: String): Bool {
    return name == "accept" ||
        name == "socket" ||
        name == "WSAAccept" ||
        name == "WSAJoinLeaf" ||
        name == "WSASocketA" ||
        name == "WSASocketW"
}

func nativeWinSockBoolReturnUsesSocketError(name: String): Bool {
    return name == "WSACloseEvent" ||
        name == "WSAConnectByNameW" ||
        name == "WSAConnectByNameA" ||
        name == "WSAConnectByList" ||
        name == "WSAGetOverlappedResult" ||
        name == "WSAGetQOSByName" ||
        name == "WSAResetEvent" ||
        name == "WSASetEvent" ||
        name == "AcceptEx" ||
        name == "TransmitFile"
}

func nativeMethodReturnsSemanticBool(method: MethodRecord): Bool {
    if (nativeMethodHasOutParameter(method)) {
        return false
    }
    return semanticBoolPrefixMatches(method.name, "Is") ||
        semanticBoolPrefixMatches(method.name, "Are") ||
        semanticBoolPrefixMatches(method.name, "Can") ||
        semanticBoolPrefixMatches(method.name, "Does") ||
        semanticBoolPrefixMatches(method.name, "Equal") ||
        semanticBoolPrefixMatches(method.name, "Has")
}

func nativeMethodCanReturnMultipleSuccessValues(method: MethodRecord): Bool {
    let importName = pinvokeImportName(method)
    if (importName == "CoCreateInstanceEx" || importName == "CoCreateInstanceFromApp") {
        return true
    }
    for (attribute in method.customAttributes) {
        if (attribute.typeName == "CanReturnMultipleSuccessValuesAttribute" ||
            endsWith(attribute.typeName, ".CanReturnMultipleSuccessValuesAttribute")) {
            return true
        }
    }
    return false
}

func nativeMultipleSuccessBoolUsesZeroFailure(name: String): Bool {
    name == "AttachThreadInput"
}

func semanticBoolPrefixMatches(name: String, prefix: String): Bool {
    let nameBytes = name.toArray()
    let prefixBytes = prefix.toArray()
    if (prefixBytes.size > nameBytes.size) {
        return false
    }
    var index: Int64 = 0
    while (index < Int64(prefixBytes.size)) {
        if (nameBytes[index] != prefixBytes[index]) {
            return false
        }
        index += 1
    }
    if (nameBytes.size == prefixBytes.size) {
        return true
    }
    return isAsciiUppercase(nameBytes[Int64(prefixBytes.size)])
}

func isAsciiUppercase(value: Byte): Bool {
    return value >= b'A' && value <= b'Z'
}

func nativeMethodHasOutParameter(method: MethodRecord): Bool {
    for (parameter in method.parameters) {
        if (contains(parameter.attributes, "Out")) {
            return true
        }
    }
    return false
}

func nativeMethodSetsLastError(method: MethodRecord): Bool {
    match (method.methodImport) {
        case Some(methodImport) =>
            if (contains(methodImport.attributes, "SetLastError")) {
                return true
            }
            return nativeMethodReportsLastErrorWithoutMetadata(method.name)
        case None => return nativeMethodReportsLastErrorWithoutMetadata(method.name)
    }
}

func nativeMethodReportsLastErrorWithoutMetadata(name: String): Bool {
    name == "AttachThreadInput" ||
        name == "GetCachedSigningLevel" ||
        name == "SetCachedSigningLevel"
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
        content += "${indent}unsafe { proc__(${args}) }\n"
    } else if (returnType == "Bool" && nativeIsIntegerBoolAbiType(rawReturnType)) {
        content += "${indent}return unsafe { proc__(${args}) } != ${nativeBoolFalseLiteral(rawReturnType)}\n"
    } else if (returnType == "windows_strings.BSTR" && rawReturnType == "CPointer<Unit>") {
        content += "${indent}return windows_strings.BSTR.fromRawTake(CPointer<UInt16>(unsafe { proc__(${args}) }))\n"
    } else if (returnType == "windows_core.HString" && rawReturnType == "CPointer<Unit>") {
        content += "${indent}return windows_core.HString.fromSystemHandleTake(unsafe { proc__(${args}) })\n"
    } else if (nativeIsComInterfacePublicType(returnType) && rawReturnType == "CPointer<Unit>") {
        content += "${indent}return ${returnType}.fromAbiTake(unsafe { proc__(${args}) })\n"
    } else if (nativeIsTextPointerPublicType(returnType)) {
        content += "${indent}return ${returnType}.fromRaw(unsafe { proc__(${args}) })\n"
    } else if (returnType != rawReturnType && startsWithString(returnType, "CPointer<") && startsWithString(rawReturnType, "CPointer<")) {
        // Both the public and raw returns are pointers, but to different element
        // types (e.g. an opaque handle `CPointer<GLUquadric>` returned through the
        // raw `CPointer<CPointer<Unit>>`). Reinterpret via the pointer constructor:
        // `CPointer` has no settable `.Value`, so the newtype `.Value` path below
        // would emit `result.Value = ...` and fail to compile. This mirrors the
        // argument side (`nativeArgumentExpression`), which casts pointer types the
        // same way.
        content += "${indent}return ${returnType}(unsafe { proc__(${args}) })\n"
    } else if (returnType != rawReturnType) {
        content += "${indent}var result = ${returnType}()\n"
        content += "${indent}result.Value = unsafe { proc__(${args}) }\n"
        if (explicitReturn) {
            content += "${indent}return result\n"
        } else {
            content += "${indent}result\n"
        }
    } else {
        content += "${indent}return unsafe { proc__(${args}) }\n"
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

func nativeMethodImportsFromModule(method: MethodRecord, moduleName: String): Bool {
    match (method.methodImport) {
        case Some(methodImport) => return methodImport.moduleName == moduleName
        case None => return false
    }
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

func nativeFunctionPointerCFuncType(
    signature: MethodSignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let params = ArrayList<String>()
    for (parameter in signature.parameters) {
        params.add(nativeRawType(parameter, symbolsByName, ownerFullName))
    }
    let returnType = nativeRawType(signature.returnType, symbolsByName, ownerFullName)
    if (params.isEmpty()) {
        return "CFunc<() -> ${returnType}>"
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>"
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
    if (signature.kind == "FunctionPointer") {
        match (signature.functionPointerSignature) {
            case Some(methodSignature) => return nativeFunctionPointerCFuncType(methodSignature, symbolsByName, ownerFullName)
            case None => return "CPointer<Unit>"
        }
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
    if (signature.kind == "FunctionPointer") {
        match (signature.functionPointerSignature) {
            case Some(methodSignature) => return nativeFunctionPointerCFuncType(methodSignature, symbolsByName, ownerFullName)
            case None => return "CPointer<Unit>"
        }
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
                    return flatAwareSymbolName(symbol)
                case None => return flatAwareSymbolName(symbol)
            }
        case None => return "CPointer<Unit>"
    }
}

// A named value type renders by its package-scoped short name. In flat mode the
// flattened package may have disambiguated that short name, so consult the
// flat-name map (keyed by full name) and emit the disambiguated name; outside
// flat mode this is just `symbol.name`.
func flatAwareSymbolName(symbol: SymbolRecord): String {
    match (flatNameOf(symbol.fullName)) {
        case Some(flatName) => return flatName
        case None => return symbol.name
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
                    return flatAwareSymbolName(symbol)
                case None => return flatAwareSymbolName(symbol)
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
