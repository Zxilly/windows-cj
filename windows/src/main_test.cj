package windows

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

func cliTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

func cliTestContainsSymbol(symbols: ArrayList<SymbolRecord>, fullName: String): Bool {
    for (symbol in symbols) {
        if (symbol.fullName == fullName) {
            return true
        }
    }
    false
}

func cliTestContainsString(values: Array<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    false
}

func cliTestRecordsByName(records: ArrayList<SymbolRecord>): HashMap<String, SymbolRecord> {
    let map = HashMap<String, SymbolRecord>()
    for (record in records) {
        map.add(record.fullName, record)
    }
    return map
}

@Test
func testParseArgsDefaultsAndDeduplicatesFeatures() {
    let defaults = parseArgs(["--input-json", "metadata.json"])
    let repeated = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Windows.Foundation",
        "--feature", "Windows.Foundation"
    ])

    @Expect(defaults.features.size, 1)
    @Expect(defaults.features[0], "all")
    @Expect(defaults.packageName, "windows_gen")
    @Expect(defaults.inputJsonPaths[0], "metadata.json")
    @Expect(defaults.outputDir, ".generated/windows")
    @Expect(repeated.features.size, 1)
    @Expect(repeated.features[0], "Windows.Foundation")
}

@Test
func testParseArgsPrintLinkOptionsFlag() {
    let config = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Windows.Foundation",
        "--print-link-options"
    ])

    @Expect(config.printLinkOptions, true)
    @Expect(config.features.size, 1)
    @Expect(config.features[0], "Windows.Foundation")
}

@Test
func testParseArgsCommonModeDefaultsOutputAndFeatures() {
    let config = parseArgs(["--input-json", "metadata.json", "--common"])

    @Expect(config.common, true)
    @Expect(config.packageName, "windows_common")
    @Expect(config.outputDir, "windows-common")
    @Expect(config.features.isEmpty(), true)
    @Expect(config.supportPackageDirs.isEmpty(), false)
}

@Test
func testCommonModeScansNativeSupportPackages() {
    let config = parseArgs(["--input-json", "metadata.json", "--common"])

    @Expect(contains(config.supportPackageDirs, "windows-version"), true)
    @Expect(contains(config.supportPackageDirs, "windows-registry"), true)
    @Expect(contains(config.supportPackageDirs, "windows-threading"), true)
    @Expect(contains(config.supportPackageDirs, "windows-services"), true)
}

@Test
func testCommonFeatureNamesIncludeWinui3SupportNamespaces() {
    let dirs = ArrayList<String>()
    dirs.add("windows-winui3")
    let common = collectCommonFeatureNames(dirs)

    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml"), true)
    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml.Controls"), true)
    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml.Markup"), true)
}

@Test
func testParseArgsRejectsBadArguments() {
    @Expect(cliTestThrows({ => let _ = parseArgs(["--feature"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--input-json"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--unknown"]) }), true)
}

@Test
func testSelectSymbolsAddsDependenciesWithoutReverseEdges() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", ["Example.Shared.Size"]))
    records.add(SymbolRecord("Example.Shared.Size", "Example.Shared", "Size", "Example_Shared_Size", []))
    records.add(SymbolRecord("Example.Controls.Button", "Example.Controls", "Button", "Example_Controls_Button", ["Example.Foundation.Widget"]))
    let features = ArrayList<String>()
    features.add("Example.Foundation")
    let selected = selectSymbolsFromRecords(features, records)

    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Widget"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Shared.Size"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Controls.Button"), false)
}

