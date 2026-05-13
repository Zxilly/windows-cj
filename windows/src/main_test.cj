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

func cliTestHelperFile(files: ArrayList<GeneratedNativeHelperFile>, path: String): String {
    for (file in files) {
        if (file.relativePath == path) {
            return file.content
        }
    }
    return ""
}

func cliTestCountOccurrences(text: String, needle: String): Int64 {
    if (needle.isEmpty()) {
        return 0
    }
    let bytes = text.toArray()
    let needleBytes = needle.toArray()
    var count: Int64 = 0
    var index: Int64 = 0
    while (index + Int64(needleBytes.size) <= Int64(bytes.size)) {
        var matched = true
        var needleIndex: Int64 = 0
        while (needleIndex < Int64(needleBytes.size)) {
            if (bytes[index + needleIndex] != needleBytes[needleIndex]) {
                matched = false
                break
            }
            needleIndex += 1
        }
        if (matched) {
            count += 1
            index += Int64(needleBytes.size)
        } else {
            index += 1
        }
    }
    return count
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
    @Expect(contains(config.supportPackageDirs, "windows-runtime"), true)
    @Expect(contains(config.supportPackageDirs, "windows-winui3"), true)
    @Expect(contains(config.supportPackageDirs, "windows-webview2"), false)
}

@Test
func testCommonFeatureNamesIncludeWinui3SupportNamespaces() {
    let dirs = ArrayList<String>()
    dirs.add("windows-winui3")
    let common = collectCommonFeatureNames(dirs)

    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml"), false)
    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml.Application"), true)
    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml.Controls.ContentControl"), true)
    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml.Markup.IXamlReaderStatics"), true)
    @Expect(cliTestContainsString(common, "Microsoft.UI.Xaml.Markup.IXamlReaderStaticsVtbl"), false)
    @Expect(cliTestContainsString(common, "Windows.Native"), false)
    @Expect(cliTestContainsString(common, "Windows.Native.AppRuntime"), false)
}

@Test
func testCommonFeatureScanRejectsMissingSupportPackage() {
    let dirs = ArrayList<String>()
    dirs.add("__missing_support_package__")

    @Expect(cliTestThrows({ => let _ = collectCommonFeatureNames(dirs) }), true)
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
func testSelectSymbolsAcceptsExactSymbolFeature() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.Gadget", "Example.Foundation", "Gadget", "Example_Foundation_Gadget", []))
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", ["Example.Shared.Size"]))
    records.add(SymbolRecord("Example.Shared.Size", "Example.Shared", "Size", "Example_Shared_Size", []))
    let features = ArrayList<String>()
    features.add("Example.Foundation.Widget")

    let selected = selectSymbolsFromRecords(features, records)

    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Gadget"), false)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Widget"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Shared.Size"), true)
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
    let fileHashes = HashMap<String, String>()
    fileHashes.add("src/a.cj", "a-hash")
    fileHashes.add("src/z.cj", "z-hash")
    let manifest = renderManifest(features, symbols, files, fileHashes, "windows_common")

    @Expect(renderCjpmToml("windows_common").contains("name = \"windows_common\""), true)
    @Expect(renderCjpmToml("windows_common").contains("[dependencies]"), true)
    @Expect(manifest.contains("\"generated_by\": \"Generated by windows-gen. DO NOT EDIT.\""), true)
    @Expect(manifest.contains("\"package_name\": \"windows_common\""), true)
    @Expect(manifest.contains("\"files\": [\"src/a.cj\", \"src/z.cj\"]"), true)
    @Expect(manifest.contains("\"file_hashes\": {"), true)
    @Expect(manifest.contains("\"src/a.cj\": \"a-hash\""), true)
    @Expect(manifest.contains("\"src/z.cj\": \"z-hash\""), true)
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
func testRuntimeSupportDependencyReplacesSplitProjectionPackages() {
    let names = stableSupportDependencyNames()
    let deps = ArrayList<String>()
    deps.add("windows_runtime")
    let cjpm = renderCjpmToml("windows_gen", supportDeps: deps)
    let supportDeps = renderSupportDependencyImports("windows_gen", supportDeps: deps)

    @Expect(cliTestContainsString(names, "windows_runtime"), true)
    @Expect(cliTestContainsString(names, "windows_collections"), false)
    @Expect(cliTestContainsString(names, "windows_future"), false)
    @Expect(cliTestContainsString(names, "windows_numerics"), false)
    @Expect(stableSupportDependencyPath("windows_runtime"), "windows-runtime")
    @Expect(cjpm.contains("windows_runtime = { path = \"../../windows-runtime\" }"), true)
    @Expect(cjpm.contains("link-option ="), false)
    @Expect(supportDeps.contains("import windows_runtime as windows_runtime"), true)
}

@Test
func testGeneratedPackageCjpmOmitsSupportLinkOptionsForDynamicNativeDeps() {
    let deps = ArrayList<String>()
    deps.add("windows_interface")
    deps.add("windows_implement")
    let cjpm = renderCjpmToml("windows_gen", supportDeps: deps)

    @Expect(cjpm.contains("name = \"windows_gen\""), true)
    @Expect(cjpm.contains("windows_interface = { path = \"../../windows-interface\" }"), true)
    @Expect(cjpm.contains("windows_implement = { path = \"../../windows-implement\" }"), true)
    @Expect(cjpm.contains("link-option ="), false)
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
        implSource: "public func touchRuntime(): Unit { windows_runtime.DateTime() }"
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
func testCommonNativeHelperFilesRenderSelectedPInvokeMethods() {
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
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let features = ArrayList<String>()
    features.add("Example.Native")
    let selected = selectSymbols(features, records)
    let helpers = commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected))
    let native = cliTestHelperFile(helpers, "src/Native/native_helpers.cj")
    let example = cliTestHelperFile(helpers, "src/Example/Native/native_helpers.cj")

    @Expect(native.isEmpty(), true)
    @Expect(example.contains("package windows_common.Example.Native"), true)
    @Expect(example.contains("import windows_libloading as windows_libloading"), true)
    @Expect(example.contains("import windows_common.Native as Native"), false)
    @Expect(example.contains("public func GetTickCount(): UInt32"), true)
    @Expect(example.contains("windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetTickCount\")"), true)
    @Expect(example.contains("Native.resolveProc"), false)
    @Expect(example.contains("public struct Apis"), false)
}

@Test
func testCommonNativeHelperFilesAdaptTransparentAbiWrappers() {
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
          "Name": "HTHING",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "PWSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
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
              "Name": "CreateThing",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CreateThing",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "HTHING"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PWSTR"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "name", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "CloseThing",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CloseThing",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "HTHING"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "thing", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "DuplicateThing",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "DuplicateThing",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL"},
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Example.Native", "Name": "HTHING"},
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Example.Native", "Name": "HTHING"}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "source", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "target", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("import windows_strings as windows_strings"), true)
    @Expect(helper.contains("public func CreateThing(name: windows_strings.PWSTR): HTHING"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<UInt16>) -> CPointer<Unit>>"), true)
    @Expect(helper.contains("var result = HTHING()"), true)
    @Expect(helper.contains("result.Value = unsafe { proc(name.asPtr()) }"), true)
    @Expect(helper.contains("public func CloseThing(thing: HTHING): Int32"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>) -> Int32>"), true)
    @Expect(helper.contains("unsafe { proc(thing.Value) }"), true)
    @Expect(helper.contains("public func DuplicateThing(source: HTHING, target: CPointer<HTHING>): Bool"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(source.Value, CPointer<CPointer<Unit>>(target)) } != 0"), true)
    @Expect(helper.contains("target.Value"), false)
}

@Test
func testCommonNativeHelpersUseTextPointerRemapsWithoutTypeDefinitions() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "PathFindFileNameW",
            "PathFindFileNameW",
            "SHLWAPI.dll",
            typeSignature("Windows.Win32.Foundation", "PWSTR"),
            [NativeParameterSeed("path", typeSignature("Windows.Win32.Foundation", "PWSTR"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "PathFindFileNameA",
            "PathFindFileNameA",
            "SHLWAPI.dll",
            typeSignature("Windows.Win32.Foundation", "PSTR"),
            [NativeParameterSeed("path", typeSignature("Windows.Win32.Foundation", "PSTR"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "CompareStringOrdinal",
            "CompareStringOrdinal",
            "KERNEL32.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("left", typeSignature("Windows.Win32.Foundation", "PCWSTR")),
                NativeParameterSeed("right", typeSignature("Windows.Win32.Foundation", "PCWSTR"))
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "CompareStringA",
            "CompareStringA",
            "KERNEL32.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("left", typeSignature("Windows.Win32.Foundation", "PCSTR")),
                NativeParameterSeed("right", typeSignature("Windows.Win32.Foundation", "PCSTR"))
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UpdateWidePointer",
            "UpdateWidePointer",
            "example.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("value", pointerSignature(typeSignature("Windows.Win32.Foundation", "PWSTR")))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UpdateAnsiPointer",
            "UpdateAnsiPointer",
            "example.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("value", pointerSignature(typeSignature("Windows.Win32.Foundation", "PSTR")))]
        )
    ))
    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Win32/Foundation/native_helpers.cj", content))
    let deps = ArrayList<String>()
    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(content.contains("import windows_strings as windows_strings"), true)
    @Expect(content.contains("public func PathFindFileNameW(path: windows_strings.PWSTR): windows_strings.PWSTR"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<UInt16>) -> CPointer<UInt16>>"), true)
    @Expect(content.contains("return windows_strings.PWSTR.fromRaw(unsafe { proc(path.asPtr()) })"), true)
    @Expect(content.contains("public func PathFindFileNameA(path: windows_strings.PSTR): windows_strings.PSTR"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<UInt8>) -> CPointer<UInt8>>"), true)
    @Expect(content.contains("return windows_strings.PSTR.fromRaw(unsafe { proc(path.asPtr()) })"), true)
    @Expect(content.contains("public func CompareStringOrdinal(left: windows_strings.PCWSTR, right: windows_strings.PCWSTR): Int32"), true)
    @Expect(content.contains("return unsafe { proc(left.asPtr(), right.asPtr()) }"), true)
    @Expect(content.contains("public func CompareStringA(left: windows_strings.PCSTR, right: windows_strings.PCSTR): Int32"), true)
    @Expect(content.contains("return unsafe { proc(left.asPtr(), right.asPtr()) }"), true)
    @Expect(content.contains("public func UpdateWidePointer(value: CPointer<CPointer<UInt16>>): Int32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<CPointer<UInt16>>) -> Int32>"), true)
    @Expect(content.contains("public func UpdateAnsiPointer(value: CPointer<CPointer<UInt8>>): Int32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<CPointer<UInt8>>) -> Int32>"), true)
    @Expect(content.contains("CPointer<windows_strings.PWSTR>"), false)
    @Expect(content.contains("CPointer<windows_strings.PSTR>"), false)
    @Expect(content.contains("var result = windows_strings.PWSTR()"), false)
    @Expect(content.contains("var result = windows_strings.PSTR()"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_strings"), true)
}

@Test
func testCommonNativeHelpersDoNotImportTextPointerWrappersForPointerOnlySlots() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UpdateWidePointer",
            "UpdateWidePointer",
            "example.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("value", pointerSignature(typeSignature("Windows.Win32.Foundation", "PWSTR")))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UpdateAnsiPointer",
            "UpdateAnsiPointer",
            "example.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("value", pointerSignature(typeSignature("Windows.Win32.Foundation", "PSTR")))]
        )
    ))
    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Win32/Foundation/native_helpers.cj", content))
    let deps = ArrayList<String>()
    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(content.contains("public func UpdateWidePointer(value: CPointer<CPointer<UInt16>>): Int32"), true)
    @Expect(content.contains("public func UpdateAnsiPointer(value: CPointer<CPointer<UInt8>>): Int32"), true)
    @Expect(content.contains("import windows_strings as windows_strings"), false)
    @Expect(content.contains("windows_strings.PWSTR"), false)
    @Expect(content.contains("windows_strings.PSTR"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_strings"), false)
}

@Test
func testCommonNativeHelperFilesDoNotProjectNonWin32TextPointersByShortName() {
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
          "Name": "PWSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
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
              "Name": "UseCustomText",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomText",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "PWSTR"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "text", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomText(text: PWSTR): Int32"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(text.Value) }"), true)
    @Expect(helper.contains("text: CPointer<UInt16>"), false)
}

@Test
func testCommonNativeHelperFilesUseAssociatedEnumParameterProjection() {
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
          "Namespace": "Example.Enums",
          "Name": "FILE_ACTION",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Open", "Signature": {"Kind": "Type", "Namespace": "Example.Enums", "Name": "FILE_ACTION"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
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
              "Name": "SetAction",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "SetAction",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Primitive", "Name": "UInt32"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {
                  "Name": "action",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.AssociatedEnumAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Type", "Namespace": "System", "Name": "Type"}, "Value": {"Namespace": "Example.Enums", "Name": "FILE_ACTION"}}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("import windows_common.Example.Enums.FILE_ACTION"), true)
    @Expect(helper.contains("public func SetAction(action: FILE_ACTION): Int32"), true)
    @Expect(helper.contains("public func SetAction(action: UInt32): Int32"), false)
    @Expect(helper.contains("let proc = CFunc<(UInt32) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(UInt32(action.value)) }"), true)
}

@Test
func testCommonNativeHelperFilesUseStringAssociatedEnumParameterDependency() {
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
          "Namespace": "Example.Enums",
          "Name": "FILE_MODE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Read", "Signature": {"Kind": "Type", "Namespace": "Example.Enums", "Name": "FILE_MODE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
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
              "Name": "SetMode",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "SetMode",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Primitive", "Name": "UInt32"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {
                  "Name": "mode",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.AssociatedEnumAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "Example.Enums.FILE_MODE"}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("import windows_common.Example.Enums.FILE_MODE"), true)
    @Expect(helper.contains("public func SetMode(mode: FILE_MODE): Int32"), true)
    @Expect(helper.contains("public func SetMode(mode: UInt32): Int32"), false)
    @Expect(helper.contains("return unsafe { proc(UInt32(mode.value)) }"), true)
}

@Test
func testCommonNativeHelperFilesUseRawAliasAssociatedEnumParameterWithoutWrapperValue() {
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
          "Namespace": "Windows.Win32.System.Com",
          "Name": "COINIT",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [{"Type": "System.FlagsAttribute", "FixedArguments": [], "NamedArguments": []}],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "COINIT_MULTITHREADED", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "COINIT"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 0}},
            {"Name": "COINIT_APARTMENTTHREADED", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "COINIT"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 2}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CoInitializeEx",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CoInitializeEx",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "OLE32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {
                  "Name": "pvReserved",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.ReservedAttribute",
                      "FixedArguments": [],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                },
                {
                  "Name": "dwCoInit",
                  "SequenceNumber": 2,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.AssociatedEnumAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "COINIT"}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    features.add("Windows.Win32.System.Com")
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Win32/System/Com/native_helpers.cj"
    )

    @Expect(helper.contains("public func CoInitializeEx(dwCoInit: COINIT): Int32"), true)
    @Expect(helper.contains("pvReserved:"), false)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>, UInt32) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(CPointer<Unit>(), UInt32(dwCoInit)) }"), true)
    @Expect(helper.contains("dwCoInit.value"), false)
}

@Test
func testCommonNativeHelperFilesDefaultReservedParameters() {
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
              "Name": "Configure",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "Configure",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {
                  "Name": "reserved",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.ReservedAttribute",
                      "FixedArguments": [],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                },
                {"Name": "value", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func Configure(value: UInt32): Int32"), true)
    @Expect(helper.contains("reserved: UInt32"), false)
    @Expect(helper.contains("let proc = CFunc<(UInt32, UInt32) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(0, value) }"), true)
}

@Test
func testCommonNativeHelperFilesDoNotInferReservedArrayLengthParameters() {
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
              "Name": "UseReservedLength",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseReservedLength",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {
                  "Name": "count",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.ReservedAttribute",
                      "FixedArguments": [],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                },
                {
                  "Name": "values",
                  "SequenceNumber": 2,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 0}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseReservedLength(values: CPointer<UInt16>): Int32"), true)
    @Expect(helper.contains("count: UInt32"), false)
    @Expect(helper.contains("values: Array<UInt16>"), false)
    @Expect(helper.contains("acquireArrayRawData(values)"), false)
    @Expect(helper.contains("return unsafe { proc(0, values) }"), true)
}

@Test
func testCommonNativeHelperFilesProjectBoolParametersAndReturns() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
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
              "Name": "SetEnabled",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "SetEnabled",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "enabled", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func SetEnabled(enabled: Bool): Bool"), true)
    @Expect(helper.contains("enabled: Int32"), false)
    @Expect(helper.contains("let proc = CFunc<(Int32) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(if (enabled) { 1 } else { 0 }) } != 0"), true)
}

@Test
func testCommonNativeHelperFilesDoNotProjectNonWin32BoolByShortName() {
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
          "Name": "BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
              "Name": "UseCustomBool",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomBool",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "BOOL"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "flag", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomBool(flag: UInt32): Int32"), true)
    @Expect(helper.contains("flag: Bool"), false)
    @Expect(helper.contains("return unsafe { proc(flag) }"), true)
}

@Test
func testCommonNativeHelperFilesKeepWin32BoolPointersRaw() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
              "Name": "ReadFlag",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "ReadFlag",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL"}}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "flag", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func ReadFlag(flag: CPointer<Int32>): Int32"), true)
    @Expect(helper.contains("CPointer<Bool>"), false)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Int32>) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(flag) }"), true)
}

@Test
func testCommonNativeHelperFilesRenderDynamicAppRuntimeSpecs() {
    let helpers = commonNativeHelperFiles(
        ArrayList<SymbolRecord>(),
        "windows_common",
        HashMap<String, SymbolRecord>()
    )
    let appRuntime = cliTestHelperFile(helpers, "src/Native/AppRuntime/native_helpers.cj")

    @Expect(appRuntime.contains("package windows_common.Native.AppRuntime"), true)
    @Expect(appRuntime.contains("import windows_libloading as windows_libloading"), true)
    @Expect(appRuntime.contains("public func MddBootstrapInitialize2("), true)
    @Expect(appRuntime.contains("bootstrapDllPath: String"), true)
    @Expect(appRuntime.contains("windows_libloading.resolveProcFromSearchPath(bootstrapDllPath, \"MddBootstrapInitialize2\")"), true)
    @Expect(appRuntime.contains("Native.resolveProc"), false)
    @Expect(appRuntime.contains("public func MddBootstrapShutdown(bootstrapDllPath: String): Unit"), true)
}

@Test
func testCommonNativeHelperFilesRenderSyntheticSupportApis() {
    let helpers = commonNativeHelperFiles(
        ArrayList<SymbolRecord>(),
        "windows_common",
        HashMap<String, SymbolRecord>()
    )
    let systemInformation = cliTestHelperFile(helpers, "src/Win32/System/SystemInformation/native_helpers.cj")
    let kernel = cliTestHelperFile(helpers, "src/Win32/System/Kernel/native_helpers.cj")

    @Expect(systemInformation.contains("public func RtlGetVersion("), true)
    @Expect(systemInformation.contains("windows_libloading.resolveProc(\"ntdll.dll\", \"RtlGetVersion\")"), true)
    @Expect(kernel.contains("public func CreateTransaction("), true)
    @Expect(kernel.contains("windows_libloading.resolveProc(\"ktmw32.dll\", \"CreateTransaction\")"), true)
    @Expect(kernel.contains("public func CommitTransaction("), true)
    @Expect(kernel.contains("windows_libloading.resolveProc(\"ktmw32.dll\", \"CommitTransaction\")"), true)
}

@Test
func testCommonNativeHelperFilesUseRawPointersForProjectedClassPointers() {
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
          "Namespace": "Example.Com",
          "Name": "IThing",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
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
          "Namespace": "Example.Com",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CreateThing",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CreateThing",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Example.Com", "Name": "IThing"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "ppThing", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "UseThing",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseThing",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Example.Com", "Name": "IThing"}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "thing", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    features.add("Example.Com")
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Com/native_helpers.cj"
    )

    @Expect(helper.contains("public func CreateThing(ppThing: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<CPointer<Unit>>) -> Int32>"), true)
    @Expect(helper.contains("public func UseThing(thing: CPointer<Unit>): Int32"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>) -> Int32>"), true)
    @Expect(helper.contains("CPointer<IThing>"), false)
}

@Test
func testCommonNativeHelperFilesUseNativeArrayInfoForLengthParameters() {
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
              "Name": "SumValues",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "SumValues",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "count", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {
                  "Name": "values",
                  "SequenceNumber": 2,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 0}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func SumValues(values: Array<UInt16>): Int32"), true)
    @Expect(helper.contains("count: UInt32"), false)
    @Expect(helper.contains("let proc = CFunc<(UInt32, CPointer<UInt16>) -> Int32>"), true)
    @Expect(helper.contains("let __valuesArrayHandle = unsafe { acquireArrayRawData(values) }"), true)
    @Expect(helper.contains("return unsafe { proc(UInt32(values.size), __valuesArrayHandle.pointer) }"), true)
    @Expect(helper.contains("unsafe { releaseArrayRawData(__valuesArrayHandle) }"), true)
}

@Test
func testCommonNativeHelperFilesUseFixedNativeArrayInfoParameters() {
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
              "Name": "UseFourValues",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseFourValues",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {
                  "Name": "values",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 4}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseFourValues(values: Array<UInt16>): Int32"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<UInt16>) -> Int32>"), true)
    @Expect(helper.contains("if (values.size != 4)"), true)
    @Expect(helper.contains("throw IllegalArgumentException(\"values must contain 4 elements\")"), true)
    @Expect(helper.contains("let __valuesArrayHandle = unsafe { acquireArrayRawData(values) }"), true)
    @Expect(helper.contains("return unsafe { proc(__valuesArrayHandle.pointer) }"), true)
    @Expect(helper.contains("unsafe { releaseArrayRawData(__valuesArrayHandle) }"), true)
}

@Test
func testCommonNativeHelperFilesKeepSharedNativeArrayLengthExplicit() {
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
              "Name": "BlendValues",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "BlendValues",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}}
                ],
                "RequiredParameterCount": 3
              },
              "Parameters": [
                {"Name": "count", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {
                  "Name": "left",
                  "SequenceNumber": 2,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 0}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                },
                {
                  "Name": "right",
                  "SequenceNumber": 3,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 0}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func BlendValues(count: UInt32, left: CPointer<UInt16>, right: CPointer<UInt16>): Int32"), true)
    @Expect(helper.contains("left: Array<UInt16>"), false)
    @Expect(helper.contains("right: Array<UInt16>"), false)
    @Expect(helper.contains("acquireArrayRawData"), false)
    @Expect(helper.contains("return unsafe { proc(count, left, right) }"), true)
}

