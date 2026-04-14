package windows_bindgen

import std.collection.*
import std.fs.*
import windows_metadata.*
import windows_bindgen.types.*

public class BindgenConfig {
    public var winmdPaths: ArrayList<String> = ArrayList<String>()
    public var outputDir: String = ""
    public var filterNamespaces: ArrayList<String> = ArrayList<String>()
    public var excludeNamespaces: ArrayList<String> = ArrayList<String>()
    public var generateSys: Bool = true
    public var generateHighLevel: Bool = false
    public var flat: Bool = false
    public var referenceArgs: ArrayList<String> = ArrayList<String>()
    public var implement: Bool = false
    public var noAllow: Bool = false
    public var noComment: Bool = false
    public var sysFnPtrs: Bool = false
    public var link: String = ""
    public var index: Bool = false
    public var packageOutput: Bool = false
    public var packageName: String = ""
    public var specificDeps: Bool = false
    public var noDeps: Bool = false
    public var derivesByType: HashMap<TypeName, Array<String>> = HashMap<TypeName, Array<String>>()

    var rawDerivesByType: HashMap<String, Array<String>> = HashMap<String, Array<String>>()
    var deriveTargetOrder: ArrayList<String> = ArrayList<String>()
    var inferredOutputRootPackageName: String = ""
    var resolvedOutputRootPackageName: Bool = false
    var inferredOutputPackageRoot: String = ""
    var resolvedOutputPackageRoot: Bool = false
    var generatedPackageNamespaces: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public static func parseArgs(args: Array<String>): BindgenConfig {
        let config = BindgenConfig()
        var kind = ArgKind.None
        var i: Int64 = 0
        while (i < Int64(args.size)) {
            let arg = args[i]
            if (startsWith(arg, "--")) {
                if (isPackageArgKind(kind)) {
                    config.packageOutput = true
                    kind = ArgKind.None
                }
                match (arg) {
                    case "--in" => kind = ArgKind.Input
                    case "--out" => kind = ArgKind.Output
                    case "--filter" => kind = ArgKind.Filter
                    case "--reference" => kind = ArgKind.Reference
                    case "--implement" =>
                        config.implement = true
                        kind = ArgKind.Implement
                    case "--derive" => kind = ArgKind.Derive
                    case "--link" => kind = ArgKind.Link
                    case "--package" => kind = ArgKind.Package
                    case "--specific-deps" =>
                        config.specificDeps = true
                        kind = ArgKind.None
                    case "--sys" =>
                        config.generateSys = true
                        kind = ArgKind.None
                    case "--no-sys" =>
                        config.generateSys = false
                        kind = ArgKind.None
                    case "--high-level" =>
                        config.generateHighLevel = true
                        kind = ArgKind.None
                    case "--no-high-level" =>
                        config.generateHighLevel = false
                        kind = ArgKind.None
                    case "--flat" =>
                        config.flat = true
                        kind = ArgKind.None
                    case "--no-deps" =>
                        config.noDeps = true
                        kind = ArgKind.None
                    case "--no-allow" =>
                        config.noAllow = true
                        kind = ArgKind.None
                    case "--no-comment" =>
                        config.noComment = true
                        kind = ArgKind.None
                    case "--sys-fn-ptrs" =>
                        config.sysFnPtrs = true
                        kind = ArgKind.None
                    case "--index" =>
                        config.index = true
                        kind = ArgKind.None
                    case _ => kind = ArgKind.None
                }
                i += 1
                continue
            }

            match (kind) {
                case None => ()
                case Input => config.winmdPaths.add(arg)
                case Output =>
                    config.outputDir = arg
                    kind = ArgKind.None
                case Filter =>
                    if (startsWith(arg, "!")) {
                        let arr = arg.toArray()
                        config.excludeNamespaces.add(String.fromUtf8(arr[1..Int64(arr.size)]))
                    } else {
                        config.filterNamespaces.add(arg)
                    }
                case Reference =>
                    config.referenceArgs.add(arg)
                    kind = ArgKind.None
                case Implement =>
                    match (parseBoolOption(arg)) {
                        case Some(value) => config.implement = value
                        case None => config.implement = true
                    }
                    kind = ArgKind.None
                case Derive =>
                    addDeriveConfig(config, arg)
                    kind = ArgKind.None
                case Link =>
                    config.link = arg
                    kind = ArgKind.None
                case Package =>
                    config.packageName = arg
                    kind = ArgKind.None
            }
            i += 1
        }

        if (isPackageArgKind(kind)) {
            config.packageOutput = true
        }
        if (!config.packageName.isEmpty() && !config.flat) {
            throw Exception("`--package <name>` requires `--flat`")
        }
        if (config.packageOutput && config.flat && config.packageName.isEmpty()) {
            throw Exception("cannot combine `--package` and `--flat`")
        }
        return config
    }

