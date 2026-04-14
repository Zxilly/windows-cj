package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

// Generate constants from a "class" TypeDef that holds static Literal fields
public func generateConstants(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    let category = index.typeDefCategory(fileIdx, row)
    match (category) {
        case Class =>
            let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
            let feature = namespaceToFeature(namespace)
            let typeTags = typeAvailabilityTags(namespace, trimTick(index.typeDefName(fileIdx, row)), fileIdx, row, index.arches(TABLE_TYPE_DEF, fileIdx, row))
            var hasAny = false
            var fi = fStart
            while (fi < fEnd) {
                let fieldFlags = index.fieldFlags(fileIdx, fi)
                if (fieldFlags.contains(FieldAttributes.Literal) && fieldFlags.contains(FieldAttributes.Static)) {
                    let constName = projectedConstantName(index, index.fieldName(fileIdx, fi), namespace)
                    let fieldType = index.fieldType(fileIdx, fi)
                    let mergedTags = mergeConstantCfgTags(typeTags, itemAvailabilityTags(TABLE_FIELD, fileIdx, fi))

                    match (FieldRef(index, fileIdx, fi).guidAttributeLiteral()) {
                        case Some(guidLiteral) =>
                            if (!hasAny) {
                                hasAny = true
                                w.writeBlankLine()
                            }
                            writeAvailabilityForTags(w, feature, mergedTags)
                                    w.writeLine("public let ${escapeSourceIdentifier(constName)}: GUID = GUID(${guidLiteral})")
                            fi += 1
                            continue
                        case None => ()
                    }

                    match (readFieldConstantLiteral(index, fileIdx, fi)) {
                        case Some((constType, constValue)) =>
                            if (!hasAny) {
                                hasAny = true
                                w.writeBlankLine()
                            }
                            let cjType = resolveConstantType(index, fieldType, constType)
                            match (formatConstantValueLiteral(index, constValue, fieldType, constType)) {
                                case Some(cjValue) =>
                                    writeAvailabilityForTags(w, feature, mergedTags)
                                    w.writeLine("public let ${escapeSourceIdentifier(constName)}: ${cjType} = ${cjValue}")
                                case None =>
                                    eprintln("warning: skipping unsupported constant `${namespace}.${constName}`")
                            }
                        case None => ()
                    }
                }
                fi += 1
            }
        case _ => ()
    }
}

public func projectedConstantName(index: TypeIndex, rawName: String, namespace: String): String {
    if (!index.contains(namespace, trimTick(rawName))) {
        return rawName
    }
    return "${rawName}_CONST"
}

func mergeConstantCfgTags(first: ArrayList<String>, second: ArrayList<String>): ArrayList<String> {
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

// Resolve the type to use for a constant declaration
func resolveConstantType(index: TypeIndex, fieldType: MetadataType, constType: MetadataType): String {
    match (fieldType) {
        case ValueName(tn) =>
            let resolved = cppType(fieldType)
            // If it resolves to a known primitive, use it directly
            if (resolved == "Int32" || resolved == "UInt32" || resolved == "Int64" || resolved == "UInt64") {
                return resolved
            }
            match (handleAliasUnderlyingType(index, tn)) {
                case Some(aliasUnderlying) =>
                    if (isPrimitiveLiteralType(aliasUnderlying) || isPointerType(aliasUnderlying)) {
                        return resolved
                    }
                case None => ()
            }
            // Otherwise it's an enum type - use the enum name
            return resolved
        case ClassName(tn) =>
            if (tn.matches("System", "Guid")) {
                return "GUID"
            }
            return cppType(fieldType)
        case _ => return cppConstantType(constType)
    }
}

func formatConstantValueLiteral(index: TypeIndex, value: String, fieldType: MetadataType, constType: MetadataType): Option<String> {
    if (cppConstantType(constType) == "String") {
        return Some(value)
    }
    match (fieldType) {
        case ValueName(_) =>
            let resolved = cppType(fieldType)
            if (isPrimitiveLiteralType(resolved)) {
                return Some(value)
            }
            if (isPointerType(resolved)) {
                return pointerConstantLiteral(resolved, value)
            }

            match (fieldType) {
                case ValueName(tn) =>
                    match (handleAliasUnderlyingType(index, tn)) {
                        case Some(aliasUnderlying) =>
                            if (isPrimitiveLiteralType(aliasUnderlying)) {
                                return Some(value)
                            }
                            if (isPointerType(aliasUnderlying)) {
                                return pointerConstantLiteral(aliasUnderlying, value)
                            }
                        case None => ()
                    }
                case _ => ()
            }
            let stripped = stripTypeSuffix(value)
            return Some("${resolved}(${stripped})")
        case _ =>
            let resolved = cppType(fieldType)
            if (isPointerType(resolved)) {
                return pointerConstantLiteral(resolved, value)
            }
            return Some(value)
    }
}

func handleAliasUnderlyingType(index: TypeIndex, tn: TypeName): Option<String> {
    let candidates = index.get(tn.namespace, trimTick(tn.name))
    if (candidates.isEmpty()) {
        return None
    }

    let (fileIdx, row) = candidates[0]
    if (!isHandleType(index, fileIdx, row)) {
        return None
    }

    let (fieldStart, _) = index.typeDefFields(fileIdx, row)
    let fieldType = index.fieldType(fileIdx, fieldStart)
    return Some(handleAliasToCj(tn.namespace, trimTick(tn.name), cppType(fieldType)))
}

func handleConstantUnderlyingType(underlyingType: String): String {
    if (underlyingType == "IntNative" || underlyingType == "UIntNative") {
        return "CPointer<Unit>"
    }
    if (underlyingType == "Int64" || underlyingType == "UInt64") {
        return "CPointer<Unit>"
    }
    if (underlyingType == "Int32" || underlyingType == "UInt32") {
        return underlyingType
    }
    return underlyingType
}

func isPrimitiveLiteralType(typeName: String): Bool {
    return typeName == "Bool" ||
           typeName == "Int8" || typeName == "UInt8" ||
           typeName == "Int16" || typeName == "UInt16" ||
           typeName == "Int32" || typeName == "UInt32" ||
           typeName == "Int64" || typeName == "UInt64" ||
           typeName == "IntNative" || typeName == "UIntNative" ||
           typeName == "Float32" || typeName == "Float64"
}

func isPointerType(typeName: String): Bool {
    return typeName.startsWith("CPointer<")
}

func pointerConstantLiteral(pointerType: String, value: String): Option<String> {
    let stripped = stripTypeSuffix(value)
    if (stripped == "0") {
        return Some("${pointerType}()")
    }
    return Some("unsafe { ${pointerType}(CPointer<UInt8>() + ${stripped}) }")
}

// Generate GUID constants from GuidAttribute custom attributes
public func generateGuidConstant(
    w: CodeWriter,
    name: String,
    guidAttr: Array<UInt32> // [data1, data2, data3, d4_0..d4_7] packed
): Unit {
    // This would require parsing GuidAttribute blob values
    // Implemented as helper for COM interface IID generation
    if (guidAttr.size >= 11) {
        w.writeLine("public let ${escapeSourceIdentifier(name)}: GUID = GUID(${guidAttr[0]}, ${UInt16(guidAttr[1])}, ${UInt16(guidAttr[2])}, ${UInt8(guidAttr[3])}, ${UInt8(guidAttr[4])}, ${UInt8(guidAttr[5])}, ${UInt8(guidAttr[6])}, ${UInt8(guidAttr[7])}, ${UInt8(guidAttr[8])}, ${UInt8(guidAttr[9])}, ${UInt8(guidAttr[10])})")
    }
}
