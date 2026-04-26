package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

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

func isWinrtStringMetadataType(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.MdString => true
        case MetadataType.ClassName(tn) => isSystemStringTypeName(tn)
        case MetadataType.ValueName(tn) => isSystemStringTypeName(tn)
        case _ => false
    }
}

func isProjectedWinrtValueType(index: TypeIndex, typeName: TypeName): Bool {
    let resolvedTypeName = qualifyTypeNameWithCurrentNamespace(typeName)
    if (!resolvedTypeName.generics.isEmpty()) {
        return false
    }
    if (resolvedTypeName.namespace != "Windows" && !resolvedTypeName.namespace.startsWith("Windows.")) {
        return false
    }
    match (bindgenContext()) {
        case Some(context) =>
            if (!context.config.isForcedLocalType(resolvedTypeName.namespace, trimTick(resolvedTypeName.name))) {
                match (context.references.importPathForType(resolvedTypeName.namespace, trimTick(resolvedTypeName.name))) {
                    case Some(importPath) =>
                        if (importPath == "windows_core" || importPath == "windows_result") {
                            return false
                        }
                    case None => ()
                }
            }
        case None => ()
    }
    if (isReferenceProjectionType(index, resolvedTypeName)) {
        return false
    }
    let candidates = index.get(resolvedTypeName.namespace, trimTick(resolvedTypeName.name))
    var projected = false
    for ((fileIdx, row) in candidates) {
        if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
            continue
        }
        match (index.typeDefCategory(fileIdx, row)) {
            case Struct =>
                let flags = index.typeDefFlags(fileIdx, row)
                let layout = index.typeDefClassLayout(fileIdx, row)
                let isUnion = flags.contains(TypeAttributes.ExplicitLayout)
                let isPacked = match (layout) {
                    case Some((packing, _)) => packing != 0u16 && packing != 8u16
                    case None => false
                }
                if (isHandleType(index, fileIdx, row) || isUnion || isPacked) {
                    continue
                }
                projected = true
            case Enum => projected = true
            case _ => ()
        }
    }
    return projected
}

func isWinrtArrayRefMetadataType(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.RefMut(inner) =>
            match (inner) {
                case MetadataType.MdArray(_) => true
                case _ => false
            }
        case MetadataType.RefConst(inner) =>
            match (inner) {
                case MetadataType.MdArray(_) => true
                case _ => false
            }
        case _ => false
    }
}

func winrtValueProjectionType(index: TypeIndex, typeName: TypeName): String {
    return typeNameToProjectionCj(index, typeName)
}

func winrtValueAbiType(index: TypeIndex, typeName: TypeName): String {
    return appendSourceIdentifierSuffix(winrtValueProjectionType(index, typeName), "Abi")
}

public func winrtPublicType(index: TypeIndex, ty: MetadataType): String {
    if (isWinrtStringMetadataType(ty)) {
        return winrtStringProjectionType()
    }
    if (isWinrtArrayRefMetadataType(ty)) {
        return winrtSlotType(index, ty)
    }
    match (ty) {
        case MetadataType.MdObject => "IInspectable"
        case MetadataType.ClassName(tn) =>
            // Use typed projection name for both generic and non-generic reference types
            return typeNameToProjectionCj(index, tn)
        case MetadataType.MdArray(_) =>
            return winrtSlotType(index, ty)
        case MetadataType.ValueName(tn) =>
            if (isSystemGuidTypeName(tn)) {
                return typeNameToProjectionCj(index, tn)
            }
            if (isProjectedWinrtValueType(index, tn)) {
                return winrtValueProjectionType(index, tn)
            }
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return typeNameToProjectionCj(index, tn)
            }
            return metadataTypeToWinrtAbiCj(ty)
        case MetadataType.Generic(_, _) =>
            return metadataTypeToProjectionCj(index, ty)
        case MetadataType.RefMut(_) =>
            return winrtSlotType(index, ty)
        case MetadataType.RefConst(_) =>
            return winrtSlotType(index, ty)
        case MetadataType.PtrMut(_, _) =>
            return winrtSlotType(index, ty)
        case MetadataType.PtrConst(_, _) =>
            return winrtSlotType(index, ty)
        case MetadataType.ArrayFixed(_, _) =>
            return winrtSlotType(index, ty)
        case _ =>
            return metadataTypeToWinrtAbiCj(ty)
    }
}