    public func hasEnabledGenerator(): Bool {
        return generateSys || generateHighLevel
    }

    public func primaryMode(): GenerationMode {
        if (generateHighLevel && !generateSys) {
            return GenerationMode.HighLevel
        }
        return GenerationMode.Sys
    }

    public func shouldImplementType(namespace: String, name: String): Bool {
        implement
    }

    public func packageNameForNamespace(namespace: String): String {
        if (usesSubpackageLayout()) {
            return FileWriter.namespaceToHierarchicalPackageName(packageNamespaceForNamespace(namespace),
                outputRootPackageName())
        }
        if (!packageName.isEmpty()) {
            return packageName
        }
        return FileWriter.namespaceToPackageName(namespace)
    }

    public func packageNamespaceForNamespace(namespace: String): String {
        if (usesSubpackageLayout() && generatedPackageNamespaces.contains(namespace)) {
            return generatedPackageNamespaces[namespace]
        }
        return namespace
    }

    public func namespaceNeedsFacade(namespace: String): Bool {
        if (!usesSubpackageLayout()) {
            return false
        }
        return packageNamespaceForNamespace(namespace) != namespace
    }

    public func facadePackageNameForNamespace(namespace: String): String {
        if (usesSubpackageLayout()) {
            return FileWriter.namespaceToHierarchicalPackageName(namespace, outputRootPackageName())
        }
        return packageNameForNamespace(namespace)
    }

    public func usesSubpackageLayout(): Bool {
        match (primaryMode()) {
            case GenerationMode.Sys => ()
            case _ => return false
        }
        if (!packageName.isEmpty() || packageOutput) {
            return false
        }
        return !outputPackageRoot().isEmpty() && !outputRootPackageName().isEmpty()
    }

    func outputRootPackageName(): String {
        if (resolvedOutputRootPackageName) {
            return inferredOutputRootPackageName
        }
        resolvedOutputRootPackageName = true
        inferredOutputRootPackageName = inferOutputRootPackageName(outputDir)
        return inferredOutputRootPackageName
    }

    public func artifactOutputDir(): String {
        if (usesSubpackageLayout()) {
            return outputPackageRoot()
        }
        return outputDir
    }

    func outputPackageRoot(): String {
        if (resolvedOutputPackageRoot) {
            return inferredOutputPackageRoot
        }
        resolvedOutputPackageRoot = true
        inferredOutputPackageRoot = inferOutputPackageRoot(outputDir)
        return inferredOutputPackageRoot
    }

    public func sharesGeneratedPackage(leftNamespace: String, rightNamespace: String): Bool {
        if (leftNamespace.isEmpty() || rightNamespace.isEmpty()) {
            return false
        }
        return packageNamespaceForNamespace(leftNamespace) == packageNamespaceForNamespace(rightNamespace)
    }

