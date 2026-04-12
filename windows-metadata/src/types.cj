package windows_metadata

import std.collection.*

// ELEMENT_TYPE constants from ECMA-335 §II.23.1.16
public let ELEMENT_TYPE_VOID: UInt8 = 1
public let ELEMENT_TYPE_BOOLEAN: UInt8 = 2
public let ELEMENT_TYPE_CHAR: UInt8 = 3
public let ELEMENT_TYPE_I1: UInt8 = 4
public let ELEMENT_TYPE_U1: UInt8 = 5
public let ELEMENT_TYPE_I2: UInt8 = 6
public let ELEMENT_TYPE_U2: UInt8 = 7
public let ELEMENT_TYPE_I4: UInt8 = 8
public let ELEMENT_TYPE_U4: UInt8 = 9
public let ELEMENT_TYPE_I8: UInt8 = 10
public let ELEMENT_TYPE_U8: UInt8 = 11
public let ELEMENT_TYPE_R4: UInt8 = 12
public let ELEMENT_TYPE_R8: UInt8 = 13
public let ELEMENT_TYPE_STRING: UInt8 = 14
public let ELEMENT_TYPE_PTR: UInt8 = 15
public let ELEMENT_TYPE_BYREF: UInt8 = 16
public let ELEMENT_TYPE_VALUETYPE: UInt8 = 17
public let ELEMENT_TYPE_CLASS: UInt8 = 18
public let ELEMENT_TYPE_VAR: UInt8 = 19
public let ELEMENT_TYPE_ARRAY: UInt8 = 20
public let ELEMENT_TYPE_GENERICINST: UInt8 = 21
public let ELEMENT_TYPE_I: UInt8 = 24
public let ELEMENT_TYPE_U: UInt8 = 25
public let ELEMENT_TYPE_OBJECT: UInt8 = 28
public let ELEMENT_TYPE_SZARRAY: UInt8 = 29
public let ELEMENT_TYPE_CMOD_REQD: UInt8 = 31
public let ELEMENT_TYPE_CMOD_OPT: UInt8 = 32

public struct TypeDefKey <: Hashable & Equatable<TypeDefKey> & Comparable<TypeDefKey> {
    public let fileIdx: Int64
    public let row: Int64

    public init(fileIdx: Int64, row: Int64) {
        this.fileIdx = fileIdx
        this.row = row
    }

    public operator func ==(other: TypeDefKey): Bool {
        fileIdx == other.fileIdx && row == other.row
    }

    public operator func !=(other: TypeDefKey): Bool {
        !(this == other)
    }

    public func hashCode(): Int64 {
        var hasher = DefaultHasher()
        hasher.write(fileIdx)
        hasher.write(row)
        hasher.finish()
    }

    public func compare(other: TypeDefKey): Ordering {
        let fileOrdering = fileIdx.compare(other.fileIdx)
        if (fileOrdering != Ordering.EQ) {
            return fileOrdering
        }
        return row.compare(other.row)
    }
}

public struct TableRowKey <: Hashable & Equatable<TableRowKey> & Comparable<TableRowKey> {
    public let table: Int64
    public let fileIdx: Int64
    public let row: Int64

    public init(table: Int64, fileIdx: Int64, row: Int64) {
        this.table = table
        this.fileIdx = fileIdx
        this.row = row
    }

    public operator func ==(other: TableRowKey): Bool {
        table == other.table && fileIdx == other.fileIdx && row == other.row
    }

    public operator func !=(other: TableRowKey): Bool {
        !(this == other)
    }

    public func hashCode(): Int64 {
        var hasher = DefaultHasher()
        hasher.write(table)
        hasher.write(fileIdx)
        hasher.write(row)
        hasher.finish()
    }

    public func compare(other: TableRowKey): Ordering {
        let tableOrdering = table.compare(other.table)
        if (tableOrdering != Ordering.EQ) {
            return tableOrdering
        }
        let fileOrdering = fileIdx.compare(other.fileIdx)
        if (fileOrdering != Ordering.EQ) {
            return fileOrdering
        }
        return row.compare(other.row)
    }
}

