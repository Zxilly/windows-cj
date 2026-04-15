package windows_bindgen

import std.collection.*
import windows_metadata.*

public func typeAvailabilityTags(
    namespace: String,
    name: String,
    fileIdx: Int64,
    row: Int64,
    arches: String
): ArrayList<String> {
    match (bindgenContext()) {
        case Some(context) =>
            let tags = context.typeMap.cfgForType(namespace, name, fileIdx, row)
            if (!tags.isEmpty()) {
                return tags
            }
            return architectureCfgTags(arches)
        case None =>
            return architectureCfgTags(arches)
    }
}

public func itemAvailabilityTags(table: Int64, fileIdx: Int64, row: Int64): ArrayList<String> {
    match (bindgenContext()) {
        case Some(context) => context.typeMap.cfgForItem(table, fileIdx, row)
        case None => ArrayList<String>()
    }
}

public func missingMethodDependencies(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    generics: Array<MetadataType>
): ArrayList<TypeName> {
    let dependencies = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()
    let missing = ArrayList<TypeName>()

    let signature = index.methodDefSignature(fileIdx, row, generics)
    collectMetadataTypeDependencies(signature.returnType, dependencies, seen)
    for (paramType in signature.paramTypes) {
        collectMetadataTypeDependencies(paramType, dependencies, seen)
    }

    match (bindgenContext()) {
        case Some(context) =>
            for (dependency in dependencies) {
                let dependencyName = dependency.definition()
                if (dependencyName.namespace.isEmpty() || dependencyName.namespace == "System") {
                    continue
                }
                if (context.references.containsType(dependencyName.namespace, trimTick(dependencyName.name))) {
                    continue
                }
                if (context.typeMap.containsType(dependencyName) &&
                    hasEmittableEntry(index, dependencyName)) {
                    continue
                }
                if (!containsTypeName(missing, dependencyName)) {
                    missing.add(dependencyName)
                }
            }
        case None => ()
    }

    sortTypeNames(missing)
    return missing
}

// A type is emittable when at least one of its winmd rows targets a supported
// architecture. Types with all rows marked unsupported are silently filtered at
// emit time and must not be considered as satisfied dependencies.
func hasEmittableEntry(index: TypeIndex, typeName: TypeName): Bool {
    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return false
    }
    for ((fi, ri) in candidates) {
        if (!isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fi, ri))) {
            return true
        }
    }
    return false
}

public func warnMissingMethodDependencies(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    dependencies: ArrayList<TypeName>
): Unit {
    if (dependencies.isEmpty()) {
        return
    }

    match (bindgenContext()) {
        case Some(context) =>
            context.warnings.skipMethod(MethodDefRef(index, fileIdx, row), dependencies, context.typeMap, context.config)
        case None => ()
    }
}
