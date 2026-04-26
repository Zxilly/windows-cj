package windows_bindgen

import std.collection.*
import windows_metadata.*

public class LayerAssignment {
    private let packageByType: HashMap<TypeName, String>
    private let bucketStemByType: HashMap<TypeName, String>
    private let sccBuckets: HashMap<String, ArrayList<String>>
    private let layeredNamespaces: HashSet<String>

    public init() {
        this.packageByType = HashMap<TypeName, String>()
        this.bucketStemByType = HashMap<TypeName, String>()
        this.sccBuckets = HashMap<String, ArrayList<String>>()
        this.layeredNamespaces = HashSet<String>()
    }

    public func add(namespace: String, name: String, packageName: String, bucketStem: String): Unit {
        let key = TypeName.named(namespace, trimTick(name)).definition()
        packageByType[key] = packageName
        bucketStemByType[key] = bucketStem
        layeredNamespaces.add(namespace)
    }

    public func addBucket(prefix: String, bucket: String): Unit {
        let stem = layerAssignmentBucketStem(bucket)
        if (!sccBuckets.contains(prefix)) {
            sccBuckets[prefix] = ArrayList<String>()
        }
        if (!layerAssignmentContainsString(sccBuckets[prefix], stem)) {
            sccBuckets[prefix].add(stem)
            sortStrings(sccBuckets[prefix])
        }
    }

    public func packageFor(namespace: String, name: String): Option<String> {
        let key = TypeName.named(namespace, trimTick(name)).definition()
        if (packageByType.contains(key)) {
            return Some(packageByType[key])
        }
        return None
    }

    public func bucketStemFor(namespace: String, name: String): Option<String> {
        let key = TypeName.named(namespace, trimTick(name)).definition()
        if (bucketStemByType.contains(key)) {
            return Some(bucketStemByType[key])
        }
        return None
    }

    public func bucketsForScc(prefix: String): ArrayList<String> {
        let result = ArrayList<String>()
        if (!sccBuckets.contains(prefix)) {
            return result
        }
        for (bucket in sccBuckets[prefix]) {
            result.add(bucket)
        }
        return result
    }

    public func namespaceHasLayeredTypes(namespace: String): Bool {
        return layeredNamespaces.contains(namespace)
    }
}

func layerAssignmentContainsString(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func layerAssignmentBucketStem(bucket: String): String {
    match (bucket.indexOf("._impl_l", 0)) {
        case Some(pos) =>
            let arr = bucket.toArray()
            return String.fromUtf8(arr[pos + 1..Int64(arr.size)])
        case None => return bucket
    }
}