// TypeName holds a qualified type name with optional generic arguments
public class TypeName <: Hashable & Equatable<TypeName> & Comparable<TypeName> & ToString {
    public let namespace: String
    public let name: String
    public let generics: ArrayList<MetadataType>

    public init(namespace: String, name: String) {
        this.namespace = namespace
        this.name = name
        this.generics = ArrayList<MetadataType>()
    }

    public init(namespace: String, name: String, generics: ArrayList<MetadataType>) {
        this.namespace = namespace
        this.name = name
        this.generics = generics
    }

    public static func named(namespace: String, name: String): TypeName {
        return TypeName(namespace, name)
    }

    public operator func ==(other: TypeName): Bool {
        return namespace == other.namespace &&
            name == other.name &&
            metadataTypeListEquals(generics, other.generics)
    }

    public operator func !=(other: TypeName): Bool {
        return !(this == other)
    }

    public func hashCode(): Int64 {
        var hasher = DefaultHasher()
        hasher = writeStringHash(hasher, namespace)
        hasher = writeStringHash(hasher, name)
        hasher.write(Int64(generics.size))
        for (generic in generics) {
            hasher = writeStringHash(hasher, metadataTypeStableKey(generic))
        }
        return hasher.finish()
    }

    public func compare(other: TypeName): Ordering {
        let namespaceOrdering = namespace.compare(other.namespace)
        if (namespaceOrdering != Ordering.EQ) {
            return namespaceOrdering
        }

        let nameOrdering = name.compare(other.name)
        if (nameOrdering != Ordering.EQ) {
            return nameOrdering
        }

        return metadataTypeListStableKey(generics).compare(metadataTypeListStableKey(other.generics))
    }

    public func toString(): String {
        let qualified = if (namespace.isEmpty()) {
            name
        } else {
            "${namespace}.${name}"
        }
        if (generics.isEmpty()) {
            return qualified
        }

        let genericParts = ArrayList<String>()
        for (generic in generics) {
            genericParts.add(metadataTypeStableKey(generic))
        }
        return "${qualified}<${joinTypeNameParts(genericParts)}>"
    }

    public func definition(): TypeName {
        return TypeName.named(namespace, trimTick(name))
    }

    public func definitionMatches(ns: String, n: String): Bool {
        return namespace == ns && trimTick(name) == n
    }

    public func matches(ns: String, n: String): Bool {
        if (namespace.isEmpty()) {
            return trimTick(name) == n
        }
        return namespace == ns && trimTick(name) == n
    }
}

// MetadataType represents a parsed type from metadata signatures
public enum MetadataType {
    | Void
    | Boolean
    | Char
    | I8
    | U8
    | I16
    | U16
    | I32
    | U32
    | I64
    | U64
    | F32
    | F64
    | ISize
    | USize
    | MdString
    | MdObject
    | ClassName(TypeName)
    | ValueName(TypeName)
    | Union(TypeName)
    | MdArray(MetadataType)
    | Generic(String, UInt16)
    | RefMut(MetadataType)
    | RefConst(MetadataType)
    | PtrMut(MetadataType, Int64)
    | PtrConst(MetadataType, Int64)
    | ArrayFixed(MetadataType, Int64)
    | Packed(MetadataType, UInt16)

    public func elementTypeCode(): UInt8 {
        match (this) {
            case Boolean => ELEMENT_TYPE_BOOLEAN
            case U8 => ELEMENT_TYPE_U1
            case I8 => ELEMENT_TYPE_I1
            case U16 => ELEMENT_TYPE_U2
            case I16 => ELEMENT_TYPE_I2
            case U32 => ELEMENT_TYPE_U4
            case I32 => ELEMENT_TYPE_I4
            case U64 => ELEMENT_TYPE_U8
            case I64 => ELEMENT_TYPE_I8
            case F32 => ELEMENT_TYPE_R4
            case F64 => ELEMENT_TYPE_R8
            case MdString => ELEMENT_TYPE_STRING
            case Packed(inner, _) => inner.elementTypeCode()
            case _ => 0
        }
    }
}

