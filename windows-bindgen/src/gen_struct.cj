package windows_bindgen

import std.collection.*
import std.collection.concurrent.*
import std.sync.*
import windows_metadata.*

// Layout caches are read+write from every namespace render worker, so the
// underlying map must be thread-safe. ConcurrentHashMap gives us striped
// locking; structEmissionRegistry_ keeps the per-namespace HashSet inside an
// outer mutex because the inner HashSet itself is not thread-safe.
var typeLayoutCache_: ConcurrentHashMap<String, (UInt32, UInt32)> =
    ConcurrentHashMap<String, (UInt32, UInt32)>()
var missingTypeLayoutCache_: ConcurrentHashMap<String, Bool> = ConcurrentHashMap<String, Bool>()
var structEmissionRegistry_: HashMap<String, HashSet<String>> = HashMap<String, HashSet<String>>()
let structEmissionMutex_ = Mutex()

public func resetStructLayoutCaches(): Unit {
    typeLayoutCache_ = ConcurrentHashMap<String, (UInt32, UInt32)>()
    missingTypeLayoutCache_ = ConcurrentHashMap<String, Bool>()
    synchronized(structEmissionMutex_) {
        structEmissionRegistry_ = HashMap<String, HashSet<String>>()
    }
}

func typeLayoutCacheGet(key: String): Option<(UInt32, UInt32)> {
    return typeLayoutCache_.get(key)
}

func typeLayoutCachePut(key: String, value: (UInt32, UInt32)): Unit {
    typeLayoutCache_[key] = value
}

func missingTypeLayoutCacheHas(key: String): Bool {
    return missingTypeLayoutCache_.get(key).isSome()
}

func missingTypeLayoutCachePut(key: String): Unit {
    missingTypeLayoutCache_[key] = true
}

// Append an underscore when a struct field's identifier would shadow a type
// referenced in its own type expression. Cangjie can't disambiguate the
// member from the type when both share a name (e.g. `var GUID: GUID = GUID()`).
func disambiguateFieldName(rawFieldName: String, fieldType: String): String {
    if (rawFieldName == "signature") {
        return "${rawFieldName}_"
    }
    if (rawFieldName == fieldType) {
        return "${rawFieldName}_"
    }
    return rawFieldName
}

// Returns true if this is the first emission of (namespace, key); false on
// duplicate (caller should skip). Used to suppress redundant nested struct
// definitions that arise from sibling outer rows in winmd.
func recordStructEmission(namespace: String, key: String): Bool {
    synchronized(structEmissionMutex_) {
        if (!structEmissionRegistry_.contains(namespace)) {
            structEmissionRegistry_[namespace] = HashSet<String>()
        }
        return structEmissionRegistry_[namespace].add(key)
    }
}

// Generate @C struct definition
public func generateStruct(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    winrtProjection!: Bool = false
): Unit {
    generateStructNamed(w, index, fileIdx, row, namespace, trimTick(index.typeDefName(fileIdx, row)), "",
        ArrayList<String>(), winrtProjection, false)
}

func generateStructNamed(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    name: String,
    parentArches: String,
    parentTags: ArrayList<String>,
    winrtProjection: Bool,
    nestedHelper: Bool
): Unit {
    let flags = index.typeDefFlags(fileIdx, row)
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    let fullName = qualifiedTypeName(namespace, name)
    let ownArches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
    let arches = inheritArches(ownArches, parentArches)

    // Skip handle types (generated separately as type aliases)
    if (isHandleType(index, fileIdx, row)) {
        return
    }
    if (isUnsupportedOnlyArchitecture(arches)) {
        return
    }
    if (!nestedHelper && shouldSkipSyntheticNestedStructEntry(index, namespace, name)) {
        return
    }

    // Check for packing/explicit layout
    let layout = index.typeDefClassLayout(fileIdx, row)
    let isUnion = flags.contains(TypeAttributes.ExplicitLayout)
    let structSignature = buildStructSignature(index, fileIdx, row, name)
    if (!nestedHelper && !shouldEmitStructRow(index, namespace, name, fileIdx, row, structSignature)) {
        return
    }

    // Outer dedup catches single-row duplicates, but the per-arch sibling walk
    // we do below for nested types can revisit the same (namespace, name, arch)
    // pair when winmd carries redundant outer entries. Track emissions per
    // namespace to filter those.
    let emissionKey = "${name}/${arches}/${structSignature}"
    if (!recordStructEmission(namespace, emissionKey)) {
        return
    }

    w.writeBlankLine()

    // Add feature guard based on the outer namespace, including nested helper types
    let feature = namespaceToFeature(namespace)
    let typeTags = mergeTypeMapCfgTags(
        parentTags,
        mergedStructTypeAvailabilityTags(index, namespace, name, fileIdx, row, structSignature, parentArches)
    )
    writeAvailabilityForTags(w, feature, typeTags)

    // Packing annotation and packed-struct dispatch
    var structPacking = 0u32
    match (layout) {
        case Some((packing, _)) =>
            structPacking = UInt32(packing)
        case None => ()
    }

    let nestedNames = directNestedTypeMap(index, fileIdx, row, name)
    let (unionSize, unionAlign) = if (isUnion) {
        computedUnionLayout(index, fileIdx, row)
    } else {
        (0u32, 1u32)
    }
    let (unionRawElemType, unionRawLen) = unionRawStorageSpec(unionSize, unionAlign)
    if (isUnion) {
        if (unionSize > 0u32) {
            // Cangjie paradigm note: `@C struct` cannot host a tagged/untagged union variant directly.
            // The size/alignment-equivalent representation is a raw VArray<T, N> backing slot plus
            // typed `mut prop` accessors. This is documented as an intended paradigm difference, not
            // an ABI bug -- the byte slot matches the union footprint exactly, only field-typed safety
            // is traded for accessor-mediated reinterpretation. See cangjie-behavior.md "repr(C) union".
            w.writeLine("// NOTE: union represented as size-equivalent VArray slot with typed `mut prop` accessors")
            w.writeLine("// (Cangjie paradigm: `@C struct` cannot host a union variant; ABI footprint is preserved)")
            eprintln("note: representing union `${fullName}` as VArray<${unionRawElemType}, ${unionRawLen}> slot (cangjie-paradigm: `@C struct` cannot host union variant; size/alignment preserved)")
        } else {
            w.writeLine("// WARNING: union size unavailable; placeholder only")
            eprintln("warning: union layout for `${fullName}` is missing ClassLayout size")
        }
    }

    // Packed struct with non-default packing (1/2/4/16): use byte storage + polyfill accessors
    let usePackedLayout = !isUnion && structPacking != 0u32 && structPacking != 8u32
    let immutablePacking = structPacking  // capture immutable copy for lambda

    if (winrtProjection && !isUnion && !usePackedLayout) {
        writeWinrtProjectionStruct(
            w,
            index,
            fileIdx,
            row,
            namespace,
            name,
            feature,
            typeTags,
            nestedNames,
            fStart,
            fEnd
        )
    } else {
        writeDeriveAttributes(w, namespace, name)
        if (usePackedLayout) {
            w.writeLine("// packed(${structPacking})")
        }
        w.writeLine("@C")
        w.writeBlock("public struct ${name}", {=>
            if (isUnion) {
                writeUnionStructBody(w, index, fileIdx, row, nestedNames, unionSize, unionRawElemType, unionRawLen,
                    winrtProjection)
            } else if (usePackedLayout) {
                writePackedStructBody(w, index, fileIdx, row, nestedNames, fullName, immutablePacking, winrtProjection)
            } else {
                let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
                var fi = fStart
                while (fi < fEnd) {
                    let fieldFlags = index.fieldFlags(fileIdx, fi)
                    // Skip literal/const fields (they become associated constants)
                    if (fieldFlags.contains(FieldAttributes.Literal)) {
                        fi += 1
                        continue
                    }

                    let rawFieldName = sanitizeIdentifier(index.fieldName(fileIdx, fi))
                    let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
                    let cjType = cppStructFieldStorageType(index, fileIdx, row, fieldType, nestedKeys)
                    let defaultVal = cppStructFieldStorageDefaultValue(index, fileIdx, row, fieldType, nestedKeys)
                    let fieldName = disambiguateFieldName(rawFieldName, cjType)
                    let fieldTags = itemAvailabilityTags(TABLE_FIELD, fileIdx, fi)

                    if (!fieldTags.isEmpty()) {
                        writeAvailabilityForTags(w, "", fieldTags)
                    }
                    w.writeLine("public var ${fieldName}: ${cjType} = ${defaultVal}")
                    fi += 1
                }
            }

            w.writeLine("public init() {}")
        })
    }

    // Generate associated constants (Literal fields) as top-level named constants
    // prefixed with the struct name, since @C structs cannot have associated constants.
    var ki = fStart
    while (ki < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, ki)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            let constName = projectedConstantName(index, "${name}_${index.fieldName(fileIdx, ki)}", namespace)
            match (readFieldConstantLiteral(index, fileIdx, ki)) {
                case Some((constType, constValue)) =>
                    let cjType = cppConstantType(constType)
                    w.writeBlankLine()
                    writeAvailabilityForTags(w, feature, mergeCfgTagsLocal(typeTags, itemAvailabilityTags(TABLE_FIELD, fileIdx, ki)))
                    w.writeLine("public let ${escapeSourceIdentifier("${name}_${constName}")}: ${cjType} = ${constValue}")
                case None => ()
            }
        }
        ki += 1
    }

    // Walk nested rows from each unique (signature, arches) outer combination
    // so per-arch nested structs survive outer deduplication. Union signatures
    // collapse arch variants into a single key, so include arches in the dedup
    // to keep both arches' nested types reachable.
    let visitedKeys = HashSet<String>()
    visitedKeys.add("${structSignature}/${arches}")
    emitOuterNestedTypes(w, index, fileIdx, row, namespace, name, arches, typeTags, winrtProjection)
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.entriesForType(namespace, name)
            for (entry in entries) {
                if (entry.fileIdx == fileIdx && entry.row == row) {
                    continue
                }
                let entryArches = inheritArches(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row), parentArches)
                if (isUnsupportedOnlyArchitecture(entryArches)) {
                    continue
                }
                let entrySignature = buildStructSignature(index, entry.fileIdx, entry.row, name)
                if (shouldEmitStructRow(index, namespace, name, entry.fileIdx, entry.row, entrySignature)) {
                    continue
                }
                let entryKey = "${entrySignature}/${entryArches}"
                if (visitedKeys.contains(entryKey)) {
                    continue
                }
                visitedKeys.add(entryKey)
                let entryTypeTags = mergeTypeMapCfgTags(
                    parentTags,
                    mergedStructTypeAvailabilityTags(index, namespace, name, entry.fileIdx, entry.row, entrySignature,
                        parentArches)
                )
                emitOuterNestedTypes(w, index, entry.fileIdx, entry.row, namespace, name, entryArches, entryTypeTags,
                    winrtProjection)
            }
        case None => ()
    }
}

