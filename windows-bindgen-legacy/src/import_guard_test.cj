package windows_bindgen

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testGeneratedPackageImportGuardCombinesCurrentAndDependencyFeature() {
    @Expect(
        guardedPackageImportCondition(
            "Windows.Win32.UI.Controls",
            "windows_sys.Win32.Graphics.Gdi"
        ),
        "Windows_Win32_UI_Controls == \"on\" && Windows_Win32_Graphics_Gdi == \"on\""
    )
}

@Test
func testNamespacePackageImportGuardPreservesWindowsRoot() {
    @Expect(
        guardedPackageImportCondition(
            "Windows.Win32.UI.Controls",
            "Windows.Win32.Graphics.Gdi"
        ),
        "Windows_Win32_UI_Controls == \"on\" && Windows_Win32_Graphics_Gdi == \"on\""
    )
}

@Test
func testReferencePackageImportGuardCombinesCurrentAndDependencyFeature() {
    @Expect(
        guardedPackageImportCondition(
            "Microsoft.UI.Xaml.Markup",
            "windows.Foundation"
        ),
        "Microsoft_UI_Xaml_Markup == \"on\" && Windows_Foundation == \"on\""
    )
}

@Test
func testNamespacePackageImportGuardPreservesMicrosoftRoot() {
    @Expect(
        guardedPackageImportCondition(
            "Microsoft.UI.Xaml.Markup",
            "Microsoft.UI.Xaml.Controls"
        ),
        "Microsoft_UI_Xaml_Markup == \"on\" && Microsoft_UI_Xaml_Controls == \"on\""
    )
}

@Test
func testSupportPackageImportGuardUsesCurrentFeatureOnly() {
    @Expect(
        guardedPackageImportCondition(
            "Microsoft.UI.Xaml.Markup",
            "windows_future"
        ),
        "Microsoft_UI_Xaml_Markup == \"on\""
    )
}

@Test
func testInternalImplImportGuardUsesCurrentFeatureOnly() {
    @Expect(
        guardedPackageImportCondition(
            "Windows.UI.Composition",
            "windows.impl"
        ),
        "Windows_UI_Composition == \"on\""
    )
    @Expect(
        guardedPackageImportCondition(
            "Windows.UI.Composition",
            "windows.impl.s_12345"
        ),
        "Windows_UI_Composition == \"on\""
    )
}

@Test
func testPackageImportToFeatureNamespaceHidesInternalImplPackages() {
    @Expect(packageImportToFeatureNamespace("windows.impl").isNone(), true)
    @Expect(packageImportToFeatureNamespace("windows.impl.s_12345").isNone(), true)
    @Expect(packageImportToFeatureNamespace("windows.UI.Xaml.impl").isNone(), true)
    @Expect(packageImportToFeatureNamespace("windows.UI.Xaml.impl.s_12345").isNone(), true)
}

func tomlContains(text: String, needle: String): Bool {
    return text.indexOf(needle, 0).isSome()
}

@Test
func testFeatureCatalogEmitsNamespaceDependencies() {
    let features = FeatureCollector()
    features.addNamespace("Microsoft.UI.Composition.Effects")
    features.addNamespace("Microsoft.UI.Xaml.Markup")
    features.addNamespaceDependency("Microsoft.UI.Xaml.Markup", "Microsoft.UI.Composition.Effects")

    let toml = features.generateFeaturesToml(true)
    @Expect(tomlFeatureDeps(toml, "Microsoft_UI_Xaml_Markup",
        "[\"Microsoft_UI_Composition_Effects\"]"),
        true)
}

@Test
func testFeatureCatalogDoesNotAddParentNamespaceAsImplicitDependency() {
    let features = FeatureCollector()
    features.addNamespace("Windows.UI.Xaml.Interop")

    let toml = features.generateFeaturesToml(true)
    @Expect(tomlFeatureDeps(toml, "Windows_UI_Xaml_Interop", "[]"), true)
}

@Test
func testFeatureCatalogEmitsFunctionDependencyClosure() {
    let features = FeatureCollector()
    features.addFunctionBinding("Windows.Win32.System.Threading", "KERNEL32.dll", "Sleep", ArrayList<String>())

    let toml = features.generateFeaturesToml(true)
    @Expect(tomlFeatureDeps(toml, "Windows_Win32_System_Threading_Sleep",
        "[\"KERNEL32\", \"Windows_Win32_System_Threading\"]"),
        true)
}

@Test
func testFeatureCatalogExtractsAvailabilityTagDependencies() {
    let features = FeatureCollector()
    let tags = ArrayList<String>()
    tags.add("Windows_UI_Core == \"on\" && arch == \"x86_64\"")
    features.addFunctionBinding("Windows.Win32.System.Threading", "KERNEL32.dll", "Sleep", tags)

    let toml = features.generateFeaturesToml(true)
    @Expect(tomlContains(toml, "deps = [\"KERNEL32\", \"Windows_UI_Core\", \"Windows_Win32_System_Threading\"]"), true)
}

