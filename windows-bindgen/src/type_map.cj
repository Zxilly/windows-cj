package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.types.*
import windows_bindgen.winmd.*

public class TypeMap {
    private let config: BindgenConfig
    private let references: References
    private let dependencyGraph: HashMap<BindgenTypeKey, ArrayList<TypeName>>
    private let namespaceTypes: HashMap<String, ArrayList<BindgenTypeEntry>>
    private let includedTypes: HashMap<TypeName, ArrayList<BindgenTypeEntry>>
    private let itemCfg: HashMap<TableRowKey, ArrayList<String>>

    public init(index: TypeIndex, filter: BindgenFilter, config: BindgenConfig, references: References) {
        this.config = config
        this.references = references
        this.dependencyGraph = HashMap<BindgenTypeKey, ArrayList<TypeName>>()
        this.namespaceTypes = HashMap<String, ArrayList<BindgenTypeEntry>>()
        this.includedTypes = HashMap<TypeName, ArrayList<BindgenTypeEntry>>()
        this.itemCfg = HashMap<TableRowKey, ArrayList<String>>()
        build(index, filter)
    }

    public func namespaces(): ArrayList<String> {
        let result = ArrayList<String>()
        for ((namespace, _) in namespaceTypes) {
            result.add(namespace)
        }
        sortStrings(result)
        return result
    }

    public func typesInNamespace(namespace: String): ArrayList<BindgenTypeEntry> {
        if (namespaceTypes.contains(namespace)) {
            return namespaceTypes[namespace]
        }
        return ArrayList<BindgenTypeEntry>()
    }

    public func containsType(namespace: String, name: String): Bool {
        return containsType(TypeName.named(namespace, trimTick(name)))
    }

    public func containsType(typeName: TypeName): Bool {
        return includedTypes.contains(typeName.definition())
    }

    public func entriesForType(namespace: String, name: String): ArrayList<BindgenTypeEntry> {
        let key = TypeName.named(namespace, trimTick(name)).definition()
        if (includedTypes.contains(key)) {
            return includedTypes[key]
        }
        return ArrayList<BindgenTypeEntry>()
    }

    public func cfgForType(namespace: String, name: String, fileIdx: Int64, row: Int64): ArrayList<String> {
        return cfgForType(TypeName.named(namespace, trimTick(name)), fileIdx, row)
    }

    public func cfgForType(typeName: TypeName, fileIdx: Int64, row: Int64): ArrayList<String> {
        let key = TableRowKey(TABLE_TYPE_DEF, fileIdx, row)
        if (itemCfg.contains(key)) {
            return itemCfg[key]
        }
        return ArrayList<String>()
    }

    public func cfgForItem(table: Int64, fileIdx: Int64, row: Int64): ArrayList<String> {
        let key = TableRowKey(table, fileIdx, row)
        if (itemCfg.contains(key)) {
            return itemCfg[key]
        }
        return ArrayList<String>()
    }

    public func forceIncludeType(index: TypeIndex, typeName: TypeName): Unit {
        if (containsType(typeName)) {
            return
        }

        let queue = ArrayList<BindgenTypeKey>()
        let queued = HashMap<BindgenTypeKey, Bool>()
        enqueueTypeCandidates(index, typeName.definition(), queue, queued)

        var added = false
        var qi: Int64 = 0
        while (qi < Int64(queue.size)) {
            let entryKey = queue[qi]
            qi += 1

            if (containsEntry(entryKey)) {
                continue
            }

            addNamespaceType(index, entryKey)
            added = true

            if (config.noDeps) {
                continue
            }

            if (!dependencyGraph.contains(entryKey)) {
                dependencyGraph[entryKey] = collectTypeDependencies(index, entryKey.fileIdx, entryKey.row)
            }

            for (dependency in dependencyGraph[entryKey]) {
                let dependencyName = dependency.definition()
                if (shouldReferenceDependency(dependencyName)) {
                    continue
                }
                enqueueTypeCandidates(index, dependencyName, queue, queued)
            }
        }

        if (added) {
            finalizeNamespaceTypeOrdering(index)
            rebuildItemCfg(index)
        }
    }

    func build(index: TypeIndex, filter: BindgenFilter): Unit {
        let queue = ArrayList<BindgenTypeKey>()
        let queued = HashMap<BindgenTypeKey, Bool>()

        for ((typeName, entry) in index.iterTypeEntries()) {
            let flags = index.typeDefFlags(entry.fileIdx, entry.row)
            if (flags.isNested()) {
                continue
            }
            if (!filter.includesType(typeName.namespace, trimTick(typeName.name))) {
                continue
            }
            if (!filter.hasExplicitIncludes() && shouldReferenceDependency(typeName.definition())) {
                continue
            }
            enqueueType(queue, queued, BindgenTypeKey(typeName.definition(), entry.fileIdx, entry.row))
        }

        var qi: Int64 = 0
        while (qi < Int64(queue.size)) {
            let entryKey = queue[qi]
            qi += 1

            addNamespaceType(index, entryKey)

            if (config.noDeps) {
                continue
            }

            if (!dependencyGraph.contains(entryKey)) {
                dependencyGraph[entryKey] = collectTypeDependencies(index, entryKey.fileIdx, entryKey.row)
            }

            for (dependency in dependencyGraph[entryKey]) {
                let dependencyName = dependency.definition()
                if (shouldReferenceDependency(dependencyName)) {
                    continue
                }
                if (filter.excludesType(dependencyName.namespace, trimTick(dependencyName.name))) {
                    continue
                }

                enqueueTypeCandidates(index, dependencyName, queue, queued)
            }
        }

        finalizeNamespaceTypeOrdering(index)
        rebuildItemCfg(index)
    }

