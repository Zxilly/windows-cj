package windows_bindgen

import std.fs.*
import std.collection.*
import windows_metadata.*
import windows_bindgen.tokens.*
import windows_bindgen.tables.*
import windows_bindgen.types.*

class NamespaceGenerationResult {
    public let namespace: String
    public let relativePath: String
    public let content: String
    public let exports: ArrayList<String>

    public init(namespace: String, relativePath: String, content: String, exports: ArrayList<String>) {
        this.namespace = namespace
        this.relativePath = relativePath
        this.content = content
        this.exports = exports
    }
}

class NamespaceRenderResult {
    public let tokens: TokenStream
    public let typeCount: Int64
    public let exports: ArrayList<String>

    public init(tokens: TokenStream, typeCount: Int64, exports: ArrayList<String>) {
        this.tokens = tokens
        this.typeCount = typeCount
        this.exports = exports
    }
}

main(args: Array<String>) {
    println("windows-bindgen: Cangjie code generator for Windows metadata")
    let warnings = runBindgen(BindgenConfig.parseArgs(args), true)
    if (!warnings.isEmpty()) {
        println("Warnings:")
        println(warnings.toString())
    }
    println("Done.")
}

public func bindgen(args: Array<String>): Warnings {
    return runBindgen(BindgenConfig.parseArgs(args), false)
}

func runBindgen(config: BindgenConfig, verbose: Bool): Warnings {
    if (config.winmdPaths.isEmpty()) {
        let defaultDir = findWinmdDir()
        if (!defaultDir.isEmpty()) {
            let entries = Directory.readFrom(defaultDir)
            for (entry in entries) {
                let path = entry.path.toString()
                if (path.endsWith(".winmd")) {
                    config.winmdPaths.add(path)
                }
            }
        }
        if (config.winmdPaths.isEmpty()) {
            throw Exception("No .winmd files specified. Use --in <path>")
        }
    }

    if (config.outputDir.isEmpty()) {
        config.outputDir = "generated"
    }
    if (!config.hasEnabledGenerator()) {
        throw Exception("at least one generation mode must be enabled")
    }

    logBindgen(verbose, "Input files: ${config.winmdPaths.size}")
    logBindgen(verbose, "Output directory: ${config.outputDir}")

    let winmdFiles = ArrayList<WinmdFile>()
    for (path in config.winmdPaths) {
        logBindgen(verbose, "  Loading: ${path}")
        match (WinmdFile.read(path)) {
            case Some(file) => winmdFiles.add(file)
            case None => logBindgen(verbose, "  Warning: Failed to parse ${path}")
        }
    }

    if (winmdFiles.isEmpty()) {
        throw Exception("No valid .winmd files loaded")
    }

    let index = TypeIndex(winmdFiles)
    logBindgen(verbose, "Type index built: ${countTypes(index)} types")

    let filter = BindgenFilter(index, config)
    let references = config.references(index)
    let warnings = WarningCollector()
    let typeMap = TypeMap(index, filter, config, references)
    config.resolveDeriveTargets(index, typeMap)
    resetStructLayoutCaches()
    setBindgenContext(BindgenContext(index, config, references, typeMap, warnings))
    config.resolveGeneratedPackages(index, typeMap)
    let typeTree = TypeTree(typeMap)
    let namespaces = typeTree.flattenNamespaces()
    let mode = config.primaryMode()
    let highLevelMode = match (mode) {
        case GenerationMode.HighLevel => true
        case GenerationMode.Sys => false
    }
    logBindgen(verbose, "Namespaces found: ${namespaces.size}")

    let fileWriter = FileWriter(config.outputDir)
    let artifactWriter = FileWriter(config.artifactOutputDir())
    let libraryCollector = LibraryCollector(config.link)
    if (!config.link.isEmpty()) {
        libraryCollector.collect(index, typeMap)
    }

    let features = FeatureCollector()
    let generatedFiles = generateNamespaceFiles(
        index,
        namespaces,
        typeMap,
        highLevelMode,
        mode,
        config,
        features
    )
    writeGeneratedNamespaceFiles(fileWriter, generatedFiles, config)
    if (config.usesSubpackageLayout()) {
        writeNamespaceFacades(fileWriter, generatedFiles, config)
        writePackageLayerStubs(fileWriter, generatedFiles, config)
    }
    let nsCount = Int64(generatedFiles.size)

    writeArtifact(artifactWriter, "features.toml", features.generateFeaturesToml(config.noComment))
    writeArtifact(artifactWriter, "link-options.toml", features.generateLinkOptionsToml(config.noComment))
    writeArtifact(artifactWriter, "cfg.toml", features.generateCfgToml(config.noComment))
    if (config.index) {
        writeArtifact(artifactWriter, "features.json", generateFeatureIndex(index, typeMap))
    }
    if (!config.link.isEmpty()) {
        writeArtifact(artifactWriter, "libraries.cj", libraryCollector.generateSource(config.noComment))
    }
    clearBindgenContext()

    logBindgen(verbose, "Generated ${nsCount} namespace files")
    logBindgen(verbose, "Generated features.toml, link-options.toml, cfg.toml")
    return warnings.build()
}