@Test
func testCommonNativeHelperFilesKeepOutNativeArrayLengthExplicit() {
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
              "Name": "ReadValues",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "ReadValues",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "UInt32"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "count", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null},
                {
                  "Name": "values",
                  "SequenceNumber": 2,
                  "Attributes": ["Out"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 0}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func ReadValues(count: CPointer<UInt32>, values: CPointer<UInt16>): Int32"), true)
    @Expect(helper.contains("values: Array<UInt16>"), false)
    @Expect(helper.contains("CPointer<UInt32>(values.size)"), false)
    @Expect(helper.contains("return unsafe { proc(count, values) }"), true)
}

@Test
func testCommonNativeHelperFilesKeepMixedSharedNativeArrayLengthExplicit() {
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
              "Name": "MixedValues",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "MixedValues",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}},
                  {"Kind": "Primitive", "Name": "UInt16"}
                ],
                "RequiredParameterCount": 3
              },
              "Parameters": [
                {"Name": "count", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {
                  "Name": "values",
                  "SequenceNumber": 2,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 0}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                },
                {
                  "Name": "sentinel",
                  "SequenceNumber": 3,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.NativeArrayInfoAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 0}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                }
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func MixedValues(count: UInt32, values: CPointer<UInt16>, sentinel: UInt16): Int32"), true)
    @Expect(helper.contains("values: Array<UInt16>"), false)
    @Expect(helper.contains("acquireArrayRawData"), false)
    @Expect(helper.contains("return unsafe { proc(count, values, sentinel) }"), true)
}

@Test
func testCommonNativeHelperFilesUseMemorySizeAttributeForByteArrays() {
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
              "Name": "WriteBytes",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "WriteBytes",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt8"}},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {
                  "Name": "buffer",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.MemorySizeAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 1}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                },
                {"Name": "byteCount", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func WriteBytes(buffer: Array<UInt8>): Int32"), true)
    @Expect(helper.contains("byteCount: UInt32"), false)
    @Expect(helper.contains("let proc = CFunc<(CPointer<UInt8>, UInt32) -> Int32>"), true)
    @Expect(helper.contains("let __bufferArrayHandle = unsafe { acquireArrayRawData(buffer) }"), true)
    @Expect(helper.contains("return unsafe { proc(__bufferArrayHandle.pointer, UInt32(buffer.size)) }"), true)
    @Expect(helper.contains("unsafe { releaseArrayRawData(__bufferArrayHandle) }"), true)
}

@Test
func testCommonNativeHelperFilesKeepMemorySizeAttributeExplicitForNonByteArrays() {
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
              "Name": "WriteWideBytes",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "WriteWideBytes",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "UInt16"}},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {
                  "Name": "buffer",
                  "SequenceNumber": 1,
                  "Attributes": ["In"],
                  "CustomAttributes": [
                    {
                      "Type": "Windows.Win32.Foundation.Metadata.MemorySizeAttribute",
                      "FixedArguments": [
                        {"Type": {"Kind": "Primitive", "Name": "Int16"}, "Value": 1}
                      ],
                      "NamedArguments": []
                    }
                  ],
                  "DefaultValue": null
                },
                {"Name": "byteCount", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func WriteWideBytes(buffer: CPointer<UInt16>, byteCount: UInt32): Int32"), true)
    @Expect(helper.contains("buffer: Array<UInt16>"), false)
    @Expect(helper.contains("acquireArrayRawData"), false)
    @Expect(helper.contains("return unsafe { proc(buffer, byteCount) }"), true)
}

@Test
func testCommonNativeHelperFilesSkipForceInlinePseudoImports() {
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
              "Name": "InlineOnly",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "InlineOnly",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "FORCEINLINE", "CustomAttributes": []}
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
        }
      ]
    }"##
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(json, "tiny"))
    let records = buildSymbolRecords(files)
    let features = ArrayList<String>()
    features.add("Example.Native")
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("InlineOnly"), false)
    @Expect(helper.contains("FORCEINLINE"), false)
}

@Test
func testCommonNativeHelperFilesRenderDelegateParametersWithNativeAbiTypes() {
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
          "Name": "BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "PTP_WORK",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "BOOL"},
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Example.Native", "Name": "BOOL"},
                  {"Kind": "Type", "Namespace": "Example.Native", "Name": "PTP_WORK"}
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
              "Name": "Register",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "Register",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "Callback"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "callback", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("callback: CFunc<(Int32, CPointer<Unit>) -> Int32>"), true)
    @Expect(helper.contains("let proc = CFunc<(CFunc<(Int32, CPointer<Unit>) -> Int32>) -> Int32>"), true)
    @Expect(helper.contains("Example_Native_BOOL"), false)
    @Expect(helper.contains("Example_Native_PTP_WORK"), false)
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
    @Expect(cjpm.contains("windows_libloading = { path = \"../windows-libloading\" }"), true)
    @Expect(cjpm.contains("[dependencies]"), true)
    @Expect(cjpm.contains(".generated/windows-common"), false)
    @Expect(supportDeps.contains("import windows_common"), false)
    @Expect(supportDeps.contains("import windows_polyfill as windows_polyfill"), false)
}

@Test
func testCommonPackageCjpmUsesLocalPathDependencies() {
    let deps = ArrayList<String>()
    deps.add("windows_core")
    deps.add("windows_polyfill")
    let cjpm = renderCjpmToml("windows_common", supportDeps: deps)

    @Expect(cjpm.contains("windows_core = { path = \"../windows-core\" }"), true)
    @Expect(cjpm.contains("windows_polyfill = { path = \"../windows-polyfill\" }"), true)
    @Expect(cjpm.contains("windows_libloading = { path = \"../windows-libloading\" }"), true)
    @Expect(cjpm.contains("version = \"0.1.0\" }"), false)
}

@Test
func testCommonNativeHelpersImportLibloadingDirectly() {
    let helpers = commonNativeHelperFiles(
        ArrayList<SymbolRecord>(),
        "windows_common",
        HashMap<String, SymbolRecord>()
    )
    let native = cliTestHelperFile(helpers, "src/Native/native_helpers.cj")
    let nativeMod = cliTestHelperFile(helpers, "src/Native/mod.cj")
    let appRuntime = cliTestHelperFile(helpers, "src/Native/AppRuntime/native_helpers.cj")

    @Expect(native.isEmpty(), true)
    @Expect(nativeMod.contains("package windows_common.Native"), true)
    @Expect(nativeMod.contains("resolveProc"), false)
    @Expect(nativeMod.contains("windows_libloading"), false)
    @Expect(appRuntime.contains("package windows_common.Native.AppRuntime"), true)
    @Expect(appRuntime.contains("import windows_libloading as windows_libloading"), true)
    @Expect(appRuntime.contains("windows_libloading.resolveProc"), true)
    @Expect(appRuntime.contains("import windows_common.Native as Native"), false)
    @Expect(appRuntime.contains("Native.resolveProc"), false)
}

@Test
func testCommonNativeHelpersRenderSystemGuidPointersAsGuidPointers() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "CLSIDFromString",
            "CLSIDFromString",
            "OLE32.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("lpsz", pointerSignature(primitiveSignature("UInt16"))),
                NativeParameterSeed("pclsid", pointerSignature(typeSignature("System", "Guid")))
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "StringFromGUID2",
            "StringFromGUID2",
            "OLE32.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("rguid", pointerSignature(typeSignature("System", "Guid"))),
                NativeParameterSeed("lpsz", pointerSignature(primitiveSignature("UInt16"))),
                NativeParameterSeed("cchMax", primitiveSignature("Int32"))
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "CoCreateGuid",
            "CoCreateGuid",
            "OLE32.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("pguid", pointerSignature(typeSignature("System", "Guid")))]
        )
    ))

    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Com",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(content.contains("import windows_interface.GUID"), true)
    @Expect(content.contains("public func CLSIDFromString(lpsz: CPointer<UInt16>, pclsid: CPointer<GUID>): Int32"), true)
    @Expect(content.contains("public func StringFromGUID2(rguid: CPointer<GUID>, lpsz: CPointer<UInt16>, cchMax: Int32): Int32"), true)
    @Expect(content.contains("public func CoCreateGuid(pguid: CPointer<GUID>): Int32"), true)
    @Expect(content.contains("CPointer<CPointer<Unit>>"), false)
}

@Test
func testCommonNativeHelpersPreserveNestedVoidPointerDepth() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "CoCreateInstance",
            "CoCreateInstance",
            "OLE32.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("rclsid", pointerSignature(typeSignature("System", "Guid"))),
                NativeParameterSeed("pUnkOuter", pointerSignature(voidSignature())),
                NativeParameterSeed("dwClsContext", primitiveSignature("UInt32")),
                NativeParameterSeed("riid", pointerSignature(typeSignature("System", "Guid"))),
                NativeParameterSeed("ppv", pointerSignature(pointerSignature(voidSignature())))
            ]
        )
    ))

    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Com",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(content.contains("ppv: CPointer<CPointer<Unit>>"), true)
    @Expect(content.contains("CFunc<(CPointer<GUID>, CPointer<Unit>, UInt32, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32>"), true)
}

@Test
func testCommonNativeHelpersUseNativeIntegerForSizeT() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "CoTaskMemAlloc",
            "CoTaskMemAlloc",
            "OLE32.dll",
            pointerSignature(voidSignature()),
            [NativeParameterSeed("cb", typeSignature("Windows.Win32.Foundation", "SIZE_T"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "CoTaskMemRealloc",
            "CoTaskMemRealloc",
            "OLE32.dll",
            pointerSignature(voidSignature()),
            [
                NativeParameterSeed("pv", pointerSignature(voidSignature())),
                NativeParameterSeed("cb", typeSignature("System", "UIntPtr"))
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "PrimitiveUIntPtrAlloc",
            "PrimitiveUIntPtrAlloc",
            "OLE32.dll",
            pointerSignature(voidSignature()),
            [NativeParameterSeed("cb", primitiveSignature("UIntPtr"))]
        )
    ))

    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Com",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(content.contains("public func CoTaskMemAlloc(cb: UIntNative): CPointer<Unit>"), true)
    @Expect(content.contains("let proc = CFunc<(UIntNative) -> CPointer<Unit>>"), true)
    @Expect(content.contains("public func CoTaskMemRealloc(pv: CPointer<Unit>, cb: UIntNative): CPointer<Unit>"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<Unit>, UIntNative) -> CPointer<Unit>>"), true)
    @Expect(content.contains("public func PrimitiveUIntPtrAlloc(cb: UIntNative): CPointer<Unit>"), true)
    @Expect(content.contains("cb: CPointer<Unit>"), false)
}

@Test
func testCommonNativeHelpersDoNotProjectNonWin32PointerSizedIntegersByShortName() {
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
          "Name": "SIZE_T",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
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
              "Name": "UseCustomSize",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomSize",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Int32"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "SIZE_T"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "size", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomSize(size: UInt32): Int32"), true)
    @Expect(helper.contains("let proc = CFunc<(UInt32) -> Int32>"), true)
    @Expect(helper.contains("return unsafe { proc(size) }"), true)
    @Expect(helper.contains("size: UIntNative"), false)
}

@Test
func testCommonNativeHelpersUseFoundationCharAndBooleanRemapsWithoutTypeDefinitions() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UseChar",
            "UseChar",
            "example.dll",
            typeSignature("Windows.Win32.Foundation", "CHAR"),
            [NativeParameterSeed("ch", typeSignature("Windows.Win32.Foundation", "CHAR"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UseBoolean",
            "UseBoolean",
            "example.dll",
            typeSignature("Windows.Win32.Foundation", "BOOLEAN"),
            [NativeParameterSeed("flag", typeSignature("Windows.Win32.Foundation", "BOOLEAN"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UseBooleanPointer",
            "UseBooleanPointer",
            "example.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("flag", pointerSignature(typeSignature("Windows.Win32.Foundation", "BOOLEAN")))]
        )
    ))

    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(content.contains("public func UseChar(ch: Int8): Int8"), true)
    @Expect(content.contains("let proc = CFunc<(Int8) -> Int8>"), true)
    @Expect(content.contains("return unsafe { proc(ch) }"), true)
    @Expect(content.contains("public func UseBoolean(flag: Bool): Bool"), true)
    @Expect(content.contains("let proc = CFunc<(UInt8) -> UInt8>"), true)
    @Expect(content.contains("return unsafe { proc(if (flag) { 1u8 } else { 0u8 }) } != 0u8"), true)
    @Expect(content.contains("public func UseBooleanPointer(flag: CPointer<UInt8>): Int32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<UInt8>) -> Int32>"), true)
    @Expect(content.contains("CPointer<Bool>"), false)
    @Expect(content.contains("flag: CPointer<Unit>"), false)
    @Expect(content.contains("ch: CPointer<Unit>"), false)
}

@Test
func testCommonNativeHelpersDoNotProjectNonWin32CharAndBooleanByShortName() {
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
          "Name": "BOOLEAN",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Primitive", "Name": "UInt8"},
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
          "Namespace": "Example.Native",
          "Name": "CHAR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Primitive", "Name": "UInt16"},
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
              "Name": "UseCustomNativeTypes",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomNativeTypes",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "BOOLEAN"},
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Example.Native", "Name": "BOOLEAN"},
                  {"Kind": "Type", "Namespace": "Example.Native", "Name": "CHAR"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "flag", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "ch", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomNativeTypes(flag: UInt8, ch: UInt16): UInt8"), true)
    @Expect(helper.contains("let proc = CFunc<(UInt8, UInt16) -> UInt8>"), true)
    @Expect(helper.contains("return unsafe { proc(flag, ch) }"), true)
    @Expect(helper.contains("flag: Bool"), false)
    @Expect(helper.contains("ch: Int8"), false)
}

@Test
func testCommonNativeHelpersUseEventRegistrationTokenRemapsWithoutTypeDefinitions() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "UseWinRtToken",
            "UseWinRtToken",
            "example.dll",
            typeSignature("Windows.Win32.System.WinRT", "EventRegistrationToken"),
            [NativeParameterSeed("token", typeSignature("Windows.Win32.System.WinRT", "EventRegistrationToken"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Foundation",
        "Windows.Foundation.Apis",
        nativeMethod(
            "UseFoundationToken",
            "UseFoundationToken",
            "example.dll",
            typeSignature("Windows.Foundation", "EventRegistrationToken"),
            [NativeParameterSeed("token", typeSignature("Windows.Foundation", "EventRegistrationToken"))]
        )
    ))

    let winrtContent = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.WinRT",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let foundationContent = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(winrtContent.contains("public func UseWinRtToken(token: Int64): Int64"), true)
    @Expect(winrtContent.contains("let proc = CFunc<(Int64) -> Int64>"), true)
    @Expect(winrtContent.contains("return unsafe { proc(token) }"), true)
    @Expect(foundationContent.contains("public func UseFoundationToken(token: Int64): Int64"), true)
    @Expect(foundationContent.contains("let proc = CFunc<(Int64) -> Int64>"), true)
    @Expect(foundationContent.contains("return unsafe { proc(token) }"), true)
    @Expect(winrtContent.contains("CPointer<Unit>"), false)
    @Expect(foundationContent.contains("CPointer<Unit>"), false)
}

@Test
func testCommonNativeHelpersDoNotProjectNonWin32EventRegistrationTokenByShortName() {
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
          "Name": "EventRegistrationToken",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
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
              "Name": "UseCustomToken",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomToken",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "EventRegistrationToken"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "EventRegistrationToken"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "token", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomToken(token: UInt32): UInt32"), true)
    @Expect(helper.contains("let proc = CFunc<(UInt32) -> UInt32>"), true)
    @Expect(helper.contains("return unsafe { proc(token) }"), true)
    @Expect(helper.contains("token: Int64"), false)
}

@Test
func testCommonNativeHelpersUseHResultRemapsWithoutTypeDefinitions() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "UseWin32HResult",
            "UseWin32HResult",
            "example.dll",
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            [NativeParameterSeed("hr", typeSignature("Windows.Win32.Foundation", "HRESULT"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Foundation",
        "Windows.Foundation.Apis",
        nativeMethod(
            "UseFoundationHResult",
            "UseFoundationHResult",
            "example.dll",
            typeSignature("Windows.Foundation", "HResult"),
            [NativeParameterSeed("hr", typeSignature("Windows.Foundation", "HResult"))]
        )
    ))

    let win32Content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let foundationContent = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(win32Content.contains("public func UseWin32HResult(hr: Int32): Int32"), true)
    @Expect(win32Content.contains("let proc = CFunc<(Int32) -> Int32>"), true)
    @Expect(win32Content.contains("return unsafe { proc(hr) }"), true)
    @Expect(foundationContent.contains("public func UseFoundationHResult(hr: Int32): Int32"), true)
    @Expect(foundationContent.contains("let proc = CFunc<(Int32) -> Int32>"), true)
    @Expect(foundationContent.contains("return unsafe { proc(hr) }"), true)
    @Expect(win32Content.contains("Result<"), false)
    @Expect(foundationContent.contains("Result<"), false)
    @Expect(win32Content.contains("CPointer<Unit>"), false)
    @Expect(foundationContent.contains("CPointer<Unit>"), false)
}

@Test
func testCommonNativeHelpersDoNotProjectNonWin32HResultByShortName() {
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
          "Name": "HRESULT",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
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
              "Name": "UseCustomHResult",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomHResult",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "HRESULT"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "HRESULT"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "hr", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomHResult(hr: UInt32): UInt32"), true)
    @Expect(helper.contains("let proc = CFunc<(UInt32) -> UInt32>"), true)
    @Expect(helper.contains("return unsafe { proc(hr) }"), true)
    @Expect(helper.contains("hr: Int32"), false)
}