    func addNamespaceType(index: TypeIndex, entryKey: BindgenTypeKey): Unit {
        let namespace = entryKey.typeName.namespace
        if (!namespaceTypes.contains(namespace)) {
            namespaceTypes[namespace] = ArrayList<BindgenTypeEntry>()
        }

        let entry = BindgenTypeEntry(entryKey.typeName, entryKey.fileIdx, entryKey.row)
        namespaceTypes[namespace].add(entry)
        sortTypeMapEntries(namespaceTypes[namespace])

        let typeName = entry.typeName.definition()
        if (!includedTypes.contains(typeName)) {
            includedTypes[typeName] = ArrayList<BindgenTypeEntry>()
        }
        includedTypes[typeName].add(entry)
        sortTypeMapEntries(includedTypes[typeName])

    }

    func rebuildItemCfg(index: TypeIndex): Unit {
        itemCfg.clear()
        for ((_, entries) in namespaceTypes) {
            for (entry in entries) {
                recordEntryItemCfg(index, entry)
            }
        }
    }

    func recordEntryItemCfg(index: TypeIndex, entry: BindgenTypeEntry): Unit {
        let arches = index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row)
        let cfgTags = mergeTypeMapCfgTags(
            architectureCfgTags(arches),
            dependencyCfgTagsForTypeSurface(index, entry.namespace, entry.fileIdx, entry.row)
        )
        if (!cfgTags.isEmpty()) {
            itemCfg[TableRowKey(TABLE_TYPE_DEF, entry.fileIdx, entry.row)] = cfgTags
        }

        let (fieldStart, fieldEnd) = index.typeDefFields(entry.fileIdx, entry.row)
        var fieldRow = fieldStart
        while (fieldRow < fieldEnd) {
            let fieldTags = architectureCfgTags(index.arches(TABLE_FIELD, entry.fileIdx, fieldRow))
            if (!fieldTags.isEmpty()) {
                itemCfg[TableRowKey(TABLE_FIELD, entry.fileIdx, fieldRow)] = fieldTags
            }
            fieldRow += 1
        }