@Test
func testSelectSymbolsKeepsNestedDependenciesFromRelativeTypeNames() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Root",
          "Name": "UsesParent",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "parent",
              "Signature": {"Kind": "Type", "Namespace": "Example.Other", "Name": "Parent"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "",
          "Name": "Nested",
          "BaseType": "System.ValueType",
          "IsNested": true,
          "Attributes": ["NestedPublic", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "value",
              "Signature": {"Kind": "Primitive", "Name": "UInt32"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Other",
          "Name": "Parent",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "nested",
              "Signature": {"Kind": "Type", "Namespace": "", "Name": "Nested"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [
            {
              "Namespace": "",
              "Name": "Nested",
              "BaseType": "System.ValueType",
              "IsNested": true,
              "Attributes": ["NestedPublic", "SequentialLayout", "Sealed"],
              "CustomAttributes": [],
              "Fields": [
                {
                  "Name": "value",
                  "Signature": {"Kind": "Primitive", "Name": "UInt32"},
                  "Attributes": ["Public"],
                  "CustomAttributes": [],
                  "DefaultValue": null
                }
              ],
              "InterfaceImplementations": [],
              "Methods": [],
              "NestedTypes": [],
              "GenericParameters": [],
              "Events": [],
              "Properties": []
            }
          ],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let features = ArrayList<String>()
    features.add("Example.Root")
    let selected = selectSymbolsFromRecords(features, records)

    @Expect(cliTestContainsSymbol(records, "Nested"), false)
    @Expect(cliTestContainsSymbol(selected, "Example.Other.Parent"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Other.Parent.Nested"), true)
}

@Test
func testFeatureNamesSkipEmptyNamespace() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", []))
    records.add(SymbolRecord("_TopLevel", "", "_TopLevel", "_TopLevel", []))
    let features = featureNamesFromRecords(records)

    @Expect(features.size, 1)
    @Expect(features[0], "Example.Foundation")
}

@Test
func testFacadeFilesImportOnlyReferencedImplSymbols() {
    let outDir = ".generated/facade-import-test"
    removeIfExists(outDir, recursive: true)
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", []))
    records.add(SymbolRecord("Example.Foundation.Gadget", "Example.Foundation", "Gadget", "Example_Foundation_Gadget", []))
    records.add(SymbolRecord("Example.Other.Hidden", "Example.Other", "Hidden", "Example_Other_Hidden", []))
    let writer = GeneratedPackageWriter(outDir, false)

    writeFacadeFiles(writer, "Example.Foundation", records, "windows")
    let content = String.fromUtf8(File.readFrom("${outDir}/src/Example/Foundation/facade_0.cj"))
    removeIfExists(outDir, recursive: true)

    @Expect(content.contains("import windows.impl.{Example_Foundation_Widget, Example_Foundation_Gadget}"), true)
    @Expect(content.contains("import windows.impl.*"), false)
    @Expect(content.contains("Example_Other_Hidden"), false)
}

@Test
func testRenderCjpmAndManifestArePackageAwareAndEscaped() {
    let symbols = ArrayList<SymbolRecord>()
    symbols.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", []))
    let files = ArrayList<String>()
    files.add("src/z.cj")
    files.add("src/a.cj")
    let features = ArrayList<String>()
    features.add("Example.Foundation")
    let manifest = renderManifest(features, symbols, files, "windows_common")

    @Expect(renderCjpmToml("windows_common").contains("name = \"windows_common\""), true)
    @Expect(renderCjpmToml("windows_common").contains("[dependencies]"), false)
    @Expect(manifest.contains("\"generated_by\": \"Generated by windows-gen. DO NOT EDIT.\""), true)
    @Expect(manifest.contains("\"package_name\": \"windows_common\""), true)
    @Expect(manifest.contains("\"files\": [\"src/a.cj\", \"src/z.cj\"]"), true)
    @Expect(jsonEscape("a\\b\"c\n"), "a\\\\b\\\"c\\n")
}

@Test
func testGeneratedPackageCjpmIncludesOnlyUsedSupportPackages() {
    let deps = ArrayList<String>()
    deps.add("windows_polyfill")
    let cjpm = renderCjpmToml("windows_gen", supportDeps: deps)
    let supportDeps = renderSupportDependencyImports("windows_gen", supportDeps: deps)

    @Expect(cjpm.contains("name = \"windows_gen\""), true)
    @Expect(cjpm.contains("link-option ="), false)
    @Expect(cjpm.contains("windows_polyfill = { path = \"../../windows-polyfill\" }"), true)
    @Expect(cjpm.contains("windows_common ="), false)
    @Expect(cjpm.contains("windows_core ="), false)
    @Expect(cjpm.contains("windows_interface ="), false)
    @Expect(cjpm.contains("windows_runtime"), false)
    @Expect(supportDeps.contains("import windows_polyfill as windows_polyfill"), true)
    @Expect(supportDeps.contains("import windows_common"), false)
}

@Test
func testGeneratedPackageCjpmIncludesSupportLinkOptions() {
    let deps = ArrayList<String>()
    deps.add("windows_numerics")
    let cjpm = renderCjpmToml("windows_gen", supportDeps: deps)

    @Expect(cjpm.contains("name = \"windows_gen\""), true)
    @Expect(cjpm.contains("link-option = \"-ld2d1 -lole32 -loleaut32 -lwindowsapp\""), true)
}

@Test
func testCoreAndResultSupportDepsDoNotEmitStaticLinkOptions() {
    let deps = ArrayList<String>()
    deps.add("windows_core")
    deps.add("windows_result")
    let cjpm = renderCjpmToml("windows_gen", supportDeps: deps)

    @Expect(cjpm.contains("windows_core = { path = \"../../windows-core\" }"), true)
    @Expect(cjpm.contains("windows_result = { path = \"../../windows-result\" }"), true)
    @Expect(cjpm.contains("link-option ="), false)
}

@Test
func testFeatureLinkOptionsUseSelectedFeatureDependencies() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord(
        "Example.Foundation.Widget",
        "Example.Foundation",
        "Widget",
        "Example_Foundation_Widget",
        [],
        implSource: "public func touchCore(): Unit { windows_core.IInspectable.runtimeName() }"
    ))
    records.add(SymbolRecord(
        "Example.Other.Vector",
        "Example.Other",
        "Vector",
        "Example_Other_Vector",
        [],
        implSource: "public func touchVector(): Unit { windows_numerics.Vector2() }"
    ))
    let config = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Example.Foundation",
        "--print-link-options"
    ])
    let options = featureLinkOptions(config, records)

    @Expect(cliTestContainsString(options.toArray(), "-lole32"), false)
    @Expect(cliTestContainsString(options.toArray(), "-loleaut32"), false)
    @Expect(cliTestContainsString(options.toArray(), "-lwindowsapp"), false)
    @Expect(cliTestContainsString(options.toArray(), "-ld2d1"), false)
}

