package windows_bindgen

import std.collection.*

public class PackageLayoutResult {
    public let assignments: HashMap<String, String>
    public let namespaceGraphNodeCount: Int64
    public let namespaceGraphEdgeCount: Int64
    public let initialMultiNodeSccCount: Int64
    public let residualMergeCount: Int64
    public let finalPackageGraph: HashMap<String, ArrayList<String>>
    public let finalMultiNodeSccCount: Int64

    public init(
        assignments: HashMap<String, String>,
        namespaceGraphNodeCount: Int64,
        namespaceGraphEdgeCount: Int64,
        initialMultiNodeSccCount: Int64,
        residualMergeCount: Int64,
        finalPackageGraph: HashMap<String, ArrayList<String>>,
        finalMultiNodeSccCount: Int64
    ) {
        this.assignments = assignments
        this.namespaceGraphNodeCount = namespaceGraphNodeCount
        this.namespaceGraphEdgeCount = namespaceGraphEdgeCount
        this.initialMultiNodeSccCount = initialMultiNodeSccCount
        this.residualMergeCount = residualMergeCount
        this.finalPackageGraph = finalPackageGraph
        this.finalMultiNodeSccCount = finalMultiNodeSccCount
    }

    public func packageNamespaceForNamespace(namespace: String): String {
        if (assignments.contains(namespace)) {
            return assignments[namespace]
        }
        return namespace
    }

    public func layoutJson(): String {
        let namespaces = layoutSortedAssignmentKeys(assignments)
        let implPackages = collectImplPackages(namespaces, assignments)
        let sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"input\": {\n")
        sb.append("    \"feature_mode\": \"all-features-on\",\n")
        sb.append("    \"namespace_count\": ${namespaceGraphNodeCount}\n")
        sb.append("  },\n")
        sb.append("  \"graphs\": {\n")
        sb.append("    \"namespace_graph\": {\n")
        sb.append("      \"nodes\": ${namespaceGraphNodeCount},\n")
        sb.append("      \"edges\": ${namespaceGraphEdgeCount},\n")
        sb.append("      \"multi_node_scc_count\": ${initialMultiNodeSccCount}\n")
        sb.append("    },\n")
        sb.append("    \"package_graph_after_merge\": {\n")
        sb.append("      \"nodes\": ${Int64(packageGraphNodes(finalPackageGraph).size)},\n")
        sb.append("      \"edges\": ${countPackageGraphEdges(finalPackageGraph)},\n")
        sb.append("      \"multi_node_scc_count\": ${finalMultiNodeSccCount}\n")
        sb.append("    }\n")
        sb.append("  },\n")
        sb.append("  \"layout\": {\n")
        sb.append("    \"namespaces\": {\n")
        var i: Int64 = 0
        while (i < Int64(namespaces.size)) {
            let namespace = namespaces[i]
            let realPackage = assignments[namespace]
            let moved = realPackage != namespace
            sb.append("      \"${jsonEscape(namespace)}\": {")
            sb.append("\"facade_package\": \"${jsonEscape(namespace)}\", ")
            sb.append("\"real_package\": \"${jsonEscape(realPackage)}\", ")
            sb.append("\"moved\": ${if (moved) { "true" } else { "false" }}")
            sb.append("}")
            if (i + 1 < Int64(namespaces.size)) {
                sb.append(",")
            }
            sb.append("\n")
            i += 1
        }
        sb.append("    }\n")
        sb.append("  },\n")
        sb.append("  \"impl_packages\": [\n")
        let implPackageNames = layoutSortedImplPackageKeys(implPackages)
        i = 0
        while (i < Int64(implPackageNames.size)) {
            let packageName = implPackageNames[i]
            sb.append("    {\"package\": \"${jsonEscape(packageName)}\", \"namespaces\": [")
            let movedNamespaces = implPackages[packageName]
            var j: Int64 = 0
            while (j < Int64(movedNamespaces.size)) {
                if (j > 0) {
                    sb.append(", ")
                }
                sb.append("\"${jsonEscape(movedNamespaces[j])}\"")
                j += 1
            }
            sb.append("], \"reason\": {\"kind\": \"residual_scc\"}}")
            if (i + 1 < Int64(implPackageNames.size)) {
                sb.append(",")
            }
            sb.append("\n")
            i += 1
        }
        sb.append("  ],\n")
        sb.append("  \"cost\": {\n")
        sb.append("    \"package_count\": ${Int64(packageGraphNodes(finalPackageGraph).size)},\n")
        sb.append("    \"import_edge_count\": ${countPackageGraphEdges(finalPackageGraph)},\n")
        sb.append("    \"moved_namespace_count\": ${countMovedNamespaces(namespaces, assignments)},\n")
        sb.append("    \"facade_count\": ${countMovedNamespaces(namespaces, assignments)}\n")
        sb.append("  }\n")
        sb.append("}\n")
        return sb.toString()
    }

    public func packageGraphDot(): String {
        let nodes = packageGraphNodes(finalPackageGraph)
        let sb = StringBuilder()
        sb.append("digraph package_graph {\n")
        for (node in nodes) {
            sb.append("  \"${dotEscape(node)}\";\n")
        }
        for (node in nodes) {
            if (!finalPackageGraph.contains(node)) {
                continue
            }
            for (edge in finalPackageGraph[node]) {
                sb.append("  \"${dotEscape(node)}\" -> \"${dotEscape(edge)}\";\n")
            }
        }
        sb.append("}\n")
        return sb.toString()
    }

    public func sccReportMarkdown(): String {
        let implPackages = collectImplPackages(layoutSortedAssignmentKeys(assignments), assignments)
        let sb = StringBuilder()
        sb.append("# windows-cj bindgen package layout report\n\n")
        sb.append("- feature mode: all-features-on\n")
        sb.append("- namespace graph nodes: ${namespaceGraphNodeCount}\n")
        sb.append("- namespace graph edges: ${namespaceGraphEdgeCount}\n")
        sb.append("- initial multi-node SCCs: ${initialMultiNodeSccCount}\n")
        sb.append("- residual package merges: ${residualMergeCount}\n")
        sb.append("- final package graph multi-node SCCs: ${finalMultiNodeSccCount}\n\n")
        sb.append("## Impl packages\n\n")
        let packages = layoutSortedImplPackageKeys(implPackages)
        if (packages.isEmpty()) {
            sb.append("No namespaces moved to internal `.impl` packages.\n")
            return sb.toString()
        }
        for (packageName in packages) {
            sb.append("### ${packageName}\n\n")
            sb.append("reason: residual_scc\n\n")
            for (namespace in implPackages[packageName]) {
                sb.append("- ${namespace}\n")
            }
            sb.append("\n")
        }
        return sb.toString()
    }
}