        let generics = buildDependencyGenericArray(index, entry.fileIdx, entry.row)
        let (methodStart, methodEnd) = index.typeDefMethods(entry.fileIdx, entry.row)
        var methodRow = methodStart
        while (methodRow < methodEnd) {
            let methodTags = mergeTypeMapCfgTags(
                architectureCfgTags(index.arches(TABLE_METHOD_DEF, entry.fileIdx, methodRow)),
                dependencyCfgTagsForMethod(index, entry.namespace, entry.fileIdx, methodRow, generics)
            )
            if (!methodTags.isEmpty()) {
                itemCfg[TableRowKey(TABLE_METHOD_DEF, entry.fileIdx, methodRow)] = methodTags
            }
            methodRow += 1
        }
    }

    func finalizeNamespaceTypeOrdering(index: TypeIndex): Unit {
        let namespaces = ArrayList<String>()
        for ((namespace, _) in namespaceTypes) {
            namespaces.add(namespace)
        }
        sortStrings(namespaces)
        for (namespace in namespaces) {
            namespaceTypes[namespace] = orderNamespaceEntries(index, namespaceTypes[namespace])
        }
    }

    func orderNamespaceEntries(
        index: TypeIndex,
        entries: ArrayList<BindgenTypeEntry>
    ): ArrayList<BindgenTypeEntry> {
        if (entries.size <= 1) {
            return entries
        }

        let availableCounts = countNamespaceTypeEntries(entries)
        let ordered = ArrayList<BindgenTypeEntry>()
        let emittedCounts = HashMap<TypeName, Int64>()
        var remaining = cloneTypeMapEntries(entries)

        while (!remaining.isEmpty()) {
            let deferred = ArrayList<BindgenTypeEntry>()
            var progress = false

            for (entry in remaining) {
                if (canEmitNamespaceEntry(index, entry, availableCounts, emittedCounts)) {
                    ordered.add(entry)
                    incrementNamespaceTypeCount(emittedCounts, entry.typeName)
                    progress = true
                } else {
                    deferred.add(entry)
                }
            }

            if (!progress) {
                ordered.add(all: deferred)
                break
            }

            remaining = deferred
        }

        return ordered
    }

    func canEmitNamespaceEntry(
        index: TypeIndex,
        entry: BindgenTypeEntry,
        availableCounts: HashMap<TypeName, Int64>,
        emittedCounts: HashMap<TypeName, Int64>
    ): Bool {
        for (dependency in dependenciesForEntry(index, entry)) {
            let dependencyName = dependency.definition()
            if (dependencyName.namespace != entry.namespace || dependencyName == entry.typeName ||
                !availableCounts.contains(dependencyName)) {
                continue
            }

            if (namespaceTypeCount(emittedCounts, dependencyName) < namespaceTypeCount(availableCounts,
                dependencyName)) {
                return false
            }
        }

        return true
    }

    func dependenciesForEntry(index: TypeIndex, entry: BindgenTypeEntry): ArrayList<TypeName> {
        let entryKey = entry.key()
        if (!dependencyGraph.contains(entryKey)) {
            dependencyGraph[entryKey] = collectTypeDependencies(index, entry.fileIdx, entry.row)
        }
        return dependencyGraph[entryKey]
    }

    func dependencyCfgTagsForTypeSurface(
        index: TypeIndex,
        ownerNamespace: String,
        fileIdx: Int64,
        row: Int64
    ): ArrayList<String> {
        let sameNamespaceSeen = HashMap<TypeName, Bool>()
        return dependencyCfgTagsForTypeSurfaceInternal(index, ownerNamespace, fileIdx, row, sameNamespaceSeen)
    }

    func dependencyCfgTagsForTypeSurfaceInternal(
        index: TypeIndex,
        ownerNamespace: String,
        fileIdx: Int64,
        row: Int64,
        sameNamespaceSeen: HashMap<TypeName, Bool>
    ): ArrayList<String> {
        match (index.typeDefCategory(fileIdx, row)) {
            case Delegate =>
                let result = ArrayList<String>()
                let generics = buildDependencyGenericArray(index, fileIdx, row)
                let (methodStart, methodEnd) = index.typeDefMethods(fileIdx, row)
                var methodRow = methodStart
                while (methodRow < methodEnd) {
                    let tags = dependencyCfgTagsForMethodInternal(index, ownerNamespace, fileIdx, methodRow, generics,
                        sameNamespaceSeen)
                    for (tag in tags) {
                        addUniqueTypeMapCfgTag(result, tag)
                    }
                    methodRow += 1
                }
                sortStrings(result)
                if (result.size > 1) {
                    let combined = ArrayList<String>()
                    combined.add(joinStrings(result, " && "))
                    return combined
                }
                return result
            case Interface =>
                let dependencies = collectInterfaceTypeSurfaceDependencies(index, fileIdx, row)
                return dependencyCfgTagsForTypesInternal(index, ownerNamespace, dependencies, sameNamespaceSeen)
            case Struct =>
                let dependencies = collectCppTypeSurfaceDependencies(index, fileIdx, row)
                return dependencyCfgTagsForTypesInternal(index, ownerNamespace, dependencies, sameNamespaceSeen)
            case _ => return ArrayList<String>()
        }
    }

    func dependencyCfgTagsForMetadataType(index: TypeIndex, ownerNamespace: String, ty: MetadataType): ArrayList<String> {
        let dependencies = ArrayList<TypeName>()
        let seen = HashMap<TypeName, Bool>()
        collectCppMetadataTypeDependencies(ty, dependencies, seen)
        return dependencyCfgTagsForTypes(index, ownerNamespace, dependencies)
    }

    func dependencyCfgTagsForMethod(
        index: TypeIndex,
        ownerNamespace: String,
        fileIdx: Int64,
        row: Int64,
        generics: Array<MetadataType>
    ): ArrayList<String> {
        let sameNamespaceSeen = HashMap<TypeName, Bool>()
        return dependencyCfgTagsForMethodInternal(index, ownerNamespace, fileIdx, row, generics, sameNamespaceSeen)
    }

    func dependencyCfgTagsForMethodInternal(
        index: TypeIndex,
        ownerNamespace: String,
        fileIdx: Int64,
        row: Int64,
        generics: Array<MetadataType>,
        sameNamespaceSeen: HashMap<TypeName, Bool>
    ): ArrayList<String> {
        let dependencies = ArrayList<TypeName>()
        let seen = HashMap<TypeName, Bool>()
        let signature = index.methodDefSignature(fileIdx, row, generics)
        collectCppMetadataTypeDependencies(signature.returnType, dependencies, seen)
        for (paramType in signature.paramTypes) {
            collectCppMetadataTypeDependencies(paramType, dependencies, seen)
        }
        return dependencyCfgTagsForTypesInternal(index, ownerNamespace, dependencies, sameNamespaceSeen)
    }

    func dependencyCfgTagsForTypes(index: TypeIndex, ownerNamespace: String, dependencies: ArrayList<TypeName>): ArrayList<String> {
        let sameNamespaceSeen = HashMap<TypeName, Bool>()
        return dependencyCfgTagsForTypesInternal(index, ownerNamespace, dependencies, sameNamespaceSeen)
    }

    func dependencyCfgTagsForTypesInternal(
        index: TypeIndex,
        ownerNamespace: String,
        dependencies: ArrayList<TypeName>,
        sameNamespaceSeen: HashMap<TypeName, Bool>
    ): ArrayList<String> {
        let result = ArrayList<String>()
        for (dependency in dependencies) {
            let dependencyName = dependency.definition()
            if (dependencyName.namespace.isEmpty() || dependencyName.namespace == "System") {
                continue
            }
            if (shouldReferenceDependency(dependencyName)) {
                if (dependencyName.namespace == ownerNamespace) {
                    continue
                }
                if (isImpliedNamespaceDependency(ownerNamespace, dependencyName.namespace)) {
                    continue
                }
                addUniqueTypeMapCfgTag(result, "${namespaceToFeature(dependencyName.namespace)} == \"on\"")
                continue
            }
            if (!containsType(dependencyName)) {
                continue
            }
            if (dependencyName.namespace == ownerNamespace) {
                addGeneratedDependencyReferenceCfgTags(index, ownerNamespace, dependencyName, result, sameNamespaceSeen)
                continue
            }
            if (isImpliedNamespaceDependency(ownerNamespace, dependencyName.namespace)) {
                continue
            }
            addUniqueTypeMapCfgTag(result, "${namespaceToFeature(dependencyName.namespace)} == \"on\"")
            addGeneratedDependencyReferenceCfgTags(index, ownerNamespace, dependencyName, result, sameNamespaceSeen)
        }
        sortStrings(result)
        if (result.size > 1) {
            let combined = ArrayList<String>()
            combined.add(joinStrings(result, " && "))
            return combined
        }
        return result
    }

    func addGeneratedDependencySurfaceCfgTags(
        index: TypeIndex,
        ownerNamespace: String,
        dependencyName: TypeName,
        result: ArrayList<String>,
        sameNamespaceSeen: HashMap<TypeName, Bool>
    ): Unit {
        if (sameNamespaceSeen.contains(dependencyName)) {
            return
        }
        sameNamespaceSeen[dependencyName] = true

        let entries = entriesForType(dependencyName.namespace, trimTick(dependencyName.name))
        for (entry in entries) {
            if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row))) {
                continue
            }
            let tags = dependencyCfgTagsForTypeSurfaceInternal(index, ownerNamespace, entry.fileIdx, entry.row,
                sameNamespaceSeen)
            for (tag in tags) {
                addUniqueTypeMapCfgTag(result, tag)
            }
        }
    }

    func addGeneratedDependencyReferenceCfgTags(
        index: TypeIndex,
        ownerNamespace: String,
        dependencyName: TypeName,
        result: ArrayList<String>,
        sameNamespaceSeen: HashMap<TypeName, Bool>
    ): Unit {
        if (sameNamespaceSeen.contains(dependencyName)) {
            return
        }
        sameNamespaceSeen[dependencyName] = true

        let entries = entriesForType(dependencyName.namespace, trimTick(dependencyName.name))
        let requiredTags = ArrayList<String>()
        let alternatives = ArrayList<String>()
        var hasUnconditionalAlternative = false
        for (entry in entries) {
            if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row))) {
                let tags = dependencyCfgTagsForTypeSurfaceInternal(index, ownerNamespace, entry.fileIdx, entry.row,
                    sameNamespaceSeen)
                for (tag in tags) {
                    addUniqueTypeMapCfgTag(requiredTags, tag)
                }
                continue
            }
            let tags = generatedDependencyReferenceCfgTagsForEntry(index, ownerNamespace, entry, sameNamespaceSeen)
            if (tags.isEmpty()) {
                hasUnconditionalAlternative = true
                continue
            }
            for (tag in tags) {
                addUniqueTypeMapCfgTag(alternatives, tag)
            }
        }
        for (tag in requiredTags) {
            addUniqueTypeMapCfgTag(result, tag)
        }
        if (!hasUnconditionalAlternative) {
            addTypeMapAlternativeCfgTag(result, alternatives)
        }
    }

    func generatedDependencyReferenceCfgTagsForEntry(
        index: TypeIndex,
        ownerNamespace: String,
        entry: BindgenTypeEntry,
        sameNamespaceSeen: HashMap<TypeName, Bool>
    ): ArrayList<String> {
        let archTags = architectureCfgTags(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row))
        match (index.typeDefCategory(entry.fileIdx, entry.row)) {
            case Struct | Delegate =>
                let surfaceTags = dependencyCfgTagsForTypeSurfaceInternal(index, ownerNamespace, entry.fileIdx, entry.row,
                    sameNamespaceSeen)
                return mergeTypeMapCfgTags(archTags, surfaceTags)
            case _ => return archTags
        }
    }

    func containsEntry(entryKey: BindgenTypeKey): Bool {
        if (!includedTypes.contains(entryKey.typeName)) {
            return false
        }
        for (entry in includedTypes[entryKey.typeName]) {
            if (entry.fileIdx == entryKey.fileIdx && entry.row == entryKey.row) {
                return true
            }
        }
        return false
    }

    func shouldReferenceDependency(typeName: TypeName): Bool {
        return references.containsType(typeName.namespace, trimTick(typeName.name)) &&
            !config.isForcedLocalType(typeName.namespace, trimTick(typeName.name))
    }
}