    public func outputRelativePathForNamespace(namespace: String): String {
        if (usesSubpackageLayout()) {
            let packageNamespace = packageNamespaceForNamespace(namespace)
            let dirPath = FileWriter.namespaceToHierarchicalDirPath(packageNamespace)
            let stem = groupedFileStemForNamespace(namespace, packageNamespace)
            if (dirPath.isEmpty()) {
                return "${stem}.cj"
            }
            return "${dirPath}/${stem}.cj"
        }
        let dirPath = FileWriter.namespaceToDirPath(namespace)
        if (flat) {
            return "${sanitizePackageSegment(lastNamespaceComponent(namespace))}.cj"
        }
        if (packageOutput) {
            return "src/${dirPath}/mod.cj"
        }
        return "${dirPath}/mod.cj"
    }

    public func facadeOutputRelativePathForNamespace(namespace: String): String {
        if (usesSubpackageLayout()) {
            let dirPath = FileWriter.namespaceToHierarchicalDirPath(namespace)
            if (dirPath.isEmpty()) {
                return "mod.cj"
            }
            return "${dirPath}/mod.cj"
        }
        return outputRelativePathForNamespace(namespace)
    }

    public func resolveGeneratedPackages(index: TypeIndex, typeMap: TypeMap): Unit {
        generatedPackageNamespaces.clear()
        if (!usesSubpackageLayout()) {
            return
        }
        let namespaces = typeMap.namespaces()
        let graph = buildNamespaceDependencyGraph(index, typeMap)
        let components = computeNamespaceComponents(namespaces, graph)
        for (component in components) {
            if (component.isEmpty()) {
                continue
            }

            let mergedNamespace = if (component.size == 1) {
                component[0]
            } else {
                "${chooseComponentPackageNamespace(component)}.impl"
            }

            for (namespace in component) {
                generatedPackageNamespaces[namespace] = mergedNamespace
            }
        }

        var changed = true
        while (changed) {
            changed = false
            let packageGraph = buildGeneratedPackageDependencyGraph(namespaces, graph, generatedPackageNamespaces)
            let packageNames = ArrayList<String>()
            for ((packageName, _) in packageGraph) {
                if (!containsString(packageNames, packageName)) {
                    packageNames.add(packageName)
                }
            }
            for (namespace in namespaces) {
                let packageName = generatedPackageNamespaces[namespace]
                if (!containsString(packageNames, packageName)) {
                    packageNames.add(packageName)
                }
            }

            let packageComponents = computeNamespaceComponents(packageNames, packageGraph)
            for (component in packageComponents) {
                if (component.size <= 1) {
                    continue
                }

                let mergedNamespaces = collectNamespacesForGeneratedPackages(namespaces, generatedPackageNamespaces,
                    component)
                if (mergedNamespaces.isEmpty()) {
                    continue
                }

                let mergedPackage = "${chooseComponentPackageNamespace(mergedNamespaces)}.impl"
                var needsMerge = false
                for (namespace in mergedNamespaces) {
                    if (generatedPackageNamespaces[namespace] != mergedPackage) {
                        needsMerge = true
                        break
                    }
                }
                if (!needsMerge) {
                    continue
                }

                for (namespace in mergedNamespaces) {
                    generatedPackageNamespaces[namespace] = mergedPackage
                }
                changed = true
            }
        }
    }

    public func resolveDeriveTargets(index: TypeIndex, typeMap: TypeMap): Unit {
        if (rawDerivesByType.isEmpty()) {
            return
        }

        let resolved = HashMap<TypeName, Array<String>>()
        for (rawTarget in deriveTargetOrder) {
            if (!rawDerivesByType.contains(rawTarget)) {
                continue
            }

            let qualifiedTarget = resolveDeriveTargetName(index, typeMap, rawTarget)
            resolved[qualifiedTarget] = rawDerivesByType[rawTarget]
        }

        derivesByType = resolved
    }

    public func derivesForType(namespace: String, name: String): Array<String> {
        let key = TypeName.named(namespace, trimTick(name))
        if (derivesByType.contains(key)) {
            return derivesByType[key]
        }
        return Array<String>(0, {_ => ""})
    }