func emitOuterNestedTypes(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    outerName: String,
    parentArches: String,
    parentTags: ArrayList<String>,
    winrtProjection: Bool
): Unit {
    let nestedRows = index.getNested(fileIdx, row)
    for (innerRow in nestedRows) {
        let innerCategory = index.typeDefCategory(fileIdx, innerRow)
        let innerLeaf = nestedLeafName(index.typeDefName(fileIdx, innerRow))
        let nestedName = "${outerName}_${innerLeaf}"
        match (innerCategory) {
            case Struct => generateStructNamed(w, index, fileIdx, innerRow, namespace, nestedName, parentArches,
                parentTags, winrtProjection, true)
            case Enum => ()
            case _ => ()
        }
    }
}

public func shouldSkipSyntheticNestedStructEntry(index: TypeIndex, namespace: String, name: String): Bool {
    match (syntheticNestedStructOuterName(name)) {
        case Some(outerName) =>
            match (bindgenContext()) {
                case Some(context) =>
                    let entries = context.typeMap.entriesForType(namespace, outerName)
                    for (entry in entries) {
                        if (!isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row))) {
                            return true
                        }
                    }
                case None => ()
            }
        case None => ()
    }
    return false
}

func syntheticNestedStructOuterName(name: String): Option<String> {
    match (name.indexOf("__", 0)) {
        case Some(pos) =>
            if (pos <= 0) {
                return None
            }
            let arr = name.toArray()
            return Some(String.fromUtf8(arr[0..pos]))
        case None => return None
    }
}

func writeWinrtProjectionStruct(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    name: String,
    feature: String,
    typeTags: ArrayList<String>,
    nestedNames: HashMap<String, String>,
    fStart: Int64,
    fEnd: Int64
): Unit {
    let abiName = appendSourceIdentifierSuffix(name, "Abi")
    writeDeriveAttributes(w, namespace, name)
    w.writeBlock("public struct ${name}", { =>
        writeWinrtProjectionStructFields(w, index, fileIdx, row, fStart, fEnd, nestedNames)
        w.writeLine("public init() {}")
    })

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("@C")
    w.writeBlock("public struct ${abiName}", { =>
        writeWinrtAbiStructFields(w, index, fileIdx, row, fStart, fEnd, nestedNames)
        w.writeLine("public init() {}")
    })

    emitWinrtValueStructExtension(w, index, fileIdx, row, name, abiName, feature, typeTags, nestedNames, fStart, fEnd)
}

func writeWinrtProjectionStructFields(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    fStart: Int64,
    fEnd: Int64,
    nestedNames: HashMap<String, String>
): Unit {
    let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fi)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            fi += 1
            continue
        }

        let rawFieldName = sanitizeIdentifier(index.fieldName(fileIdx, fi))
        let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
        let publicType = winrtStructFieldPublicType(index, fileIdx, row, fieldType, nestedKeys)
        let defaultVal = winrtStructFieldPublicDefaultExpr(index, fileIdx, row, fieldType, nestedKeys, publicType)
        let fieldName = disambiguateFieldName(rawFieldName, publicType)
        let fieldTags = itemAvailabilityTags(TABLE_FIELD, fileIdx, fi)

        if (!fieldTags.isEmpty()) {
            writeAvailabilityForTags(w, "", fieldTags)
        }
        w.writeLine("public var ${fieldName}: ${publicType} = ${defaultVal}")
        fi += 1
    }
}

func writeWinrtAbiStructFields(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    fStart: Int64,
    fEnd: Int64,
    nestedNames: HashMap<String, String>
): Unit {
    let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fi)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            fi += 1
            continue
        }

        let rawFieldName = sanitizeIdentifier(index.fieldName(fileIdx, fi))
        let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
        let abiType = winrtStructFieldAbiType(index, fileIdx, row, fieldType, nestedKeys)
        let defaultVal = winrtStructFieldAbiDefaultExprForType(index, fileIdx, row, fieldType, nestedKeys, abiType)
        let fieldName = disambiguateFieldName(rawFieldName, abiType)
        let fieldTags = itemAvailabilityTags(TABLE_FIELD, fileIdx, fi)

        if (!fieldTags.isEmpty()) {
            writeAvailabilityForTags(w, "", fieldTags)
        }
        w.writeLine("public var ${fieldName}: ${abiType} = ${defaultVal}")
        fi += 1
    }
}

func winrtStructFieldPublicType(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>
): String {
    match (ty) {
        case MetadataType.MdArray(_) => return winrtStructFieldAbiType(index, fileIdx, scopeRow, ty, nestedKeys)
        case MetadataType.RefMut(_) => return winrtStructFieldAbiType(index, fileIdx, scopeRow, ty, nestedKeys)
        case MetadataType.RefConst(_) => return winrtStructFieldAbiType(index, fileIdx, scopeRow, ty, nestedKeys)
        case MetadataType.PtrMut(_, _) => return winrtStructFieldAbiType(index, fileIdx, scopeRow, ty, nestedKeys)
        case MetadataType.PtrConst(_, _) => return winrtStructFieldAbiType(index, fileIdx, scopeRow, ty, nestedKeys)
        case MetadataType.ArrayFixed(_, _) => return winrtStructFieldAbiType(index, fileIdx, scopeRow, ty, nestedKeys)
        case _ => return highLevelType(index, ty)
    }
}

func winrtStructFieldPublicDefaultExpr(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>,
    publicType: String
): String {
    if (isNativeDelegateStructFieldType(index, fileIdx, scopeRow, ty, nestedKeys)) {
        return cppDefaultValue(ty)
    }
    match (ty) {
        case MetadataType.MdArray(_) => return winrtStructFieldAbiDefaultExpr(publicType)
        case MetadataType.RefMut(_) => return winrtStructFieldAbiDefaultExpr(publicType)
        case MetadataType.RefConst(_) => return winrtStructFieldAbiDefaultExpr(publicType)
        case MetadataType.PtrMut(_, _) => return winrtStructFieldAbiDefaultExpr(publicType)
        case MetadataType.PtrConst(_, _) => return winrtStructFieldAbiDefaultExpr(publicType)
        case MetadataType.ArrayFixed(_, _) => return winrtStructFieldAbiDefaultExpr(publicType)
        case _ => return highLevelDefaultExpr(index, ty)
    }
}

func winrtStructFieldAbiType(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>
): String {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
                case Some((resolvedFileIdx, resolvedRow)) =>
                    match (index.typeDefCategory(resolvedFileIdx, resolvedRow)) {
                        case Delegate =>
                            if (!index.typeDefFlags(resolvedFileIdx, resolvedRow).contains(TypeAttributes.WindowsRuntime)) {
                                return highLevelType(index, ty)
                            }
                        case _ => ()
                    }
                case None =>
                    if (isNativeDelegateTypeName(index, typeName)) {
                        return highLevelType(index, ty)
                    }
            }
            return highLevelAbiType(index, ty)
        case MetadataType.ValueName(typeName) =>
            if (!typeName.namespace.isEmpty()) {
                if (isProjectedWinrtValueType(index, typeName)) {
                    return appendSourceIdentifierSuffix(highLevelType(index, ty), "Abi")
                }
                return highLevelAbiType(index, ty)
            }
            match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
                case Some((resolvedFileIdx, resolvedRow)) =>
                    if (typeDefUsesProjectedAbi(index, resolvedFileIdx, resolvedRow)) {
                        return appendSourceIdentifierSuffix(highLevelType(index, ty), "Abi")
                    }
                    return cppStructFieldStorageType(index, resolvedFileIdx, resolvedRow, ty, directNestedTypeKeyMap(index, resolvedFileIdx, resolvedRow))
                case None => return highLevelAbiType(index, ty)
            }
        case MetadataType.Union(typeName) =>
            if (!typeName.namespace.isEmpty()) {
                if (isProjectedWinrtValueType(index, typeName)) {
                    return appendSourceIdentifierSuffix(highLevelType(index, ty), "Abi")
                }
                return highLevelAbiType(index, ty)
            }
            match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
                case Some((resolvedFileIdx, resolvedRow)) =>
                    if (typeDefUsesProjectedAbi(index, resolvedFileIdx, resolvedRow)) {
                        return appendSourceIdentifierSuffix(highLevelType(index, ty), "Abi")
                    }
                    return cppStructFieldStorageType(index, resolvedFileIdx, resolvedRow, ty, directNestedTypeKeyMap(index, resolvedFileIdx, resolvedRow))
                case None => return highLevelAbiType(index, ty)
            }
        case MetadataType.MdArray(elem) =>
            return "CPointer<${winrtStructFieldAbiType(index, fileIdx, scopeRow, elem, nestedKeys)}>"
        case MetadataType.RefMut(inner) =>
            return "CPointer<${winrtStructFieldAbiType(index, fileIdx, scopeRow, inner, nestedKeys)}>"
        case MetadataType.RefConst(inner) =>
            return "CPointer<${winrtStructFieldAbiType(index, fileIdx, scopeRow, inner, nestedKeys)}>"
        case MetadataType.PtrMut(inner, depth) =>
            return wrapWinrtStructFieldAbiPointer(index, fileIdx, scopeRow, inner, depth, nestedKeys)
        case MetadataType.PtrConst(inner, depth) =>
            return wrapWinrtStructFieldAbiPointer(index, fileIdx, scopeRow, inner, depth, nestedKeys)
        case MetadataType.ArrayFixed(elem, size) =>
            if (isDelegateArrayMetadataType(elem)) {
                if (size == 1) {
                    return winrtStructFieldAbiType(index, fileIdx, scopeRow, elem, nestedKeys)
                }
                return "VArray<CPointer<Unit>, \$${size}>"
            }
            return "VArray<${winrtStructFieldAbiType(index, fileIdx, scopeRow, elem, nestedKeys)}, \$${size}>"
        case MetadataType.Packed(inner, _) =>
            return winrtStructFieldAbiType(index, fileIdx, scopeRow, inner, nestedKeys)
        case _ => return highLevelAbiType(index, ty)
    }
}