func mergeTypeMapCfgTags(first: ArrayList<String>, second: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    if (first.isEmpty()) {
        for (value in second) {
            addUniqueTypeMapCfgTag(result, value)
        }
        return result
    }
    if (second.isEmpty()) {
        for (value in first) {
            addUniqueTypeMapCfgTag(result, value)
        }
        return result
    }

    for (value in first) {
        for (other in second) {
            let combined = combineTypeMapCfgTagConditions(typeMapCfgTagCondition(value), typeMapCfgTagCondition(other))
            if (!combined.isEmpty()) {
                addUniqueTypeMapCfgTag(result, combined)
            }
        }
    }
    return result
}

func combineTypeMapCfgTagConditions(first: String, second: String): String {
    if (first == second) {
        return first
    }

    let firstArch = requiredSingleArch(first)
    let secondArch = requiredSingleArch(second)
    if (!firstArch.isEmpty() && !secondArch.isEmpty()) {
        if (firstArch != secondArch) {
            return ""
        }
        if (isExactArchCondition(first, firstArch)) {
            return second
        }
        if (isExactArchCondition(second, secondArch)) {
            return first
        }
    }

    return "${first} && ${second}"
}

func requiredSingleArch(condition: String): String {
    if (condition.indexOf(" || ", 0).isSome()) {
        return ""
    }
    let hasX64 = condition.indexOf("arch == \"x86_64\"", 0).isSome()
    let hasArm64 = condition.indexOf("arch == \"aarch64\"", 0).isSome()
    if (hasX64 && !hasArm64) {
        return "x86_64"
    }
    if (hasArm64 && !hasX64) {
        return "aarch64"
    }
    return ""
}

