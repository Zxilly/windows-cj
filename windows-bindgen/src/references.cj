package windows_bindgen

import std.collection.*
import windows_metadata.*

enum ReferenceStyle {
    | Full
    | Flat
    | SkipRoot
}

class ReferenceEntry {
    public let packageName: String
    public let style: ReferenceStyle
    public let selector: String

    public init(packageName: String, style: ReferenceStyle, selector: String) {
        this.packageName = packageName
        this.style = style
        this.selector = selector
    }
}

public class References {
    private let entries: ArrayList<ReferenceEntry>

    public init() {
        this.entries = ArrayList<ReferenceEntry>()
    }

    public init(args: ArrayList<String>) {
        this.entries = ArrayList<ReferenceEntry>()
        for (arg in args) {
            add(arg)
        }
    }

    public func add(arg: String): Unit {
        let normalized = if (arg == "windows") {
            "windows,skip-root,Windows"
        } else {
            arg
        }

        let parts = splitString(normalized, b',')
        if (parts.size != 3) {
            throwInvalidReference()
        }

        if (parts[0].isEmpty() || parts[2].isEmpty()) {
            throwInvalidReference()
        }

        entries.add(ReferenceEntry(parts[0], parseReferenceStyle(parts[1]), parts[2]))
    }

    public func contains(namespace: String): Bool {
        findNamespace(namespace).isSome()
    }

    public func containsType(namespace: String, name: String): Bool {
        findType(namespace, name).isSome()
    }

    public func importPath(namespace: String): Option<String> {
        match (findNamespace(namespace)) {
            case Some(entry) =>
                return Some(buildImportPath(entry, namespace))
            case None =>
                return None
        }
    }

    public func rewriteQualified(namespace: String, name: String): String {
        match (findType(namespace, name)) {
            case Some(entry) => "${buildImportPath(entry, namespace)}.${name}"
            case None => match (importPath(namespace)) {
                case Some(path) => "${path}.${name}"
                case None => "${namespace}.${name}"
            }
        }
    }

    public func rewriteTypeName(typeName: TypeName): String {
        let name = trimTick(typeName.name)
        if (typeName.namespace.isEmpty()) {
            return name
        }
        match (findType(typeName.namespace, name)) {
            case Some(entry) =>
                return "${buildImportPath(entry, typeName.namespace)}.${name}"
            case None =>
                return rewriteQualified(typeName.namespace, name)
        }
    }

    func findNamespace(namespace: String): Option<ReferenceEntry> {
        var best: Option<ReferenceEntry> = None
        var bestLength: Int64 = -1
        for (entry in entries) {
            if (matchesNamespaceSelector(entry.selector, namespace)) {
                let length = selectorSpecificity(entry.selector)
                if (length > bestLength) {
                    best = Some(entry)
                    bestLength = length
                }
            }
        }
        return best
    }

    func findType(namespace: String, name: String): Option<ReferenceEntry> {
        var best: Option<ReferenceEntry> = None
        var bestLength: Int64 = -1
        for (entry in entries) {
            if (matchesTypeSelector(entry.selector, namespace, name)) {
                let length = selectorSpecificity(entry.selector)
                if (length > bestLength) {
                    best = Some(entry)
                    bestLength = length
                }
            }
        }
        return best
    }
}

func parseReferenceStyle(value: String): ReferenceStyle {
    if (value == "flat") {
        return ReferenceStyle.Flat
    }
    if (value == "skip-root") {
        return ReferenceStyle.SkipRoot
    }
    if (value != "full") {
        throwInvalidReference()
    }
    return ReferenceStyle.Full
}

func throwInvalidReference(): Unit {
    throw Exception("`--reference` must be `<crate>,<full/flat/skip-root>,<type name>`")
}

func buildImportPath(entry: ReferenceEntry, namespace: String): String {
    let parts = splitString(namespace, b'.')
    match (entry.style) {
        case ReferenceStyle.Flat =>
            return entry.packageName
        case ReferenceStyle.SkipRoot =>
            if (parts.size <= 1) {
                return entry.packageName
            }
            let trimmed = sliceStringParts(parts, 1)
            if (trimmed.isEmpty()) {
                return entry.packageName
            }
            return "${entry.packageName}.${joinPackageParts(trimmed)}"
        case ReferenceStyle.Full =>
            return "${entry.packageName}.${joinPackageParts(parts)}"
    }
}

func matchesNamespaceSelector(selector: String, namespace: String): Bool {
    if (selector.endsWith(".*")) {
        let prefix = trimReferenceSuffix(selector, 2)
        return namespace == prefix || namespaceStartsWith(namespace, prefix)
    }

    return namespace == selector || namespaceStartsWith(namespace, selector)
}

func matchesTypeSelector(selector: String, namespace: String, name: String): Bool {
    let qualified = qualifiedReferenceType(namespace, name)
    if (selector.endsWith(".*")) {
        let prefix = trimReferenceSuffix(selector, 2)
        return namespace == prefix || namespaceStartsWith(namespace, prefix) || startsWith(qualified, "${prefix}.")
    }

    if (selector.endsWith("*")) {
        let prefix = trimReferenceSuffix(selector, 1)
        return startsWith(qualified, prefix)
    }

    if (qualified == selector) {
        return true
    }

    return matchesNamespaceSelector(selector, namespace)
}

func selectorSpecificity(selector: String): Int64 {
    let arr = selector.toArray()
    var count: Int64 = 0
    for (ch in arr) {
        if (ch != b'*') {
            count += 1
        }
    }
    count
}

func trimReferenceSuffix(value: String, count: Int64): String {
    let arr = value.toArray()
    if (count <= 0 || count >= Int64(arr.size)) {
        return value
    }
    return String.fromUtf8(arr[0..Int64(arr.size) - count])
}

func qualifiedReferenceType(namespace: String, name: String): String {
    if (namespace.isEmpty()) {
        return name
    }
    return "${namespace}.${name}"
}

func sliceStringParts(parts: ArrayList<String>, start: Int64): ArrayList<String> {
    let result = ArrayList<String>()
    var i = start
    while (i < Int64(parts.size)) {
        result.add(parts[i])
        i += 1
    }
    return result
}

func joinPackageParts(parts: ArrayList<String>): String {
    let normalized = ArrayList<String>()
    for (part in parts) {
        normalized.add(toLowerSnake(part))
    }
    return joinStrings(normalized, ".")
}