func generateNamespaceFiles(
    index: TypeIndex,
    namespaces: ArrayList<String>,
    typeMap: TypeMap,
    highLevelMode: Bool,
    mode: GenerationMode,
    config: BindgenConfig,
    features: FeatureCollector
): ArrayList<NamespaceGenerationResult> {
    let results = ArrayList<NamespaceGenerationResult>()
    for (namespace in namespaces) {
        setCurrentNamespace(namespace)
        let entries = typeMap.typesInNamespace(namespace)
        if (entries.isEmpty()) {
            continue
        }

        let projectedTypes = projectNamespaceTypes(index, entries, highLevelMode)
        features.addNamespace(namespace)
        let rendered = emitNamespaceTable(index, namespace, projectedTypes, features, mode, config)
        if (rendered.typeCount <= 0 || rendered.tokens.isEmpty()) {
            continue
        }

        results.add(
            NamespaceGenerationResult(
                namespace,
                config.outputRelativePathForNamespace(namespace),
                rendered.tokens.toString(),
                rendered.exports
            )
        )
    }
    return results
}

func writeNamespacePrelude(
    w: CodeWriter,
    namespace: String,
    packageImports: ArrayList<String>,
    mode: GenerationMode,
    config: BindgenConfig
): Unit {
    let pkgName = config.packageNameForNamespace(namespace)
    if (!config.noComment) {
        w.writeLine("// Auto-generated by windows-bindgen. Do not edit.")
    }
    match (mode) {
        case GenerationMode.HighLevel =>
            if (!config.noComment) {
                w.writeLine("// Generation mode: high-level")
                w.writeLine("// High-level projection emits WinRT wrapper types and Win32 sys bindings.")
            }
        case GenerationMode.Sys => ()
    }
    w.writeLine("package ${pkgName}")
    w.writeBlankLine()
    if (config.namespaceHasDerives(namespace)) {
        w.writeLine("import std.deriving.*")
    }
    match (mode) {
        case GenerationMode.HighLevel => w.writeLine("import std.collection.*")
        case GenerationMode.Sys => ()
    }
    for (pkg in supportPackagesForMode(mode)) {
        let used = supportSymbolsFor(namespace, pkg)
        if (!used.isEmpty()) {
            w.writeLine("import ${pkg}.{${joinStrings(used, ", ")}}")
        }
    }
    for (packageImport in packageImports) {
        w.writeLine("import ${packageImport} as ${importedPackageQualifier(packageImport)}")
    }
    w.writeBlankLine()
}

func supportPackagesForMode(mode: GenerationMode): ArrayList<String> {
    let result = ArrayList<String>()
    match (mode) {
        case GenerationMode.HighLevel =>
            result.add("windows_core")
            result.add("windows_interface")
            result.add("windows_polyfill")
        case GenerationMode.Sys =>
            result.add("windows_interface")
            result.add("windows_result")
            result.add("windows_polyfill")
    }
    return result
}