func isExactArchCondition(condition: String, archValue: String): Bool {
    return condition == "arch == \"${archValue}\""
}

func typeMapCfgTagCondition(tag: String): String {
    match (tag) {
        case "arch_x86_64" => return "arch == \"x86_64\""
        case "arch_arm64" => return "arch == \"aarch64\""
        case _ => return tag
    }
}

func addUniqueTypeMapCfgTag(values: ArrayList<String>, value: String): Unit {
    for (existing in values) {
        if (existing == value) {
            return
        }
    }
    values.add(value)
}

func addTypeMapAlternativeCfgTag(result: ArrayList<String>, alternatives: ArrayList<String>): Unit {
    if (alternatives.isEmpty()) {
        return
    }
    if (alternatives.size == 1) {
        addUniqueTypeMapCfgTag(result, alternatives[0])
        return
    }
    let wrapped = ArrayList<String>()
    for (alternative in alternatives) {
        if (conditionNeedsTypeMapParentheses(alternative)) {
            wrapped.add("(${alternative})")
        } else {
            wrapped.add(alternative)
        }
    }
    let group = joinStrings(wrapped, " || ")
    addUniqueTypeMapCfgTag(result, "(${group})")
}

func conditionNeedsTypeMapParentheses(condition: String): Bool {
    return condition.indexOf(" && ", 0).isSome() || condition.indexOf(" || ", 0).isSome()
}

func isImpliedNamespaceDependency(ownerNamespace: String, dependencyNamespace: String): Bool {
    if (dependencyNamespace == "Windows.Win32.Foundation" &&
        (ownerNamespace == "Windows.Win32" || ownerNamespace.startsWith("Windows.Win32.") ||
            ownerNamespace == "Windows.Wdk" || ownerNamespace.startsWith("Windows.Wdk."))) {
        return true
    }

    if (dependencyNamespace == "Windows.Foundation" &&
        ownerNamespace.startsWith("Windows.") &&
        ownerNamespace != "Windows.Win32" &&
        !ownerNamespace.startsWith("Windows.Win32.") &&
        ownerNamespace != "Windows.Wdk" &&
        !ownerNamespace.startsWith("Windows.Wdk.")) {
        return true
    }

    return false
}

func enqueueType(
    queue: ArrayList<BindgenTypeKey>,
    queued: HashMap<BindgenTypeKey, Bool>,
    entryKey: BindgenTypeKey
): Unit {
    if (queued.contains(entryKey)) {
        return
    }

    queued[entryKey] = true
    queue.add(entryKey)
}

func enqueueTypeCandidates(
    index: TypeIndex,
    typeName: TypeName,
    queue: ArrayList<BindgenTypeKey>,
    queued: HashMap<BindgenTypeKey, Bool>
): Unit {
    let candidates = index.get(typeName)
    for (candidate in candidates) {
        let flags = index.typeDefFlags(candidate.fileIdx, candidate.row)
        if (flags.isNested()) {
            continue
        }
        enqueueType(queue, queued, BindgenTypeKey(typeName.definition(), candidate.fileIdx, candidate.row))
    }
}

func cloneTypeMapEntries(values: ArrayList<BindgenTypeEntry>): ArrayList<BindgenTypeEntry> {
    let result = ArrayList<BindgenTypeEntry>()
    result.add(all: values)
    return result
}

func countNamespaceTypeEntries(entries: ArrayList<BindgenTypeEntry>): HashMap<TypeName, Int64> {
    let counts = HashMap<TypeName, Int64>()
    for (entry in entries) {
        incrementNamespaceTypeCount(counts, entry.typeName)
    }
    return counts
}

func incrementNamespaceTypeCount(counts: HashMap<TypeName, Int64>, typeName: TypeName): Unit {
    counts[typeName] = namespaceTypeCount(counts, typeName) + 1
}