public func winrtSlotType(index: TypeIndex, ty: MetadataType): String {
    if (isWinrtStringMetadataType(ty)) {
        return "CPointer<Unit>"
    }
    match (ty) {
        case MetadataType.MdObject => "CPointer<Unit>"
        case MetadataType.ClassName(tn) =>
            if (isProjectedWinrtValueType(index, tn)) {
                return winrtValueAbiType(index, tn)
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return typeNameToProjectionCj(index, tn)
            }
            return "CPointer<Unit>"
        case MetadataType.ValueName(tn) =>
            if (isProjectedWinrtValueType(index, tn)) {
                return winrtValueAbiType(index, tn)
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return typeNameToProjectionCj(index, tn)
            }
            if (isReferenceProjectionType(index, tn)) {
                return "CPointer<Unit>"
            }
            return metadataTypeToWinrtAbiCj(ty)
        case MetadataType.MdArray(elem) =>
            return "CPointer<${winrtSlotType(index, elem)}>"
        case MetadataType.RefMut(inner) =>
            return "CPointer<${winrtSlotType(index, inner)}>"
        case MetadataType.RefConst(inner) =>
            return "CPointer<${winrtSlotType(index, inner)}>"
        case MetadataType.PtrMut(inner, depth) =>
            return wrapWinrtAbiPointer(index, inner, depth)
        case MetadataType.PtrConst(inner, depth) =>
            return wrapWinrtAbiPointer(index, inner, depth)
        case MetadataType.ArrayFixed(inner, size) =>
            return "VArray<${winrtSlotType(index, inner)}, \$${size}>"
        case MetadataType.Packed(inner, _) =>
            return metadataTypeToWinrtAbiCj(inner)
        case MetadataType.Generic(_, _) => "CPointer<Unit>"
        case _ =>
            return metadataTypeToWinrtAbiCj(ty)
    }
}

func wrapWinrtAbiPointer(index: TypeIndex, inner: MetadataType, depth: Int64): String {
    var result = winrtSlotType(index, inner)
    var currentDepth = depth
    while (currentDepth > 0) {
        result = "CPointer<${result}>"
        currentDepth -= 1
    }
    return result
}

public func winrtNeedsInParam(index: TypeIndex, ty: MetadataType): Bool {
    if (isWinrtStringMetadataType(ty)) {
        return true
    }

    match (ty) {
        case MetadataType.MdObject => true
        case MetadataType.ClassName(_) => true
        case MetadataType.ValueName(tn) =>
            if (isProjectedWinrtValueType(index, tn)) {
                return false
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return false
            }
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return true
            }
            return false
        case _ => false
    }
}

public func winrtArgumentExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    if (isWinrtStringMetadataType(ty)) {
        return "${expr}.asRaw()"
    }
    match (ty) {
        case MetadataType.MdObject => "${expr}.asRaw()"
        case MetadataType.ClassName(_) =>
            // All reference class types (generic or not) pass as raw pointer
            return "${expr}.asRaw()"
        case MetadataType.ValueName(tn) =>
            if (isSystemGuidTypeName(tn)) {
                return "${expr}.toRaw()"
            }
            if (isProjectedWinrtValueType(index, tn)) {
                let projection = winrtValueProjectionType(index, tn)
                return "windows_core.projectTypedAbi(${expr}, windows_core.typeMarker<${projection}>())"
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return expr
            }
            if (isReferenceProjectionType(index, tn)) {
                return "${expr}.asRaw()"
            }
            return expr
        case _ =>
            return expr
    }
}