    public func typeHasDerive(namespace: String, name: String, traitName: String): Bool {
        let derives = derivesForType(namespace, name)
        for (derive in derives) {
            if (derive == traitName) {
                return true
            }
        }
        return false
    }

    public func namespaceHasDerives(namespace: String): Bool {
        for ((typeName, _) in derivesByType) {
            if (typeName.namespace == namespace) {
                return true
            }
        }
        return false
    }

    public func references(index: TypeIndex): References {
        let args = ArrayList<String>()
        appendDefaultReferenceArgs(this, args, index)
        for (arg in referenceArgs) {
            args.add(arg)
        }
        References(args)
    }
}

func buildNamespaceDependencyGraph(
    index: TypeIndex,
    typeMap: TypeMap
): HashMap<String, ArrayList<String>> {
    let graph = HashMap<String, ArrayList<String>>()
    for (namespace in typeMap.namespaces()) {
        graph[namespace] = ArrayList<String>()
    }

    for (namespace in typeMap.namespaces()) {
        let dependencies = HashMap<String, Bool>()
        for (entry in typeMap.typesInNamespace(namespace)) {
            let typeDependencies = collectTypeDependencies(index, entry.fileIdx, entry.row)
            for (dependency in typeDependencies) {
                let dependencyName = dependency.definition()
                if (dependencyName.namespace.isEmpty() || dependencyName.namespace == namespace ||
                    !typeMap.containsType(dependencyName)) {
                    continue
                }
                dependencies[dependencyName.namespace] = true
            }
        }

        let edges = ArrayList<String>()
        for ((dependencyNamespace, _) in dependencies) {
            edges.add(dependencyNamespace)
        }
        sortStrings(edges)
        graph[namespace] = edges
    }

    return graph
}

func computeNamespaceComponents(
    namespaces: ArrayList<String>,
    graph: HashMap<String, ArrayList<String>>
): ArrayList<ArrayList<String>> {
    let visited = HashMap<String, Bool>()
    let order = ArrayList<String>()
    for (namespace in namespaces) {
        dfsNamespaceOrder(namespace, graph, visited, order)
    }

    let reversed = reverseNamespaceGraph(namespaces, graph)
    visited.clear()
    let components = ArrayList<ArrayList<String>>()
    var i = Int64(order.size) - 1
    while (i >= 0) {
        let namespace = order[i]
        if (visited.contains(namespace)) {
            i -= 1
            continue
        }

        let component = ArrayList<String>()
        dfsNamespaceCollect(namespace, reversed, visited, component)
        sortStrings(component)
        components.add(component)
        i -= 1
    }

    return components
}

func reverseNamespaceGraph(
    namespaces: ArrayList<String>,
    graph: HashMap<String, ArrayList<String>>
): HashMap<String, ArrayList<String>> {
    let reversed = HashMap<String, ArrayList<String>>()
    for (namespace in namespaces) {
        reversed[namespace] = ArrayList<String>()
    }

    for ((namespace, edges) in graph) {
        for (edge in edges) {
            if (!reversed.contains(edge)) {
                reversed[edge] = ArrayList<String>()
            }
            reversed[edge].add(namespace)
        }
    }

    for ((_, edges) in reversed) {
        sortStrings(edges)
    }
    return reversed
}

func dfsNamespaceOrder(
    namespace: String,
    graph: HashMap<String, ArrayList<String>>,
    visited: HashMap<String, Bool>,
    order: ArrayList<String>
): Unit {
    if (visited.contains(namespace)) {
        return
    }

    visited[namespace] = true
    if (graph.contains(namespace)) {
        for (dependency in graph[namespace]) {
            dfsNamespaceOrder(dependency, graph, visited, order)
        }
    }
    order.add(namespace)
}