func namespaceTypeCount(counts: HashMap<TypeName, Int64>, typeName: TypeName): Int64 {
    if (counts.contains(typeName)) {
        return counts[typeName]
    }
    return 0
}

func collectTypeDependencies(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()
    let visitedTypeDefs = HashMap<String, Bool>()
    collectTypeDefDependencies(index, fileIdx, row, result, seen, visitedTypeDefs)
    sortTypeNames(result)
    return result
}

func collectTypeDefDependencies(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>,
    visitedTypeDefs: HashMap<String, Bool>
): Unit {
    let visitKey = "${fileIdx}:${row}"
    if (visitedTypeDefs.contains(visitKey)) {
        return
    }
    visitedTypeDefs[visitKey] = true

    collectExtendsDependency(index, fileIdx, row, result, seen)
    collectInterfaceDependencies(index, fileIdx, row, result, seen)
    collectFactoryInterfaceDependencies(index, fileIdx, row, result, seen)
    collectProjectedClassDependencies(index, fileIdx, row, result, seen)
    collectAlsoUsableForDependencies(index, fileIdx, row, result, seen)

    let (fieldStart, fieldEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fieldStart
    while (fieldRow < fieldEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (!fieldFlags.contains(FieldAttributes.Literal)) {
            collectMetadataTypeDependencies(index.fieldType(fileIdx, fieldRow), result, seen)
        }
        fieldRow += 1
    }

    let generics = buildDependencyGenericArray(index, fileIdx, row)
    let (methodStart, methodEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = methodStart
    while (methodRow < methodEnd) {
        let signature = index.methodDefSignature(fileIdx, methodRow, generics)
        collectMetadataTypeDependencies(signature.returnType, result, seen)
        for (paramType in signature.paramTypes) {
            collectMetadataTypeDependencies(paramType, result, seen)
        }
        methodRow += 1
    }

    let nestedRows = index.getNested(fileIdx, row)
    for (nestedRow in nestedRows) {
        collectTypeDefDependencies(index, fileIdx, nestedRow, result, seen, visitedTypeDefs)
    }
}

func collectFactoryInterfaceDependencies(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    for (factoryInfo in collectFactoryInterfaces(index, fileIdx, row)) {
        addDependency(factoryInfo.typeName, result, seen)
    }
}

func collectExtendsDependency(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    let file = index.getFile(fileIdx)
    let (extTable, extRow) = index.typeDefExtends(fileIdx, row)
    if (extTable == TABLE_TYPE_DEF) {
        addDependency(TypeName.named(file.getString(extRow, TABLE_TYPE_DEF, 2), trimTick(file.getString(extRow, TABLE_TYPE_DEF, 1))), result, seen)
    } else if (extTable == TABLE_TYPE_REF) {
        addDependency(TypeName.named(file.getString(extRow, TABLE_TYPE_REF, 2), trimTick(file.getString(extRow, TABLE_TYPE_REF, 1))), result, seen)
    }
}

func collectInterfaceDependencies(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
        match (decodeTypeDefOrRefTypeName(index, fileIdx, ifaceValue)) {
            case Some(typeName) =>
                addDependency(typeName, result, seen)
                let candidates = index.get(typeName.definition())
                if (!candidates.isEmpty()) {
                    let entry = candidates[0]
                    for (ancestor in winmdCollectInterfaceAncestors(index, entry.fileIdx, entry.row)) {
                        addDependency(ancestor, result, seen)
                    }
                }
            case None => ()
        }
        ii += 1
    }
}

func collectProjectedClassDependencies(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    match (index.typeDefCategory(fileIdx, row)) {
        case Class => ()
        case _ => return
    }

    for (baseType in winmdCollectClassBases(index, fileIdx, row)) {
        addDependency(baseType, result, seen)
        let candidates = index.get(baseType.definition())
        if (candidates.isEmpty()) {
            continue
        }
        let entry = candidates[0]
        for (iface in winmdCollectInterfaceAncestors(index, entry.fileIdx, entry.row)) {
            addDependency(iface, result, seen)
        }
    }
}

public func collectMetadataTypeDependencies(
    ty: MetadataType,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            collectTypeNameDependencies(typeName, result, seen)
        case MetadataType.ValueName(typeName) =>
            collectTypeNameDependencies(typeName, result, seen)
        case MetadataType.Union(typeName) =>
            collectTypeNameDependencies(typeName, result, seen)
        case MetadataType.MdArray(inner) =>
            collectMetadataTypeDependencies(inner, result, seen)
        case MetadataType.RefMut(inner) =>
            collectMetadataTypeDependencies(inner, result, seen)
        case MetadataType.RefConst(inner) =>
            collectMetadataTypeDependencies(inner, result, seen)
        case MetadataType.PtrMut(inner, _) =>
            collectMetadataTypeDependencies(inner, result, seen)
        case MetadataType.PtrConst(inner, _) =>
            collectMetadataTypeDependencies(inner, result, seen)
        case MetadataType.ArrayFixed(inner, _) =>
            collectMetadataTypeDependencies(inner, result, seen)
        case MetadataType.Packed(inner, _) =>
            collectMetadataTypeDependencies(inner, result, seen)
        case _ => ()
    }
}

