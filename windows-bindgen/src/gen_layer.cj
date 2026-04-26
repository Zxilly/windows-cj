package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.types.*

class TarjanNodeState {
    public var index: Int64 = -1
    public var lowLink: Int64 = -1
    public var onStack: Bool = false

    public init() {}
}

class TarjanFrame {
    public let node: String
    public let edges: ArrayList<String>
    public var nextEdge: Int64 = 0

    public init(node: String, edges: ArrayList<String>) {
        this.node = node
        this.edges = edges
    }
}

class LayerBucket {
    public let packageName: String
    public let stem: String
    public let types: ArrayList<String>

    public init(packageName: String, stem: String, types: ArrayList<String>) {
        this.packageName = packageName
        this.stem = stem
        this.types = types
    }
}

class LayerTypeGraph {
    public let nodes: ArrayList<String>
    public let graph: HashMap<String, ArrayList<String>>

    public init(nodes: ArrayList<String>, graph: HashMap<String, ArrayList<String>>) {
        this.nodes = nodes
        this.graph = graph
    }
}

public func tarjanSccForTest(
    nodes: ArrayList<String>,
    graph: HashMap<String, ArrayList<String>>
): ArrayList<ArrayList<String>> {
    return tarjanScc(nodes, graph)
}

public func computeLayersForTest(
    nodes: ArrayList<String>,
    graph: HashMap<String, ArrayList<String>>
): ArrayList<ArrayList<String>> {
    return computeLayers(nodes, graph)
}

public func computeBucketsForTest(
    prefix: String,
    layers: ArrayList<ArrayList<String>>,
    targetBucketSize: Int64
): ArrayList<String> {
    let result = ArrayList<String>()
    for (bucket in computeBuckets(prefix, layers, targetBucketSize)) {
        let value = if (bucket.types.size > 20) {
            "${bucket.types.size}"
        } else {
            joinStrings(bucket.types, "+")
        }
        result.add("${bucket.packageName}:${value}")
    }
    return result
}

public func computeLayerAssignment(
    index: TypeIndex,
    typeMap: TypeMap,
    namespaceComponents: ArrayList<ArrayList<String>>,
    outputRootPackageName: String,
    targetBucketSize: Int64
): LayerAssignment {
    let assignment = LayerAssignment()
    for (component in namespaceComponents) {
        if (component.size <= 1) {
            continue
        }
        assignLayersForNsScc(index, typeMap, component, outputRootPackageName, targetBucketSize, assignment)
    }
    return assignment
}

func assignLayersForNsScc(
    index: TypeIndex,
    typeMap: TypeMap,
    component: ArrayList<String>,
    outputRootPackageName: String,
    targetBucketSize: Int64,
    assignment: LayerAssignment
): Unit {
    let prefix = FileWriter.namespaceToHierarchicalPackageName(
        chooseComponentPackageNamespace(component),
        outputRootPackageName
    )
    let graphData = buildTypeGraphForNsScc(index, typeMap, component)
    let layers = computeLayers(graphData.nodes, graphData.graph)

    for (bucket in computeBuckets(prefix, layers, targetBucketSize)) {
        assignment.addBucket(prefix, bucket.stem)
        for (node in bucket.types) {
            let (namespace, name) = splitLayerNodeKey(node)
            assignment.add(namespace, name, bucket.packageName, bucket.stem)
        }
    }
}

func buildTypeGraphForNsScc(
    index: TypeIndex,
    typeMap: TypeMap,
    component: ArrayList<String>
): LayerTypeGraph {
    let componentSet = HashSet<String>()
    for (namespace in component) {
        componentSet.add(namespace)
    }

    let nodes = ArrayList<String>()
    let nodeSet = HashSet<String>()
    let graph = HashMap<String, ArrayList<String>>()

    for (namespace in component) {
        for (entry in typeMap.typesInNamespace(namespace)) {
            let key = layerNodeKey(entry.typeName)
            if (!nodeSet.contains(key)) {
                nodeSet.add(key)
                nodes.add(key)
                graph[key] = ArrayList<String>()
            }
        }
    }
    sortStrings(nodes)

    for (namespace in component) {
        for (entry in typeMap.typesInNamespace(namespace)) {
            let source = layerNodeKey(entry.typeName)
            if (!graph.contains(source)) {
                graph[source] = ArrayList<String>()
            }

            let dependencies = collectTypeDependencies(index, entry.fileIdx, entry.row)
            for (dependency in dependencies) {
                let dependencyName = dependency.definition()
                if (!componentSet.contains(dependencyName.namespace)) {
                    continue
                }
                if (!typeMap.containsType(dependencyName)) {
                    continue
                }

                let target = layerNodeKey(dependencyName)
                if (target == source || !nodeSet.contains(target)) {
                    continue
                }
                if (!layerContainsString(graph[source], target)) {
                    graph[source].add(target)
                }
            }
            sortStrings(graph[source])
        }
    }

    return LayerTypeGraph(nodes, graph)
}