func dfsNamespaceCollect(
    namespace: String,
    graph: HashMap<String, ArrayList<String>>,
    visited: HashMap<String, Bool>,
    component: ArrayList<String>
): Unit {
    if (visited.contains(namespace)) {
        return
    }

    visited[namespace] = true
    component.add(namespace)
    if (graph.contains(namespace)) {
        for (dependency in graph[namespace]) {
            dfsNamespaceCollect(dependency, graph, visited, component)
        }
    }
}

func chooseComponentPackageNamespace(component: ArrayList<String>): String {
    if (component.isEmpty()) {
        return ""
    }
    if (component.size == 1) {
        return component[0]
    }

    let firstParts = splitString(component[0], b'.')
    let prefix = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(firstParts.size)) {
        let candidate = firstParts[i]
        var matchesAll = true
        for (namespace in component) {
            let parts = splitString(namespace, b'.')
            if (i >= Int64(parts.size) || parts[i] != candidate) {
                matchesAll = false
                break
            }
        }
        if (!matchesAll) {
            break
        }
        prefix.add(candidate)
        i += 1
    }

    if (prefix.isEmpty()) {
        return component[0]
    }
    return joinStrings(prefix, ".")
}

func buildGeneratedPackageDependencyGraph(
    namespaces: ArrayList<String>,
    namespaceGraph: HashMap<String, ArrayList<String>>,
    packageAssignments: HashMap<String, String>
): HashMap<String, ArrayList<String>> {
    let result = HashMap<String, ArrayList<String>>()

    for (namespace in namespaces) {
        if (!packageAssignments.contains(namespace)) {
            continue
        }
        let sourcePackage = packageAssignments[namespace]
        if (!result.contains(sourcePackage)) {
            result[sourcePackage] = ArrayList<String>()
        }

        if (!namespaceGraph.contains(namespace)) {
            continue
        }

        for (dependency in namespaceGraph[namespace]) {
            if (!packageAssignments.contains(dependency)) {
                continue
            }
            let targetPackage = packageAssignments[dependency]
            if (targetPackage == sourcePackage) {
                continue
            }
            if (!containsString(result[sourcePackage], targetPackage)) {
                result[sourcePackage].add(targetPackage)
            }
        }
    }

    for ((_, edges) in result) {
        sortStrings(edges)
    }
    return result
}

func collectNamespacesForGeneratedPackages(
    namespaces: ArrayList<String>,
    packageAssignments: HashMap<String, String>,
    packages: ArrayList<String>
): ArrayList<String> {
    let result = ArrayList<String>()
    for (namespace in namespaces) {
        if (!packageAssignments.contains(namespace)) {
            continue
        }
        if (containsString(packages, packageAssignments[namespace])) {
            result.add(namespace)
        }
    }
    sortStrings(result)
    return result
}

func lastNamespaceComponent(namespace: String): String {
    let parts = splitString(namespace, b'.')
    if (parts.isEmpty()) {
        return namespace
    }
    return parts[parts.size - 1]
}

func isImplementationPackageNamespace(namespace: String): Bool {
    return namespace.endsWith(".impl")
}

func implementationOwnerNamespace(namespace: String): String {
    if (!isImplementationPackageNamespace(namespace)) {
        return namespace
    }
    let arr = namespace.toArray()
    return String.fromUtf8(arr[0..Int64(arr.size) - Int64(".impl".toArray().size)])
}

func groupedFileStemForNamespace(namespace: String, packageNamespace: String): String {
    if (!isImplementationPackageNamespace(packageNamespace)) {
        return FileWriter.namespaceToGroupedFileStem(namespace, packageNamespace)
    }
    return FileWriter.namespaceToGroupedFileStem(namespace, implementationOwnerNamespace(packageNamespace))
}

enum ArgKind {
    | None
    | Input
    | Output
    | Filter
    | Reference
    | Implement
    | Derive
    | Link
    | Package
}

func isPackageArgKind(kind: ArgKind): Bool {
    match (kind) {
        case ArgKind.Package => true
        case _ => false
    }
}

