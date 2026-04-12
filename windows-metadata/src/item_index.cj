package windows_metadata

import std.collection.*

public enum Item {
    | Type(TypeDefRef)
    | Fn(MethodDefRef)
    | Const(FieldRef)
}

public interface ItemLookup<T> {
    func items(): ArrayList<T>
    func namespace_items(namespace: String): ArrayList<(String, T)>
    func get(namespace: String, name: String): ArrayList<T>

    func expect(namespace: String, name: String): T {
        let found = get(namespace, name)
        if (found.isEmpty()) {
            throw Exception("item not found: ${namespace}.${name}")
        }
        if (Int64(found.size) > 1) {
            throw Exception("more than one item found: ${namespace}.${name}")
        }
        return found[0]
    }
}

public class ItemIndex <: ItemLookup<Item> {
    public let index: TypeIndex
    public let members: HashMap<String, HashMap<String, ArrayList<Item>>>

    public init(index: TypeIndex) {
        this.index = index
        this.members = HashMap<String, HashMap<String, ArrayList<Item>>>()
        buildIndex()
    }

    func buildIndex(): Unit {
        for ((namespace, name, fileIdx, row) in index.iter()) {
            let ty = TypeDefRef(index, fileIdx, row)
            let isApis = !ty.flags().contains(TypeAttributes.WindowsRuntime) &&
                isClassCategory(ty.category()) &&
                name == "Apis"

            if (isApis) {
                for (method in ty.methods()) {
                    insertItem(namespace, method.name(), Item.Fn(method))
                }
                for (field in ty.fields()) {
                    insertItem(namespace, field.name(), Item.Const(field))
                }
            } else {
                insertItem(namespace, name, Item.Type(ty))
            }
        }
    }

    func insertItem(namespace: String, name: String, item: Item): Unit {
        if (!members.contains(namespace)) {
            members[namespace] = HashMap<String, ArrayList<Item>>()
        }

        let namespaceItems = members[namespace]
        if (!namespaceItems.contains(name)) {
            namespaceItems[name] = ArrayList<Item>()
        }
        namespaceItems[name].add(item)
    }

    public func get(namespace: String, name: String): ArrayList<Item> {
        let result = ArrayList<Item>()
        if (members.contains(namespace)) {
            let namespaceItems = members[namespace]
            if (namespaceItems.contains(name)) {
                for (item in namespaceItems[name]) {
                    result.add(item)
                }
            }
        }
        return result
    }

    public func iter(): ArrayList<(String, String, Item)> {
        let result = ArrayList<(String, String, Item)>()
        for ((namespace, namespaceItems) in members) {
            for ((name, found) in namespaceItems) {
                for (item in found) {
                    result.add((namespace, name, item))
                }
            }
        }
        return result
    }

    public func items(): ArrayList<Item> {
        let result = ArrayList<Item>()
        for ((_, namespaceItems) in members) {
            for ((_, found) in namespaceItems) {
                for (item in found) {
                    result.add(item)
                }
            }
        }
        return result
    }

    public func namespace_items(namespace: String): ArrayList<(String, Item)> {
        let result = ArrayList<(String, Item)>()
        if (!members.contains(namespace)) {
            return result
        }

        let namespaceItems = members[namespace]
        for ((name, found) in namespaceItems) {
            for (item in found) {
                result.add((name, item))
            }
        }
        return result
    }
}

func isClassCategory(category: TypeCategory): Bool {
    match (category) {
        case TypeCategory.Class => return true
        case _ => return false
    }
}