@Test
func testCommonNativeHelpersUseBStrRemapsWithoutTypeDefinitions() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "SysAllocString",
            "SysAllocString",
            "OLEAUT32.dll",
            typeSignature("Windows.Win32.Foundation", "BSTR"),
            [NativeParameterSeed("psz", pointerSignature(primitiveSignature("UInt16")))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "SysStringLen",
            "SysStringLen",
            "OLEAUT32.dll",
            primitiveSignature("UInt32"),
            [NativeParameterSeed("pbstr", typeSignature("Windows.Win32.Foundation", "BSTR"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "SysFreeString",
            "SysFreeString",
            "OLEAUT32.dll",
            voidSignature(),
            [NativeParameterSeed("bstrString", typeSignature("Windows.Win32.Foundation", "BSTR"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "FreeBstrAlias",
            "SysFreeString",
            "OLEAUT32.dll",
            voidSignature(),
            [NativeParameterSeed("owned", typeSignature("Windows.Win32.Foundation", "BSTR"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "ReleaseBstrAlias",
            "SysReleaseString",
            "OLEAUT32.dll",
            voidSignature(),
            [NativeParameterSeed("released", typeSignature("Windows.Win32.Foundation", "BSTR"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "SysReAllocString",
            "SysReAllocString",
            "OLEAUT32.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("pbstr", pointerSignature(typeSignature("Windows.Win32.Foundation", "BSTR"))),
                NativeParameterSeed("psz", pointerSignature(primitiveSignature("UInt16")))
            ]
        )
    ))
    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Win32/Foundation/native_helpers.cj", content))
    let deps = ArrayList<String>()
    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(content.contains("import windows_strings as windows_strings"), true)
    @Expect(content.contains("public func SysAllocString(psz: CPointer<UInt16>): windows_strings.BSTR"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<UInt16>) -> CPointer<Unit>>"), true)
    @Expect(content.contains("return windows_strings.BSTR.fromRawTake(CPointer<UInt16>(unsafe { proc(psz) }))"), true)
    @Expect(content.contains("public func SysStringLen(pbstr: windows_strings.BSTR): UInt32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<Unit>) -> UInt32>"), true)
    @Expect(content.contains("return unsafe { proc(CPointer<Unit>(pbstr.asPtr())) }"), true)
    @Expect(content.contains("public func SysFreeString(bstrString: windows_strings.BSTR): Unit"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<Unit>) -> Unit>"), true)
    @Expect(content.contains("unsafe { proc(CPointer<Unit>(bstrString.intoRaw())) }"), true)
    @Expect(content.contains("unsafe { proc(CPointer<Unit>(bstrString.asPtr())) }"), false)
    @Expect(content.contains("public func FreeBstrAlias(owned: windows_strings.BSTR): Unit"), true)
    @Expect(content.contains("unsafe { proc(CPointer<Unit>(owned.intoRaw())) }"), true)
    @Expect(content.contains("unsafe { proc(CPointer<Unit>(owned.asPtr())) }"), false)
    @Expect(content.contains("public func ReleaseBstrAlias(released: windows_strings.BSTR): Unit"), true)
    @Expect(content.contains("unsafe { proc(CPointer<Unit>(released.intoRaw())) }"), true)
    @Expect(content.contains("unsafe { proc(CPointer<Unit>(released.asPtr())) }"), false)
    @Expect(content.contains("public func SysReAllocString(pbstr: CPointer<CPointer<Unit>>, psz: CPointer<UInt16>): Int32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<CPointer<Unit>>, CPointer<UInt16>) -> Int32>"), true)
    @Expect(content.contains("var result = windows_strings.BSTR()"), false)
    @Expect(content.contains("result.Value = unsafe { proc"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_strings"), true)
}

@Test
func testCommonNativeHelpersDoNotImportBStrResourceForPointerOnlySlots() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Foundation",
        "Windows.Win32.Foundation.Apis",
        nativeMethod(
            "SysReAllocString",
            "SysReAllocString",
            "OLEAUT32.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("pbstr", pointerSignature(typeSignature("Windows.Win32.Foundation", "BSTR"))),
                NativeParameterSeed("psz", pointerSignature(primitiveSignature("UInt16")))
            ]
        )
    ))
    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Win32/Foundation/native_helpers.cj", content))
    let deps = ArrayList<String>()
    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(content.contains("public func SysReAllocString(pbstr: CPointer<CPointer<Unit>>, psz: CPointer<UInt16>): Int32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<CPointer<Unit>>, CPointer<UInt16>) -> Int32>"), true)
    @Expect(content.contains("import windows_strings as windows_strings"), false)
    @Expect(content.contains("windows_strings.BSTR"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_strings"), false)
}

@Test
func testCommonNativeHelpersDoNotProjectNonWin32BStrByShortName() {
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
          "Name": "BSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
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
              "Name": "UseCustomBStr",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomBStr",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "BSTR"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "BSTR"}],
                "RequiredParameterCount": 1
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
    let features = ArrayList<String>()
    features.add("Example.Native")
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomBStr(value: BSTR): BSTR"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>) -> CPointer<Unit>>"), true)
    @Expect(helper.contains("var result = BSTR()"), true)
    @Expect(helper.contains("result.Value = unsafe { proc(value.Value) }"), true)
    @Expect(helper.contains("windows_strings.BSTR"), false)
}

@Test
func testCommonNativeHelpersUseHStringRemapsWithoutTypeDefinitions() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "WindowsGetStringLen",
            "WindowsGetStringLen",
            "api-ms-win-core-winrt-string-l1-1-0.dll",
            primitiveSignature("UInt32"),
            [NativeParameterSeed("string", typeSignature("Windows.Win32.System.WinRT", "HSTRING"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "WindowsDuplicateString",
            "WindowsDuplicateString",
            "api-ms-win-core-winrt-string-l1-1-0.dll",
            typeSignature("Windows.Win32.System.WinRT", "HSTRING"),
            [NativeParameterSeed("string", typeSignature("Windows.Win32.System.WinRT", "HSTRING"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "WindowsDeleteString",
            "WindowsDeleteString",
            "api-ms-win-core-winrt-string-l1-1-0.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("string", typeSignature("Windows.Win32.System.WinRT", "HSTRING"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "DeleteStringAlias",
            "WindowsDeleteString",
            "api-ms-win-core-winrt-string-l1-1-0.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("string", typeSignature("Windows.Win32.System.WinRT", "HSTRING"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "CompareTwoStrings",
            "WindowsCompareStringOrdinal",
            "api-ms-win-core-winrt-string-l1-1-0.dll",
            primitiveSignature("Int32"),
            [
                NativeParameterSeed("left", typeSignature("Windows.Win32.System.WinRT", "HSTRING")),
                NativeParameterSeed("right", typeSignature("Windows.Win32.System.WinRT", "HSTRING"))
            ]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "HSTRING_UserUnmarshal",
            "HSTRING_UserUnmarshal",
            "api-ms-win-core-winrt-string-l1-1-0.dll",
            pointerSignature(primitiveSignature("UInt8")),
            [
                NativeParameterSeed("flags", pointerSignature(primitiveSignature("UInt32"))),
                NativeParameterSeed("buffer", pointerSignature(primitiveSignature("UInt8"))),
                NativeParameterSeed("string", pointerSignature(typeSignature("Windows.Win32.System.WinRT", "HSTRING")))
            ]
        )
    ))
    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.WinRT",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Win32/System/WinRT/native_helpers.cj", content))
    let deps = ArrayList<String>()
    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(content.contains("import windows_core as windows_core"), true)
    @Expect(content.contains("public func WindowsGetStringLen(string: windows_core.HString): UInt32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<Unit>) -> UInt32>"), true)
    @Expect(content.contains("var __stringHStringHandle = CPointer<Unit>()"), true)
    @Expect(content.contains("__stringHStringHandle = string.toSystemHandleCopy()"), true)
    @Expect(content.contains("return unsafe { proc(__stringHStringHandle) }"), true)
    @Expect(content.contains("windows_core.releaseSystemHStringHandle(__stringHStringHandle)"), true)
    @Expect(content.contains("public func WindowsDuplicateString(string: windows_core.HString): windows_core.HString"), true)
    @Expect(content.contains("return windows_core.HString.fromSystemHandleTake(unsafe { proc(__stringHStringHandle) })"), true)
    @Expect(content.contains("public func WindowsDeleteString(string: windows_core.HString): Int32"), true)
    @Expect(content.contains("public func DeleteStringAlias(string: windows_core.HString): Int32"), true)
    @Expect(content.contains("windows_libloading.resolveProc(\"api-ms-win-core-winrt-string-l1-1-0.dll\", \"WindowsDeleteString\")"), true)
    @Expect(cliTestCountOccurrences(content, "windows_core.releaseSystemHStringHandle(__stringHStringHandle)"), 2)
    @Expect(content.contains("public func CompareTwoStrings(left: windows_core.HString, right: windows_core.HString): Int32"), true)
    @Expect(content.contains("var __leftHStringHandle = CPointer<Unit>()"), true)
    @Expect(content.contains("var __rightHStringHandle = CPointer<Unit>()"), true)
    @Expect(content.contains("__leftHStringHandle = left.toSystemHandleCopy()"), true)
    @Expect(content.contains("__rightHStringHandle = right.toSystemHandleCopy()"), true)
    @Expect(content.contains("return unsafe { proc(__leftHStringHandle, __rightHStringHandle) }"), true)
    @Expect(content.contains("windows_core.releaseSystemHStringHandle(__leftHStringHandle)"), true)
    @Expect(content.contains("windows_core.releaseSystemHStringHandle(__rightHStringHandle)"), true)
    @Expect(content.contains("public func HSTRING_UserUnmarshal(flags: CPointer<UInt32>, buffer: CPointer<UInt8>, string: CPointer<CPointer<Unit>>): CPointer<UInt8>"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<UInt32>, CPointer<UInt8>, CPointer<CPointer<Unit>>) -> CPointer<UInt8>>"), true)
    @Expect(content.contains("CPointer<windows_core.HString>"), false)
    @Expect(content.contains("var result = windows_core.HString()"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_core"), true)
}

@Test
func testCommonNativeHelpersDoNotImportHStringResourceForPointerOnlySlots() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.WinRT",
        "Windows.Win32.System.WinRT.Apis",
        nativeMethod(
            "HSTRING_UserFree",
            "HSTRING_UserFree",
            "api-ms-win-core-winrt-string-l1-1-0.dll",
            voidSignature(),
            [
                NativeParameterSeed("flags", pointerSignature(primitiveSignature("UInt32"))),
                NativeParameterSeed("string", pointerSignature(typeSignature("Windows.Win32.System.WinRT", "HSTRING")))
            ]
        )
    ))
    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.WinRT",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Win32/System/WinRT/native_helpers.cj", content))
    let deps = ArrayList<String>()
    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(content.contains("public func HSTRING_UserFree(flags: CPointer<UInt32>, string: CPointer<CPointer<Unit>>): Unit"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<UInt32>, CPointer<CPointer<Unit>>) -> Unit>"), true)
    @Expect(content.contains("import windows_core as windows_core"), false)
    @Expect(content.contains("windows_core.HString"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_core"), false)
}

@Test
func testCommonNativeHelpersDoNotProjectNonWinRtHStringByShortName() {
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
          "Name": "HSTRING",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
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
              "Name": "UseCustomHString",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomHString",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "HSTRING"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "HSTRING"}],
                "RequiredParameterCount": 1
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
    let features = ArrayList<String>()
    features.add("Example.Native")
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomHString(value: HSTRING): HSTRING"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>) -> CPointer<Unit>>"), true)
    @Expect(helper.contains("var result = HSTRING()"), true)
    @Expect(helper.contains("result.Value = unsafe { proc(value.Value) }"), true)
    @Expect(helper.contains("windows_core.HString"), false)
}

@Test
func testCommonNativeHelpersUseComInterfaceRemapsWithoutTypeDefinitions() {
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "Inspect",
            "Inspect",
            "example.dll",
            typeSignature("Windows.Win32.System.Com", "IUnknown"),
            [NativeParameterSeed("input", typeSignature("Windows.Win32.System.WinRT", "IInspectable"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "UseUnknown",
            "UseUnknown",
            "example.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("value", typeSignature("Windows.Win32.System.Com", "IUnknown"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.System.Com",
        "Windows.Win32.System.Com.Apis",
        nativeMethod(
            "GetUnknownOut",
            "GetUnknownOut",
            "example.dll",
            primitiveSignature("Int32"),
            [NativeParameterSeed("result", pointerSignature(typeSignature("Windows.Win32.System.Com", "IUnknown")))]
        )
    ))
    let content = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Com",
        specs,
        HashMap<String, SymbolRecord>()
    )
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile("src/Win32/System/Com/native_helpers.cj", content))
    let deps = ArrayList<String>()
    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(content.contains("import windows_interface as windows_interface"), true)
    @Expect(content.contains("public func Inspect(input: windows_interface.IInspectable): windows_interface.IUnknown"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<Unit>) -> CPointer<Unit>>"), true)
    @Expect(content.contains("return windows_interface.IUnknown.fromAbiTake(unsafe { proc(input.asRaw()) })"), true)
    @Expect(content.contains("public func UseUnknown(value: windows_interface.IUnknown): Int32"), true)
    @Expect(content.contains("return unsafe { proc(value.asRaw()) }"), true)
    @Expect(content.contains("public func GetUnknownOut(result: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(content.contains("let proc = CFunc<(CPointer<CPointer<Unit>>) -> Int32>"), true)
    @Expect(content.contains("CPointer<windows_interface.IUnknown>"), false)
    @Expect(content.contains("var result = windows_interface.IUnknown()"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_interface"), true)
}

@Test
func testCommonNativeHelpersDoNotProjectNonWin32ComInterfacesByShortName() {
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
          "Name": "IUnknown",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
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
              "Name": "UseCustomUnknown",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomUnknown",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "IUnknown"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "IUnknown"}],
                "RequiredParameterCount": 1
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
    let features = ArrayList<String>()
    features.add("Example.Native")
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomUnknown(value: IUnknown): IUnknown"), true)
    @Expect(helper.contains("let proc = CFunc<(CPointer<Unit>) -> CPointer<Unit>>"), true)
    @Expect(helper.contains("var result = IUnknown()"), true)
    @Expect(helper.contains("result.Value = unsafe { proc(value.Value) }"), true)
    @Expect(helper.contains("windows_interface.IUnknown"), false)
}

@Test
func testCommonNativeHelpersRemapDirect2DAndDirect3DNumericsTypes() {
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
          "Namespace": "Windows.Foundation.Numerics",
          "Name": "Vector2",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "X", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Y", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Foundation.Numerics",
          "Name": "Matrix3x2",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "M11", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "M12", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Foundation.Numerics",
          "Name": "Matrix4x4",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "M11", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "M12", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Foundation.Numerics",
          "Name": "Vector4",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "X", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Y", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Z", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "W", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Graphics.Direct2D.Common",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "UsePoint",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UsePoint",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct2D.Common", "Name": "D2D_POINT_2F"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct2D.Common", "Name": "D2D_VECTOR_2F"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "point", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "UseVector4",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseVector4",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct2D.Common", "Name": "D2D_VECTOR_4F"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct2D.Common", "Name": "D2D_MATRIX_3X2_F"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "matrix", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "UseMatrix4",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseMatrix4",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct2D.Common", "Name": "D2D_MATRIX_4X4_F"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct2D.Common", "Name": "D2D_MATRIX_4X4_F"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "matrix", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Graphics.Direct3D",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "UseMatrix",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseMatrix",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct3D", "Name": "D3DMATRIX"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Graphics.Direct2D.Common", "Name": "D2D_MATRIX_4X4_F"}],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "matrix", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Graphics.Direct2D.Common",
        "Windows.Win32.Graphics.Direct2D.Common.Apis",
        nativeMethod(
            "UsePoint",
            "UsePoint",
            "example.dll",
            typeSignature("Windows.Win32.Graphics.Direct2D.Common", "D2D_POINT_2F"),
            [NativeParameterSeed("point", typeSignature("Windows.Win32.Graphics.Direct2D.Common", "D2D_VECTOR_2F"))]
        )
    ))
    specs.add(NativeFunctionSpec(
        "Windows.Win32.Graphics.Direct3D",
        "Windows.Win32.Graphics.Direct3D.Apis",
        nativeMethod(
            "UseMatrix",
            "UseMatrix",
            "example.dll",
            typeSignature("Windows.Win32.Graphics.Direct3D", "D3DMATRIX"),
            [NativeParameterSeed("matrix", typeSignature("Windows.Win32.Graphics.Direct2D.Common", "D2D_MATRIX_4X4_F"))]
        )
    ))
    let symbolsByName = recordsByFullName(records)

    let direct2d = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Graphics.Direct2D.Common",
        specs,
        symbolsByName
    )
    let direct3d = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Graphics.Direct3D",
        specs,
        symbolsByName
    )

    @Expect(direct2d.contains("import windows_common.Foundation.Numerics.Vector2"), true)
    @Expect(direct2d.contains("public func UsePoint(point: Vector2): Vector2"), true)
    @Expect(direct2d.contains("let proc = CFunc<(Vector2) -> Vector2>"), true)
    @Expect(direct2d.contains("return unsafe { proc(point) }"), true)
    @Expect(direct3d.contains("import windows_common.Foundation.Numerics.Matrix4x4"), true)
    @Expect(direct3d.contains("public func UseMatrix(matrix: Matrix4x4): Matrix4x4"), true)
    @Expect(direct3d.contains("let proc = CFunc<(Matrix4x4) -> Matrix4x4>"), true)
    @Expect(direct3d.contains("return unsafe { proc(matrix) }"), true)
    @Expect(direct2d.contains("CPointer<Unit>"), false)
    @Expect(direct3d.contains("CPointer<Unit>"), false)

    let features = ArrayList<String>()
    features.add("Windows.Win32.Graphics.Direct2D.Common")
    features.add("Windows.Win32.Graphics.Direct3D")
    let selected = selectSymbols(features, records)
    let selectedByName = recordsByFullName(selected)
    let helpers = commonNativeHelperFiles(selected, "windows_common", selectedByName)
    let productionDirect2d = cliTestHelperFile(helpers, "src/Win32/Graphics/Direct2D/Common/native_helpers.cj")
    let productionDirect3d = cliTestHelperFile(helpers, "src/Win32/Graphics/Direct3D/native_helpers.cj")

    @Expect(cliTestContainsSymbol(selected, "Windows.Foundation.Numerics.Vector2"), true)
    @Expect(cliTestContainsSymbol(selected, "Windows.Foundation.Numerics.Vector4"), true)
    @Expect(cliTestContainsSymbol(selected, "Windows.Foundation.Numerics.Matrix3x2"), true)
    @Expect(cliTestContainsSymbol(selected, "Windows.Foundation.Numerics.Matrix4x4"), true)
    @Expect(productionDirect2d.contains("import windows_common.Foundation.Numerics.Matrix3x2"), true)
    @Expect(productionDirect2d.contains("import windows_common.Foundation.Numerics.Matrix4x4"), true)
    @Expect(productionDirect2d.contains("import windows_common.Foundation.Numerics.Vector2"), true)
    @Expect(productionDirect2d.contains("import windows_common.Foundation.Numerics.Vector4"), true)
    @Expect(productionDirect2d.contains("public func UsePoint(point: Vector2): Vector2"), true)
    @Expect(productionDirect2d.contains("public func UseVector4(matrix: Matrix3x2): Vector4"), true)
    @Expect(productionDirect2d.contains("public func UseMatrix4(matrix: Matrix4x4): Matrix4x4"), true)
    @Expect(productionDirect3d.contains("import windows_common.Foundation.Numerics.Matrix4x4"), true)
    @Expect(productionDirect3d.contains("public func UseMatrix(matrix: Matrix4x4): Matrix4x4"), true)
    @Expect(productionDirect2d.contains("CPointer<Unit>"), false)
    @Expect(productionDirect3d.contains("CPointer<Unit>"), false)
}

@Test
func testCommonNativeHelpersDoNotRemapNonDirect2DNumericsShortNames() {
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
          "Name": "D2D_POINT_2F",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Value",
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
              "Name": "UseCustomPoint",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "UseCustomPoint",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Native", "Name": "D2D_POINT_2F"},
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Example.Native", "Name": "D2D_POINT_2F"}],
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
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Example/Native/native_helpers.cj"
    )

    @Expect(helper.contains("public func UseCustomPoint(point: UInt32): UInt32"), true)
    @Expect(helper.contains("let proc = CFunc<(UInt32) -> UInt32>"), true)
    @Expect(helper.contains("return unsafe { proc(point) }"), true)
    @Expect(helper.contains("point: Vector2"), false)
}

@Test
func testCommonNativeHelperImportsParticipateInSupportDependencies() {
    let files = ArrayList<GeneratedNativeHelperFile>()
    files.add(GeneratedNativeHelperFile(
        "src/Win32/System/Com/native_helpers.cj",
        "package windows_common.Win32.System.Com\n\nimport windows_libloading as windows_libloading\nimport windows_interface.GUID\n\nlet _ = windows_libloading.resolveProc\n"
    ))
    let deps = ArrayList<String>()

    collectSupportDependencyNamesFromGeneratedNativeHelpers("windows_common", deps, files)

    @Expect(cliTestContainsString(deps.toArray(), "windows_interface"), true)
    @Expect(cliTestContainsString(deps.toArray(), "windows_libloading"), true)
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
func testGeneratedWriterTracksEachFileOnce() {
    let writer = GeneratedPackageWriter("__windows_cj_missing_dir__", true)
    writer.writeFile("src/mod.cj", "package windows\n")
    writer.writeFile("src/mod.cj", "package windows\n")
    writer.writeFile("src/impl/mod.cj", "package windows.impl\n")

    @Expect(writer.files().size, 2)
    @Expect(writer.files()[0], "src/mod.cj")
    @Expect(writer.files()[1], "src/impl/mod.cj")
    @Expect(writer.fileHashes().contains("src/mod.cj"), true)
    @Expect(writer.fileHashes().contains("src/impl/mod.cj"), true)
}

@Test
func testGeneratedWriterRejectsConflictingDuplicateFile() {
    let writer = GeneratedPackageWriter("__windows_cj_missing_dir__", true)
    writer.writeFile("src/mod.cj", "package windows\n")

    @Expect(cliTestThrows({ => writer.writeFile("src/mod.cj", "package windows.impl\n") }), true)
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
func testValueStructLiteralFieldsRenderAsStaticConstants() {
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
              "Name": "value",
              "Signature": {"Kind": "Primitive", "Name": "Int32"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            },
            {
              "Name": "Enabled",
              "Signature": {"Kind": "Primitive", "Name": "Int32"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 4}
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

    @Expect(source.contains("public var value: Int32 = 0"), true)
    @Expect(source.contains("public static const Enabled: Int32 = 4"), true)
    @Expect(source.contains("public var Enabled"), false)
}

@Test
func testBoolLiteralConstantsRenderAsBoolValues() {
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
          "Name": "BOOL_FLAGS",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "Enabled",
              "Signature": {"Kind": "Primitive", "Name": "Boolean"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"TypeCode": "UInt8", "Value": 1}
            },
            {
              "Name": "Disabled",
              "Signature": {"Kind": "Primitive", "Name": "Boolean"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"TypeCode": "UInt8", "Value": 0}
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

    @Expect(source.contains("public static const Enabled: Bool = true"), true)
    @Expect(source.contains("public static const Disabled: Bool = false"), true)
    @Expect(source.contains("public static const Enabled: Bool = 1"), false)
    @Expect(source.contains("public var reserved"), false)
}

@Test
func testFlagsEnumRendersBitwiseHelpers() {
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
          "Name": "WidgetFlags",
          "MetadataToken": "0x02000002",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [
            {
              "Type": "System.FlagsAttribute",
              "FixedArguments": [],
              "NamedArguments": []
            }
          ],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Read", "Signature": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "WidgetFlags"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}},
            {"Name": "Write", "Signature": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "WidgetFlags"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2}}
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

    @Expect(source.contains("public func contains(other: Tiny_Foundation_WidgetFlags): Bool"), true)
    @Expect(source.contains("return (value & other.value) == other.value"), true)
    @Expect(source.contains("public operator func |(other: Tiny_Foundation_WidgetFlags): Tiny_Foundation_WidgetFlags"), true)
    @Expect(source.contains("return Tiny_Foundation_WidgetFlags(value | other.value)"), true)
    @Expect(source.contains("public operator func &(other: Tiny_Foundation_WidgetFlags): Tiny_Foundation_WidgetFlags"), true)
    @Expect(source.contains("return Tiny_Foundation_WidgetFlags(value & other.value)"), true)
    @Expect(source.contains("public operator func ^(other: Tiny_Foundation_WidgetFlags): Tiny_Foundation_WidgetFlags"), true)
    @Expect(source.contains("return Tiny_Foundation_WidgetFlags(value ^ other.value)"), true)
    @Expect(source.contains("public operator func !(): Tiny_Foundation_WidgetFlags"), true)
    @Expect(source.contains("return Tiny_Foundation_WidgetFlags(!value)"), true)
    @Expect(source.contains("public let Tiny_Foundation_WidgetFlags_Read = Tiny_Foundation_WidgetFlags(1)"), true)
}

@Test
func testNonSystemFlagsAttributeDoesNotRenderBitwiseHelpers() {
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
          "Name": "WidgetState",
          "MetadataToken": "0x02000002",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [
            {
              "Type": "Example.Metadata.FlagsAttribute",
              "FixedArguments": [],
              "NamedArguments": []
            }
          ],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Ready", "Signature": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "WidgetState"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
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

    @Expect(source.contains("public func contains(other: Tiny_Foundation_WidgetState): Bool"), false)
    @Expect(source.contains("public operator func |(other: Tiny_Foundation_WidgetState): Tiny_Foundation_WidgetState"), false)
}

@Test
func testStringLiteralConstantsUseStringProjection() {
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
          "Name": "NAMES",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "RuntimeName",
              "Signature": {"Kind": "Primitive", "Name": "String"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "Tiny.Foundation.Sample"}
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

    @Expect(source.contains("public static const RuntimeName: String = \"Tiny.Foundation.Sample\""), true)
    @Expect(source.contains("public static const RuntimeName: CPointer<Unit>"), false)
    @Expect(source.contains("public var reserved"), false)
}

@Test
func testStringLiteralConstantsOnAbiStructRenderAsStaticFunctions() {
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
          "Name": "NAMED_VALUE",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "value",
              "Signature": {"Kind": "Primitive", "Name": "Int32"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            },
            {
              "Name": "RuntimeName",
              "Signature": {"Kind": "Primitive", "Name": "String"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "Tiny.Foundation.NamedValue"}
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

    @Expect(source.contains("@C\npublic struct Tiny_Foundation_NAMED_VALUE"), true)
    @Expect(source.contains("public var value: Int32 = 0"), true)
    @Expect(source.contains("public static func RuntimeName(): String {\n        return \"Tiny.Foundation.NamedValue\"\n    }"), true)
    @Expect(source.contains("public static const RuntimeName: String"), false)
}

@Test
func testWin32TextPointerLiteralConstantsUseStringFactories() {
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
          "Name": "TEXT_NAMES",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "WideName",
              "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PCWSTR"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "Wide.Name"}
            },
            {
              "Name": "NarrowName",
              "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PCSTR"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "Narrow.Name"}
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
          "Name": "TEXT_VALUE",
          "MetadataToken": "0x02000003",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {
              "Name": "value",
              "Signature": {"Kind": "Primitive", "Name": "Int32"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null
            },
            {
              "Name": "WideName",
              "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PCWSTR"},
              "Attributes": ["Public", "Static", "Literal"],
              "CustomAttributes": [],
              "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "String"}, "Value": "Wide.Value"}
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
    var textNamesSource = ""
    var textValueSource = ""
    for (record in records) {
        if (record.fullName == "Tiny.Foundation.TEXT_NAMES") {
            textNamesSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.TEXT_VALUE") {
            textValueSource = renderSymbolImpl(record, symbolsByName)
        }
    }
    let deps = collectSupportDependencyNames("windows_gen", records, symbolsByName)
    let outDir = ".generated/text-literal-import-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeImplFiles(writer, records, "windows_gen", symbolsByName)
    let implChunk = String.fromUtf8(File.readFrom("${outDir}/src/impl/symbols_0.cj"))
    removeIfExists(outDir, recursive: true)

    @Expect(textNamesSource.contains("public static let WideName: windows_strings.WideStringFactory = windows_strings.wideStringFactory(\"Wide.Name\")"), true)
    @Expect(textNamesSource.contains("public static let NarrowName: windows_strings.NarrowStringFactory = windows_strings.pcstrLiteral(\"Narrow.Name\")"), true)
    @Expect(textNamesSource.contains("public static const WideName"), false)
    @Expect(textNamesSource.contains("public static const NarrowName"), false)
    @Expect(textValueSource.contains("public static func WideName(): windows_strings.WideStringFactory {\n        return windows_strings.wideStringFactory(\"Wide.Value\")\n    }"), true)
    @Expect(textValueSource.contains("public static let WideName"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_strings"), true)
    @Expect(implChunk.contains("import windows_strings as windows_strings"), true)
}

@Test
func testWin32TextPointerAbiContextsUseTypedRawPointers() {
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
          "Name": "TEXT_POINTERS",
          "MetadataToken": "0x02000002",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Wide", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PCWSTR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "MutableWide", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PWSTR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Narrow", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PCSTR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "MutableNarrow", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PSTR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "ITextConsumer",
          "MetadataToken": "0x02000003",
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
              "Name": "SetWide",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PCWSTR"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "name", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetWide",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PWSTR"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetNarrow",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "PCSTR"}
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}
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
    var structSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Tiny.Foundation.TEXT_POINTERS") {
            structSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.ITextConsumer") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(structSource.contains("public var Wide: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(structSource.contains("public var MutableWide: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(structSource.contains("public var Narrow: CPointer<UInt8> = CPointer<UInt8>()"), true)
    @Expect(structSource.contains("public var MutableNarrow: CPointer<UInt8> = CPointer<UInt8>()"), true)
    @Expect(structSource.contains("Windows_Win32_Foundation_PCWSTR"), false)
    @Expect(structSource.contains("Windows_Win32_Foundation_PSTR"), false)
    @Expect(interfaceSource.contains("func SetWide(name: CPointer<UInt16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetWide(value: CPointer<CPointer<UInt16>>): Int32"), true)
    @Expect(interfaceSource.contains("func GetNarrow(result: CPointer<CPointer<UInt8>>): Int32"), true)
    @Expect(interfaceSource.contains("CPointer<Unit>"), false)
}

@Test
func testWin32TextPointerTypeDefinitionsRenderRawPointerAliases() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "PWSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "PSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "PCWSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "PCSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
    var wideMutable = ""
    var narrowMutable = ""
    var wideConst = ""
    var narrowConst = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.PWSTR") {
            wideMutable = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.PSTR") {
            narrowMutable = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.PCWSTR") {
            wideConst = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.PCSTR") {
            narrowConst = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(wideMutable.contains("public type Windows_Win32_Foundation_PWSTR = CPointer<UInt16>"), true)
    @Expect(narrowMutable.contains("public type Windows_Win32_Foundation_PSTR = CPointer<UInt8>"), true)
    @Expect(wideConst.contains("public type Windows_Win32_Foundation_PCWSTR = CPointer<UInt16>"), true)
    @Expect(narrowConst.contains("public type Windows_Win32_Foundation_PCSTR = CPointer<UInt8>"), true)
    @Expect(wideMutable.contains("public struct Windows_Win32_Foundation_PWSTR"), false)
    @Expect(narrowMutable.contains("public struct Windows_Win32_Foundation_PSTR"), false)
    @Expect(wideConst.contains("public struct Windows_Win32_Foundation_PCWSTR"), false)
    @Expect(narrowConst.contains("public struct Windows_Win32_Foundation_PCSTR"), false)
}

@Test
func testEventRegistrationTokenAbiContextsUseInt64Aliases() {
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
          "Namespace": "Windows.Foundation",
          "Name": "EventRegistrationToken",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int64"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.WinRT",
          "Name": "EventRegistrationToken",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int64"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "TokenBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Token", "Signature": {"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "EventRegistrationToken"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
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
          "Name": "IEventSource",
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
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "TypedEventHandler"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "EventRegistrationToken"}
              },
              "Parameters": [{"Name": "handler", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "remove_Completed",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "EventRegistrationToken"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "token", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "add_LowLevel",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "TypedEventHandler"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "EventRegistrationToken"}
              },
              "Parameters": [{"Name": "handler", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "remove_LowLevel",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "EventRegistrationToken"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "token", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}],
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
    var foundationTokenSource = ""
    var win32TokenSource = ""
    var holderSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Foundation.EventRegistrationToken") {
            foundationTokenSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.WinRT.EventRegistrationToken") {
            win32TokenSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.TokenBox") {
            holderSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IEventSource") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(foundationTokenSource.contains("public type Windows_Foundation_EventRegistrationToken = Int64"), true)
    @Expect(win32TokenSource.contains("public type Windows_Win32_System_WinRT_EventRegistrationToken = Int64"), true)
    @Expect(foundationTokenSource.contains("public struct Windows_Foundation_EventRegistrationToken"), false)
    @Expect(win32TokenSource.contains("public struct Windows_Win32_System_WinRT_EventRegistrationToken"), false)
    @Expect(holderSource.contains("public var Token: Int64 = 0"), true)
    @Expect(holderSource.contains("Windows_Foundation_EventRegistrationToken"), false)
    @Expect(interfaceSource.contains("func add_Completed(handler: CPointer<Unit>, result: CPointer<Int64>): Int32"), true)
    @Expect(interfaceSource.contains("func remove_Completed(token: Int64): Int32"), true)
    @Expect(interfaceSource.contains("func add_LowLevel(handler: CPointer<Unit>, result: CPointer<Int64>): Int32"), true)
    @Expect(interfaceSource.contains("func remove_LowLevel(token: Int64): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Foundation_EventRegistrationToken"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_WinRT_EventRegistrationToken"), false)
}

@Test
func testWin32ScalarTypedefAbiContextsUsePrimitiveAliases() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "BOOLEAN",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "UInt8"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "CHAR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int8"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "ScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Ok", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ByteFlag", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOLEAN"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Ansi", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "CHAR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "BOOL"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "IScalarConsumer",
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
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOLEAN"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "CHAR"}
                ],
                "RequiredParameterCount": 3,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "ok", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "flag", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "ch", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetFlag",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOLEAN"}
              },
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetChar",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "CHAR"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "value", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
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
    var boolSource = ""
    var booleanSource = ""
    var charSource = ""
    var boxSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.BOOL") {
            boolSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.BOOLEAN") {
            booleanSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.CHAR") {
            charSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.ScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IScalarConsumer") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(boolSource.contains("public type Windows_Win32_Foundation_BOOL = Int32"), true)
    @Expect(booleanSource.contains("public type Windows_Win32_Foundation_BOOLEAN = UInt8"), true)
    @Expect(charSource.contains("public type Windows_Win32_Foundation_CHAR = Int8"), true)
    @Expect(boolSource.contains("public struct Windows_Win32_Foundation_BOOL"), false)
    @Expect(booleanSource.contains("public struct Windows_Win32_Foundation_BOOLEAN"), false)
    @Expect(charSource.contains("public struct Windows_Win32_Foundation_CHAR"), false)
    @Expect(boxSource.contains("public var Ok: Int32 = 0"), true)
    @Expect(boxSource.contains("public var ByteFlag: UInt8 = 0"), true)
    @Expect(boxSource.contains("public var Ansi: Int8 = 0"), true)
    @Expect(boxSource.contains("public var Other: Example_Native_BOOL = Example_Native_BOOL()"), true)
    @Expect(interfaceSource.contains("func Set(ok: Int32, flag: UInt8, ch: Int8): Int32"), true)
    @Expect(interfaceSource.contains("func GetFlag(result: CPointer<UInt8>): Int32"), true)
    @Expect(interfaceSource.contains("func GetChar(value: CPointer<Int8>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_BOOL"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_BOOLEAN"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_CHAR"), false)
}

@Test
func testVariantBoolAbiContextsUseInt16Alias() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "VARIANT_BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int16"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "VARIANT_BOOL",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "VariantBoolBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Flag", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "VARIANT_BOOL"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "FlagPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "VARIANT_BOOL"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "OtherPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Example.Native", "Name": "VARIANT_BOOL"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "VariantBoolUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {
              "Name": "Flag",
              "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "VARIANT_BOOL"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null,
              "Offset": 0
            },
            {
              "Name": "FlagPointer",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "VARIANT_BOOL"}},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null,
              "Offset": 0
            },
            {
              "Name": "OtherPointer",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Example.Native", "Name": "VARIANT_BOOL"}},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null,
              "Offset": 0
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
          "Name": "IVariantBoolConsumer",
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
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "VARIANT_BOOL"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "flag", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "Get",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "VARIANT_BOOL"}
              },
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetOut",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "VARIANT_BOOL"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "value", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
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
    var variantSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.VARIANT_BOOL") {
            variantSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.VARIANT_BOOL") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.VariantBoolBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.VariantBoolUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IVariantBoolConsumer") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(variantSource.contains("public type Windows_Win32_Foundation_VARIANT_BOOL = Int16"), true)
    @Expect(variantSource.contains("public struct Windows_Win32_Foundation_VARIANT_BOOL"), false)
    @Expect(exampleSource.contains("public struct Example_Native_VARIANT_BOOL"), true)
    @Expect(boxSource.contains("public var Flag: Int16 = 0"), true)
    @Expect(boxSource.contains("public var FlagPointer: CPointer<Int16> = CPointer<Int16>()"), true)
    @Expect(boxSource.contains("public var OtherPointer: CPointer<Unit> = CPointer<Unit>()"), true)
    @Expect(unionSource.contains("public mut prop Flag: Int16"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt16(base, 0)"), true)
    @Expect(unionSource.contains("windows_polyfill.unionWriteInt16(base, 0, val)"), true)
    @Expect(unionSource.contains("public mut prop FlagPointer: CPointer<Int16>"), true)
    @Expect(unionSource.contains("let ptr = CPointer<CPointer<Int16>>(p)"), true)
    @Expect(unionSource.contains("public mut prop OtherPointer: CPointer<Unit>"), true)
    @Expect(interfaceSource.contains("func Set(flag: Int16): Int32"), true)
    @Expect(interfaceSource.contains("func Get(result: CPointer<Int16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetOut(value: CPointer<Int16>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_VARIANT_BOOL"), false)
}

@Test
func testHResultAbiContextsUseInt32Aliases() {
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
          "Namespace": "Windows.Foundation",
          "Name": "HResult",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "HRESULT",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "HResult",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "ErrorBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Foundation", "Signature": {"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "HResult"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Win32", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "HResult"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "IErrorSource",
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
              "Name": "SetError",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "HResult"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "foundation", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "win32", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetError",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "HResult"}
              },
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var foundationSource = ""
    var win32Source = ""
    var boxSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Foundation.HResult") {
            foundationSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.HRESULT") {
            win32Source = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.ErrorBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IErrorSource") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(foundationSource.contains("public type Windows_Foundation_HResult = Int32"), true)
    @Expect(win32Source.contains("public type Windows_Win32_Foundation_HRESULT = Int32"), true)
    @Expect(foundationSource.contains("public struct Windows_Foundation_HResult"), false)
    @Expect(win32Source.contains("public struct Windows_Win32_Foundation_HRESULT"), false)
    @Expect(boxSource.contains("public var Foundation: Int32 = 0"), true)
    @Expect(boxSource.contains("public var Win32: Int32 = 0"), true)
    @Expect(boxSource.contains("public var Other: Example_Native_HResult = Example_Native_HResult()"), true)
    @Expect(interfaceSource.contains("func SetError(foundation: Int32, win32: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func GetError(result: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Foundation_HResult"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_HRESULT"), false)
}

@Test
func testWin32StatusCodeAbiContextsUsePrimitiveAliasesAndConstants() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "NTSTATUS",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "WIN32_ERROR",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "NO_ERROR", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 0}},
            {"Name": "ERROR_CONTROL_C_EXIT", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 572}},
            {"Name": "ERROR_WAIT_NO_CHILDREN", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 128}}
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
          "Name": "WIN32_ERROR",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "WIN32_ERROR"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
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
          "Name": "StatusBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Status", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Error", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ErrorPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "WIN32_ERROR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "StatusUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "Status", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Error", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ErrorPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
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
          "Name": "IStatusCodes",
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
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "status", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "error", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetStatus",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetError",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WIN32_ERROR"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "error", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
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
    var statusSource = ""
    var errorSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.NTSTATUS") {
            statusSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.WIN32_ERROR") {
            errorSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.WIN32_ERROR") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.StatusBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.StatusUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IStatusCodes") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(statusSource.contains("public type Windows_Win32_Foundation_NTSTATUS = Int32"), true)
    @Expect(errorSource.contains("public type Windows_Win32_Foundation_WIN32_ERROR = UInt32"), true)
    @Expect(statusSource.contains("public struct Windows_Win32_Foundation_NTSTATUS"), false)
    @Expect(errorSource.contains("public struct Windows_Win32_Foundation_WIN32_ERROR"), false)
    @Expect(errorSource.contains("public let Windows_Win32_Foundation_WIN32_ERROR_NO_ERROR: Windows_Win32_Foundation_WIN32_ERROR = 0"), true)
    @Expect(errorSource.contains("public let Windows_Win32_Foundation_WIN32_ERROR_ERROR_CONTROL_C_EXIT: Windows_Win32_Foundation_WIN32_ERROR = 572"), true)
    @Expect(errorSource.contains("Windows_Win32_Foundation_WIN32_ERROR(0)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_WIN32_ERROR"), true)
    @Expect(boxSource.contains("public var Status: Int32 = 0"), true)
    @Expect(boxSource.contains("public var Error: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var ErrorPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var Other: UInt16 = 0"), true)
    @Expect(unionSource.contains("public mut prop Status: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Error: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ErrorPointer: CPointer<UInt32>"), true)
    @Expect(interfaceSource.contains("func Set(status: Int32, error: UInt32): Int32"), true)
    @Expect(interfaceSource.contains("func GetStatus(result: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetError(error: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_NTSTATUS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_WIN32_ERROR"), false)
}

