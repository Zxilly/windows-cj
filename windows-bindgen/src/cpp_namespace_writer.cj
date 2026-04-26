package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.types.*

public func writeCppNamespace(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    types: ArrayList<BindgenType>,
    features: FeatureCollector,
    perTypeFragments: HashMap<String, String>,
    config: BindgenConfig
): Int64 {
    // Preserve the historical two-phase emission: non-CppFn types first, then
    // CppFn types. Within each phase render the per-type fragments in
    // parallel, then serialise them back into `w` in original order so the
    // generated source is deterministic.
    let nonFnTypes = ArrayList<BindgenType>()
    let fnTypes = ArrayList<BindgenType>()
    for (ty in types) {
        match (ty) {
            case CppFn(_) => fnTypes.add(ty)
            case _ => nonFnTypes.add(ty)
        }
    }

    var typeCount: Int64 = 0
    typeCount += emitRenderedFragments(w, perTypeFragments,
        renderTypeFragmentsParallel(index, namespace, nonFnTypes, features, config, false))
    typeCount += emitRenderedFragments(w, perTypeFragments,
        renderTypeFragmentsParallel(index, namespace, fnTypes, features, config, false))
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
            generateStruct(w, index, fileIdx, row, namespace, winrtProjection: false)
            return 1
        case CppEnum(_) =>
            generateEnum(w, index, fileIdx, row, namespace, winrtProjection: false)
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