func generateNamespaceProjection(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    types: ArrayList<BindgenType>,
    features: FeatureCollector,
    mode: GenerationMode,
    config: BindgenConfig
): Int64 {
    match (mode) {
        case GenerationMode.HighLevel => return writeHighLevelNamespace(w, index, namespace, types, features, config)
        case GenerationMode.Sys => return writeCppNamespace(w, index, namespace, types, features)
    }
}

func emitNamespaceTable(
    index: TypeIndex,
    namespace: String,
    projectedTypes: ArrayList<BindgenType>,
    features: FeatureCollector,
    mode: GenerationMode,
    config: BindgenConfig
): NamespaceRenderResult {
    let bodyWriter = CodeWriter()
    let typeCount = generateNamespaceProjection(bodyWriter, index, namespace, projectedTypes, features, mode, config)
    let bodyText = bodyWriter.toString()
    let packageImports = collectNamespacePackageImports(index, namespace, projectedTypes, config)
    let exports = collectProjectedPublicExports(index, namespace, projectedTypes, mode, config)

    let headerWriter = CodeWriter()
    writeNamespacePrelude(headerWriter, namespace, packageImports, mode, config)

    let table = NamespaceTable(
        namespace,
        projectedTypes,
        TokenStream.fromString(headerWriter.toString()),
        TokenStream.fromString(bodyText)
    )
    return NamespaceRenderResult(toTokenStream(table), typeCount, exports)
}

func collectNamespacePackageImports(
    index: TypeIndex,
    namespace: String,
    projectedTypes: ArrayList<BindgenType>,
    config: BindgenConfig
): ArrayList<String> {
    let result = ArrayList<String>()
    match (bindgenContext()) {
        case Some(context) => for (projectedType in projectedTypes) {
            let entry = bindgenTypeEntry(projectedType)
            let dependencies = collectTypeDependencies(index, entry.fileIdx, entry.row)
            for (dependency in dependencies) {
                let dependencyName = dependency.definition()
                if (dependencyName.namespace.isEmpty() || dependencyName.namespace == namespace ||
                    !context.typeMap.containsType(dependencyName) || config.sharesGeneratedPackage(namespace,
                    dependencyName.namespace)) {
                    continue
                }

                let packageImport = config.packageNameForNamespace(dependencyName.namespace)
                if (!containsPackageImport(result, packageImport)) {
                    result.add(packageImport)
                }
            }
        }
        case None => ()
    }
    sortStrings(result)
    return result
}

func writeGeneratedNamespaceFiles(
    fileWriter: FileWriter,
    generatedFiles: ArrayList<NamespaceGenerationResult>,
    config: BindgenConfig
): Unit {
    for (generated in generatedFiles) {
        cleanupNamespaceOutputs(fileWriter, generated.namespace, config)
        fileWriter.writeFile(generated.relativePath, generated.content)
    }
}

func writeNamespaceFacades(
    fileWriter: FileWriter,
    generatedFiles: ArrayList<NamespaceGenerationResult>,
    config: BindgenConfig
): Unit {
    for (generated in generatedFiles) {
        if (!config.namespaceNeedsFacade(generated.namespace) || generated.exports.isEmpty()) {
            continue
        }

        let facade = CodeWriter()
        if (!config.noComment) {
            facade.writeLine("// Auto-generated by windows-bindgen. Do not edit.")
        }
        facade.writeLine("package ${config.facadePackageNameForNamespace(generated.namespace)}")
        facade.writeBlankLine()
        let implementationPackage = config.packageNameForNamespace(generated.namespace)
        for (name in generated.exports) {
            facade.writeLine("public import ${implementationPackage}.${escapeSourceIdentifier(name)}")
        }
        facade.writeBlankLine()
        fileWriter.writeFile(config.facadeOutputRelativePathForNamespace(generated.namespace), facade.toString())
    }
}

