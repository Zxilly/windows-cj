package windows_metadata

import std.collection.*

// Table indices used internally — these are logical indices into the File.tables array,
// NOT the ECMA-335 table numbers. Mapped from ECMA-335 numbers during parsing.
public let TABLE_ASSEMBLY: Int64 = 0
public let TABLE_ASSEMBLY_REF: Int64 = 1
public let TABLE_ATTRIBUTE: Int64 = 2
public let TABLE_CLASS_LAYOUT: Int64 = 3
public let TABLE_CONSTANT: Int64 = 4
public let TABLE_FIELD: Int64 = 5
public let TABLE_GENERIC_PARAM: Int64 = 6
public let TABLE_IMPL_MAP: Int64 = 7
public let TABLE_INTERFACE_IMPL: Int64 = 8
public let TABLE_MEMBER_REF: Int64 = 9
public let TABLE_METHOD_DEF: Int64 = 10
public let TABLE_METHOD_PARAM: Int64 = 11
public let TABLE_MODULE: Int64 = 12
public let TABLE_MODULE_REF: Int64 = 13
public let TABLE_NESTED_CLASS: Int64 = 14
public let TABLE_TYPE_DEF: Int64 = 15
public let TABLE_TYPE_REF: Int64 = 16
public let TABLE_TYPE_SPEC: Int64 = 17
public let TABLE_FIELD_LAYOUT: Int64 = 18
public let TABLE_COUNT: Int64 = 19

// Column describes one column within a metadata table row
public class Column {
    public var offset: Int64 = 0
    public var width: Int64 = 0

    public init() {}

    public init(offset: Int64, width: Int64) {
        this.offset = offset
        this.width = width
    }
}

// Table describes one metadata table: its data offset, row count, row width, and column layout
public class Table {
    public var offset: Int64 = 0
    public var len: Int64 = 0
    public var width: Int64 = 0
    public var columns: Array<Column> = Array<Column>(6, {_ => Column()})

    public init() {}

    public func indexWidth(): Int64 {
        if (this.len < (1 << 16)) {
            return 2
        } else {
            return 4
        }
    }

    public func setColumns(a: Int64, b: Int64, c: Int64, d: Int64, e: Int64, f: Int64): Unit {
        this.width = a + b + c + d + e + f
        this.columns[0] = Column(0, a)
        if (b != 0) {
            this.columns[1] = Column(a, b)
        }
        if (c != 0) {
            this.columns[2] = Column(a + b, c)
        }
        if (d != 0) {
            this.columns[3] = Column(a + b + c, d)
        }
        if (e != 0) {
            this.columns[4] = Column(a + b + c + d, e)
        }
        if (f != 0) {
            this.columns[5] = Column(a + b + c + d + e, f)
        }
    }

    // Set data offset and advance the view pointer
    public func setData(view: Int64): Int64 {
        if (this.len != 0) {
            this.offset = view
            return view + this.len * this.width
        }
        return view
    }
}

// Compute coded index column width.
// A coded index can refer to multiple tables; we need enough bits for the tag
// plus enough range for the largest table's row count.
public func codedIndexSize(tableLens: Array<Int64>): Int64 {
    let numTables = tableLens.size
    let bitsNeeded = bitsForCount(Int64(numTables))

    var allSmall = true
    for (tl in tableLens) {
        if (!isSmall(tl, bitsNeeded)) {
            allSmall = false
        }
    }
    if (allSmall) {
        return 2
    } else {
        return 4
    }
}

func isSmall(rowCount: Int64, bits: Int64): Bool {
    return rowCount < (1 << (16 - bits))
}

func bitsForCount(value: Int64): Int64 {
    var v = value - 1
    var bits: Int64 = 1
    v = v >> 1
    while (v != 0) {
        bits += 1
        v = v >> 1
    }
    return bits
}

// --- Coded Index Decoding ---

// Decode a coded index value into (tableIndex, row).
// tagBits: number of bits for the tag
// tableMap: maps tag value -> logical table index
public func decodeCodedIndex(value: Int64, tagBits: Int64, tableMap: Array<Int64>): (Int64, Int64) {
    let mask = (1 << tagBits) - 1
    let tag = value & mask
    let row = (value >> tagBits) - 1
    return (tableMap[tag], row)
}

// Encode a coded index from table tag and row
public func encodeCodedIndex(tag: Int64, row: Int64, tagBits: Int64): Int64 {
    return ((row + 1) << tagBits) | tag
}

// --- Coded Index Type Constants ---

// TypeDefOrRef: 2-bit tag
// 0=TypeDef, 1=TypeRef, 2=TypeSpec
public let CODED_TYPE_DEF_OR_REF_BITS: Int64 = 2
public let CODED_TYPE_DEF_OR_REF_MAP: Array<Int64> = [TABLE_TYPE_DEF, TABLE_TYPE_REF, TABLE_TYPE_SPEC]