func wrapWinrtStructFieldAbiPointer(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    inner: MetadataType,
    depth: Int64,
    nestedKeys: HashMap<String, Int64>
): String {
    var result = winrtStructFieldAbiType(index, fileIdx, scopeRow, inner, nestedKeys)
    var d = depth
    while (d > 0) {
        result = "CPointer<${result}>"
        d -= 1
    }
    return result
}

func typeDefUsesProjectedAbi(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    match (index.typeDefCategory(fileIdx, row)) {
        case Enum => return true
        case Struct =>
            let flags = index.typeDefFlags(fileIdx, row)
            let layout = index.typeDefClassLayout(fileIdx, row)
            let isUnion = flags.contains(TypeAttributes.ExplicitLayout)
            let isPacked = match (layout) {
                case Some((packing, _)) => packing != 0u16 && packing != 8u16
                case None => false
            }
            return !isHandleType(index, fileIdx, row) && !isUnion && !isPacked
        case _ => return false
    }
}

func winrtStructFieldAbiDefaultExpr(abiType: String): String {
    return highLevelResultDefaultExpr(abiType)
}

func winrtStructFieldAbiDefaultExprForType(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>,
    abiType: String
): String {
    match (structFieldHandleAliasDefaultExpr(index, fileIdx, scopeRow, ty)) {
        case Some(defaultExpr) => return defaultExpr
        case None => ()
    }
    if (isNativeDelegateStructFieldType(index, fileIdx, scopeRow, ty, nestedKeys)) {
        return cppDefaultValue(ty)
    }
    return winrtStructFieldAbiDefaultExpr(abiType)
}

func structFieldHandleAliasDefaultExpr(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType
): Option<String> {
    let typeName = match (ty) {
        case MetadataType.ClassName(tn) => tn
        case MetadataType.ValueName(tn) => tn
        case MetadataType.Packed(inner, _) => return structFieldHandleAliasDefaultExpr(index, fileIdx, scopeRow, inner)
        case _ => return None
    }
    let resolvedTypeName = if (typeName.namespace.isEmpty()) {
        TypeName(index.typeDefNamespace(fileIdx, scopeRow), typeName.name, typeName.generics)
    } else {
        typeName
    }
    match (handleAliasUnderlyingType(index, resolvedTypeName)) {
        case Some(underlying) => return Some(highLevelResultDefaultExpr(underlying))
        case None => return None
    }
}

func isNativeDelegateStructFieldType(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>
): Bool {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            return isNativeDelegateStructFieldTypeName(index, fileIdx, scopeRow, typeName, nestedKeys)
        case MetadataType.ValueName(typeName) =>
            return isNativeDelegateStructFieldTypeName(index, fileIdx, scopeRow, typeName, nestedKeys)
        case MetadataType.Packed(inner, _) =>
            return isNativeDelegateStructFieldType(index, fileIdx, scopeRow, inner, nestedKeys)
        case MetadataType.ArrayFixed(inner, _) =>
            return isNativeDelegateStructFieldType(index, fileIdx, scopeRow, inner, nestedKeys)
        case _ => return false
    }
}

func isNativeDelegateStructFieldTypeName(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    typeName: TypeName,
    nestedKeys: HashMap<String, Int64>
): Bool {
    match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
        case Some((resolvedFileIdx, resolvedRow)) =>
            match (index.typeDefCategory(resolvedFileIdx, resolvedRow)) {
                case Delegate => return !index.typeDefFlags(resolvedFileIdx, resolvedRow).contains(TypeAttributes.WindowsRuntime)
                case _ => return false
            }
        case None => return isNativeDelegateTypeName(index, typeName)
    }
}

func isQualifiedProjectedSource(typeName: String): Bool {
    return splitString(typeName, b'.').size > 1
}

func winrtStructFieldProjectExpr(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>,
    expr: String,
    publicType: String,
    abiType: String
): String {
    let _ = fileIdx
    let _ = scopeRow
    let _ = nestedKeys
    if (publicType == abiType) {
        return expr
    }
    if (abiType == appendSourceIdentifierSuffix(publicType, "Abi")) {
        if (isQualifiedProjectedSource(publicType)) {
            return "windows_core.projectTypedAbi(${expr}, windows_core.typeMarker<${publicType}>())"
        }
        return "${publicType}.projectAbi(${expr})"
    }
    return highLevelArgumentExpr(index, ty, expr)
}

func winrtStructFieldReturnExpr(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>,
    expr: String,
    publicType: String,
    abiType: String
): String {
    let _ = fileIdx
    let _ = scopeRow
    let _ = nestedKeys
    if (publicType == abiType) {
        return expr
    }
    if (abiType == appendSourceIdentifierSuffix(publicType, "Abi")) {
        if (isQualifiedProjectedSource(publicType)) {
            return "windows_core.fromTypedAbi(${expr}, windows_core.typeMarker<${publicType}>()).unwrap()"
        }
        return "${publicType}.assumeInitRef(${expr})"
    }
    return highLevelReturnExpr(index, ty, expr)
}

func emitWinrtValueStructExtension(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    name: String,
    abiName: String,
    feature: String,
    typeTags: ArrayList<String>,
    nestedNames: HashMap<String, String>,
    fStart: Int64,
    fEnd: Int64
): Unit {
    useSupportSymbol("windows_core", "CopyType")
    useSupportSymbol("windows_core", "ProjectedCopyWinrtOutputBridge")
    useSupportSymbol("windows_core", "Result")
    useSupportSymbol("windows_core", "RuntimeType")
    useSupportSymbol("windows_core", "Type")
    useSupportSymbol("windows_core", "WinrtGenericType")
    useSupportSymbol("windows_core", "WinrtOutputBridge")
    useSupportSymbol("windows_core", "fromTypedAbi")
    useSupportSymbol("windows_core", "projectTypedAbi")
    useSupportSymbol("windows_core", "typeMarker")

    let runtimeSignature = structRuntimeSignature(index, fileIdx, row)
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeBlock(
        "extend ${name} <: windows_core.CopyType & windows_core.RuntimeType & windows_core.Type<${name}, ${abiName}, ${name}> & windows_core.WinrtGenericType<${name}>",
        { =>
            w.writeLine("public static func typeKind(): windows_core.TypeKind { windows_core.TypeKind.Copy }")
            w.writeLine("public static func abiType(): String { \"${abiName}\" }")
            w.writeLine("public static func signature(): String { \"${runtimeSignature}\" }")
            w.writeLine("public static func projectAbi(value: ${name}): ${abiName} {")
            w.writeLine("    var abi = ${abiName}()")
            let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
            var fi = fStart
            while (fi < fEnd) {
                let fieldFlags = index.fieldFlags(fileIdx, fi)
                if (!fieldFlags.contains(FieldAttributes.Literal)) {
                    let rawFieldName = sanitizeIdentifier(index.fieldName(fileIdx, fi))
                    let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
                    let publicType = winrtStructFieldPublicType(index, fileIdx, row, fieldType, nestedKeys)
                    let abiType = winrtStructFieldAbiType(index, fileIdx, row, fieldType, nestedKeys)
                    let publicFieldName = disambiguateFieldName(rawFieldName, publicType)
                    let abiFieldName = disambiguateFieldName(rawFieldName, abiType)
                    w.writeLine("    abi.${abiFieldName} = ${winrtStructFieldProjectExpr(index, fileIdx, row, fieldType, nestedKeys, "value.${publicFieldName}", publicType, abiType)}")
                }
                fi += 1
            }
            w.writeLine("    return abi")
            w.writeLine("}")
            w.writeLine("public static func assumeInitRef(abi: ${abiName}): ${name} {")
            w.writeLine("    var value = ${name}()")
            fi = fStart
            while (fi < fEnd) {
                let fieldFlags = index.fieldFlags(fileIdx, fi)
                if (!fieldFlags.contains(FieldAttributes.Literal)) {
                    let rawFieldName = sanitizeIdentifier(index.fieldName(fileIdx, fi))
                    let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
                    let publicType = winrtStructFieldPublicType(index, fileIdx, row, fieldType, nestedKeys)
                    let abiType = winrtStructFieldAbiType(index, fileIdx, row, fieldType, nestedKeys)
                    let publicFieldName = disambiguateFieldName(rawFieldName, publicType)
                    let abiFieldName = disambiguateFieldName(rawFieldName, abiType)
                    w.writeLine("    value.${publicFieldName} = ${winrtStructFieldReturnExpr(index, fileIdx, row, fieldType, nestedKeys, "abi.${abiFieldName}", publicType, abiType)}")
                }
                fi += 1
            }
            w.writeLine("    return value")
            w.writeLine("}")
            w.writeLine("public static func fromAbi(abi: ${abiName}): Result<${name}> { Result<${name}>.Ok(${name}.assumeInitRef(abi)) }")
            w.writeLine("public static func fromDefault(defaultValue: ${name}): Result<${name}> { Result<${name}>.Ok(defaultValue) }")
            w.writeLine("public static func winrtOutputBridge(): windows_core.WinrtOutputBridge<${name}> {")
            w.writeLine("    windows_core.ProjectedCopyWinrtOutputBridge<${name}, ${abiName}, ${name}>()")
            w.writeLine("}")
        }
    )
}

func shouldEmitStructRow(
    index: TypeIndex,
    namespace: String,
    name: String,
    fileIdx: Int64,
    row: Int64,
    structSignature: String
): Bool {
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.entriesForType(namespace, name)
            for (entry in entries) {
                if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row))) {
                    continue
                }
                if (buildStructSignature(index, entry.fileIdx, entry.row, name) != structSignature) {
                    continue
                }
                return entry.fileIdx == fileIdx && entry.row == row
            }
            return true
        case None =>
            return true
    }
}

func mergedStructTypeAvailabilityTags(
    index: TypeIndex,
    namespace: String,
    name: String,
    fileIdx: Int64,
    row: Int64,
    structSignature: String,
    parentArches: String
): ArrayList<String> {
    let result = ArrayList<String>()
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.entriesForType(namespace, name)
            for (entry in entries) {
                let entryArches = inheritArches(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row), parentArches)
                if (isUnsupportedOnlyArchitecture(entryArches)) {
                    continue
                }
                if (buildStructSignature(index, entry.fileIdx, entry.row, name) != structSignature) {
                    continue
                }
                let entryTags = typeAvailabilityTags(namespace, name, entry.fileIdx, entry.row, entryArches)
                for (tag in entryTags) {
                    var seen = false
                    for (existing in result) {
                        if (existing == tag) {
                            seen = true
                            break
                        }
                    }
                    if (!seen) {
                        result.add(tag)
                    }
                }
            }
        case None => ()
    }

    if (result.isEmpty()) {
        let effectiveArches = inheritArches(index.arches(TABLE_TYPE_DEF, fileIdx, row), parentArches)
        return typeAvailabilityTags(namespace, trimTick(index.typeDefName(fileIdx, row)), fileIdx, row, effectiveArches)
    }
    return result
}