@Test
func testPInvokeWrappersUseLibloadingDependencyWithoutForeignFunc() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Native",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetTickCount",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetTickCount",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "KERNEL32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "UInt32"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Other",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "MessageBeep",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "MessageBeep",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "user32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Bool"},
                "ParameterTypes": [{"Kind": "Primitive", "Name": "UInt32"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "uType", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let features = ArrayList<String>()
    features.add("Example.Native")
    let selected = selectSymbols(features, records)
    let selectedByName = recordsByFullName(selected)
    let deps = collectSupportDependencyNames("windows_gen", selected, selectedByName)
    let cjpm = renderCjpmToml("windows_gen", supportDeps: deps)
    var source = ""
    for (record in selected) {
        if (record.fullName == "Example.Native.Apis") {
            source = renderSymbolImpl(record, selectedByName)
        }
    }

    @Expect(source.contains("foreign func"), false)
    @Expect(source.contains("let proc = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetTickCount\"))"), true)
    @Expect(source.contains("return unsafe { proc() }"), true)
    @Expect(cliTestContainsString(deps.toArray(), "windows_libloading"), true)
    @Expect(cjpm.contains("windows_libloading = { path = \"../../windows-libloading\" }"), true)
    @Expect(cjpm.contains("-lkernel32"), false)
}

@Test
func testCommonSelectionOmitsPInvokeContainers() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Native",
          "Name": "POINT",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "x", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "y", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Native",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetPoint",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetPoint",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Void"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "POINT"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "point", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let features = ArrayList<String>()
    features.add("Example.Native")
    let selected = filterCommonSymbols(selectSymbols(features, records))
    let names = ArrayList<String>()
    for (record in selected) {
        names.add(record.fullName)
    }

    @Expect(cliTestContainsString(names.toArray(), "Example.Native.POINT"), true)
    @Expect(cliTestContainsString(names.toArray(), "Example.Native.Apis"), false)
}

