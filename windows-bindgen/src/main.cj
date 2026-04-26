package windows_bindgen

import std.fs.*
import std.collection.*
import std.runtime.*
import std.sort.*
import std.sync.*
import windows_metadata.*
import windows_bindgen.tokens.*
import windows_bindgen.tables.*
import windows_bindgen.types.*
import windows_bindgen.winmd.*

class NamespaceGenerationResult {
    public let namespace: String
    public let relativePath: String
    public let header: String
    public let body: String
    public let content: String
    public let exports: ArrayList<String>
    public let perTypeFragments: HashMap<String, String>
    public let exportOwners: HashMap<String, String>
    public let mode: GenerationMode
    public let packageImports: ArrayList<String>

    public init(
        namespace: String,
        relativePath: String,
        header: String,
        body: String,
        content: String,
        exports: ArrayList<String>,
        perTypeFragments: HashMap<String, String>,
        exportOwners: HashMap<String, String>,
        mode: GenerationMode,
        packageImports: ArrayList<String>
    ) {
        this.namespace = namespace
        this.relativePath = relativePath
        this.header = header
        this.body = body
        this.content = content
        this.exports = exports
        this.perTypeFragments = perTypeFragments
        this.exportOwners = exportOwners
        this.mode = mode
        this.packageImports = packageImports
    }
}

class NamespaceRenderResult {
    public let tokens: TokenStream
    public let header: String
    public let body: String
    public let typeCount: Int64
    public let exports: ArrayList<String>
    public let perTypeFragments: HashMap<String, String>
    public let exportOwners: HashMap<String, String>
    public let packageImports: ArrayList<String>

    public init(
        tokens: TokenStream,
        header: String,
        body: String,
        typeCount: Int64,
        exports: ArrayList<String>,
        perTypeFragments: HashMap<String, String>,
        exportOwners: HashMap<String, String>,
        packageImports: ArrayList<String>
    ) {
        this.tokens = tokens
        this.header = header
        this.body = body
        this.typeCount = typeCount
        this.exports = exports
        this.perTypeFragments = perTypeFragments
        this.exportOwners = exportOwners
        this.packageImports = packageImports
    }
}

class NamespaceWorkItem {
    public let namespace: String
    public let projectedTypes: ArrayList<BindgenType>

    public init(namespace: String, projectedTypes: ArrayList<BindgenType>) {
        this.namespace = namespace
        this.projectedTypes = projectedTypes
    }
}

// Slot holder for parallel render results. ArrayList per-index assignment from
// multiple workers is racy; wrapping the slot in a class lets each worker write
// its own slot through a stable reference without sharing mutable container
// state.
class RenderSlot {
    public var value: Option<NamespaceGenerationResult> = Option<NamespaceGenerationResult>.None
}

// Output of a single per-type render. Mutable class lets parallel workers
// fill in their assigned slot through a stable reference without sharing
// container state.
class RenderedFragment {
    public var name: String = ""
    public var text: String = ""
    public var typeCount: Int64 = 0
}

// Render every type in `types` to its own fragment in parallel, returning
// fragments in the same order as the input. Workers race on an atomic index;
// each worker re-establishes the namespace ThreadLocal because Cangjie
// ThreadLocals are per-coroutine and do not propagate across spawn.
func renderTypeFragmentsParallel(
    index: TypeIndex,
    namespace: String,
    types: ArrayList<BindgenType>,
    features: FeatureCollector,
    config: BindgenConfig,
    highLevel: Bool
): ArrayList<RenderedFragment> {
    let total = Int64(types.size)
    let slots = ArrayList<RenderedFragment>()
    for (_ in 0..total) {
        slots.add(RenderedFragment())
    }
    if (total == 0) {
        return slots
    }
    // Only invoke nested parallelism when the namespace is large enough that
    // the spawn overhead and mutex contention from extra coroutines are
    // amortised. Small namespaces are already covered by the outer namespace
    // worker pool, so we render them serially inside that worker.
    let nestedParallelThreshold: Int64 = 24
    let workerCount = if (config.jobs > total) {
        total
    } else {
        config.jobs
    }
    if (workerCount <= 1 || total < nestedParallelThreshold) {
        var k: Int64 = 0
        while (k < total) {
            renderOneTypeFragmentInto(slots[k], index, namespace, types[k], features, config, highLevel)
            k += 1
        }
        return slots
    }
    let nextIdx = AtomicInt64(0)
    let workers = ArrayList<Future<Unit>>()
    for (_ in 0..workerCount) {
        let worker: Future<Unit> = spawn {
            =>
            setCurrentNamespace(namespace)
            while (true) {
                let k = nextIdx.fetchAdd(1)
                if (k >= total) {
                    break
                }
                renderOneTypeFragmentInto(slots[k], index, namespace, types[k], features, config, highLevel)
            }
        }
        workers.add(worker)
    }
    for (worker in workers) {
        worker.get()
    }
    return slots
}