public func winrtThunkParamExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    if (isWinrtStringMetadataType(ty)) {
        let projection = winrtStringProjectionType()
        return "InParam<${projection}>(${projection}.viewOf(${expr}))"
    }
    match (ty) {
        case MetadataType.MdObject => "InParam<IInspectable>(IInspectable.viewOf(${expr}))"
        case MetadataType.ClassName(tn) =>
            let projection = typeNameToProjectionCj(index, tn)
            return "InParam<${projection}>(${projection}.viewOf(${expr}))"
        case MetadataType.ValueName(tn) =>
            if (isSystemGuidTypeName(tn)) {
                return "${typeNameToProjectionCj(index, tn)}(${expr})"
            }
            if (isProjectedWinrtValueType(index, tn)) {
                let projection = winrtValueProjectionType(index, tn)
                return "windows_core.assumeInitTypedAbi(${expr}, windows_core.typeMarker<${projection}>())"
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return expr
            }
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
    if (isWinrtStringMetadataType(ty)) {
        let projection = winrtStringProjectionType()
        return "${projection}.fromAbiTake(${expr})"
    }
    match (ty) {
        case MetadataType.MdObject => "IInspectable.fromAbiTake(${expr})"
        case MetadataType.ClassName(tn) =>
            return "${typeNameToProjectionCj(index, tn)}.fromAbiTake(${expr})"
        case MetadataType.ValueName(tn) =>
            if (isSystemGuidTypeName(tn)) {
                return "${typeNameToProjectionCj(index, tn)}(${expr})"
            }
            if (isProjectedWinrtValueType(index, tn)) {
                let projection = winrtValueProjectionType(index, tn)
                return "windows_core.fromTypedAbi(${expr}, windows_core.typeMarker<${projection}>()).unwrap()"
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return expr
            }
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return "${typeNameToProjectionCj(index, tn)}.fromAbiTake(${expr})"
            }
            return expr
        case _ =>
            return expr
    }
}

public func winrtThunkReturnExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    if (isWinrtStringMetadataType(ty)) {
        return "${expr}.intoRaw()"
    }
    match (ty) {
        case MetadataType.MdObject => "${expr}.intoAbi()"
        case MetadataType.ClassName(_) =>
            return "${expr}.intoAbi()"
        case MetadataType.ValueName(tn) =>
            if (isSystemGuidTypeName(tn)) {
                return "${expr}.toRaw()"
            }
            if (isProjectedWinrtValueType(index, tn)) {
                let projection = winrtValueProjectionType(index, tn)
                return "windows_core.projectTypedAbi(${expr}, windows_core.typeMarker<${projection}>())"
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return expr
            }
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
    match (varrayElementTypeSource(typeName)) {
        case Some(elemType) => return "${typeName}(repeat: ${winrtResultDefaultExpr(elemType)})"
        case None => ()
    }
    if (typeName == "Unit") {
        return "()"
    }
    if (typeName == "Bool") {
        return "false"
    }
    if (typeName == "HResult" || typeName == "HRESULT") {
        return "0i32"
    }
    if (typeName == "Float32") {
        return "0.0f32"
    }
    if (typeName == "Float64") {
        return "0.0f64"
    }
    if (typeName == "Int8") { return "0i8" }
    if (typeName == "UInt8") { return "0u8" }
    if (typeName == "Int16") { return "0i16" }
    if (typeName == "UInt16") { return "0u16" }
    if (typeName == "Int32") { return "0i32" }
    if (typeName == "UInt32") { return "0u32" }
    if (typeName == "Int64") { return "0i64" }
    if (typeName == "UInt64") { return "0u64" }
    if (typeName == "IntNative") { return "0" }
    if (typeName == "UIntNative") { return "0" }
    if (isPrimitiveAliasResultType(typeName)) { return "0" }
    if (typeName.startsWith("CPointer")) {
        return "${typeName}()"
    }
    return "${typeName}()"
}

