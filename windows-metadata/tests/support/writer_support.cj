package __SMOKE_PACKAGE__

import std.collection.*
import windows_metadata.*

// BlobWriter encodes the subset of metadata blobs needed by the metadata smoke tests.
class BlobWriter {
    var bytes: ArrayList<Byte>

    public init() {
        this.bytes = ArrayList<Byte>()
    }

    func appendByte(value: UInt8): Unit {
        bytes.add(value)
    }

    public func writeCompressed(value: Int64): Unit {
        if (value < 0) {
            throw Exception("negative compressed integer")
        }
        if (value > 0x1FFFFFFF) {
            throw Exception("compressed integer exceeds 29-bit maximum")
        }

        if (value < 0x80) {
            appendByte(UInt8(value))
        } else if (value < 0x4000) {
            appendByte(UInt8(((value >> 8) & 0x3f) | 0x80))
            appendByte(UInt8(value & 0xff))
        } else {
            appendByte(UInt8(((value >> 24) & 0x1f) | 0xc0))
            appendByte(UInt8((value >> 16) & 0xff))
            appendByte(UInt8((value >> 8) & 0xff))
            appendByte(UInt8(value & 0xff))
        }
    }

    public func writeBool(value: Bool): Unit {
        appendByte(if (value) { 1u8 } else { 0u8 })
    }

    public func writeI32(value: Int32): Unit {
        let raw = UInt32(value)
        appendByte(UInt8(raw & 0xffu32))
        appendByte(UInt8((raw >> 8) & 0xffu32))
        appendByte(UInt8((raw >> 16) & 0xffu32))
        appendByte(UInt8((raw >> 24) & 0xffu32))
    }

    public func writeUtf8(value: String): Unit {
        let data = value.toArray()
        writeCompressed(Int64(data.size))
        for (b in data) {
            appendByte(b)
        }
    }

    public func writeTypeCode(ty: MetadataType): Unit {
        match (ty) {
            case MetadataType.Void => appendByte(ELEMENT_TYPE_VOID)
            case MetadataType.Boolean => appendByte(ELEMENT_TYPE_BOOLEAN)
            case MetadataType.Char => appendByte(ELEMENT_TYPE_CHAR)
            case MetadataType.I8 => appendByte(ELEMENT_TYPE_I1)
            case MetadataType.U8 => appendByte(ELEMENT_TYPE_U1)
            case MetadataType.I16 => appendByte(ELEMENT_TYPE_I2)
            case MetadataType.U16 => appendByte(ELEMENT_TYPE_U2)
            case MetadataType.I32 => appendByte(ELEMENT_TYPE_I4)
            case MetadataType.U32 => appendByte(ELEMENT_TYPE_U4)
            case MetadataType.I64 => appendByte(ELEMENT_TYPE_I8)
            case MetadataType.U64 => appendByte(ELEMENT_TYPE_U8)
            case MetadataType.F32 => appendByte(ELEMENT_TYPE_R4)
            case MetadataType.F64 => appendByte(ELEMENT_TYPE_R8)
            case MetadataType.ISize => appendByte(ELEMENT_TYPE_I)
            case MetadataType.USize => appendByte(ELEMENT_TYPE_U)
            case MetadataType.MdString => appendByte(ELEMENT_TYPE_STRING)
            case MetadataType.MdObject => appendByte(ELEMENT_TYPE_OBJECT)
            case MetadataType.RefMut(inner) =>
                appendByte(ELEMENT_TYPE_BYREF)
                writeTypeCode(inner)
            case MetadataType.RefConst(inner) =>
                appendByte(ELEMENT_TYPE_BYREF)
                writeTypeCode(inner)
            case MetadataType.MdArray(inner) =>
                appendByte(ELEMENT_TYPE_SZARRAY)
                writeTypeCode(inner)
            case MetadataType.Packed(inner, _) =>
                writeTypeCode(inner)
            case MetadataType.ClassName(_) =>
                throw Exception("unsupported composite metadata type for writer")
            case MetadataType.ValueName(_) =>
                throw Exception("unsupported composite metadata type for writer")
            case MetadataType.Union(_) =>
                throw Exception("unsupported composite metadata type for writer")
            case MetadataType.Generic(_, _) =>
                throw Exception("unsupported composite metadata type for writer")
            case MetadataType.PtrMut(_, _) =>
                throw Exception("unsupported composite metadata type for writer")
            case MetadataType.PtrConst(_, _) =>
                throw Exception("unsupported composite metadata type for writer")
            case MetadataType.ArrayFixed(_, _) =>
                throw Exception("unsupported composite metadata type for writer")
        }
    }

    public func writeMetadataValue(value: MetadataValue, ty: MetadataType): Unit {
        match (value) {
            case MetadataValue.ValBool(v) =>
                match (ty) {
                    case MetadataType.Boolean => writeBool(v)
                    case _ => throw Exception("boolean value type mismatch")
                }
            case MetadataValue.ValI32(v) =>
                match (ty) {
                    case MetadataType.I32 => writeI32(v)
                    case _ => throw Exception("i32 value type mismatch")
                }
            case MetadataValue.ValUtf8(v) =>
                match (ty) {
                    case MetadataType.MdString => writeUtf8(v)
                    case _ => throw Exception("utf8 value type mismatch")
                }
            case _ =>
                throw Exception("unsupported metadata value for writer")
        }
    }

    public func toBytes(): Array<Byte> {
        return Array<Byte>(bytes.size, { idx => bytes[idx] })
    }
}

func encodeCompressedInt(value: Int64): Array<Byte> {
    let writer = BlobWriter()
    writer.writeCompressed(value)
    return writer.toBytes()
}

func encodeTypeSignature(ty: MetadataType): Array<Byte> {
    let writer = BlobWriter()
    writer.writeTypeCode(ty)
    return writer.toBytes()
}

func encodeMetadataValue(value: MetadataValue, ty: MetadataType): Array<Byte> {
    let writer = BlobWriter()
    writer.writeMetadataValue(value, ty)
    return writer.toBytes()
}
