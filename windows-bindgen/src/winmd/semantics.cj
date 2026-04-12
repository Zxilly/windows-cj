package windows_bindgen.winmd

import std.collection.*
import windows_metadata.*

public func winmdBuildGenericArray(
    index: TypeIndex,
    fileIdx: Int64,
    gpStart: Int64,
    gpEnd: Int64
): Array<MetadataType> {
    if (gpStart >= gpEnd) {
        return Array<MetadataType>(0, {_ => MetadataType.Void})
    }

    let generics = ArrayList<MetadataType>()
    var gpRow = gpStart
    while (gpRow < gpEnd) {
        let genericName = index.genericParamName(fileIdx, gpRow)
        generics.add(MetadataType.Generic(genericName, UInt16(gpRow - gpStart)))
        gpRow += 1
    }

    let result = Array<MetadataType>(generics.size, {_ => MetadataType.Void})
    var i: Int64 = 0
    while (i < Int64(generics.size)) {
        result[i] = generics[i]
        i += 1
    }
    return result
}

public func winmdTypeGenericParameterNames(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<String> {
    let result = ArrayList<String>()
    let (gpStart, gpEnd) = index.typeDefGenericParams(fileIdx, row)
    var gpRow = gpStart
    while (gpRow < gpEnd) {
        result.add(index.genericParamName(fileIdx, gpRow))
        gpRow += 1
    }
    return result
}

public func winmdRowGenericStart(index: TypeIndex, fileIdx: Int64, row: Int64): Int64 {
    let (gpStart, _) = index.typeDefGenericParams(fileIdx, row)
    return gpStart
}

public func winmdRowGenericEnd(index: TypeIndex, fileIdx: Int64, row: Int64): Int64 {
    let (_, gpEnd) = index.typeDefGenericParams(fileIdx, row)
    return gpEnd
}

public func winmdFindBaseInterface(index: TypeIndex, fileIdx: Int64, row: Int64): Option<TypeName> {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    if (iiStart < iiEnd) {
        let ifaceValue = file.getUInt(iiStart, TABLE_INTERFACE_IMPL, 1)
        match (decodeTypeDefOrRefTypeName(index, fileIdx, ifaceValue)) {
            case Some(typeName) =>
                if (trimTick(typeName.name) != "IUnknown") {
                    return Some(typeName.definition())
                }
            case None => ()
        }
    }
    return None
}

public func winmdExtendsIInspectable(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
        let (ifaceTable, ifaceRow) = decodeCodedIndex(ifaceValue, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)
        var ifaceName = ""
        if (ifaceTable == TABLE_TYPE_DEF) {
            ifaceName = file.getString(ifaceRow, TABLE_TYPE_DEF, 1)
        } else if (ifaceTable == TABLE_TYPE_REF) {
            ifaceName = file.getString(ifaceRow, TABLE_TYPE_REF, 1)
        }
        if (ifaceName == "IInspectable") {
            return true
        }
        ii += 1
    }
    return false
}

public func winmdFirstInterfaceType(index: TypeIndex, fileIdx: Int64, row: Int64): Option<TypeName> {
    let direct = winmdDirectInterfaceTypes(index, fileIdx, row)
    if (direct.isEmpty()) {
        return None
    }
    return Some(direct[0])
}

public func winmdCollectInterfaceAncestors(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()
    for (iface in winmdDirectInterfaceTypes(index, fileIdx, row)) {
        winmdCollectInterfaceAncestorsFromType(index, iface, result, seen)
    }
    return result
}

func winmdCollectInterfaceAncestorsFromType(
    index: TypeIndex,
    iface: TypeName,
    result: ArrayList<TypeName>,
    seen: HashMap<TypeName, Bool>
): Unit {
    if (seen.contains(iface)) {
        return
    }
    seen[iface] = true
    result.add(iface)

    let candidates = index.get(iface.definition())
    if (candidates.isEmpty()) {
        return
    }
    let entry = candidates[0]
    for (baseType in winmdDirectInterfaceTypes(index, entry.fileIdx, entry.row)) {
        winmdCollectInterfaceAncestorsFromType(index, baseType, result, seen)
    }
}

public func winmdDirectInterfaceTypes(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
        match (decodeTypeDefOrRefTypeName(index, fileIdx, ifaceValue)) {
            case Some(typeName) =>
                let leaf = trimTick(typeName.name)
                if (leaf != "IUnknown" && leaf != "IInspectable") {
                    result.add(typeName)
                }
            case None => ()
        }
        ii += 1
    }
    return result
}

public func winmdDefaultClassInterfaceType(index: TypeIndex, fileIdx: Int64, row: Int64): Option<TypeName> {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        if (index.hasAttribute(TABLE_INTERFACE_IMPL, fileIdx, ii, "DefaultAttribute")) {
            let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
            return decodeTypeDefOrRefTypeName(index, fileIdx, ifaceValue)
        }
        ii += 1
    }
    return None
}

public func winmdCollectClassBases(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()
    var currentFileIdx = fileIdx
    var currentRow = row
    while (true) {
        let file = index.getFile(currentFileIdx)
        let (table, extRow) = index.typeDefExtends(currentFileIdx, currentRow)
        if (table != TABLE_TYPE_DEF && table != TABLE_TYPE_REF) {
            break
        }

        let baseNamespace = if (table == TABLE_TYPE_DEF) {
            file.getString(extRow, TABLE_TYPE_DEF, 2)
        } else {
            file.getString(extRow, TABLE_TYPE_REF, 2)
        }
        let baseName = if (table == TABLE_TYPE_DEF) {
            trimTick(file.getString(extRow, TABLE_TYPE_DEF, 1))
        } else {
            trimTick(file.getString(extRow, TABLE_TYPE_REF, 1))
        }

        if (baseNamespace == "System" && baseName == "Object") {
            break
        }

        let typeName = TypeName.named(baseNamespace, baseName)
        if (!seen.contains(typeName)) {
            seen[typeName] = true
            result.add(typeName)
        }

        let candidates = index.get(typeName)
        if (candidates.isEmpty()) {
            break
        }
        currentFileIdx = candidates[0].fileIdx
        currentRow = candidates[0].row
    }
    return result
}