func isPrimitiveAliasResultType(typeName: String): Bool {
    return typeName == "CHAR" ||
           typeName == "BOOLEAN" ||
           typeName == "BOOL" ||
           typeName == "COLORREF" ||
           typeName == "VARIANT_BOOL" ||
           typeName == "Win32_Foundation.CHAR" ||
           typeName == "Win32_Foundation.BOOLEAN" ||
           typeName == "Win32_Foundation.BOOL" ||
           typeName == "Win32_Foundation.COLORREF" ||
           typeName == "Win32_Foundation.VARIANT_BOOL" ||
           typeName == "windows.Win32.Foundation.CHAR" ||
           typeName == "windows.Win32.Foundation.BOOLEAN" ||
           typeName == "windows.Win32.Foundation.BOOL" ||
           typeName == "windows.Win32.Foundation.COLORREF" ||
           typeName == "windows.Win32.Foundation.VARIANT_BOOL"
}

func varrayElementTypeSource(typeName: String): Option<String> {
    if (!typeName.startsWith("VArray<")) {
        return None
    }

    let arr = typeName.toArray()
    let start = Int64("VArray<".toArray().size)
    var depth: Int64 = 0
    var i = start
    while (i < Int64(arr.size)) {
        let ch = arr[i]
        if (ch == b'<') {
            depth += 1
        } else if (ch == b'>') {
            if (depth > 0) {
                depth -= 1
            }
        } else if (ch == b',' && depth == 0) {
            return Some(String.fromUtf8(arr[start..i]))
        }
        i += 1
    }
    return None
}

public func winrtDefaultExpr(index: TypeIndex, ty: MetadataType): String {
    if (isWinrtStringMetadataType(ty)) {
        return "${winrtStringProjectionType()}()"
    }
    match (ty) {
        case MetadataType.MdObject => "IInspectable(CPointer<Unit>())"
        case MetadataType.ClassName(tn) =>
            if (isNativeDelegateTypeName(index, tn)) {
                return cppDefaultValue(ty)
            }
            return "${typeNameToProjectionCj(index, tn)}(CPointer<Unit>())"
        case MetadataType.ValueName(tn) =>
            if (isSystemGuidTypeName(tn)) {
                return "${typeNameToProjectionCj(index, tn)}()"
            }
            if (isNativeDelegateTypeName(index, tn)) {
                return cppDefaultValue(ty)
            }
            match (handleAliasUnderlyingType(index, qualifyTypeNameWithCurrentNamespace(tn))) {
                case Some(underlying) => return winrtResultDefaultExpr(underlying)
                case None => ()
            }
            if (isProjectedWinrtValueType(index, tn)) {
                return "${winrtValueProjectionType(index, tn)}()"
            }
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return "${typeNameToProjectionCj(index, tn)}(CPointer<Unit>())"
            }
            return winrtResultDefaultExpr(metadataTypeToWinrtAbiCj(ty))
        case MetadataType.MdArray(_) =>
            return winrtResultDefaultExpr(highLevelType(index, ty))
        case MetadataType.RefMut(_) =>
            return winrtResultDefaultExpr(winrtSlotType(index, ty))
        case MetadataType.RefConst(_) =>
            return winrtResultDefaultExpr(winrtSlotType(index, ty))
        case MetadataType.ArrayFixed(inner, size) =>
            if (isNativeDelegateArrayElement(index, inner)) {
                return cppDefaultValue(ty)
            }
            let elemType = winrtSlotType(index, inner)
            return "VArray<${elemType}, \$${size}>(repeat: ${winrtResultDefaultExpr(elemType)})"
        case MetadataType.Generic(name, _) =>
            return "throw IllegalStateException(\"WinRT generic `${name}` has no default value\")"
        case _ =>
            return winrtResultDefaultExpr(highLevelType(index, ty))
    }
}