func tarjanScc(
    rawNodes: ArrayList<String>,
    graph: HashMap<String, ArrayList<String>>
): ArrayList<ArrayList<String>> {
    let nodes = cloneStringList(rawNodes)
    sortStrings(nodes)

    let nodeSet = HashSet<String>()
    for (node in nodes) {
        nodeSet.add(node)
    }

    let states = HashMap<String, TarjanNodeState>()
    for (node in nodes) {
        states[node] = TarjanNodeState()
    }

    let result = ArrayList<ArrayList<String>>()
    let stack = ArrayList<String>()
    var stackTop: Int64 = 0
    let frames = ArrayList<TarjanFrame>()
    var frameTop: Int64 = 0
    var nextIndex: Int64 = 0

    for (node in nodes) {
        if (states[node].index >= 0) {
            continue
        }

        pushTarjanFrame(node, graph, nodeSet, states, stack, stackTop, frames, frameTop, nextIndex)
        stackTop += 1
        frameTop += 1
        nextIndex += 1

        while (frameTop > 0) {
            let frame = frames[frameTop - 1]
            if (frame.nextEdge < Int64(frame.edges.size)) {
                let edge = frame.edges[frame.nextEdge]
                frame.nextEdge += 1
                let edgeState = states[edge]
                if (edgeState.index < 0) {
                    pushTarjanFrame(edge, graph, nodeSet, states, stack, stackTop, frames, frameTop, nextIndex)
                    stackTop += 1
                    frameTop += 1
                    nextIndex += 1
                } else if (edgeState.onStack) {
                    let nodeState = states[frame.node]
                    if (edgeState.index < nodeState.lowLink) {
                        nodeState.lowLink = edgeState.index
                    }
                }
                continue
            }

            let completedNode = frame.node
            let completedState = states[completedNode]
            if (completedState.lowLink == completedState.index) {
                let component = ArrayList<String>()
                var done = false
                while (!done && stackTop > 0) {
                    stackTop -= 1
                    let stackedNode = stack[stackTop]
                    states[stackedNode].onStack = false
                    component.add(stackedNode)
                    if (stackedNode == completedNode) {
                        done = true
                    }
                }
                sortStrings(component)
                result.add(component)
            }

            frameTop -= 1
            if (frameTop > 0) {
                let parentNode = frames[frameTop - 1].node
                let parentState = states[parentNode]
                if (completedState.lowLink < parentState.lowLink) {
                    parentState.lowLink = completedState.lowLink
                }
            }
        }
    }

    sortComponents(result)
    return result
}

func pushTarjanFrame(
    node: String,
    graph: HashMap<String, ArrayList<String>>,
    nodeSet: HashSet<String>,
    states: HashMap<String, TarjanNodeState>,
    stack: ArrayList<String>,
    stackTop: Int64,
    frames: ArrayList<TarjanFrame>,
    frameTop: Int64,
    nextIndex: Int64
): Unit {
    let state = states[node]
    state.index = nextIndex
    state.lowLink = nextIndex
    state.onStack = true

    if (stackTop < Int64(stack.size)) {
        stack[stackTop] = node
    } else {
        stack.add(node)
    }

    let frame = TarjanFrame(node, sortedKnownEdges(node, graph, nodeSet))
    if (frameTop < Int64(frames.size)) {
        frames[frameTop] = frame
    } else {
        frames.add(frame)
    }
}

