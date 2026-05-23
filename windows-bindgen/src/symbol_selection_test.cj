package windows_bindgen

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

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
func testSelectSymbolsFiltersByShortNameAndExpandsDependencies() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", ["Example.Shared.Size"]))
    records.add(SymbolRecord("Example.Controls.Widget", "Example.Controls", "Widget", "Example_Controls_Widget", []))
    records.add(SymbolRecord("Example.Controls.Button", "Example.Controls", "Button", "Example_Controls_Button", []))
    records.add(SymbolRecord("Example.Shared.Size", "Example.Shared", "Size", "Example_Shared_Size", []))
    let filters = ArrayList<String>()
    filters.add("Widget")

    let selected = selectSymbolsFromRecords(filters, records)

    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Widget"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Controls.Widget"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Shared.Size"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Controls.Button"), false)
}

@Test
func testSelectSymbolsFiltersNamespacePrefixWildcardAndExclude() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", []))
    records.add(SymbolRecord("Example.Foundation.Controls.Button", "Example.Foundation.Controls", "Button", "Example_Foundation_Controls_Button", []))
    records.add(SymbolRecord("Example.Foundation.Controls.ButtonHelper", "Example.Foundation.Controls", "ButtonHelper", "Example_Foundation_Controls_ButtonHelper", []))
    records.add(SymbolRecord("Example.Other.Button", "Example.Other", "Button", "Example_Other_Button", []))
    let filters = ArrayList<String>()
    filters.add("Example.Foundation")
    filters.add("!*Helper")

    let selected = selectSymbolsFromRecords(filters, records)

    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Widget"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Controls.Button"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Controls.ButtonHelper"), false)
    @Expect(cliTestContainsSymbol(selected, "Example.Other.Button"), false)
}

@Test
func testSelectSymbolsExplicitExcludePreventsDependencyReentry() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Controls.Button", "Example.Controls", "Button", "Example_Controls_Button", ["Example.Foundation.Widget"]))
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", []))
    let filters = ArrayList<String>()
    filters.add("Button")
    filters.add("!Example.Foundation.Widget")

    let selected = selectSymbolsFromRecords(filters, records)

    @Expect(cliTestContainsSymbol(selected, "Example.Controls.Button"), true)
    @Expect(cliTestContainsSymbol(selected, "Example.Foundation.Widget"), false)
}

@Test
func testFeatureSelectionDoesNotPullWin32SubnamespaceMsxmlDependencies() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Windows.Win32.Foundation.HANDLE", "Windows.Win32.Foundation", "HANDLE", "Windows_Win32_Foundation_HANDLE", []))
    records.add(SymbolRecord("Windows.Win32.Foundation.Metadata.GuidAttribute", "Windows.Win32.Foundation.Metadata", "GuidAttribute", "Windows_Win32_Foundation_Metadata_GuidAttribute", []))
    records.add(SymbolRecord("Windows.Win32.Security.ACL", "Windows.Win32.Security", "ACL", "Windows_Win32_Security_ACL", []))
    records.add(SymbolRecord("Windows.Win32.Security.ExtensibleAuthenticationProtocol.EapXml", "Windows.Win32.Security.ExtensibleAuthenticationProtocol", "EapXml", "Windows_Win32_Security_ExtensibleAuthenticationProtocol_EapXml", ["Windows.Win32.Data.Xml.MsXml.IXMLDOMNode"]))
    records.add(SymbolRecord("Windows.Win32.System.Com.IUnknown", "Windows.Win32.System.Com", "IUnknown", "Windows_Win32_System_Com_IUnknown", []))
    records.add(SymbolRecord("Windows.Win32.System.Com.Urlmon.XmlConsumer", "Windows.Win32.System.Com.Urlmon", "XmlConsumer", "Windows_Win32_System_Com_Urlmon_XmlConsumer", ["Windows.Win32.Data.Xml.MsXml.IXMLElement"]))
    records.add(SymbolRecord("Windows.Win32.Data.Xml.MsXml.IXMLDOMNode", "Windows.Win32.Data.Xml.MsXml", "IXMLDOMNode", "Windows_Win32_Data_Xml_MsXml_IXMLDOMNode", []))
    records.add(SymbolRecord("Windows.Win32.Data.Xml.MsXml.IXMLElement", "Windows.Win32.Data.Xml.MsXml", "IXMLElement", "Windows_Win32_Data_Xml_MsXml_IXMLElement", []))

    let selected = BindgenBuilder()
        .feature("Windows.Win32.Foundation")
        .feature("Windows.Win32.Security")
        .feature("Windows.Win32.System.Com")
        .selectedSymbols(records)

    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.Foundation.HANDLE"), true)
    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.Security.ACL"), true)
    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.System.Com.IUnknown"), true)
    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.Foundation.Metadata.GuidAttribute"), false)
    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.Security.ExtensibleAuthenticationProtocol.EapXml"), false)
    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.System.Com.Urlmon.XmlConsumer"), false)
    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.Data.Xml.MsXml.IXMLDOMNode"), false)
    @Expect(cliTestContainsSymbol(selected, "Windows.Win32.Data.Xml.MsXml.IXMLElement"), false)
}