func isNativeDelegateArrayElement(index: TypeIndex, ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.ClassName(tn) => return isNativeDelegateTypeName(index, tn)
        case MetadataType.ValueName(tn) => return isNativeDelegateTypeName(index, tn)
        case MetadataType.Packed(inner, _) => return isNativeDelegateArrayElement(index, inner)
        case _ => return false
    }
}

public func winrtActualAbiType(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.Generic(name, _) => "${name}Abi"
        case _ => winrtSlotType(index, ty)
    }
}

public func winrtPublicArrayPointerType(index: TypeIndex, elem: MetadataType): String {
    match (elem) {
        case MetadataType.Generic(_, _) => "CPointer<Unit>"
        case _ => "CPointer<${winrtSlotType(index, elem)}>"
    }
}

public func winrtActualArrayPointerType(index: TypeIndex, elem: MetadataType): String {
    return "CPointer<${winrtActualAbiType(index, elem)}>"
}

public enum WinrtGenericConstraintKind {
    | RuntimeOnly
    | WinrtGeneric
    | HandleOnly
}

func mergeWinrtGenericConstraintKind(
    left: WinrtGenericConstraintKind,
    right: WinrtGenericConstraintKind
): WinrtGenericConstraintKind {
    match (left) {
        case WinrtGenericConstraintKind.HandleOnly => return left
        case WinrtGenericConstraintKind.WinrtGeneric =>
            match (right) {
                case WinrtGenericConstraintKind.HandleOnly => return right
                case _ => return left
            }
        case WinrtGenericConstraintKind.RuntimeOnly => return right
    }
}

func bareGenericConstraintKind(ty: MetadataType, inputPosition!: Bool = false): Option<(String, WinrtGenericConstraintKind)> {
    match (ty) {
        case MetadataType.Generic(name, _) =>
            let _ = inputPosition
            return Some((name, WinrtGenericConstraintKind.WinrtGeneric))
        case _ =>
            return None
    }
}

func defaultWinrtGenericConstraintKinds(genericParams: ArrayList<String>): HashMap<String, WinrtGenericConstraintKind> {
    let kinds = HashMap<String, WinrtGenericConstraintKind>()
    for (genericParam in genericParams) {
        kinds[genericParam] = WinrtGenericConstraintKind.RuntimeOnly
    }
    return kinds
}

func winrtConstraintInferenceKey(index: TypeIndex, fileIdx: Int64, row: Int64, genericCount: Int64): String {
    return "${index.typeDefNamespace(fileIdx, row)}:${trimTick(index.typeDefName(fileIdx, row))}/${genericCount}"
}

func winrtDirectInterfaceTypes(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    genericsArray: Array<MetadataType>
): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
        match (decodeTypeDefOrRefTypeNameWithGenerics(index, fileIdx, ifaceValue, genericsArray)) {
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

func mergeWinrtConstraintKindsFromInstantiatedType(
    index: TypeIndex,
    typeName: TypeName,
    kinds: HashMap<String, WinrtGenericConstraintKind>,
    seen: HashMap<String, Bool>
): Unit {
    if (typeName.generics.isEmpty()) {
        return
    }

    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return
    }

    let (refFileIdx, refRow) = candidates[0]
    let refGenericParams = winmdTypeGenericParameterNames(index, refFileIdx, refRow)
    if (refGenericParams.isEmpty()) {
        return
    }

    let refGenericsArray = winmdBuildGenericArray(
        index,
        refFileIdx,
        winmdRowGenericStart(index, refFileIdx, refRow),
        winmdRowGenericEnd(index, refFileIdx, refRow)
    )
    let refKinds = winrtGenericConstraintKindsForInterfaceInternal(index, refFileIdx, refRow, refGenericParams, refGenericsArray, seen)
    var i: Int64 = 0
    let maxArgs = if (Int64(typeName.generics.size) < Int64(refGenericParams.size)) {
        Int64(typeName.generics.size)
    } else {
        Int64(refGenericParams.size)
    }
    while (i < maxArgs) {
        let actualArg = typeName.generics[i]
        mergeWinrtConstraintKindsFromMetadataType(index, actualArg, kinds, seen)
        match (actualArg) {
            case MetadataType.Generic(name, _) =>
                if (kinds.contains(name)) {
                    kinds[name] = mergeWinrtGenericConstraintKind(kinds[name], refKinds[refGenericParams[i]])
                }
            case _ => ()
        }
        i += 1
    }
}

