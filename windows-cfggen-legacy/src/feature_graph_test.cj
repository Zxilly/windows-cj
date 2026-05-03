package windows_cfggen

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testResolveFeatureClosureIncludesTransitiveDependencies() {
    let catalog = HashMap<String, FeatureSpec>()
    addTestFeature(catalog, "Microsoft_UI_Xaml", ["Microsoft_UI_Composition"])
    addTestFeature(catalog, "Microsoft_UI_Composition", ["Windows_Graphics"])
    addTestFeature(catalog, "Windows_Graphics", Array<String>())

    let enabled = ArrayList<String>()
    enabled.add("Microsoft_UI_Xaml")
    let resolved = resolveFeatureClosure(enabled, catalog)

    @Expect(resolved.size, 3)
    @Expect(resolvedContains(resolved, "Microsoft_UI_Xaml"), true)
    @Expect(resolvedContains(resolved, "Microsoft_UI_Composition"), true)
    @Expect(resolvedContains(resolved, "Windows_Graphics"), true)
}

@Test
func testResolveFeatureClosureHandlesDependencyCycle() {
    let catalog = HashMap<String, FeatureSpec>()
    addTestFeature(catalog, "A", ["B"])
    addTestFeature(catalog, "B", ["A"])

    let enabled = ArrayList<String>()
    enabled.add("A")
    let resolved = resolveFeatureClosure(enabled, catalog)

    @Expect(resolved.size, 2)
    @Expect(resolvedContains(resolved, "A"), true)
    @Expect(resolvedContains(resolved, "B"), true)
}

func addTestFeature(catalog: HashMap<String, FeatureSpec>, name: String, deps: Array<String>): Unit {
    let spec = FeatureSpec(name)
    spec.cfg = name
    for (dep in deps) {
        spec.deps.add(dep)
    }
    catalog.add(name, spec)
}

func resolvedContains(resolved: ArrayList<FeatureSpec>, name: String): Bool {
    for (spec in resolved) {
        if (spec.name == name) {
            return true
        }
    }
    return false
}