public func computePackageLayoutFromGraph(
    namespaces: ArrayList<String>,
    namespaceGraph: HashMap<String, ArrayList<String>>
): PackageLayoutResult {
    let assignments = initialPackageAssignments(namespaces)
    let namespaceComponents = computeNamespaceComponents(namespaces, namespaceGraph)
    let initialMultiNodeSccCount = countMultiNodeComponents(namespaceComponents)
    mergeNamespaceComponents(namespaces, assignments, namespaceComponents)
    return finishPackageLayout(namespaces, namespaceGraph, assignments, initialMultiNodeSccCount)
}

public func computePackageLayoutFromAssignmentsForTest(
    namespaces: ArrayList<String>,
    namespaceGraph: HashMap<String, ArrayList<String>>,
    assignments: HashMap<String, String>
): PackageLayoutResult {
    return finishPackageLayout(namespaces, namespaceGraph, cloneAssignments(namespaces, assignments), 0)
}

public func validatePackageGraphIsDag(graph: HashMap<String, ArrayList<String>>): Unit {
    let nodes = packageGraphNodes(graph)
    let components = computeNamespaceComponents(nodes, graph)
    let multiNodeSccCount = countMultiNodeComponents(components)
    if (multiNodeSccCount > 0) {
        throw Exception("generated package graph contains ${multiNodeSccCount} cycle(s)")
    }
}