func mergeWinrtConstraintKindsFromMetadataType(
    index: TypeIndex,
    ty: MetadataType,
    kinds: HashMap<String, WinrtGenericConstraintKind>,
    seen: HashMap<String, Bool>
): Unit {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            mergeWinrtConstraintKindsFromInstantiatedType(index, typeName, kinds, seen)
        case MetadataType.ValueName(typeName) =>
            mergeWinrtConstraintKindsFromInstantiatedType(index, typeName, kinds, seen)
        case MetadataType.MdArray(elem) =>
            mergeWinrtConstraintKindsFromMetadataType(index, elem, kinds, seen)
        case MetadataType.RefMut(inner) =>
            mergeWinrtConstraintKindsFromMetadataType(index, inner, kinds, seen)
        case MetadataType.RefConst(inner) =>
            mergeWinrtConstraintKindsFromMetadataType(index, inner, kinds, seen)
        case MetadataType.PtrMut(inner, _) =>
            mergeWinrtConstraintKindsFromMetadataType(index, inner, kinds, seen)
        case MetadataType.PtrConst(inner, _) =>
            mergeWinrtConstraintKindsFromMetadataType(index, inner, kinds, seen)
        case MetadataType.ArrayFixed(inner, _) =>
            mergeWinrtConstraintKindsFromMetadataType(index, inner, kinds, seen)
        case MetadataType.Packed(inner, _) =>
            mergeWinrtConstraintKindsFromMetadataType(index, inner, kinds, seen)
        case _ => ()
    }
}

func winrtGenericConstraintKindsForInterfaceInternal(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    genericParams: ArrayList<String>,
    genericsArray: Array<MetadataType>,
    seen: HashMap<String, Bool>
): HashMap<String, WinrtGenericConstraintKind> {
    let typeKey = winrtConstraintInferenceKey(index, fileIdx, row, Int64(genericParams.size))
    if (seen.contains(typeKey)) {
        return defaultWinrtGenericConstraintKinds(genericParams)
    }
    seen[typeKey] = true

    let kinds = defaultWinrtGenericConstraintKinds(genericParams)

    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
        match (bareGenericConstraintKind(sig.returnType)) {
            case Some((name, kind)) =>
                if (kinds.contains(name)) {
                    kinds[name] = mergeWinrtGenericConstraintKind(kinds[name], kind)
                }
            case None => ()
        }
        mergeWinrtConstraintKindsFromMetadataType(index, sig.returnType, kinds, seen)
        for (paramType in sig.paramTypes) {
            match (bareGenericConstraintKind(paramType, inputPosition: true)) {
                case Some((name, kind)) =>
                    if (kinds.contains(name)) {
                        kinds[name] = mergeWinrtGenericConstraintKind(kinds[name], kind)
                    }
                case None => ()
            }
            mergeWinrtConstraintKindsFromMetadataType(index, paramType, kinds, seen)
        }
        methodRow += 1
    }

    for (iface in winrtDirectInterfaceTypes(index, fileIdx, row, genericsArray)) {
        mergeWinrtConstraintKindsFromInstantiatedType(index, iface, kinds, seen)
    }

    seen.remove(typeKey)
    return kinds
}

public func winrtGenericConstraintKindsForInterface(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    genericParams: ArrayList<String>,
    genericsArray: Array<MetadataType>
): HashMap<String, WinrtGenericConstraintKind> {
    let seen = HashMap<String, Bool>()
    return winrtGenericConstraintKindsForInterfaceInternal(index, fileIdx, row, genericParams, genericsArray, seen)
}