// Propagate parent's architecture constraint to a nested type that has none of its own.
// If both have constraints, take the intersection. Empty/0/7 mask means "all architectures".
func inheritArches(ownArches: String, parentArches: String): String {
    let ownMask = parseInt64OrZero(ownArches)
    let parentMask = parseInt64OrZero(parentArches)
    let ownEffective = if (ownMask <= 0) { 7 } else { ownMask }
    let parentEffective = if (parentMask <= 0) { 7 } else { parentMask }
    let combined = ownEffective & parentEffective
    if (combined == 0) {
        if (parentMask > 0 && parentMask != 7) {
            return parentEffective.toString()
        }
        return "1"
    }
    if (combined == 7) {
        return ""
    }
    return combined.toString()
}

func buildStructSignature(index: TypeIndex, fileIdx: Int64, row: Int64, name: String): String {
    let flags = index.typeDefFlags(fileIdx, row)
    if (flags.contains(TypeAttributes.ExplicitLayout)) {
        return "union:${name}"
    }

    let nestedNames = directNestedTypeMap(index, fileIdx, row, name)
    let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
    let fields = ArrayList<String>()
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (!fieldFlags.contains(FieldAttributes.Literal)) {
            let fieldName = sanitizeIdentifier(index.fieldName(fileIdx, fieldRow))
            let fieldType = resolveNestedType(index.fieldType(fileIdx, fieldRow), nestedNames)
            fields.add("${fieldName}:${cppStructFieldStorageType(index, fileIdx, row, fieldType, nestedKeys)}")
        }
        fieldRow += 1
    }
    return joinStrings(fields, "|")
}

func mergeCfgTagsLocal(first: ArrayList<String>, second: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (value in first) {
        result.add(value)
    }
    for (value in second) {
        var seen = false
        for (existing in result) {
            if (existing == value) {
                seen = true
                break
            }
        }
        if (!seen) {
            result.add(value)
        }
    }
    return result
}

func directNestedTypeMap(index: TypeIndex, fileIdx: Int64, row: Int64, outerName: String): HashMap<String, String> {
    let result = HashMap<String, String>()
    let nestedRows = index.getNested(fileIdx, row)
    for (innerRow in nestedRows) {
        let leafName = nestedLeafName(index.typeDefName(fileIdx, innerRow))
        let nestedName = "${outerName}_${leafName}"
        result[leafName] = nestedName
    }
    return result
}

func nestedLeafName(name: String): String {
    let trimmed = trimTick(name)
    let parts = splitString(trimmed, b'/')
    if (!parts.isEmpty()) {
        return parts[parts.size - 1]
    }
    return trimmed
}

func resolveNestedType(ty: MetadataType, nestedNames: HashMap<String, String>): MetadataType {
    match (ty) {
        case MetadataType.ValueName(tn) =>
            let leaf = nestedLeafName(tn.name)
            if (tn.namespace.isEmpty() && nestedNames.contains(leaf)) {
                return MetadataType.ValueName(TypeName.named("", nestedNames[leaf]))
            }
            return ty
        case MetadataType.Union(tn) =>
            let leaf = nestedLeafName(tn.name)
            if (tn.namespace.isEmpty() && nestedNames.contains(leaf)) {
                return MetadataType.Union(TypeName.named("", nestedNames[leaf]))
            }
            return ty
        case MetadataType.MdArray(inner) =>
            return MetadataType.MdArray(resolveNestedType(inner, nestedNames))
        case MetadataType.RefMut(inner) =>
            return MetadataType.RefMut(resolveNestedType(inner, nestedNames))
        case MetadataType.RefConst(inner) =>
            return MetadataType.RefConst(resolveNestedType(inner, nestedNames))
        case MetadataType.PtrMut(inner, depth) =>
            return MetadataType.PtrMut(resolveNestedType(inner, nestedNames), depth)
        case MetadataType.PtrConst(inner, depth) =>
            return MetadataType.PtrConst(resolveNestedType(inner, nestedNames), depth)
        case MetadataType.ArrayFixed(inner, size) =>
            return MetadataType.ArrayFixed(resolveNestedType(inner, nestedNames), size)
        case MetadataType.Packed(inner, packing) =>
            return MetadataType.Packed(resolveNestedType(inner, nestedNames), packing)
        case _ => ty
    }
}

func computedUnionByteSize(index: TypeIndex, fileIdx: Int64, row: Int64): UInt32 {
    match (index.typeDefClassLayout(fileIdx, row)) {
        case Some((_, classSize)) =>
            if (classSize > 0u32) {
                return classSize
            }
        case None => ()
    }

    let visiting = HashMap<String, Bool>()
    match (computeTypeDefLayout(index, fileIdx, row, visiting)) {
        case Some((size, _)) => size
        case None => 0u32
    }
}

func computedUnionLayout(index: TypeIndex, fileIdx: Int64, row: Int64): (UInt32, UInt32) {
    let unionSize = computedUnionByteSize(index, fileIdx, row)
    let visiting = HashMap<String, Bool>()
    let unionAlign = match (computeTypeDefLayout(index, fileIdx, row, visiting)) {
        case Some((_, align)) =>
            if (align > 0u32) {
                align
            } else {
                1u32
            }
        case None => 1u32
    }
    return (unionSize, unionAlign)
}

func computeTypeDefLayout(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    visiting: HashMap<String, Bool>
): Option<(UInt32, UInt32)> {
    let key = layoutCacheKey(fileIdx, row)
    match (typeLayoutCacheGet(key)) {
        case Some(cached) => return Some(cached)
        case None => ()
    }
    if (missingTypeLayoutCacheHas(key)) {
        return None
    }
    if (visiting.contains(key) && visiting[key]) {
        return None
    }

    visiting[key] = true
    let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
    let result = computeTypeDefLayoutCore(index, fileIdx, row, nestedKeys, visiting)
    visiting[key] = false

    match (result) {
        case Some(layout) =>
            typeLayoutCachePut(key, layout)
            return Some(layout)
        case None =>
            missingTypeLayoutCachePut(key)
            return None
    }
}

func computeTypeDefLayoutCore(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    nestedKeys: HashMap<String, Int64>,
    visiting: HashMap<String, Bool>
): Option<(UInt32, UInt32)> {
    match (index.typeDefCategory(fileIdx, row)) {
        case Enum =>
            return computeMetadataTypeLayout(
                index,
                fileIdx,
                row,
                enumUnderlyingMetadataTypeLocal(index, fileIdx, row),
                nestedKeys,
                visiting
            )
        case _ => ()
    }

    let flags = index.typeDefFlags(fileIdx, row)
    let (packing, classSize) = classLayoutInfo(index, fileIdx, row)
    if (flags.contains(TypeAttributes.ExplicitLayout)) {
        return computeExplicitLayoutType(index, fileIdx, row, nestedKeys, packing, classSize, visiting)
    }
    return computeSequentialLayoutType(index, fileIdx, row, nestedKeys, packing, classSize, visiting)
}

func computeExplicitLayoutType(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    nestedKeys: HashMap<String, Int64>,
    packing: UInt32,
    classSize: UInt32,
    visiting: HashMap<String, Bool>
): Option<(UInt32, UInt32)> {
    var size = classSize
    var align = 1u32
    var sawKnownField = false
    var missingFieldLayout = false

    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fi)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            fi += 1
            continue
        }

        let offset = match (index.fieldLayout(fileIdx, fi)) {
            case Some(value) => value
            case None => 0u32
        }
        match (computeMetadataTypeLayout(index, fileIdx, row, index.fieldType(fileIdx, fi), nestedKeys, visiting)) {
            case Some((fieldSize, fieldAlign)) =>
                sawKnownField = true
                let fieldEnd = offset + fieldSize
                if (fieldEnd > size) {
                    size = fieldEnd
                }
                let effectiveAlign = applyPacking(fieldAlign, packing)
                if (effectiveAlign > align) {
                    align = effectiveAlign
                }
            case None =>
                missingFieldLayout = true
        }

        fi += 1
    }

    if (size > 0u32) {
        return Some((size, align))
    }
    if (sawKnownField && !missingFieldLayout) {
        return Some((0u32, align))
    }
    return None
}

func computeSequentialLayoutType(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    nestedKeys: HashMap<String, Int64>,
    packing: UInt32,
    classSize: UInt32,
    visiting: HashMap<String, Bool>
): Option<(UInt32, UInt32)> {
    var offset = 0u32
    var align = 1u32
    var sawKnownField = false
    var missingFieldLayout = false

    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fi)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            fi += 1
            continue
        }

        match (computeMetadataTypeLayout(index, fileIdx, row, index.fieldType(fileIdx, fi), nestedKeys, visiting)) {
            case Some((fieldSize, fieldAlign)) =>
                sawKnownField = true
                let effectiveAlign = applyPacking(fieldAlign, packing)
                offset = roundUpUInt32(offset, effectiveAlign)
                offset += fieldSize
                if (effectiveAlign > align) {
                    align = effectiveAlign
                }
            case None =>
                missingFieldLayout = true
        }

        fi += 1
    }

    var size = if (offset > 0u32) {
        roundUpUInt32(offset, align)
    } else {
        0u32
    }
    if (classSize > size) {
        size = classSize
    }

    if (size > 0u32) {
        return Some((size, align))
    }
    if (sawKnownField && !missingFieldLayout) {
        return Some((0u32, align))
    }
    return None
}

