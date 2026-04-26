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
    config: BindgenConfig,
    perTypeFragments: HashMap<String, String>
): Int64 {
    // Render every type's fragment in parallel; emit serially in input order
    // so generated output remains deterministic.
    return emitRenderedFragments(w, perTypeFragments,
        renderTypeFragmentsParallel(index, namespace, types, features, config, true))
}

func emitHighLevelNamespaceItem(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    ty: BindgenType,
    features: FeatureCollector,
    config: BindgenConfig
): Int64 {
    let fileIdx = bindgenTypeFileIdx(ty)
    let row = bindgenTypeRow(ty)

    match (ty) {
        case HighLevelInterface(_) =>
            generateWinrtInterface(w, index, fileIdx, row, namespace, config)
            return 1
        case CppInterface(_) =>
            generateComInterface(w, index, fileIdx, row, namespace)
            return 1
        case Handle(_) =>
            generateHandle(w, index, fileIdx, row, namespace)
            return 1
        case HighLevelStruct(_) =>
            generateStruct(w, index, fileIdx, row, namespace, winrtProjection: true)
            return 1
        case CppStruct(_) =>
            generateStruct(w, index, fileIdx, row, namespace, winrtProjection: false)
            return 1
        case HighLevelEnum(_) =>
            generateEnum(w, index, fileIdx, row, namespace, winrtProjection: true)
            return 1
        case CppEnum(_) =>
            generateEnum(w, index, fileIdx, row, namespace, winrtProjection: false)
            return 1
        case HighLevelDelegate(_) =>
            generateWinrtDelegate(w, index, fileIdx, row, namespace)
            return 1
        case CppDelegate(_) =>
            generateDelegate(w, index, fileIdx, row, namespace)
            return 1
        case HighLevelClass(_) =>
            generateWinrtClass(w, index, fileIdx, row, namespace, config)
            return 1
        case CppFn(_) =>
            generateFunctions(w, index, fileIdx, row, namespace)
            generateConstants(w, index, fileIdx, row, namespace)
            collectFeatures(index, fileIdx, row, namespace, features)
            return 1
        case Attribute(_) =>
            return 0
    }
}