public func winrtConstraintClauseForGeneric(
    genericParam: String,
    kinds: HashMap<String, WinrtGenericConstraintKind>
): String {
    match (kinds[genericParam]) {
        case WinrtGenericConstraintKind.RuntimeOnly =>
            return "${genericParam} <: windows_core.RuntimeType"
        case WinrtGenericConstraintKind.WinrtGeneric =>
            return "${genericParam} <: windows_core.RuntimeType & windows_core.WinrtGenericType<${genericParam}>"
        case WinrtGenericConstraintKind.HandleOnly =>
            return "${genericParam} <: windows_core.RuntimeType & windows_core.HandleWinrtType<${genericParam}>"
    }
}

public func metadataTypeContainsBareGeneric(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.Generic(_, _) => true
        case MetadataType.MdArray(_) => false
        case MetadataType.RefMut(_) => false
        case MetadataType.RefConst(_) => false
        case MetadataType.PtrMut(_, _) => false
        case MetadataType.PtrConst(_, _) => false
        case MetadataType.ArrayFixed(_, _) => false
        case MetadataType.Packed(_, _) => false
        case _ => false
    }
}

public func winrtMethodNeedsGenericAbiBridge(sig: MethodSignature): Bool {
    if (metadataTypeContainsBareGeneric(sig.returnType)) {
        return true
    }
    for (paramType in sig.paramTypes) {
        if (metadataTypeContainsBareGeneric(paramType)) {
            return true
        }
    }
    return false
}

public func winrtMethodHasArrayParam(sig: MethodSignature): Bool {
    for (paramType in sig.paramTypes) {
        match (paramType) {
            case MetadataType.MdArray(_) => return true
            case _ => ()
        }
    }
    return false
}

public func winrtMethodHasArrayReturn(sig: MethodSignature): Bool {
    match (sig.returnType) {
        case MetadataType.MdArray(_) => true
        case _ => false
    }
}

public func substituteMethodSignature(sig: MethodSignature, genericArgs: ArrayList<MetadataType>): MethodSignature {
    if (genericArgs.isEmpty()) {
        return sig
    }

    let result = MethodSignature()
    result.flags = sig.flags
    result.returnType = substituteMetadataType(sig.returnType, genericArgs)
    for (paramType in sig.paramTypes) {
        result.paramTypes.add(substituteMetadataType(paramType, genericArgs))
    }
    return result
}

public func substituteMetadataType(ty: MetadataType, genericArgs: ArrayList<MetadataType>): MetadataType {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            return MetadataType.ClassName(substituteTypeName(typeName, genericArgs))
        case MetadataType.ValueName(typeName) =>
            return MetadataType.ValueName(substituteTypeName(typeName, genericArgs))
        case MetadataType.Union(typeName) =>
            return MetadataType.Union(substituteTypeName(typeName, genericArgs))
        case MetadataType.MdArray(inner) =>
            return MetadataType.MdArray(substituteMetadataType(inner, genericArgs))
        case MetadataType.Generic(name, pos) =>
            if (Int64(pos) < Int64(genericArgs.size)) {
                return genericArgs[Int64(pos)]
            }
            return ty
        case MetadataType.RefMut(inner) =>
            return MetadataType.RefMut(substituteMetadataType(inner, genericArgs))
        case MetadataType.RefConst(inner) =>
            return MetadataType.RefConst(substituteMetadataType(inner, genericArgs))
        case MetadataType.PtrMut(inner, depth) =>
            return MetadataType.PtrMut(substituteMetadataType(inner, genericArgs), depth)
        case MetadataType.PtrConst(inner, depth) =>
            return MetadataType.PtrConst(substituteMetadataType(inner, genericArgs), depth)
        case MetadataType.ArrayFixed(inner, size) =>
            return MetadataType.ArrayFixed(substituteMetadataType(inner, genericArgs), size)
        case MetadataType.Packed(inner, packing) =>
            return MetadataType.Packed(substituteMetadataType(inner, genericArgs), packing)
        case _ => return ty
    }
}