func computeMetadataTypeLayout(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>,
    visiting: HashMap<String, Bool>
): Option<(UInt32, UInt32)> {
    match (ty) {
        case MetadataType.Boolean => return Some((1u32, 1u32))
        case MetadataType.I8 => return Some((1u32, 1u32))
        case MetadataType.U8 => return Some((1u32, 1u32))
        case MetadataType.I16 => return Some((2u32, 2u32))
        case MetadataType.U16 => return Some((2u32, 2u32))
        case MetadataType.Char => return Some((2u32, 2u32))
        case MetadataType.I32 => return Some((4u32, 4u32))
        case MetadataType.U32 => return Some((4u32, 4u32))
        case MetadataType.F32 => return Some((4u32, 4u32))
        case MetadataType.I64 => return Some((8u32, 8u32))
        case MetadataType.U64 => return Some((8u32, 8u32))
        case MetadataType.F64 => return Some((8u32, 8u32))
        case MetadataType.ISize => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.USize => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.MdString => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.MdObject => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.MdArray(_) => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.Generic(_, _) => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.RefMut(_) => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.RefConst(_) => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.PtrMut(_, _) => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.PtrConst(_, _) => return Some((nativePointerSize(), nativePointerSize()))
        case MetadataType.ArrayFixed(inner, count) =>
            if (count <= 0) {
                return Some((0u32, 1u32))
            }
            match (computeMetadataTypeLayout(index, fileIdx, scopeRow, inner, nestedKeys, visiting)) {
                case Some((elemSize, elemAlign)) =>
                    return Some((UInt32(UInt64(elemSize) * UInt64(count)), elemAlign))
                case None =>
                    return None
            }
        case MetadataType.Packed(inner, packing) =>
            match (computeMetadataTypeLayout(index, fileIdx, scopeRow, inner, nestedKeys, visiting)) {
                case Some((innerSize, innerAlign)) =>
                    return Some((innerSize, applyPacking(innerAlign, UInt32(packing))))
                case None =>
                    return None
            }
        case MetadataType.ClassName(typeName) =>
            return computeNamedMetadataTypeLayout(index, fileIdx, scopeRow, typeName, nestedKeys, true, visiting)
        case MetadataType.ValueName(typeName) =>
            return computeNamedMetadataTypeLayout(index, fileIdx, scopeRow, typeName, nestedKeys, false, visiting)
        case MetadataType.Union(typeName) =>
            return computeNamedMetadataTypeLayout(index, fileIdx, scopeRow, typeName, nestedKeys, false, visiting)
        case _ =>
            return None
    }
}

func computeNamedMetadataTypeLayout(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    typeName: TypeName,
    nestedKeys: HashMap<String, Int64>,
    preferPointer: Bool,
    visiting: HashMap<String, Bool>
): Option<(UInt32, UInt32)> {
    let resolved = resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)
    match (resolved) {
        case Some((resolvedFileIdx, resolvedRow)) =>
            let category = index.typeDefCategory(resolvedFileIdx, resolvedRow)
            match (category) {
                case Class => return Some((nativePointerSize(), nativePointerSize()))
                case Interface => return Some((nativePointerSize(), nativePointerSize()))
                case Delegate => return Some((nativePointerSize(), nativePointerSize()))
                case _ => ()
            }
            return computeTypeDefLayout(index, resolvedFileIdx, resolvedRow, visiting)
        case None =>
            if (preferPointer) {
                return Some((nativePointerSize(), nativePointerSize()))
            }
            return fallbackNamedMetadataTypeLayout(typeName)
    }
}

func fallbackNamedMetadataTypeLayout(typeName: TypeName): Option<(UInt32, UInt32)> {
    let leaf = trimTick(typeName.name)
    if ((typeName.namespace == "System" && leaf == "Guid") || leaf == "GUID") {
        return Some((16u32, 4u32))
    }

    let resolved = cppType(MetadataType.ValueName(typeName))
    if (resolved == "Bool" || resolved == "Int8" || resolved == "UInt8") {
        return Some((1u32, 1u32))
    }
    if (resolved == "Int16" || resolved == "UInt16") {
        return Some((2u32, 2u32))
    }
    if (resolved == "Int32" || resolved == "UInt32" || resolved == "Float32") {
        return Some((4u32, 4u32))
    }
    if (resolved == "Int64" || resolved == "UInt64" || resolved == "Float64") {
        return Some((8u32, 8u32))
    }
    if (resolved == "IntNative" || resolved == "UIntNative" || isPointerCjType(resolved)) {
        return Some((nativePointerSize(), nativePointerSize()))
    }
    return None
}

func resolveTypeDefKey(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    typeName: TypeName,
    nestedKeys: HashMap<String, Int64>
): Option<(Int64, Int64)> {
    let leaf = nestedLeafName(typeName.name)
    if (typeName.namespace.isEmpty()) {
        if (nestedKeys.contains(leaf)) {
            return Some((fileIdx, nestedKeys[leaf]))
        }
        let requested = trimTick(typeName.name)
        for ((nestedLeaf, nestedRow) in nestedKeys) {
            if (requested == nestedLeaf || requested.endsWith("_${nestedLeaf}")) {
                return Some((fileIdx, nestedRow))
            }
        }
        let scopeNested = directNestedTypeKeyMap(index, fileIdx, scopeRow)
        if (scopeNested.contains(leaf)) {
            return Some((fileIdx, scopeNested[leaf]))
        }
        for ((nestedLeaf, nestedRow) in scopeNested) {
            if (requested == nestedLeaf || requested.endsWith("_${nestedLeaf}")) {
                return Some((fileIdx, nestedRow))
            }
        }
        let ownerNamespace = index.typeDefNamespace(fileIdx, scopeRow)
        if (!ownerNamespace.isEmpty()) {
            let candidates = index.get(ownerNamespace, requested)
            for ((candidateFileIdx, candidateRow) in candidates) {
                if (candidateFileIdx == fileIdx) {
                    return Some((candidateFileIdx, candidateRow))
                }
            }
            if (!candidates.isEmpty()) {
                return Some(candidates[0])
            }
        }
        return None
    }

    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return None
    }

    for ((candidateFileIdx, candidateRow) in candidates) {
        if (candidateFileIdx == fileIdx) {
            return Some((candidateFileIdx, candidateRow))
        }
    }
    return Some(candidates[0])
}

func directNestedTypeKeyMap(index: TypeIndex, fileIdx: Int64, row: Int64): HashMap<String, Int64> {
    let result = HashMap<String, Int64>()
    let nestedRows = index.getNested(fileIdx, row)
    for (innerRow in nestedRows) {
        let leafName = nestedLeafName(index.typeDefName(fileIdx, innerRow))
        result[leafName] = innerRow
    }
    return result
}

func cppStructFieldStorageType(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>
): String {
    match (ty) {
        case MetadataType.ValueName(typeName) =>
            match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
                case Some((resolvedFileIdx, resolvedRow)) =>
                    match (index.typeDefCategory(resolvedFileIdx, resolvedRow)) {
                        case Enum =>
                            return cppStructFieldStorageType(
                                index,
                                resolvedFileIdx,
                                resolvedRow,
                                enumUnderlyingMetadataTypeLocal(index, resolvedFileIdx, resolvedRow),
                                directNestedTypeKeyMap(index, resolvedFileIdx, resolvedRow)
                            )
                        case _ =>
                            return cppType(ty)
                    }
                case None =>
                    return cppType(ty)
            }
        case MetadataType.MdArray(elem) =>
            return "CPointer<${cppStructFieldStorageType(index, fileIdx, scopeRow, elem, nestedKeys)}>"
        case MetadataType.RefMut(inner) =>
            return "CPointer<${cppStructFieldStorageType(index, fileIdx, scopeRow, inner, nestedKeys)}>"
        case MetadataType.RefConst(inner) =>
            return "CPointer<${cppStructFieldStorageType(index, fileIdx, scopeRow, inner, nestedKeys)}>"
        case MetadataType.PtrMut(inner, depth) =>
            return wrapStructFieldStoragePointer(index, fileIdx, scopeRow, inner, depth, nestedKeys)
        case MetadataType.PtrConst(inner, depth) =>
            return wrapStructFieldStoragePointer(index, fileIdx, scopeRow, inner, depth, nestedKeys)
        case MetadataType.ArrayFixed(elem, size) =>
            if (isDelegateArrayMetadataType(elem)) {
                if (size == 1) {
                    return cppStructFieldStorageType(index, fileIdx, scopeRow, elem, nestedKeys)
                }
                return "VArray<CPointer<Unit>, \$${size}>"
            }
            return "VArray<${cppStructFieldStorageType(index, fileIdx, scopeRow, elem, nestedKeys)}, \$${size}>"
        case MetadataType.Packed(inner, _) =>
            return cppStructFieldStorageType(index, fileIdx, scopeRow, inner, nestedKeys)
        case _ =>
            return cppType(ty)
    }
}

func cppStructFieldStorageDefaultValue(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    ty: MetadataType,
    nestedKeys: HashMap<String, Int64>
): String {
    match (ty) {
        case MetadataType.ValueName(typeName) =>
            match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
                case Some((resolvedFileIdx, resolvedRow)) =>
                    match (index.typeDefCategory(resolvedFileIdx, resolvedRow)) {
                        case Enum =>
                            return cppStructFieldStorageDefaultValue(
                                index,
                                resolvedFileIdx,
                                resolvedRow,
                                enumUnderlyingMetadataTypeLocal(index, resolvedFileIdx, resolvedRow),
                                directNestedTypeKeyMap(index, resolvedFileIdx, resolvedRow)
                            )
                        case _ =>
                            return cppDefaultValue(ty)
                    }
                case None =>
                    return cppDefaultValue(ty)
            }
        case MetadataType.MdArray(_) =>
            return "${cppStructFieldStorageType(index, fileIdx, scopeRow, ty, nestedKeys)}()"
        case MetadataType.RefMut(_) =>
            return "${cppStructFieldStorageType(index, fileIdx, scopeRow, ty, nestedKeys)}()"
        case MetadataType.RefConst(_) =>
            return "${cppStructFieldStorageType(index, fileIdx, scopeRow, ty, nestedKeys)}()"
        case MetadataType.PtrMut(_, _) =>
            return "${cppStructFieldStorageType(index, fileIdx, scopeRow, ty, nestedKeys)}()"
        case MetadataType.PtrConst(_, _) =>
            return "${cppStructFieldStorageType(index, fileIdx, scopeRow, ty, nestedKeys)}()"
        case MetadataType.ArrayFixed(elem, size) =>
            if (isDelegateArrayMetadataType(elem)) {
                if (size == 1) {
                    return cppStructFieldStorageDefaultValue(index, fileIdx, scopeRow, elem, nestedKeys)
                }
                return "VArray<CPointer<Unit>, \$${size}>(repeat: CPointer<Unit>())"
            }
            return "VArray<${cppStructFieldStorageType(index, fileIdx, scopeRow, elem, nestedKeys)}, \$${size}>(repeat: ${cppStructFieldStorageDefaultValue(index, fileIdx, scopeRow, elem, nestedKeys)})"
        case MetadataType.Packed(inner, _) =>
            return cppStructFieldStorageDefaultValue(index, fileIdx, scopeRow, inner, nestedKeys)
        case _ =>
            return cppDefaultValue(ty)
    }
}

