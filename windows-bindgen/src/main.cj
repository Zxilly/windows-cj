package windows_bindgen

import std.fs.*
import std.collection.*
import std.sync.*
import windows_metadata.*
import windows_bindgen.tokens.*
import windows_bindgen.tables.*
import windows_bindgen.types.*

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
    let typeTree = TypeTree(typeMap)
    let namespaces = typeTree.flattenNamespaces()
    let mode = config.primaryMode()
    let highLevelMode = match (mode) {
        case GenerationMode.HighLevel => true
        case GenerationMode.Sys => false
    }
    logBindgen(verbose, "Namespaces found: ${namespaces.size}")

    let features = FeatureCollector()
    let fileWriter = FileWriter(config.outputDir)
    let artifactWriter = FileWriter(config.artifactOutputDir())
    let libraryCollector = LibraryCollector(config.link)
    if (!config.link.isEmpty()) {
        libraryCollector.collect(index, typeMap)
    }

    let sem = Semaphore(16)
    let futures = ArrayList<Future<Int64>>()
    for (namespace in namespaces) {
        let ns = namespace
        sem.acquire()
        let fut = spawn {
            setCurrentNamespace(ns)
            var result: Int64 = 0
            let entries = typeMap.typesInNamespace(ns)
            if (!entries.isEmpty()) {
                let projectedTypes = projectNamespaceTypes(index, entries, highLevelMode)
                features.addNamespace(ns)
                let (tokens, typeCount) = emitNamespaceTable(index, ns, projectedTypes, features, mode, config)
                if (typeCount > 0 && !tokens.isEmpty()) {
                    let dirPath = FileWriter.namespaceToDirPath(ns)
                    let fileName = if (config.usesSubpackageLayout()) {
                        "${FileWriter.namespaceToSubpackageDirPath(ns)}/mod.cj"
                    } else if (config.flat) {
                        "${toLowerSnake(lastComponent(ns))}.cj"
                    } else if (config.packageOutput) {
                        "src/${dirPath}/mod.cj"
                    } else {
                        "${dirPath}/mod.cj"
                    }
                    fileWriter.writeFile(fileName, tokens.toString())
                    result = 1
                }
            }
            sem.release()
            result
        }
        futures.add(fut)
    }
    var nsCount: Int64 = 0
    for (fut in futures) {
        nsCount += fut.get()
    }

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

func writeNamespacePrelude(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    projectedTypes: ArrayList<BindgenType>,
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
        case GenerationMode.HighLevel =>
            w.writeLine("import std.collection.*")
        case GenerationMode.Sys => ()
    }
    match (mode) {
        case GenerationMode.HighLevel =>
            w.writeLine("import windows_core.*")
            w.writeLine("import windows_interface.*")
        case GenerationMode.Sys =>
            w.writeLine("import windows_interface.*")
            w.writeLine("import windows_result.*")
    }
    let packageImports = collectNamespacePackageImports(index, namespace, projectedTypes, config)
    for (packageImport in packageImports) {
        w.writeLine("import ${packageImport}")
    }
    let foundationPkg = config.packageNameForNamespace("Windows.Win32.Foundation")
    if (pkgName != foundationPkg) {
        if (!containsPackageImport(packageImports, foundationPkg)) {
            w.writeLine("import ${foundationPkg}")
        }
        w.writeLine("import ${foundationPkg}.*")
    }
    w.writeBlankLine()
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
        case GenerationMode.HighLevel =>
            return writeHighLevelNamespace(w, index, namespace, types, features, config)
        case GenerationMode.Sys =>
            return writeCppNamespace(w, index, namespace, types, features)
    }
}

func emitNamespaceTable(
    index: TypeIndex,
    namespace: String,
    projectedTypes: ArrayList<BindgenType>,
    features: FeatureCollector,
    mode: GenerationMode,
    config: BindgenConfig
): (TokenStream, Int64) {
    let headerWriter = CodeWriter()
    writeNamespacePrelude(headerWriter, index, namespace, projectedTypes, mode, config)

    let bodyWriter = CodeWriter()
    let typeCount = generateNamespaceProjection(bodyWriter, index, namespace, projectedTypes, features, mode, config)

    let table = NamespaceTable(
        namespace,
        projectedTypes,
        TokenStream.fromString(headerWriter.toString()),
        TokenStream.fromString(bodyWriter.toString())
    )
    return (toTokenStream(table), typeCount)
}

func collectNamespacePackageImports(
    index: TypeIndex,
    namespace: String,
    projectedTypes: ArrayList<BindgenType>,
    config: BindgenConfig
): ArrayList<String> {
    let result = ArrayList<String>()
    match (bindgenContext()) {
        case Some(context) =>
            for (projectedType in projectedTypes) {
                let entry = bindgenTypeEntry(projectedType)
                let dependencies = collectTypeDependencies(index, entry.fileIdx, entry.row)
                for (dependency in dependencies) {
                    let dependencyName = dependency.definition()
                    if (dependencyName.namespace.isEmpty() ||
                        dependencyName.namespace == namespace ||
                        !context.typeMap.containsType(dependencyName) ||
                        config.sharesGeneratedPackage(namespace, dependencyName.namespace)) {
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

func lastComponent(namespace: String): String {
    let parts = splitString(namespace, b'.')
    if (parts.isEmpty()) {
        return namespace
    }
    return parts[parts.size - 1]
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
            case Some((_, _, moduleName)) =>
                features.addBinding(namespace, moduleName)
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
