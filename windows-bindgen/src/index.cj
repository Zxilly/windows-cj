package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

class FeatureIndexItem {
    public let name: String
    public let features: ArrayList<Int64>

    public init(name: String, features: ArrayList<Int64>) {
        this.name = name
        this.features = features
    }
}

class FeatureIndex {
    private let namespaces_: ArrayList<String>
    private let items_: HashMap<Int64, ArrayList<FeatureIndexItem>>

    public init() {
        this.namespaces_ = ArrayList<String>()
        this.items_ = HashMap<Int64, ArrayList<FeatureIndexItem>>()
    }

    public func addNamespace(namespace: String): Int64 {
        var i: Int64 = 0
        while (i < Int64(namespaces_.size)) {
            if (namespaces_[i] == namespace) {
                return i
            }
            i += 1
        }
        namespaces_.add(namespace)
        return Int64(namespaces_.size) - 1
    }

    public func addItem(namespace: String, name: String, features: ArrayList<String>): Unit {
        let namespaceIndex = addNamespace(namespace)
        let featureIndexes = ArrayList<Int64>()
        for (feature in features) {
            if (feature.isEmpty()) {
                continue
            }
            let featureIndex = addNamespace(feature)
            if (!containsInt64(featureIndexes, featureIndex)) {
                featureIndexes.add(featureIndex)
            }
        }
        sortInt64s(featureIndexes)

        if (!items_.contains(namespaceIndex)) {
            items_[namespaceIndex] = ArrayList<FeatureIndexItem>()
        }

        let items = items_[namespaceIndex]
        for (item in items) {
            if (item.name == name) {
                for (featureIndex in featureIndexes) {
                    if (!containsInt64(item.features, featureIndex)) {
                        item.features.add(featureIndex)
                    }
                }
                sortInt64s(item.features)
                return
            }
        }

        items.add(FeatureIndexItem(name, featureIndexes))
    }

    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{\"version\":2,\"namespaces\":[")
        var nsIndex: Int64 = 0
        while (nsIndex < Int64(namespaces_.size)) {
            if (nsIndex > 0) {
                sb.append(",")
            }
            sb.append("\"${jsonEscape(namespaces_[nsIndex])}\"")
            nsIndex += 1
        }
        sb.append("],\"items\":{")

        let itemKeys = ArrayList<Int64>()
        for ((key, _) in items_) {
            itemKeys.add(key)
        }
        sortInt64s(itemKeys)

        var firstNamespace = true
        for (key in itemKeys) {
            if (!firstNamespace) {
                sb.append(",")
            }
            sb.append("\"${key}\":[")
            let items = items_[key]
            sortFeatureIndexItems(items)
            var itemIndex: Int64 = 0
            while (itemIndex < Int64(items.size)) {
                if (itemIndex > 0) {
                    sb.append(",")
                }
                let item = items[itemIndex]
                sb.append("{\"n\":\"${jsonEscape(item.name)}\",\"f\":[")
                var featureIndex: Int64 = 0
                while (featureIndex < Int64(item.features.size)) {
                    if (featureIndex > 0) {
                        sb.append(",")
                    }
                    sb.append("${item.features[featureIndex]}")
                    featureIndex += 1
                }
                sb.append("]}")
                itemIndex += 1
            }
            sb.append("]")
            firstNamespace = false
        }

        sb.append("}}")
        return sb.toString()
    }
}

public func generateFeatureIndex(index: TypeIndex, typeMap: TypeMap): String {
    let featureIndex = FeatureIndex()
    let namespaces = typeMap.namespaces()
    for (namespace in namespaces) {
        let types = typeMap.typesInNamespace(namespace)
        for (entry in types) {
            let features = ArrayList<String>()
            features.add(namespace)
            let typeDependencies = collectTypeDependencies(index, entry.fileIdx, entry.row)
            for (dependency in typeDependencies) {
                if (!dependency.namespace.isEmpty()) {
                    features.add(dependency.namespace)
                }
            }
            featureIndex.addItem(namespace, entry.name, features)

            let (mStart, mEnd) = index.typeDefMethods(entry.fileIdx, entry.row)
            var methodRow = mStart
            while (methodRow < mEnd) {
                let methodFeatures = ArrayList<String>()
                methodFeatures.add(namespace)
                let signature = index.methodDefSignature(entry.fileIdx, methodRow, winmdBuildGenericArray(index, entry.fileIdx, winmdRowGenericStart(index, entry.fileIdx, entry.row), winmdRowGenericEnd(index, entry.fileIdx, entry.row)))
                let dependencies = ArrayList<TypeName>()
                let seen = HashMap<TypeName, Bool>()
                collectMetadataTypeDependencies(signature.returnType, dependencies, seen)
                for (paramType in signature.paramTypes) {
                    collectMetadataTypeDependencies(paramType, dependencies, seen)
                }
                for (dependency in dependencies) {
                    if (!dependency.namespace.isEmpty()) {
                        methodFeatures.add(dependency.namespace)
                    }
                }
                featureIndex.addItem(namespace, "${entry.name}.${index.methodDefName(entry.fileIdx, methodRow)}", methodFeatures)
                methodRow += 1
            }
        }
    }
    return featureIndex.toJson()
}

func containsInt64(values: ArrayList<Int64>, target: Int64): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func sortInt64s(values: ArrayList<Int64>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && values[j] > key) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}

func sortFeatureIndexItems(values: ArrayList<FeatureIndexItem>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && values[j].name > key.name) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}