@Test
func testCommonPackageCjpmOmitsUnusedSupportPackages() {
    let deps = ArrayList<String>()
    let cjpm = renderCjpmToml("windows_common", supportDeps: deps)
    let supportDeps = renderSupportDependencyImports("windows_common", supportDeps: deps)

    @Expect(cjpm.contains("windows_core ="), false)
    @Expect(cjpm.contains("windows_polyfill ="), false)
    @Expect(cjpm.contains("windows_common ="), false)
    @Expect(cjpm.contains("[dependencies]"), false)
    @Expect(cjpm.contains(".generated/windows-common"), false)
    @Expect(supportDeps.contains("import windows_common"), false)
    @Expect(supportDeps.contains("import windows_polyfill as windows_polyfill"), false)
}

@Test
func testRenderImplSourceUsesEmbeddedSourceBeforeFallback() {
    let embedded = SymbolRecord(
        "Example.Foundation.Widget",
        "Example.Foundation",
        "Widget",
        "Example_Foundation_Widget",
        [],
        implSource: "public struct Example_Foundation_Widget {\n    public var x: Int32 = 0\n}"
    )
    let fallback = SymbolRecord("Example.Foundation.Empty", "Example.Foundation", "Empty", "Example_Foundation_Empty", [])
    let map = HashMap<String, SymbolRecord>()
    map.add(embedded.fullName, embedded)
    map.add(fallback.fullName, fallback)

    @Expect(renderImplSource(embedded, map).contains("public var x: Int32 = 0"), true)
    @Expect(renderImplSource(fallback, map).contains("public init() {}"), true)
}

@Test
func testCommonPackageNamesAreFlatAndCfgFree() {
    let config = parseArgs(["--common", "--feature", "Microsoft.Web.WebView2.Core"])
    let cjpm = renderCjpmToml(config.packageName)

    @Expect(config.packageName, "windows_common")
    @Expect(config.outputDir, "windows-common")
    @Expect(namespaceToPackage("Windows.Foundation", config.packageName), "windows_common.Foundation")
    @Expect(namespaceToPackage("Microsoft.Web.WebView2.Core", config.packageName), "windows_common.Microsoft.Web.WebView2.Core")
    @Expect(namespaceToRelativePath("Windows.Foundation"), "src/Foundation/mod.cj")
    @Expect(cjpm.contains("@When"), false)
    @Expect(cjpm.contains("--cfg"), false)
}

@Test
func testDryRunWriterTracksFilesWithoutCreatingThem() {
    let writer = GeneratedPackageWriter("__windows_cj_missing_dir__", true)
    writer.writeFile("src/mod.cj", "package windows\n")

    @Expect(writer.files().size, 1)
    @Expect(writer.files()[0], "src/mod.cj")
}

@Test
func testGeneratedWriterAddsDoNotEditHeaders() {
    let outDir = ".generated/header-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writer.writeFile("src/mod.cj", "package windows_gen\n")
    writer.writeFile("cjpm.toml", "[package]\n")
    writer.writeFile("codegen-manifest.json", "{}\n")

    let cj = String.fromUtf8(File.readFrom("${outDir}/src/mod.cj"))
    let toml = String.fromUtf8(File.readFrom("${outDir}/cjpm.toml"))
    let json = String.fromUtf8(File.readFrom("${outDir}/codegen-manifest.json"))
    removeIfExists(outDir, recursive: true)

    @Expect(startsWithString(cj, "// Generated by windows-gen. DO NOT EDIT.\n\npackage windows_gen\n"), true)
    @Expect(startsWithString(toml, "# Generated by windows-gen. DO NOT EDIT.\n\n[package]\n"), true)
    @Expect(startsWithString(json, "{}\n"), true)
}

@Test
func testJsonInputBuildsSymbolsAndRendersValueStruct() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "POINT",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "x",
              "Signature": {"Kind": "Primitive", "Name": "Int32"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)

    @Expect(records.size, 1)
    @Expect(records[0].fullName, "Tiny.Foundation.POINT")
    @Expect(records[0].implName, "Tiny_Foundation_POINT")
    @Expect(featureNamesFromRecords(records)[0], "Tiny.Foundation")
    @Expect(renderSymbolImpl(records[0], symbolsByName).contains("@C\npublic struct Tiny_Foundation_POINT"), true)
    @Expect(renderSymbolImpl(records[0], symbolsByName).contains("public var x: Int32 = 0"), true)
}

