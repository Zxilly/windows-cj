package windows_bindgen

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func namespaceToCfgVarReplacesDots(): Unit {
    @Expect(namespaceToCfgVar("Microsoft.UI.Composition"), "Microsoft_UI_Composition")
    @Expect(namespaceToCfgVar("Windows.Foundation"), "Windows_Foundation")
    @Expect(namespaceToCfgVar("Windows"), "Windows")
    @Expect(namespaceToCfgVar(""), "Windows_root")
}

@Test
func cfgGateAnnotationFormat(): Unit {
    @Expect(cfgGateAnnotation("Windows.Foundation"), "@When[Windows_Foundation == \"on\"]")
}

@Test
func gatePrefixFormat(): Unit {
    @Expect(gatePrefix("Windows.Foundation"), "@When[Windows_Foundation == \"on\"]\n")
    @Expect(gatePrefix(""), "@When[Windows_root == \"on\"]\n")
}

@Test
func renderCfgTomlEmitsOffEntries(): Unit {
    let vars = ArrayList<String>()
    vars.add("Windows_Foundation")
    vars.add("Microsoft_UI")
    let rendered = renderCfgToml(vars)
    @Expect(rendered, "Windows_Foundation = \"off\"\nMicrosoft_UI = \"off\"\n")
}

@Test
func computeNamespaceDependenciesEdges(): Unit {
    let symbols = ArrayList<SymbolRecord>()
    symbols.add(SymbolRecord(
        "A.Foo", "A", "Foo", "A_Foo",
        ["B.Bar", "A.Baz"],
    ))
    symbols.add(SymbolRecord(
        "B.Bar", "B", "Bar", "B_Bar",
        [],
    ))
    symbols.add(SymbolRecord(
        "A.Baz", "A", "Baz", "A_Baz",
        [],
    ))
    let byName = recordsByFullName(symbols)
    let edges = computeNamespaceDependencies(symbols, byName)
    // A depends on B (via B.Bar); the intra-namespace A.Baz edge is dropped.
    let aDeps = match (edges.get("A")) {
        case Some(found) => found
        case None => ArrayList<String>()
    }
    @Expect(aDeps.size, 1)
    @Expect(aDeps[0], "B")
    // B has no outgoing edges.
    let bDeps = match (edges.get("B")) {
        case Some(found) => found
        case None => ArrayList<String>()
    }
    @Expect(bDeps.size, 0)
}

@Test
func renderNamespaceDepsJsonStable(): Unit {
    let edges = HashMap<String, ArrayList<String>>()
    let aDeps = ArrayList<String>()
    aDeps.add("B")
    edges.add("A", aDeps)
    edges.add("B", ArrayList<String>())
    let json = renderNamespaceDepsJson(edges)
    @Expect(json, "{\n  \"A\": [\"B\"],\n  \"B\": []\n}\n")
}