func computeLayers(
    nodes: ArrayList<String>,
    graph: HashMap<String, ArrayList<String>>
): ArrayList<ArrayList<String>> {
    let components = tarjanScc(nodes, graph)
    let componentByNode = HashMap<String, Int64>()
    var componentIndex: Int64 = 0
    while (componentIndex < Int64(components.size)) {
        for (node in components[componentIndex]) {
            componentByNode[node] = componentIndex
        }
        componentIndex += 1
    }

    let componentLayers = HashMap<Int64, Int64>()
    componentIndex = 0
    while (componentIndex < Int64(components.size)) {
        componentLayers[componentIndex] = 0
        componentIndex += 1
    }

    var changed = true
    while (changed) {
        changed = false
        componentIndex = 0
        while (componentIndex < Int64(components.size)) {
            var requiredLayer: Int64 = 0
            for (node in components[componentIndex]) {
                if (!graph.contains(node)) {
                    continue
                }
                for (edge in graph[node]) {
                    if (!componentByNode.contains(edge)) {
                        continue
                    }
                    let edgeComponent = componentByNode[edge]
                    if (edgeComponent == componentIndex) {
                        continue
                    }
                    let candidate = componentLayers[edgeComponent] + 1
                    if (candidate > requiredLayer) {
                        requiredLayer = candidate
                    }
                }
            }

            if (requiredLayer > componentLayers[componentIndex]) {
                componentLayers[componentIndex] = requiredLayer
                changed = true
            }
            componentIndex += 1
        }
    }

    var maxLayer: Int64 = -1
    for ((_, layer) in componentLayers) {
        if (layer > maxLayer) {
            maxLayer = layer
        }
    }

    let result = ArrayList<ArrayList<String>>()
    var layerIndex: Int64 = 0
    while (layerIndex <= maxLayer) {
        let layerNodes = ArrayList<String>()
        componentIndex = 0
        while (componentIndex < Int64(components.size)) {
            if (componentLayers[componentIndex] == layerIndex) {
                for (node in components[componentIndex]) {
                    layerNodes.add(node)
                }
            }
            componentIndex += 1
        }
        sortStrings(layerNodes)
        result.add(layerNodes)
        layerIndex += 1
    }

    return result
}

func computeBuckets(
    prefix: String,
    layers: ArrayList<ArrayList<String>>,
    targetBucketSize: Int64
): ArrayList<LayerBucket> {
    let result = ArrayList<LayerBucket>()
    if (layers.isEmpty()) {
        return result
    }

    var bucketSize = targetBucketSize
    if (bucketSize <= 0) {
        bucketSize = countLayerTypes(layers)
    }
    if (bucketSize <= 0) {
        bucketSize = 1
    }

    var current = ArrayList<String>()
    var currentCount: Int64 = 0
    var bucketIndex: Int64 = 0

    for (layer in layers) {
        let layerNodes = cloneStringList(layer)
        sortStrings(layerNodes)
        let layerCount = Int64(layerNodes.size)
        if (layerCount == 0) {
            continue
        }

        if (currentCount > 0 && currentCount + layerCount > bucketSize) {
            let stem = "_impl_l${bucketIndex}"
            result.add(LayerBucket("${prefix}.${stem}", stem, current))
            bucketIndex += 1
            current = ArrayList<String>()
            currentCount = 0
        }

        for (node in layerNodes) {
            current.add(node)
        }
        currentCount += layerCount
    }

    if (currentCount > 0) {
        let stem = "_impl_l${bucketIndex}"
        result.add(LayerBucket("${prefix}.${stem}", stem, current))
        bucketIndex += 1
    }
    return result
}

func countLayerTypes(layers: ArrayList<ArrayList<String>>): Int64 {
    var result: Int64 = 0
    for (layer in layers) {
        result += Int64(layer.size)
    }
    return result
}

func sortedKnownEdges(
    node: String,
    graph: HashMap<String, ArrayList<String>>,
    nodeSet: HashSet<String>
): ArrayList<String> {
    let result = ArrayList<String>()
    if (graph.contains(node)) {
        for (edge in graph[node]) {
            if (nodeSet.contains(edge) && !layerContainsString(result, edge)) {
                result.add(edge)
            }
        }
    }
    sortStrings(result)
    return result
}

func cloneStringList(values: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (value in values) {
        result.add(value)
    }
    return result
}

func sortComponents(values: ArrayList<ArrayList<String>>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && componentSortKey(values[j]) > componentSortKey(key)) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}

func componentSortKey(component: ArrayList<String>): String {
    if (component.isEmpty()) {
        return ""
    }
    return component[0]
}

func layerContainsString(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func layerNodeKey(typeName: TypeName): String {
    let definition = typeName.definition()
    return "${definition.namespace}:${trimTick(definition.name)}"
}

func splitLayerNodeKey(key: String): (String, String) {
    match (key.indexOf(":", 0)) {
        case Some(pos) =>
            let arr = key.toArray()
            return (
                String.fromUtf8(arr[0..pos]),
                String.fromUtf8(arr[pos + 1..Int64(arr.size)])
            )
        case None => return ("", key)
    }
}
