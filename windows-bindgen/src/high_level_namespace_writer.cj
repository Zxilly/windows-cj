package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.types.*

public func writeHighLevelNamespace(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    types: ArrayList<BindgenType>,
    features: FeatureCollector,
    config: BindgenConfig
): Int64 {
    var typeCount: Int64 = 0
    for (ty in types) {
        let fileIdx = bindgenTypeFileIdx(ty)
        let row = bindgenTypeRow(ty)

        match (ty) {
            case HighLevelInterface(_) =>
                generateWinrtInterface(w, index, fileIdx, row, namespace, config)
                typeCount += 1
            case CppInterface(_) =>
                generateComInterface(w, index, fileIdx, row, namespace)
                typeCount += 1
            case Handle(_) =>
                generateHandle(w, index, fileIdx, row, namespace)
                typeCount += 1
            case HighLevelStruct(_) | CppStruct(_) =>
                generateStruct(w, index, fileIdx, row, namespace)
                typeCount += 1
            case HighLevelEnum(_) | CppEnum(_) =>
                generateEnum(w, index, fileIdx, row, namespace)
                typeCount += 1
            case HighLevelDelegate(_) =>
                generateWinrtDelegate(w, index, fileIdx, row, namespace)
                typeCount += 1
            case CppDelegate(_) =>
                generateDelegate(w, index, fileIdx, row, namespace)
                typeCount += 1
            case HighLevelClass(_) =>
                generateWinrtClass(w, index, fileIdx, row, namespace, config)
                typeCount += 1
            case CppFn(_) =>
                generateFunctions(w, index, fileIdx, row, namespace)
                generateConstants(w, index, fileIdx, row, namespace)
                collectFeatures(index, fileIdx, row, namespace, features)
                typeCount += 1
            case Attribute(_) =>
                ()
        }
    }
    return typeCount
}