func writePackageLayerStubs(
    fileWriter: FileWriter,
    generatedFiles: ArrayList<NamespaceGenerationResult>,
    config: BindgenConfig
): Unit {
    let rootPackage = config.packageNameForNamespace("Windows")
    let packagesWithRealMod = HashSet<String>()
    let requiredPackages = HashSet<String>()

    requiredPackages.add(rootPackage)

    for (generated in generatedFiles) {
        let implementationPackage = config.packageNameForNamespace(generated.namespace)
        addRequiredPackageChain(requiredPackages, implementationPackage, rootPackage)
        if (groupedFileStemForNamespace(generated.namespace, config.packageNamespaceForNamespace(generated.namespace)) ==
            "mod") {
            packagesWithRealMod.add(implementationPackage)
        }

        if (config.namespaceNeedsFacade(generated.namespace)) {
            let facadePackage = config.facadePackageNameForNamespace(generated.namespace)
            addRequiredPackageChain(requiredPackages, facadePackage, rootPackage)
            packagesWithRealMod.add(facadePackage)
        }
    }

    let packageList = ArrayList<String>()
    for (packageName in requiredPackages) {
        if (!packagesWithRealMod.contains(packageName)) {
            packageList.add(packageName)
        }
    }
    sortStrings(packageList)

    for (packageName in packageList) {
        let relativeDir = FileWriter.packageNameToRelativeDirPath(packageName, rootPackage)
        let relativePath = if (relativeDir.isEmpty()) {
            "mod.cj"
        } else {
            "${relativeDir}/mod.cj"
        }

        let stub = CodeWriter()
        if (!config.noComment) {
            stub.writeLine("// Auto-generated by windows-bindgen. Do not edit.")
        }
        stub.writeLine("package ${packageName}")
        stub.writeBlankLine()
        fileWriter.writeFile(relativePath, stub.toString())
    }
}

func addRequiredPackageChain(
    packages: HashSet<String>,
    packageName: String,
    rootPackage: String
): Unit {
    let rootParts = splitString(rootPackage, b'.')
    let relativeParts = FileWriter.packageNameToRelativeParts(packageName, rootPackage)
    packages.add(rootPackage)

    if (relativeParts.isEmpty()) {
        return
    }

    let current = ArrayList<String>()
    for (part in rootParts) {
        current.add(part)
    }

    for (part in relativeParts) {
        current.add(part)
        packages.add(joinStrings(current, "."))
    }
}

func cleanupNamespaceOutputs(
    fileWriter: FileWriter,
    namespace: String,
    config: BindgenConfig
): Unit {
    if (!config.usesSubpackageLayout()) {
        return
    }

    for (relativePath in namespaceOutputCandidatePaths(namespace)) {
        removeFileIfExists("${fileWriter.outputDir}/${relativePath}")
    }
}

func namespaceOutputCandidatePaths(namespace: String): ArrayList<String> {
    let result = ArrayList<String>()
    let packageNamespaces = ArrayList<String>()
    packageNamespaces.add(namespace)
    let parts = splitString(namespace, b'.')
    if (parts.size > 1) {
        var prefixLength: Int64 = Int64(parts.size) - 1
        while (prefixLength >= 2) {
            let prefixParts = ArrayList<String>()
            var index: Int64 = 0
            while (index < prefixLength) {
                prefixParts.add(parts[index])
                index += 1
            }
            let prefixNamespace = joinStrings(prefixParts, ".")
            let implementationNamespace = "${prefixNamespace}.impl"
            if (!containsString(packageNamespaces, implementationNamespace)) {
                packageNamespaces.add(implementationNamespace)
            }
            prefixLength -= 1
        }
    }

    for (packageNamespace in packageNamespaces) {
        let dirPath = FileWriter.namespaceToHierarchicalDirPath(packageNamespace)
        let stem = groupedFileStemForCandidate(namespace, packageNamespace)
        let relativePath = if (stem == "mod") {
            "${dirPath}/mod.cj"
        } else {
            "${dirPath}/${stem}.cj"
        }
        if (!containsString(result, relativePath)) {
            result.add(relativePath)
        }
    }
    return result
}

