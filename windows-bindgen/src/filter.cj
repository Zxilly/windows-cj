package windows_bindgen

import std.collection.*
import windows_metadata.*

enum FilterRuleKind {
    | Namespace
    | ExactType
    | TypePrefix
    | ShortName
}

class FilterRule {
    public let raw: String
    public let include: Bool
    public let kind: FilterRuleKind
    public let namespace: String
    public let name: String

    public init(raw: String, include: Bool, kind: FilterRuleKind, namespace: String, name: String) {
        this.raw = raw
        this.include = include
        this.kind = kind
        this.namespace = namespace
        this.name = name
    }
}

public class BindgenFilter {
    let rules: ArrayList<FilterRule>
    let hasIncludes: Bool

    public init(index: TypeIndex, config: BindgenConfig) {
        this.rules = ArrayList<FilterRule>()

        var includes = false
        for (raw in config.filterNamespaces) {
            for (rule in parseFilterRules(index, raw, true)) {
                rules.add(rule)
            }
            includes = true
        }
        for (raw in config.excludeNamespaces) {
            for (rule in parseFilterRules(index, raw, false)) {
                rules.add(rule)
            }
        }

        sortFilterRules(rules)
        this.hasIncludes = includes
    }

    public func includesNamespace(namespace: String): Bool {
        if (rules.isEmpty()) {
            return true
        }

        for (rule in rules) {
            if (matchesNamespace(rule, namespace)) {
                return rule.include
            }
        }

        return !hasIncludes
    }

    public func includesType(namespace: String, name: String): Bool {
        if (rules.isEmpty()) {
            return true
        }

        for (rule in rules) {
            if (matchesType(rule, namespace, name)) {
                return rule.include
            }
        }

        return includesNamespace(namespace)
    }

    public func excludesType(namespace: String, name: String): Bool {
        if (rules.isEmpty()) {
            return false
        }

        for (rule in rules) {
            if (matchesType(rule, namespace, name)) {
                return !rule.include
            }
        }

        return false
    }
}

func parseFilterRules(index: TypeIndex, raw: String, include: Bool): ArrayList<FilterRule> {
    match (splitNamespaceAndLeaf(raw)) {
        case Some((namespace, leaf)) =>
            if (leaf.endsWith("*")) {
                return singleFilterRule(FilterRule(raw, include, FilterRuleKind.TypePrefix, namespace, trimSuffix(leaf, 1)))
            }

            let trimmedLeaf = trimTick(leaf)
            if (index.contains(namespace, trimmedLeaf)) {
                return singleFilterRule(FilterRule(raw, include, FilterRuleKind.ExactType, namespace, trimmedLeaf))
            }

            return singleFilterRule(FilterRule(raw, include, FilterRuleKind.Namespace, raw, ""))
        case None =>
            if (index.containsNamespace(raw)) {
                return singleFilterRule(FilterRule(raw, include, FilterRuleKind.Namespace, raw, ""))
            }

            let expanded = ArrayList<FilterRule>()
            let namespaceSeen = HashMap<String, Bool>()
            let typeSeen = HashMap<String, Bool>()
            let trimmedRaw = trimTick(raw)

            for ((typeName, entry) in index.iterTypeEntries()) {
                let trimmedName = trimTick(typeName.name)
                if (trimmedName == trimmedRaw) {
                    let typeKey = "${typeName.namespace}.${trimmedName}"
                    if (!typeSeen.contains(typeKey)) {
                        typeSeen[typeKey] = true
                        expanded.add(FilterRule(typeKey, include, FilterRuleKind.ExactType, typeName.namespace, trimmedName))
                    }
                }

                let (methodStart, methodEnd) = index.typeDefMethods(entry.fileIdx, entry.row)
                var methodRow = methodStart
                while (methodRow < methodEnd) {
                    let methodFlags = index.methodDefFlags(entry.fileIdx, methodRow)
                    if (methodFlags.contains(MethodAttributes.Public) &&
                        methodFlags.contains(MethodAttributes.Static) &&
                        index.methodDefName(entry.fileIdx, methodRow) == raw) {
                        if (!namespaceSeen.contains(typeName.namespace)) {
                            namespaceSeen[typeName.namespace] = true
                            expanded.add(FilterRule(typeName.namespace, include, FilterRuleKind.Namespace, typeName.namespace, ""))
                        }
                        break
                    }
                    methodRow += 1
                }
            }

            if (!expanded.isEmpty()) {
                return expanded
            }

            return singleFilterRule(FilterRule(raw, include, FilterRuleKind.ShortName, "", trimmedRaw))
    }
}

func singleFilterRule(rule: FilterRule): ArrayList<FilterRule> {
    let result = ArrayList<FilterRule>()
    result.add(rule)
    return result
}

func matchesNamespace(rule: FilterRule, namespace: String): Bool {
    match (rule.kind) {
        case FilterRuleKind.Namespace =>
            return namespace == rule.namespace || namespaceStartsWith(namespace, rule.namespace)
        case FilterRuleKind.ExactType =>
            return namespace == rule.namespace
        case FilterRuleKind.TypePrefix =>
            return namespace == rule.namespace
        case FilterRuleKind.ShortName =>
            return false
    }
}

func matchesType(rule: FilterRule, namespace: String, name: String): Bool {
    match (rule.kind) {
        case FilterRuleKind.Namespace =>
            return namespace == rule.namespace || namespaceStartsWith(namespace, rule.namespace)
        case FilterRuleKind.ExactType =>
            return namespace == rule.namespace && name == rule.name
        case FilterRuleKind.TypePrefix =>
            return namespace == rule.namespace && startsWith(name, rule.name)
        case FilterRuleKind.ShortName =>
            return name == rule.name
    }
}

func splitNamespaceAndLeaf(value: String): Option<(String, String)> {
    let arr = value.toArray()
    var lastDot: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'.') {
            lastDot = i
        }
        i += 1
    }

    if (lastDot <= 0 || lastDot >= Int64(arr.size) - 1) {
        return None
    }

    return Some((
        String.fromUtf8(arr[0..lastDot]),
        String.fromUtf8(arr[lastDot + 1..Int64(arr.size)])
    ))
}

func trimSuffix(value: String, count: Int64): String {
    let arr = value.toArray()
    return String.fromUtf8(arr[0..Int64(arr.size) - count])
}

func sortFilterRules(values: ArrayList<FilterRule>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && filterRuleLess(key, values[j])) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}

func filterRuleLess(lhs: FilterRule, rhs: FilterRule): Bool {
    let lhsLen = Int64(lhs.raw.toArray().size)
    let rhsLen = Int64(rhs.raw.toArray().size)
    if (lhsLen != rhsLen) {
        return lhsLen > rhsLen
    }
    if (lhs.include != rhs.include) {
        return !lhs.include && rhs.include
    }
    return lhs.raw < rhs.raw
}
