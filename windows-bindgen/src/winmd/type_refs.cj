package windows_bindgen.winmd

import windows_metadata.*

public func decodeTypeDefOrRefTypeName(index: TypeIndex, fileIdx: Int64, coded: Int64): Option<TypeName> {
    let file = index.getFile(fileIdx)
    let (table, row) = decodeCodedIndex(coded, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)
    if (table == TABLE_TYPE_DEF) {
        return Some(TypeName.named(file.getString(row, TABLE_TYPE_DEF, 2), trimTick(file.getString(row, TABLE_TYPE_DEF, 1))))
    }
    if (table == TABLE_TYPE_REF) {
        return Some(TypeName.named(file.getString(row, TABLE_TYPE_REF, 2), trimTick(file.getString(row, TABLE_TYPE_REF, 1))))
    }
    if (table == TABLE_TYPE_SPEC) {
        match (TypeSpec(index, fileIdx, row).ty()) {
            case MetadataType.ClassName(typeName) => return Some(typeName)
            case MetadataType.ValueName(typeName) => return Some(typeName)
            case MetadataType.Union(typeName) => return Some(typeName)
            case _ => return None
        }
    }
    return None
}

public func decodeMemberRefParentTypeName(file: WinmdFile, memberRefRow: Int64): Option<TypeName> {
    let coded = file.getUInt(memberRefRow, TABLE_MEMBER_REF, 0)
    let (table, row) = decodeCodedIndex(coded, CODED_MEMBER_REF_PARENT_BITS, CODED_MEMBER_REF_PARENT_MAP)
    if (table == TABLE_TYPE_DEF) {
        return Some(TypeName.named(file.getString(row, TABLE_TYPE_DEF, 2), trimTick(file.getString(row, TABLE_TYPE_DEF, 1))))
    }
    if (table == TABLE_TYPE_REF) {
        return Some(TypeName.named(file.getString(row, TABLE_TYPE_REF, 2), trimTick(file.getString(row, TABLE_TYPE_REF, 1))))
    }
    if (table == TABLE_TYPE_SPEC) {
        return None
    }
    return None
}

public func customAttributeTypeName(index: TypeIndex, fileIdx: Int64, attrRow: Int64): Option<TypeName> {
    let file = index.getFile(fileIdx)
    let coded = file.getUInt(attrRow, TABLE_ATTRIBUTE, 1)
    let (table, row) = decodeCodedIndex(coded, CODED_CUSTOM_ATTRIBUTE_TYPE_BITS, CODED_CUSTOM_ATTRIBUTE_TYPE_MAP)
    if (table == TABLE_METHOD_DEF) {
        let ownerRow = file.parentRow(row, TABLE_TYPE_DEF, 5)
        return Some(TypeName.named(file.getString(ownerRow, TABLE_TYPE_DEF, 2), trimTick(file.getString(ownerRow, TABLE_TYPE_DEF, 1))))
    }
    if (table == TABLE_MEMBER_REF) {
        return decodeMemberRefParentTypeName(file, row)
    }
    return None
}
