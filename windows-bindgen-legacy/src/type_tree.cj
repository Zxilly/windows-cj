package windows_bindgen

import std.collection.*

class TypeTreeNode {
    public let namespace: String
    public let childNames: ArrayList<String>
    public let children: HashMap<String, TypeTreeNode>

    public init(namespace: String) {
        this.namespace = namespace
        this.childNames = ArrayList<String>()
        this.children = HashMap<String, TypeTreeNode>()
    }
}

public class TypeTree {
    let root: TypeTreeNode

    public init(typeMap: TypeMap) {
        this.root = TypeTreeNode("")
        for (namespace in typeMap.namespaces()) {
            insertNamespace(namespace)
        }
    }

    public func flattenNamespaces(): ArrayList<String> {
        let result = ArrayList<String>()
        appendNamespaces(root, result)
        return result
    }

    func insertNamespace(namespace: String): Unit {
        if (namespace.isEmpty()) {
            return
        }

        var current = root
        var currentNamespace = ""
        for (segment in splitString(namespace, b'.')) {
            currentNamespace = if (currentNamespace.isEmpty()) {
                segment
            } else {
                "${currentNamespace}.${segment}"
            }

            if (!current.children.contains(segment)) {
                current.children[segment] = TypeTreeNode(currentNamespace)
                current.childNames.add(segment)
                sortStrings(current.childNames)
            }
            current = current.children[segment]
        }
    }

    func appendNamespaces(node: TypeTreeNode, result: ArrayList<String>): Unit {
        if (!node.namespace.isEmpty()) {
            result.add(node.namespace)
        }

        for (childName in node.childNames) {
            appendNamespaces(node.children[childName], result)
        }
    }
}
