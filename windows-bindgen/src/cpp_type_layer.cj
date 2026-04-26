package windows_bindgen

import std.collection.*
import windows_metadata.*

// Explicit low-level type layer for sys/@C projection code generation.
public func cppType(ty: MetadataType): String {
    return metadataTypeToCppCj(ty)
}

public func cppDefaultValue(ty: MetadataType): String {
    return metadataTypeToCppDefaultValue(ty)
}

public func cppConstantType(ty: MetadataType): String {
    return constantTypeToCj(ty)
}

func metadataTypeToCppCj(ty: MetadataType): String {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            if (isReferenceTypeName(typeName)) {
                return "CPointer<Unit>"
            }
            return metadataTypeToCj(ty)
        case MetadataType.ValueName(typeName) =>
            if (isReferenceTypeName(typeName)) {
                return "CPointer<Unit>"
            }
            match (referencedCppSupportType(typeName)) {
                case Some(projected) => return projected
                case None => ()
            }
            match (enumUnderlyingMetadataType(typeName)) {
                case Some(underlying) => return metadataTypeToCppCj(underlying)
                case None => ()
            }
            return metadataTypeToCj(ty)
        case MetadataType.Union(typeName) =>
            if (isReferenceTypeName(typeName)) {
                return "CPointer<Unit>"
            }
            return metadataTypeToCj(ty)
        case MetadataType.MdArray(elem) => "CPointer<${metadataTypeToCppCj(elem)}>"
        case MetadataType.RefMut(inner) => "CPointer<${metadataTypeToCppCj(inner)}>"
        case MetadataType.RefConst(inner) => "CPointer<${metadataTypeToCppCj(inner)}>"
        case MetadataType.PtrMut(inner, depth) => wrapCppPointer(inner, depth)
        case MetadataType.PtrConst(inner, depth) => wrapCppPointer(inner, depth)
        case MetadataType.ArrayFixed(elem, size) =>
            if (isDelegateArrayMetadataType(elem)) {
                if (size == 1) {
                    return metadataTypeToCppCj(elem)
                }
                return "VArray<CPointer<Unit>, \$${size}>"
            }
            return "VArray<${metadataTypeToCppCj(elem)}, \$${size}>"
        case MetadataType.Packed(inner, _) => metadataTypeToCppCj(inner)
        case _ => metadataTypeToCj(ty)
    }
}

func metadataTypeToCppDefaultValue(ty: MetadataType): String {
    match (ty) {
        case MetadataType.ClassName(typeName) =>
            if (isReferenceTypeName(typeName)) {
                return "CPointer<Unit>()"
            }
            return namedTypeCppDefaultValue(typeName, ty)
        case MetadataType.ValueName(typeName) =>
            if (isReferenceTypeName(typeName)) {
                return "CPointer<Unit>()"
            }
            match (referencedCppSupportType(typeName)) {
                case Some(projected) => return "${projected}()"
                case None => ()
            }
            match (enumUnderlyingMetadataType(typeName)) {
                case Some(underlying) => return metadataTypeToCppDefaultValue(underlying)
                case None => ()
            }
            return namedTypeCppDefaultValue(typeName, ty)
        case MetadataType.Union(typeName) =>
            if (isReferenceTypeName(typeName)) {
                return "CPointer<Unit>()"
            }
            return namedTypeCppDefaultValue(typeName, ty)
        case MetadataType.MdArray(_) => "${metadataTypeToCppCj(ty)}()"
        case MetadataType.RefMut(_) => "${metadataTypeToCppCj(ty)}()"
        case MetadataType.RefConst(_) => "${metadataTypeToCppCj(ty)}()"
        case MetadataType.PtrMut(_, _) => "${metadataTypeToCppCj(ty)}()"
        case MetadataType.PtrConst(_, _) => "${metadataTypeToCppCj(ty)}()"
        case MetadataType.ArrayFixed(elem, size) =>
            if (isDelegateArrayMetadataType(elem)) {
                if (size == 1) {
                    return metadataTypeToCppDefaultValue(elem)
                }
                return "VArray<CPointer<Unit>, \$${size}>(repeat: CPointer<Unit>())"
            }
            "VArray<${metadataTypeToCppCj(elem)}, \$${size}>(repeat: ${metadataTypeToCppDefaultValue(elem)})"
        case MetadataType.Packed(inner, _) => metadataTypeToCppDefaultValue(inner)
        case _ => metadataTypeDefaultValue(ty)
    }
}

func namedTypeCppDefaultValue(typeName: TypeName, ty: MetadataType): String {
    match (bindgenContext()) {
        case Some(context) =>
            let candidates = context.index.get(typeName.namespace, trimTick(typeName.name))
            for ((fileIdx, row) in candidates) {
                match (context.index.typeDefCategory(fileIdx, row)) {
                    case Delegate =>
                        match (delegateTypeCppDefaultValue(typeName, context.index, fileIdx, row)) {
                            case Some(value) => return value
                            case None => ()
                        }
                    case _ => ()
                }
                if (isHandleType(context.index, fileIdx, row)) {
                    let (fieldStart, _) = context.index.typeDefFields(fileIdx, row)
                    let handleType = handleAliasToCj(typeName.namespace, trimTick(typeName.name), cppType(context.index.fieldType(fileIdx, fieldStart)))
                    if (isPrimitiveCjType(handleType)) {
                        return "0"
                    }
                    return "${handleType}()"
                }
            }
            return metadataTypeDefaultValue(ty)
        case None =>
            return metadataTypeDefaultValue(ty)
    }
}

