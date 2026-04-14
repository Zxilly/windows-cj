package windows_bindgen

import std.collection.*
import windows_metadata.*

var typeLayoutCache_: HashMap<String, (UInt32, UInt32)> = HashMap<String, (UInt32, UInt32)>()
var missingTypeLayoutCache_: HashMap<String, Bool> = HashMap<String, Bool>()

public func resetStructLayoutCaches(): Unit {
    typeLayoutCache_ = HashMap<String, (UInt32, UInt32)>()
    missingTypeLayoutCache_ = HashMap<String, Bool>()
}

// Generate @C struct definition
public func generateStruct(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    generateStructNamed(w, index, fileIdx, row, namespace, trimTick(index.typeDefName(fileIdx, row)))
}

func generateStructNamed(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    name: String
): Unit {
    let flags = index.typeDefFlags(fileIdx, row)
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    let fullName = qualifiedTypeName(namespace, name)
    let arches = index.arches(TABLE_TYPE_DEF, fileIdx, row)

    // Skip handle types (generated separately as type aliases)
    if (isHandleType(index, fileIdx, row)) {
        return
    }
    if (isUnsupportedOnlyArchitecture(arches)) {
        return
    }

    // Check for packing/explicit layout
    let layout = index.typeDefClassLayout(fileIdx, row)
    let isUnion = flags.contains(TypeAttributes.ExplicitLayout)
    let structSignature = buildStructSignature(index, fileIdx, row, name)
    if (!shouldEmitStructRow(index, namespace, name, fileIdx, row, structSignature)) {
        return
    }

    w.writeBlankLine()

    // Add feature guard based on the outer namespace, including nested helper types
    let feature = namespaceToFeature(namespace)
    let typeTags = mergedStructTypeAvailabilityTags(index, namespace, name, fileIdx, row, structSignature)
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
            w.writeLine("// WARNING: union simulated as byte array (size-equivalent, not type-safe)")
            eprintln("warning: simulating union layout for `${fullName}` using VArray<${unionRawElemType}, ${unionRawLen}>")
        } else {
            w.writeLine("// WARNING: union size unavailable; placeholder only")
            eprintln("warning: union layout for `${fullName}` is missing ClassLayout size")
        }
    }

    // Packed struct with non-default packing (1/2/4/16): use byte storage + polyfill accessors
    let usePackedLayout = !isUnion && structPacking != 0u32 && structPacking != 8u32
    let immutablePacking = structPacking  // capture immutable copy for lambda

    writeDeriveAttributes(w, namespace, name)
    w.writeLine("@C")
    w.writeBlock("public struct ${name}", {=>
        if (isUnion) {
            writeUnionStructBody(w, index, fileIdx, row, nestedNames, unionSize, unionRawElemType, unionRawLen)
        } else if (usePackedLayout) {
            writePackedStructBody(w, index, fileIdx, row, nestedNames, fullName, immutablePacking)
        } else {
            var fi = fStart
            while (fi < fEnd) {
                let fieldFlags = index.fieldFlags(fileIdx, fi)
                // Skip literal/const fields (they become associated constants)
                if (fieldFlags.contains(FieldAttributes.Literal)) {
                    fi += 1
                    continue
                }

                let fieldName = sanitizeIdentifier(index.fieldName(fileIdx, fi))
                let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
                let cjType = cppType(fieldType)
                let defaultVal = cppDefaultValue(fieldType)
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

    // Generate nested types with flattened names (OuterName_InnerName).
    let nestedRows = index.getNested(fileIdx, row)
    for (innerRow in nestedRows) {
        let innerCategory = index.typeDefCategory(fileIdx, innerRow)
        let innerLeaf = nestedLeafName(index.typeDefName(fileIdx, innerRow))
        let nestedName = "${name}_${innerLeaf}"
        match (innerCategory) {
            case Struct => generateStructNamed(w, index, fileIdx, innerRow, namespace, nestedName)
            case Enum => ()
            case _ => ()
        }
    }
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
    structSignature: String
): ArrayList<String> {
    let result = ArrayList<String>()
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.entriesForType(namespace, name)
            for (entry in entries) {
                let entryArches = index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row)
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
        return typeAvailabilityTags(namespace, trimTick(index.typeDefName(fileIdx, row)), fileIdx, row, index.arches(TABLE_TYPE_DEF, fileIdx, row))
    }
    return result
}

func buildStructSignature(index: TypeIndex, fileIdx: Int64, row: Int64, name: String): String {
    let flags = index.typeDefFlags(fileIdx, row)
    if (flags.contains(TypeAttributes.ExplicitLayout)) {
        return "union:${name}"
    }

    let nestedNames = directNestedTypeMap(index, fileIdx, row, name)
    let fields = ArrayList<String>()
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (!fieldFlags.contains(FieldAttributes.Literal)) {
            let fieldName = sanitizeIdentifier(index.fieldName(fileIdx, fieldRow))
            let fieldType = resolveNestedType(index.fieldType(fileIdx, fieldRow), nestedNames)
            fields.add("${fieldName}:${cppType(fieldType)}")
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
    match (computeTypeDefLayout(index, fileIdx, row, typeLayoutCache_, visiting)) {
        case Some((size, _)) => size
        case None => 0u32
    }
}

func computedUnionLayout(index: TypeIndex, fileIdx: Int64, row: Int64): (UInt32, UInt32) {
    let unionSize = computedUnionByteSize(index, fileIdx, row)
    let visiting = HashMap<String, Bool>()
    let unionAlign = match (computeTypeDefLayout(index, fileIdx, row, typeLayoutCache_, visiting)) {
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
    cache: HashMap<String, (UInt32, UInt32)>,
    visiting: HashMap<String, Bool>
): Option<(UInt32, UInt32)> {
    let key = layoutCacheKey(fileIdx, row)
    if (cache.contains(key)) {
        return Some(cache[key])
    }
    if (missingTypeLayoutCache_.contains(key)) {
        return None
    }
    if (visiting.contains(key) && visiting[key]) {
        return None
    }

    visiting[key] = true
    let nestedKeys = directNestedTypeKeyMap(index, fileIdx, row)
    let result = computeTypeDefLayoutCore(index, fileIdx, row, nestedKeys, cache, visiting)
    visiting[key] = false

    match (result) {
        case Some(layout) =>
            cache[key] = layout
            return Some(layout)
        case None =>
            missingTypeLayoutCache_[key] = true
            return None
    }
}

func computeTypeDefLayoutCore(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    nestedKeys: HashMap<String, Int64>,
    cache: HashMap<String, (UInt32, UInt32)>,
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
                cache,
                visiting
            )
        case _ => ()
    }

    let flags = index.typeDefFlags(fileIdx, row)
    let (packing, classSize) = classLayoutInfo(index, fileIdx, row)
    if (flags.contains(TypeAttributes.ExplicitLayout)) {
        return computeExplicitLayoutType(index, fileIdx, row, nestedKeys, packing, classSize, cache, visiting)
    }
    return computeSequentialLayoutType(index, fileIdx, row, nestedKeys, packing, classSize, cache, visiting)
}

func computeExplicitLayoutType(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    nestedKeys: HashMap<String, Int64>,
    packing: UInt32,
    classSize: UInt32,
    cache: HashMap<String, (UInt32, UInt32)>,
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
        match (computeMetadataTypeLayout(index, fileIdx, row, index.fieldType(fileIdx, fi), nestedKeys, cache, visiting)) {
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
    cache: HashMap<String, (UInt32, UInt32)>,
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

        match (computeMetadataTypeLayout(index, fileIdx, row, index.fieldType(fileIdx, fi), nestedKeys, cache, visiting)) {
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
    cache: HashMap<String, (UInt32, UInt32)>,
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
            match (computeMetadataTypeLayout(index, fileIdx, scopeRow, inner, nestedKeys, cache, visiting)) {
                case Some((elemSize, elemAlign)) =>
                    return Some((UInt32(UInt64(elemSize) * UInt64(count)), elemAlign))
                case None =>
                    return None
            }
        case MetadataType.Packed(inner, packing) =>
            match (computeMetadataTypeLayout(index, fileIdx, scopeRow, inner, nestedKeys, cache, visiting)) {
                case Some((innerSize, innerAlign)) =>
                    return Some((innerSize, applyPacking(innerAlign, UInt32(packing))))
                case None =>
                    return None
            }
        case MetadataType.ClassName(typeName) =>
            return computeNamedMetadataTypeLayout(index, fileIdx, scopeRow, typeName, nestedKeys, true, cache, visiting)
        case MetadataType.ValueName(typeName) =>
            return computeNamedMetadataTypeLayout(index, fileIdx, scopeRow, typeName, nestedKeys, false, cache, visiting)
        case MetadataType.Union(typeName) =>
            return computeNamedMetadataTypeLayout(index, fileIdx, scopeRow, typeName, nestedKeys, false, cache, visiting)
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
    cache: HashMap<String, (UInt32, UInt32)>,
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
            return computeTypeDefLayout(index, resolvedFileIdx, resolvedRow, cache, visiting)
        case None =>
            if (preferPointer) {
                return Some((nativePointerSize(), nativePointerSize()))
            }
            return fallbackNamedMetadataTypeLayout(typeName)
    }
}

func fallbackNamedMetadataTypeLayout(typeName: TypeName): Option<(UInt32, UInt32)> {
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
        let scopeNested = directNestedTypeKeyMap(index, fileIdx, scopeRow)
        if (scopeNested.contains(leaf)) {
            return Some((fileIdx, scopeNested[leaf]))
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
    // Always use UInt8 byte storage; alignment-specific types are no longer
    // needed because polyfill helpers work on CPointer<UInt8>. Keep unused
    // parameter for call-site compatibility during transition.
    let _ = unionAlign
    if (unionSize == 0u32) {
        return ("UInt8", 0u32)
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
    unionRawLen: UInt32
): Unit {
    if (unionSize == 0u32) {
        return
    }

    w.writeLine("public var _raw: VArray<${unionRawElemType}, \$${unionRawLen}> = VArray<${unionRawElemType}, \$${unionRawLen}>(repeat: 0)")

    let accessorCounts = HashMap<String, Int64>()
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
                let fieldType = resolveNestedType(index.fieldType(fileIdx, fi), nestedNames)
                let fieldCjType = cppType(fieldType)
                if (canEmitUnionAccessor(fieldType, fieldCjType) && offset < unionSize) {
                    w.writeBlankLine()
                    let fieldTags = itemAvailabilityTags(TABLE_FIELD, fileIdx, fi)
                    if (!fieldTags.isEmpty()) {
                        writeAvailabilityForTags(w, "", fieldTags)
                    }
                    let accessorName = uniqueUnionAccessorName(accessorCounts, index.fieldName(fileIdx, fi))
                    writeUnionAccessor(w, accessorName, fieldCjType, offset, unionRawElemType)
                }
            case None => ()
        }

        fi += 1
    }
}

func canEmitUnionAccessor(fieldType: MetadataType, fieldCjType: String): Bool {
    if (fieldCjType == "Unit") {
        return false
    }

    if (isPrimitiveCjType(fieldCjType) ||
        isPointerCjType(fieldCjType) ||
        fieldCjType.startsWith("VArray<")) {
        return true
    }

    match (fieldType) {
        case MetadataType.ValueName(_) => true
        case MetadataType.Union(_) => true
        case MetadataType.Packed(inner, _) => canEmitUnionAccessor(inner, fieldCjType)
        case _ => false
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
    offset: UInt32
): Unit {
    w.writeBlock("public func ${accessorName}(): ${fieldCjType}", {=>
        w.writeLine("unsafe {")
        w.indent()
        w.writeLine("var rawStorage = _raw")
        w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
        if (offset > 0u32) {
            w.writeLine("let p = base + Int64(${offset})")
        } else {
            w.writeLine("let p = base")
        }
        w.writeLine("let ptr = CPointer<${fieldCjType}>(p)")
        w.writeLine("return ptr.read()")
        w.dedent()
        w.writeLine("}")
    })
    w.writeBlankLine()
    w.writeBlock("public mut func set_${accessorName}(val: ${fieldCjType}): Unit", {=>
        w.writeLine("unsafe {")
        w.indent()
        w.writeLine("var rawStorage = _raw")
        w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
        if (offset > 0u32) {
            w.writeLine("let p = base + Int64(${offset})")
        } else {
            w.writeLine("let p = base")
        }
        w.writeLine("let ptr = CPointer<${fieldCjType}>(p)")
        w.writeLine("ptr.write(val)")
        w.writeLine("_raw = rawStorage")
        w.dedent()
        w.writeLine("}")
    })
}

func writeUnionAccessor(
    w: CodeWriter,
    accessorName: String,
    fieldCjType: String,
    offset: UInt32,
    unionRawElemType: String  // now always "UInt8", kept for signature compatibility
): Unit {
    let polyfillFn = polyfillUnionAccessorName(fieldCjType)
    if (polyfillFn.isEmpty()) {
        // Fallback to generic pointer-cast for non-primitive types (nested struct, etc.)
        writeUnionAccessorGeneric(w, accessorName, fieldCjType, offset)
        return
    }

    // Primitive types: use polyfill helpers
    let writeFn = polyfillWriteFnName(polyfillFn)
    w.writeBlock("public func ${accessorName}(): ${fieldCjType}", {=>
        w.writeLine("unsafe {")
        w.indent()
        w.writeLine("var rawStorage = _raw")
        w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
        w.writeLine("return ${polyfillFn}(base, ${Int64(offset)})")
        w.dedent()
        w.writeLine("}")
    })
    w.writeBlankLine()
    w.writeBlock("public mut func set_${accessorName}(val: ${fieldCjType}): Unit", {=>
        w.writeLine("unsafe {")
        w.indent()
        w.writeLine("var rawStorage = _raw")
        w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
        w.writeLine("${writeFn}(base, ${Int64(offset)}, val)")
        w.writeLine("_raw = rawStorage")
        w.dedent()
        w.writeLine("}")
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
    packing: UInt32
): Unit {
    // Compute total struct size via layout engine
    let visiting = HashMap<String, Bool>()
    let totalSize = match (computeTypeDefLayout(index, fileIdx, row, typeLayoutCache_, visiting)) {
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
    let cache = typeLayoutCache_
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
        let fieldCjType = cppType(fieldType)
        let visitingField = HashMap<String, Bool>()
        match (computeMetadataTypeLayout(index, fileIdx, row, index.fieldType(fileIdx, fi), nestedKeys, cache, visitingField)) {
            case Some((fieldSize, fieldAlign)) =>
                let effectiveAlign = applyPacking(fieldAlign, packing)
                offset = roundUpUInt32(offset, effectiveAlign)
                let fieldOffset = offset
                offset += fieldSize

                let fieldTags = itemAvailabilityTags(TABLE_FIELD, fileIdx, fi)
                let polyfillFn = polyfillPackedAccessorName(fieldCjType)
                if (polyfillFn.isEmpty()) {
                    // Non-primitive type: skip with warning
                    w.writeBlankLine()
                    w.writeLine("// packed field `${index.fieldName(fileIdx, fi)}`: type `${fieldCjType}` not supported by polyfill; skipped")
                    eprintln("warning: packed struct `${fullName}` field `${index.fieldName(fileIdx, fi)}` type `${fieldCjType}` not in polyfill; skipped")
                } else {
                    let writeFn = polyfillWriteFnName(polyfillFn)
                    let accessorName = sanitizeIdentifier(lowerCamelIdentifier(sanitizeIdentifier(index.fieldName(fileIdx, fi))))
                    w.writeBlankLine()
                    if (!fieldTags.isEmpty()) {
                        writeAvailabilityForTags(w, "", fieldTags)
                    }
                    w.writeBlock("public func ${accessorName}(): ${fieldCjType}", {=>
                        w.writeLine("unsafe {")
                        w.indent()
                        w.writeLine("var rawStorage = _raw")
                        w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                        w.writeLine("return ${polyfillFn}(base, ${Int64(fieldOffset)})")
                        w.dedent()
                        w.writeLine("}")
                    })
                    w.writeBlankLine()
                    w.writeBlock("public mut func set_${accessorName}(val: ${fieldCjType}): Unit", {=>
                        w.writeLine("unsafe {")
                        w.indent()
                        w.writeLine("var rawStorage = _raw")
                        w.writeLine("let base = CPointer<UInt8>(inout rawStorage)")
                        w.writeLine("${writeFn}(base, ${Int64(fieldOffset)}, val)")
                        w.writeLine("_raw = rawStorage")
                        w.dedent()
                        w.writeLine("}")
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