@Test
func testWin32NtStatusSubcodeAbiContextsUseUInt32AliasesAndConstants() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "NTSTATUS_FACILITY_CODE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "FACILITY_DEBUGGER", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}},
            {"Name": "FACILITY_NTWIN32", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 7}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "NTSTATUS_SEVERITY_CODE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "STATUS_SEVERITY_SUCCESS", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_SEVERITY_CODE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 0}},
            {"Name": "STATUS_SEVERITY_ERROR", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_SEVERITY_CODE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 3}}
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
          "Name": "NTSTATUS_FACILITY_CODE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "NTSTATUS_FACILITY_CODE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
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
          "Name": "NtSubcodeBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Facility", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Severity", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_SEVERITY_CODE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "FacilityPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "NTSTATUS_FACILITY_CODE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "NtSubcodeUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "Facility", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Severity", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_SEVERITY_CODE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "FacilityPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
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
          "Name": "INtSubcodes",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 572662306},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 13107},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 17476},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_SEVERITY_CODE"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "facility", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "severity", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetFacility",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_FACILITY_CODE"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "facility", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetSeverity",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "NTSTATUS_SEVERITY_CODE"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var facilitySource = ""
    var severitySource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.NTSTATUS_FACILITY_CODE") {
            facilitySource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.NTSTATUS_SEVERITY_CODE") {
            severitySource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.NTSTATUS_FACILITY_CODE") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.NtSubcodeBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.NtSubcodeUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.INtSubcodes") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(facilitySource.contains("public type Windows_Win32_Foundation_NTSTATUS_FACILITY_CODE = UInt32"), true)
    @Expect(severitySource.contains("public type Windows_Win32_Foundation_NTSTATUS_SEVERITY_CODE = UInt32"), true)
    @Expect(facilitySource.contains("public struct Windows_Win32_Foundation_NTSTATUS_FACILITY_CODE"), false)
    @Expect(severitySource.contains("public struct Windows_Win32_Foundation_NTSTATUS_SEVERITY_CODE"), false)
    @Expect(facilitySource.contains("public let Windows_Win32_Foundation_NTSTATUS_FACILITY_CODE_FACILITY_DEBUGGER: Windows_Win32_Foundation_NTSTATUS_FACILITY_CODE = 1"), true)
    @Expect(severitySource.contains("public let Windows_Win32_Foundation_NTSTATUS_SEVERITY_CODE_STATUS_SEVERITY_ERROR: Windows_Win32_Foundation_NTSTATUS_SEVERITY_CODE = 3"), true)
    @Expect(facilitySource.contains("Windows_Win32_Foundation_NTSTATUS_FACILITY_CODE(1)"), false)
    @Expect(severitySource.contains("Windows_Win32_Foundation_NTSTATUS_SEVERITY_CODE(3)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_NTSTATUS_FACILITY_CODE"), true)
    @Expect(boxSource.contains("public var Facility: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Severity: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var FacilityPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var Other: UInt16 = 0"), true)
    @Expect(unionSource.contains("public mut prop Facility: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Severity: UInt32"), true)
    @Expect(unionSource.contains("public mut prop FacilityPointer: CPointer<UInt32>"), true)
    @Expect(interfaceSource.contains("func Set(facility: UInt32, severity: UInt32): Int32"), true)
    @Expect(interfaceSource.contains("func GetFacility(facility: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetSeverity(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_NTSTATUS_FACILITY_CODE"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_NTSTATUS_SEVERITY_CODE"), false)
}

@Test
func testWin32UInt32ScalarAbiContextsUseUInt32AliasesAndConstants() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "COLORREF",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "DUPLICATE_HANDLE_OPTIONS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "DUPLICATE_CLOSE_SOURCE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "DUPLICATE_HANDLE_OPTIONS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "GENERIC_ACCESS_RIGHTS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "GENERIC_READ", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "GENERIC_ACCESS_RIGHTS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2147483648}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "HANDLE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "HANDLE_FLAG_INHERIT", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HANDLE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "OBJECT_ATTRIBUTE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "OBJ_INHERIT", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "OBJECT_ATTRIBUTE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "WAIT_EVENT",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "WAIT_OBJECT_0", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WAIT_EVENT"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 0}}
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
          "Name": "HANDLE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "HANDLE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
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
          "Name": "UInt32ScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Color", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "COLORREF"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Duplicate", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "DUPLICATE_HANDLE_OPTIONS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Access", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "GENERIC_ACCESS_RIGHTS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "HandleFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HANDLE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ObjectFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "OBJECT_ATTRIBUTE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Wait", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WAIT_EVENT"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ColorPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "COLORREF"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "HANDLE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "UInt32ScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "Color", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "COLORREF"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Wait", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WAIT_EVENT"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ColorPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "COLORREF"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
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
          "Name": "IUInt32Scalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 858993459},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 17476},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 21845},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "COLORREF"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WAIT_EVENT"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "color", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "wait", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetColor",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "COLORREF"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "color", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetWait",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WAIT_EVENT"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var colorSource = ""
    var duplicateSource = ""
    var accessSource = ""
    var handleSource = ""
    var objectSource = ""
    var waitSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.COLORREF") {
            colorSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.DUPLICATE_HANDLE_OPTIONS") {
            duplicateSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.GENERIC_ACCESS_RIGHTS") {
            accessSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.HANDLE_FLAGS") {
            handleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.OBJECT_ATTRIBUTE_FLAGS") {
            objectSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.WAIT_EVENT") {
            waitSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.HANDLE_FLAGS") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.UInt32ScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.UInt32ScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IUInt32Scalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(colorSource.contains("public type Windows_Win32_Foundation_COLORREF = UInt32"), true)
    @Expect(duplicateSource.contains("public type Windows_Win32_Foundation_DUPLICATE_HANDLE_OPTIONS = UInt32"), true)
    @Expect(accessSource.contains("public type Windows_Win32_Foundation_GENERIC_ACCESS_RIGHTS = UInt32"), true)
    @Expect(handleSource.contains("public type Windows_Win32_Foundation_HANDLE_FLAGS = UInt32"), true)
    @Expect(objectSource.contains("public type Windows_Win32_Foundation_OBJECT_ATTRIBUTE_FLAGS = UInt32"), true)
    @Expect(waitSource.contains("public type Windows_Win32_Foundation_WAIT_EVENT = UInt32"), true)
    @Expect(colorSource.contains("public struct Windows_Win32_Foundation_COLORREF"), false)
    @Expect(handleSource.contains("public struct Windows_Win32_Foundation_HANDLE_FLAGS"), false)
    @Expect(waitSource.contains("public struct Windows_Win32_Foundation_WAIT_EVENT"), false)
    @Expect(duplicateSource.contains("public let Windows_Win32_Foundation_DUPLICATE_HANDLE_OPTIONS_DUPLICATE_CLOSE_SOURCE: Windows_Win32_Foundation_DUPLICATE_HANDLE_OPTIONS = 1"), true)
    @Expect(accessSource.contains("public let Windows_Win32_Foundation_GENERIC_ACCESS_RIGHTS_GENERIC_READ: Windows_Win32_Foundation_GENERIC_ACCESS_RIGHTS = 2147483648"), true)
    @Expect(handleSource.contains("public let Windows_Win32_Foundation_HANDLE_FLAGS_HANDLE_FLAG_INHERIT: Windows_Win32_Foundation_HANDLE_FLAGS = 1"), true)
    @Expect(objectSource.contains("public let Windows_Win32_Foundation_OBJECT_ATTRIBUTE_FLAGS_OBJ_INHERIT: Windows_Win32_Foundation_OBJECT_ATTRIBUTE_FLAGS = 2"), true)
    @Expect(waitSource.contains("public let Windows_Win32_Foundation_WAIT_EVENT_WAIT_OBJECT_0: Windows_Win32_Foundation_WAIT_EVENT = 0"), true)
    @Expect(handleSource.contains("Windows_Win32_Foundation_HANDLE_FLAGS(1)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_HANDLE_FLAGS"), true)
    @Expect(boxSource.contains("public var Color: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Duplicate: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Access: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var HandleFlags: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var ObjectFlags: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Wait: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var ColorPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var Other: UInt16 = 0"), true)
    @Expect(unionSource.contains("public mut prop Color: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Wait: UInt32"), true)
    @Expect(unionSource.contains("public mut prop ColorPointer: CPointer<UInt32>"), true)
    @Expect(interfaceSource.contains("func Set(color: UInt32, wait: UInt32): Int32"), true)
    @Expect(interfaceSource.contains("func GetColor(color: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetWait(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_COLORREF"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_WAIT_EVENT"), false)
}

@Test
func testWin32SecurityScalarAbiContextsUsePrimitiveAliasesAndConstants() {
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
          "Namespace": "Windows.Win32.Security",
          "Name": "ACE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CONTAINER_INHERIT_ACE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Security",
          "Name": "ACL_INFORMATION_CLASS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "AclSizeInformation", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACL_INFORMATION_CLASS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 2}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Security",
          "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CLAIM_SECURITY_ATTRIBUTE_TYPE_OCTET_STRING", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 16}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Security",
          "Name": "SECURITY_DESCRIPTOR_CONTROL",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "SE_SELF_RELATIVE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "SECURITY_DESCRIPTOR_CONTROL"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 32768}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Security",
          "Name": "TOKEN_PRIVILEGES_ATTRIBUTES",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "SE_PRIVILEGE_USED_FOR_ACCESS", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "TOKEN_PRIVILEGES_ATTRIBUTES"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2147483648}}
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
          "Name": "ACE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt8"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "ACE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt8"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Security",
          "Name": "SecurityScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Ace", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "AclClass", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACL_INFORMATION_CLASS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ClaimType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Control", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "SECURITY_DESCRIPTOR_CONTROL"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "TokenPrivilege", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "TOKEN_PRIVILEGES_ATTRIBUTES"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "AcePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACE_FLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "AclPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACL_INFORMATION_CLASS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ClaimPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "ACE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Security",
          "Name": "SecurityScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "Ace", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "AclClass", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACL_INFORMATION_CLASS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ClaimType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ClaimPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Security",
          "Name": "ISecurityScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1145324612},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 21845},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 26214},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 238}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACE_FLAGS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "ACL_INFORMATION_CLASS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"}
                ],
                "RequiredParameterCount": 3,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "ace", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "acl", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "claim", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetClaim",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "claim", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetPrivilege",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Security", "Name": "TOKEN_PRIVILEGES_ATTRIBUTES"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var aceSource = ""
    var aclSource = ""
    var claimSource = ""
    var controlSource = ""
    var tokenPrivilegeSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Security.ACE_FLAGS") {
            aceSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Security.ACL_INFORMATION_CLASS") {
            aclSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Security.CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE") {
            claimSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Security.SECURITY_DESCRIPTOR_CONTROL") {
            controlSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Security.TOKEN_PRIVILEGES_ATTRIBUTES") {
            tokenPrivilegeSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.ACE_FLAGS") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Security.SecurityScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Security.SecurityScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Security.ISecurityScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(aceSource.contains("public type Windows_Win32_Security_ACE_FLAGS = UInt32"), true)
    @Expect(aclSource.contains("public type Windows_Win32_Security_ACL_INFORMATION_CLASS = Int32"), true)
    @Expect(claimSource.contains("public type Windows_Win32_Security_CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE = UInt16"), true)
    @Expect(controlSource.contains("public type Windows_Win32_Security_SECURITY_DESCRIPTOR_CONTROL = UInt16"), true)
    @Expect(tokenPrivilegeSource.contains("public type Windows_Win32_Security_TOKEN_PRIVILEGES_ATTRIBUTES = UInt32"), true)
    @Expect(aceSource.contains("public struct Windows_Win32_Security_ACE_FLAGS"), false)
    @Expect(aclSource.contains("public struct Windows_Win32_Security_ACL_INFORMATION_CLASS"), false)
    @Expect(claimSource.contains("public struct Windows_Win32_Security_CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"), false)
    @Expect(aceSource.contains("public let Windows_Win32_Security_ACE_FLAGS_CONTAINER_INHERIT_ACE: Windows_Win32_Security_ACE_FLAGS = 2"), true)
    @Expect(aclSource.contains("public let Windows_Win32_Security_ACL_INFORMATION_CLASS_AclSizeInformation: Windows_Win32_Security_ACL_INFORMATION_CLASS = 2"), true)
    @Expect(claimSource.contains("public let Windows_Win32_Security_CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE_CLAIM_SECURITY_ATTRIBUTE_TYPE_OCTET_STRING: Windows_Win32_Security_CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE = 16"), true)
    @Expect(controlSource.contains("public let Windows_Win32_Security_SECURITY_DESCRIPTOR_CONTROL_SE_SELF_RELATIVE: Windows_Win32_Security_SECURITY_DESCRIPTOR_CONTROL = 32768"), true)
    @Expect(tokenPrivilegeSource.contains("public let Windows_Win32_Security_TOKEN_PRIVILEGES_ATTRIBUTES_SE_PRIVILEGE_USED_FOR_ACCESS: Windows_Win32_Security_TOKEN_PRIVILEGES_ATTRIBUTES = 2147483648"), true)
    @Expect(aceSource.contains("Windows_Win32_Security_ACE_FLAGS(2)"), false)
    @Expect(tokenPrivilegeSource.contains("Windows_Win32_Security_TOKEN_PRIVILEGES_ATTRIBUTES(2147483648)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_ACE_FLAGS"), true)
    @Expect(boxSource.contains("public var Ace: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var AclClass: Int32 = 0"), true)
    @Expect(boxSource.contains("public var ClaimType: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var Control: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var TokenPrivilege: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var AcePointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var AclPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var ClaimPointer: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(boxSource.contains("public var Other: UInt8 = 0"), true)
    @Expect(unionSource.contains("public mut prop Ace: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop AclClass: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ClaimType: UInt16"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt16(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ClaimPointer: CPointer<UInt16>"), true)
    @Expect(interfaceSource.contains("func Set(ace: UInt32, acl: Int32, claim: UInt16): Int32"), true)
    @Expect(interfaceSource.contains("func GetClaim(claim: CPointer<UInt16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetPrivilege(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Security_ACE_FLAGS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Security_CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE"), false)
}

@Test
func testWin32ThreadingScalarAbiContextsUsePrimitiveAliasesAndConstants() {
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
          "Namespace": "Windows.Win32.System.Threading",
          "Name": "CREATE_EVENT",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CREATE_EVENT_MANUAL_RESET", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "CREATE_EVENT"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Threading",
          "Name": "PROCESS_CREATION_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CREATE_IGNORE_SYSTEM_DEFAULT", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "PROCESS_CREATION_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2147483648}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Threading",
          "Name": "QUEUE_USER_APC_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "QUEUE_USER_APC_FLAGS_SPECIAL_USER_APC", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "QUEUE_USER_APC_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Threading",
          "Name": "THREAD_PRIORITY",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "THREAD_PRIORITY_IDLE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_PRIORITY"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": -15}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Threading",
          "Name": "THREAD_ACCESS_RIGHTS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "THREAD_ALL_ACCESS", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_ACCESS_RIGHTS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2097151}}
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
          "Name": "PROCESS_CREATION_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "PROCESS_CREATION_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Threading",
          "Name": "ThreadingScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "CreateEvent", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "CREATE_EVENT"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ProcessFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "PROCESS_CREATION_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "QueueFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "QUEUE_USER_APC_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ThreadPriority", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_PRIORITY"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ThreadAccess", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_ACCESS_RIGHTS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CreateEventPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "CREATE_EVENT"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "PriorityPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_PRIORITY"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "PROCESS_CREATION_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Threading",
          "Name": "ThreadingScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "CreateEvent", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "CREATE_EVENT"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ThreadPriority", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_PRIORITY"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "CreateEventPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "CREATE_EVENT"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Threading",
          "Name": "IThreadingScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1431655765},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 26214},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 30583},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 238},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 255}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "CREATE_EVENT"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_PRIORITY"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "createEvent", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "priority", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetPriority",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "THREAD_PRIORITY"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "priority", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetProcessFlags",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Threading", "Name": "PROCESS_CREATION_FLAGS"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var createEventSource = ""
    var processFlagsSource = ""
    var queueFlagsSource = ""
    var prioritySource = ""
    var threadAccessSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Threading.CREATE_EVENT") {
            createEventSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Threading.PROCESS_CREATION_FLAGS") {
            processFlagsSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Threading.QUEUE_USER_APC_FLAGS") {
            queueFlagsSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Threading.THREAD_PRIORITY") {
            prioritySource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Threading.THREAD_ACCESS_RIGHTS") {
            threadAccessSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.PROCESS_CREATION_FLAGS") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Threading.ThreadingScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Threading.ThreadingScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Threading.IThreadingScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(createEventSource.contains("public type Windows_Win32_System_Threading_CREATE_EVENT = UInt32"), true)
    @Expect(processFlagsSource.contains("public type Windows_Win32_System_Threading_PROCESS_CREATION_FLAGS = UInt32"), true)
    @Expect(queueFlagsSource.contains("public type Windows_Win32_System_Threading_QUEUE_USER_APC_FLAGS = Int32"), true)
    @Expect(prioritySource.contains("public type Windows_Win32_System_Threading_THREAD_PRIORITY = Int32"), true)
    @Expect(threadAccessSource.contains("public type Windows_Win32_System_Threading_THREAD_ACCESS_RIGHTS = UInt32"), true)
    @Expect(createEventSource.contains("public struct Windows_Win32_System_Threading_CREATE_EVENT"), false)
    @Expect(prioritySource.contains("public struct Windows_Win32_System_Threading_THREAD_PRIORITY"), false)
    @Expect(createEventSource.contains("public let Windows_Win32_System_Threading_CREATE_EVENT_CREATE_EVENT_MANUAL_RESET: Windows_Win32_System_Threading_CREATE_EVENT = 1"), true)
    @Expect(processFlagsSource.contains("public let Windows_Win32_System_Threading_PROCESS_CREATION_FLAGS_CREATE_IGNORE_SYSTEM_DEFAULT: Windows_Win32_System_Threading_PROCESS_CREATION_FLAGS = 2147483648"), true)
    @Expect(queueFlagsSource.contains("public let Windows_Win32_System_Threading_QUEUE_USER_APC_FLAGS_QUEUE_USER_APC_FLAGS_SPECIAL_USER_APC: Windows_Win32_System_Threading_QUEUE_USER_APC_FLAGS = 1"), true)
    @Expect(prioritySource.contains("public let Windows_Win32_System_Threading_THREAD_PRIORITY_THREAD_PRIORITY_IDLE: Windows_Win32_System_Threading_THREAD_PRIORITY = -15"), true)
    @Expect(threadAccessSource.contains("public let Windows_Win32_System_Threading_THREAD_ACCESS_RIGHTS_THREAD_ALL_ACCESS: Windows_Win32_System_Threading_THREAD_ACCESS_RIGHTS = 2097151"), true)
    @Expect(processFlagsSource.contains("Windows_Win32_System_Threading_PROCESS_CREATION_FLAGS(2147483648)"), false)
    @Expect(prioritySource.contains("Windows_Win32_System_Threading_THREAD_PRIORITY(-15)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_PROCESS_CREATION_FLAGS"), true)
    @Expect(boxSource.contains("public var CreateEvent: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var ProcessFlags: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var QueueFlags: Int32 = 0"), true)
    @Expect(boxSource.contains("public var ThreadPriority: Int32 = 0"), true)
    @Expect(boxSource.contains("public var ThreadAccess: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var CreateEventPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var PriorityPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var Other: UInt16 = 0"), true)
    @Expect(unionSource.contains("public mut prop CreateEvent: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ThreadPriority: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop CreateEventPointer: CPointer<UInt32>"), true)
    @Expect(interfaceSource.contains("func Set(createEvent: UInt32, priority: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func GetPriority(priority: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetProcessFlags(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Threading_CREATE_EVENT"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Threading_THREAD_PRIORITY"), false)
}

@Test
func testWin32RegistryScalarAbiContextsUsePrimitiveAliasesAndConstants() {
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
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_CREATE_KEY_DISPOSITION",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "REG_CREATED_NEW_KEY", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_CREATE_KEY_DISPOSITION"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_NOTIFY_FILTER",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "REG_NOTIFY_THREAD_AGNOSTIC", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_NOTIFY_FILTER"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 268435456}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_OPEN_CREATE_OPTIONS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "REG_OPTION_DONT_VIRTUALIZE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_OPEN_CREATE_OPTIONS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 16}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_RESTORE_KEY_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "REG_FORCE_RESTORE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_RESTORE_KEY_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 8}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_ROUTINE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "RRF_ZEROONFAILURE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_ROUTINE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 536870912}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_SAM_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "KEY_ALL_ACCESS", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_SAM_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 983103}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_SAVE_FORMAT",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "REG_NO_COMPRESSION", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_SAVE_FORMAT"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 4}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Registry",
          "Name": "REG_VALUE_TYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "REG_QWORD_LITTLE_ENDIAN", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_VALUE_TYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 11}}
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
          "Name": "REG_SAM_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "REG_SAM_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Registry",
          "Name": "RegistryScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Disposition", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_CREATE_KEY_DISPOSITION"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Notify", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_NOTIFY_FILTER"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Restore", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_RESTORE_KEY_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Routine", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_ROUTINE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Sam", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_SAM_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ValueType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_VALUE_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "NotifyPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_NOTIFY_FILTER"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "RestorePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_RESTORE_KEY_FLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "REG_SAM_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Registry",
          "Name": "RegistryScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "Notify", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_NOTIFY_FILTER"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Restore", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_RESTORE_KEY_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "NotifyPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_NOTIFY_FILTER"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Registry",
          "Name": "IRegistryScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1717986918},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 30583},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 34952},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 238},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 255},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 17}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_CREATE_KEY_DISPOSITION"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_RESTORE_KEY_FLAGS"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "disposition", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "restore", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetRestore",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_RESTORE_KEY_FLAGS"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "restore", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetValueType",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Registry", "Name": "REG_VALUE_TYPE"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var dispositionSource = ""
    var notifySource = ""
    var openOptionsSource = ""
    var restoreSource = ""
    var routineSource = ""
    var samSource = ""
    var saveFormatSource = ""
    var valueTypeSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Registry.REG_CREATE_KEY_DISPOSITION") {
            dispositionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Registry.REG_NOTIFY_FILTER") {
            notifySource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Registry.REG_OPEN_CREATE_OPTIONS") {
            openOptionsSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Registry.REG_RESTORE_KEY_FLAGS") {
            restoreSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Registry.REG_ROUTINE_FLAGS") {
            routineSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Registry.REG_SAM_FLAGS") {
            samSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Registry.REG_SAVE_FORMAT") {
            saveFormatSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Registry.REG_VALUE_TYPE") {
            valueTypeSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.REG_SAM_FLAGS") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Registry.RegistryScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Registry.RegistryScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Registry.IRegistryScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(dispositionSource.contains("public type Windows_Win32_System_Registry_REG_CREATE_KEY_DISPOSITION = UInt32"), true)
    @Expect(notifySource.contains("public type Windows_Win32_System_Registry_REG_NOTIFY_FILTER = UInt32"), true)
    @Expect(openOptionsSource.contains("public type Windows_Win32_System_Registry_REG_OPEN_CREATE_OPTIONS = UInt32"), true)
    @Expect(restoreSource.contains("public type Windows_Win32_System_Registry_REG_RESTORE_KEY_FLAGS = Int32"), true)
    @Expect(routineSource.contains("public type Windows_Win32_System_Registry_REG_ROUTINE_FLAGS = UInt32"), true)
    @Expect(samSource.contains("public type Windows_Win32_System_Registry_REG_SAM_FLAGS = UInt32"), true)
    @Expect(saveFormatSource.contains("public type Windows_Win32_System_Registry_REG_SAVE_FORMAT = UInt32"), true)
    @Expect(valueTypeSource.contains("public type Windows_Win32_System_Registry_REG_VALUE_TYPE = UInt32"), true)
    @Expect(notifySource.contains("public struct Windows_Win32_System_Registry_REG_NOTIFY_FILTER"), false)
    @Expect(restoreSource.contains("public struct Windows_Win32_System_Registry_REG_RESTORE_KEY_FLAGS"), false)
    @Expect(dispositionSource.contains("public let Windows_Win32_System_Registry_REG_CREATE_KEY_DISPOSITION_REG_CREATED_NEW_KEY: Windows_Win32_System_Registry_REG_CREATE_KEY_DISPOSITION = 1"), true)
    @Expect(notifySource.contains("public let Windows_Win32_System_Registry_REG_NOTIFY_FILTER_REG_NOTIFY_THREAD_AGNOSTIC: Windows_Win32_System_Registry_REG_NOTIFY_FILTER = 268435456"), true)
    @Expect(openOptionsSource.contains("public let Windows_Win32_System_Registry_REG_OPEN_CREATE_OPTIONS_REG_OPTION_DONT_VIRTUALIZE: Windows_Win32_System_Registry_REG_OPEN_CREATE_OPTIONS = 16"), true)
    @Expect(restoreSource.contains("public let Windows_Win32_System_Registry_REG_RESTORE_KEY_FLAGS_REG_FORCE_RESTORE: Windows_Win32_System_Registry_REG_RESTORE_KEY_FLAGS = 8"), true)
    @Expect(routineSource.contains("public let Windows_Win32_System_Registry_REG_ROUTINE_FLAGS_RRF_ZEROONFAILURE: Windows_Win32_System_Registry_REG_ROUTINE_FLAGS = 536870912"), true)
    @Expect(samSource.contains("public let Windows_Win32_System_Registry_REG_SAM_FLAGS_KEY_ALL_ACCESS: Windows_Win32_System_Registry_REG_SAM_FLAGS = 983103"), true)
    @Expect(saveFormatSource.contains("public let Windows_Win32_System_Registry_REG_SAVE_FORMAT_REG_NO_COMPRESSION: Windows_Win32_System_Registry_REG_SAVE_FORMAT = 4"), true)
    @Expect(valueTypeSource.contains("public let Windows_Win32_System_Registry_REG_VALUE_TYPE_REG_QWORD_LITTLE_ENDIAN: Windows_Win32_System_Registry_REG_VALUE_TYPE = 11"), true)
    @Expect(notifySource.contains("Windows_Win32_System_Registry_REG_NOTIFY_FILTER(268435456)"), false)
    @Expect(routineSource.contains("Windows_Win32_System_Registry_REG_ROUTINE_FLAGS(536870912)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_REG_SAM_FLAGS"), true)
    @Expect(boxSource.contains("public var Disposition: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Notify: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Restore: Int32 = 0"), true)
    @Expect(boxSource.contains("public var Routine: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Sam: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var ValueType: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var NotifyPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var RestorePointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var Other: UInt16 = 0"), true)
    @Expect(unionSource.contains("public mut prop Notify: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Restore: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop NotifyPointer: CPointer<UInt32>"), true)
    @Expect(interfaceSource.contains("func Set(disposition: UInt32, restore: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func GetRestore(restore: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetValueType(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Registry_REG_CREATE_KEY_DISPOSITION"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Registry_REG_RESTORE_KEY_FLAGS"), false)
}

func cliTestExpectWin32ScalarRawAbi(fullName: String, expected: String) {
    match (win32ScalarRawAbiTypeByFullName(fullName)) {
        case Some(actual) => @Expect(actual, expected)
        case None => @Expect("<none>", expected)
    }
}

@Test
func testWin32ServicesScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.ENUM_SERVICE_STATE", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.ENUM_SERVICE_TYPE", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SC_ACTION_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SC_ENUM_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SC_EVENT_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SC_STATUS_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_CONFIG", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_DIRECTORY_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_ERROR", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_NOTIFY", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_REGISTRY_STATE_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_RUNS_IN_PROCESS", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_SHARED_DIRECTORY_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_SHARED_REGISTRY_STATE_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_START_TYPE", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_STATUS_CURRENT_STATE", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_TRIGGER_ACTION", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_TRIGGER_SPECIFIC_DATA_ITEM_DATA_TYPE", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Services.SERVICE_TRIGGER_TYPE", "UInt32")

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
          "Namespace": "Windows.Win32.System.Services",
          "Name": "ENUM_SERVICE_TYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "SERVICE_USER_SHARE_PROCESS", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "ENUM_SERVICE_TYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 96}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Services",
          "Name": "SC_ACTION_TYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "SC_ACTION_OWN_RESTART", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "SC_ACTION_TYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 4}}
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
          "Name": "SC_ACTION_TYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "SC_ACTION_TYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Services",
          "Name": "ServiceScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "ServiceType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "ENUM_SERVICE_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Action", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "SC_ACTION_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ServiceTypePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "ENUM_SERVICE_TYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ActionPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "SC_ACTION_TYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "SC_ACTION_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Services",
          "Name": "ServiceScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "ServiceType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "ENUM_SERVICE_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Action", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "SC_ACTION_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ActionPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "SC_ACTION_TYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Services",
          "Name": "IServicesScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 305419896},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4660},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 22136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 18},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 52},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 86},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 120},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 154},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 188},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 222},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 240}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "ENUM_SERVICE_TYPE"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "SC_ACTION_TYPE"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "serviceType", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "action", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetAction",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "SC_ACTION_TYPE"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "action", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetServiceType",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Services", "Name": "ENUM_SERVICE_TYPE"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var serviceTypeSource = ""
    var actionSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Services.ENUM_SERVICE_TYPE") {
            serviceTypeSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Services.SC_ACTION_TYPE") {
            actionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.SC_ACTION_TYPE") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Services.ServiceScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Services.ServiceScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Services.IServicesScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(serviceTypeSource.contains("public type Windows_Win32_System_Services_ENUM_SERVICE_TYPE = UInt32"), true)
    @Expect(actionSource.contains("public type Windows_Win32_System_Services_SC_ACTION_TYPE = Int32"), true)
    @Expect(serviceTypeSource.contains("public struct Windows_Win32_System_Services_ENUM_SERVICE_TYPE"), false)
    @Expect(actionSource.contains("public struct Windows_Win32_System_Services_SC_ACTION_TYPE"), false)
    @Expect(serviceTypeSource.contains("public let Windows_Win32_System_Services_ENUM_SERVICE_TYPE_SERVICE_USER_SHARE_PROCESS: Windows_Win32_System_Services_ENUM_SERVICE_TYPE = 96"), true)
    @Expect(actionSource.contains("public let Windows_Win32_System_Services_SC_ACTION_TYPE_SC_ACTION_OWN_RESTART: Windows_Win32_System_Services_SC_ACTION_TYPE = 4"), true)
    @Expect(serviceTypeSource.contains("Windows_Win32_System_Services_ENUM_SERVICE_TYPE(96)"), false)
    @Expect(actionSource.contains("Windows_Win32_System_Services_SC_ACTION_TYPE(4)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_SC_ACTION_TYPE"), true)
    @Expect(boxSource.contains("public var ServiceType: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Action: Int32 = 0"), true)
    @Expect(boxSource.contains("public var ServiceTypePointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var ActionPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var Other: Int32 = 0"), true)
    @Expect(unionSource.contains("public mut prop ServiceType: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Action: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ActionPointer: CPointer<Int32>"), true)
    @Expect(interfaceSource.contains("func Set(serviceType: UInt32, action: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func GetAction(action: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetServiceType(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Services_ENUM_SERVICE_TYPE"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Services_SC_ACTION_TYPE"), false)
}

@Test
func testWin32KernelScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Kernel.COMPARTMENT_ID", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Kernel.EVENT_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Kernel.EXCEPTION_DISPOSITION", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Kernel.NT_PRODUCT_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Kernel.SUITE_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Kernel.TIMER_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Kernel.WAIT_TYPE", "Int32")

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
          "Namespace": "Windows.Win32.System.Kernel",
          "Name": "COMPARTMENT_ID",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "DEFAULT_COMPARTMENT_ID", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "COMPARTMENT_ID"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Kernel",
          "Name": "WAIT_TYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "WaitDpc", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "WAIT_TYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 4}}
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
          "Name": "WAIT_TYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "WAIT_TYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Kernel",
          "Name": "KernelScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Compartment", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "COMPARTMENT_ID"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Wait", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "WAIT_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CompartmentPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "COMPARTMENT_ID"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "WaitPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "WAIT_TYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "WAIT_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Kernel",
          "Name": "KernelScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "Compartment", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "COMPARTMENT_ID"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Wait", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "WAIT_TYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "WaitPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "WAIT_TYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Kernel",
          "Name": "IKernelScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 19088743},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 17185},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 34661},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 1},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 35},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 69},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 103},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 137},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 171},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 205},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 239}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "COMPARTMENT_ID"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "WAIT_TYPE"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "compartment", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "wait", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetWait",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "WAIT_TYPE"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "wait", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetCompartment",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Kernel", "Name": "COMPARTMENT_ID"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var compartmentSource = ""
    var waitSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Kernel.COMPARTMENT_ID") {
            compartmentSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Kernel.WAIT_TYPE") {
            waitSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.WAIT_TYPE") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Kernel.KernelScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Kernel.KernelScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Kernel.IKernelScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(compartmentSource.contains("public type Windows_Win32_System_Kernel_COMPARTMENT_ID = Int32"), true)
    @Expect(waitSource.contains("public type Windows_Win32_System_Kernel_WAIT_TYPE = Int32"), true)
    @Expect(compartmentSource.contains("public struct Windows_Win32_System_Kernel_COMPARTMENT_ID"), false)
    @Expect(waitSource.contains("public struct Windows_Win32_System_Kernel_WAIT_TYPE"), false)
    @Expect(compartmentSource.contains("public let Windows_Win32_System_Kernel_COMPARTMENT_ID_DEFAULT_COMPARTMENT_ID: Windows_Win32_System_Kernel_COMPARTMENT_ID = 1"), true)
    @Expect(waitSource.contains("public let Windows_Win32_System_Kernel_WAIT_TYPE_WaitDpc: Windows_Win32_System_Kernel_WAIT_TYPE = 4"), true)
    @Expect(compartmentSource.contains("Windows_Win32_System_Kernel_COMPARTMENT_ID(1)"), false)
    @Expect(waitSource.contains("Windows_Win32_System_Kernel_WAIT_TYPE(4)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_WAIT_TYPE"), true)
    @Expect(boxSource.contains("public var Compartment: Int32 = 0"), true)
    @Expect(boxSource.contains("public var Wait: Int32 = 0"), true)
    @Expect(boxSource.contains("public var CompartmentPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var WaitPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var Other: Int32 = 0"), true)
    @Expect(unionSource.contains("public mut prop Compartment: Int32"), true)
    @Expect(unionSource.contains("public mut prop Wait: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop WaitPointer: CPointer<Int32>"), true)
    @Expect(interfaceSource.contains("func Set(compartment: Int32, wait: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func GetWait(wait: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetCompartment(result: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Kernel_COMPARTMENT_ID"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Kernel_WAIT_TYPE"), false)
}

@Test
func testWin32SystemOneOffScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Diagnostics.Debug.CONTEXT_FLAGS", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Ole.PARAMFLAGS", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemServices.RTL_UMS_SCHEDULER_REASON", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Variant.VARENUM", "UInt16")

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
          "Namespace": "Windows.Win32.System.Diagnostics.Debug",
          "Name": "CONTEXT_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CONTEXT_EXCEPTION_REPORTING_AMD64", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Diagnostics.Debug", "Name": "CONTEXT_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2147483648}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Ole",
          "Name": "PARAMFLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "PARAMFLAG_FHASCUSTDATA", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Ole", "Name": "PARAMFLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 64}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.SystemServices",
          "Name": "RTL_UMS_SCHEDULER_REASON",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "UmsSchedulerThreadYield", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemServices", "Name": "RTL_UMS_SCHEDULER_REASON"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 2}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Variant",
          "Name": "VARENUM",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "VT_ILLEGAL", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Variant", "Name": "VARENUM"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 65535}}
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
          "Name": "VARENUM",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "VARENUM"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.OneOff",
          "Name": "OneOffScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "ContextFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Diagnostics.Debug", "Name": "CONTEXT_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ParamFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Ole", "Name": "PARAMFLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Reason", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemServices", "Name": "RTL_UMS_SCHEDULER_REASON"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "VarType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Variant", "Name": "VARENUM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ContextPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Diagnostics.Debug", "Name": "CONTEXT_FLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ParamPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Ole", "Name": "PARAMFLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ReasonPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemServices", "Name": "RTL_UMS_SCHEDULER_REASON"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "VarPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Variant", "Name": "VARENUM"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "VARENUM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.OneOff",
          "Name": "OneOffScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "ContextFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Diagnostics.Debug", "Name": "CONTEXT_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ParamFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Ole", "Name": "PARAMFLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Reason", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemServices", "Name": "RTL_UMS_SCHEDULER_REASON"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "VarPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Variant", "Name": "VARENUM"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.OneOff",
          "Name": "IOneOffScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 324508639},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4951},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 9320},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 17},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 34},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 51},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 68},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Diagnostics.Debug", "Name": "CONTEXT_FLAGS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Ole", "Name": "PARAMFLAGS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemServices", "Name": "RTL_UMS_SCHEDULER_REASON"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Variant", "Name": "VARENUM"}
                ],
                "RequiredParameterCount": 4,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "contextFlags", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "paramFlags", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "reason", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "varType", "SequenceNumber": 4, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetParamFlags",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Ole", "Name": "PARAMFLAGS"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "paramFlags", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetContextFlags",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Diagnostics.Debug", "Name": "CONTEXT_FLAGS"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var contextSource = ""
    var paramSource = ""
    var reasonSource = ""
    var varenumSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Diagnostics.Debug.CONTEXT_FLAGS") {
            contextSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Ole.PARAMFLAGS") {
            paramSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.SystemServices.RTL_UMS_SCHEDULER_REASON") {
            reasonSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Variant.VARENUM") {
            varenumSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.VARENUM") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.OneOff.OneOffScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.OneOff.OneOffScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.OneOff.IOneOffScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(contextSource.contains("public type Windows_Win32_System_Diagnostics_Debug_CONTEXT_FLAGS = UInt32"), true)
    @Expect(paramSource.contains("public type Windows_Win32_System_Ole_PARAMFLAGS = UInt16"), true)
    @Expect(reasonSource.contains("public type Windows_Win32_System_SystemServices_RTL_UMS_SCHEDULER_REASON = Int32"), true)
    @Expect(varenumSource.contains("public type Windows_Win32_System_Variant_VARENUM = UInt16"), true)
    @Expect(contextSource.contains("public struct Windows_Win32_System_Diagnostics_Debug_CONTEXT_FLAGS"), false)
    @Expect(paramSource.contains("public struct Windows_Win32_System_Ole_PARAMFLAGS"), false)
    @Expect(reasonSource.contains("public struct Windows_Win32_System_SystemServices_RTL_UMS_SCHEDULER_REASON"), false)
    @Expect(varenumSource.contains("public struct Windows_Win32_System_Variant_VARENUM"), false)
    @Expect(contextSource.contains("public let Windows_Win32_System_Diagnostics_Debug_CONTEXT_FLAGS_CONTEXT_EXCEPTION_REPORTING_AMD64: Windows_Win32_System_Diagnostics_Debug_CONTEXT_FLAGS = 2147483648"), true)
    @Expect(paramSource.contains("public let Windows_Win32_System_Ole_PARAMFLAGS_PARAMFLAG_FHASCUSTDATA: Windows_Win32_System_Ole_PARAMFLAGS = 64"), true)
    @Expect(reasonSource.contains("public let Windows_Win32_System_SystemServices_RTL_UMS_SCHEDULER_REASON_UmsSchedulerThreadYield: Windows_Win32_System_SystemServices_RTL_UMS_SCHEDULER_REASON = 2"), true)
    @Expect(varenumSource.contains("public let Windows_Win32_System_Variant_VARENUM_VT_ILLEGAL: Windows_Win32_System_Variant_VARENUM = 65535"), true)
    @Expect(contextSource.contains("Windows_Win32_System_Diagnostics_Debug_CONTEXT_FLAGS(2147483648)"), false)
    @Expect(varenumSource.contains("Windows_Win32_System_Variant_VARENUM(65535)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_VARENUM"), true)
    @Expect(boxSource.contains("public var ContextFlags: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var ParamFlags: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var Reason: Int32 = 0"), true)
    @Expect(boxSource.contains("public var VarType: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var ContextPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var ParamPointer: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(boxSource.contains("public var ReasonPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var VarPointer: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(boxSource.contains("public var Other: UInt16 = 0"), true)
    @Expect(unionSource.contains("public mut prop ContextFlags: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ParamFlags: UInt16"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt16(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Reason: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop VarPointer: CPointer<UInt16>"), true)
    @Expect(interfaceSource.contains("func Set(contextFlags: UInt32, paramFlags: UInt16, reason: Int32, varType: UInt16): Int32"), true)
    @Expect(interfaceSource.contains("func GetParamFlags(paramFlags: CPointer<UInt16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetContextFlags(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Diagnostics_Debug_CONTEXT_FLAGS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Ole_PARAMFLAGS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_SystemServices_RTL_UMS_SCHEDULER_REASON"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Variant_VARENUM"), false)
}

@Test
func testWin32ComScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.IDLFLAGS", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.IMPLTYPEFLAGS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.INVOKEKIND", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.LOCKTYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.MEMCTX", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.MSHCTX", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.MSHLFLAGS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.REGCLS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.ROT_FLAGS", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.STGM", "UInt32")

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
          "Namespace": "Windows.Win32.System.Com",
          "Name": "IDLFLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "IDLFLAG_FRETVAL", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "IDLFLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 8}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "REGCLS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "REGCLS_MULTIPLEUSE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "REGCLS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "STGM",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "STGM_SIMPLE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STGM"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 134217728}}
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
          "Name": "STGM",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "STGM"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Com",
          "Name": "ComScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "IdlFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "IDLFLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ClassRegistration", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "REGCLS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "StorageMode", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STGM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "IdlPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "IDLFLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "RegistrationPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "REGCLS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "StoragePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STGM"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "STGM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Com",
          "Name": "ComScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "IdlFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "IDLFLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ClassRegistration", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "REGCLS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "StorageMode", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STGM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "StoragePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STGM"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.Com",
          "Name": "IComScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 324508639},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4951},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 9320},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 1},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 35},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 69},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 103},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 137},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 171},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 205},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 239}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "IDLFLAGS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "REGCLS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STGM"}
                ],
                "RequiredParameterCount": 3,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "idlFlags", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "classRegistration", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "storageMode", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetIdlFlags",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "IDLFLAGS"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "idlFlags", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetStorageMode",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STGM"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var idlSource = ""
    var regclsSource = ""
    var stgmSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Com.IDLFLAGS") {
            idlSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.REGCLS") {
            regclsSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.STGM") {
            stgmSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.STGM") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Com.ComScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Com.ComScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Com.IComScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(idlSource.contains("public type Windows_Win32_System_Com_IDLFLAGS = UInt16"), true)
    @Expect(regclsSource.contains("public type Windows_Win32_System_Com_REGCLS = Int32"), true)
    @Expect(stgmSource.contains("public type Windows_Win32_System_Com_STGM = UInt32"), true)
    @Expect(idlSource.contains("public struct Windows_Win32_System_Com_IDLFLAGS"), false)
    @Expect(regclsSource.contains("public struct Windows_Win32_System_Com_REGCLS"), false)
    @Expect(stgmSource.contains("public struct Windows_Win32_System_Com_STGM"), false)
    @Expect(idlSource.contains("public let Windows_Win32_System_Com_IDLFLAGS_IDLFLAG_FRETVAL: Windows_Win32_System_Com_IDLFLAGS = 8"), true)
    @Expect(regclsSource.contains("public let Windows_Win32_System_Com_REGCLS_REGCLS_MULTIPLEUSE: Windows_Win32_System_Com_REGCLS = 1"), true)
    @Expect(stgmSource.contains("public let Windows_Win32_System_Com_STGM_STGM_SIMPLE: Windows_Win32_System_Com_STGM = 134217728"), true)
    @Expect(idlSource.contains("Windows_Win32_System_Com_IDLFLAGS(8)"), false)
    @Expect(stgmSource.contains("Windows_Win32_System_Com_STGM(134217728)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_STGM"), true)
    @Expect(boxSource.contains("public var IdlFlags: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var ClassRegistration: Int32 = 0"), true)
    @Expect(boxSource.contains("public var StorageMode: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var IdlPointer: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(boxSource.contains("public var RegistrationPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var StoragePointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var Other: UInt32 = 0"), true)
    @Expect(unionSource.contains("public mut prop IdlFlags: UInt16"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt16(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ClassRegistration: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop StorageMode: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop StoragePointer: CPointer<UInt32>"), true)
    @Expect(interfaceSource.contains("func Set(idlFlags: UInt16, classRegistration: Int32, storageMode: UInt32): Int32"), true)
    @Expect(interfaceSource.contains("func GetIdlFlags(idlFlags: CPointer<UInt16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetStorageMode(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_IDLFLAGS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_REGCLS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_STGM"), false)
}

@Test
func testWin32ComAdditionalScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.RPCOPT_PROPERTIES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.RPCOPT_SERVER_LOCALITY_VALUES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.RPC_C_AUTHN_LEVEL", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.RPC_C_IMP_LEVEL", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.STATFLAG", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.STGC", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.STGTY", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.STREAM_SEEK", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.TYSPEC", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.URI_CREATE_FLAGS", "UInt32")

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
          "Namespace": "Windows.Win32.System.Com",
          "Name": "RPC_C_AUTHN_LEVEL",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "RPC_C_AUTHN_LEVEL_PKT_PRIVACY", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "RPC_C_AUTHN_LEVEL"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 6}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "STATFLAG",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "STATFLAG_NONAME", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STATFLAG"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "URI_CREATE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Uri_CREATE_ALLOW_RELATIVE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "URI_CREATE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
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
          "Name": "STATFLAG",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "STATFLAG"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 2}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComMore",
          "Name": "ComMoreScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "AuthnLevel", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "RPC_C_AUTHN_LEVEL"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "StatFlag", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STATFLAG"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "UriFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "URI_CREATE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "AuthnPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "RPC_C_AUTHN_LEVEL"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "StatPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STATFLAG"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "UriPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "URI_CREATE_FLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "STATFLAG"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComMore",
          "Name": "ComMoreScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "AuthnLevel", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "RPC_C_AUTHN_LEVEL"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "StatFlag", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STATFLAG"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "UriFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "URI_CREATE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "UriPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "URI_CREATE_FLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComMore",
          "Name": "IComMoreScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 610839776},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4660},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 22136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 16},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 50},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 84},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 118},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 152},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 186},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 220},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 254}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "RPC_C_AUTHN_LEVEL"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STATFLAG"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "URI_CREATE_FLAGS"}
                ],
                "RequiredParameterCount": 3,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "authnLevel", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "statFlag", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "uriFlags", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetStatFlag",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "STATFLAG"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "statFlag", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetUriFlags",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "URI_CREATE_FLAGS"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var authnSource = ""
    var statSource = ""
    var uriSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Com.RPC_C_AUTHN_LEVEL") {
            authnSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.STATFLAG") {
            statSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.URI_CREATE_FLAGS") {
            uriSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.STATFLAG") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComMore.ComMoreScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComMore.ComMoreScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComMore.IComMoreScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(authnSource.contains("public type Windows_Win32_System_Com_RPC_C_AUTHN_LEVEL = UInt32"), true)
    @Expect(statSource.contains("public type Windows_Win32_System_Com_STATFLAG = Int32"), true)
    @Expect(uriSource.contains("public type Windows_Win32_System_Com_URI_CREATE_FLAGS = UInt32"), true)
    @Expect(authnSource.contains("public struct Windows_Win32_System_Com_RPC_C_AUTHN_LEVEL"), false)
    @Expect(statSource.contains("public struct Windows_Win32_System_Com_STATFLAG"), false)
    @Expect(uriSource.contains("public struct Windows_Win32_System_Com_URI_CREATE_FLAGS"), false)
    @Expect(authnSource.contains("public let Windows_Win32_System_Com_RPC_C_AUTHN_LEVEL_RPC_C_AUTHN_LEVEL_PKT_PRIVACY: Windows_Win32_System_Com_RPC_C_AUTHN_LEVEL = 6"), true)
    @Expect(statSource.contains("public let Windows_Win32_System_Com_STATFLAG_STATFLAG_NONAME: Windows_Win32_System_Com_STATFLAG = 1"), true)
    @Expect(uriSource.contains("public let Windows_Win32_System_Com_URI_CREATE_FLAGS_Uri_CREATE_ALLOW_RELATIVE: Windows_Win32_System_Com_URI_CREATE_FLAGS = 1"), true)
    @Expect(authnSource.contains("Windows_Win32_System_Com_RPC_C_AUTHN_LEVEL(6)"), false)
    @Expect(statSource.contains("Windows_Win32_System_Com_STATFLAG(1)"), false)
    @Expect(uriSource.contains("Windows_Win32_System_Com_URI_CREATE_FLAGS(1)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_STATFLAG"), true)
    @Expect(boxSource.contains("public var AuthnLevel: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var StatFlag: Int32 = 0"), true)
    @Expect(boxSource.contains("public var UriFlags: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var AuthnPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var StatPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var UriPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var Other: Int32 = 0"), true)
    @Expect(unionSource.contains("public mut prop AuthnLevel: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop StatFlag: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop UriFlags: UInt32"), true)
    @Expect(unionSource.contains("public mut prop UriPointer: CPointer<UInt32>"), true)
    @Expect(interfaceSource.contains("func Set(authnLevel: UInt32, statFlag: Int32, uriFlags: UInt32): Int32"), true)
    @Expect(interfaceSource.contains("func GetStatFlag(statFlag: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("func GetUriFlags(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_RPC_C_AUTHN_LEVEL"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_STATFLAG"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_URI_CREATE_FLAGS"), false)
}

@Test
func testWin32ComRemainingScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.MKRREDUCE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.MKSYS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.PENDINGMSG", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.PENDINGTYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.SERVERCALL", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.ShutdownType", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.SYSKIND", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.THDTYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.TYMED", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.TYPEKIND", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.Uri_PROPERTY", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.VARFLAGS", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.VARKIND", "Int32")

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
          "Namespace": "Windows.Win32.System.Com",
          "Name": "TYPEKIND",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "TKIND_INTERFACE", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYPEKIND"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 3}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "VARFLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "VARFLAG_FREADONLY", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "VARFLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "TYMED",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "TYMED_HGLOBAL", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYMED"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
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
          "Name": "TYPEKIND",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "TYPEKIND"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 9}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComRest",
          "Name": "ComRestScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "TypeKind", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYPEKIND"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "VarFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "VARFLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Tymed", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYMED"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "TypeKindPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYPEKIND"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "VarFlagsPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "VARFLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "TymedPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYMED"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "TYPEKIND"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComRest",
          "Name": "ComRestScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "TypeKind", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYPEKIND"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "VarFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "VARFLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Tymed", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYMED"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "VarFlagsPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "VARFLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComRest",
          "Name": "IComRestScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 267242409},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4369},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 8738},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 51},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 68},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYPEKIND"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "VARFLAGS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYMED"}
                ],
                "RequiredParameterCount": 3,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "typeKind", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "varFlags", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "tymed", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetVarFlags",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "VARFLAGS"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "varFlags", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetTypeKind",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "TYPEKIND"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var typeKindSource = ""
    var varFlagsSource = ""
    var tymedSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Com.TYPEKIND") {
            typeKindSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.VARFLAGS") {
            varFlagsSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.TYMED") {
            tymedSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.TYPEKIND") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComRest.ComRestScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComRest.ComRestScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComRest.IComRestScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(typeKindSource.contains("public type Windows_Win32_System_Com_TYPEKIND = Int32"), true)
    @Expect(varFlagsSource.contains("public type Windows_Win32_System_Com_VARFLAGS = UInt16"), true)
    @Expect(tymedSource.contains("public type Windows_Win32_System_Com_TYMED = Int32"), true)
    @Expect(typeKindSource.contains("public struct Windows_Win32_System_Com_TYPEKIND"), false)
    @Expect(varFlagsSource.contains("public struct Windows_Win32_System_Com_VARFLAGS"), false)
    @Expect(tymedSource.contains("public struct Windows_Win32_System_Com_TYMED"), false)
    @Expect(typeKindSource.contains("public let Windows_Win32_System_Com_TYPEKIND_TKIND_INTERFACE: Windows_Win32_System_Com_TYPEKIND = 3"), true)
    @Expect(varFlagsSource.contains("public let Windows_Win32_System_Com_VARFLAGS_VARFLAG_FREADONLY: Windows_Win32_System_Com_VARFLAGS = 1"), true)
    @Expect(tymedSource.contains("public let Windows_Win32_System_Com_TYMED_TYMED_HGLOBAL: Windows_Win32_System_Com_TYMED = 1"), true)
    @Expect(typeKindSource.contains("Windows_Win32_System_Com_TYPEKIND(3)"), false)
    @Expect(varFlagsSource.contains("Windows_Win32_System_Com_VARFLAGS(1)"), false)
    @Expect(tymedSource.contains("Windows_Win32_System_Com_TYMED(1)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_TYPEKIND"), true)
    @Expect(boxSource.contains("public var TypeKind: Int32 = 0"), true)
    @Expect(boxSource.contains("public var VarFlags: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var Tymed: Int32 = 0"), true)
    @Expect(boxSource.contains("public var TypeKindPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var VarFlagsPointer: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(boxSource.contains("public var TymedPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var Other: Int32 = 0"), true)
    @Expect(unionSource.contains("public mut prop TypeKind: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop VarFlags: UInt16"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt16(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Tymed: Int32"), true)
    @Expect(unionSource.contains("public mut prop VarFlagsPointer: CPointer<UInt16>"), true)
    @Expect(interfaceSource.contains("func Set(typeKind: Int32, varFlags: UInt16, tymed: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func GetVarFlags(varFlags: CPointer<UInt16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetTypeKind(result: CPointer<Int32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_TYPEKIND"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_VARFLAGS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_TYMED"), false)
}

@Test
func testWin32ComSymbols2ScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.ADVANCED_FEATURE_FLAGS", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.DISPATCH_FLAGS", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.DVASPECT", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.COINITBASE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.CLSCTX", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.EXTCONN", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.EOLE_AUTHENTICATION_CAPABILITIES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.GLOBALOPT_PROPERTIES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.GLOBALOPT_EH_VALUES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.GLOBALOPT_RPCTP_VALUES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.GLOBALOPT_RO_FLAGS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.GLOBALOPT_UNMARSHALING_POLICY_VALUES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.DCOM_CALL_STATE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.APTTYPEQUALIFIER", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.APTTYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.CO_MARSHALING_CONTEXT_ATTRIBUTES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.BIND_FLAGS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.ADVF", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.DATADIR", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.CALLTYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.ApplicationType", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.COINIT", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.COMSD", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.COWAIT_FLAGS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.CWMO_FLAGS", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.BINDINFOF", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.CALLCONV", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.FUNCKIND", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.FUNCFLAGS", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.Com.DESCKIND", "Int32")

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
          "Namespace": "Windows.Win32.System.Com",
          "Name": "ADVANCED_FEATURE_FLAGS",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "FADF_AUTO", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "ADVANCED_FEATURE_FLAGS"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "CLSCTX",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "CLSCTX_LOCAL_SERVER", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "CLSCTX"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 4}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.Com",
          "Name": "APTTYPE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "APTTYPE_CURRENT", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "APTTYPE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": -1}}
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
          "Name": "CLSCTX",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "CLSCTX"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 32}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComSymbols2",
          "Name": "ComSymbols2ScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "FeatureFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "ADVANCED_FEATURE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ClassContext", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "CLSCTX"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ApartmentType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "APTTYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "FeaturePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "ADVANCED_FEATURE_FLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ContextPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "CLSCTX"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ApartmentPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "APTTYPE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "CLSCTX"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComSymbols2",
          "Name": "ComSymbols2ScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "FeatureFlags", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "ADVANCED_FEATURE_FLAGS"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ClassContext", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "CLSCTX"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "ApartmentType", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "APTTYPE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "FeaturePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "ADVANCED_FEATURE_FLAGS"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.ComSymbols2",
          "Name": "IComSymbols2Scalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1432778632},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 43690},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 48059},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 238},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 1},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 2},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 3},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 4},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 5}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "ADVANCED_FEATURE_FLAGS"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "CLSCTX"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "APTTYPE"}
                ],
                "RequiredParameterCount": 3,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "featureFlags", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "classContext", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "apartmentType", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetFeatureFlags",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "ADVANCED_FEATURE_FLAGS"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "featureFlags", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetClassContext",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.Com", "Name": "CLSCTX"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var featureSource = ""
    var clsctxSource = ""
    var apttypeSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.Com.ADVANCED_FEATURE_FLAGS") {
            featureSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.CLSCTX") {
            clsctxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.Com.APTTYPE") {
            apttypeSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.CLSCTX") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComSymbols2.ComSymbols2ScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComSymbols2.ComSymbols2ScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.ComSymbols2.IComSymbols2Scalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(featureSource.contains("public type Windows_Win32_System_Com_ADVANCED_FEATURE_FLAGS = UInt16"), true)
    @Expect(clsctxSource.contains("public type Windows_Win32_System_Com_CLSCTX = UInt32"), true)
    @Expect(apttypeSource.contains("public type Windows_Win32_System_Com_APTTYPE = Int32"), true)
    @Expect(featureSource.contains("public struct Windows_Win32_System_Com_ADVANCED_FEATURE_FLAGS"), false)
    @Expect(clsctxSource.contains("public struct Windows_Win32_System_Com_CLSCTX"), false)
    @Expect(apttypeSource.contains("public struct Windows_Win32_System_Com_APTTYPE"), false)
    @Expect(featureSource.contains("public let Windows_Win32_System_Com_ADVANCED_FEATURE_FLAGS_FADF_AUTO: Windows_Win32_System_Com_ADVANCED_FEATURE_FLAGS = 1"), true)
    @Expect(clsctxSource.contains("public let Windows_Win32_System_Com_CLSCTX_CLSCTX_LOCAL_SERVER: Windows_Win32_System_Com_CLSCTX = 4"), true)
    @Expect(apttypeSource.contains("public let Windows_Win32_System_Com_APTTYPE_APTTYPE_CURRENT: Windows_Win32_System_Com_APTTYPE = -1"), true)
    @Expect(featureSource.contains("Windows_Win32_System_Com_ADVANCED_FEATURE_FLAGS(1)"), false)
    @Expect(clsctxSource.contains("Windows_Win32_System_Com_CLSCTX(4)"), false)
    @Expect(apttypeSource.contains("Windows_Win32_System_Com_APTTYPE(-1)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_CLSCTX"), true)
    @Expect(boxSource.contains("public var FeatureFlags: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var ClassContext: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var ApartmentType: Int32 = 0"), true)
    @Expect(boxSource.contains("public var FeaturePointer: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(boxSource.contains("public var ContextPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var ApartmentPointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var Other: UInt32 = 0"), true)
    @Expect(unionSource.contains("public mut prop FeatureFlags: UInt16"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt16(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ClassContext: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop ApartmentType: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop FeaturePointer: CPointer<UInt16>"), true)
    @Expect(interfaceSource.contains("func Set(featureFlags: UInt16, classContext: UInt32, apartmentType: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func GetFeatureFlags(featureFlags: CPointer<UInt16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetClassContext(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_ADVANCED_FEATURE_FLAGS"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_CLSCTX"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_Com_APTTYPE"), false)
}

@Test
func testWin32SystemInformationScalarAbiContextsUsePrimitiveAliasesAndConstants() {
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.COMPUTER_NAME_FORMAT", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.CPU_SET_INFORMATION_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.DEP_SYSTEM_POLICY_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.DEVELOPER_DRIVE_ENABLEMENT_STATE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.DEVICEFAMILYDEVICEFORM", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.DEVICEFAMILYINFOENUM", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.FIRMWARE_TABLE_PROVIDER", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.FIRMWARE_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.IMAGE_FILE_MACHINE", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.LOGICAL_PROCESSOR_RELATIONSHIP", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.OS_DEPLOYEMENT_STATE_VALUES", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.OS_PRODUCT_TYPE", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.PROCESSOR_ARCHITECTURE", "UInt16")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.PROCESSOR_CACHE_TYPE", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.RTL_SYSTEM_GLOBAL_DATA_ID", "Int32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.USER_CET_ENVIRONMENT", "UInt32")
    cliTestExpectWin32ScalarRawAbi("Windows.Win32.System.SystemInformation.VER_FLAGS", "UInt32")

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
          "Namespace": "Windows.Win32.System.SystemInformation",
          "Name": "COMPUTER_NAME_FORMAT",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ComputerNameMax", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "COMPUTER_NAME_FORMAT"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 8}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.SystemInformation",
          "Name": "FIRMWARE_TABLE_PROVIDER",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "RSMB", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "FIRMWARE_TABLE_PROVIDER"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1381190978}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.SystemInformation",
          "Name": "IMAGE_FILE_MACHINE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt16"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "IMAGE_FILE_MACHINE_ARM64", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "IMAGE_FILE_MACHINE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 43620}}
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
          "Name": "IMAGE_FILE_MACHINE",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "IMAGE_FILE_MACHINE"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.SystemInfo",
          "Name": "SystemInfoScalarBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "NameFormat", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "COMPUTER_NAME_FORMAT"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "FirmwareProvider", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "FIRMWARE_TABLE_PROVIDER"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Machine", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "IMAGE_FILE_MACHINE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "NamePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "COMPUTER_NAME_FORMAT"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ProviderPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "FIRMWARE_TABLE_PROVIDER"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "MachinePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "IMAGE_FILE_MACHINE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "IMAGE_FILE_MACHINE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.SystemInfo",
          "Name": "SystemInfoScalarUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "NameFormat", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "COMPUTER_NAME_FORMAT"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "FirmwareProvider", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "FIRMWARE_TABLE_PROVIDER"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "Machine", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "IMAGE_FILE_MACHINE"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "MachinePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "IMAGE_FILE_MACHINE"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Tiny.SystemInfo",
          "Name": "ISystemInfoScalars",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2004318071},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 34952},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 39321},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 238},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 255},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 17},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 34}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "COMPUTER_NAME_FORMAT"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "FIRMWARE_TABLE_PROVIDER"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "IMAGE_FILE_MACHINE"}
                ],
                "RequiredParameterCount": 3,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "nameFormat", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "firmwareProvider", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "machine", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetMachine",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "IMAGE_FILE_MACHINE"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "machine", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetFirmwareProvider",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.System.SystemInformation", "Name": "FIRMWARE_TABLE_PROVIDER"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
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
    var nameFormatSource = ""
    var firmwareProviderSource = ""
    var machineSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.System.SystemInformation.COMPUTER_NAME_FORMAT") {
            nameFormatSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.SystemInformation.FIRMWARE_TABLE_PROVIDER") {
            firmwareProviderSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.SystemInformation.IMAGE_FILE_MACHINE") {
            machineSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.IMAGE_FILE_MACHINE") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.SystemInfo.SystemInfoScalarBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.SystemInfo.SystemInfoScalarUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.SystemInfo.ISystemInfoScalars") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(nameFormatSource.contains("public type Windows_Win32_System_SystemInformation_COMPUTER_NAME_FORMAT = Int32"), true)
    @Expect(firmwareProviderSource.contains("public type Windows_Win32_System_SystemInformation_FIRMWARE_TABLE_PROVIDER = UInt32"), true)
    @Expect(machineSource.contains("public type Windows_Win32_System_SystemInformation_IMAGE_FILE_MACHINE = UInt16"), true)
    @Expect(nameFormatSource.contains("public struct Windows_Win32_System_SystemInformation_COMPUTER_NAME_FORMAT"), false)
    @Expect(machineSource.contains("public struct Windows_Win32_System_SystemInformation_IMAGE_FILE_MACHINE"), false)
    @Expect(nameFormatSource.contains("public let Windows_Win32_System_SystemInformation_COMPUTER_NAME_FORMAT_ComputerNameMax: Windows_Win32_System_SystemInformation_COMPUTER_NAME_FORMAT = 8"), true)
    @Expect(firmwareProviderSource.contains("public let Windows_Win32_System_SystemInformation_FIRMWARE_TABLE_PROVIDER_RSMB: Windows_Win32_System_SystemInformation_FIRMWARE_TABLE_PROVIDER = 1381190978"), true)
    @Expect(machineSource.contains("public let Windows_Win32_System_SystemInformation_IMAGE_FILE_MACHINE_IMAGE_FILE_MACHINE_ARM64: Windows_Win32_System_SystemInformation_IMAGE_FILE_MACHINE = 43620"), true)
    @Expect(firmwareProviderSource.contains("Windows_Win32_System_SystemInformation_FIRMWARE_TABLE_PROVIDER(1381190978)"), false)
    @Expect(machineSource.contains("Windows_Win32_System_SystemInformation_IMAGE_FILE_MACHINE(43620)"), false)
    @Expect(exampleSource.contains("public struct Example_Native_IMAGE_FILE_MACHINE"), true)
    @Expect(boxSource.contains("public var NameFormat: Int32 = 0"), true)
    @Expect(boxSource.contains("public var FirmwareProvider: UInt32 = 0"), true)
    @Expect(boxSource.contains("public var Machine: UInt16 = 0"), true)
    @Expect(boxSource.contains("public var NamePointer: CPointer<Int32> = CPointer<Int32>()"), true)
    @Expect(boxSource.contains("public var ProviderPointer: CPointer<UInt32> = CPointer<UInt32>()"), true)
    @Expect(boxSource.contains("public var MachinePointer: CPointer<UInt16> = CPointer<UInt16>()"), true)
    @Expect(boxSource.contains("public var Other: UInt32 = 0"), true)
    @Expect(unionSource.contains("public mut prop NameFormat: Int32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop FirmwareProvider: UInt32"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt32(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop Machine: UInt16"), true)
    @Expect(unionSource.contains("windows_polyfill.unionReadUInt16(base, 0)"), true)
    @Expect(unionSource.contains("public mut prop MachinePointer: CPointer<UInt16>"), true)
    @Expect(interfaceSource.contains("func Set(nameFormat: Int32, firmwareProvider: UInt32, machine: UInt16): Int32"), true)
    @Expect(interfaceSource.contains("func GetMachine(machine: CPointer<UInt16>): Int32"), true)
    @Expect(interfaceSource.contains("func GetFirmwareProvider(result: CPointer<UInt32>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_System_SystemInformation_COMPUTER_NAME_FORMAT"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_SystemInformation_IMAGE_FILE_MACHINE"), false)
}

@Test
func testWin32PointerSizedIntegerAbiContextsUseNativeAliases() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "LPARAM",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Type", "Namespace": "System", "Name": "IntPtr"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "LRESULT",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Type", "Namespace": "System", "Name": "IntPtr"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "SHANDLE_PTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Type", "Namespace": "System", "Name": "IntPtr"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "WPARAM",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Type", "Namespace": "System", "Name": "UIntPtr"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.Foundation",
          "Name": "HANDLE_PTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Type", "Namespace": "System", "Name": "UIntPtr"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "LPARAM",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Type", "Namespace": "System", "Name": "IntPtr"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "PointerSizedBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "LParam", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LPARAM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "WParam", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WPARAM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "ResultPointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LRESULT"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "HandlePointer", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HANDLE_PTR"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "LPARAM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "PointerSizedUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {"Name": "LParam", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LPARAM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0},
            {"Name": "WParam", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WPARAM"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null, "Offset": 0}
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
          "Name": "IPointerSized",
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
              "Name": "Set",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LPARAM"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WPARAM"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "lparam", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "wparam", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetResult",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {"ParameterTypes": [], "RequiredParameterCount": 0, "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LRESULT"}},
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetHandlePtr",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HANDLE_PTR"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "value", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
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
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "DispatchMessage",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "DispatchMessage",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "tiny.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LRESULT"},
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LPARAM"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "WPARAM"},
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "LRESULT"}},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HANDLE_PTR"}
                ],
                "RequiredParameterCount": 4
              },
              "Parameters": [
                {"Name": "lparam", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "wparam", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "result", "SequenceNumber": 3, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "handlePtr", "SequenceNumber": 4, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    var lparamSource = ""
    var lresultSource = ""
    var shandleSource = ""
    var wparamSource = ""
    var handlePtrSource = ""
    var exampleSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.LPARAM") {
            lparamSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.LRESULT") {
            lresultSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.SHANDLE_PTR") {
            shandleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.WPARAM") {
            wparamSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.Foundation.HANDLE_PTR") {
            handlePtrSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Example.Native.LPARAM") {
            exampleSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.PointerSizedBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.PointerSizedUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IPointerSized") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }
    let features = ArrayList<String>()
    features.add("Tiny.Foundation")
    let selected = selectSymbols(features, records)
    let helper = cliTestHelperFile(
        commonNativeHelperFiles(selected, "windows_common", recordsByFullName(selected)),
        "src/Tiny/Foundation/native_helpers.cj"
    )

    @Expect(lparamSource.contains("public type Windows_Win32_Foundation_LPARAM = IntNative"), true)
    @Expect(lresultSource.contains("public type Windows_Win32_Foundation_LRESULT = IntNative"), true)
    @Expect(shandleSource.contains("public type Windows_Win32_Foundation_SHANDLE_PTR = IntNative"), true)
    @Expect(wparamSource.contains("public type Windows_Win32_Foundation_WPARAM = UIntNative"), true)
    @Expect(handlePtrSource.contains("public type Windows_Win32_Foundation_HANDLE_PTR = UIntNative"), true)
    @Expect(lparamSource.contains("public struct Windows_Win32_Foundation_LPARAM"), false)
    @Expect(wparamSource.contains("public struct Windows_Win32_Foundation_WPARAM"), false)
    @Expect(exampleSource.contains("public struct Example_Native_LPARAM"), true)
    @Expect(boxSource.contains("public var LParam: IntNative = 0"), true)
    @Expect(boxSource.contains("public var WParam: UIntNative = 0"), true)
    @Expect(boxSource.contains("public var ResultPointer: CPointer<IntNative> = CPointer<IntNative>()"), true)
    @Expect(boxSource.contains("public var HandlePointer: CPointer<UIntNative> = CPointer<UIntNative>()"), true)
    @Expect(boxSource.contains("public var Other: Example_Native_LPARAM = Example_Native_LPARAM()"), true)
    @Expect(unionSource.contains("public mut prop LParam: IntNative"), true)
    @Expect(unionSource.contains("let ptr = CPointer<IntNative>(p)"), true)
    @Expect(unionSource.contains("public mut prop WParam: UIntNative"), true)
    @Expect(unionSource.contains("let ptr = CPointer<UIntNative>(p)"), true)
    @Expect(interfaceSource.contains("func Set(lparam: IntNative, wparam: UIntNative): Int32"), true)
    @Expect(interfaceSource.contains("func GetResult(result: CPointer<IntNative>): Int32"), true)
    @Expect(interfaceSource.contains("func GetHandlePtr(value: CPointer<UIntNative>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_LPARAM"), false)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_WPARAM"), false)
    @Expect(helper.contains("public func DispatchMessage(lparam: IntNative, wparam: UIntNative, result: CPointer<IntNative>, handlePtr: UIntNative): IntNative"), true)
    @Expect(helper.contains("let proc = CFunc<(IntNative, UIntNative, CPointer<IntNative>, UIntNative) -> IntNative>"), true)
    @Expect(helper.contains("return unsafe { proc(lparam, wparam, result, handlePtr) }"), true)
    @Expect(helper.contains(".Value"), false)
}

@Test
func testStringHandleAbiContextsUseRawPointerAliases() {
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
          "Namespace": "Windows.Win32.Foundation",
          "Name": "BSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Windows.Win32.System.WinRT",
          "Name": "HSTRING",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "BSTR",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Value", "Signature": {"Kind": "Primitive", "Name": "UInt32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "StringHandleBox",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "SequentialLayout", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "Bstr", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "HString", "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "HSTRING"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Other", "Signature": {"Kind": "Type", "Namespace": "Example.Native", "Name": "BSTR"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
          "Name": "StringHandleUnion",
          "BaseType": "System.ValueType",
          "IsNested": false,
          "Attributes": ["Public", "ExplicitLayout", "Sealed"],
          "CustomAttributes": [],
          "Layout": {"IsDefault": false, "PackingSize": 0, "Size": 8},
          "Fields": [
            {
              "Name": "Bstr",
              "Signature": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR"},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null,
              "Offset": 0
            },
            {
              "Name": "BstrPointer",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR"}},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null,
              "Offset": 0
            },
            {
              "Name": "HStringPointer",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "HSTRING"}},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null,
              "Offset": 0
            },
            {
              "Name": "OtherPointer",
              "Signature": {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Example.Native", "Name": "BSTR"}},
              "Attributes": ["Public"],
              "CustomAttributes": [],
              "DefaultValue": null,
              "Offset": 0
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
          "Name": "IStringHandleSource",
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
              "Name": "SetHandles",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "HSTRING"}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "bstr", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "hstring", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetBstr",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR"}
              },
              "Parameters": [{"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}],
              "GenericParameters": []
            },
            {
              "Name": "GetHString",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [{"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "HSTRING"}],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [{"Name": "value", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}],
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
    var bstrSource = ""
    var hstringSource = ""
    var boxSource = ""
    var unionSource = ""
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Windows.Win32.Foundation.BSTR") {
            bstrSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Windows.Win32.System.WinRT.HSTRING") {
            hstringSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.StringHandleBox") {
            boxSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.StringHandleUnion") {
            unionSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.IStringHandleSource") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(bstrSource.contains("public type Windows_Win32_Foundation_BSTR = CPointer<Unit>"), true)
    @Expect(hstringSource.contains("public type Windows_Win32_System_WinRT_HSTRING = CPointer<Unit>"), true)
    @Expect(bstrSource.contains("public struct Windows_Win32_Foundation_BSTR"), false)
    @Expect(hstringSource.contains("public struct Windows_Win32_System_WinRT_HSTRING"), false)
    @Expect(boxSource.contains("public var Bstr: CPointer<Unit> = CPointer<Unit>()"), true)
    @Expect(boxSource.contains("public var HString: CPointer<Unit> = CPointer<Unit>()"), true)
    @Expect(boxSource.contains("public var Other: Example_Native_BSTR = Example_Native_BSTR()"), true)
    @Expect(unionSource.contains("public mut prop Bstr: CPointer<Unit>"), true)
    @Expect(unionSource.contains("public mut prop BstrPointer: CPointer<CPointer<Unit>>"), true)
    @Expect(unionSource.contains("public mut prop HStringPointer: CPointer<CPointer<Unit>>"), true)
    @Expect(unionSource.contains("public mut prop OtherPointer: CPointer<Unit>"), true)
    @Expect(interfaceSource.contains("func SetHandles(bstr: CPointer<Unit>, hstring: CPointer<Unit>): Int32"), true)
    @Expect(interfaceSource.contains("func GetBstr(result: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(interfaceSource.contains("func GetHString(value: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(interfaceSource.contains("Windows_Win32_Foundation_BSTR"), false)
    @Expect(interfaceSource.contains("Windows_Win32_System_WinRT_HSTRING"), false)
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
func testWinrtInterfaceRendersInterfaceMacroAndSupportDependencies() {
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

    @Expect(source.contains("@Interface[\"11111111-2222-3333-4455-66778899aabb\", \"Example.Foundation.IWidget\"]"), true)
    @Expect(source.contains("public interface Example_Foundation_IWidget <: IInspectable {"), true)
    @Expect(source.contains("func Ping(): Int32"), true)
    @Expect(source.contains("func CreateInstance(baseInterface: CPointer<Unit>, innerInterface: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(source.contains("func External(value: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(source.contains("func SetExternal(value: CPointer<Unit>): Int32"), true)
    @Expect(source.contains("@C\npublic struct Example_Foundation_IWidgetVtbl"), false)
    @Expect(source.contains("public open class Example_Foundation_IWidget"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_core"), true)
    @Expect(cliTestContainsString(deps.toArray(), "windows_interface"), true)
    @Expect(renderCjpmToml("windows_gen", supportDeps: deps).contains("windows_core = { path = \"../../windows-core\" }"), true)
    @Expect(renderCjpmToml("windows_gen", supportDeps: deps).contains("windows_interface = { path = \"../../windows-interface\" }"), true)

    let outDir = ".generated/interface-macro-import-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeImplFiles(writer, records, "windows_gen", symbolsByName)
    let implChunk = String.fromUtf8(File.readFrom("${outDir}/src/impl/symbols_0.cj"))
    removeIfExists(outDir, recursive: true)
    @Expect(implChunk.contains("import windows_core.*"), false)
    @Expect(implChunk.contains("import windows_interface.*"), false)
    @Expect(implChunk.contains("import windows_interface.macros.*"), false)
    @Expect(implChunk.contains("import windows_core as windows_core"), true)
    @Expect(implChunk.contains("import windows_interface as windows_interface"), true)
    @Expect(implChunk.contains("import windows_interface.IInspectable"), true)
    @Expect(implChunk.contains("import windows_interface.macros.Interface"), true)
}

@Test
func testWinrtClassWithDefaultInterfaceRendersRuntimeWrapper() {
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
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IWidgetExtra",
          "MetadataToken": "0x02000003",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 305419896},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4660},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 22136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 144},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 171},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 205},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 239},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 1},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 35},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 69},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 103}
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
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "WidgetKind",
          "MetadataToken": "0x02000009",
          "BaseType": "System.Enum",
          "IsNested": false,
          "Attributes": ["Public", "Sealed"],
          "CustomAttributes": [],
          "Fields": [
            {"Name": "value__", "Signature": {"Kind": "Primitive", "Name": "Int32"}, "Attributes": ["Public", "SpecialName"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "Primary", "Signature": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "WidgetKind"}, "Attributes": ["Public", "Static", "Literal"], "CustomAttributes": [], "DefaultValue": {"Type": {"Kind": "Primitive", "Name": "Int32"}, "Value": 1}}
          ],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IMap",
          "MetadataToken": "0x02000004",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 572662306},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 13107},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 17476},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [
            {"Name": "K", "SequenceNumber": 0, "Attributes": [], "CustomAttributes": [], "Constraints": []},
            {"Name": "V", "SequenceNumber": 1, "Attributes": [], "CustomAttributes": [], "Constraints": []}
          ],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IVector",
          "MetadataToken": "0x02000005",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 858993459},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 17476},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 21845},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [
            {"Name": "T", "SequenceNumber": 0, "Attributes": [], "CustomAttributes": [], "Constraints": []}
          ],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IWidgetFactory",
          "MetadataToken": "0x02000006",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1145324612},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 21845},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 26214},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 238}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CreateWidget",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "Widget"},
                "Parameters": [
                  {"Kind": "Type", "Namespace": "System", "Name": "String"}
                ]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "Widget"}},
                {"Name": "name", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "get_DisplayName",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"},
                "Parameters": []
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "put_DisplayName",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "Type", "Namespace": "System", "Name": "String"}
                ]
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "SetKind",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "WidgetKind"}
                ]
              },
              "Parameters": [
                {"Name": "kind", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "WidgetKind"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetKind",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "WidgetKind"},
                "Parameters": []
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "WidgetKind"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "CreateGuidArray",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "Object"},
                "Parameters": [
                  {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid"}}
                ]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "Object"}},
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid"}}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetNames",
              "Signature": {
                "ReturnType": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "String"}},
                "Parameters": []
              },
              "Parameters": [
                {"Name": "names", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "String"}}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IWidgetStatics",
          "MetadataToken": "0x02000007",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1431655765},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 26214},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 30583},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 187},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 238},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 255}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "NormalizeName",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"},
                "Parameters": [
                  {"Kind": "Type", "Namespace": "System", "Name": "String"}
                ]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}},
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "Widget",
          "MetadataToken": "0x02000008",
          "BaseType": "System.Object",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "CustomAttributes": [
            {"Type": "Windows.Foundation.Metadata.ActivatableAttribute", "FixedArguments": [], "NamedArguments": []},
            {
              "Type": "Windows.Foundation.Metadata.ActivatableAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Type", "Namespace": "System", "Name": "Type"}, "Value": "Example.Foundation.IWidgetFactory"},
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}
              ],
              "NamedArguments": []
            },
            {
              "Type": "Windows.Foundation.Metadata.StaticAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Type", "Namespace": "System", "Name": "Type"}, "Value": {"Namespace": "Example.Foundation", "Name": "IWidgetStatics"}},
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IWidget"},
              "CustomAttributes": [
                {"Type": "Windows.Foundation.Metadata.DefaultAttribute", "FixedArguments": [], "NamedArguments": []}
              ]
            },
            {
              "Interface": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IWidgetExtra"},
              "CustomAttributes": []
            },
            {
              "Interface": {
                "Kind": "Type",
                "Namespace": "Example.Foundation",
                "Name": "IMap",
                "TypeArguments": [
                  {"Kind": "Type", "Namespace": "System", "Name": "String"},
                  {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IWidget"}
                ]
              },
              "CustomAttributes": []
            },
            {
              "Interface": {
                "Kind": "TypeSpecification",
                "TypeSpecification": {
                  "Signature": {
                    "Kind": "Type",
                    "Namespace": "Example.Foundation",
                    "Name": "IVector",
                    "TypeArguments": [
                      {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IWidgetExtra"}
                    ]
                  },
                  "CustomAttributes": []
                }
              },
              "CustomAttributes": []
            }
          ],
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
    var classSource = ""
    for (record in records) {
        if (record.fullName == "Example.Foundation.Widget") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("public class Example_Foundation_Widget <: windows_interface.InterfaceWrapperBase & windows_interface.ComInterface"), true)
    @Expect(classSource.contains("public static func fromAbiTake(raw: CPointer<Unit>): Example_Foundation_Widget"), true)
    @Expect(classSource.contains("public static func viewOf(raw: CPointer<Unit>): Example_Foundation_Widget"), true)
    @Expect(classSource.contains("public static func iid(): windows_interface.GUID {\n        Example_Foundation_IWidget.iid()\n    }"), true)
    @Expect(classSource.contains("let ancestors = [Example_Foundation_IWidget.iid(), Example_Foundation_IWidgetExtra.iid(), Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>.iid(), Example_Foundation_IVector<Example_Foundation_IWidgetExtra>.iid(), windows_interface.IInspectable.iid(), windows_interface.IUnknown.iid()]"), true)
    @Expect(classSource.contains("windows_interface.InterfaceDescriptor<Example_Foundation_Widget>(\"Widget\", Example_Foundation_IWidget.iid(), ancestors"), true)
    @Expect(classSource.contains("public func defaultInterface(): Example_Foundation_IWidget"), true)
    @Expect(classSource.contains("public func asIWidget(): Example_Foundation_IWidget"), true)
    @Expect(classSource.contains("public func asIWidgetExtra(): Example_Foundation_IWidgetExtra"), true)
    @Expect(classSource.contains("public func asIMap(): Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>"), true)
    @Expect(classSource.contains("query<Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>>(Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>.descriptor())"), true)
    @Expect(classSource.contains("public func asIVector(): Example_Foundation_IVector<Example_Foundation_IWidgetExtra>"), true)
    @Expect(classSource.contains("public static func new(): Example_Foundation_Widget"), true)
    @Expect(classSource.contains("windows_core.factory<Example_Foundation_Widget, windows_core.IGenericFactory>().unwrap()"), true)
    @Expect(classSource.contains("factory__.ActivateInstance<Example_Foundation_Widget>(Example_Foundation_Widget.descriptor()).unwrap()"), true)
    @Expect(classSource.contains("public static func CreateWidget(name: windows_core.HString): Example_Foundation_Widget"), true)
    @Expect(classSource.contains("windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetFactory>().unwrap()"), true)
    @Expect(classSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_core.HString>(name))"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateWidget(__argBorrow0.asRaw(), CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("return Example_Foundation_Widget.fromAbiTakeWinrtHandle(result__)"), true)
    @Expect(classSource.contains("public static func NormalizeName(value: windows_core.HString): windows_core.HString"), true)
    @Expect(classSource.contains("windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetStatics>().unwrap()"), true)
    @Expect(classSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_core.HString>(value))"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.NormalizeName(__argBorrow0.asRaw(), CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("return windows_core.HString.fromAbiTakeWinrtHandle(result__)"), true)
    @Expect(classSource.contains("public static func DisplayName(): windows_core.HString"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.DisplayName(CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("public static func SetDisplayName(value: windows_core.HString): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.SetDisplayName(__argBorrow0.asRaw()) }"), true)
    @Expect(classSource.contains("public static func SetKind(kind: Example_Foundation_WidgetKind): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.SetKind(kind.value) }"), true)
    @Expect(classSource.contains("public static func GetKind(): Example_Foundation_WidgetKind"), true)
    @Expect(classSource.contains("return Example_Foundation_WidgetKind(result__)"), true)
    @Expect(classSource.contains("public static func CreateGuidArray(valuesSize: UInt32, values: CPointer<GUID>, result: CPointer<CPointer<Unit>>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateGuidArray(valuesSize, values, result) }"), true)
    @Expect(classSource.contains("public static func GetNames(namesSize: CPointer<UInt32>, names: CPointer<CPointer<CPointer<Unit>>>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.GetNames(namesSize, names) }"), true)
    @Expect(classSource.contains("public static func runtimeName(): String {\n        \"Example.Foundation.Widget\"\n    }"), true)
    @Expect(classSource.contains("return \"rc(Example.Foundation.Widget;\" + Example_Foundation_IWidget.signature() + \")\""), true)
    @Expect(classSource.contains("windows_interface.RuntimeTypeContract(\"Example.Foundation.Widget\", Example_Foundation_Widget.signature(), Example_Foundation_IWidget.iid())"), true)
    @Expect(classSource.contains("extend Example_Foundation_Widget <: windows_core.HandleWinrtType<Example_Foundation_Widget>"), true)
    @Expect(classSource.contains("public class Example_Foundation_Widget {\n    private let raw: CPointer<Unit>"), false)

    let outDir = ".generated/runtime-class-wrapper-import-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeImplFiles(writer, records, "windows_gen", symbolsByName)
    let implChunk = String.fromUtf8(File.readFrom("${outDir}/src/impl/symbols_0.cj"))
    removeIfExists(outDir, recursive: true)
    @Expect(implChunk.contains("import windows_core as windows_core"), true)
    @Expect(implChunk.contains("import windows_interface as windows_interface"), true)
    @Expect(implChunk.contains("import windows_interface.GUID"), true)

    let exactFeatures = ArrayList<String>()
    exactFeatures.add("Example.Foundation.Widget")
    let selected = selectSymbolsFromRecords(exactFeatures, records)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.WidgetKind"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.IWidgetFactory"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.IWidgetStatics"), true)
}

@Test
func testWinrtMethodProjectionNamesUseSpecialNamesAndOverloadAttributes() {
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
          "Name": "IWidgetOptions",
          "MetadataToken": "0x02000002",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2882400001},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 43690},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 48059},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 204},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 221},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 1},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 2},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 3},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 4},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 5},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 6}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "get_DisplayName",
              "Signature": {"ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"}, "Parameters": []},
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "put_DisplayName",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": [{"Kind": "Type", "Namespace": "System", "Name": "String"}]},
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "add_Changed",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": []},
              "Parameters": [],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "remove_Changed",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": []},
              "Parameters": [],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "Find",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": []},
              "Parameters": [],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "FindByName",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": [{"Kind": "Type", "Namespace": "System", "Name": "String"}]},
              "Parameters": [
                {"Name": "name", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [
                {
                  "Type": "Windows.Foundation.Metadata.OverloadAttribute",
                  "FixedArguments": [
                    {"Type": {"Kind": "Type", "Namespace": "System", "Name": "String"}, "Value": "Find"}
                  ],
                  "NamedArguments": []
                }
              ],
              "GenericParameters": []
            },
            {
              "Name": "FindByKind",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": [{"Kind": "Primitive", "Name": "Int32"}]},
              "Parameters": [
                {"Name": "kind", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "Int32"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [
                {
                  "Type": "Windows.Foundation.Metadata.OverloadAttribute",
                  "FixedArguments": [
                    {"Type": {"Kind": "Type", "Namespace": "System", "Name": "String"}, "Value": "Find"}
                  ],
                  "NamedArguments": []
                }
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
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Example.Foundation.IWidgetOptions") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(interfaceSource.contains("func DisplayName("), true)
    @Expect(interfaceSource.contains("func SetDisplayName(value: CPointer<Unit>): Int32"), true)
    @Expect(interfaceSource.contains("func Changed(): Int32"), true)
    @Expect(interfaceSource.contains("func RemoveChanged(): Int32"), true)
    @Expect(interfaceSource.contains("func Find(): Int32"), true)
    @Expect(interfaceSource.contains("func Find_1(name: CPointer<Unit>): Int32"), true)
    @Expect(interfaceSource.contains("func Find_2(kind: Int32): Int32"), true)
    @Expect(interfaceSource.contains("func DisplayName_1("), false)
    @Expect(interfaceSource.contains("func add_Changed("), false)
    @Expect(interfaceSource.contains("func remove_Changed("), false)
    @Expect(interfaceSource.contains("func FindByName("), false)
    @Expect(interfaceSource.contains("func FindByKind("), false)
}

@Test
func testWinrtMethodProjectionNameDedupUsesExactCollisionsOnly() {
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
          "Name": "IWidgetLookup",
          "MetadataToken": "0x02000002",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 270544960},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4951},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 9320},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 154},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 188},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 222},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 240},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 18},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 52},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 86},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 120}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Find_1",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": []},
              "Parameters": [],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "FindByName",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Void"}, "Parameters": [{"Kind": "Type", "Namespace": "System", "Name": "String"}]},
              "Parameters": [
                {"Name": "name", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [
                {
                  "Type": "Windows.Foundation.Metadata.OverloadAttribute",
                  "FixedArguments": [
                    {"Type": {"Kind": "Type", "Namespace": "System", "Name": "String"}, "Value": "Find"}
                  ],
                  "NamedArguments": []
                }
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
    var interfaceSource = ""
    for (record in records) {
        if (record.fullName == "Example.Foundation.IWidgetLookup") {
            interfaceSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(interfaceSource.contains("func Find_1(): Int32"), true)
    @Expect(interfaceSource.contains("func Find(name: CPointer<Unit>): Int32"), true)
    @Expect(interfaceSource.contains("func Find_1(name: CPointer<Unit>): Int32"), false)
}

@Test
func testWinrtComposableAttributeRendersRuntimeFactoryMethod() {
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
          "Name": "IComposableWidget",
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
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IComposableWidgetFactory",
          "MetadataToken": "0x02000003",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 305419896},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4660},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 22136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 144},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 171},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 205},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 239},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 1},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 35},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 69},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 103}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CreateInstance",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "ComposableWidget"},
                "Parameters": [
                  {"Kind": "Type", "Namespace": "System", "Name": "Object"},
                  {"Kind": "Type", "Namespace": "System", "Name": "Object"}
                ]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "ComposableWidget"}},
                {"Name": "baseInterface", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "Object"}},
                {"Name": "innerInterface", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "Object"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "ComposableWidget",
          "MetadataToken": "0x02000004",
          "BaseType": "System.Object",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.ComposableAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Type", "Namespace": "System", "Name": "Type"}, "Value": "Example.Foundation.IComposableWidgetFactory"},
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IComposableWidget"},
              "CustomAttributes": [
                {"Type": "Windows.Foundation.Metadata.DefaultAttribute", "FixedArguments": [], "NamedArguments": []}
              ]
            }
          ],
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
    var classSource = ""
    for (record in records) {
        if (record.fullName == "Example.Foundation.ComposableWidget") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("windows_core.factory<Example_Foundation_ComposableWidget, Example_Foundation_IComposableWidgetFactory>().unwrap()"), true)
    @Expect(classSource.contains("public static func CreateInstance(baseInterface: CPointer<Unit>, innerInterface: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateInstance(baseInterface, innerInterface, result) }"), true)

    let exactFeatures = ArrayList<String>()
    exactFeatures.add("Example.Foundation.ComposableWidget")
    let selected = selectSymbolsFromRecords(exactFeatures, records)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.IComposableWidgetFactory"), true)
}

