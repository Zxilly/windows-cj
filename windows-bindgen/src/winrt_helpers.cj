package windows_bindgen

import std.collection.*
import windows_metadata.*

enum WinrtFactoryKind {
    | Static
    | Composable
}

class WinrtFactoryInterface {
    public let typeName: TypeName
    public let kind: WinrtFactoryKind

    public init(typeName: TypeName, kind: WinrtFactoryKind) {
        this.typeName = typeName
        this.kind = kind
    }
}

public func isAsyncInterfaceType(typeName: TypeName): Bool {
    let name = trimTick(typeName.name)
    if (typeName.namespace != "Windows.Foundation") {
        return false
    }
    return name == "IAsyncAction" ||
        name == "IAsyncActionWithProgress" ||
        name == "IAsyncOperation" ||
        name == "IAsyncOperationWithProgress"
}

public func isAgileType(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    if (index.hasAttribute(TABLE_TYPE_DEF, fileIdx, row, "AgileAttribute")) {
        return true
    }

    match (index.findAttribute(TABLE_TYPE_DEF, fileIdx, row, "MarshalingBehaviorAttribute")) {
        case Some(attrRow) =>
            let values = index.attributeValues(fileIdx, attrRow)
            if (!values.isEmpty()) {
                match (values[0][1]) {
                    case MetadataValue.ValI32(value) =>
                        if (value == 2) {
                            return true
                        }
                    case MetadataValue.ValEnum(_, inner) =>
                        match (inner) {
                            case MetadataValue.ValI32(value) =>
                                if (value == 2) {
                                    return true
                                }
                            case _ => ()
                        }
                    case _ => ()
                }
            }
        case None => ()
    }

    return isAsyncInterfaceType(TypeName(index.typeDefNamespace(fileIdx, row), trimTick(index.typeDefName(fileIdx, row))))
}

public func hasDefaultActivatableConstructor(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    let attrs = index.getAttributesFor(TABLE_TYPE_DEF, fileIdx, row)
    for (attrRow in attrs) {
        if (index.attributeName(fileIdx, attrRow) != "ActivatableAttribute") {
            continue
        }

        var hasInterfaceValue = false
        for ((_, value) in index.attributeValues(fileIdx, attrRow)) {
            match (value) {
                case MetadataValue.ValTypeName(typeName) =>
                    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
                    if (!candidates.isEmpty()) {
                        let (candidateFileIdx, candidateRow) = candidates[0]
                        if (isInterfaceCategory(index.typeDefCategory(candidateFileIdx, candidateRow))) {
                            hasInterfaceValue = true
                            break
                        }
                    }
                case _ => ()
            }
        }

        if (!hasInterfaceValue) {
            return true
        }
    }

    return false
}

func collectFactoryInterfaces(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<WinrtFactoryInterface> {
    let result = ArrayList<WinrtFactoryInterface>()
    let seen = HashMap<TypeName, Bool>()
    collectFactoryInterfacesForAttribute(index, fileIdx, row, "StaticAttribute", WinrtFactoryKind.Static, result, seen)
    collectFactoryInterfacesForAttribute(index, fileIdx, row, "ActivatableAttribute", WinrtFactoryKind.Static, result, seen)
    collectFactoryInterfacesForAttribute(index, fileIdx, row, "ComposableAttribute", WinrtFactoryKind.Composable, result, seen)
    return result
}

func collectFactoryInterfacesForAttribute(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    attrName: String,
    kind: WinrtFactoryKind,
    result: ArrayList<WinrtFactoryInterface>,
    seen: HashMap<TypeName, Bool>
): Unit {
    let attrs = index.getAttributesFor(TABLE_TYPE_DEF, fileIdx, row)
    for (attrRow in attrs) {
        if (index.attributeName(fileIdx, attrRow) != attrName) {
            continue
        }

        for ((_, value) in index.attributeValues(fileIdx, attrRow)) {
            match (value) {
                case MetadataValue.ValTypeName(typeName) =>
                    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
                    if (candidates.isEmpty() || seen.contains(typeName)) {
                        continue
                    }
                    let (candidateFileIdx, candidateRow) = candidates[0]
                    if (isInterfaceCategory(index.typeDefCategory(candidateFileIdx, candidateRow))) {
                        seen[typeName] = true
                        result.add(WinrtFactoryInterface(typeName, kind))
                        break
                    }
                case _ => ()
            }
        }
    }
}

public func isExclusiveInterfaceType(index: TypeIndex, typeName: TypeName): Bool {
    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return false
    }
    let (fileIdx, row) = candidates[0]
    return index.hasAttribute(TABLE_TYPE_DEF, fileIdx, row, "ExclusiveToAttribute")
}