func removeFileIfExists(path: String): Unit {
    if (!exists(path) || isDirectoryPath(path)) {
        return
    }
    remove(path)
}

func groupedFileStemForCandidate(namespace: String, packageNamespace: String): String {
    if (!isImplementationPackageNamespace(packageNamespace)) {
        return FileWriter.namespaceToGroupedFileStem(namespace, packageNamespace)
    }
    return FileWriter.namespaceToGroupedFileStem(namespace, implementationOwnerNamespace(packageNamespace))
}

func isDirectoryPath(path: String): Bool {
    try {
        Directory.readFrom(path)
        return true
    } catch (_: Exception) {
        return false
    }
}

func containsPackageImport(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func logBindgen(verbose: Bool, message: String): Unit {
    if (verbose) {
        println(message)
    }
}

func countTypes(index: TypeIndex): Int64 {
    return Int64(index.iter().size)
}

func collectFeatures(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    features: FeatureCollector
): Unit {
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        match (index.methodDefImplMap(fileIdx, methodRow)) {
            case Some((_, _, moduleName)) => features.addBinding(namespace, moduleName)
            case None => ()
        }
        methodRow += 1
    }
}

func findWinmdDir(): String {
    let candidates = [
        "../winmd",
        "../../winmd",
        "winmd"
    ]
    for (candidate in candidates) {
        if (exists(candidate)) {
            return candidate
        }
    }
    return ""
}

func writeArtifact(fileWriter: FileWriter, relativePath: String, content: String): Unit {
    let table = TextArtifactTable(relativePath, TokenStream.fromString(content))
    fileWriter.writeFile(relativePath, toTokenStream(table).toString())
}

func collectProjectedPublicExports(
    index: TypeIndex,
    namespace: String,
    projectedTypes: ArrayList<BindgenType>,
    mode: GenerationMode,
    config: BindgenConfig
): ArrayList<String> {
    let exports = ArrayList<String>()
    match (mode) {
        case GenerationMode.HighLevel => return exports
        case GenerationMode.Sys => ()
    }

    for (projectedType in projectedTypes) {
        let entry = bindgenTypeEntry(projectedType)
        match (projectedType) {
            case CppInterface(_) => collectCppInterfaceExports(index, entry.fileIdx, entry.row, exports)
            case Handle(_) => collectHandleExports(index, entry.fileIdx, entry.row, exports)
            case CppStruct(_) => collectStructExports(index, entry.fileIdx, entry.row, namespace,
                trimTick(index.typeDefName(entry.fileIdx, entry.row)), exports)
            case CppEnum(_) => collectEnumExports(index, entry.fileIdx, entry.row, namespace, exports)
            case CppDelegate(_) => collectDelegateExports(index, entry.fileIdx, entry.row, namespace, exports)
            case CppFn(_) => collectCppFunctionExports(index, entry.fileIdx, entry.row, namespace, config, exports)
            case Attribute(_) => ()
            case HighLevelClass(_) | HighLevelDelegate(_) | HighLevelEnum(_) | HighLevelInterface(_)
                | HighLevelStruct(_) => ()
        }
    }

    sortStrings(exports)
    return exports
}

func collectCppInterfaceExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    exports: ArrayList<String>
): Unit {
    let flags = index.typeDefFlags(fileIdx, row)
    if (!flags.contains(TypeAttributes.Interface)) {
        return
    }

    if (skipForSysGeneric(index, fileIdx, row)) {
        return
    }
    if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
        return
    }

    let name = trimTick(index.typeDefName(fileIdx, row))
    addExportName(exports, "${name}Vtbl")
    addExportName(exports, name)
}

func collectHandleExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    exports: ArrayList<String>
): Unit {
    if (!isHandleType(index, fileIdx, row)) {
        return
    }
    if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
        return
    }
    addExportName(exports, trimTick(index.typeDefName(fileIdx, row)))
}

func collectStructExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    name: String,
    exports: ArrayList<String>
): Unit {
    if (isHandleType(index, fileIdx, row)) {
        return
    }
    if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
        return
    }
    let structSignature = buildStructSignature(index, fileIdx, row, name)
    if (!shouldEmitStructRow(index, namespace, name, fileIdx, row, structSignature)) {
        return
    }

    addExportName(exports, name)
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            let constName = projectedConstantName(index, "${name}_${index.fieldName(fileIdx, fieldRow)}", namespace)
            addExportName(exports, "${name}_${constName}")
        }
        fieldRow += 1
    }

    let parentArches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
    let nestedRows = index.getNested(fileIdx, row)
    for (innerRow in nestedRows) {
        match (index.typeDefCategory(fileIdx, innerRow)) {
            case Struct =>
                // Nested structs are reachable only through the parent's accessor
                // methods, and may carry per-arch gates that the facade `public
                // import` cannot conditionalise. Compute the EFFECTIVE arches —
                // inherited from the parent when the nested row carries none —
                // and skip exporting if it would not be visible on every arch.
                let inherited = inheritArches(index.arches(TABLE_TYPE_DEF, fileIdx, innerRow), parentArches)
                if (isUnsupportedOnlyArchitecture(inherited)) {
                    continue
                }
                let mask = parseInt64OrZero(inherited)
                if (mask > 0 && mask != 7 && mask != 6) {
                    continue
                }
                let nestedName = "${name}_${nestedLeafName(index.typeDefName(fileIdx, innerRow))}"
                collectStructExports(index, fileIdx, innerRow, namespace, nestedName, exports)
            case _ => ()
        }
    }
}

func collectEnumExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    exports: ArrayList<String>
): Unit {
    let rawEnumName = trimTick(index.typeDefName(fileIdx, row))
    addExportName(exports, rawEnumName)
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            let qualifiedName = "${rawEnumName}_${index.fieldName(fileIdx, fieldRow)}"
            addExportName(exports, projectedConstantName(index, qualifiedName, namespace))
        }
        fieldRow += 1
    }
}

func collectDelegateExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    exports: ArrayList<String>
): Unit {
    let name = trimTick(index.typeDefName(fileIdx, row))
    if (!shouldEmitDelegateRow(index, namespace, name, fileIdx, row)) {
        return
    }
    if (skipForSysGeneric(index, fileIdx, row)) {
        return
    }
    if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
        return
    }
    if (mergedDelegateAliasType(index, namespace, name, fileIdx, row).isEmpty()) {
        return
    }
    addExportName(exports, name)
}

func collectCppFunctionExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    config: BindgenConfig,
    exports: ArrayList<String>
): Unit {
    match (index.typeDefCategory(fileIdx, row)) {
        case TypeCategory.Class => ()
        case _ => return
    }

    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (fieldFlags.contains(FieldAttributes.Literal) && fieldFlags.contains(FieldAttributes.Static)) {
            addExportName(exports, projectedConstantName(index, index.fieldName(fileIdx, fieldRow), namespace))
        }
        fieldRow += 1
    }

    if (!config.sysFnPtrs) {
        return
    }

    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let flags = index.methodDefFlags(fileIdx, methodRow)
        if (flags.contains(MethodAttributes.Static) && flags.contains(MethodAttributes.Public)) {
            match (index.methodDefImplMap(fileIdx, methodRow)) {
                case Some((_, _, _)) =>
                    let missing = missingMethodDependencies(index, fileIdx, methodRow,
                        Array<MetadataType>(0, {_ => MetadataType.Void}))
                    if (missing.isEmpty()) {
                        addExportName(exports, "${index.methodDefName(fileIdx, methodRow)}Fn")
                    }
                case None => ()
            }
        }
        methodRow += 1
    }
}

func addExportName(exports: ArrayList<String>, name: String): Unit {
    if (name.isEmpty() || containsString(exports, name)) {
        return
    }
    exports.add(name)
}
