package windows_bindgen

import std.collection.*
import windows_metadata.*

public class MethodNames {
    private let overloads: HashMap<String, Int64>
    private let seenSignatures: HashMap<String, String>

    public init() {
        this.overloads = HashMap<String, Int64>()
        this.seenSignatures = HashMap<String, String>()
    }

    public func add(index: TypeIndex, fileIdx: Int64, methodRow: Int64): String {
        let baseName = normalizedMethodName(index, fileIdx, methodRow)
        let signatureKey = methodSignatureKey(index, fileIdx, methodRow, baseName)
        if (seenSignatures.contains(signatureKey)) {
            return seenSignatures[signatureKey]
        }

        if (!overloads.contains(baseName)) {
            overloads[baseName] = 0
        }
        overloads[baseName] = overloads[baseName] + 1

        let overload = overloads[baseName]
        let result = if (overload > 1) {
            sanitizeIdentifier("${baseName}${overload}")
        } else {
            sanitizeIdentifier(baseName)
        }
        seenSignatures[signatureKey] = result
        return result
    }
}

public func buildNormalizedMethodNames(index: TypeIndex, fileIdx: Int64, row: Int64): HashMap<Int64, String> {
    let result = HashMap<Int64, String>()
    let names = MethodNames()
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)

    var methodRow = mStart
    while (methodRow < mEnd) {
        result[methodRow] = names.add(index, fileIdx, methodRow)
        methodRow += 1
    }

    return result
}

func normalizedMethodName(index: TypeIndex, fileIdx: Int64, methodRow: Int64): String {
    let rawName = index.methodDefName(fileIdx, methodRow)
    let flags = index.methodDefFlags(fileIdx, methodRow)
    let specialName = flags.contains(MethodAttributes.SpecialName) || flags.contains(MethodAttributes.RTSpecialName)
    if (specialName || startsWith(rawName, "get_") || startsWith(rawName, "put_") || startsWith(rawName, "add_") || startsWith(rawName, "remove_")) {
        return normalizeAccessorName(rawName)
    }

    match (extractOverloadName(index, fileIdx, methodRow, rawName)) {
        case Some(overloadName) => return overloadName
        case None => return rawName
    }
}

func normalizeAccessorName(rawName: String): String {
    if (startsWith(rawName, "get_")) {
        return substringFrom(rawName, 4)
    }
    if (startsWith(rawName, "put_")) {
        return "Set${substringFrom(rawName, 4)}"
    }
    if (startsWith(rawName, "add_")) {
        return substringFrom(rawName, 4)
    }
    if (startsWith(rawName, "remove_")) {
        return "Remove${substringFrom(rawName, 7)}"
    }
    return rawName
}

func extractOverloadName(index: TypeIndex, fileIdx: Int64, methodRow: Int64, rawName: String): Option<String> {
    let encoded = encodeCodedIndex(0, methodRow, CODED_HAS_CUSTOM_ATTRIBUTE_BITS)
    let attrs = index.getAttributes(fileIdx, encoded)

    for (attr in attrs) {
        let (attrFileIdx, _, attrRow) = attr
        let attrType = index.attributeName(attrFileIdx, attrRow)
        if (attrType != "OverloadAttribute") {
            continue
        }

        let values = index.attributeValues(attrFileIdx, attrRow)
        if (values.isEmpty()) {
            continue
        }

        match (values[0][1]) {
            case MetadataValue.ValUtf8(overloadName) =>
                return normalizeOverloadName(rawName, overloadName)
            case MetadataValue.ValUtf16(overloadName) =>
                return normalizeOverloadName(rawName, overloadName)
            case _ => ()
        }
    }

    return None
}

func normalizeOverloadName(rawName: String, overloadName: String): Option<String> {
    if (overloadName.isEmpty()) {
        return None
    }

    if (startsWith(overloadName, rawName)) {
        let suffix = substringFrom(overloadName, Int64(rawName.toArray().size))
        if (!suffix.isEmpty() && isAllDigits(suffix)) {
            return Some(rawName)
        }
    }

    return Some(overloadName)
}

func methodSignatureKey(index: TypeIndex, fileIdx: Int64, methodRow: Int64, name: String): String {
    let generics = Array<MetadataType>(0, {_ => MetadataType.Void})
    let signature = index.methodDefSignature(fileIdx, methodRow, generics)
    var sb = StringBuilder()
    sb.append(name)
    sb.append("|")
    sb.append(metadataTypeSignatureKey(signature.returnType))
    for (paramType in signature.paramTypes) {
        sb.append("|")
        sb.append(metadataTypeSignatureKey(paramType))
    }
    return sb.toString()
}

func metadataTypeSignatureKey(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Void => "void"
        case MetadataType.Boolean => "bool"
        case MetadataType.Char => "char"
        case MetadataType.I8 => "i8"
        case MetadataType.U8 => "u8"
        case MetadataType.I16 => "i16"
        case MetadataType.U16 => "u16"
        case MetadataType.I32 => "i32"
        case MetadataType.U32 => "u32"
        case MetadataType.I64 => "i64"
        case MetadataType.U64 => "u64"
        case MetadataType.F32 => "f32"
        case MetadataType.F64 => "f64"
        case MetadataType.ISize => "isize"
        case MetadataType.USize => "usize"
        case MetadataType.MdString => "string"
        case MetadataType.MdObject => "object"
        case MetadataType.ClassName(tn) => "class:${tn.toString()}"
        case MetadataType.ValueName(tn) => "value:${tn.toString()}"
        case MetadataType.Union(tn) => "union:${tn.toString()}"
        case MetadataType.MdArray(inner) => "array:${metadataTypeSignatureKey(inner)}"
        case MetadataType.Generic(name, pos) => "generic:${name}:${pos}"
        case MetadataType.RefMut(inner) => "refmut:${metadataTypeSignatureKey(inner)}"
        case MetadataType.RefConst(inner) => "refconst:${metadataTypeSignatureKey(inner)}"
        case MetadataType.PtrMut(inner, depth) => "ptrmut:${depth}:${metadataTypeSignatureKey(inner)}"
        case MetadataType.PtrConst(inner, depth) => "ptrconst:${depth}:${metadataTypeSignatureKey(inner)}"
        case MetadataType.ArrayFixed(inner, size) => "fixed:${size}:${metadataTypeSignatureKey(inner)}"
        case MetadataType.Packed(inner, packing) => "packed:${packing}:${metadataTypeSignatureKey(inner)}"
    }
}

func substringFrom(value: String, start: Int64): String {
    let arr = value.toArray()
    if (start >= Int64(arr.size)) {
        return ""
    }
    return String.fromUtf8(arr[start..Int64(arr.size)])
}

func isAllDigits(value: String): Bool {
    if (value.isEmpty()) {
        return false
    }

    for (ch in value.toArray()) {
        if (ch < b'0' || ch > b'9') {
            return false
        }
    }

    return true
}
