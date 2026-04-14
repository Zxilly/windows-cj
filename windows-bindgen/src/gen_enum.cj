package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

// Generate enum/flags struct definition
// Cangjie enums in windows-cj are modeled as wrapper structs with constants and operator overloads,
// matching the pattern from windows-core (e.g., TypeAttributes, FieldAttributes)
public func generateEnum(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    let name = escapeSourceIdentifier(trimTick(index.typeDefName(fileIdx, row)))
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    let underlyingType = resolveUnderlyingType(index, fileIdx, row)

    // Check if this is a flags enum
    let isFlags = hasAttribute(index, fileIdx, row, "FlagsAttribute")

    let feature = namespaceToFeature(namespace)
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, index.arches(TABLE_TYPE_DEF, fileIdx, row))
    let hasDerivedEquatable = typeHasDerive(namespace, name, "Equatable") || typeHasDerive(namespace, name, "Comparable")
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    writeDeriveAttributes(w, namespace, name)
    w.writeLine("@C")
    w.writeBlock("public struct ${name}", {=>
        w.writeLine("public var value: ${underlyingType} = 0")
        w.writeBlankLine()
        w.writeLine("public init() {}")
        w.writeBlankLine()
        w.writeLine("public init(value: ${underlyingType}) {")
        w.writeLine("    this.value = value")
        w.writeLine("}")

        if (!hasDerivedEquatable) {
            // Preserve the existing equality surface unless Deriving owns it.
            w.writeBlankLine()
            w.writeLine("public operator func ==(other: ${name}): Bool {")
            w.writeLine("    return this.value == other.value")
            w.writeLine("}")
            w.writeLine("public operator func !=(other: ${name}): Bool {")
            w.writeLine("    return this.value != other.value")
            w.writeLine("}")
        }

        // Bitwise operators and contains only for flags enums
        if (isFlags) {
            w.writeBlankLine()
            w.writeLine("public func contains(other: ${name}): Bool {")
            w.writeLine("    return (this.value & other.value) == other.value")
            w.writeLine("}")
            w.writeBlankLine()
            w.writeLine("public operator func |(other: ${name}): ${name} {")
            w.writeLine("    return ${name}(this.value | other.value)")
            w.writeLine("}")
            w.writeLine("public operator func &(other: ${name}): ${name} {")
            w.writeLine("    return ${name}(this.value & other.value)")
            w.writeLine("}")
            w.writeLine("public operator func !(): ${name} {")
            w.writeLine("    return ${name}(!this.value)")
            w.writeLine("}")
        }
    })

    // Generate enum/flag literals as top-level constants because @C structs cannot
    // carry non-CType static members inside the type body.
    var ci = fStart
    while (ci < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, ci)
        if (fieldFlags.contains(FieldAttributes.Literal)) {
            let constName = projectedConstantName(index, index.fieldName(fileIdx, ci), namespace)
            match (readFieldConstantLiteral(index, fileIdx, ci)) {
                case Some((_, constValue)) =>
                    let rawValue = stripTypeSuffix(constValue)
                    let fieldTags = itemAvailabilityTags(TABLE_FIELD, fileIdx, ci)
                    w.writeBlankLine()
                    writeAvailabilityForTags(w, feature, mergeEnumCfgTags(typeTags, fieldTags))
                    w.writeLine("public let ${escapeSourceIdentifier(constName)}: ${name} = ${name}(${rawValue})")
                case None => ()
            }
        }
        ci += 1
    }
}

func mergeEnumCfgTags(first: ArrayList<String>, second: ArrayList<String>): ArrayList<String> {
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

func resolveUnderlyingType(index: TypeIndex, fileIdx: Int64, row: Int64): String {
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fi)
        if (!fieldFlags.contains(FieldAttributes.Literal)) {
            let fieldTy = index.fieldType(fileIdx, fi)
            return cppType(fieldTy)
        }
        fi += 1
    }
    return "Int32"
}

// Check if a TypeDef has a specific custom attribute
func hasAttribute(index: TypeIndex, fileIdx: Int64, row: Int64, attrName: String): Bool {
    // HasCustomAttribute encoded: TypeDef is tag 3 (0-indexed in the big table)
    let encoded = encodeCodedIndex(3, row, CODED_HAS_CUSTOM_ATTRIBUTE_BITS)
    let attrs = index.getAttributes(fileIdx, encoded)
    for (attr in attrs) {
        let (attrFileIdx, _, attrRow) = attr
        match (customAttributeTypeName(index, attrFileIdx, attrRow)) {
            case Some(typeName) =>
                if (typeName.name == attrName) {
                    return true
                }
            case None => ()
        }
    }
    return false
}

// Strip type suffix (i8, u8, i16, u16, i32, u32, i64, u64, f32, f64) from a
// value literal so it can be used as the raw argument to the enum constructor.
func stripTypeSuffix(value: String): String {
    let arr = value.toArray()
    let len = Int64(arr.size)
    // 3-char suffixes: i16, u16, i32, u32, i64, u64, f32, f64
    if (len > 3) {
        let s3 = String.fromUtf8(arr[len - 3..len])
        if (s3 == "i16" || s3 == "u16" ||
            s3 == "i32" || s3 == "u32" ||
            s3 == "i64" || s3 == "u64" ||
            s3 == "f32" || s3 == "f64") {
            return String.fromUtf8(arr[0..len - 3])
        }
    }
    // 2-char suffixes: i8, u8
    if (len > 2) {
        let s2 = String.fromUtf8(arr[len - 2..len])
        if (s2 == "i8" || s2 == "u8") {
            return String.fromUtf8(arr[0..len - 2])
        }
    }
    return value
}
