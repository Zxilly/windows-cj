package windows_metadata

import std.collection.*

// BlobReader — reads compressed integers and type signatures from a blob slice
public class BlobReader {
    public let bytes: Array<Byte>
    public var offset: Int64
    public var remaining: Int64

    public init(bytes: Array<Byte>, offset: Int64, size: Int64) {
        this.bytes = bytes
        this.offset = offset
        this.remaining = size
    }

    public func len(): Int64 {
        return remaining
    }

    func advance(count: Int64): Unit {
        offset += count
        remaining -= count
    }

    // Peek at compressed unsigned integer without advancing
    func peek(): (Int64, Int64) {
        let b0 = UInt8(bytes[offset])
        if ((Int64(b0) & 0x80) == 0) {
            return (Int64(b0), 1)
        } else if ((Int64(b0) & 0xC0) == 0x80) {
            let b1 = UInt8(bytes[offset + 1])
            return (((Int64(b0) & 0x3F) << 8) | Int64(b1), 2)
        } else {
            let b1 = UInt8(bytes[offset + 1])
            let b2 = UInt8(bytes[offset + 2])
            let b3 = UInt8(bytes[offset + 3])
            return (((Int64(b0) & 0x1F) << 24) | (Int64(b1) << 16) | (Int64(b2) << 8) | Int64(b3), 4)
        }
    }

    // Read a compressed unsigned integer (ECMA-335 §II.23.2)
    public func readCompressed(): Int64 {
        let (value, size) = peek()
        advance(size)
        return value
    }

    // Try to read an expected compressed value; returns true if matched
    public func tryRead(expected: Int64): Bool {
        let (value, size) = peek()
        if (value == expected) {
            advance(size)
            return true
        }
        return false
    }

    public func readU8(): UInt8 {
        let v = UInt8(bytes[offset])
        advance(1)
        return v
    }

    public func readI8(): Int8 {
        let v = Int8(bytes[offset])
        advance(1)
        return v
    }

    public func readU16(): UInt16 {
        let b0 = UInt16(UInt8(bytes[offset]))
        let b1 = UInt16(UInt8(bytes[offset + 1]))
        let v = b0 | (b1 << 8)
        advance(2)
        return v
    }

    public func readI16(): Int16 {
        let v = Int16(readU16())
        return v
    }

    public func readU32(): UInt32 {
        let b0 = UInt32(UInt8(bytes[offset]))
        let b1 = UInt32(UInt8(bytes[offset + 1]))
        let b2 = UInt32(UInt8(bytes[offset + 2]))
        let b3 = UInt32(UInt8(bytes[offset + 3]))
        let v = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        advance(4)
        return v
    }

    public func readI32(): Int32 {
        return Int32(readU32())
    }

    public func readU64(): UInt64 {
        let lo = UInt64(readU32())
        let hi = UInt64(readU32())
        return lo | (hi << 32)
    }

    public func readI64(): Int64 {
        return Int64(readU64())
    }

    public func readF32(): Float32 {
        let bits = readU32()
        return Float32.fromBits(bits)
    }

    public func readF64(): Float64 {
        let bits = readU64()
        return Float64.fromBits(bits)
    }

    public func readBool(): Bool {
        let v = readU8()
        if (v == 0u8) {
            return false
        } else if (v == 1u8) {
            return true
        } else {
            throw Exception("Invalid bool value in blob: ${v}")
        }
    }

    // Read a UTF-8 string prefixed by compressed length
    public func readUtf8(): String {
        let strLen = readCompressed()
        if (strLen == 0) {
            return ""
        }
        let arr = bytes[offset..offset + strLen]
        advance(strLen)
        return String.fromUtf8(arr)
    }

    // Read a UTF-16LE string (uses all remaining bytes)
    public func readUtf16(): String {
        let byteLen = remaining
        let charCount = byteLen / 2
        let units = Array<UInt16>(charCount, {i =>
            let off = offset + i * 2
            let b0 = UInt16(UInt8(bytes[off]))
            let b1 = UInt16(UInt8(bytes[off + 1]))
            b0 | (b1 << 8)
        })
        advance(byteLen)
        var result = ""
        var index: Int64 = 0
        while (index < Int64(units.size)) {
            let unit = units[index]
            if (unit >= 0xD800u16 && unit <= 0xDBFFu16) {
                if (index + 1 < Int64(units.size)) {
                    let low = units[index + 1]
                    if (low >= 0xDC00u16 && low <= 0xDFFFu16) {
                        let codePoint = 0x10000u32 + ((UInt32(unit) - 0xD800u32) << 10) + (UInt32(low) - 0xDC00u32)
                        result += "${Rune(codePoint)}"
                        index += 2
                    } else {
                        result += "${Rune(0xFFFDu32)}"
                        index += 1
                    }
                } else {
                    result += "${Rune(0xFFFDu32)}"
                    index += 1
                }
            } else if (unit >= 0xDC00u16 && unit <= 0xDFFFu16) {
                result += "${Rune(0xFFFDu32)}"
                index += 1
            } else {
                result += "${Rune(UInt32(unit))}"
                index += 1
            }
        }
        return result
    }