@Test
func testFixedArrayFieldsRenderAsVArray() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "FixedText",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "chars",
              "Signature": {
                "Kind": "Array",
                "Type": {"Kind": "Primitive", "Name": "Char"},
                "LowerBounds": [0],
                "Rank": 1,
                "Sizes": [4]
              },
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(records[0], symbolsByName)

    @Expect(source.contains("public var chars: VArray<UInt16, $4> = VArray<UInt16, $4>(repeat: 0u16)"), true)
    @Expect(source.contains("public var chars: CPointer<Unit>"), false)
}

@Test
func testDelegateTypesRenderAsCFuncInAbiFields() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "Callback",
          "BaseType": "System.MulticastDelegate",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Invoke",
              "Attributes": ["Public", "Virtual"],
              "CustomAttributes": [],
              "ImplAttributes": [],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ReturnType": {"Kind": "Void"},
                "ParameterTypes": [{"Kind": "Primitive", "Name": "Int32"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "HasCallback",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "cb",
              "Signature": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "Callback"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)
    var delegateSource = ""
    var structSource = ""
    for (record in records) {
        if (record.fullName == "Tiny.Foundation.Callback") {
            delegateSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.HasCallback") {
            structSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(delegateSource.contains("public type Tiny_Foundation_Callback = CFunc<(Int32) -> Unit>"), true)
    @Expect(structSource.contains("public var cb: CFunc<(Int32) -> Unit> = CFunc<(Int32) -> Unit>(CPointer<Unit>())"), true)
    @Expect(structSource.contains("public var cb: CPointer<Unit>"), false)
}

@Test
func testWinrtInterfaceRendersDescriptorVtblAndCoreDependency() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IWidget",
          "MetadataToken": "0x02000002",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 286331153},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 8738},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 13107},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 68},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Ping",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "GenericParameterCount": 0,
                "Header": {"Attributes": ["Instance"], "CallingConvention": "Default", "HasExplicitThis": false, "IsGeneric": false, "IsInstance": true, "Kind": "Method"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "CreateInstance",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract", "SpecialName"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "GenericParameterCount": 0,
                "Header": {"Attributes": ["Instance"], "CallingConvention": "Default", "HasExplicitThis": false, "IsGeneric": false, "IsInstance": true, "Kind": "Method"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "Object"},
                  {"Kind": "Primitive", "Name": "Object"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Object"}
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "baseInterface", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "innerInterface", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "get_External",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract", "SpecialName"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "GenericParameterCount": 0,
                "Header": {"Attributes": ["Instance"], "CallingConvention": "Default", "HasExplicitThis": false, "IsGeneric": false, "IsInstance": true, "Kind": "Method"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "Type", "Namespace": "External.WinRT", "Name": "IThing", "Comment": "TypeReference"}
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 0, "Attributes": ["None"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "put_External",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract", "SpecialName"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "GenericParameterCount": 0,
                "Header": {"Attributes": ["Instance"], "CallingConvention": "Default", "HasExplicitThis": false, "IsGeneric": false, "IsInstance": true, "Kind": "Method"},
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "External.WinRT", "Name": "IThing", "Comment": "TypeReference"}
                ],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(records[0], symbolsByName)
    let deps = collectSupportDependencyNames("windows_gen", records, symbolsByName)

    @Expect(source.contains("@C\npublic struct Example_Foundation_IWidgetVtbl"), true)
    @Expect(source.contains("public var base_: windows_core.IInspectableVtbl = windows_core.IInspectableVtbl()"), true)
    @Expect(source.contains("public var Ping: CFunc<(CPointer<Unit>) -> Int32>"), true)
    @Expect(source.contains("public var CreateInstance: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>, CPointer<CPointer<Unit>>) -> Int32>"), true)
    @Expect(source.contains("public var External: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>"), true)
    @Expect(source.contains("public var External_1: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32>"), true)
    @Expect(source.contains("public open class Example_Foundation_IWidget <: windows_core.InterfaceWrapperBase & windows_core.ComInterface & windows_core.RuntimeName"), true)
    @Expect(source.contains("public static func descriptor(): windows_core.InterfaceDescriptor<Example_Foundation_IWidget>"), true)
    @Expect(source.contains("return windows_core.GUID.from_values(286331153u32, 8738u16, 13107u16, 68u8, 85u8, 102u8, 119u8, 136u8, 153u8, 170u8, 187u8)"), true)
    @Expect(source.contains("windows_core.InterfaceDescriptor<Example_Foundation_IWidget>(\"Example.Foundation.IWidget\""), true)
    @Expect(source.contains("extend Example_Foundation_IWidget <: windows_core.Interface<Example_Foundation_IWidget> {}"), true)
    @Expect(cliTestContainsString(deps.toArray(), "windows_core"), true)
    @Expect(renderCjpmToml("windows_gen", supportDeps: deps).contains("windows_core = { path = \"../../windows-core\" }"), true)
}

