package windows_sync

import std.collection.*

public func resolveFeatureClosure(
    enabledFeatures: ArrayList<String>,
    catalog: HashMap<String, FeatureSpec>
): ArrayList<FeatureSpec> {
    let visiting = HashMap<String, Bool>()
    let selected = HashMap<String, Bool>()
    var orderedNames = ArrayList<String>()

    for (feature in enabledFeatures) {
        visitFeature(feature, catalog, visiting, selected, orderedNames)
    }

    sortStrings(orderedNames)

    var resolved = ArrayList<FeatureSpec>()
    for (name in orderedNames) {
        resolved.add(catalog.get(name).getOrThrow())
    }
    return resolved
}

func visitFeature(
    name: String,
    catalog: HashMap<String, FeatureSpec>,
    visiting: HashMap<String, Bool>,
    selected: HashMap<String, Bool>,
    orderedNames: ArrayList<String>
): Unit {
    if (selected.contains(name)) {
        return
    }
    if (!catalog.contains(name)) {
        throw Exception("unknown feature: ${name}")
    }
    if (visiting.contains(name)) {
        throw Exception("cyclic feature dependency detected: ${name}")
    }

    visiting.add(name, true)
    let spec = catalog.get(name).getOrThrow()
    for (dep in spec.deps) {
        visitFeature(dep, catalog, visiting, selected, orderedNames)
    }
    visiting.add(name, false)
    selected.add(name, true)
    orderedNames.add(name)
}

func sortStrings(values: ArrayList<String>): Unit {
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && values[j] > key) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}