public enum GenerationMode {
    | Sys
    | HighLevel
}

func splitCsv(value: String): ArrayList<String> {
    let result = ArrayList<String>()
    let arr = value.toArray()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b',') {
            if (i > start) {
                result.add(String.fromUtf8(arr[start..i]))
            }
            start = i + 1
        }
        i += 1
    }
    if (start < Int64(arr.size)) {
        result.add(String.fromUtf8(arr[start..Int64(arr.size)]))
    }
    return result
}

func addDeriveConfig(config: BindgenConfig, value: String): Unit {
    match (splitDeriveArg(value)) {
        case Some((rawTarget, rawTraits)) =>
            let target = trimAsciiWhitespace(rawTarget)
            if (target.isEmpty()) {
                throw Exception("`--derive` must be `<type name>=Comma,Separated,List`")
            }

            let traits = normalizeDeriveTraits(rawTraits)
            config.deriveTargetOrder.add(target)
            config.rawDerivesByType[target] = traits
        case None => throw Exception("`--derive` must be `<type name>=Comma,Separated,List`")
    }
}

func splitDeriveArg(value: String): Option<(String, ArrayList<String>)> {
    let arr = value.toArray()
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'=') {
            return Some((String.fromUtf8(arr[0..i]), splitCsv(String.fromUtf8(arr[i + 1..Int64(arr.size)]))))
        }
        i += 1
    }
    return None
}

func normalizeDeriveTraits(rawTraits: ArrayList<String>): Array<String> {
    let normalized = ArrayList<String>()
    for (rawTrait in rawTraits) {
        let traitName = normalizeDeriveTraitName(trimAsciiWhitespace(rawTrait))
        if (!traitName.isEmpty() && !containsString(normalized, traitName)) {
            normalized.add(traitName)
        }
    }

    if (normalized.isEmpty()) {
        throw Exception("`--derive` must include at least one supported trait")
    }

    return normalized.toArray()
}

func normalizeDeriveTraitName(rawTrait: String): String {
    match (rawTrait) {
        case "ToString" => return "ToString"
        case "Hash" => return "Hashable"
        case "Hashable" => return "Hashable"
        case "Eq" => return "Equatable"
        case "PartialEq" => return "Equatable"
        case "Equatable" => return "Equatable"
        case "Ord" => return "Comparable"
        case "PartialOrd" => return "Comparable"
        case "Comparable" => return "Comparable"
        case _ => throw Exception("unsupported derive trait: `${rawTrait}`")
    }
}

func appendDefaultReferenceArgs(config: BindgenConfig, args: ArrayList<String>, index: TypeIndex): Unit {
    if (config.generateSys || config.noDeps) {
        return
    }

    if (index.containsNamespace("Windows.Foundation")) {
        args.add("windows_collections,flat,Windows.Foundation.Collections")
        args.add("windows_numerics,flat,Windows.Foundation.Numerics")
        args.add("windows_future,flat,Windows.Foundation.Async*")
        args.add("windows_future,flat,Windows.Foundation.IAsync*")
    }

    let corePackage = if (config.specificDeps) {
        "windows_result"
    } else {
        "windows_core"
    }

    if (index.contains("Windows.Win32.Foundation", "WIN32_ERROR")) {
        args.add("${corePackage},flat,Windows.Win32.Foundation.WIN32_ERROR")
    }
    if (index.contains("Windows.Win32.Foundation", "NTSTATUS")) {
        args.add("${corePackage},flat,Windows.Win32.Foundation.NTSTATUS")
    }
    if (index.contains("Windows.Win32.System.Rpc", "RPC_STATUS")) {
        args.add("${corePackage},flat,Windows.Win32.System.Rpc.RPC_STATUS")
    }
}