@Test
func testInterfaceVtblFallbackCountsNestedCFuncParameters() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "EventRegistrationToken",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "value",
              "Signature": {"Kind": "Primitive", "Name": "Int64"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "TypedEventHandler",
          "BaseType": "System.MulticastDelegate",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Invoke",
              "Attributes": ["Public", "Virtual"],
              "CustomAttributes": [],
              "ImplAttributes": [],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ReturnType": {"Kind": "Void"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "Object"},
                  {"Kind": "Primitive", "Name": "Object"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "ICommitBatch",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 286331153},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 8738},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 13107},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 68},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "add_Completed",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "TypedEventHandler"}
                ],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "EventRegistrationToken"}
              },
              "Parameters": [
                {"Name": "handler", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)
    var source = ""
    for (record in records) {
        if (record.fullName == "Tiny.Foundation.ICommitBatch") {
            source = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(source.contains("public var add_Completed: CFunc<(CPointer<Unit>, CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>, CPointer<Tiny_Foundation_EventRegistrationToken>) -> Int32> = { _, _, _ => -2147467263i32 }"), true)
    @Expect(source.contains("{ _, _, _, _ => -2147467263i32 }"), false)
}

@Test
func testFacadeExportsInterfaceVtblAlias() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "IWidget",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 286331153},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 8738},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 13107},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 68},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let outDir = ".generated/facade-interface-vtbl-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)

    writeFacadeFiles(writer, "Tiny.Foundation", records, "windows")
    let content = String.fromUtf8(File.readFrom("${outDir}/src/Tiny/Foundation/facade_0.cj"))
    removeIfExists(outDir, recursive: true)

    @Expect(content.contains("import windows.impl.{Tiny_Foundation_IWidget, Tiny_Foundation_IWidgetVtbl}"), true)
    @Expect(content.contains("public type IWidget = Tiny_Foundation_IWidget"), true)
    @Expect(content.contains("public type IWidgetVtbl = Tiny_Foundation_IWidgetVtbl"), true)
}

@Test
func testNativeBitfieldAttributesRenderPropertiesUsingPolyfill() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "FLAGS",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "_bitfield",
              "Signature": {"Kind": "Primitive", "Name": "UInt32"},
              "Attributes": ["Public"],
              "CustomAttributes": [
                {
                  "Type": "Windows.Win32.Foundation.Metadata.NativeBitfieldAttribute",
                  "FixedArguments": [
                    {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "Mode"},
                    {"Type": {"Kind": "Primitive", "Name": "Int64"}, "Value": 4},
                    {"Type": {"Kind": "Primitive", "Name": "Int64"}, "Value": 3}
                  ],
                  "NamedArguments": []
                }
              ],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(records[0], symbolsByName)

    @Expect(source.contains("public var _bitfield: UInt32 = 0"), true)
    @Expect(source.contains("public mut prop Mode: UInt32"), true)
    @Expect(source.contains("windows_polyfill.bitfieldReadUInt32(_bitfield, 4, 3)"), true)
    @Expect(source.contains("_bitfield = windows_polyfill.bitfieldWriteUInt32(_bitfield, 4, 3, val)"), true)
}