func finishPackageLayout(
    namespaces: ArrayList<String>,
    namespaceGraph: HashMap<String, ArrayList<String>>,
    assignments: HashMap<String, String>,
    initialMultiNodeSccCount: Int64
): PackageLayoutResult {
    let residualMergeCount = mergeResidualPackageCycles(namespaces, namespaceGraph, assignments)
    let finalGraph = buildGeneratedPackageDependencyGraph(namespaces, namespaceGraph, assignments)
    let finalComponents = computeNamespaceComponents(packageGraphNodes(finalGraph), finalGraph)
    let finalMultiNodeSccCount = countMultiNodeComponents(finalComponents)
    validatePackageGraphIsDag(finalGraph)
    return PackageLayoutResult(
        assignments,
        Int64(namespaces.size),
        countNamespaceGraphEdges(namespaceGraph),
        initialMultiNodeSccCount,
        residualMergeCount,
        finalGraph,
        finalMultiNodeSccCount
    )
}

func initialPackageAssignments(namespaces: ArrayList<String>): HashMap<String, String> {
    let assignments = HashMap<String, String>()
    for (namespace in namespaces) {
        assignments[namespace] = namespace
    }
    return assignments
}

func cloneAssignments(
    namespaces: ArrayList<String>,
    assignments: HashMap<String, String>
): HashMap<String, String> {
    let result = HashMap<String, String>()
    for (namespace in namespaces) {
        if (assignments.contains(namespace)) {
            result[namespace] = assignments[namespace]
        } else {
            result[namespace] = namespace
        }
    }
    return result
}

func mergeNamespaceComponents(
    namespaces: ArrayList<String>,
    assignments: HashMap<String, String>,
    components: ArrayList<ArrayList<String>>
): Int64 {
    let mergeComponents = ArrayList<ArrayList<String>>()
    for (component in components) {
        if (component.size > 1) {
            mergeComponents.add(component)
        }
    }
    if (mergeComponents.isEmpty()) {
        return 0
    }

    let packageNames = chooseImplPackageNamespaces(namespaces, assignments, mergeComponents)
    var i: Int64 = 0
    while (i < Int64(mergeComponents.size)) {
        let component = mergeComponents[i]
        let packageName = packageNames[i]
        for (namespace in component) {
            assignments[namespace] = packageName
        }
        i += 1
    }
    return Int64(mergeComponents.size)
}

func mergeResidualPackageCycles(
    namespaces: ArrayList<String>,
    namespaceGraph: HashMap<String, ArrayList<String>>,
    assignments: HashMap<String, String>
): Int64 {
    var mergeCount: Int64 = 0
    var changed = true
    while (changed) {
        changed = false
        let packageGraph = buildGeneratedPackageDependencyGraph(namespaces, namespaceGraph, assignments)
        let packageComponents = computeNamespaceComponents(packageGraphNodes(packageGraph), packageGraph)
        let namespaceComponents = ArrayList<ArrayList<String>>()
        for (component in packageComponents) {
            if (component.size <= 1) {
                continue
            }
            let mergedNamespaces = collectNamespacesForGeneratedPackages(namespaces, assignments, component)
            if (!mergedNamespaces.isEmpty()) {
                namespaceComponents.add(mergedNamespaces)
            }
        }
        if (namespaceComponents.isEmpty()) {
            continue
        }

        let packageNames = chooseImplPackageNamespaces(namespaces, assignments, namespaceComponents)
        var i: Int64 = 0
        while (i < Int64(namespaceComponents.size)) {
            let component = namespaceComponents[i]
            let packageName = packageNames[i]
            var componentChanged = false
            for (namespace in component) {
                if (!assignments.contains(namespace) || assignments[namespace] != packageName) {
                    assignments[namespace] = packageName
                    componentChanged = true
                }
            }
            if (componentChanged) {
                changed = true
                mergeCount += 1
            }
            i += 1
        }
    }
    return mergeCount
}

func chooseImplPackageNamespaces(
    namespaces: ArrayList<String>,
    assignments: HashMap<String, String>,
    components: ArrayList<ArrayList<String>>
): ArrayList<String> {
    let result = ArrayList<String>()
    let baseNames = ArrayList<String>()
    for (component in components) {
        baseNames.add("${chooseComponentPackageNamespace(component)}.impl")
    }

    var i: Int64 = 0
    while (i < Int64(components.size)) {
        let component = components[i]
        let baseName = baseNames[i]
        var packageName = baseName
        if (implPackageBaseNeedsSuffix(baseName, i, namespaces, assignments, components, baseNames)) {
            packageName = "${baseName}.s_${stableNamespaceComponentId(component)}"
        }
        var collisionIndex: Int64 = 1
        while (containsString(result, packageName)) {
            packageName = "${baseName}.s_${stableNamespaceComponentId(component)}_${collisionIndex}"
            collisionIndex += 1
        }
        result.add(packageName)
        i += 1
    }
    return result
}