func collectCppTypeSurfaceDependencies(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()
    let visitedTypeDefs = HashMap<TableRowKey, Bool>()

    collectCppTypeSurfaceDependenciesInto(index, fileIdx, row, result, seen, visitedTypeDefs)

    return result
}

func collectInterfaceTypeSurfaceDependencies(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()

    match (winmdFindBaseInterface(index, fileIdx, row)) {
        case Some(baseInterface) => addDependency(baseInterface.definition(), result, seen)
        case None => ()
    }

    return result
}

func collectCppTypeSurfaceDependenciesInto(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>,
    visitedTypeDefs: HashMap<TableRowKey, Bool>
): Unit {
    let visitKey = TableRowKey(TABLE_TYPE_DEF, fileIdx, row)
    if (visitedTypeDefs.contains(visitKey)) {
        return
    }
    visitedTypeDefs[visitKey] = true

    collectAlsoUsableForDependencies(index, fileIdx, row, result, seen)

    let (fieldStart, fieldEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fieldStart
    while (fieldRow < fieldEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (!fieldFlags.contains(FieldAttributes.Literal)) {
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, row, index.fieldType(fileIdx, fieldRow), result,
                seen, visitedTypeDefs)
        }
        fieldRow += 1
    }
}

func collectCppMetadataTypeDependencies(
    ty: MetadataType,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            collectCppTypeNameDependency(ty, typeName, result, seen)
        case MetadataType.ValueName(typeName) =>
            collectCppTypeNameDependency(ty, typeName, result, seen)
        case MetadataType.Union(typeName) =>
            collectCppTypeNameDependency(ty, typeName, result, seen)
        case MetadataType.MdArray(inner) =>
            collectCppMetadataTypeDependencies(inner, result, seen)
        case MetadataType.RefMut(inner) =>
            collectCppMetadataTypeDependencies(inner, result, seen)
        case MetadataType.RefConst(inner) =>
            collectCppMetadataTypeDependencies(inner, result, seen)
        case MetadataType.PtrMut(inner, _) =>
            collectCppMetadataTypeDependencies(inner, result, seen)
        case MetadataType.PtrConst(inner, _) =>
            collectCppMetadataTypeDependencies(inner, result, seen)
        case MetadataType.ArrayFixed(inner, _) =>
            collectCppMetadataTypeDependencies(inner, result, seen)
        case MetadataType.Packed(inner, _) =>
            collectCppMetadataTypeDependencies(inner, result, seen)
        case _ => ()
    }
}

func collectCppMetadataTypeDependenciesInScope(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>,
    visitedTypeDefs: HashMap<TableRowKey, Bool>
): Unit {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            collectCppTypeNameDependencyInScope(index, fileIdx, scopeRow, ty, typeName, result, seen, visitedTypeDefs)
        case MetadataType.ValueName(typeName) =>
            collectCppTypeNameDependencyInScope(index, fileIdx, scopeRow, ty, typeName, result, seen, visitedTypeDefs)
        case MetadataType.Union(typeName) =>
            collectCppTypeNameDependencyInScope(index, fileIdx, scopeRow, ty, typeName, result, seen, visitedTypeDefs)
        case MetadataType.MdArray(inner) =>
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, inner, result, seen, visitedTypeDefs)
        case MetadataType.RefMut(inner) =>
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, inner, result, seen, visitedTypeDefs)
        case MetadataType.RefConst(inner) =>
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, inner, result, seen, visitedTypeDefs)
        case MetadataType.PtrMut(inner, _) =>
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, inner, result, seen, visitedTypeDefs)
        case MetadataType.PtrConst(inner, _) =>
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, inner, result, seen, visitedTypeDefs)
        case MetadataType.ArrayFixed(inner, _) =>
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, inner, result, seen, visitedTypeDefs)
        case MetadataType.Packed(inner, _) =>
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, inner, result, seen, visitedTypeDefs)
        case _ => ()
    }
}

func collectCppTypeNameDependencyInScope(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    typeName: TypeName,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>,
    visitedTypeDefs: HashMap<TableRowKey, Bool>
): Unit {
    if (typeName.namespace.isEmpty()) {
        let nestedKeys = directNestedTypeKeyMap(index, fileIdx, scopeRow)
        match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
            case Some((resolvedFileIdx, resolvedRow)) =>
                collectCppTypeSurfaceDependenciesInto(index, resolvedFileIdx, resolvedRow, result, seen, visitedTypeDefs)
            case None => ()
        }
        for (generic in typeName.generics) {
            collectCppMetadataTypeDependenciesInScope(index, fileIdx, scopeRow, generic, result, seen, visitedTypeDefs)
        }
        return
    }

    collectCppTypeNameDependency(ty, typeName, result, seen)
}

func collectCppTypeNameDependency(
    ty: MetadataType,
    typeName: TypeName,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    if (!typeName.namespace.isEmpty() && cppTypeReferencesNamedType(cppType(ty), trimTick(typeName.name))) {
        addDependency(typeName, result, seen)
    }

    for (generic in typeName.generics) {
        collectCppMetadataTypeDependencies(generic, result, seen)
    }
}