func resolveDeriveTargetName(index: TypeIndex, typeMap: TypeMap, rawTarget: String): TypeName {
    let target = trimAsciiWhitespace(rawTarget)
    match (parseQualifiedTypeName(target)) {
        case Some(typeName) =>
            let erased = typeName.definition()
            validateDeriveTarget(index, typeMap, erased.namespace, trimTick(erased.name), target)
            return erased
        case None => return resolveShortDeriveTargetName(index, typeMap, target)
    }
}

func resolveShortDeriveTargetName(index: TypeIndex, typeMap: TypeMap, name: String): TypeName {
    let includedMatches = ArrayList<TypeName>()
    for (namespace in typeMap.namespaces()) {
        let types = typeMap.typesInNamespace(namespace)
        for (entry in types) {
            if (entry.name == name) {
                includedMatches.add(entry.typeName)
            }
        }
    }

    if (includedMatches.size == 1) {
        return includedMatches[0]
    }
    if (includedMatches.size > 1) {
        throw Exception("ambiguous derive target: `${name}`")
    }

    let knownMatches = ArrayList<TypeName>()
    for (entry in index.iter()) {
        let (namespace, typeName, _, _) = entry
        if (typeName == name) {
            let qualifiedName = TypeName.named(namespace, typeName)
            if (!containsTypeName(knownMatches, qualifiedName)) {
                knownMatches.add(qualifiedName)
            }
        }
    }

    if (knownMatches.isEmpty()) {
        throw Exception("type not found: `${name}`")
    }
    throw Exception("type not included: `${name}`")
}

func validateDeriveTarget(
    index: TypeIndex,
    typeMap: TypeMap,
    namespace: String,
    name: String,
    rawTarget: String
): Unit {
    let candidates = index.get(namespace, name)
    if (candidates.isEmpty()) {
        throw Exception("type not found: `${rawTarget}`")
    }
    if (!typeMap.containsType(namespace, name)) {
        throw Exception("type not included: `${rawTarget}`")
    }

    let (fileIdx, row) = candidates[0]
    let category = index.typeDefCategory(fileIdx, row)
    match (category) {
        case Struct =>
            if (isHandleType(index, fileIdx, row)) {
                throw Exception("unsupported derive target: `${rawTarget}`")
            }
        case Enum => ()
        case _ => throw Exception("unsupported derive target: `${rawTarget}`")
    }
}

func trimAsciiWhitespace(value: String): String {
    let arr = value.toArray()
    if (arr.isEmpty()) {
        return value
    }

    var start: Int64 = 0
    var end = Int64(arr.size)
    while (start < end && isAsciiWhitespace(arr[start])) {
        start += 1
    }
    while (end > start && isAsciiWhitespace(arr[end - 1])) {
        end -= 1
    }
    return String.fromUtf8(arr[start..end])
}

func isAsciiWhitespace(ch: Byte): Bool {
    return ch == b' ' || ch == b'\t' || ch == b'\r' || ch == b'\n'
}

func inferOutputRootPackageName(outputDir: String): String {
    let packageRoot = inferOutputPackageRoot(outputDir)
    if (packageRoot.isEmpty()) {
        return ""
    }

    let cjpmTomlPath = "${packageRoot}/cjpm.toml"
    if (!exists(cjpmTomlPath)) {
        return ""
    }

    return parseCjpmPackageName(String.fromUtf8(File.readFrom(cjpmTomlPath)))
}

func inferOutputPackageRoot(outputDir: String): String {
    let normalizedOutputDir = trimTrailingPathSeparators(outputDir)
    if (pathBaseName(normalizedOutputDir) != "src") {
        return ""
    }

    let packageRoot = pathParent(normalizedOutputDir)
    if (packageRoot.isEmpty()) {
        return ""
    }

    let cjpmTomlPath = "${packageRoot}/cjpm.toml"
    if (!exists(cjpmTomlPath)) {
        return ""
    }
    return packageRoot
}

