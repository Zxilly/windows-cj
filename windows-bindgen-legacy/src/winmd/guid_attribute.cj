package windows_bindgen.winmd

import windows_metadata.*

public struct GuidParts {
    public let data1: UInt32
    public let data2: UInt16
    public let data3: UInt16
    public let data4_0: UInt8
    public let data4_1: UInt8
    public let data4_2: UInt8
    public let data4_3: UInt8
    public let data4_4: UInt8
    public let data4_5: UInt8
    public let data4_6: UInt8
    public let data4_7: UInt8

    public init(
        data1: UInt32,
        data2: UInt16,
        data3: UInt16,
        data4_0: UInt8,
        data4_1: UInt8,
        data4_2: UInt8,
        data4_3: UInt8,
        data4_4: UInt8,
        data4_5: UInt8,
        data4_6: UInt8,
        data4_7: UInt8
    ) {
        this.data1 = data1
        this.data2 = data2
        this.data3 = data3
        this.data4_0 = data4_0
        this.data4_1 = data4_1
        this.data4_2 = data4_2
        this.data4_3 = data4_3
        this.data4_4 = data4_4
        this.data4_5 = data4_5
        this.data4_6 = data4_6
        this.data4_7 = data4_7
    }

    public func toGuidCtorArguments(): String {
        return "0x${hexU32(data1)}, 0x${hexU16(data2)}, 0x${hexU16(data3)}, 0x${hexU8(data4_0)}, 0x${hexU8(data4_1)}, 0x${hexU8(data4_2)}, 0x${hexU8(data4_3)}, 0x${hexU8(data4_4)}, 0x${hexU8(data4_5)}, 0x${hexU8(data4_6)}, 0x${hexU8(data4_7)}"
    }

    public func toGuidText(): String {
        return "${hexU32(data1)}-${hexU16(data2)}-${hexU16(data3)}-${hexU8(data4_0)}${hexU8(data4_1)}-${hexU8(data4_2)}${hexU8(data4_3)}${hexU8(data4_4)}${hexU8(data4_5)}${hexU8(data4_6)}${hexU8(data4_7)}"
    }
}

public interface GuidAttributeExt <: HasAttributes {
    func guidAttribute(): Option<GuidParts> {
        match (findAttribute("GuidAttribute")) {
            case Some(attrRow) =>
                let values = attributeIndex().attributeValues(attributeFileIdx(), attrRow)
                if (values.size < 11) {
                    return None
                }
                return Some(GuidParts(
                    guidValueToU32(values[0][1]),
                    guidValueToU16(values[1][1]),
                    guidValueToU16(values[2][1]),
                    guidValueToU8(values[3][1]),
                    guidValueToU8(values[4][1]),
                    guidValueToU8(values[5][1]),
                    guidValueToU8(values[6][1]),
                    guidValueToU8(values[7][1]),
                    guidValueToU8(values[8][1]),
                    guidValueToU8(values[9][1]),
                    guidValueToU8(values[10][1])
                ))
            case None =>
                return None
        }
    }

    func guidAttributeLiteral(): Option<String> {
        match (guidAttribute()) {
            case Some(guid) => return Some(guid.toGuidCtorArguments())
            case None => return None
        }
    }

    func guidAttributeText(): Option<String> {
        match (guidAttribute()) {
            case Some(guid) => return Some(guid.toGuidText())
            case None => return None
        }
    }
}

extend TypeDefRef <: GuidAttributeExt {}
extend MethodDefRef <: GuidAttributeExt {}
extend FieldRef <: GuidAttributeExt {}
extend TypeSpec <: GuidAttributeExt {}

public func guidAttribute(index: TypeIndex, fileIdx: Int64, row: Int64): Option<GuidParts> {
    return TypeDefRef(index, fileIdx, row).guidAttribute()
}

public func guidAttributeLiteral(index: TypeIndex, fileIdx: Int64, row: Int64): Option<String> {
    return TypeDefRef(index, fileIdx, row).guidAttributeLiteral()
}

public func guidAttributeText(index: TypeIndex, fileIdx: Int64, row: Int64): Option<String> {
    return TypeDefRef(index, fileIdx, row).guidAttributeText()
}

func guidValueToU32(value: MetadataValue): UInt32 {
    match (value) {
        case MetadataValue.ValU32(v) => return v
        case MetadataValue.ValI32(v) => return UInt32(v)
        case _ => throw Exception("invalid GuidAttribute UInt32 component")
    }
}

func guidValueToU16(value: MetadataValue): UInt16 {
    match (value) {
        case MetadataValue.ValU16(v) => return v
        case MetadataValue.ValI16(v) => return UInt16(v)
        case _ => throw Exception("invalid GuidAttribute UInt16 component")
    }
}

func guidValueToU8(value: MetadataValue): UInt8 {
    match (value) {
        case MetadataValue.ValU8(v) => return v
        case MetadataValue.ValI8(v) => return UInt8(v)
        case _ => throw Exception("invalid GuidAttribute UInt8 component")
    }
}

func hexU32(v: UInt32): String {
    return padHexUpper(UInt64(v), 8)
}

func hexU16(v: UInt16): String {
    return padHexUpper(UInt64(v), 4)
}

func hexU8(v: UInt8): String {
    return padHexUpper(UInt64(v), 2)
}

func padHexUpper(value: UInt64, width: Int64): String {
    let hexChars = "0123456789ABCDEF".toArray()
    var result = Array<Byte>(width, {_ => b'0'})
    var v = value
    var i = width - 1
    while (i >= 0 && v > 0u64) {
        result[i] = hexChars[Int64(v & 0xFu64)]
        v = v >> 4
        i -= 1
    }
    return String.fromUtf8(result)
}