@Test
func testWinrtStaticOnlyClassRendersRuntimeFactoryMethods() {
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
          "Name": "IStaticWidgetStatics",
          "MetadataToken": "0x02000002",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 2863311530},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4369},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 8738},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 51},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 68},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 85},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 102},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 119},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 153},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 170}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "BuildName",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"},
                "Parameters": [
                  {"Kind": "Type", "Namespace": "System", "Name": "String"}
                ]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}},
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "StaticWidget",
          "MetadataToken": "0x02000003",
          "BaseType": "System.Object",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.StaticAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Type", "Namespace": "System", "Name": "Type"}, "Value": "Example.Foundation.IStaticWidgetStatics"},
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 1}
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
    let symbolsByName = cliTestRecordsByName(records)
    var classSource = ""
    for (record in records) {
        if (record.fullName == "Example.Foundation.StaticWidget") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("public struct Example_Foundation_StaticWidget <: windows_interface.RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeName & windows_core.RuntimeType"), true)
    @Expect(classSource.contains("public static func BuildName(value: windows_core.HString): windows_core.HString"), true)
    @Expect(classSource.contains("windows_core.factory<Example_Foundation_StaticWidget, Example_Foundation_IStaticWidgetStatics>().unwrap()"), true)
    @Expect(classSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_core.HString>(value))"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.BuildName(__argBorrow0.asRaw(), CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("return windows_core.HString.fromAbiTakeWinrtHandle(result__)"), true)
    @Expect(classSource.contains("public static func runtimeName(): String {\n        \"Example.Foundation.StaticWidget\"\n    }"), true)
    @Expect(classSource.contains("return \"rc(Example.Foundation.StaticWidget)\""), true)
    @Expect(classSource.contains("windows_interface.RuntimeTypeContract(\"Example.Foundation.StaticWidget\", Example_Foundation_StaticWidget.signature())"), true)
    @Expect(classSource.contains("public class Example_Foundation_StaticWidget {\n    private let raw: CPointer<Unit>"), false)

    let exactFeatures = ArrayList<String>()
    exactFeatures.add("Example.Foundation.StaticWidget")
    let selected = selectSymbolsFromRecords(exactFeatures, records)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.IStaticWidgetStatics"), true)
}