func cppTypeReferencesNamedType(typeText: String, rawName: String): Bool {
    let name = escapeSourceIdentifier(rawName)
    if (name.isEmpty()) {
        return false
    }
    let haystack = typeText.toArray()
    let needle = name.toArray()
    let n = Int64(haystack.size)
    let m = Int64(needle.size)
    if (m == 0 || m > n) {
        return false
    }

    var i: Int64 = 0
    while (i <= n - m) {
        var matched = true
        var j: Int64 = 0
        while (j < m) {
            if (haystack[i + j] != needle[j]) {
                matched = false
                break
            }
            j += 1
        }
        if (matched) {
            let beforeOk = i == 0 || !typeMapIdentifierChar(haystack[i - 1])
            let afterIdx = i + m
            let afterOk = afterIdx >= n || !typeMapIdentifierChar(haystack[afterIdx])
            if (beforeOk && afterOk) {
                return true
            }
        }
        i += 1
    }
    return false
}

func typeMapIdentifierChar(b: Byte): Bool {
    if (b >= b'a' && b <= b'z') { return true }
    if (b >= b'A' && b <= b'Z') { return true }
    if (b >= b'0' && b <= b'9') { return true }
    return b == b'_'
}

func collectTypeNameDependencies(
    typeName: TypeName,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    if (!typeName.namespace.isEmpty()) {
        addDependency(typeName, result, seen)
    }

    for (generic in typeName.generics) {
        collectMetadataTypeDependencies(generic, result, seen)
    }
}

func collectAlsoUsableForDependencies(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    match (index.findAttribute(TABLE_TYPE_DEF, fileIdx, row, "AlsoUsableForAttribute")) {
        case Some(attrRow) =>
            let namespace = index.typeDefNamespace(fileIdx, row)
            for ((_, value) in index.attributeValues(fileIdx, attrRow)) {
                match (value) {
                    case MetadataValue.ValTypeName(typeName) =>
                        addDependency(typeName.definition(), result, seen)
                    case MetadataValue.ValUtf8(typeNameText) =>
                        addDependency(parseAlsoUsableTypeName(namespace, typeNameText), result, seen)
                    case _ => ()
                }
            }
        case None => ()
    }
}

func parseAlsoUsableTypeName(defaultNamespace: String, typeNameText: String): TypeName {
    let arr = typeNameText.toArray()
    var lastDot: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'.') {
            lastDot = i
        }
        i += 1
    }
    if (lastDot >= 0) {
        return TypeName.named(
            String.fromUtf8(arr[0..lastDot]),
            String.fromUtf8(arr[lastDot + 1..Int64(arr.size)])
        )
    }
    return TypeName.named(defaultNamespace, typeNameText)
}

func addDependency(
    typeName: TypeName,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    if (typeName.namespace.isEmpty()) {
        return
    }

    if (seen.contains(typeName)) {
        return
    }

    seen[typeName] = true
    result.add(typeName)
}

func buildDependencyGenericArray(index: TypeIndex, fileIdx: Int64, row: Int64): Array<MetadataType> {
    let (gpStart, gpEnd) = index.typeDefGenericParams(fileIdx, row)
    if (gpStart >= gpEnd) {
        return Array<MetadataType>(0, {_ => MetadataType.Void})
    }

    let generics = ArrayList<MetadataType>()
    var gpRow = gpStart
    while (gpRow < gpEnd) {
        let genericName = index.genericParamName(fileIdx, gpRow)
        generics.add(MetadataType.Generic(genericName, UInt16(gpRow - gpStart)))
        gpRow += 1
    }

    let result = Array<MetadataType>(generics.size, {_ => MetadataType.Void})
    var i: Int64 = 0
    while (i < Int64(generics.size)) {
        result[i] = generics[i]
        i += 1
    }
    return result
}

public func qualifiedTypeName(namespace: String, name: String): String {
    if (namespace.isEmpty()) {
        return trimTick(name)
    }
    return "${namespace}.${trimTick(name)}"
}

public func qualifiedTypeName(typeName: TypeName): String {
    return qualifiedTypeName(typeName.namespace, trimTick(typeName.name))
}

public func splitQualifiedType(value: String): Option<(String, String)> {
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

public func parseQualifiedTypeName(value: String): Option<TypeName> {
    match (splitQualifiedType(value)) {
        case Some((namespace, name)) => return Some(TypeName.named(namespace, trimTick(name)))
        case None => return None
    }
}

func sortTypeMapEntries(values: ArrayList<BindgenTypeEntry>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && typeMapEntryLess(key, values[j])) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}

func typeMapEntryLess(lhs: BindgenTypeEntry, rhs: BindgenTypeEntry): Bool {
    if (lhs.typeName != rhs.typeName) {
        return lhs.typeName.compare(rhs.typeName) == Ordering.LT
    }
    if (lhs.fileIdx != rhs.fileIdx) {
        return lhs.fileIdx < rhs.fileIdx
    }
    return lhs.row < rhs.row
}

func sortTypeNames(values: ArrayList<TypeName>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && key.compare(values[j]) == Ordering.LT) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}

public func sortStrings(values: ArrayList<String>): Unit {
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