func implPackageBaseNeedsSuffix(
    baseName: String,
    componentIndex: Int64,
    namespaces: ArrayList<String>,
    assignments: HashMap<String, String>,
    components: ArrayList<ArrayList<String>>,
    baseNames: ArrayList<String>
): Bool {
    var sameBaseCount: Int64 = 0
    for (base in baseNames) {
        if (base == baseName) {
            sameBaseCount += 1
        }
    }
    if (sameBaseCount > 1) {
        return true
    }

    if (containsString(namespaces, baseName)) {
        return true
    }

    let component = components[componentIndex]
    for (namespace in namespaces) {
        if (componentContainsNamespace(component, namespace)) {
            continue
        }
        if (assignments.contains(namespace) && assignments[namespace] == baseName) {
            return true
        }
    }
    return false
}

func componentContainsNamespace(component: ArrayList<String>, namespace: String): Bool {
    for (value in component) {
        if (value == namespace) {
            return true
        }
    }
    return false
}

func stableNamespaceComponentId(component: ArrayList<String>): String {
    var hash: Int64 = 5381
    for (namespace in component) {
        for (ch in namespace.toArray()) {
            hash = (hash * 131 + Int64(ch)) % 2147483647
        }
        hash = (hash * 131 + 59) % 2147483647
    }
    if (hash < 0) {
        hash = -hash
    }
    return "${hash}"
}

func countMultiNodeComponents(components: ArrayList<ArrayList<String>>): Int64 {
    var result: Int64 = 0
    for (component in components) {
        if (component.size > 1) {
            result += 1
        }
    }
    return result
}

func countNamespaceGraphEdges(graph: HashMap<String, ArrayList<String>>): Int64 {
    var result: Int64 = 0
    for ((_, edges) in graph) {
        result += Int64(edges.size)
    }
    return result
}

func countPackageGraphEdges(graph: HashMap<String, ArrayList<String>>): Int64 {
    return countNamespaceGraphEdges(graph)
}

func packageGraphNodes(graph: HashMap<String, ArrayList<String>>): ArrayList<String> {
    let result = ArrayList<String>()
    for ((node, edges) in graph) {
        if (!containsString(result, node)) {
            result.add(node)
        }
        for (edge in edges) {
            if (!containsString(result, edge)) {
                result.add(edge)
            }
        }
    }
    sortStrings(result)
    return result
}

func layoutSortedAssignmentKeys(map: HashMap<String, String>): ArrayList<String> {
    let result = ArrayList<String>()
    for ((key, _) in map) {
        result.add(key)
    }
    sortStrings(result)
    return result
}

func layoutSortedImplPackageKeys(map: HashMap<String, ArrayList<String>>): ArrayList<String> {
    let result = ArrayList<String>()
    for ((key, _) in map) {
        result.add(key)
    }
    sortStrings(result)
    return result
}

func collectImplPackages(
    namespaces: ArrayList<String>,
    assignments: HashMap<String, String>
): HashMap<String, ArrayList<String>> {
    let result = HashMap<String, ArrayList<String>>()
    for (namespace in namespaces) {
        if (!assignments.contains(namespace)) {
            continue
        }
        let packageName = assignments[namespace]
        if (packageName == namespace || !isImplementationPackageNamespace(packageName)) {
            continue
        }
        if (!result.contains(packageName)) {
            result[packageName] = ArrayList<String>()
        }
        result[packageName].add(namespace)
    }
    for ((_, values) in result) {
        sortStrings(values)
    }
    return result
}

func countMovedNamespaces(
    namespaces: ArrayList<String>,
    assignments: HashMap<String, String>
): Int64 {
    var result: Int64 = 0
    for (namespace in namespaces) {
        if (assignments.contains(namespace) && assignments[namespace] != namespace) {
            result += 1
        }
    }
    return result
}

func dotEscape(value: String): String {
    return jsonEscape(value)
}
