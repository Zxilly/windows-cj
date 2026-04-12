package windows_bindgen.types

import std.collection.*
import windows_metadata.*

public struct BindgenTypeKey <: Hashable & Equatable<BindgenTypeKey> & Comparable<BindgenTypeKey> {
    public let typeName: TypeName
    public let fileIdx: Int64
    public let row: Int64

    public init(typeName: TypeName, fileIdx: Int64, row: Int64) {
        this.typeName = typeName
        this.fileIdx = fileIdx
        this.row = row
    }

    public operator func ==(other: BindgenTypeKey): Bool {
        typeName == other.typeName && fileIdx == other.fileIdx && row == other.row
    }

    public operator func !=(other: BindgenTypeKey): Bool {
        !(this == other)
    }

    public func hashCode(): Int64 {
        var hasher = DefaultHasher()
        hasher.write(typeName.hashCode())
        hasher.write(fileIdx)
        hasher.write(row)
        hasher.finish()
    }

    public func compare(other: BindgenTypeKey): Ordering {
        let nameOrdering = typeName.compare(other.typeName)
        if (nameOrdering != Ordering.EQ) {
            return nameOrdering
        }
        let fileOrdering = fileIdx.compare(other.fileIdx)
        if (fileOrdering != Ordering.EQ) {
            return fileOrdering
        }
        return row.compare(other.row)
    }
}

public struct BindgenTypeEntry {
    public let typeName: TypeName
    public let name: String
    public let namespace: String
    public let fileIdx: Int64
    public let row: Int64

    public init(typeName: TypeName, fileIdx: Int64, row: Int64) {
        this.typeName = typeName.definition()
        this.name = trimTick(typeName.name)
        this.namespace = typeName.namespace
        this.fileIdx = fileIdx
        this.row = row
    }

    public func key(): BindgenTypeKey {
        return BindgenTypeKey(typeName, fileIdx, row)
    }
}

public enum BindgenType {
    | HighLevelClass(BindgenTypeEntry)
    | HighLevelDelegate(BindgenTypeEntry)
    | HighLevelEnum(BindgenTypeEntry)
    | HighLevelInterface(BindgenTypeEntry)
    | HighLevelStruct(BindgenTypeEntry)
    | CppDelegate(BindgenTypeEntry)
    | CppEnum(BindgenTypeEntry)
    | CppFn(BindgenTypeEntry)
    | CppInterface(BindgenTypeEntry)
    | CppStruct(BindgenTypeEntry)
    | Handle(BindgenTypeEntry)
    | Attribute(BindgenTypeEntry)
}

public func bindgenTypeEntry(ty: BindgenType): BindgenTypeEntry {
    match (ty) {
        case HighLevelClass(entry) => entry
        case HighLevelDelegate(entry) => entry
        case HighLevelEnum(entry) => entry
        case HighLevelInterface(entry) => entry
        case HighLevelStruct(entry) => entry
        case CppDelegate(entry) => entry
        case CppEnum(entry) => entry
        case CppFn(entry) => entry
        case CppInterface(entry) => entry
        case CppStruct(entry) => entry
        case Handle(entry) => entry
        case Attribute(entry) => entry
    }
}

public func bindgenTypeName(ty: BindgenType): String {
    return bindgenTypeEntry(ty).name
}

public func bindgenTypeFileIdx(ty: BindgenType): Int64 {
    return bindgenTypeEntry(ty).fileIdx
}

public func bindgenTypeRow(ty: BindgenType): Int64 {
    return bindgenTypeEntry(ty).row
}

public func bindgenTypeGeneratesCode(ty: BindgenType): Bool {
    match (ty) {
        case Attribute(_) => false
        case _ => true
    }
}

public func projectNamespaceTypes(
    index: TypeIndex,
    entries: ArrayList<BindgenTypeEntry>,
    highLevel: Bool
): ArrayList<BindgenType> {
    let result = ArrayList<BindgenType>()
    for (entry in entries) {
        result.add(projectBindgenType(index, entry, highLevel))
    }
    return result
}

public func projectBindgenType(index: TypeIndex, entry: BindgenTypeEntry, highLevel: Bool): BindgenType {
    let category = index.typeDefCategory(entry.fileIdx, entry.row)
    let flags = index.typeDefFlags(entry.fileIdx, entry.row)
    let isWinRT = flags.contains(TypeAttributes.WindowsRuntime)

    match (category) {
        case Interface =>
            if (highLevel && isWinRT) {
                return HighLevelInterface(entry)
            }
            return CppInterface(entry)
        case Struct =>
            if (isHandleBindgenType(index, entry.fileIdx, entry.row)) {
                return Handle(entry)
            }
            if (highLevel) {
                return HighLevelStruct(entry)
            }
            return CppStruct(entry)
        case Enum =>
            if (highLevel) {
                return HighLevelEnum(entry)
            }
            return CppEnum(entry)
        case Delegate =>
            if (highLevel && isWinRT) {
                return HighLevelDelegate(entry)
            }
            return CppDelegate(entry)
        case Class =>
            if (highLevel && isWinRT) {
                return HighLevelClass(entry)
            }
            return CppFn(entry)
        case Attribute =>
            return Attribute(entry)
    }
}

func isHandleBindgenType(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    let (fieldStart, fieldEnd) = index.typeDefFields(fileIdx, row)
    if (fieldEnd - fieldStart != 1) {
        return false
    }

    if (index.fieldName(fileIdx, fieldStart) != "Value") {
        return false
    }

    return isHandleBindgenFieldType(index.fieldType(fileIdx, fieldStart))
}

func isPrimitiveBindgenType(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.Boolean => true
        case MetadataType.I8 => true
        case MetadataType.U8 => true
        case MetadataType.I16 => true
        case MetadataType.U16 => true
        case MetadataType.I32 => true
        case MetadataType.U32 => true
        case MetadataType.I64 => true
        case MetadataType.U64 => true
        case MetadataType.F32 => true
        case MetadataType.F64 => true
        case MetadataType.ISize => true
        case MetadataType.USize => true
        case _ => false
    }
}

func isHandleBindgenFieldType(ty: MetadataType): Bool {
    if (isPrimitiveBindgenType(ty)) {
        return true
    }
    match (ty) {
        case MetadataType.MdString => true
        case MetadataType.MdObject => true
        case MetadataType.MdArray(_) => true
        case MetadataType.RefMut(_) => true
        case MetadataType.RefConst(_) => true
        case MetadataType.PtrMut(_, _) => true
        case MetadataType.PtrConst(_, _) => true
        case _ => false
    }
}