// MetadataValue represents constant values found in metadata
public enum MetadataValue {
    | ValBool(Bool)
    | ValU8(UInt8)
    | ValI8(Int8)
    | ValU16(UInt16)
    | ValI16(Int16)
    | ValU32(UInt32)
    | ValI32(Int32)
    | ValU64(UInt64)
    | ValI64(Int64)
    | ValF32(Float32)
    | ValF64(Float64)
    | ValUtf8(String)
    | ValUtf16(String)
    | ValTypeName(TypeName)
    | ValEnum(TypeName, MetadataValue)
}

// MethodSignature holds a parsed method signature
public class MethodSignature {
    public var flags: UInt8 = 0
    public var returnType: MetadataType = MetadataType.Void
    public var paramTypes: ArrayList<MetadataType> = ArrayList<MetadataType>()

    public init() {}
}

// TypeCategory classifies a TypeDef
public enum TypeCategory {
    | Interface
    | Class
    | Enum
    | Struct
    | Delegate
    | Attribute
}

// --- Flags types ---

public struct TypeAttributes <: ToString {
    public let value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public static let Public = TypeAttributes(0x1)
    public static let NestedPublic = TypeAttributes(0x2)
    public static let ExplicitLayout = TypeAttributes(0x10)
    public static let Abstract = TypeAttributes(0x80)
    public static let Sealed = TypeAttributes(0x100)
    public static let WindowsRuntime = TypeAttributes(0x4000)
    public static let Interface = TypeAttributes(0x20)
    public static let SequentialLayout = TypeAttributes(0x8)
    public static let Import = TypeAttributes(0x1000)

    public func contains(other: TypeAttributes): Bool {
        return (this.value & other.value) == other.value
    }

    public func isNested(): Bool {
        return (this.value & 0x6u32) != 0u32
    }

    public func toString(): String {
        return "TypeAttributes(0x${value})"
    }
}

public struct FieldAttributes {
    public let value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public static let Private = FieldAttributes(0x1)
    public static let Public = FieldAttributes(0x6)
    public static let Literal = FieldAttributes(0x40)
    public static let Static = FieldAttributes(0x10)
    public static let SpecialName = FieldAttributes(0x200)
    public static let RTSpecialName = FieldAttributes(0x400)
    public static let HasDefault = FieldAttributes(0x8000)

    public func contains(other: FieldAttributes): Bool {
        return (this.value & other.value) == other.value
    }
}

public struct MethodAttributes {
    public let value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public static let Abstract = MethodAttributes(0x400)
    public static let HideBySig = MethodAttributes(0x80)
    public static let NewSlot = MethodAttributes(0x100)
    public static let Public = MethodAttributes(0x6)
    public static let Static = MethodAttributes(0x10)
    public static let SpecialName = MethodAttributes(0x800)
    public static let Virtual = MethodAttributes(0x40)
    public static let PInvokeImpl = MethodAttributes(0x2000)
    public static let RTSpecialName = MethodAttributes(0x1000)

    public func contains(other: MethodAttributes): Bool {
        return (this.value & other.value) == other.value
    }
}

public struct MethodImplAttributes {
    public let value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public static let PreserveSig = MethodImplAttributes(0x80)

    public func contains(other: MethodImplAttributes): Bool {
        return (this.value & other.value) == other.value
    }
}

public struct MethodCallAttributes <: Equatable<MethodCallAttributes> {
    public let value: UInt8

    public init(value: UInt8) {
        this.value = value
    }

    public static let HASTHIS = MethodCallAttributes(0x20)
    public static let VARARG = MethodCallAttributes(0x05)

    public func contains(other: MethodCallAttributes): Bool {
        return (this.value & other.value) == other.value
    }

    public operator func ==(other: MethodCallAttributes): Bool {
        return this.value == other.value
    }

    public operator func !=(other: MethodCallAttributes): Bool {
        return this.value != other.value
    }
}

public struct ParamAttributes {
    public let value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public static let In = ParamAttributes(0x1)
    public static let Out = ParamAttributes(0x2)
    public static let Optional = ParamAttributes(0x10)