func parseCjpmPackageName(content: String): String {
    let lines = splitLines(content)
    var inPackageTable = false
    for (line in lines) {
        let trimmed = trimAsciiWhitespace(line)
        if (trimmed.isEmpty() || startsWith(trimmed, "#")) {
            continue
        }

        if (trimmed == "[package]") {
            inPackageTable = true
            continue
        }
        if (startsWith(trimmed, "[")) {
            inPackageTable = false
            continue
        }
        if (!inPackageTable) {
            continue
        }

        let packageName = parseQuotedAssignment(trimmed, "name")
        if (!packageName.isEmpty()) {
            return packageName
        }
    }
    return ""
}

func parseQuotedAssignment(line: String, key: String): String {
    if (!startsWith(line, key)) {
        return ""
    }

    let arr = line.toArray()
    var i = Int64(key.toArray().size)
    while (i < Int64(arr.size) && isAsciiWhitespace(arr[i])) {
        i += 1
    }
    if (i >= Int64(arr.size) || arr[i] != b'=') {
        return ""
    }

    i += 1
    while (i < Int64(arr.size) && isAsciiWhitespace(arr[i])) {
        i += 1
    }
    if (i >= Int64(arr.size) || arr[i] != b'"') {
        return ""
    }

    i += 1
    let start = i
    while (i < Int64(arr.size) && arr[i] != b'"') {
        i += 1
    }
    if (i <= start || i >= Int64(arr.size)) {
        return ""
    }
    return String.fromUtf8(arr[start..i])
}

func splitLines(content: String): ArrayList<String> {
    let arr = content.toArray()
    let lines = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'\n') {
            var end = i
            if (end > start && arr[end - 1] == b'\r') {
                end -= 1
            }
            lines.add(String.fromUtf8(arr[start..end]))
            start = i + 1
        }
        i += 1
    }
    if (start <= Int64(arr.size)) {
        lines.add(String.fromUtf8(arr[start..Int64(arr.size)]))
    }
    return lines
}

func trimTrailingPathSeparators(path: String): String {
    let arr = path.toArray()
    var end = Int64(arr.size)
    while (end > 0 && (arr[end - 1] == b'/' || arr[end - 1] == b'\\')) {
        end -= 1
    }
    if (end <= 0) {
        return path
    }
    return String.fromUtf8(arr[0..end])
}

func pathBaseName(path: String): String {
    let arr = path.toArray()
    if (arr.isEmpty()) {
        return ""
    }

    var lastSep: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'/' || arr[i] == b'\\') {
            lastSep = i
        }
        i += 1
    }
    return String.fromUtf8(arr[lastSep + 1..Int64(arr.size)])
}

func pathParent(path: String): String {
    let arr = path.toArray()
    if (arr.isEmpty()) {
        return ""
    }

    var lastSep: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'/' || arr[i] == b'\\') {
            lastSep = i
        }
        i += 1
    }
    if (lastSep < 0) {
        return ""
    }
    return String.fromUtf8(arr[0..lastSep])
}

func containsString(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func containsTypeName(values: ArrayList<TypeName>, target: TypeName): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func parseBoolOption(value: String): Option<Bool> {
    if (value == "true" || value == "1" || value == "yes" || value == "on") {
        return Some(true)
    }
    if (value == "false" || value == "0" || value == "no" || value == "off") {
        return Some(false)
    }
    None
}

func startsWith(s: String, prefix: String): Bool {
    let sArr = s.toArray()
    let pArr = prefix.toArray()
    if (Int64(sArr.size) < Int64(pArr.size)) {
        return false
    }
    var i: Int64 = 0
    while (i < Int64(pArr.size)) {
        if (sArr[i] != pArr[i]) {
            return false
        }
        i += 1
    }
    return true
}

func namespaceStartsWith(namespace: String, prefix: String): Bool {
    if (!startsWith(namespace, prefix)) {
        return false
    }
    let nsArr = namespace.toArray()
    let pLen = Int64(prefix.toArray().size)
    return Int64(nsArr.size) == pLen || (Int64(nsArr.size) > pLen && nsArr[pLen] == b'.')
}