func wrapStructFieldStoragePointer(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    inner: MetadataType,
    depth: Int64,
    nestedKeys: HashMap<String, Int64>
): String {
    var result = cppStructFieldStorageType(index, fileIdx, scopeRow, inner, nestedKeys)
    var d = depth
    while (d > 0) {
        result = "CPointer<${result}>"
        d -= 1
    }
    return result
}

func enumUnderlyingMetadataTypeLocal(index: TypeIndex, fileIdx: Int64, row: Int64): MetadataType {
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        if (index.fieldName(fileIdx, fieldRow) == "value__") {
            return index.fieldType(fileIdx, fieldRow)
        }
        fieldRow += 1
    }
    return MetadataType.I32
}

func classLayoutInfo(index: TypeIndex, fileIdx: Int64, row: Int64): (UInt32, UInt32) {
    match (index.typeDefClassLayout(fileIdx, row)) {
        case Some((packing, classSize)) =>
            return (UInt32(packing), classSize)
        case None =>
            return (0u32, 0u32)
    }
}

func nativePointerSize(): UInt32 {
    return 8u32
}

func unionRawStorageSpec(unionSize: UInt32, unionAlign: UInt32): (String, UInt32) {
    if (unionSize == 0u32) {
        return ("UInt8", 0u32)
    }

    // Preserve the union's native alignment in the raw storage type whenever
    // the computed ClassLayout size allows an exact-sized VArray. Accessors
    // still reinterpret the backing storage as bytes when reading/writing.
    if (unionAlign >= 8u32 && unionSize % 8u32 == 0u32) {
        return ("UInt64", unionSize / 8u32)
    }
    if (unionAlign >= 4u32 && unionSize % 4u32 == 0u32) {
        return ("UInt32", unionSize / 4u32)
    }
    if (unionAlign >= 2u32 && unionSize % 2u32 == 0u32) {
        return ("UInt16", unionSize / 2u32)
    }
    return ("UInt8", unionSize)
}

func applyPacking(align: UInt32, packing: UInt32): UInt32 {
    if (align == 0u32) {
        return 1u32
    }
    if (packing > 0u32 && packing < align) {
        return packing
    }
    return align
}

func roundUpUInt32(value: UInt32, align: UInt32): UInt32 {
    if (align <= 1u32) {
        return value
    }
    let rounded = value + align - 1u32
    return (rounded / align) * align
}

func layoutCacheKey(fileIdx: Int64, row: Int64): String {
    return "${fileIdx}:${row}"
}

func writeUnionStructBody(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    nestedNames: HashMap<String, String>,
    unionSize: UInt32,
    unionRawElemType: String,
    unionRawLen: UInt32,
    winrtProjection: Bool
): Unit {
    if (unionSize == 0u32) {
        return
    }

    w.writeLine("public var _raw: VArray<${unionRawElemType}, \$${unionRawLen}> = VArray<${unionRawElemType}, \$${unionRawLen}>(repeat: 0)")

    let accessorCounts = HashMap<String, Int64>()
    let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fi)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            fi += 1
            continue
        }

        match (index.fieldLayout(fileIdx, fi)) {
            case Some(offset) =>
                let rawFieldType = index.fieldType(fileIdx, fi)
                let fieldType = resolveNestedType(rawFieldType, nestedNames)
                let fieldTags = mergeAccessorCfgTags(
                    itemAvailabilityTags(TABLE_FIELD, fileIdx, fi),
                    nestedFieldArchTags(index, fileIdx, row, rawFieldType))
                let accessorName = uniqueUnionAccessorName(accessorCounts, index.fieldName(fileIdx, fi))
                match (enumBinaryAccessorInfo(index, fileIdx, row, fieldType, nestedKeys)) {
                    case Some((enumType, underlyingCjType)) =>
                        if (offset < unionSize) {
                            w.writeBlankLine()
                            writeUnionEnumAccessor(w, accessorName, enumType, underlyingCjType, offset, fieldTags)
                        }
                    case None =>
                        let fieldCjType = if (winrtProjection) {
                            winrtStructFieldPublicType(index, fileIdx, row, fieldType, nestedKeys)
                        } else {
                            cppType(fieldType)
                        }
                        let fieldAbiType = if (winrtProjection) {
                            winrtStructFieldAbiType(index, fileIdx, row, fieldType, nestedKeys)
                        } else {
                            fieldCjType
                        }
                        if (canEmitUnionAccessor(index, fileIdx, row, nestedKeys, fieldType, fieldCjType) && offset < unionSize) {
                            w.writeBlankLine()
                            writeUnionAccessor(w, accessorName, fieldCjType, fieldAbiType, offset, unionRawElemType,
                                fieldTags)
                        }
                }
            case None => ()
        }

        fi += 1
    }
}

func unionAccessorAbiType(index: TypeIndex, fieldType: MetadataType, fieldCjType: String, winrtProjection: Bool): String {
    if (!winrtProjection) {
        return fieldCjType
    }

    let abiType = highLevelAbiType(index, fieldType)
    if (abiType != fieldCjType) {
        return abiType
    }
    return fieldCjType
}

// Resolve a union accessor's arch tag. The field type may reference a
// `nested` typedef under the same parent (winmd `NestedClass` table); look it
// up by inner name and inherit the parent's arch when the nested type
// itself carries no SupportedArchitecture attribute.
func nestedFieldArchTags(
    index: TypeIndex,
    parentFileIdx: Int64,
    parentRow: Int64,
    rawFieldType: MetadataType
): ArrayList<String> {
    let typeName = match (rawFieldType) {
        case ValueName(tn) => tn
        case ClassName(tn) => tn
        case Union(tn) => tn
        case Packed(inner, _) => return nestedFieldArchTags(index, parentFileIdx, parentRow, inner)
        case _ => return ArrayList<String>()
    }
    let leaf = trimTick(typeName.name)
    if (typeName.namespace.isEmpty()) {
        for (innerRow in index.getNested(parentFileIdx, parentRow)) {
            if (nestedLeafName(index.typeDefName(parentFileIdx, innerRow)) == leaf) {
                let inherited = inheritArches(
                    index.arches(TABLE_TYPE_DEF, parentFileIdx, innerRow),
                    index.arches(TABLE_TYPE_DEF, parentFileIdx, parentRow))
                return architectureCfgTags(inherited)
            }
        }
        return ArrayList<String>()
    }
    return unionFieldTypeArchTags(index, rawFieldType)
}

// When a union slot points at a nested struct that is arch-gated, propagate
// the arch tag onto the accessor itself; otherwise the accessor body would
// reference a type that the current arch did not emit.
func unionFieldTypeArchTags(index: TypeIndex, fieldType: MetadataType): ArrayList<String> {
    let result = ArrayList<String>()
    let typeName = match (fieldType) {
        case ValueName(tn) => tn
        case ClassName(tn) => tn
        case Union(tn) => tn
        case Packed(inner, _) => return unionFieldTypeArchTags(index, inner)
        case _ => return result
    }
    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return result
    }
    let (fi, ri) = candidates[0]
    return architectureCfgTags(index.arches(TABLE_TYPE_DEF, fi, ri))
}

func mergeAccessorCfgTags(first: ArrayList<String>, second: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (value in first) {
        result.add(value)
    }
    for (value in second) {
        var seen = false
        for (existing in result) {
            if (existing == value) {
                seen = true
                break
            }
        }
        if (!seen) {
            result.add(value)
        }
    }
    return result
}

func canEmitNamedBinaryAccessor(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    nestedKeys: HashMap<String, Int64>,
    typeName: TypeName,
    preferPointer: Bool
): Bool {
    match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
        case Some((resolvedFileIdx, resolvedRow)) =>
            match (index.typeDefCategory(resolvedFileIdx, resolvedRow)) {
                // Delegates project to CFunc aliases, so they are raw function
                // pointers and remain safe to read/write by value in packed or
                // union storage.
                case Delegate => return true
                case Class => return false
                case Interface => return false
                case _ => return true
            }
        case None =>
            if (preferPointer) {
                return false
            }
            match (fallbackNamedMetadataTypeLayout(typeName)) {
                case Some(_) => return true
                case None => return false
            }
    }
}

func canEmitUnionAccessor(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    nestedKeys: HashMap<String, Int64>,
    fieldType: MetadataType,
    fieldCjType: String
): Bool {
    if (fieldCjType == "Unit") {
        return false
    }

    if (isPrimitiveCjType(fieldCjType) ||
        isPointerCjType(fieldCjType) ||
        fieldCjType.startsWith("VArray<")) {
        return true
    }

    match (fieldType) {
        case MetadataType.ClassName(typeName) =>
            return canEmitNamedBinaryAccessor(index, fileIdx, scopeRow, nestedKeys, typeName, true)
        case MetadataType.ValueName(_) => true
        case MetadataType.Union(_) => true
        case MetadataType.Packed(inner, _) =>
            return canEmitUnionAccessor(index, fileIdx, scopeRow, nestedKeys, inner, fieldCjType)
        case _ => false
    }
}

// Packed/union accessors should expose enum wrapper types at the API surface,
// but read/write their primitive ABI storage underneath.
func enumBinaryAccessorInfo(
    index: TypeIndex,
    fileIdx: Int64,
    scopeRow: Int64,
    fieldType: MetadataType,
    nestedKeys: HashMap<String, Int64>
): Option<(String, String)> {
    match (fieldType) {
        case MetadataType.ValueName(typeName) =>
            match (resolveTypeDefKey(index, fileIdx, scopeRow, typeName, nestedKeys)) {
                case Some((resolvedFileIdx, resolvedRow)) =>
                    match (index.typeDefCategory(resolvedFileIdx, resolvedRow)) {
                        case Enum =>
                            let underlying = enumUnderlyingMetadataTypeLocal(index, resolvedFileIdx, resolvedRow)
                            return Some((metadataTypeToCj(fieldType), cppType(underlying)))
                        case _ => ()
                    }
                case None =>
                    match (enumUnderlyingMetadataType(typeName)) {
                        case Some(underlying) =>
                            return Some((metadataTypeToCj(fieldType), cppType(underlying)))
                        case None => ()
                    }
            }
            return None
        case MetadataType.Packed(inner, _) =>
            return enumBinaryAccessorInfo(index, fileIdx, scopeRow, inner, nestedKeys)
        case _ =>
            return None
    }
}

