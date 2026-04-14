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
        case MetadataType.ArrayFixed(elem, size) => "VArray<${metadataTypeToCppCj(elem)}, \$${size}>"
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
                        match (delegateTypeCppDefaultValue(context.index, fileIdx, row)) {
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

func delegateTypeCppDefaultValue(index: TypeIndex, fileIdx: Int64, row: Int64): Option<String> {
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        if (index.methodDefName(fileIdx, methodRow) == "Invoke") {
            let generics = Array<MetadataType>(0, {_ => MetadataType.Void})
            let sig = index.methodDefSignature(fileIdx, methodRow, generics)
            return Some(defaultCallbackLiteral(sig))
        }
        methodRow += 1
    }
    return None
}

func defaultCallbackLiteral(sig: MethodSignature): String {
    let paramNames = ArrayList<String>()
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        paramNames.add("_")
        pi += 1
    }
    let params = joinStrings(paramNames, ", ")
    let returnType = cppType(sig.returnType)
    if (returnType == "Unit") {
        return "{ ${params} => () }"
    }
    return "{ ${params} => ${cppDefaultValue(sig.returnType)} }"
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