    // Read modifiers (CMOD_OPT / CMOD_REQD) and return decoded TypeDefOrRef indices
    // Returns list of (table, row) pairs
    public func readModifiers(): ArrayList<(Int64, Int64)> {
        var mods = ArrayList<(Int64, Int64)>()
        while (true) {
            let (value, size) = peek()
            if (value != Int64(ELEMENT_TYPE_CMOD_OPT) && value != Int64(ELEMENT_TYPE_CMOD_REQD)) {
                break
            }
            advance(size)
            let coded = readCompressed()
            mods.add(decodeCodedIndex(coded, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP))
        }
        return mods
    }

    // Check if a modifier refers to System.Runtime.CompilerServices.IsConst
    public func isConstModifier(file: WinmdFile, table: Int64, row: Int64): Bool {
        if (table == TABLE_TYPE_DEF) {
            let ns = file.getString(row, TABLE_TYPE_DEF, 2)
            let nm = file.getString(row, TABLE_TYPE_DEF, 1)
            return ns == "System.Runtime.CompilerServices" && nm == "IsConst"
        } else if (table == TABLE_TYPE_REF) {
            let ns = file.getString(row, TABLE_TYPE_REF, 2)
            let nm = file.getString(row, TABLE_TYPE_REF, 1)
            return ns == "System.Runtime.CompilerServices" && nm == "IsConst"
        }
        return false
    }

    // Read a method signature
    public func readMethodSignature(file: WinmdFile, generics: Array<MetadataType>): MethodSignature {
        let sig = MethodSignature()
        sig.flags = readU8()
        let paramCount = readCompressed()
        sig.returnType = readTypeSignature(file, generics)
        var pi: Int64 = 0
        while (pi < paramCount) {
            sig.paramTypes.add(readTypeSignature(file, generics))
            pi += 1
        }
        return sig
    }

    // Read a full type signature (handles modifiers, BYREF, SZARRAY, PTR)
    public func readTypeSignature(file: WinmdFile, generics: Array<MetadataType>): MetadataType {
        let mods = readModifiers()
        var isConst = false
        for (m in mods) {
            if (isConstModifier(file, m[0], m[1])) {
                isConst = true
            }
        }

        let isRef = tryRead(Int64(ELEMENT_TYPE_BYREF))

        if (tryRead(Int64(ELEMENT_TYPE_VOID))) {
            return MetadataType.Void
        }

        let isArray = tryRead(Int64(ELEMENT_TYPE_SZARRAY))

        var pointers: Int64 = 0
        while (tryRead(Int64(ELEMENT_TYPE_PTR))) {
            pointers += 1
        }

        let ty = readTypeCode(file, generics)

        if (pointers > 0) {
            var ptr: MetadataType = if (isConst) {
                MetadataType.PtrConst(ty, pointers)
            } else {
                MetadataType.PtrMut(ty, pointers)
            }
            if (isArray) {
                return MetadataType.MdArray(ptr)
            }
            return ptr
        } else if (isConst) {
            return MetadataType.RefConst(ty)
        } else if (isArray) {
            let arrTy = MetadataType.MdArray(ty)
            if (isRef) {
                return MetadataType.RefMut(arrTy)
            }
            return arrTy
        } else if (isRef) {
            return MetadataType.RefMut(ty)
        }
        return ty
    }