func uniqueUnionAccessorName(accessorCounts: HashMap<String, Int64>, rawFieldName: String): String {
    let baseName = sanitizeIdentifier(lowerCamelIdentifier(sanitizeIdentifier(rawFieldName)))
    if (!accessorCounts.contains(baseName)) {
        accessorCounts[baseName] = 1
        return baseName
    }

    accessorCounts[baseName] = accessorCounts[baseName] + 1
    return sanitizeIdentifier("${baseName}${accessorCounts[baseName]}")
}

func lowerCamelIdentifier(value: String): String {
    if (value.isEmpty()) {
        return value
    }

    let arr = value.toArray()
    let len = Int64(arr.size)
    let bytes = ArrayList<Byte>()

    if (len == 1) {
        let only = arr[0]
        if (only >= b'A' && only <= b'Z') {
            bytes.add(only - b'A' + b'a')
        } else {
            bytes.add(only)
        }
        return byteListToString(bytes)
    }

    var prefixEnd: Int64 = 1
    while (prefixEnd < len &&
        arr[prefixEnd] >= b'A' &&
        arr[prefixEnd] <= b'Z' &&
        !(prefixEnd + 1 < len && arr[prefixEnd + 1] >= b'a' && arr[prefixEnd + 1] <= b'z')) {
        prefixEnd += 1
    }

    var i: Int64 = 0
    while (i < len) {
        let ch = arr[i]
        if ((i < prefixEnd || i == 0) && ch >= b'A' && ch <= b'Z') {
            bytes.add(ch - b'A' + b'a')
        } else {
            bytes.add(ch)
        }
        i += 1
    }

    return byteListToString(bytes)
}

// Map a Cangjie primitive type to the polyfill read function name.
// Returns empty string for non-primitive types (use generic pointer-cast fallback).
func polyfillUnionAccessorName(cjType: String): String {
    if (cjType == "UInt8") { return "unionReadUInt8" }
    if (cjType == "Int8") { return "unionReadInt8" }
    if (cjType == "UInt16") { return "unionReadUInt16" }
    if (cjType == "Int16") { return "unionReadInt16" }
    if (cjType == "UInt32") { return "unionReadUInt32" }
    if (cjType == "Int32") { return "unionReadInt32" }
    if (cjType == "UInt64") { return "unionReadUInt64" }
    if (cjType == "Int64") { return "unionReadInt64" }
    if (cjType == "Float32") { return "unionReadFloat32" }
    if (cjType == "Float64") { return "unionReadFloat64" }
    return ""
}

// Map a Cangjie primitive type to the polyfill read function name for packed fields.
// Returns empty string for non-primitive types.
func polyfillPackedAccessorName(cjType: String): String {
    if (cjType == "UInt8") { return "packedReadUInt8" }
    if (cjType == "Int8") { return "packedReadInt8" }
    if (cjType == "UInt16") { return "packedReadUInt16" }
    if (cjType == "Int16") { return "packedReadInt16" }
    if (cjType == "UInt32") { return "packedReadUInt32" }
    if (cjType == "Int32") { return "packedReadInt32" }
    if (cjType == "UInt64") { return "packedReadUInt64" }
    if (cjType == "Int64") { return "packedReadInt64" }
    if (cjType == "UIntNative") { return "packedReadUIntNative" }
    if (cjType == "IntNative") { return "packedReadIntNative" }
    if (cjType == "Float32") { return "packedReadFloat32" }
    if (cjType == "Float64") { return "packedReadFloat64" }
    return ""
}

// Map a polyfill read function name to the corresponding write function name.
// Handles both "unionReadXxx" → "unionWriteXxx" and "packedReadXxx" → "packedWriteXxx".
func polyfillWriteFnName(readFn: String): String {
    if (readFn == "unionReadUInt8")   { return "unionWriteUInt8" }
    if (readFn == "unionReadInt8")    { return "unionWriteInt8" }
    if (readFn == "unionReadUInt16")  { return "unionWriteUInt16" }
    if (readFn == "unionReadInt16")   { return "unionWriteInt16" }
    if (readFn == "unionReadUInt32")  { return "unionWriteUInt32" }
    if (readFn == "unionReadInt32")   { return "unionWriteInt32" }
    if (readFn == "unionReadUInt64")  { return "unionWriteUInt64" }
    if (readFn == "unionReadInt64")   { return "unionWriteInt64" }
    if (readFn == "unionReadFloat32") { return "unionWriteFloat32" }
    if (readFn == "unionReadFloat64") { return "unionWriteFloat64" }
    if (readFn == "packedReadUInt8")   { return "packedWriteUInt8" }
    if (readFn == "packedReadInt8")    { return "packedWriteInt8" }
    if (readFn == "packedReadUInt16")  { return "packedWriteUInt16" }
    if (readFn == "packedReadInt16")   { return "packedWriteInt16" }
    if (readFn == "packedReadUInt32")  { return "packedWriteUInt32" }
    if (readFn == "packedReadInt32")   { return "packedWriteInt32" }
    if (readFn == "packedReadUInt64")  { return "packedWriteUInt64" }
    if (readFn == "packedReadInt64")   { return "packedWriteInt64" }
    if (readFn == "packedReadUIntNative") { return "packedWriteUIntNative" }
    if (readFn == "packedReadIntNative")  { return "packedWriteIntNative" }
    if (readFn == "packedReadFloat32") { return "packedWriteFloat32" }
    if (readFn == "packedReadFloat64") { return "packedWriteFloat64" }
    return readFn  // fallback: return unchanged (should not happen)
}

// Generic fallback for union accessors when field type is not a primitive.
// Uses pointer-cast approach on the UInt8 byte array storage.
func writeUnionAccessorGeneric(
    w: CodeWriter,
    accessorName: String,
    fieldCjType: String,
    fieldAbiType: String,
    offset: UInt32,
    fieldTags: ArrayList<String>
): Unit {
    if (!fieldTags.isEmpty()) {
        writeAvailabilityForTags(w, "", fieldTags)
    }
    w.writeBlock("public mut prop ${accessorName}: ${fieldCjType}", {=>
        w.writeBlock("get()", {=>
            w.writeLine("unsafe {")
            w.indent()
            w.writeLine("var rawStorage = _raw")
            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
            if (offset > 0u32) {
                w.writeLine("let p = base + Int64(${offset})")
            } else {
                w.writeLine("let p = base")
            }
            w.writeLine("let ptr = CPointer<${fieldAbiType}>(p)")
            if (fieldAbiType == fieldCjType) {
                w.writeLine("return ptr.read()")
            } else {
                w.writeLine("let raw = ptr.read()")
                if (fieldAbiType == appendSourceIdentifierSuffix(fieldCjType, "Abi") && isQualifiedProjectedSource(fieldCjType)) {
                    useSupportSymbol("windows_core", "fromTypedAbi")
                    useSupportSymbol("windows_core", "typeMarker")
                    w.writeLine("return windows_core.fromTypedAbi(raw, windows_core.typeMarker<${fieldCjType}>()).unwrap()")
                } else {
                    w.writeLine("return ${fieldCjType}.assumeInitRef(raw)")
                }
            }
            w.dedent()
            w.writeLine("}")
        })
        w.writeBlock("set(val)", {=>
            w.writeLine("unsafe {")
            w.indent()
            w.writeLine("var rawStorage = _raw")
            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
            if (offset > 0u32) {
                w.writeLine("let p = base + Int64(${offset})")
            } else {
                w.writeLine("let p = base")
            }
            w.writeLine("let ptr = CPointer<${fieldAbiType}>(p)")
            if (fieldAbiType == fieldCjType) {
                w.writeLine("ptr.write(val)")
            } else {
                if (fieldAbiType == appendSourceIdentifierSuffix(fieldCjType, "Abi") && isQualifiedProjectedSource(fieldCjType)) {
                    useSupportSymbol("windows_core", "projectTypedAbi")
                    useSupportSymbol("windows_core", "typeMarker")
                    w.writeLine("ptr.write(windows_core.projectTypedAbi(val, windows_core.typeMarker<${fieldCjType}>()))")
                } else {
                    w.writeLine("ptr.write(${fieldCjType}.projectAbi(val))")
                }
            }
            w.writeLine("_raw = rawStorage")
            w.dedent()
            w.writeLine("}")
        })
    })
}

func writeUnionEnumAccessor(
    w: CodeWriter,
    accessorName: String,
    enumType: String,
    underlyingCjType: String,
    offset: UInt32,
    fieldTags: ArrayList<String>
): Unit {
    let polyfillFn = polyfillUnionAccessorName(underlyingCjType)
    let writeFn = if (polyfillFn.isEmpty()) {
        ""
    } else {
        polyfillWriteFnName(polyfillFn)
    }
    if (!polyfillFn.isEmpty()) {
        useSupportSymbol("windows_polyfill", polyfillFn)
        useSupportSymbol("windows_polyfill", writeFn)
    }

    if (!fieldTags.isEmpty()) {
        writeAvailabilityForTags(w, "", fieldTags)
    }
    w.writeBlock("public mut prop ${accessorName}: ${enumType}", {=>
        w.writeBlock("get()", {=>
            w.writeLine("unsafe {")
            w.indent()
            w.writeLine("var rawStorage = _raw")
            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
            if (polyfillFn.isEmpty()) {
                if (offset > 0u32) {
                    w.writeLine("let p = base + Int64(${offset})")
                } else {
                    w.writeLine("let p = base")
                }
                w.writeLine("let ptr = CPointer<${underlyingCjType}>(p)")
                w.writeLine("return ${enumType}(ptr.read())")
            } else {
                w.writeLine("return ${enumType}(${polyfillFn}(base, ${Int64(offset)}))")
            }
            w.dedent()
            w.writeLine("}")
        })
        w.writeBlock("set(val)", {=>
            w.writeLine("unsafe {")
            w.indent()
            w.writeLine("var rawStorage = _raw")
            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
            if (polyfillFn.isEmpty()) {
                if (offset > 0u32) {
                    w.writeLine("let p = base + Int64(${offset})")
                } else {
                    w.writeLine("let p = base")
                }
                w.writeLine("let ptr = CPointer<${underlyingCjType}>(p)")
                w.writeLine("ptr.write(val.value)")
            } else {
                w.writeLine("${writeFn}(base, ${Int64(offset)}, val.value)")
            }
            w.writeLine("_raw = rawStorage")
            w.dedent()
            w.writeLine("}")
        })
    })
}