func renderOneTypeFragmentInto(
    slot: RenderedFragment,
    index: TypeIndex,
    namespace: String,
    ty: BindgenType,
    features: FeatureCollector,
    config: BindgenConfig,
    highLevel: Bool
): Unit {
    let fragmentWriter = CodeWriter()
    let entry = bindgenTypeEntry(ty)
    setCurrentTypeName(entry.name)
    let count = if (highLevel) {
        emitHighLevelNamespaceItem(fragmentWriter, index, namespace, ty, features, config)
    } else {
        emitCppNamespaceItem(fragmentWriter, index, namespace, ty, features)
    }
    clearCurrentTypeName()
    slot.name = entry.name
    slot.typeCount = count
    if (!fragmentWriter.isEmpty()) {
        slot.text = fragmentWriter.toString()
    }
}

// Serially append parallel-rendered fragments into the outer writer in their
// original order, and merge into the per-type fragment map. Returns the sum
// of typeCounts across all fragments.
func emitRenderedFragments(
    w: CodeWriter,
    perTypeFragments: HashMap<String, String>,
    fragments: ArrayList<RenderedFragment>
): Int64 {
    var total: Int64 = 0
    for (frag in fragments) {
        total += frag.typeCount
        if (frag.text.isEmpty()) {
            continue
        }
        w.writeRaw(frag.text)
        if (perTypeFragments.contains(frag.name)) {
            perTypeFragments[frag.name] = "${perTypeFragments[frag.name]}${frag.text}"
        } else {
            perTypeFragments[frag.name] = frag.text
        }
    }
    return total
}