    // Read an ELEMENT_TYPE code and return the corresponding MetadataType
    public func readTypeCode(file: WinmdFile, generics: Array<MetadataType>): MetadataType {
        let code = readU8()

        if (code == ELEMENT_TYPE_VOID) { return MetadataType.Void }
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
        if (code == ELEMENT_TYPE_OBJECT) { return MetadataType.MdObject }

        if (code == ELEMENT_TYPE_VALUETYPE || code == ELEMENT_TYPE_CLASS) {
            let coded = readCompressed()
            let (tdrTable, tdrRow) = decodeCodedIndex(coded, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)

            // If it's a TypeSpec, recursively parse its full signature
            if (tdrTable == TABLE_TYPE_SPEC) {
                var specBlob = file.getBlob(tdrRow, TABLE_TYPE_SPEC, 0)
                return specBlob.readTypeSignature(file, generics)
            }

            var ns = ""
            var nm = ""
            if (tdrTable == TABLE_TYPE_DEF) {
                ns = file.getString(tdrRow, TABLE_TYPE_DEF, 2)
                nm = file.getString(tdrRow, TABLE_TYPE_DEF, 1)
            } else if (tdrTable == TABLE_TYPE_REF) {
                ns = file.getString(tdrRow, TABLE_TYPE_REF, 2)
                nm = file.getString(tdrRow, TABLE_TYPE_REF, 1)
            }

            if (code == ELEMENT_TYPE_VALUETYPE) {
                return MetadataType.ValueName(TypeName.named(ns, nm))
            } else {
                return MetadataType.ClassName(TypeName.named(ns, nm))
            }
        }

        if (code == ELEMENT_TYPE_VAR) {
            let idx = readCompressed()
            if (idx < Int64(generics.size)) {
                return generics[idx]
            }
            return MetadataType.Generic("T${idx}", UInt16(idx))
        }

        if (code == ELEMENT_TYPE_ARRAY) {
            // ELEMENT_TYPE_ARRAY with ArrayShape (II.23.2.13)
            let elemTy = readTypeSignature(file, generics)
            let rank = readCompressed()
            if (rank != 1) {
                throw Exception("Unsupported ELEMENT_TYPE_ARRAY rank: ${rank}")
            }
            let numSizes = readCompressed()
            if (numSizes != 1) {
                throw Exception("Unsupported ELEMENT_TYPE_ARRAY size count: ${numSizes}")
            }
            let arraySize = readCompressed()
            var si2: Int64 = 1
            while (si2 < numSizes) {
                readCompressed()
                si2 += 1
            }
            let numLoBounds = readCompressed()
            if (numLoBounds != 0 && numLoBounds != 1) {
                throw Exception("Unsupported ELEMENT_TYPE_ARRAY lower bound count: ${numLoBounds}")
            }
            var li: Int64 = 0
            while (li < numLoBounds) {
                let loBound = readCompressed()
                if (loBound != 0) {
                    throw Exception("Unsupported ELEMENT_TYPE_ARRAY lower bound: ${loBound}")
                }
                li += 1
            }
            return MetadataType.ArrayFixed(elemTy, arraySize)
        }

        if (code == ELEMENT_TYPE_GENERICINST) {
            let typeCode = readU8()
            if (typeCode != ELEMENT_TYPE_VALUETYPE && typeCode != ELEMENT_TYPE_CLASS) {
                throw Exception("Invalid ELEMENT_TYPE_GENERICINST type code: ${typeCode}")
            }
            let coded = readCompressed()
            let (tdrTable, tdrRow) = decodeCodedIndex(coded, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)

            var ns = ""
            var nm = ""
            if (tdrTable == TABLE_TYPE_DEF) {
                ns = file.getString(tdrRow, TABLE_TYPE_DEF, 2)
                nm = file.getString(tdrRow, TABLE_TYPE_DEF, 1)
            } else if (tdrTable == TABLE_TYPE_REF) {
                ns = file.getString(tdrRow, TABLE_TYPE_REF, 2)
                nm = file.getString(tdrRow, TABLE_TYPE_REF, 1)
            } else if (tdrTable == TABLE_TYPE_SPEC) {
                throw Exception("Unsupported ELEMENT_TYPE_GENERICINST TypeSpec base")
            } else {
                throw Exception("Unsupported ELEMENT_TYPE_GENERICINST TypeDefOrRef table: ${tdrTable}")
            }

            let genCount = readCompressed()
            var tyGenerics = ArrayList<MetadataType>()
            var gi: Int64 = 0
            while (gi < genCount) {
                tyGenerics.add(readTypeCode(file, generics))
                gi += 1
            }

            let tn = TypeName(ns, nm, tyGenerics)
            if (typeCode == ELEMENT_TYPE_VALUETYPE) {
                return MetadataType.ValueName(tn)
            } else {
                return MetadataType.ClassName(tn)
            }
        }

        // 0x55 = SERIALIZATION_TYPE_ENUM
        if (code == 0x55u8) {
            let enumName = readUtf8()
            match (enumName.indexOf(".", 0)) {
                case None => return MetadataType.ValueName(TypeName.named("", enumName))
                case Some(_) =>
                    // Find LAST dot
                    var lastDot: Int64 = -1
                    let enumArr = enumName.toArray()
                    var ci: Int64 = 0
                    while (ci < Int64(enumArr.size)) {
                        if (enumArr[ci] == b'.') { // '.'
                            lastDot = ci
                        }
                        ci += 1
                    }
                    if (lastDot >= 0) {
                        let ns2 = String.fromUtf8(enumArr[0..lastDot])
                        let nm2 = String.fromUtf8(enumArr[lastDot + 1..Int64(enumArr.size)])
                        return MetadataType.ValueName(TypeName.named(ns2, nm2))
                    }
                    return MetadataType.ValueName(TypeName.named("", enumName))
            }
        }

        throw Exception("Unknown ELEMENT_TYPE: ${code}")
    }

