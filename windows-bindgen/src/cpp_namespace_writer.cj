package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.types.*

public func writeCppNamespace(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    types: ArrayList<BindgenType>,
    features: FeatureCollector
): Int64 {
    var typeCount: Int64 = 0

    for (ty in types) {
        match (ty) {
            case CppFn(_) => ()
            case _ =>
                typeCount += emitCppNamespaceItem(w, index, namespace, ty, features)
        }
    }
    for (ty in types) {
        match (ty) {
            case CppFn(_) =>
                typeCount += emitCppNamespaceItem(w, index, namespace, ty, features)
            case _ => ()
        }
    }
    return typeCount
}

func emitCppNamespaceItem(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    ty: BindgenType,
    features: FeatureCollector
): Int64 {
    let fileIdx = bindgenTypeFileIdx(ty)
    let row = bindgenTypeRow(ty)
    match (ty) {
        case CppInterface(_) =>
            generateComInterface(w, index, fileIdx, row, namespace)
            return 1
        case Handle(_) =>
            generateHandle(w, index, fileIdx, row, namespace)
            return 1
        case CppStruct(_) =>
            generateStruct(w, index, fileIdx, row, namespace)
            return 1
        case CppEnum(_) =>
            generateEnum(w, index, fileIdx, row, namespace)
            return 1
        case CppDelegate(_) =>
            generateDelegate(w, index, fileIdx, row, namespace)
            return 1
        case CppFn(_) =>
            generateFunctions(w, index, fileIdx, row, namespace)
            generateConstants(w, index, fileIdx, row, namespace)
            collectFeatures(index, fileIdx, row, namespace, features)
            return 1
        case Attribute(_) =>
            return 0
        case HighLevelClass(_) | HighLevelDelegate(_) | HighLevelEnum(_) | HighLevelInterface(_) | HighLevelStruct(_) =>
            throw Exception("high-level bindgen type reached sys emitter")
    }
}