func tomlFeatureDeps(text: String, feature: String, deps: String): Bool {
    return tomlContains(text, "[features.${feature}]\ncfg = \"${feature}\"\ndeps = ${deps}\n")
}

func layoutTestNamespaces(values: Array<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (value in values) {
        result.add(value)
    }
    return result
}

func layoutTestGraph(namespaces: ArrayList<String>): HashMap<String, ArrayList<String>> {
    let graph = HashMap<String, ArrayList<String>>()
    for (namespace in namespaces) {
        graph[namespace] = ArrayList<String>()
    }
    return graph
}

func addLayoutTestEdge(graph: HashMap<String, ArrayList<String>>, from: String, to: String): Unit {
    if (!graph.contains(from)) {
        graph[from] = ArrayList<String>()
    }
    graph[from].add(to)
}

@Test
func testPackageLayoutKeepsAcyclicNamespacesInOriginalPackages() {
    let namespaces = layoutTestNamespaces(["Windows.A", "Windows.B"])
    let graph = layoutTestGraph(namespaces)
    addLayoutTestEdge(graph, "Windows.A", "Windows.B")

    let layout = computePackageLayoutFromGraph(namespaces, graph)

    @Expect(layout.packageNamespaceForNamespace("Windows.A"), "Windows.A")
    @Expect(layout.packageNamespaceForNamespace("Windows.B"), "Windows.B")
    @Expect(layout.finalMultiNodeSccCount, 0)
}

@Test
func testPackageLayoutMergesOnlyNamespaceSccIntoImplPackage() {
    let namespaces = layoutTestNamespaces(["Windows.UI.A", "Windows.UI.B", "Windows.UI.C"])
    let graph = layoutTestGraph(namespaces)
    addLayoutTestEdge(graph, "Windows.UI.A", "Windows.UI.B")
    addLayoutTestEdge(graph, "Windows.UI.B", "Windows.UI.A")
    addLayoutTestEdge(graph, "Windows.UI.C", "Windows.UI.A")

    let layout = computePackageLayoutFromGraph(namespaces, graph)

    @Expect(layout.packageNamespaceForNamespace("Windows.UI.A"), "Windows.UI.impl")
    @Expect(layout.packageNamespaceForNamespace("Windows.UI.B"), "Windows.UI.impl")
    @Expect(layout.packageNamespaceForNamespace("Windows.UI.C"), "Windows.UI.C")
    @Expect(layout.finalMultiNodeSccCount, 0)
}

@Test
func testPackageLayoutAddsStableSuffixForSamePrefixSccs() {
    let namespaces = layoutTestNamespaces([
        "Windows.UI.A",
        "Windows.UI.B",
        "Windows.UI.C",
        "Windows.UI.D"
    ])
    let graph = layoutTestGraph(namespaces)
    addLayoutTestEdge(graph, "Windows.UI.A", "Windows.UI.B")
    addLayoutTestEdge(graph, "Windows.UI.B", "Windows.UI.A")
    addLayoutTestEdge(graph, "Windows.UI.C", "Windows.UI.D")
    addLayoutTestEdge(graph, "Windows.UI.D", "Windows.UI.C")

    let layout = computePackageLayoutFromGraph(namespaces, graph)
    let firstPackage = layout.packageNamespaceForNamespace("Windows.UI.A")
    let secondPackage = layout.packageNamespaceForNamespace("Windows.UI.C")

    @Expect(firstPackage.startsWith("Windows.UI.impl.s_"), true)
    @Expect(secondPackage.startsWith("Windows.UI.impl.s_"), true)
    @Expect(firstPackage != secondPackage, true)
    @Expect(layout.packageNamespaceForNamespace("Windows.UI.B"), firstPackage)
    @Expect(layout.packageNamespaceForNamespace("Windows.UI.D"), secondPackage)
}

@Test
func testPackageLayoutResidualPackageCycleMergesToFixedPoint() {
    let namespaces = layoutTestNamespaces(["Windows.A", "Windows.B"])
    let graph = layoutTestGraph(namespaces)
    addLayoutTestEdge(graph, "Windows.A", "Windows.B")
    addLayoutTestEdge(graph, "Windows.B", "Windows.A")

    let assignments = HashMap<String, String>()
    assignments["Windows.A"] = "Windows.A.impl.s_1"
    assignments["Windows.B"] = "Windows.B.impl.s_2"

    let layout = computePackageLayoutFromAssignmentsForTest(namespaces, graph, assignments)

    @Expect(layout.packageNamespaceForNamespace("Windows.A"), "Windows.impl")
    @Expect(layout.packageNamespaceForNamespace("Windows.B"), "Windows.impl")
    @Expect(layout.finalMultiNodeSccCount, 0)
}

@Test
func testValidatePackageGraphRejectsCycles() {
    let graph = HashMap<String, ArrayList<String>>()
    graph["a"] = ArrayList<String>()
    graph["a"].add("b")
    graph["b"] = ArrayList<String>()
    graph["b"].add("a")

    @ExpectThrows[Exception](validatePackageGraphIsDag(graph))
}