@Test
func testWinrtInterfaceRequiredInterfacesDoNotBecomeDirectBases() {
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
          "Name": "IBase",
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
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "IDerived",
          "MetadataToken": "0x02000003",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "AutoLayout", "Interface", "Abstract", "WindowsRuntime"],
          "CustomAttributes": [
            {
              "Type": "Windows.Foundation.Metadata.GuidAttribute",
              "FixedArguments": [
                {"Type": {"Kind": "Primitive", "Name": "UInt32"}, "Value": 305419896},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 4660},
                {"Type": {"Kind": "Primitive", "Name": "UInt16"}, "Value": 22136},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 144},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 171},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 205},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 239},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 1},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 35},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 69},
                {"Type": {"Kind": "Primitive", "Name": "Byte"}, "Value": 103}
              ],
              "NamedArguments": []
            }
          ],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IBase"},
              "CustomAttributes": []
            }
          ],
          "Methods": [
            {
              "Name": "DerivedOnly",
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
    var derivedSource = ""
    for (record in records) {
        if (record.fullName == "Example.Foundation.IDerived") {
            derivedSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(derivedSource.contains("public interface Example_Foundation_IDerived <: IInspectable {"), true)
    @Expect(derivedSource.contains("public interface Example_Foundation_IDerived <: Example_Foundation_IBase {"), false)
    @Expect(derivedSource.contains("func DerivedOnly(): Int32"), true)
}

@Test
func testWinrtInterfaceArrayParametersRenderSizePointerPairs() {
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
          "Name": "IArrayWidget",
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
              "Name": "SetItems",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "Int32"}}
                ],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetItems",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "Int32"}}
              },
              "Parameters": [
                {"Name": "items", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetItemsByRef",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {
                    "Kind": "ByReference",
                    "Type": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "Int32"}}
                  }
                ],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "items", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "SetGuids",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid"}}
                ],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetGuids",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [],
                "RequiredParameterCount": 0,
                "ReturnType": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid"}}
              },
              "Parameters": [
                {"Name": "guids", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}
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

    @Expect(source.contains("func SetItems(valuesSize: UInt32, values: CPointer<Int32>): Int32"), true)
    @Expect(source.contains("func GetItems(itemsSize: CPointer<UInt32>, items: CPointer<CPointer<Int32>>): Int32"), true)
    @Expect(source.contains("func GetItemsByRef(itemsSize: CPointer<UInt32>, items: CPointer<CPointer<Int32>>): Int32"), true)
    @Expect(source.contains("func SetGuids(valuesSize: UInt32, values: CPointer<GUID>): Int32"), true)
    @Expect(source.contains("func GetGuids(guidsSize: CPointer<UInt32>, guids: CPointer<CPointer<GUID>>): Int32"), true)
    @Expect(source.contains("func SetItems(values: CPointer<Unit>): Int32"), false)
    @Expect(source.contains("func GetItems(items: CPointer<CPointer<Unit>>): Int32"), false)
    @Expect(source.contains("func GetItemsByRef(items: CPointer<CPointer<Unit>>): Int32"), false)
    @Expect(source.contains("func SetGuids(valuesSize: UInt32, values: CPointer<Unit>): Int32"), false)
    @Expect(source.contains("func GetGuids(guidsSize: CPointer<UInt32>, guids: CPointer<CPointer<Unit>>): Int32"), false)

    let outDir = ".generated/interface-array-guid-import-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeImplFiles(writer, records, "windows_gen", symbolsByName)
    let implChunk = String.fromUtf8(File.readFrom("${outDir}/src/impl/symbols_0.cj"))
    removeIfExists(outDir, recursive: true)
    @Expect(implChunk.contains("import windows_interface.GUID"), true)
}

@Test
func testWinrtDelegateParametersRenderAsComPointers() {
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
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
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
    var delegateSource = ""
    var source = ""
    for (record in records) {
        if (record.fullName == "Tiny.Foundation.TypedEventHandler") {
            delegateSource = renderSymbolImpl(record, symbolsByName)
        }
        if (record.fullName == "Tiny.Foundation.ICommitBatch") {
            source = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(delegateSource.contains("public type Tiny_Foundation_TypedEventHandler = CFunc"), false)
    @Expect(delegateSource.contains("public class Tiny_Foundation_TypedEventHandler"), true)
    @Expect(source.contains("func add_Completed(handler: CPointer<Unit>, result: CPointer<Tiny_Foundation_EventRegistrationToken>): Int32"), true)
    @Expect(source.contains("func add_Completed(handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>"), false)
    @Expect(source.contains("func add_Completed(handler: CPointer<Unit>, sender: CPointer<Unit>, args: CPointer<Unit>, result: CPointer<Tiny_Foundation_EventRegistrationToken>): Int32"), false)
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