@Test
func testExplicitLayoutUnionRendersRawStorageAndProperties() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "",
          "Name": "<Module>",
          "BaseType": null,
          "IsNested": false,
          "Attributes": [],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "DECIMAL",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Anonymous2",
              "Signature": {"Kind": "Type", "Namespace": "", "Name": "_Anonymous2_e__Union"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            }
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [
            {
              "Namespace": "Tiny.Foundation",
              "Name": "_Anonymous2_e__Union",
              "MetadataToken": "0x02000003",
              "BaseType": "System.ValueType",
              "IsNested": true,
              "Attributes": ["NestedPublic", "ExplicitLayout", "Sealed"],
              "CustomAttributes": [],
              "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 0},
              "Fields": [
                {
                  "Name": "Anonymous",
                  "Signature": {"Kind": "Type", "Namespace": "", "Name": "_Anonymous_e__Struct"},
                  "Attributes": ["Public"],
                  "CustomAttributes": [],
                  "DefaultValue": null,
                  "Offset": 0
                },
                {
                  "Name": "Lo64",
                  "Signature": {"Kind": "Primitive", "Name": "UInt64"},
                  "Attributes": ["Public"],
                  "CustomAttributes": [],
                  "DefaultValue": null,
                  "Offset": 0
                }
              ],
              "InterfaceImplementations": [],
              "Methods": [],
              "NestedTypes": [
                {
                  "Namespace": "Tiny.Foundation",
                  "Name": "_Anonymous_e__Struct",
                  "MetadataToken": "0x02000004",
                  "BaseType": "System.ValueType",
                  "IsNested": true,
                  "Attributes": ["NestedPublic", "SequentialLayout", "Sealed"],
                  "CustomAttributes": [],
                  "Fields": [
                    {
                      "Name": "Lo32",
                      "Signature": {"Kind": "Primitive", "Name": "UInt32"},
                      "Attributes": ["Public"],
                      "CustomAttributes": [],
                      "DefaultValue": null
                    },
                    {
                      "Name": "Mid32",
                      "Signature": {"Kind": "Primitive", "Name": "UInt32"},
                      "Attributes": ["Public"],
                      "CustomAttributes": [],
                      "DefaultValue": null
                    }
                  ],
                  "InterfaceImplementations": [],
                  "Methods": [],
                  "NestedTypes": [],
                  "GenericParameters": [],
                  "Events": [],
                  "Properties": []
                }
              ],
              "GenericParameters": [],
              "Events": [],
              "Properties": []
            }
          ],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)
    var unionSource = ""
    for (record in records) {
        if (record.fullName == "Tiny.Foundation.DECIMAL._Anonymous2_e__Union") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(unionSource.contains("public var _raw: VArray<UInt64, $1> = VArray<UInt64, $1>(repeat: 0u64)"), true)
    @Expect(unionSource.contains("public mut prop Anonymous: Tiny_Foundation_DECIMAL__Anonymous2_e__Union__Anonymous_e__Struct"), true)
    @Expect(unionSource.contains("public mut prop Lo64: UInt64"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt64(base, 0)"), true)
    @Expect(unionSource.contains("public var _raw: VArray<UInt8, $1>"), false)
    @Expect(unionSource.contains("public var Anonymous: _Anonymous_e__Struct"), false)
    @Expect(unionSource.contains("public var Lo64: UInt64 = 0"), false)
}

@Test
func testImplFilesImportPolyfillWhenRenderedSourceUsesLayoutHelper() {
    let outDir = ".generated/impl-polyfill-import-test"
    removeIfExists(outDir, recursive: true)
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord(
        "Example.Foundation.Union",
        "Example.Foundation",
        "Union",
        "Example_Foundation_Union",
        [],
        implSource: "public struct Example_Foundation_Union {\n    public func read(base: CPointer<UInt8>): UInt64 {\n        return unsafe { windows_polyfill.unionReadUInt64(base, 0) }\n    }\n}"
    ))
    let writer = GeneratedPackageWriter(outDir, false)
    let symbolsByName = cliTestRecordsByName(records)

    writeImplFiles(writer, records, "windows", symbolsByName)
    let content = String.fromUtf8(File.readFrom("${outDir}/src/impl/symbols_0.cj"))
    removeIfExists(outDir, recursive: true)

    @Expect(content.contains("import windows_polyfill as windows_polyfill"), true)
}
