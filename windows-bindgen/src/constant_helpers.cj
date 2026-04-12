package windows_bindgen

import windows_metadata.*

// Read a field constant directly from the metadata blob without the narrow parser.
// This avoids dropping values whose signed forms would overflow a narrow cast.
public func readFieldConstantLiteral(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64
): Option<(MetadataType, String)> {
    let file = index.getFile(fileIdx)
    let encoded = encodeCodedIndex(0, row, CODED_HAS_CONSTANT_BITS) // 0 = Field tag
    let (start, end) = file.equalRange(TABLE_CONSTANT, 1, encoded)
    if (start >= end) {
        return None
    }

    let constTypeCode = UInt8(file.getUInt(start, TABLE_CONSTANT, 0))
    let constType = constantElementTypeToMetadataType(constTypeCode)
    let blob = file.getBlob(start, TABLE_CONSTANT, 2)
    let value = readConstantLiteral(blob, constType)
    return Some((constType, value))
}

func constantElementTypeToMetadataType(code: UInt8): MetadataType {
    if (code == ELEMENT_TYPE_BOOLEAN) { return MetadataType.Boolean }
    if (code == ELEMENT_TYPE_CHAR) { return MetadataType.Char }
    if (code == ELEMENT_TYPE_I1) { return MetadataType.I8 }
    if (code == ELEMENT_TYPE_U1) { return MetadataType.U8 }
    if (code == ELEMENT_TYPE_I2) { return MetadataType.I16 }
    if (code == ELEMENT_TYPE_U2) { return MetadataType.U16 }
    if (code == ELEMENT_TYPE_I4) { return MetadataType.I32 }
    if (code == ELEMENT_TYPE_U4) { return MetadataType.U32 }
    if (code == ELEMENT_TYPE_I8) { return MetadataType.I64 }
    if (code == ELEMENT_TYPE_U8) { return MetadataType.U64 }
    if (code == ELEMENT_TYPE_R4) { return MetadataType.F32 }
    if (code == ELEMENT_TYPE_R8) { return MetadataType.F64 }
    if (code == ELEMENT_TYPE_I) { return MetadataType.ISize }
    if (code == ELEMENT_TYPE_U) { return MetadataType.USize }
    if (code == ELEMENT_TYPE_STRING) { return MetadataType.MdString }
    throw Exception("Unknown constant element type: ${code}")
}

func readConstantLiteral(blob: BlobReader, ty: MetadataType): String {
    match (ty) {
        case MetadataType.Boolean =>
            if (blob.readBool()) { "true" } else { "false" }
        case MetadataType.Char =>
            "${blob.readU16()}"
        case MetadataType.I8 =>
            formatSignedLiteral(UInt64(blob.readU8()), 8, "i8")
        case MetadataType.U8 =>
            "${blob.readU8()}u8"
        case MetadataType.I16 =>
            formatSignedLiteral(UInt64(blob.readU16()), 16, "i16")
        case MetadataType.U16 =>
            "${blob.readU16()}u16"
        case MetadataType.I32 =>
            formatSignedLiteral(UInt64(blob.readU32()), 32, "i32")
        case MetadataType.U32 =>
            "${blob.readU32()}u32"
        case MetadataType.I64 =>
            formatSignedLiteral(blob.readU64(), 64, "i64")
        case MetadataType.U64 =>
            "${blob.readU64()}u64"
        case MetadataType.F32 =>
            formatF32Literal(blob.readF32())
        case MetadataType.F64 =>
            formatF64Literal(blob.readF64())
        case MetadataType.ISize =>
            formatSignedLiteral(blob.readU64(), 64, "i64")
        case MetadataType.USize =>
            "${blob.readU64()}u64"
        case MetadataType.MdString =>
            "\"${escapeString(blob.readUtf16())}\""
        case _ =>
            throw Exception("Unsupported constant type")
    }
}

func formatSignedLiteral(raw: UInt64, bitWidth: Int64, suffix: String): String {
    let signBit = signedLiteralSignBit(bitWidth)
    if (raw < signBit) {
        return "${raw}${suffix}"
    }

    let magnitude = signedLiteralMagnitude(raw, bitWidth)
    return "-${magnitude}${suffix}"
}

func signedLiteralSignBit(bitWidth: Int64): UInt64 {
    if (bitWidth == 64) {
        return 0x8000000000000000u64
    }
    return 1u64 << (bitWidth - 1)
}

func signedLiteralMagnitude(raw: UInt64, bitWidth: Int64): UInt64 {
    let signBit = signedLiteralSignBit(bitWidth)
    let lowMask = signBit - 1u64
    return signBit - (raw & lowMask)
}