public func filterPublicClassInterfaces(
    index: TypeIndex,
    interfaces: ArrayList<TypeName>,
    defaultInterface: Option<TypeName>
): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    for (iface in interfaces) {
        if (isExclusiveInterfaceType(index, iface)) {
            match (defaultInterface) {
                case Some(defaultType) =>
                    if (iface == defaultType) {
                        result.add(iface)
                    }
                case None => ()
            }
            continue
        }
        result.add(iface)
    }
    return result
}

public func winrtPublicType(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.MdObject => "IInspectable"
        case MetadataType.ClassName(tn) =>
            // Use typed projection name for both generic and non-generic reference types
            return typeNameToProjectionCj(index, tn)
        case MetadataType.ValueName(tn) =>
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return typeNameToProjectionCj(index, tn)
            }
            return metadataTypeToWinrtAbiCj(ty)
        case MetadataType.Generic(_, _) =>
            return metadataTypeToProjectionCj(index, ty)
        case _ =>
            return metadataTypeToWinrtAbiCj(ty)
    }
}

public func winrtSlotType(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.MdObject => "CPointer<Unit>"
        case MetadataType.ClassName(_) => "CPointer<Unit>"
        case MetadataType.ValueName(tn) =>
            if (isReferenceProjectionType(index, tn)) {
                return "CPointer<Unit>"
            }
            return metadataTypeToWinrtAbiCj(ty)
        case MetadataType.Generic(_, _) => "CPointer<Unit>"
        case _ =>
            return metadataTypeToWinrtAbiCj(ty)
    }
}

public func winrtArgumentExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.MdObject => "${expr}.asRaw()"
        case MetadataType.ClassName(_) =>
            // All reference class types (generic or not) pass as raw pointer
            return "${expr}.asRaw()"
        case MetadataType.ValueName(tn) =>
            if (isReferenceProjectionType(index, tn)) {
                return "${expr}.asRaw()"
            }
            return expr
        case _ =>
            return expr
    }
}

public func winrtThunkParamExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.MdObject => "InParam<IInspectable>(IInspectable.viewOf(${expr}))"
        case MetadataType.ClassName(tn) =>
            let projection = typeNameToProjectionCj(index, tn)
            return "InParam<${projection}>(${projection}.viewOf(${expr}))"
        case MetadataType.ValueName(tn) =>
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                let projection = typeNameToProjectionCj(index, tn)
                return "InParam<${projection}>(${projection}.viewOf(${expr}))"
            }
            return expr
        case _ =>
            return expr
    }
}

public func winrtReturnExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.MdObject => "IInspectable.fromAbiTake(${expr})"
        case MetadataType.ClassName(tn) =>
            return "${typeNameToProjectionCj(index, tn)}.fromAbiTake(${expr})"
        case MetadataType.ValueName(tn) =>
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return "${typeNameToProjectionCj(index, tn)}.fromAbiTake(${expr})"
            }
            return expr
        case _ =>
            return expr
    }
}

public func winrtThunkReturnExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.MdObject => "${expr}.intoAbi()"
        case MetadataType.ClassName(_) =>
            return "${expr}.intoAbi()"
        case MetadataType.ValueName(tn) =>
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return "${expr}.intoAbi()"
            }
            return expr
        case _ =>
            return expr
    }
}

public func winrtHasResult(sig: MethodSignature): Bool {
    return winrtPublicTypePlaceholder(sig.returnType) != "Unit"
}

func winrtPublicTypePlaceholder(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Void => "Unit"
        case _ => "Value"
    }
}

public func winrtResultDefaultExpr(typeName: String): String {
    if (typeName == "Unit") {
        return "()"
    }
    if (typeName == "Bool") {
        return "false"
    }
    if (typeName == "Float32") {
        return "0.0f32"
    }
    if (typeName == "Float64") {
        return "0.0f64"
    }
    if (typeName == "Int8" || typeName == "UInt8" ||
        typeName == "Int16" || typeName == "UInt16" ||
        typeName == "Int32" || typeName == "UInt32" ||
        typeName == "Int64" || typeName == "UInt64" ||
        typeName == "IntNative" || typeName == "UIntNative") {
        return "0"
    }
    if (typeName.startsWith("CPointer")) {
        return "${typeName}()"
    }
    return "${typeName}()"
}

func isReferenceProjectionType(index: TypeIndex, typeName: TypeName): Bool {
    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return false
    }
    let (fileIdx, row) = candidates[0]
    return isReferenceCategory(index.typeDefCategory(fileIdx, row))
}

func isInterfaceCategory(category: TypeCategory): Bool {
    match (category) {
        case TypeCategory.Interface => true
        case _ => false
    }
}

func isReferenceCategory(category: TypeCategory): Bool {
    match (category) {
        case TypeCategory.Interface => true
        case TypeCategory.Class => true
        case TypeCategory.Delegate => true
        case _ => false
    }
}