func substituteTypeName(typeName: TypeName, genericArgs: ArrayList<MetadataType>): TypeName {
    if (typeName.generics.isEmpty()) {
        return TypeName(typeName.namespace, typeName.name)
    }

    let substitutedGenerics = ArrayList<MetadataType>()
    for (generic in typeName.generics) {
        substitutedGenerics.add(substituteMetadataType(generic, genericArgs))
    }
    return TypeName(typeName.namespace, typeName.name, substitutedGenerics)
}

func isReferenceProjectionType(index: TypeIndex, typeName: TypeName): Bool {
    let resolvedTypeName = qualifyTypeNameWithCurrentNamespace(typeName)
    let candidates = index.get(resolvedTypeName.namespace, trimTick(resolvedTypeName.name))
    if (candidates.isEmpty()) {
        return false
    }
    let (fileIdx, row) = candidates[0]
    return isReferenceCategory(index.typeDefCategory(fileIdx, row))
}

func isNativeDelegateTypeName(index: TypeIndex, typeName: TypeName): Bool {
    let resolvedTypeName = qualifyTypeNameWithCurrentNamespace(typeName)
    let candidates = index.get(resolvedTypeName.namespace, trimTick(resolvedTypeName.name))
    for ((fileIdx, row) in candidates) {
        match (index.typeDefCategory(fileIdx, row)) {
            case TypeCategory.Delegate =>
                return !index.typeDefFlags(fileIdx, row).contains(TypeAttributes.WindowsRuntime)
            case _ => ()
        }
    }
    return false
}

func qualifyTypeNameWithCurrentNamespace(typeName: TypeName): TypeName {
    if (!typeName.namespace.isEmpty()) {
        return typeName
    }
    let namespace = currentNamespace()
    if (namespace.isEmpty()) {
        return typeName
    }
    return TypeName(namespace, typeName.name, typeName.generics)
}

func qualifyMetadataTypeWithNamespace(namespace: String, ty: MetadataType): MetadataType {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            return MetadataType.ClassName(qualifyTypeNameWithNamespace(namespace, typeName))
        case MetadataType.ValueName(typeName) =>
            return MetadataType.ValueName(qualifyTypeNameWithNamespace(namespace, typeName))
        case MetadataType.Union(typeName) =>
            return MetadataType.Union(qualifyTypeNameWithNamespace(namespace, typeName))
        case MetadataType.MdArray(inner) =>
            return MetadataType.MdArray(qualifyMetadataTypeWithNamespace(namespace, inner))
        case MetadataType.RefMut(inner) =>
            return MetadataType.RefMut(qualifyMetadataTypeWithNamespace(namespace, inner))
        case MetadataType.RefConst(inner) =>
            return MetadataType.RefConst(qualifyMetadataTypeWithNamespace(namespace, inner))
        case MetadataType.PtrMut(inner, depth) =>
            return MetadataType.PtrMut(qualifyMetadataTypeWithNamespace(namespace, inner), depth)
        case MetadataType.PtrConst(inner, depth) =>
            return MetadataType.PtrConst(qualifyMetadataTypeWithNamespace(namespace, inner), depth)
        case MetadataType.ArrayFixed(inner, size) =>
            return MetadataType.ArrayFixed(qualifyMetadataTypeWithNamespace(namespace, inner), size)
        case MetadataType.Packed(inner, packing) =>
            return MetadataType.Packed(qualifyMetadataTypeWithNamespace(namespace, inner), packing)
        case _ => return ty
    }
}

func qualifyTypeNameWithNamespace(namespace: String, typeName: TypeName): TypeName {
    if (!typeName.namespace.isEmpty() || namespace.isEmpty()) {
        return typeName
    }
    return TypeName(namespace, typeName.name, typeName.generics)
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