func writeUnionAccessor(
    w: CodeWriter,
    accessorName: String,
    fieldCjType: String,
    fieldAbiType: String,
    offset: UInt32,
    unionRawElemType: String,
    fieldTags: ArrayList<String>
): Unit {
    let _ = unionRawElemType
    let polyfillFn = polyfillUnionAccessorName(fieldCjType)
    if (polyfillFn.isEmpty()) {
        // Fallback to generic pointer-cast for non-primitive types (nested struct, etc.)
        writeUnionAccessorGeneric(w, accessorName, fieldCjType, fieldAbiType, offset, fieldTags)
        return
    }

    // Primitive types: use polyfill helpers
    let writeFn = polyfillWriteFnName(polyfillFn)
    useSupportSymbol("windows_polyfill", polyfillFn)
    useSupportSymbol("windows_polyfill", writeFn)
    if (!fieldTags.isEmpty()) {
        writeAvailabilityForTags(w, "", fieldTags)
    }
    w.writeBlock("public mut prop ${accessorName}: ${fieldCjType}", {=>
        w.writeBlock("get()", {=>
            w.writeLine("unsafe {")
            w.indent()
            w.writeLine("var rawStorage = _raw")
            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
            w.writeLine("return ${polyfillFn}(base, ${Int64(offset)})")
            w.dedent()
            w.writeLine("}")
        })
        w.writeBlock("set(val)", {=>
            w.writeLine("unsafe {")
            w.indent()
            w.writeLine("var rawStorage = _raw")
            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
            w.writeLine("${writeFn}(base, ${Int64(offset)}, val)")
            w.writeLine("_raw = rawStorage")
            w.dedent()
            w.writeLine("}")
        })
    })
}

// Generate body for packed(N) structs (N != 0 && N != 8).
// Uses VArray<UInt8, $size> storage with packedReadXxx/packedWriteXxx accessors.
func writePackedStructBody(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    nestedNames: HashMap<String, String>,
    fullName: String,
    packing: UInt32,
    winrtProjection: Bool
): Unit {
    // Compute total struct size via layout engine
    let visiting = HashMap<String, Bool>()
    let totalSize = match (computeTypeDefLayout(index, fileIdx, row, visiting)) {
        case Some((size, _)) => size
        case None => 0u32
    }

    if (totalSize == 0u32) {
        eprintln("warning: cannot compute size for packed struct `${fullName}` with packing(${packing}); skipping packed body")
        return
    }

    w.writeLine("public var _raw: VArray<UInt8, \$${totalSize}> = VArray<UInt8, \$${totalSize}>(repeat: 0u8)")

    // Walk fields and compute their offsets following packing rules (sequential layout)
    let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
    var offset = 0u32
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fi)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            fi += 1
            continue
        }

        let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
        let fieldCjType = if (winrtProjection) {
            winrtStructFieldPublicType(index, fileIdx, row, fieldType, nestedKeys)
        } else {
            cppType(fieldType)
        }
        let fieldAbiType = if (winrtProjection) {
            winrtStructFieldAbiType(index, fileIdx, row, fieldType, nestedKeys)
        } else {
            fieldCjType
        }
        let visitingField = HashMap<String, Bool>()
        match (computeMetadataTypeLayout(index, fileIdx, row, index.fieldType(fileIdx, fi), nestedKeys, visitingField)) {
            case Some((fieldSize, fieldAlign)) =>
                let effectiveAlign = applyPacking(fieldAlign, packing)
                offset = roundUpUInt32(offset, effectiveAlign)
                let fieldOffset = offset
                offset += fieldSize

                let fieldTags = itemAvailabilityTags(TABLE_FIELD, fileIdx, fi)
                match (enumBinaryAccessorInfo(index, fileIdx, row, fieldType, nestedKeys)) {
                    case Some((enumType, underlyingCjType)) =>
                        let polyfillFn = polyfillPackedAccessorName(underlyingCjType)
                        if (polyfillFn.isEmpty()) {
                            w.writeBlankLine()
                            w.writeLine("// packed field `${index.fieldName(fileIdx, fi)}`: type `${enumType}` not supported by polyfill; skipped")
                            eprintln("warning: packed struct `${fullName}` field `${index.fieldName(fileIdx, fi)}` type `${enumType}` not in polyfill; skipped")
                            fi += 1
                            continue
                        }

                        let writeFn = polyfillWriteFnName(polyfillFn)
                        useSupportSymbol("windows_polyfill", polyfillFn)
                        useSupportSymbol("windows_polyfill", writeFn)
                        let accessorName = sanitizeIdentifier(lowerCamelIdentifier(sanitizeIdentifier(index.fieldName(fileIdx, fi))))
                        w.writeBlankLine()
                        if (!fieldTags.isEmpty()) {
                            writeAvailabilityForTags(w, "", fieldTags)
                        }
                        w.writeBlock("public mut prop ${accessorName}: ${enumType}", {=>
                            w.writeBlock("get()", {=>
                                w.writeLine("unsafe {")
                                w.indent()
                                w.writeLine("var rawStorage = _raw")
                                w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                                w.writeLine("return ${enumType}(${polyfillFn}(base, ${Int64(fieldOffset)}))")
                                w.dedent()
                                w.writeLine("}")
                            })
                            w.writeBlock("set(val)", {=>
                                w.writeLine("unsafe {")
                                w.indent()
                                w.writeLine("var rawStorage = _raw")
                                w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                                w.writeLine("${writeFn}(base, ${Int64(fieldOffset)}, val.value)")
                                w.writeLine("_raw = rawStorage")
                                w.dedent()
                                w.writeLine("}")
                            })
                        })
                        fi += 1
                        continue
                    case None => ()
                }

                let defaultVal = if (winrtProjection) {
                    winrtStructFieldAbiDefaultExprForType(index, fileIdx, row, fieldType, nestedKeys, fieldAbiType)
                } else if (fieldAbiType == fieldCjType) {
                    cppDefaultValue(fieldType)
                } else {
                    highLevelResultDefaultExpr(fieldAbiType)
                }
                let polyfillFn = polyfillPackedAccessorName(fieldAbiType)
                if (polyfillFn.isEmpty()) {
                    if (!canEmitUnionAccessor(index, fileIdx, row, nestedKeys, fieldType, fieldAbiType)) {
                        w.writeBlankLine()
                        w.writeLine("// packed field `${index.fieldName(fileIdx, fi)}`: type `${fieldAbiType}` not supported by polyfill; skipped")
                        eprintln("warning: packed struct `${fullName}` field `${index.fieldName(fileIdx, fi)}` type `${fieldAbiType}` not in polyfill; skipped")
                        fi += 1
                        continue
                    }

                    useSupportSymbol("windows_polyfill", "packedReadValue")
                    useSupportSymbol("windows_polyfill", "packedWriteValue")
                    let accessorName = sanitizeIdentifier(lowerCamelIdentifier(sanitizeIdentifier(index.fieldName(fileIdx, fi))))
                    w.writeBlankLine()
                    if (!fieldTags.isEmpty()) {
                        writeAvailabilityForTags(w, "", fieldTags)
                    }
                    w.writeBlock("public mut prop ${accessorName}: ${fieldCjType}", {=>
                        w.writeBlock("get()", {=>
                            w.writeLine("unsafe {")
                            w.indent()
                            w.writeLine("var rawStorage = _raw")
                            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                            w.writeLine("let defaultValue: ${fieldAbiType} = ${defaultVal}")
                            if (fieldAbiType == fieldCjType) {
                                w.writeLine("return packedReadValue<${fieldCjType}>(base, ${Int64(fieldOffset)}, defaultValue)")
                            } else {
                                w.writeLine("let raw = packedReadValue<${fieldAbiType}>(base, ${Int64(fieldOffset)}, defaultValue)")
                                w.writeLine("return ${winrtStructFieldReturnExpr(index, fileIdx, row, fieldType, nestedKeys, "raw", fieldCjType, fieldAbiType)}")
                            }
                            w.dedent()
                            w.writeLine("}")
                        })
                        w.writeBlock("set(val)", {=>
                            w.writeLine("unsafe {")
                            w.indent()
                            w.writeLine("var rawStorage = _raw")
                            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                            if (fieldAbiType == fieldCjType) {
                                w.writeLine("packedWriteValue(base, ${Int64(fieldOffset)}, val)")
                            } else {
                                w.writeLine("packedWriteValue(base, ${Int64(fieldOffset)}, ${winrtStructFieldProjectExpr(index, fileIdx, row, fieldType, nestedKeys, "val", fieldCjType, fieldAbiType)})")
                            }
                            w.writeLine("_raw = rawStorage")
                            w.dedent()
                            w.writeLine("}")
                        })
                    })
                } else {
                    let writeFn = polyfillWriteFnName(polyfillFn)
                    useSupportSymbol("windows_polyfill", polyfillFn)
                    useSupportSymbol("windows_polyfill", writeFn)
                    let accessorName = sanitizeIdentifier(lowerCamelIdentifier(sanitizeIdentifier(index.fieldName(fileIdx, fi))))
                    w.writeBlankLine()
                    if (!fieldTags.isEmpty()) {
                        writeAvailabilityForTags(w, "", fieldTags)
                    }
                    w.writeBlock("public mut prop ${accessorName}: ${fieldCjType}", {=>
                        w.writeBlock("get()", {=>
                            w.writeLine("unsafe {")
                            w.indent()
                            w.writeLine("var rawStorage = _raw")
                            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                            w.writeLine("return ${polyfillFn}(base, ${Int64(fieldOffset)})")
                            w.dedent()
                            w.writeLine("}")
                        })
                        w.writeBlock("set(val)", {=>
                            w.writeLine("unsafe {")
                            w.indent()
                            w.writeLine("var rawStorage = _raw")
                            w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                            w.writeLine("${writeFn}(base, ${Int64(fieldOffset)}, val)")
                            w.writeLine("_raw = rawStorage")
                            w.dedent()
                            w.writeLine("}")
                        })
                    })
                }
            case None =>
                w.writeBlankLine()
                w.writeLine("// packed field `${index.fieldName(fileIdx, fi)}`: layout unknown; skipped")
                eprintln("warning: packed struct `${fullName}` field `${index.fieldName(fileIdx, fi)}` layout unknown; skipped")
        }

        fi += 1
    }
}