// Generic worker-pool helper: dispatch `action(item)` for every element of
// `items`, with up to `jobs` concurrent workers cooperating via an atomic
// index. Falls back to a serial loop when jobs<=1 or items<=1 to avoid the
// spawn overhead.
func parallelForEach<T>(items: ArrayList<T>, jobs: Int64, action: (T) -> Unit): Unit {
    let total = Int64(items.size)
    if (total <= 1 || jobs <= 1) {
        for (item in items) {
            action(item)
        }
        return
    }
    let nextIdx = AtomicInt64(0)
    let workerCount = if (jobs > total) {
        total
    } else {
        jobs
    }
    let workers = ArrayList<Future<Unit>>()
    for (_ in 0..workerCount) {
        let worker: Future<Unit> = spawn {
            =>
            while (true) {
                let i = nextIdx.fetchAdd(1)
                if (i >= total) {
                    break
                }
                action(items[i])
            }
        }
        workers.add(worker)
    }
    for (worker in workers) {
        worker.get()
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
    if (config.jobs <= 0) {
        let cores = getProcessorCount()
        config.jobs = if (cores > 0) {
            cores
        } else {
            4
        }
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
    config.resolveDeriveTargets(index, typeMap, references)
    resetStructLayoutCaches()
    resetSupportSymbolUsage()
    setBindgenContext(BindgenContext(index, config, references, typeMap, warnings))
    config.resolveGeneratedPackages(index, typeMap)
    if (config.usesLayeredImpl && config.usesSubpackageLayout()) {
        let namespaceGraph = buildNamespaceDependencyGraph(index, typeMap)
        let namespaceComponents = computeNamespaceComponents(typeMap.namespaces(), namespaceGraph)
        config.layerAssignment = Some(computeLayerAssignment(index, typeMap, namespaceComponents,
            config.outputRootPackageName(), config.targetBucketSize))
    }
    let typeTree = TypeTree(typeMap)
    let namespaces = typeTree.flattenNamespaces()
    let mode = config.primaryMode()
    let highLevelMode = match (mode) {
        case GenerationMode.HighLevel => true
        case GenerationMode.Sys => false
    }
    logBindgen(verbose, "Namespaces found: ${namespaces.size}")
    logBindgen(verbose, "Namespace render jobs: ${config.jobs}")

    let fileWriter = FileWriter(config.outputDir)
    let artifactWriter = FileWriter(config.artifactOutputDir())
    let libraryCollector = LibraryCollector(config.link)
    if (!config.link.isEmpty()) {
        libraryCollector.collect(index, typeMap)
    }

    let features = FeatureCollector()
    let cfgUniverse = collectCfgUniverse(index)
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
        writeNamespaceFacades(fileWriter, generatedFiles, config, index)
        writePackageLayerStubs(fileWriter, generatedFiles, config)
    } else if (config.packageOutput) {
        writePackageOutputStubs(fileWriter, generatedFiles, config)
    }
    let nsCount = Int64(generatedFiles.size)

    let cfgListToml = features.generateCfgListToml(config.noComment, universe: cfgUniverse)
    writeArtifact(artifactWriter, "features.toml", features.generateFeaturesToml(config.noComment))
    writeArtifact(artifactWriter, "link-options.toml", features.generateLinkOptionsToml(config.noComment))
    writeArtifact(artifactWriter, "cfg_list.toml", cfgListToml)
    if (config.index) {
        writeArtifact(artifactWriter, "features.json", generateFeatureIndex(index, typeMap))
    }
    if (!config.link.isEmpty()) {
        writeArtifact(artifactWriter, "libraries.cj", libraryCollector.generateSource(config.noComment))
    }
    clearBindgenContext()

    logBindgen(verbose, "Generated ${nsCount} namespace files")
    logBindgen(verbose, "Generated features.toml, link-options.toml, cfg_list.toml")
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
    let workItems = ArrayList<NamespaceWorkItem>()
    for (namespace in namespaces) {
        let entries = typeMap.typesInNamespace(namespace)
        if (entries.isEmpty()) {
            continue
        }

        let projectedTypes = projectNamespaceTypes(index, entries, highLevelMode)
        features.addNamespace(namespace)
        workItems.add(NamespaceWorkItem(namespace, projectedTypes))
    }

    // LPT (Longest Processing Time) scheduling: dispatch larger namespaces first
    // so the longest task starts running ASAP and small ones backfill at the
    // tail. This minimises makespan when task sizes vary widely.
    sort<NamespaceWorkItem>(workItems, by: {a: NamespaceWorkItem, b: NamespaceWorkItem =>
        let aSize = Int64(a.projectedTypes.size)
        let bSize = Int64(b.projectedTypes.size)
        if (aSize > bSize) {
            return Ordering.LT
        }
        if (aSize < bSize) {
            return Ordering.GT
        }
        return Ordering.EQ
    })

    if (config.jobs <= 1 || workItems.size <= 1) {
        return generateNamespaceFilesSequential(index, workItems, mode, config, features)
    }
    return generateNamespaceFilesParallel(index, workItems, mode, config, features)
}

func generateNamespaceFilesSequential(
    index: TypeIndex,
    workItems: ArrayList<NamespaceWorkItem>,
    mode: GenerationMode,
    config: BindgenConfig,
    features: FeatureCollector
): ArrayList<NamespaceGenerationResult> {
    let results = ArrayList<NamespaceGenerationResult>()
    for (workItem in workItems) {
        match (renderNamespaceWorkItem(index, workItem, mode, config, features)) {
            case Some(generated) => results.add(generated)
            case None => ()
        }
    }
    return results
}

func generateNamespaceFilesParallel(
    index: TypeIndex,
    workItems: ArrayList<NamespaceWorkItem>,
    mode: GenerationMode,
    config: BindgenConfig,
    features: FeatureCollector
): ArrayList<NamespaceGenerationResult> {
    let total = Int64(workItems.size)

    // Pre-allocate per-namespace slot objects so each worker writes through
    // its own reference. Workers race on `nextIdx` only.
    let slots = ArrayList<RenderSlot>()
    for (_ in 0..total) {
        slots.add(RenderSlot())
    }

    let nextIdx = AtomicInt64(0)
    let workerCount = if (config.jobs < total) {
        config.jobs
    } else {
        total
    }

    let workers = ArrayList<Future<Unit>>()
    for (_ in 0..workerCount) {
        let worker: Future<Unit> = spawn {
            =>
            while (true) {
                let i = nextIdx.fetchAdd(1)
                if (i >= total) {
                    break
                }
                let workItem = workItems[i]
                slots[i].value = renderNamespaceWorkItem(index, workItem, mode, config, features)
            }
        }
        workers.add(worker)
    }

    for (worker in workers) {
        worker.get()
    }

    let results = ArrayList<NamespaceGenerationResult>()
    for (slot in slots) {
        match (slot.value) {
            case Some(generated) => results.add(generated)
            case None => ()
        }
    }
    return results
}

func renderNamespaceWorkItem(
    index: TypeIndex,
    workItem: NamespaceWorkItem,
    mode: GenerationMode,
    config: BindgenConfig,
    features: FeatureCollector
): Option<NamespaceGenerationResult> {
    setCurrentNamespace(workItem.namespace)
    let rendered = emitNamespaceTable(index, workItem.namespace, workItem.projectedTypes, features, mode, config)
    if (rendered.typeCount <= 0 || rendered.tokens.isEmpty()) {
        return Option<NamespaceGenerationResult>.None
    }
    return Some(
        NamespaceGenerationResult(
            workItem.namespace,
            config.outputRelativePathForNamespace(workItem.namespace),
            rendered.header,
            rendered.body,
            rendered.tokens.toString(),
            rendered.exports,
            rendered.perTypeFragments,
            rendered.exportOwners,
            mode,
            rendered.packageImports
        )
    )
}

func writeNamespacePrelude(
    w: CodeWriter,
    namespace: String,
    packageImports: ArrayList<String>,
    mode: GenerationMode,
    config: BindgenConfig
): Unit {
    writeNamespacePreludeForPackage(w, namespace, config.packageNameForNamespace(namespace), packageImports, mode,
        config)
}

func writeNamespacePreludeForPackage(
    w: CodeWriter,
    namespace: String,
    packageName: String,
    packageImports: ArrayList<String>,
    mode: GenerationMode,
    config: BindgenConfig
): Unit {
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
    w.writeLine("package ${packageName}")
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
            w.writeLine("import ${pkg} as ${importedPackageQualifier(pkg)}")
        }
    }
    for (packageImport in packageImports) {
        if (packageImport == packageName) {
            continue
        }
        if (!shouldWritePackageImportForPackage(packageName, packageImport)) {
            continue
        }
        let importTags = config.packageImportAvailabilityTags(packageImport)
        if (!importTags.isEmpty()) {
            writeAvailabilityForTags(w, "", importTags)
        }
        w.writeLine("import ${packageImport} as ${importedPackageQualifier(packageImport)}")
    }
    w.writeBlankLine()
}