    public func readCustomAttributeValues(file: WinmdFile, signature: MethodSignature): ArrayList<(String, MetadataValue)> {
        let prolog = readU16()
        if (prolog != 1u16) {
            throw Exception("Invalid custom attribute blob prolog: ${prolog}")
        }

        let values = ArrayList<(String, MetadataValue)>()
        for (ty in signature.paramTypes) {
            values.add(("", readMetadataValue(this, ty)))
        }

        let namedArgCount = readU16()
        var i: Int64 = 0
        while (i < Int64(namedArgCount)) {
            let kind = readU8()
            if (kind != 0x53u8 && kind != 0x54u8) {
                throw Exception("Invalid custom attribute named argument kind: ${kind}")
            }
            let ty = readTypeCode(file, Array<MetadataType>())
            let name = readUtf8()
            let value = readMetadataValue(this, ty)
            values.add((name, value))
            i += 1
        }

        return values
    }
}

public func readCustomAttributeValues(blob: BlobReader, file: WinmdFile, signature: MethodSignature): ArrayList<(String, MetadataValue)> {
    return blob.readCustomAttributeValues(file, signature)
}

// Read an attribute value from a blob given its type
public func readMetadataValue(blob: BlobReader, ty: MetadataType): MetadataValue {
    match (ty) {
        case MetadataType.Boolean => MetadataValue.ValBool(blob.readBool())
        case MetadataType.I8 => MetadataValue.ValI8(blob.readI8())
        case MetadataType.U8 => MetadataValue.ValU8(blob.readU8())
        case MetadataType.I16 => MetadataValue.ValI16(blob.readI16())
        case MetadataType.U16 => MetadataValue.ValU16(blob.readU16())
        case MetadataType.I32 => MetadataValue.ValI32(blob.readI32())
        case MetadataType.U32 => MetadataValue.ValU32(blob.readU32())
        case MetadataType.I64 => MetadataValue.ValI64(blob.readI64())
        case MetadataType.U64 => MetadataValue.ValU64(blob.readU64())
        case MetadataType.F32 => MetadataValue.ValF32(blob.readF32())
        case MetadataType.F64 => MetadataValue.ValF64(blob.readF64())
        case MetadataType.MdString => MetadataValue.ValUtf8(blob.readUtf8())
        case MetadataType.ClassName(tn) =>
            if (tn.matches("System", "Type")) {
                let s = blob.readUtf8()
                let sArr = s.toArray()
                var lastDot: Int64 = -1
                var si: Int64 = 0
                while (si < Int64(sArr.size)) {
                    if (sArr[si] == b'.') {
                        lastDot = si
                    }
                    si += 1
                }
                if (lastDot >= 0) {
                    MetadataValue.ValTypeName(TypeName.named(
                        String.fromUtf8(sArr[0..lastDot]),
                        String.fromUtf8(sArr[lastDot + 1..Int64(sArr.size)])
                    ))
                } else {
                    MetadataValue.ValTypeName(TypeName.named("", s))
                }
            } else {
                MetadataValue.ValEnum(tn, readMetadataValue(blob, MetadataType.I32))
            }
        case MetadataType.ValueName(tn) =>
            MetadataValue.ValEnum(tn, readMetadataValue(blob, MetadataType.I32))
        case _ => throw Exception("Unsupported attribute value type")
    }
}
