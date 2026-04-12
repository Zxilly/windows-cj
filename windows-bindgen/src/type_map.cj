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
                if (references.containsType(dependencyName.namespace, trimTick(dependencyName.name))) {
                    continue
                }
                if (filter.excludesType(dependencyName.namespace, trimTick(dependencyName.name))) {
                    continue
                }

                let candidates = index.get(dependencyName)
                for (candidate in candidates) {
                    let depFlags = index.typeDefFlags(candidate.fileIdx, candidate.row)
                    if (depFlags.isNested()) {
                        continue
                    }
                    enqueueType(queue, queued, BindgenTypeKey(dependencyName, candidate.fileIdx, candidate.row))
                }
            }
        }
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

        let arches = index.arches(TABLE_TYPE_DEF, entryKey.fileIdx, entryKey.row)
        let cfgTags = architectureCfgTags(arches)
        if (!cfgTags.isEmpty()) {
            itemCfg[TableRowKey(TABLE_TYPE_DEF, entryKey.fileIdx, entryKey.row)] = cfgTags
        }

        let (fieldStart, fieldEnd) = index.typeDefFields(entryKey.fileIdx, entryKey.row)
        var fieldRow = fieldStart
        while (fieldRow < fieldEnd) {
            let fieldTags = architectureCfgTags(index.arches(TABLE_FIELD, entryKey.fileIdx, fieldRow))
            if (!fieldTags.isEmpty()) {
                itemCfg[TableRowKey(TABLE_FIELD, entryKey.fileIdx, fieldRow)] = fieldTags
            }
            fieldRow += 1
        }

        let (methodStart, methodEnd) = index.typeDefMethods(entryKey.fileIdx, entryKey.row)
        var methodRow = methodStart
        while (methodRow < methodEnd) {
            let methodTags = architectureCfgTags(index.arches(TABLE_METHOD_DEF, entryKey.fileIdx, methodRow))
            if (!methodTags.isEmpty()) {
                itemCfg[TableRowKey(TABLE_METHOD_DEF, entryKey.fileIdx, methodRow)] = methodTags
            }
            methodRow += 1
        }
    }
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

func collectTypeDependencies(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()

    collectExtendsDependency(index, fileIdx, row, result, seen)
    collectInterfaceDependencies(index, fileIdx, row, result, seen)
    collectFactoryInterfaceDependencies(index, fileIdx, row, result, seen)

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

    sortTypeNames(result)
    return result
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
            case None => ()
        }
        ii += 1
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