@Test
func testGenerateUsesExactFeatureSelectionForWin32MsxmlDrift() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Windows.Win32.Foundation.HANDLE", "Windows.Win32.Foundation", "HANDLE", "Windows_Win32_Foundation_HANDLE", []))
    records.add(SymbolRecord("Windows.Win32.Foundation.Metadata.GuidAttribute", "Windows.Win32.Foundation.Metadata", "GuidAttribute", "Windows_Win32_Foundation_Metadata_GuidAttribute", []))
    records.add(SymbolRecord("Windows.Win32.Security.ACL", "Windows.Win32.Security", "ACL", "Windows_Win32_Security_ACL", []))
    records.add(SymbolRecord("Windows.Win32.Security.ExtensibleAuthenticationProtocol.EapXml", "Windows.Win32.Security.ExtensibleAuthenticationProtocol", "EapXml", "Windows_Win32_Security_ExtensibleAuthenticationProtocol_EapXml", ["Windows.Win32.Data.Xml.MsXml.IXMLDOMNode"]))
    records.add(SymbolRecord("Windows.Win32.System.Com.IUnknown", "Windows.Win32.System.Com", "IUnknown", "Windows_Win32_System_Com_IUnknown", []))
    records.add(SymbolRecord("Windows.Win32.System.Com.Urlmon.XmlConsumer", "Windows.Win32.System.Com.Urlmon", "XmlConsumer", "Windows_Win32_System_Com_Urlmon_XmlConsumer", ["Windows.Win32.Data.Xml.MsXml.IXMLElement"]))
    records.add(SymbolRecord("Windows.Win32.Data.Xml.MsXml.IXMLDOMNode", "Windows.Win32.Data.Xml.MsXml", "IXMLDOMNode", "Windows_Win32_Data_Xml_MsXml_IXMLDOMNode", []))
    records.add(SymbolRecord("Windows.Win32.Data.Xml.MsXml.IXMLElement", "Windows.Win32.Data.Xml.MsXml", "IXMLElement", "Windows_Win32_Data_Xml_MsXml_IXMLElement", []))
    let outDir = ".generated/feature-msxml-drift-test"
    removeIfExists(outDir, recursive: true)
    let config = CliConfig()
    config.outputDir = outDir
    config.clean = true
    config.features.add("Windows.Win32.Foundation")
    config.features.add("Windows.Win32.Security")
    config.features.add("Windows.Win32.System.Com")

    generate(config, records)
    let manifest = String.fromUtf8(File.readFrom("${outDir}/codegen-manifest.json"))
    removeIfExists(outDir, recursive: true)

    @Expect(manifest.contains("Windows.Win32.Foundation.HANDLE"), true)
    @Expect(manifest.contains("Windows.Win32.Security.ACL"), true)
    @Expect(manifest.contains("Windows.Win32.System.Com.IUnknown"), true)
    @Expect(manifest.contains("Windows.Win32.Foundation.Metadata.GuidAttribute"), false)
    @Expect(manifest.contains("Windows.Win32.Security.ExtensibleAuthenticationProtocol.EapXml"), false)
    @Expect(manifest.contains("Windows.Win32.System.Com.Urlmon.XmlConsumer"), false)
    @Expect(manifest.contains("Windows.Win32.Data.Xml.MsXml"), false)
}

@Test
func testValidateRequestedFiltersAcceptKnownFormsAndRejectUnknown() {
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.Widget", "Example.Foundation", "Widget", "Example_Foundation_Widget", []))
    records.add(SymbolRecord("Example.Foundation.Controls.Button", "Example.Foundation.Controls", "Button", "Example_Foundation_Controls_Button", []))
    let valid = ArrayList<String>()
    valid.add("all")
    valid.add("Widget")
    valid.add("Example.Foundation.Controls.Button")
    valid.add("Example.Foundation.*")
    valid.add("!Example.Foundation.Controls")
    let invalid = ArrayList<String>()
    invalid.add("MissingType")

    validateRequestedFilters(valid, records)
    @Expect(cliTestThrows({ => validateRequestedFilters(invalid, records) }), true)
}