func shouldWritePackageImportForPackage(packageName: String, packageImport: String): Bool {
    let packageLayer = layerPackageIndex(packageName)
    if (packageLayer < 0) {
        return true
    }
    let importLayer = layerPackageIndex(packageImport)
    if (importLayer < 0) {
        return true
    }
    if (layerPackagePrefix(packageName) != layerPackagePrefix(packageImport)) {
        return true
    }
    return importLayer <= packageLayer
}

func layerPackagePrefix(packageName: String): String {
    match (packageName.indexOf("._impl_l", 0)) {
        case Some(pos) =>
            let arr = packageName.toArray()
            return String.fromUtf8(arr[0..pos])
        case None => return packageName
    }
}

func layerPackageIndex(packageName: String): Int64 {
    match (packageName.indexOf("._impl_l", 0)) {
        case Some(pos) =>
            let arr = packageName.toArray()
            var i = pos + Int64("._impl_l".toArray().size)
            var value: Int64 = 0
            var hasDigit = false
            while (i < Int64(arr.size)) {
                let ch = arr[i]
                if (ch < b'0' || ch > b'9') {
                    return if (hasDigit) { value } else { -1 }
                }
                value = value * 10 + Int64(ch - b'0')
                hasDigit = true
                i += 1
            }
            return if (hasDigit) { value } else { -1 }
        case None => return -1
    }
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
    config: BindgenConfig,
    perTypeFragments: HashMap<String, String>
): Int64 {
    match (mode) {
        case GenerationMode.HighLevel => return writeHighLevelNamespace(w, index, namespace, types, features, config,
            perTypeFragments)
        case GenerationMode.Sys => return writeCppNamespace(w, index, namespace, types, features, perTypeFragments,
            config)
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
    let perTypeFragments = HashMap<String, String>()
    let typeCount = generateNamespaceProjection(bodyWriter, index, namespace, projectedTypes, features, mode, config,
        perTypeFragments)
    let bodyText = bodyWriter.toString()
    let packageImports = collectNamespacePackageImports(index, namespace, projectedTypes, config)
    let exports = collectProjectedPublicExports(index, namespace, projectedTypes, mode, config)
    let exportOwners = collectProjectedPublicExportOwners(index, namespace, projectedTypes, mode, config)

    let headerWriter = CodeWriter()
    writeNamespacePrelude(headerWriter, namespace, packageImports, mode, config)
    let headerText = headerWriter.toString()

    let table = NamespaceTable(
        namespace,
        projectedTypes,
        TokenStream.fromString(headerText),
        TokenStream.fromString(bodyText)
    )
    return NamespaceRenderResult(toTokenStream(table), headerText, bodyText, typeCount, exports, perTypeFragments,
        exportOwners, packageImports)
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
            let currentPackage = config.packageNameForType(namespace, entry.name)
            let dependencies = collectTypeDependencies(index, entry.fileIdx, entry.row)
            for (dependency in dependencies) {
                let dependencyName = dependency.definition()
                if (context.typeMap.containsType(dependencyName)) {
                    if (dependencyName.namespace.isEmpty()) {
                        continue
                    }
                    let packageImport = config.packageNameForType(dependencyName.namespace, dependencyName.name)
                    if (packageImport == currentPackage) {
                        continue
                    }
                    if (!containsPackageImport(result, packageImport)) {
                        result.add(packageImport)
                    }
                    continue
                }

                if (!context.config.isForcedLocalType(dependencyName.namespace, trimTick(dependencyName.name))) {
                    match (context.references.importPathForType(dependencyName.namespace, trimTick(dependencyName.name))) {
                        case Some(importPath) =>
                            if (importPath != currentPackage && !containsPackageImport(result, importPath)) {
                                result.add(importPath)
                            }
                            continue
                        case None => ()
                    }
                }

                if (dependencyName.namespace.isEmpty() || dependencyName.namespace == namespace) {
                    continue
                }

                if (!context.typeMap.containsType(dependencyName) ||
                    config.packageNameForType(dependencyName.namespace, dependencyName.name) == currentPackage) {
                    continue
                }
                let packageImport = config.packageNameForType(dependencyName.namespace, dependencyName.name)
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
    parallelForEach<NamespaceGenerationResult>(generatedFiles, config.jobs, {generated =>
        cleanupNamespaceOutputs(fileWriter, generated.namespace, config)
        if (!(config.namespaceHasLayeredTypes(generated.namespace) &&
            emitTypesGroupedByLayer(fileWriter, generated, config))) {
            fileWriter.writeFile(generated.relativePath, generated.content)
        }
    })
}

func emitTypesGroupedByLayer(
    fileWriter: FileWriter,
    generated: NamespaceGenerationResult,
    config: BindgenConfig
): Bool {
    if (generated.perTypeFragments.isEmpty()) {
        return false
    }

    match (config.layerAssignment) {
        case Some(assignment) =>
            let typesByStem = HashMap<String, ArrayList<String>>()
            let stemOrder = ArrayList<String>()
            // Iterate over a deterministically-ordered key list. Cangjie HashMap
            // does not guarantee iteration order; without this sort the merge
            // order of fragments for namespaces that have multiple types per
            // bucket (e.g. arch-divergent CONTEXT structs) becomes
            // non-deterministic between runs.
            let sortedFragmentTypeNames = ArrayList<String>()
            for ((typeName, _) in generated.perTypeFragments) {
                sortedFragmentTypeNames.add(typeName)
            }
            sortStrings(sortedFragmentTypeNames)
            for (typeName in sortedFragmentTypeNames) {
                match (assignment.bucketStemFor(generated.namespace, typeName)) {
                    case Some(stem) =>
                        if (!typesByStem.contains(stem)) {
                            typesByStem[stem] = ArrayList<String>()
                            stemOrder.add(stem)
                        }
                        typesByStem[stem].add(typeName)
                    case None => return false
                }
            }

            sortStrings(stemOrder)
            for (stem in stemOrder) {
                let typeNames = typesByStem[stem]
                if (typeNames.isEmpty()) {
                    continue
                }
                sortStrings(typeNames)
                let firstTypeName = typeNames[0]
                let packageName = config.packageNameForType(generated.namespace, firstTypeName)
                let fragments = ArrayList<String>()
                for (typeName in typeNames) {
                    fragments.add(generated.perTypeFragments[typeName])
                }
                let packageImports = packageImportsUsedByFragments(packageName, generated.packageImports, fragments)
                let prelude = CodeWriter()
                writeNamespacePreludeForPackage(prelude, generated.namespace, packageName, packageImports,
                    generated.mode, config)

                let w = CodeWriter()
                w.writeRaw(prelude.toString())
                for (fragment in fragments) {
                    w.writeRaw(fragment)
                }
                fileWriter.writeFile(config.outputRelativePathForType(generated.namespace, firstTypeName), w.toString())
            }
            return true
        case None => return false
    }
}

func packageImportsUsedByFragments(
    packageName: String,
    packageImports: ArrayList<String>,
    fragments: ArrayList<String>
): ArrayList<String> {
    let result = ArrayList<String>()
    for (packageImport in packageImports) {
        if (packageImport == packageName) {
            continue
        }
        if (!shouldWritePackageImportForPackage(packageName, packageImport)) {
            continue
        }
        let aliasUse = "${importedPackageQualifier(packageImport)}."
        if (!fragmentsContainText(fragments, aliasUse)) {
            continue
        }
        if (!containsPackageImport(result, packageImport)) {
            result.add(packageImport)
        }
    }
    sortStrings(result)
    return result
}

func fragmentsContainText(fragments: ArrayList<String>, needle: String): Bool {
    for (fragment in fragments) {
        if (fragment.indexOf(needle, 0).isSome()) {
            return true
        }
    }
    return false
}

func writeNamespaceFacades(
    fileWriter: FileWriter,
    generatedFiles: ArrayList<NamespaceGenerationResult>,
    config: BindgenConfig,
    index: TypeIndex
): Unit {
    parallelForEach<NamespaceGenerationResult>(generatedFiles, config.jobs, {generated =>
        if (config.namespaceNeedsFacade(generated.namespace) && !generated.exports.isEmpty()) {
            writeOneNamespaceFacade(fileWriter, generated, config, index)
        }
    })
}

func writeOneNamespaceFacade(
    fileWriter: FileWriter,
    generated: NamespaceGenerationResult,
    config: BindgenConfig,
    index: TypeIndex
): Unit {
    let facade = CodeWriter()
    if (!config.noComment) {
        facade.writeLine("// Auto-generated by windows-bindgen. Do not edit.")
    }
    facade.writeLine("package ${config.facadePackageNameForNamespace(generated.namespace)}")
    facade.writeBlankLine()
    let feature = namespaceToFeature(generated.namespace)
    // Group exports by their availability condition so we can emit a single
    // brace-list `public import pkg.{a, b, c}` per group instead of one
    // `public import` per symbol. This dramatically cuts ImportPackages
    // CPU on facade packages (Win32.UI.Controls etc) which otherwise
    // re-export thousands of symbols one at a time.
    let groupedNames = HashMap<String, ArrayList<String>>()
    let groupedPackages = HashMap<String, String>()
    let groupedConditions = HashMap<String, String>()
    let groupOrder = ArrayList<String>()
    for (name in generated.exports) {
        let tags = facadeExportAvailabilityTags(index, generated.namespace, name)
        let condition = availabilityCondition(feature, tags)
        let ownerName = if (generated.exportOwners.contains(name)) {
            generated.exportOwners[name]
        } else {
            name
        }
        let targetPackage = config.packageNameForType(generated.namespace, ownerName)
        let groupKey = facadeImportGroupKey(condition, targetPackage)
        if (!groupedNames.contains(groupKey)) {
            groupedNames[groupKey] = ArrayList<String>()
            groupedPackages[groupKey] = targetPackage
            groupedConditions[groupKey] = condition
            groupOrder.add(groupKey)
        }
        groupedNames[groupKey].add(escapeSourceIdentifier(name))
    }
    for (groupKey in groupOrder) {
        let condition = groupedConditions[groupKey]
        let implementationPackage = groupedPackages[groupKey]
        let names = groupedNames[groupKey]
        if (!condition.isEmpty()) {
            facade.writeLine("@When[${condition}]")
        }
        if (names.size == 1) {
            facade.writeLine("public import ${implementationPackage}.${names[0]}")
        } else {
            let joined = String.join(names.toArray(), delimiter: ", ")
            facade.writeLine("public import ${implementationPackage}.{${joined}}")
        }
    }
    facade.writeBlankLine()
    fileWriter.writeFile(config.facadeOutputRelativePathForNamespace(generated.namespace), facade.toString())
}

func facadeImportGroupKey(condition: String, targetPackage: String): String {
    return "${targetPackage}\n${condition}"
}

func facadeExportAvailabilityTags(index: TypeIndex, namespace: String, name: String): ArrayList<String> {
    match (facadeWinrtImplSurfaceBaseName(name)) {
        case Some(baseName) =>
            let candidates = index.get(namespace, baseName)
            for (candidate in candidates) {
                let (fileIdx, row) = candidate
                let arches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
                if (isUnsupportedOnlyArchitecture(arches)) {
                    continue
                }
                match (index.typeDefCategory(fileIdx, row)) {
                    case Interface =>
                        let typeTags = typeAvailabilityTags(namespace, baseName, fileIdx, row, arches)
                        let ancestors = winmdCollectInterfaceAncestors(index, fileIdx, row)
                        return winrtInterfaceImplSurfaceAvailabilityTags(index, fileIdx, row, typeTags, ancestors)
                    case _ => ()
                }
            }
            return ArrayList<String>()
        case None => ()
    }

    return facadeTypeExportAvailabilityTags(index, namespace, facadeTypeExportBaseName(name), name)
}

func facadeTypeExportAvailabilityTags(
    index: TypeIndex,
    namespace: String,
    baseName: String,
    exportName: String
): ArrayList<String> {
    let candidates = index.get(namespace, baseName)
    for (candidate in candidates) {
        let (fileIdx, row) = candidate
        let arches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
        if (isUnsupportedOnlyArchitecture(arches)) {
            continue
        }
        match (index.typeDefCategory(fileIdx, row)) {
            case Interface =>
                if (isWinrtInterfaceRow(index, fileIdx, row)) {
                    return architectureCfgTags(arches)
                }
                return typeAvailabilityTags(namespace, baseName, fileIdx, row, arches)
            case Class =>
                return typeAvailabilityTags(namespace, baseName, fileIdx, row, arches)
            case Delegate =>
                if (isWinrtDelegateRow(index, fileIdx, row)) {
                    return typeAvailabilityTags(namespace, baseName, fileIdx, row, arches)
                }
                return mergedDelegateTypeAvailabilityTags(index, namespace, baseName, fileIdx, row)
            case Struct =>
                if (isHandleType(index, fileIdx, row)) {
                    return typeAvailabilityTags(namespace, baseName, fileIdx, row, arches)
                }
                let structSignature = buildStructSignature(index, fileIdx, row, baseName)
                if (!shouldEmitStructRow(index, namespace, baseName, fileIdx, row, structSignature)) {
                    continue
                }
                return mergedStructTypeAvailabilityTags(index, namespace, baseName, fileIdx, row, structSignature, "")
            case Enum =>
                return typeAvailabilityTags(namespace, baseName, fileIdx, row, arches)
            case Attribute =>
                return typeAvailabilityTags(namespace, baseName, fileIdx, row, arches)
        }
    }

    match (facadeNestedStructExportAvailabilityTags(index, namespace, exportName)) {
        case Some(tags) => return tags
        case None => ()
    }
    return ArrayList<String>()
}

func facadeNestedStructExportAvailabilityTags(
    index: TypeIndex,
    namespace: String,
    exportName: String
): Option<ArrayList<String>> {
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.typesInNamespace(namespace)
            for (entry in entries) {
                match (index.typeDefCategory(entry.fileIdx, entry.row)) {
                    case Struct =>
                        if (isHandleType(index, entry.fileIdx, entry.row)) {
                            continue
                        }
                        let name = trimTick(index.typeDefName(entry.fileIdx, entry.row))
                        if (exportName == name || !exportName.startsWith("${name}_")) {
                            continue
                        }
                        match (facadeNestedStructExportAvailabilityTagsFromRow(
                            index,
                            namespace,
                            entry.fileIdx,
                            entry.row,
                            name,
                            "",
                            ArrayList<String>(),
                            exportName
                        )) {
                            case Some(tags) => return Some(tags)
                            case None => ()
                        }
                    case _ => ()
                }
            }
        case None => ()
    }
    return None
}

func facadeNestedStructExportAvailabilityTagsFromRow(
    index: TypeIndex,
    namespace: String,
    fileIdx: Int64,
    row: Int64,
    name: String,
    parentArches: String,
    parentTags: ArrayList<String>,
    exportName: String
): Option<ArrayList<String>> {
    let arches = inheritArches(index.arches(TABLE_TYPE_DEF, fileIdx, row), parentArches)
    if (isUnsupportedOnlyArchitecture(arches)) {
        return None
    }
    let structSignature = buildStructSignature(index, fileIdx, row, name)
    if (!shouldEmitStructRow(index, namespace, name, fileIdx, row, structSignature)) {
        return None
    }
    let typeTags = mergeTypeMapCfgTags(
        parentTags,
        mergedStructTypeAvailabilityTags(index, namespace, name, fileIdx, row, structSignature, parentArches)
    )
    if (name == exportName) {
        return Some(typeTags)
    }
    if (!exportName.startsWith("${name}_")) {
        return None
    }

    let nestedRows = index.getNested(fileIdx, row)
    for (innerRow in nestedRows) {
        match (index.typeDefCategory(fileIdx, innerRow)) {
            case Struct =>
                let nestedName = "${name}_${nestedLeafName(index.typeDefName(fileIdx, innerRow))}"
                if (exportName == nestedName || exportName.startsWith("${nestedName}_")) {
                    match (facadeNestedStructExportAvailabilityTagsFromRow(
                        index,
                        namespace,
                        fileIdx,
                        innerRow,
                        nestedName,
                        arches,
                        typeTags,
                        exportName
                    )) {
                        case Some(tags) => return Some(tags)
                        case None => ()
                    }
                }
            case _ => ()
        }
    }
    return None
}

func facadeTypeExportBaseName(name: String): String {
    match (stripSuffix(name, "Vtbl")) {
        case Some(baseName) => return baseName
        case None => return name
    }
}

func isWinrtInterfaceRow(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    let flags = index.typeDefFlags(fileIdx, row)
    return flags.contains(TypeAttributes.WindowsRuntime) || winmdExtendsIInspectable(index, fileIdx, row)
}

func isWinrtDelegateRow(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    return index.typeDefFlags(fileIdx, row).contains(TypeAttributes.WindowsRuntime)
}

func facadeWinrtImplSurfaceBaseName(name: String): Option<String> {
    match (stripSuffix(name, "_ImplErased")) {
        case Some(baseName) => return Some(baseName)
        case None => ()
    }
    return stripSuffix(name, "_Impl")
}

func stripSuffix(value: String, suffix: String): Option<String> {
    if (!value.endsWith(suffix)) {
        return None
    }
    let valueArr = value.toArray()
    let suffixLen = Int64(suffix.toArray().size)
    return Some(String.fromUtf8(valueArr[0..Int64(valueArr.size) - suffixLen]))
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
        if (config.namespaceHasLayeredTypes(generated.namespace) && !generated.perTypeFragments.isEmpty()) {
            let realStem = groupedFileStemForNamespace(generated.namespace,
                config.packageNamespaceForNamespace(generated.namespace))
            // Sort type names so package chain registration order is stable.
            let sortedTypeNames = ArrayList<String>()
            for ((typeName, _) in generated.perTypeFragments) {
                sortedTypeNames.add(typeName)
            }
            sortStrings(sortedTypeNames)
            for (typeName in sortedTypeNames) {
                let implementationPackage = config.packageNameForType(generated.namespace, typeName)
                addRequiredPackageChain(requiredPackages, implementationPackage, rootPackage)
                if (realStem == "mod") {
                    packagesWithRealMod.add(implementationPackage)
                }
            }
        } else {
            let implementationPackage = config.packageNameForNamespace(generated.namespace)
            addRequiredPackageChain(requiredPackages, implementationPackage, rootPackage)
            if (groupedFileStemForNamespace(generated.namespace, config.packageNamespaceForNamespace(generated.namespace)) ==
                "mod") {
                packagesWithRealMod.add(implementationPackage)
            }
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

    parallelForEach<String>(packageList, config.jobs, {packageName =>
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
        fileWriter.writeFile(relativePath, stub.toString())
    })
}

func writePackageOutputStubs(
    fileWriter: FileWriter,
    generatedFiles: ArrayList<NamespaceGenerationResult>,
    config: BindgenConfig
): Unit {
    if (generatedFiles.isEmpty()) {
        return
    }

    let rootPackage = packageRootName(config.packageNameForNamespace(generatedFiles[0].namespace))
    if (rootPackage.isEmpty()) {
        return
    }

    let packagesWithRealMod = HashSet<String>()
    let requiredPackages = HashSet<String>()

    requiredPackages.add(rootPackage)

    for (generated in generatedFiles) {
        let packageName = config.packageNameForNamespace(generated.namespace)
        addRequiredPackageChain(requiredPackages, packageName, rootPackage)
        if (groupedFileStemForNamespace(generated.namespace, config.packageNamespaceForNamespace(generated.namespace)) ==
            "mod") {
            packagesWithRealMod.add(packageName)
        }
    }

    let packageList = ArrayList<String>()
    for (packageName in requiredPackages) {
        if (!packagesWithRealMod.contains(packageName)) {
            packageList.add(packageName)
        }
    }
    sortStrings(packageList)

    parallelForEach<String>(packageList, config.jobs, {packageName =>
        let relativeDir = FileWriter.packageNameToRelativeDirPath(packageName, rootPackage)
        let relativePath = if (relativeDir.isEmpty()) {
            "src/mod.cj"
        } else {
            "src/${relativeDir}/mod.cj"
        }

        let stub = CodeWriter()
        if (!config.noComment) {
            stub.writeLine("// Auto-generated by windows-bindgen. Do not edit.")
        }
        stub.writeLine("package ${packageName}")
        fileWriter.writeFile(relativePath, stub.toString())
    })
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

func packageRootName(packageName: String): String {
    let parts = splitString(packageName, b'.')
    if (parts.isEmpty()) {
        return packageName
    }
    return parts[0]
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

func collectCfgUniverse(index: TypeIndex): ArrayList<String> {
    let universe = FeatureCollector()
    for ((namespace, _, fileIdx, row) in index.iter()) {
        if (namespace.isEmpty() || !namespace.startsWith("Windows.")) {
            continue
        }
        universe.addNamespace(namespace)
        collectFeatures(index, fileIdx, row, namespace, universe)
    }
    return sortedFeatureKeys(universe)
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
                if (functionRequiresRuntimeEntryPointResolver(index, fileIdx, methodRow)) {
                    features.addBinding(namespace, "kernel32.dll")
                }
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
    let _ = mode
    let exports = ArrayList<String>()

    for (projectedType in projectedTypes) {
        collectProjectedPublicExportsForType(index, namespace, projectedType, config, exports)
    }

    sortStrings(exports)
    return exports
}

func collectProjectedPublicExportOwners(
    index: TypeIndex,
    namespace: String,
    projectedTypes: ArrayList<BindgenType>,
    mode: GenerationMode,
    config: BindgenConfig
): HashMap<String, String> {
    let _ = mode
    let owners = HashMap<String, String>()

    for (projectedType in projectedTypes) {
        let entry = bindgenTypeEntry(projectedType)
        let exports = ArrayList<String>()
        collectProjectedPublicExportsForType(index, namespace, projectedType, config, exports)
        for (name in exports) {
            addExportOwner(owners, name, entry.name)
        }
    }

    return owners
}

func collectProjectedPublicExportsForType(
    index: TypeIndex,
    namespace: String,
    projectedType: BindgenType,
    config: BindgenConfig,
    exports: ArrayList<String>
): Unit {
    let entry = bindgenTypeEntry(projectedType)
    match (projectedType) {
        case HighLevelInterface(_) => collectWinrtInterfaceExports(index, entry.fileIdx, entry.row, config, exports)
        case HighLevelClass(_) => collectWinrtClassExports(index, entry.fileIdx, entry.row, exports)
        case HighLevelDelegate(_) => collectWinrtDelegateExports(index, entry.fileIdx, entry.row, exports)
        case HighLevelEnum(_) => collectEnumExports(index, entry.fileIdx, entry.row, namespace, exports)
        case HighLevelStruct(_) => collectStructExports(index, entry.fileIdx, entry.row, namespace,
            trimTick(index.typeDefName(entry.fileIdx, entry.row)), exports)
        case CppInterface(_) => collectCppInterfaceExports(index, entry.fileIdx, entry.row, exports)
        case Handle(_) => collectHandleExports(index, entry.fileIdx, entry.row, exports)
        case CppStruct(_) => collectStructExports(index, entry.fileIdx, entry.row, namespace,
            trimTick(index.typeDefName(entry.fileIdx, entry.row)), exports)
        case CppEnum(_) => collectEnumExports(index, entry.fileIdx, entry.row, namespace, exports)
        case CppDelegate(_) => collectDelegateExports(index, entry.fileIdx, entry.row, namespace, exports)
        case CppFn(_) => collectCppFunctionExports(index, entry.fileIdx, entry.row, namespace, config, exports)
        case Attribute(_) => ()
    }
}

func addExportOwner(owners: HashMap<String, String>, name: String, owner: String): Unit {
    if (name.isEmpty() || owners.contains(name)) {
        return
    }
    owners[name] = owner
}

func collectWinrtInterfaceExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    config: BindgenConfig,
    exports: ArrayList<String>
): Unit {
    if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
        return
    }

    let name = trimTick(index.typeDefName(fileIdx, row))
    addExportName(exports, "${name}Vtbl")
    let isExclusive = index.hasAttribute(TABLE_TYPE_DEF, fileIdx, row, "ExclusiveToAttribute")
    if (shouldEmitWinrtImplSurface(config, isExclusive)) {
        addExportName(exports, "${name}_ImplErased")
        addExportName(exports, "${name}_Impl")
    }
    addExportName(exports, name)
}

func collectWinrtClassExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    exports: ArrayList<String>
): Unit {
    if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
        return
    }

    addExportName(exports, trimTick(index.typeDefName(fileIdx, row)))
}

func collectWinrtDelegateExports(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    exports: ArrayList<String>
): Unit {
    if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
        return
    }

    let name = trimTick(index.typeDefName(fileIdx, row))
    addExportName(exports, "${name}Vtbl")
    addExportName(exports, name)
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
    if (shouldSkipSyntheticNestedStructEntry(index, namespace, name)) {
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