    public func contains(other: ParamAttributes): Bool {
        return (this.value & other.value) == other.value
    }
}

public struct PInvokeAttributes {
    public let value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public static let NoMangle = PInvokeAttributes(0x01)
    public static let SupportsLastError = PInvokeAttributes(0x40)
    public static let CallConvPlatformapi = PInvokeAttributes(0x100)
    public static let CallConvCdecl = PInvokeAttributes(0x200)
    public static let CallConvFastcall = PInvokeAttributes(0x500)

    public func contains(other: PInvokeAttributes): Bool {
        return (this.value & other.value) == other.value
    }
}

public struct GenericParamAttributes {
    public let value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public func contains(other: GenericParamAttributes): Bool {
        return (this.value & other.value) == other.value
    }
}

// Utility: trim tick from generic type names (e.g. "IVector`1" -> "IVector")
public func trimTick(name: String): String {
    match (name.indexOf("`", 0)) {
        case Some(pos) =>
            let arr = name.toArray()
            return String.fromUtf8(arr[0..pos])
        case None => return name
    }
}

func writeStringHash(hasher: DefaultHasher, value: String): DefaultHasher {
    var next = hasher
    next.write(Int64(value.toArray().size))
    for (byte in value.toArray()) {
        next.write(byte)
    }
    return next
}

func metadataTypeListEquals(lhs: ArrayList<MetadataType>, rhs: ArrayList<MetadataType>): Bool {
    if (lhs.size != rhs.size) {
        return false
    }

    var i: Int64 = 0
    while (i < Int64(lhs.size)) {
        if (metadataTypeStableKey(lhs[i]) != metadataTypeStableKey(rhs[i])) {
            return false
        }
        i += 1
    }
    return true
}

func metadataTypeListStableKey(types: ArrayList<MetadataType>): String {
    if (types.isEmpty()) {
        return ""
    }

    let parts = ArrayList<String>()
    for (ty in types) {
        parts.add(metadataTypeStableKey(ty))
    }
    return joinTypeNameParts(parts)
}

func joinTypeNameParts(parts: ArrayList<String>): String {
    let builder = StringBuilder()
    var first = true
    for (part in parts) {
        if (!first) {
            builder.append(", ")
        }
        builder.append(part)
        first = false
    }
    return builder.toString()
}

public func metadataTypeStableKey(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Void => "Void"
        case MetadataType.Boolean => "Boolean"
        case MetadataType.Char => "Char"
        case MetadataType.I8 => "I8"
        case MetadataType.U8 => "U8"
        case MetadataType.I16 => "I16"
        case MetadataType.U16 => "U16"
        case MetadataType.I32 => "I32"
        case MetadataType.U32 => "U32"
        case MetadataType.I64 => "I64"
        case MetadataType.U64 => "U64"
        case MetadataType.F32 => "F32"
        case MetadataType.F64 => "F64"
        case MetadataType.ISize => "ISize"
        case MetadataType.USize => "USize"
        case MetadataType.MdString => "String"
        case MetadataType.MdObject => "Object"
        case MetadataType.ClassName(typeName) => "class:${typeName}"
        case MetadataType.ValueName(typeName) => "value:${typeName}"
        case MetadataType.Union(typeName) => "union:${typeName}"
        case MetadataType.MdArray(inner) => "array:${metadataTypeStableKey(inner)}"
        case MetadataType.Generic(name, index) => "generic:${name}:${index}"
        case MetadataType.RefMut(inner) => "refmut:${metadataTypeStableKey(inner)}"
        case MetadataType.RefConst(inner) => "refconst:${metadataTypeStableKey(inner)}"
        case MetadataType.PtrMut(inner, depth) => "ptrmut:${depth}:${metadataTypeStableKey(inner)}"
        case MetadataType.PtrConst(inner, depth) => "ptrconst:${depth}:${metadataTypeStableKey(inner)}"
        case MetadataType.ArrayFixed(inner, size) => "fixed:${size}:${metadataTypeStableKey(inner)}"
        case MetadataType.Packed(inner, packing) => "packed:${packing}:${metadataTypeStableKey(inner)}"
    }
}