// HasConstant: 2-bit tag
// 0=Field, 1=Param, 2=Property
public let CODED_HAS_CONSTANT_BITS: Int64 = 2
public let CODED_HAS_CONSTANT_MAP: Array<Int64> = [TABLE_FIELD, TABLE_METHOD_PARAM, -1]

// HasCustomAttribute: 5-bit tag (21 possible tables)
public let CODED_HAS_CUSTOM_ATTRIBUTE_BITS: Int64 = 5
public let CODED_HAS_CUSTOM_ATTRIBUTE_MAP: Array<Int64> = [
    TABLE_METHOD_DEF,
    TABLE_FIELD,
    TABLE_TYPE_REF,
    TABLE_TYPE_DEF,
    TABLE_METHOD_PARAM,
    TABLE_INTERFACE_IMPL,
    TABLE_MEMBER_REF,
    TABLE_MODULE,
    -1,
    -1,
    -1,
    TABLE_MODULE_REF,
    TABLE_TYPE_SPEC,
    TABLE_ASSEMBLY,
    TABLE_ASSEMBLY_REF,
    -1,
    -1,
    -1,
    TABLE_GENERIC_PARAM,
    -1,
    -1
]

// CustomAttributeType: 3-bit tag
// 0=unused, 1=unused, 2=MethodDef, 3=MemberRef, 4=unused
public let CODED_CUSTOM_ATTRIBUTE_TYPE_BITS: Int64 = 3
public let CODED_CUSTOM_ATTRIBUTE_TYPE_MAP: Array<Int64> = [-1, -1, TABLE_METHOD_DEF, TABLE_MEMBER_REF, -1]

// MemberRefParent: 3-bit tag
// 0=TypeDef, 1=TypeRef, 2=ModuleRef, 3=MethodDef, 4=TypeSpec
public let CODED_MEMBER_REF_PARENT_BITS: Int64 = 3
public let CODED_MEMBER_REF_PARENT_MAP: Array<Int64> = [TABLE_TYPE_DEF, TABLE_TYPE_REF, TABLE_MODULE_REF, TABLE_METHOD_DEF, TABLE_TYPE_SPEC]

// MemberForwarded: 1-bit tag
// 0=Field, 1=MethodDef
public let CODED_MEMBER_FORWARDED_BITS: Int64 = 1
public let CODED_MEMBER_FORWARDED_MAP: Array<Int64> = [TABLE_FIELD, TABLE_METHOD_DEF]

// TypeOrMethodDef: 1-bit tag
// 0=TypeDef, 1=MethodDef
public let CODED_TYPE_OR_METHOD_DEF_BITS: Int64 = 1
public let CODED_TYPE_OR_METHOD_DEF_MAP: Array<Int64> = [TABLE_TYPE_DEF, TABLE_METHOD_DEF]

// ResolutionScope: 2-bit tag
// 0=Module, 1=ModuleRef, 2=AssemblyRef, 3=TypeRef
public let CODED_RESOLUTION_SCOPE_BITS: Int64 = 2
public let CODED_RESOLUTION_SCOPE_MAP: Array<Int64> = [TABLE_MODULE, TABLE_MODULE_REF, TABLE_ASSEMBLY_REF, TABLE_TYPE_REF]

// Implementation: 2-bit tag
// 0=File, 1=AssemblyRef, 2=ExportedType
public let CODED_IMPLEMENTATION_BITS: Int64 = 2

// HasFieldMarshal: 1-bit tag
// 0=Field, 1=Param
public let CODED_HAS_FIELD_MARSHAL_BITS: Int64 = 1

// HasDeclSecurity: 2-bit tag
// 0=TypeDef, 1=MethodDef, 2=Assembly
public let CODED_HAS_DECL_SECURITY_BITS: Int64 = 2

// HasSemantics: 1-bit tag
public let CODED_HAS_SEMANTICS_BITS: Int64 = 1

// MethodDefOrRef: 1-bit tag
public let CODED_METHOD_DEF_OR_REF_BITS: Int64 = 1

public func hasCustomAttributeTag(table: Int64): Option<Int64> {
    var tag: Int64 = 0
    while (tag < Int64(CODED_HAS_CUSTOM_ATTRIBUTE_MAP.size)) {
        if (CODED_HAS_CUSTOM_ATTRIBUTE_MAP[tag] == table) {
            return Some(tag)
        }
        tag += 1
    }
    return None
}

public func encodeHasCustomAttribute(table: Int64, row: Int64): Option<Int64> {
    match (hasCustomAttributeTag(table)) {
        case Some(tag) => return Some(encodeCodedIndex(tag, row, CODED_HAS_CUSTOM_ATTRIBUTE_BITS))
        case None => return None
    }
}