func referencedCppSupportType(typeName: TypeName): Option<String> {
    if (!isReferencedCppSupportType(typeName)) {
        return None
    }

    let name = trimTick(typeName.name)
    match (bindgenContext()) {
        case Some(context) =>
            match (context.references.importPathForType(typeName.namespace, name)) {
                case Some(importPath) =>
                    if (importPath == "windows_core" || importPath == "windows_result") {
                        return Some("${importPath}.${name}")
                    }
                    return None
                case None =>
                    return None
            }
        case None =>
            return None
    }
}

func isReferencedCppSupportType(typeName: TypeName): Bool {
    let name = trimTick(typeName.name)
    if (typeName.namespace == "Windows.Win32.Foundation") {
        return name == "WIN32_ERROR" || name == "NTSTATUS"
    }
    if (typeName.namespace == "Windows.Win32.System.Rpc") {
        return name == "RPC_STATUS"
    }
    return false
}

func enumUnderlyingMetadataType(typeName: TypeName): Option<MetadataType> {
    if (typeName.namespace.isEmpty()) {
        return None
    }

    match (bindgenContext()) {
        case Some(context) =>
            let candidates = context.index.get(typeName.namespace, trimTick(typeName.name))
            for ((fileIdx, row) in candidates) {
                match (context.index.typeDefCategory(fileIdx, row)) {
                    case Enum => return Some(enumUnderlyingMetadataTypeForType(context.index, fileIdx, row))
                    case _ => ()
                }
            }
            return None
        case None =>
            return None
    }
}

func enumUnderlyingMetadataTypeForType(index: TypeIndex, fileIdx: Int64, row: Int64): MetadataType {
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        if (index.fieldName(fileIdx, fieldRow) == "value__") {
            return index.fieldType(fileIdx, fieldRow)
        }
        fieldRow += 1
    }
    return MetadataType.I32
}

func delegateTypeCppDefaultValue(
    typeName: TypeName,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64
): Option<String> {
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        if (index.methodDefName(fileIdx, methodRow) == "Invoke") {
            let generics = Array<MetadataType>(0, {_ => MetadataType.Void})
            let signature = index.methodDefSignature(fileIdx, methodRow, generics)
            return Some(delegateNullDefaultValue(typeName.namespace, signature))
        }
        methodRow += 1
    }
    return None
}

func delegateNullDefaultValue(namespace: String, sig: MethodSignature): String {
    return "${delegateCFuncType(namespace, sig)}(CPointer<Unit>())"
}

func delegateCFuncType(namespace: String, sig: MethodSignature): String {
    let params = ArrayList<String>()
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        params.add(functionAbiTypeForPointerInNamespace(namespace, sig.paramTypes[pi]))
        pi += 1
    }
    let returnType = functionAbiTypeForPointerInNamespace(namespace, sig.returnType)
    return "CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>"
}

func delegateLambdaDefaultValue(namespace: String, sig: MethodSignature): String {
    let params = ArrayList<String>()
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        params.add("_")
        pi += 1
    }

    let returnType = functionAbiTypeForPointerInNamespace(namespace, sig.returnType)
    let returnDefault = highLevelResultDefaultExpr(returnType)
    if (params.isEmpty()) {
        return "{ => ${returnDefault} }"
    }
    return "{ ${joinStrings(params, ", ")} => ${returnDefault} }"
}

func wrapCppPointer(inner: MetadataType, depth: Int64): String {
    var result = metadataTypeToCppCj(inner)
    var d = depth
    while (d > 0) {
        result = "CPointer<${result}>"
        d -= 1
    }
    return result
}

func isReferenceTypeName(typeName: TypeName): Bool {
    match (bindgenContext()) {
        case Some(context) =>
            let candidates = context.index.get(typeName.namespace, trimTick(typeName.name))
            if (candidates.isEmpty()) {
                return false
            }

            for ((fileIdx, row) in candidates) {
                match (context.index.typeDefCategory(fileIdx, row)) {
                    case Interface => return true
                    case Class => return true
                    case _ => ()
                }
            }
            return false
        case None =>
            return false
    }
}

func isDelegateArrayMetadataType(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.ValueName(typeName) => return isDelegateTypeName(typeName)
        case MetadataType.ClassName(typeName) => return isDelegateTypeName(typeName)
        case MetadataType.Union(typeName) => return isDelegateTypeName(typeName)
        case MetadataType.Packed(inner, _) => return isDelegateArrayMetadataType(inner)
        case _ => return false
    }
}

func isDelegateTypeName(typeName: TypeName): Bool {
    match (bindgenContext()) {
        case Some(context) =>
            let candidates = context.index.get(typeName.namespace, trimTick(typeName.name))
            for ((fileIdx, row) in candidates) {
                match (context.index.typeDefCategory(fileIdx, row)) {
                    case Delegate => return true
                    case _ => ()
                }
            }
            return false
        case None =>
            return false
    }
}