@Test
func testInterfaceImplementationTopLevelTypeSpecificationResolvesAndAddsDependencies() {
    let typeArguments = ArrayList<SignatureRecord>()
    typeArguments.add(SignatureRecord("Type", name: "IWidget", namespace: "Example.Foundation", hasNamespace: true))
    let signature = SignatureRecord("Type", name: "IVector", namespace: "Example.Foundation", hasNamespace: true, typeArguments: typeArguments)
    let implementation = InterfaceImplementationRecord(typeSpecification: Some(TypeSpecificationRecord(signature)))
    let records = ArrayList<SymbolRecord>()
    records.add(SymbolRecord("Example.Foundation.IVector", "Example.Foundation", "IVector", "Example_Foundation_IVector", []))
    records.add(SymbolRecord("Example.Foundation.IWidget", "Example.Foundation", "IWidget", "Example_Foundation_IWidget", []))
    let symbolsByName = cliTestRecordsByName(records)

    match (interfaceImplementationFullName(implementation, symbolsByName, "Example.Foundation.Widget")) {
        case Some(fullName) => @Expect(fullName, "Example.Foundation.IVector")
        case None => @Expect(false, true)
    }

    let implementations = ArrayList<InterfaceImplementationRecord>()
    implementations.add(implementation)
    let typeDef = TypeDefinitionRecord("Example.Foundation", "Widget", interfaceImplementations: implementations)
    let dependencies = typeDependencies(typeDef, typeDef.fullName())
    @Expect(contains(dependencies, "Example.Foundation.IVector"), true)
    @Expect(contains(dependencies, "Example.Foundation.IWidget"), true)
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
func testFilterReferencedSymbolsRemovesMatchingNamespace() {
    let symbols = ArrayList<SymbolRecord>()
    symbols.add(SymbolRecord("Windows.Foundation.IThing", "Windows.Foundation", "IThing", "Windows_Foundation_IThing", []))
    symbols.add(SymbolRecord("Windows.Foundation.Collections.IVector", "Windows.Foundation.Collections", "IVector", "Windows_Foundation_Collections_IVector", []))
    symbols.add(SymbolRecord("Windows.Foundation.Numerics.Vector2", "Windows.Foundation.Numerics", "Vector2", "Windows_Foundation_Numerics_Vector2", []))
    let references = ArrayList<ReferenceStage>()
    references.add(ReferenceStage.parse("windows_collections,flat,Windows.Foundation.Collections"))
    references.add(ReferenceStage.parse("windows_numerics,flat,Windows.Foundation.Numerics"))

    let remaining = filterReferencedSymbols(symbols, references)

    @Expect(remaining.size, 1)
    @Expect(remaining[0].fullName, "Windows.Foundation.IThing")
}

@Test
func testFilterReferencedSymbolsDoesNotFilterSubNamespaces() {
    let symbols = ArrayList<SymbolRecord>()
    symbols.add(SymbolRecord("Windows.Win32.Security.ACL", "Windows.Win32.Security", "ACL", "Windows_Win32_Security_ACL", []))
    symbols.add(SymbolRecord("Windows.Win32.Security.Cryptography.ALG_ID", "Windows.Win32.Security.Cryptography", "ALG_ID", "Windows_Win32_Security_Cryptography_ALG_ID", []))
    let references = ArrayList<ReferenceStage>()
    references.add(ReferenceStage.parse("windows_common,skip-root,Windows.Win32.Security"))

    let remaining = filterReferencedSymbols(symbols, references)

    @Expect(remaining.size, 1)
    @Expect(remaining[0].fullName, "Windows.Win32.Security.Cryptography.ALG_ID")
}

@Test
func testFilterReferencedSymbolsSupportsWildcardForNamespacePrefix() {
    let symbols = ArrayList<SymbolRecord>()
    symbols.add(SymbolRecord("Windows.Win32.Security.ACL", "Windows.Win32.Security", "ACL", "Windows_Win32_Security_ACL", []))
    symbols.add(SymbolRecord("Windows.Win32.Security.Cryptography.ALG_ID", "Windows.Win32.Security.Cryptography", "ALG_ID", "Windows_Win32_Security_Cryptography_ALG_ID", []))
    let references = ArrayList<ReferenceStage>()
    references.add(ReferenceStage.parse("windows_common,skip-root,Windows.Win32.Security*"))

    let remaining = filterReferencedSymbols(symbols, references)

    @Expect(remaining.size, 0)
}

@Test
func testQualifyMangledFullNameRespectsActiveReferences() {
    let references = ArrayList<ReferenceStage>()
    references.add(ReferenceStage.parse("windows_collections,flat,Windows.Foundation.Collections"))
    setActiveReferences(references)
    let outsideRef = qualifyMangledFullName("Windows.Foundation.IThing")
    let insideRef = qualifyMangledFullName("Windows.Foundation.Collections.IVector")
    clearActiveReferences()
    let clearedRef = qualifyMangledFullName("Windows.Foundation.Collections.IVector")

    @Expect(outsideRef, "Windows_Foundation_IThing")
    @Expect(insideRef, "windows_collections.Windows_Foundation_Collections_IVector")
    @Expect(clearedRef, "Windows_Foundation_Collections_IVector")
}
