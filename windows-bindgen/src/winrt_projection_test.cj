package windows_bindgen

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testWinrtProjectedPrimitiveStringUsesHString() {
    let symbolsByName = HashMap<String, SymbolRecord>()

    @Expect(
        winrtProjectedTypeName(SignatureRecord("Primitive", name: "String"), symbolsByName, "Example.Foundation.Uri"),
        "windows_core.HString"
    )
    @Expect(
        winrtProjectedTypeName(SignatureRecord("Primitive", name: "Object"), symbolsByName, "Example.Foundation.Value"),
        "windows_interface.IInspectable"
    )
}

@Test
func testClosedWinrtGenericValueStructArgumentFallsBackToInspectable() {
    let symbolsByName = HashMap<String, SymbolRecord>()
    let vectorAttributes = ArrayList<String>()
    vectorAttributes.add("Public")
    vectorAttributes.add("AutoLayout")
    vectorAttributes.add("Interface")
    vectorAttributes.add("Abstract")
    vectorAttributes.add("WindowsRuntime")
    let vectorGenerics = ArrayList<GenericParameterRecord>()
    vectorGenerics.add(GenericParameterRecord("T"))
    let vectorDef = TypeDefinitionRecord(
        "Example.Foundation",
        "IVectorView`1",
        attributes: vectorAttributes,
        genericParameters: vectorGenerics
    )
    let valueAttributes = ArrayList<String>()
    valueAttributes.add("Public")
    valueAttributes.add("SequentialLayout")
    let valueDef = TypeDefinitionRecord(
        "Example.Foundation",
        "Usage",
        baseType: "System.ValueType",
        hasBaseType: true,
        attributes: valueAttributes
    )
    symbolsByName.add("Example.Foundation.IVectorView`1", SymbolRecord(
        "Example.Foundation.IVectorView`1",
        "Example.Foundation",
        "IVectorView`1",
        "Example_Foundation_IVectorView_1",
        [],
        typeDef: Some(vectorDef)
    ))
    symbolsByName.add("Example.Foundation.Usage", SymbolRecord(
        "Example.Foundation.Usage",
        "Example.Foundation",
        "Usage",
        "Example_Foundation_Usage",
        [],
        typeDef: Some(valueDef)
    ))
    let arguments = ArrayList<SignatureRecord>()
    arguments.add(SignatureRecord("Type", name: "Usage", namespace: "Example.Foundation", hasNamespace: true))
    let signature = SignatureRecord(
        "Generic",
        typeSig: Some(SignatureRecord("Type", name: "IVectorView`1", namespace: "Example.Foundation", hasNamespace: true)),
        typeArguments: arguments
    )

    @Expect(winrtProjectedTypeName(signature, symbolsByName, "Example.Foundation.Device"), "windows_interface.IInspectable")
}

@Test
func testGenericWinrtRawEventAddClearsTokenOutSlotBeforeLiveRawFailure() {
    let symbolsByName = HashMap<String, SymbolRecord>()
    let typeAttributes = ArrayList<String>()
    typeAttributes.add("Public")
    typeAttributes.add("AutoLayout")
    typeAttributes.add("Interface")
    typeAttributes.add("Abstract")
    typeAttributes.add("WindowsRuntime")
    let genericParameters = ArrayList<GenericParameterRecord>()
    genericParameters.add(GenericParameterRecord("T"))
    let methodAttributes = ArrayList<String>()
    methodAttributes.add("Public")
    methodAttributes.add("Virtual")
    methodAttributes.add("SpecialName")
    let signatureParameters = ArrayList<SignatureRecord>()
    signatureParameters.add(SignatureRecord("Type", name: "TypedEventHandler", namespace: "Tiny.Foundation", hasNamespace: true))
    let metadataParameters = ArrayList<ParameterRecord>()
    metadataParameters.add(ParameterRecord("handler", sequenceNumber: 1))
    let methods = ArrayList<MethodRecord>()
    methods.add(MethodRecord(
        "add_Changed",
        MethodSignatureRecord(
            SignatureRecord("Type", name: "EventRegistrationToken", namespace: "Windows.Foundation", hasNamespace: true),
            parameters: signatureParameters,
            requiredParameterCount: 1
        ),
        parameters: metadataParameters,
        attributes: methodAttributes
    ))
    let typeDef = TypeDefinitionRecord(
        "Tiny.Foundation",
        "IGenericSource`1",
        attributes: typeAttributes,
        methods: methods,
        genericParameters: genericParameters
    )
    let symbol = SymbolRecord(
        "Tiny.Foundation.IGenericSource`1",
        "Tiny.Foundation",
        "IGenericSource`1",
        "Tiny_Foundation_IGenericSource_1",
        [],
        typeDef: Some(typeDef)
    )
    let source = renderGenericWinrtInterfaceMethods(symbol, typeDef, symbolsByName)

    @Expect(source.contains("public unsafe func Changed(handler: CPointer<Unit>, result: CPointer<Int64>): windows_core.HRESULT {\n        if (result.isNotNull()) {\n            unsafe { result.write(0i64) }\n        }\n        let liveRaw = asRaw()"), true)
}

@Test
func testGenericWinrtVtblNoneBranchClearsOutSlots() {
    let symbolsByName = HashMap<String, SymbolRecord>()
    let typeAttributes = ArrayList<String>()
    typeAttributes.add("Public")
    typeAttributes.add("AutoLayout")
    typeAttributes.add("Interface")
    typeAttributes.add("Abstract")
    typeAttributes.add("WindowsRuntime")
    let genericParameters = ArrayList<GenericParameterRecord>()
    genericParameters.add(GenericParameterRecord("T"))
    let methodAttributes = ArrayList<String>()
    methodAttributes.add("Public")
    methodAttributes.add("Virtual")
    let outAttributes = ArrayList<String>()
    outAttributes.add("Out")
    let indexOfParameters = ArrayList<SignatureRecord>()
    indexOfParameters.add(SignatureRecord("Primitive", name: "Int32"))
    indexOfParameters.add(SignatureRecord("Primitive", name: "UInt32"))
    let indexOfMetadataParameters = ArrayList<ParameterRecord>()
    indexOfMetadataParameters.add(ParameterRecord("value", sequenceNumber: 1))
    indexOfMetadataParameters.add(ParameterRecord("index", sequenceNumber: 2, attributes: outAttributes))
    let getManyParameters = ArrayList<SignatureRecord>()
    getManyParameters.add(SignatureRecord("Primitive", name: "UInt32"))
    getManyParameters.add(SignatureRecord("SZArray", typeSig: Some(SignatureRecord("GenericParameter", name: "T"))))
    let lengthAttributes = ArrayList<CustomAttributeRecord>()
    lengthAttributes.add(CustomAttributeRecord("Windows.Foundation.Metadata.LengthIsAttribute"))
    let getManyMetadataParameters = ArrayList<ParameterRecord>()
    getManyMetadataParameters.add(ParameterRecord("startIndex", sequenceNumber: 1))
    getManyMetadataParameters.add(ParameterRecord("items", sequenceNumber: 2, attributes: outAttributes, customAttributes: lengthAttributes))
    let methods = ArrayList<MethodRecord>()
    methods.add(MethodRecord(
        "Name",
        MethodSignatureRecord(SignatureRecord("Primitive", name: "String")),
        attributes: methodAttributes
    ))
    methods.add(MethodRecord(
        "CreateObject",
        MethodSignatureRecord(SignatureRecord("Primitive", name: "Object")),
        attributes: methodAttributes
    ))
    methods.add(MethodRecord(
        "IndexOf",
        MethodSignatureRecord(
            SignatureRecord("Primitive", name: "Boolean"),
            parameters: indexOfParameters,
            requiredParameterCount: 2
        ),
        parameters: indexOfMetadataParameters,
        attributes: methodAttributes
    ))
    methods.add(MethodRecord(
        "Items",
        MethodSignatureRecord(
            SignatureRecord("SZArray", typeSig: Some(SignatureRecord("Primitive", name: "Int32")))
        ),
        attributes: methodAttributes
    ))
    methods.add(MethodRecord(
        "Names",
        MethodSignatureRecord(
            SignatureRecord("SZArray", typeSig: Some(SignatureRecord("Primitive", name: "String")))
        ),
        attributes: methodAttributes
    ))
    methods.add(MethodRecord(
        "GetMany",
        MethodSignatureRecord(
            SignatureRecord("Primitive", name: "UInt32"),
            parameters: getManyParameters,
            requiredParameterCount: 2
        ),
        parameters: getManyMetadataParameters,
        attributes: methodAttributes
    ))
    let typeDef = TypeDefinitionRecord(
        "Tiny.Foundation",
        "IClearingSource`1",
        attributes: typeAttributes,
        methods: methods,
        genericParameters: genericParameters
    )
    let symbol = SymbolRecord(
        "Tiny.Foundation.IClearingSource`1",
        "Tiny.Foundation",
        "IClearingSource`1",
        "Tiny_Foundation_IClearingSource_1",
        [],
        typeDef: Some(typeDef)
    )
    let source = renderGenericWinrtInterfaceVtbl(symbol, typeDef, symbolsByName)

    @Expect(source.contains("type Tiny_Foundation_IClearingSource_1ExceptionBase = Exception"), true)
    @Expect(source.contains("public var Name: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result =>\n        if (result.isNotNull()) {\n            unsafe { result.write(CPointer<Unit>()) }\n        }\n        windows_core.E_NOTIMPL.value\n    }"), true)
    @Expect(source.contains("public var CreateObject: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result =>\n        if (result.isNotNull()) {\n            unsafe { result.write(CPointer<Unit>()) }\n        }\n        windows_core.E_NOTIMPL.value\n    }"), true)
    @Expect(source.contains("public var IndexOf: CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32> = { _, value, index, result =>\n        if (index.isNotNull()) {\n            unsafe { index.write(0u32) }\n        }\n        if (result.isNotNull()) {\n            unsafe { result.write(false) }\n        }\n        windows_core.E_NOTIMPL.value\n    }"), true)
    @Expect(source.contains("public var Items: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<Int32>>) -> Int32> = { _, resultSize, result =>\n        if (resultSize.isNotNull()) {\n            unsafe { resultSize.write(0u32) }\n        }\n        if (result.isNotNull()) {\n            unsafe { result.write(CPointer<Int32>()) }\n        }\n        windows_core.E_NOTIMPL.value\n    }"), true)
    @Expect(source.contains("public var Names: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<CPointer<Unit>>>) -> Int32> = { _, resultSize, result =>\n        if (resultSize.isNotNull()) {\n            unsafe { resultSize.write(0u32) }\n        }\n        if (result.isNotNull()) {\n            unsafe { result.write(CPointer<CPointer<Unit>>()) }\n        }\n        windows_core.E_NOTIMPL.value\n    }"), true)
    @Expect(source.contains("public var GetMany: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, startIndex, itemsSize, items, result =>\n        if (result.isNotNull()) {\n            unsafe { result.write(0u32) }\n        }\n        windows_core.E_NOTIMPL.value\n    }"), true)
    @Expect(source.contains("public var GetMany: CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<CPointer<CPointer<Unit>>>, CPointer<UInt32>) -> Int32>"), false)
    @Expect(source.contains("case None =>\n                    if (result.isNotNull()) {\n                        unsafe { result.write(CPointer<Unit>()) }\n                    }\n                    windows_core.E_NOINTERFACE.value"), true)
    @Expect(source.contains("case None =>\n                    if (index.isNotNull()) {\n                        unsafe { index.write(0u32) }\n                    }\n                    if (result.isNotNull()) {\n                        unsafe { result.write(false) }\n                    }\n                    windows_core.E_NOINTERFACE.value"), true)
    @Expect(source.contains("if (items.isNull() || result.isNull()) {\n                        if (result.isNotNull()) {\n                            unsafe { result.write(0u32) }\n                        }\n                        windows_core.E_POINTER.value"), true)
    @Expect(source.contains("let resultHr__ = impl.Name(result)\n                            if (windows_core.HRESULT(resultHr__).failed()) {\n                                if (result.isNotNull()) {\n                                    let failedString__ = unsafe { result.read() }"), true)
    @Expect(source.contains("windows_core.releaseSystemHStringHandle(failedString__)\n                                        unsafe { result.write(CPointer<Unit>()) }"), true)
    @Expect(source.contains("let resultHr__ = impl.CreateObject(result)\n                            if (windows_core.HRESULT(resultHr__).failed()) {\n                                windows_core.releaseFailedComOutSlot(result)\n                                if (result.isNotNull()) {\n                                    unsafe { result.write(CPointer<Unit>()) }\n                                }\n                            }\n                            resultHr__\n                        } catch (error: windows_core.WindowsException) {\n                            windows_core.releaseFailedComOutSlot(result)\n                            if (result.isNotNull()) {\n                                unsafe { result.write(CPointer<Unit>()) }\n                            }\n                            error.code().value\n                        } catch (_: Tiny_Foundation_IClearingSource_1ExceptionBase) {\n                            windows_core.releaseFailedComOutSlot(result)\n                            if (result.isNotNull()) {\n                                unsafe { result.write(CPointer<Unit>()) }\n                            }\n                            windows_core.E_FAIL.value\n                        }"), true)
    @Expect(source.contains("let resultHr__ = impl.IndexOf(value, index, result)\n                            if (windows_core.HRESULT(resultHr__).failed()) {\n                                if (index.isNotNull()) {\n                                    unsafe { index.write(0u32) }\n                                }\n                                if (result.isNotNull()) {\n                                    unsafe { result.write(false) }\n                                }\n                            }\n                            resultHr__"), true)
    @Expect(source.contains("let resultHr__ = impl.Items(resultSize, result)\n                            if (windows_core.HRESULT(resultHr__).failed()) {\n                                if (result.isNotNull()) {\n                                    var rawSize__ = 0u32"), true)
    @Expect(source.contains("windows_core.coTaskMemFree(CPointer<Unit>(rawArray__))\n                                    }\n                                    unsafe { result.write(CPointer<Int32>()) }\n                                }\n                                if (resultSize.isNotNull())"), true)
    @Expect(source.contains("let resultHr__ = impl.Names(resultSize, result)\n                            if (windows_core.HRESULT(resultHr__).failed()) {\n                                if (result.isNotNull()) {\n                                    var rawSize__ = 0u32"), true)
    @Expect(source.contains("windows_core.winrtReleaseGenericArrayOut<windows_core.HString>(CPointer<Unit>(rawArray__), rawSize__)\n                                    }\n                                    unsafe { result.write(CPointer<CPointer<Unit>>()) }\n                                }\n                                if (resultSize.isNotNull())"), true)
    @Expect(source.contains("let resultHr__ = impl.GetMany(startIndex, itemsSize, items, result)\n                            if (windows_core.HRESULT(resultHr__).failed()) {\n                                if (result.isNotNull()) {\n                                    unsafe { result.write(0u32) }\n                                }\n                            }\n                            resultHr__"), true)
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
              "Name": "get_Title",
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
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"}
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 0, "Attributes": ["None"], "CustomAttributes": [], "DefaultValue": null}
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
            },
            {
              "Name": "GetNames",
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
                "ReturnType": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}
              },
              "Parameters": [
                {"Name": "names", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null}
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
    let deps = collectSupportDependencyNames("windows", records, symbolsByName)

    @Expect(source.contains("@Interface[\"11111111-2222-3333-4455-66778899aabb\", \"Example.Foundation.IWidget\", \"CreateInstance.innerInterface=Com;CreateInstance.result=Com;Title.value=HString;External.value=Com;GetNames.names=Array<windows_core.HString>\"]"), true)
    @Expect(source.contains("public interface Example_Foundation_IWidget <: IInspectable {"), true)
    @Expect(source.contains("func Ping(): Int32"), true)
    @Expect(source.contains("func CreateInstance(baseInterface: CPointer<Unit>, innerInterface: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(source.contains("func Title(value: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(source.contains("func External(value: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(source.contains("func SetExternal(value: CPointer<Unit>): Int32"), true)
    @Expect(source.contains("func GetNames(namesSize: CPointer<UInt32>, names: CPointer<CPointer<CPointer<Unit>>>): Int32"), true)
    @Expect(source.contains("@C\npublic struct Example_Foundation_IWidgetVtbl"), false)
    @Expect(source.contains("public open class Example_Foundation_IWidget"), false)
    @Expect(cliTestContainsString(deps.toArray(), "windows_core"), true)
    @Expect(cliTestContainsString(deps.toArray(), "windows_interface"), true)
    @Expect(renderCjpmToml("windows", supportDeps: deps).contains("windows_core = { path = \"../../windows-core\" }"), true)
    @Expect(renderCjpmToml("windows", supportDeps: deps).contains("windows_interface = { path = \"../../windows-interface\" }"), true)

    let outDir = ".generated/interface-macro-import-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeImplFiles(writer, records, "windows", symbolsByName)
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
func testGenericWinrtInterfaceUsesClosedSignatureIid() {
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
          "Name": "IVector`1",
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
              "Name": "GetAt",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "GenericParameter", "Name": "T"}
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "index", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [
            {"Name": "T", "SequenceNumber": 0, "Attributes": [], "CustomAttributes": [], "Constraints": []}
          ],
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
        if (record.fullName == "Example.Foundation.IVector`1") {
            source = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(source.contains("public interface Example_Foundation_IVector_1_Impl<T> <: Example_Foundation_IVector_1_ImplErased where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T> {}"), true)
    @Expect(source.contains("public open class Example_Foundation_IVector_1<T> <: windows_interface.InterfaceWrapperBase"), true)
    @Expect(source.contains("windows_interface.GUID.from_signature(Example_Foundation_IVector_1<T>.signature())"), true)
    @Expect(source.contains("sb.append(\"pinterface({11111111-2222-3333-4455-66778899aabb}\")"), true)
    @Expect(source.contains("sb.append(T.signature())"), true)
    @Expect(source.contains("func GetAt(index: UInt32, result: CPointer<CPointer<Unit>>): windows_core.HRESULT"), true)
    @Expect(source.contains("windows_interface.InterfaceParameterSchema(\"index\", \"UInt32\", \"UInt32\", windows_interface.InterfaceParameterBridgeKind.Value)"), true)
    @Expect(source.contains("windows_interface.InterfaceParameterSchema(\"result\", \"CPointer<CPointer<Unit>>\", \"OutSlot<T>\", windows_interface.InterfaceParameterBridgeKind.OutSlot)"), true)
    @Expect(source.contains("windows_interface.InterfaceParameterSchema(\"result\", \"CPointer<CPointer<Unit>>\", \"CPointer<CPointer<Unit>>\", windows_interface.InterfaceParameterBridgeKind.Value)"), false)
    @Expect(source.contains("windows_interface.InterfaceDescriptor<Example_Foundation_IVector_1<T>>"), true)
    @Expect(source.contains("extend<T> Example_Foundation_IVector_1<T> <: windows_core.Interface<Example_Foundation_IVector_1<T>> where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T> {}"), true)
    @Expect(source.contains("windows_interface.GUID.parse(\"11111111-2222-3333-4455-66778899aabb\")"), false)

    let outDir = ".generated/generic-facade-alias-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeFacadeFiles(writer, "Example.Foundation", records, "windows")
    let facade = String.fromUtf8(File.readFrom("${outDir}/src/Example/Foundation/facade_0.cj"))
    removeIfExists(outDir, recursive: true)

    @Expect(facade.contains("public type IVector<T> = Example_Foundation_IVector_1<T>"), true)
    @Expect(facade.contains("public type IVector = Example_Foundation_IVector_1"), false)
    @Expect(facade.contains("public type IVectorVtbl = Example_Foundation_IVector_1Vtbl"), true)
}

@Test
func testGenericWinrtDelegateUsesClosedSignatureIid() {
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
          "Name": "EventHandler`1",
          "MetadataToken": "0x02000002",
          "BaseType": "System.MulticastDelegate",
          "IsNested": false,
          "Attributes": ["Public", "Sealed", "WindowsRuntime"],
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
                  {"Kind": "GenericParameter", "Name": "T"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "sender", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "args", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [
            {"Name": "T", "SequenceNumber": 0, "Attributes": [], "CustomAttributes": [], "Constraints": []}
          ],
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
        if (record.fullName == "Example.Foundation.EventHandler`1") {
            source = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(source.contains("public open class Example_Foundation_EventHandler_1<T> <: windows_interface.InterfaceWrapperBase"), true)
    @Expect(source.contains("windows_interface.GUID.from_signature(Example_Foundation_EventHandler_1<T>.signature())"), true)
    @Expect(source.contains("sb.append(T.signature())"), true)
    @Expect(source.contains("@C\npublic struct Example_Foundation_EventHandler_1Vtbl"), true)
    @Expect(source.contains("windows_interface.InterfaceDescriptorSchema(\"Example.Foundation.EventHandler\", Example_Foundation_EventHandler_1<T>.iid(), windows_interface.IUnknown.descriptorSchema()"), true)
    @Expect(source.contains("windows_interface.InterfaceMethodSchema(\"Invoke\", 3"), true)
    @Expect(source.contains("public unsafe func Invoke(sender: windows_interface.IInspectable, args: T): Unit"), true)
    @Expect(source.contains("public static func new(invoke: (windows_interface.IInspectable, T) -> Unit): Example_Foundation_EventHandler_1<T>"), true)
    @Expect(source.contains("this.Invoke(windows_core.winrtProjectGenericIn<windows_interface.IInspectable>(sender), windows_core.winrtProjectGenericIn<T>(args))"), true)
    @Expect(source.contains("private class Example_Foundation_EventHandler_1Box<T> <: Example_Foundation_EventHandler_1Invoker<T> & Resource"), true)
    @Expect(source.contains("func buildExample_Foundation_EventHandler_1BoxVtbl<T>(): Example_Foundation_EventHandler_1Vtbl where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T>"), true)
    @Expect(source.contains("windows_core.asImplFromRaw<Example_Foundation_EventHandler_1InvokerErased>(instanceRaw)"), true)
    @Expect(source.contains("extend<T> Example_Foundation_EventHandler_1<T> <: windows_core.Interface<Example_Foundation_EventHandler_1<T>> where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T> {}"), true)
    @Expect(source.contains("public class Example_Foundation_EventHandler_1 {\n    private let raw: CPointer<Unit>"), false)
    @Expect(source.contains("unsupportedDelegateAuthoringReason"), false)
}

@Test
func testWinrtDelegateWithoutGuidRendersUnsupportedAuthoringFactory() {
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
          "Name": "NoGuidHandler",
          "MetadataToken": "0x02000002",
          "BaseType": "System.MulticastDelegate",
          "IsNested": false,
          "Attributes": ["Public", "Sealed", "WindowsRuntime"],
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
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Foundation.NoGuidHandler") {
            source = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(source.contains("public class Example_Foundation_NoGuidHandler <: Resource"), true)
    @Expect(source.contains("let shouldRelease = ownsHandle\n        ownsHandle = false\n        closed = true\n        if (shouldRelease) {\n            Example_Foundation_NoGuidHandler.releaseRaw(raw)\n        }"), true)
    @Expect(source.contains("unsupportedDelegateAuthoringReason"), true)
    @Expect(source.contains("missing GuidAttribute"), true)
    @Expect(source.contains("public static func new(): Example_Foundation_NoGuidHandler"), true)
    @Expect(source.contains("public static func new(invoke:"), false)
    @Expect(source.contains("InterfaceDescriptorSchema"), false)
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
          "Name": "IIterable",
          "MetadataToken": "0x0200000a",
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
          "Name": "IKeyValuePair",
          "MetadataToken": "0x0200000b",
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
          "InterfaceImplementations": [
            {
              "Interface": {
                "Kind": "Generic",
                "Type": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IIterable"},
                "TypeArguments": [
                  {
                    "Kind": "Generic",
                    "Type": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IKeyValuePair"},
                    "TypeArguments": [
                      {"Kind": "GenericParameter", "Name": "K"},
                      {"Kind": "GenericParameter", "Name": "V"}
                    ]
                  }
                ]
              },
              "CustomAttributes": []
            }
          ],
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
              "Name": "CreateRawStrings",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "Object"},
                "Parameters": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}
                ]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "Object"}},
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "CreateRawObjectOut",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}},
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "Object"}}
                ]
              },
              "Parameters": [
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}},
                {"Name": "objectValue", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "Object"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "CreateRawStringOut",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}},
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "String"}}
                ]
              },
              "Parameters": [
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}},
                {"Name": "stringValue", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetRawStringArrayOut",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}
                ]
              },
              "Parameters": [
                {"Name": "names", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetCount",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "Int32"}}
                ]
              },
              "Parameters": [
                {"Name": "count", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "Int32"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetRawObjectOut",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "Object"}}
                ]
              },
              "Parameters": [
                {"Name": "objectValue", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "Object"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetPairOut",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "Object"}},
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "String"}}
                ]
              },
              "Parameters": [
                {"Name": "firstValue", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "Object"}},
                {"Name": "secondValue", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetRawStringOut",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [
                  {"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "String"}}
                ]
              },
              "Parameters": [
                {"Name": "stringValue", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "String"}}
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
                "Kind": "Generic",
                "Type": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IMap"},
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
    @Expect(classSource.contains("let ancestors = [Example_Foundation_IWidget.iid(), Example_Foundation_IWidgetExtra.iid(), Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>.iid(), Example_Foundation_IIterable<Example_Foundation_IKeyValuePair<windows_core.HString, Example_Foundation_IWidget>>.iid(), Example_Foundation_IVector<Example_Foundation_IWidgetExtra>.iid(), windows_interface.IInspectable.iid(), windows_interface.IUnknown.iid()]"), true)
    @Expect(classSource.contains("windows_interface.InterfaceDescriptor<Example_Foundation_Widget>(\"Widget\", Example_Foundation_IWidget.iid(), ancestors"), true)
    @Expect(classSource.contains("public func defaultInterface(): Example_Foundation_IWidget"), true)
    @Expect(classSource.contains("public func asIWidget(): Example_Foundation_IWidget"), true)
    @Expect(classSource.contains("public func asIWidgetExtra(): Example_Foundation_IWidgetExtra"), true)
    @Expect(classSource.contains("public func asIMap(): Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>"), true)
    @Expect(classSource.contains("query<Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>>(Example_Foundation_IMap<windows_core.HString, Example_Foundation_IWidget>.descriptor())"), true)
    @Expect(classSource.contains("public func asIIterable(): Example_Foundation_IIterable<Example_Foundation_IKeyValuePair<windows_core.HString, Example_Foundation_IWidget>>"), true)
    @Expect(classSource.contains("IKeyValuePair<K, V>"), false)
    @Expect(classSource.contains("public func asIVector(): Example_Foundation_IVector<Example_Foundation_IWidgetExtra>"), true)
    @Expect(classSource.contains("public static func new(): Example_Foundation_Widget"), true)
    @Expect(classSource.contains("windows_core.factory<Example_Foundation_Widget, windows_core.IGenericFactory>().unwrap()"), true)
    @Expect(classSource.contains("factory__.ActivateInstance<Example_Foundation_Widget>(Example_Foundation_Widget.descriptor()).unwrap()"), true)
    @Expect(classSource.contains("public static func CreateWidget(name: windows_core.HString): Example_Foundation_Widget"), true)
    @Expect(classSource.contains("windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetFactory>().unwrap()"), true)
    @Expect(classSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_core.HString>(name))"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateWidget(__argBorrow0.asRaw(), CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<Example_Foundation_Widget>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("return Example_Foundation_Widget.fromAbiTakeWinrtHandle(result__)"), true)
    @Expect(classSource.contains("public static func NormalizeName(value: windows_core.HString): windows_core.HString"), true)
    @Expect(classSource.contains("windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetStatics>().unwrap()"), true)
    @Expect(classSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_core.HString>(value))"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.NormalizeName(__argBorrow0.asRaw(), CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_core.HString>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("return windows_core.HString.fromSystemHandleTake(result__)"), true)
    @Expect(classSource.contains("public static func DisplayName(): windows_core.HString"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.DisplayName(CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_core.HString>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("public static func SetDisplayName(value: windows_core.HString): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.SetDisplayName(__argBorrow0.asRaw()) }"), true)
    @Expect(classSource.contains("public static func SetKind(kind: Example_Foundation_WidgetKind): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.SetKind(kind.value) }"), true)
    @Expect(classSource.contains("hr__.check()"), true)
    @Expect(classSource.contains("let _ = hr__.ok()"), false)
    @Expect(classSource.contains("public static func GetKind(): Example_Foundation_WidgetKind"), true)
    @Expect(classSource.contains("return Example_Foundation_WidgetKind(result__)"), true)
    @Expect(classSource.contains("public static func CreateGuidArray(values: Array<windows_core.GuidValue>): windows_interface.IInspectable"), true)
    @Expect(classSource.contains("let __arg0AbiValues = Array<GUID>(values.size, { index => values[index].toRaw() })"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateGuidArray(__arg0Len, __arg0Raw, CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_interface.IInspectable>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("return windows_interface.IInspectable.fromAbiTakeWinrtHandle(result__)"), true)
    @Expect(classSource.contains("public static func CreateRawStrings(values: Array<windows_core.HString>): windows_interface.IInspectable"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateRawStrings(__arg0Len, __arg0Raw, CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("public static func CreateRawStrings(valuesSize: UInt32, values: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Unit"), false)
    @Expect(classSource.contains("windows_core.releaseFailedComOutSlot(result)"), false)
    @Expect(classSource.contains("windows_core.releaseFailedComOutSlot(values)"), false)
    @Expect(classSource.contains("public static func CreateRawObjectOut(values: Array<windows_core.HString>, objectValue: windows_core.OutSlot<windows_interface.IInspectable>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateRawObjectOut(__arg0Len, __arg0Raw, objectValue.borrowMut<CPointer<Unit>>()) }"), true)
    @Expect(classSource.contains("if (objectValue.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        objectValue.clear()\n        let __arg0AbiValues = Array<CPointer<Unit>>(values.size, { _ => CPointer<Unit>() })"), true)
    @Expect(classSource.contains("public static func CreateRawObjectOut(valuesSize: UInt32, values: CPointer<CPointer<Unit>>, objectValue: CPointer<CPointer<Unit>>): Unit"), false)
    @Expect(classSource.contains("public static func CreateRawStringOut(values: Array<windows_core.HString>, stringValue: windows_core.OutSlot<windows_core.HString>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateRawStringOut(__arg0Len, __arg0Raw, stringValue.borrowMut<CPointer<Unit>>()) }"), true)
    @Expect(classSource.contains("if (stringValue.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        stringValue.clear()\n        let __arg0AbiValues = Array<CPointer<Unit>>(values.size, { _ => CPointer<Unit>() })"), true)
    @Expect(classSource.contains("public static func CreateRawStringOut(valuesSize: UInt32, values: CPointer<CPointer<Unit>>, stringValue: CPointer<CPointer<Unit>>): Unit"), false)
    @Expect(classSource.contains("windows_core.releaseFailedComOutSlot(objectValue)"), false)
    @Expect(classSource.contains("windows_core.releaseFailedComOutSlot(stringValue)"), false)
    @Expect(classSource.contains("public static func GetCount(count: windows_core.OutSlot<Int32>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.GetCount(count.borrowMut<Int32>()) }"), true)
    @Expect(classSource.contains("if (count.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        count.clear()\n        try (factory__ = windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetFactory>().unwrap())"), true)
    @Expect(classSource.contains("count.write(__arg0Value)"), true)
    @Expect(classSource.contains("public static func GetRawObjectOut(objectValue: windows_core.OutSlot<windows_interface.IInspectable>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.GetRawObjectOut(objectValue.borrowMut<CPointer<Unit>>()) }"), true)
    @Expect(classSource.contains("public static func GetRawObjectOut(objectValue: windows_core.OutSlot<windows_interface.IInspectable>): Unit {\n        var hr__ = windows_core.E_POINTER\n        if (objectValue.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        objectValue.clear()\n        try (factory__ = windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetFactory>().unwrap()) {\n            hr__ = unsafe { factory__.GetRawObjectOut(objectValue.borrowMut<CPointer<Unit>>()) }\n        }\n        if (hr__.failed()) {\n            match (objectValue.takeAbi<CPointer<Unit>>()) {\n                case Some(__arg0ValuePartial) =>\n                    if (__arg0ValuePartial.isNotNull()) {\n                        windows_core.winrtReleaseGenericOut<windows_interface.IInspectable>(__arg0ValuePartial)\n                    }\n                case None => ()\n            }\n        }\n        hr__.check()\n        let __arg0Value = match (objectValue.takeAbi<CPointer<Unit>>()) {\n            case Some(value) => value\n            case None => throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        objectValue.write(windows_interface.IInspectable.fromAbiTakeWinrtHandle(__arg0Value))\n    }"), true)
    @Expect(classSource.contains("public static func GetPairOut(firstValue: windows_core.OutSlot<windows_interface.IInspectable>, secondValue: windows_core.OutSlot<windows_core.HString>): Unit"), true)
    @Expect(classSource.contains("var hr__ = windows_core.E_POINTER\n        var nullOutSlot__ = false\n        if (firstValue.isNull()) {\n            nullOutSlot__ = true\n        } else {\n            firstValue.clear()\n        }\n        if (secondValue.isNull()) {\n            nullOutSlot__ = true\n        } else {\n            secondValue.clear()\n        }\n        if (nullOutSlot__) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        try (factory__ = windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetFactory>().unwrap()) {\n            hr__ = unsafe { factory__.GetPairOut(firstValue.borrowMut<CPointer<Unit>>(), secondValue.borrowMut<CPointer<Unit>>()) }"), true)
    @Expect(classSource.contains("if (firstValue.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        firstValue.clear()\n        if (secondValue.isNull())"), false)
    @Expect(classSource.contains("public static func GetRawStringOut(stringValue: windows_core.OutSlot<windows_core.HString>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.GetRawStringOut(stringValue.borrowMut<CPointer<Unit>>()) }"), true)
    @Expect(classSource.contains("if (stringValue.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        stringValue.clear()\n        try (factory__ = windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetFactory>().unwrap())"), true)
    @Expect(classSource.contains("stringValue.write(windows_core.HString.fromSystemHandleTake(__arg0Value))"), true)
    @Expect(classSource.contains("public static func GetRawStringArrayOut(names: windows_core.OutSlot<Array<windows_core.HString>>): Unit"), true)
    @Expect(classSource.contains("if (names.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        names.clear()\n        try (factory__ = windows_core.factory<Example_Foundation_Widget, Example_Foundation_IWidgetFactory>().unwrap())"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.GetRawStringArrayOut(CPointer<UInt32>(inout __arg0Size), CPointer<CPointer<CPointer<Unit>>>(inout __arg0Data)) }"), true)
    @Expect(classSource.contains("names.write(__arg0Value)"), true)
    @Expect(classSource.contains("public static func GetNames(): Array<windows_core.HString>"), true)
    @Expect(classSource.contains("var __returnData = CPointer<CPointer<Unit>>()"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.GetNames(CPointer<UInt32>(inout __returnSize), CPointer<CPointer<CPointer<Unit>>>(inout __returnData)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && __returnData.isNotNull()) {\n            windows_core.winrtReleaseGenericArrayOut<windows_core.HString>(CPointer<Unit>(__returnData), __returnSize)\n            __returnData = CPointer<CPointer<Unit>>()\n            __returnSize = 0u32\n        }\n        hr__.check()"), true)
    @Expect(classSource.contains("return windows_core.winrtTakeGenericArrayOut<windows_core.HString>(CPointer<Unit>(__returnData), __returnSize)"), true)
    @Expect(classSource.contains("public static func CreateGuidArray(valuesSize: UInt32, values: CPointer<GUID>, result: CPointer<CPointer<Unit>>): Unit"), false)
    @Expect(classSource.contains("public static func GetNames(namesSize: CPointer<UInt32>, names: CPointer<CPointer<CPointer<Unit>>>): Unit"), false)
    @Expect(classSource.contains("public static func runtimeName(): String {\n        \"Example.Foundation.Widget\"\n    }"), true)
    @Expect(classSource.contains("return \"rc(Example.Foundation.Widget;{\" + Example_Foundation_IWidget.iid().toSignatureString() + \"})\""), true)
    @Expect(classSource.contains("windows_interface.RuntimeTypeContract(\"Example.Foundation.Widget\", Example_Foundation_Widget.signature(), Example_Foundation_IWidget.iid())"), true)
    @Expect(classSource.contains("extend Example_Foundation_Widget <: windows_core.HandleWinrtType<Example_Foundation_Widget>"), true)
    @Expect(classSource.contains("public class Example_Foundation_Widget {\n    private let raw: CPointer<Unit>"), false)

    let outDir = ".generated/runtime-class-wrapper-import-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeImplFiles(writer, records, "windows", symbolsByName)
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
func testWinrtRuntimeClassRawAbiFailureCleanupReleasesArrayOutSlots() {
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
              "Name": "CollectNamesWithRawInput",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "IntPtr"}},
                  {"Kind": "ByReference", "Type": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "rawValues", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "names", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "CollectIdsWithRawInput",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "IntPtr"}},
                  {"Kind": "ByReference", "Type": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid"}}}
                ],
                "RequiredParameterCount": 2,
                "ReturnType": {"Kind": "Primitive", "Name": "Void"}
              },
              "Parameters": [
                {"Name": "rawValues", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "ids", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null}
              ],
              "GenericParameters": []
            },
            {
              "Name": "ReturnNamesWithRawInput",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "IntPtr"}}
                ],
                "RequiredParameterCount": 1,
                "ReturnType": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}
              },
              "Parameters": [
                {"Name": "names", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "rawValues", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
          "Namespace": "Tiny.Foundation",
          "Name": "ArrayWidget",
          "MetadataToken": "0x02000003",
          "BaseType": "System.Object",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "IArrayWidget"},
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
        if (record.fullName == "Tiny.Foundation.ArrayWidget") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("public func CollectNamesWithRawInput(rawValuesSize: UInt32, rawValues: CPointer<CPointer<Unit>>, namesSize: CPointer<UInt32>, names: CPointer<CPointer<CPointer<Unit>>>): Unit"), true)
    @Expect(classSource.contains("var hr__ = windows_core.E_POINTER\n        if (namesSize.isNotNull()) {\n            unsafe { namesSize.write(0u32) }\n        }\n        if (names.isNotNull()) {\n            unsafe { names.write(CPointer<CPointer<Unit>>()) }\n        }\n        try (interface__ = defaultInterface()) {\n            hr__ = unsafe { interface__.CollectNamesWithRawInput(rawValuesSize, rawValues, namesSize, names) }"), true)
    @Expect(classSource.contains("windows_core.winrtReleaseGenericArrayOut<windows_core.HString>(CPointer<Unit>(__rawAbiArrayOut0Data), __rawAbiArrayOut0Size)"), true)
    @Expect(classSource.contains("unsafe { names.write(CPointer<CPointer<Unit>>()) }"), true)
    @Expect(classSource.contains("unsafe { namesSize.write(0u32) }"), true)
    @Expect(classSource.contains("public func CollectIdsWithRawInput(rawValuesSize: UInt32, rawValues: CPointer<CPointer<Unit>>, idsSize: CPointer<UInt32>, ids: CPointer<CPointer<GUID>>): Unit"), true)
    @Expect(classSource.contains("var hr__ = windows_core.E_POINTER\n        if (idsSize.isNotNull()) {\n            unsafe { idsSize.write(0u32) }\n        }\n        if (ids.isNotNull()) {\n            unsafe { ids.write(CPointer<GUID>()) }\n        }\n        try (interface__ = defaultInterface()) {\n            hr__ = unsafe { interface__.CollectIdsWithRawInput(rawValuesSize, rawValues, idsSize, ids) }"), true)
    @Expect(classSource.contains("windows_core.coTaskMemFree(CPointer<Unit>(__rawAbiArrayOut0Data))"), true)
    @Expect(classSource.contains("unsafe { ids.write(CPointer<GUID>()) }"), true)
    @Expect(classSource.contains("unsafe { idsSize.write(0u32) }"), true)
    @Expect(classSource.contains("public func ReturnNamesWithRawInput(rawValuesSize: UInt32, rawValues: CPointer<CPointer<Unit>>, namesSize: CPointer<UInt32>, names: CPointer<CPointer<CPointer<Unit>>>): Unit"), true)
    @Expect(classSource.contains("var hr__ = windows_core.E_POINTER\n        if (namesSize.isNotNull()) {\n            unsafe { namesSize.write(0u32) }\n        }\n        if (names.isNotNull()) {\n            unsafe { names.write(CPointer<CPointer<Unit>>()) }\n        }\n        try (interface__ = defaultInterface()) {\n            hr__ = unsafe { interface__.ReturnNamesWithRawInput(rawValuesSize, rawValues, namesSize, names) }"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.ReturnNamesWithRawInput(rawValuesSize, rawValues, namesSize, names) }"), true)
}

@Test
func testWinrtRuntimeClassProjectsDefaultInterfaceMembersPropertiesAndEvents() {
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
            {"Name": "value", "Signature": {"Kind": "Primitive", "Name": "Int64"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
              "Name": "Invoke",
              "Signature": {
                "ReturnType": {"Kind": "Void"},
                "Parameters": [
                  {"Kind": "Primitive", "Name": "Object"},
                  {"Kind": "Primitive", "Name": "Object"}
                ]
              },
              "Parameters": [],
              "Attributes": ["Public", "Virtual"],
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
          "Namespace": "Tiny.Foundation",
          "Name": "IWidget",
          "MetadataToken": "0x02000004",
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
              "Name": "GetName",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"},
                "Parameters": [{"Kind": "Type", "Namespace": "System", "Name": "String"}]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}},
                {"Name": "prefix", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "get_Title",
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
              "Name": "GetRawObject",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "Object"}, "Parameters": []},
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "Object"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetRawString",
              "Signature": {"ReturnType": {"Kind": "Primitive", "Name": "String"}, "Parameters": []},
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "String"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "put_Title",
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
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "EventRegistrationToken"},
                "Parameters": [{"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "TypedEventHandler"}]
              },
              "Parameters": [
                {"Name": "handler", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "TypedEventHandler"}},
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "EventRegistrationToken"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "remove_Changed",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [{"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "EventRegistrationToken"}]
              },
              "Parameters": [
                {"Name": "token", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "EventRegistrationToken"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual", "SpecialName"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "SetTags",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [{"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "String"}}]
              },
              "Parameters": [
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "String"}}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "CreateRawTitle",
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"},
                "Parameters": [{"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}]
              },
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Type", "Namespace": "System", "Name": "String"}},
                {"Name": "values", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Primitive", "Name": "String"}}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetIds",
              "Signature": {
                "ReturnType": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid"}},
                "Parameters": []
              },
              "Parameters": [
                {"Name": "ids", "SequenceNumber": 0, "Attributes": ["Retval"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid"}}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            },
            {
              "Name": "GetPriority",
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "Void"},
                "Parameters": [{"Kind": "ByReference", "Type": {"Kind": "Primitive", "Name": "Int32"}}]
              },
              "Parameters": [
                {"Name": "priority", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [], "DefaultValue": null, "Signature": {"Kind": "Primitive", "Name": "Int32"}}
              ],
              "Attributes": ["Public", "Abstract", "Virtual"],
              "ImplAttributes": [],
              "CustomAttributes": [],
              "GenericParameters": []
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [
            {
              "Name": "Changed",
              "Type": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "TypedEventHandler"},
              "Attributes": ["SpecialName"],
              "CustomAttributes": [],
              "Accessors": {"Adder": "add_Changed", "Remover": "remove_Changed"}
            }
          ],
          "Properties": [
            {
              "Name": "Title",
              "Signature": {"ReturnType": {"Kind": "Type", "Namespace": "System", "Name": "String"}, "Parameters": []},
              "Attributes": ["SpecialName"],
              "CustomAttributes": [],
              "Accessors": {"Getter": "get_Title", "Setter": "put_Title"},
              "DefaultValue": null
            }
          ]
        },
        {
          "Namespace": "Tiny.Foundation",
          "Name": "Widget",
          "MetadataToken": "0x02000005",
          "BaseType": "System.Object",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Tiny.Foundation", "Name": "IWidget"},
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
        if (record.fullName == "Tiny.Foundation.Widget") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("public func GetName(prefix: windows_core.HString): windows_core.HString"), true)
    @Expect(classSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_core.HString>(prefix))"), true)
    @Expect(classSource.contains("try (interface__ = defaultInterface())"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.GetName(__argBorrow0.asRaw(), CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_core.HString>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("return windows_core.HString.fromSystemHandleTake(result__)"), true)
    @Expect(classSource.contains("public mut prop Title: windows_core.HString"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.Title(CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_core.HString>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("public func GetRawObject(): windows_interface.IInspectable"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.GetRawObject(CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_interface.IInspectable>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("public func GetRawObject(): windows_interface.IInspectable {\n        var result__ = CPointer<Unit>()\n        var hr__ = windows_core.E_POINTER\n        try (interface__ = defaultInterface()) {\n            hr__ = unsafe { interface__.GetRawObject(CPointer<CPointer<Unit>>(inout result__)) }\n        }\n        if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_interface.IInspectable>(result__)\n            result__ = CPointer<Unit>()\n        }\n        hr__.check()\n        return windows_interface.IInspectable.fromAbiTakeWinrtHandle(result__)\n    }"), true)
    @Expect(classSource.contains("public func GetRawString(): windows_core.HString"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.GetRawString(CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_core.HString>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("return windows_core.HString.fromSystemHandleTake(result__)"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.SetTitle(__argBorrow0.asRaw()) }"), true)
    @Expect(classSource.contains("public func addChanged(handler: Tiny_Foundation_TypedEventHandler): Tiny_Foundation_EventRegistrationToken"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.Changed(__argBorrow0.asRaw(), CPointer<Tiny_Foundation_EventRegistrationToken>(inout result__)) }"), true)
    @Expect(classSource.contains("public func removeChanged(token: Tiny_Foundation_EventRegistrationToken): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.RemoveChanged(token) }"), true)
    @Expect(classSource.contains("public func SetTags(values: Array<windows_core.HString>): Unit"), true)
    @Expect(classSource.contains("let __arg0AbiValues = Array<CPointer<Unit>>(values.size, { _ => CPointer<Unit>() })"), true)
    @Expect(classSource.contains("let __arg0Borrow = windows_core.winrtBorrowGenericIn<windows_core.HString>(values[__arg0Index])"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.SetTags(__arg0Len, __arg0Raw) }"), true)
    @Expect(classSource.contains("public func CreateRawTitle(values: Array<windows_core.HString>): windows_core.HString"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.CreateRawTitle(__arg0Len, __arg0Raw, CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("return windows_core.HString.fromSystemHandleTake(result__)"), true)
    @Expect(classSource.contains("public func CreateRawTitle(valuesSize: UInt32, values: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Unit"), false)
    @Expect(classSource.contains("windows_core.releaseFailedComOutSlot(result)"), false)
    @Expect(classSource.contains("windows_core.releaseFailedComOutSlot(values)"), false)
    @Expect(classSource.contains("public func GetIds(): Array<windows_core.GuidValue>"), true)
    @Expect(classSource.contains("var __returnData = CPointer<GUID>()"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.GetIds(CPointer<UInt32>(inout __returnSize), CPointer<CPointer<GUID>>(inout __returnData)) }"), true)
    @Expect(classSource.contains("if (hr__.failed() && __returnData.isNotNull()) {\n            windows_core.coTaskMemFree(CPointer<Unit>(__returnData))\n            __returnData = CPointer<GUID>()\n            __returnSize = 0u32\n        }\n        hr__.check()"), true)
    // The array-return value is materialized with straight-line statements
    // (not an immediately-invoked closure), so the projected local is returned
    // directly and there is no `return { => ... }()` wrapper to mix address
    // spaces around the inout data/size slots.
    @Expect(classSource.contains("return { =>"), false)
    @Expect(classSource.contains("hr__.check()\n        if (__returnSize > 0u32 && __returnData.isNull()) {"), true)
    @Expect(classSource.contains("Array<windows_core.GuidValue>(__returnValueAbiValues.size, { index => windows_core.GuidValue.fromRaw(__returnValueAbiValues[index]) })"), true)
    @Expect(classSource.contains("return __returnValueProjected"), true)
    @Expect(classSource.contains("public func GetPriority(priority: windows_core.OutSlot<Int32>): Unit"), true)
    @Expect(classSource.contains("hr__ = unsafe { interface__.GetPriority(priority.borrowMut<Int32>()) }"), true)
    @Expect(classSource.contains("if (priority.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        priority.clear()\n        try (interface__ = defaultInterface())"), true)
    @Expect(classSource.contains("priority.write(__arg0Value)"), true)
    @Expect(classSource.contains("public func SetTags(valuesSize: UInt32, values: CPointer<CPointer<Unit>>): Unit"), false)
    @Expect(classSource.contains("public func GetIds(idsSize: CPointer<UInt32>, ids: CPointer<CPointer<GUID>>): Unit"), false)
    @Expect(classSource.contains("public func get_Title("), false)
    @Expect(classSource.contains("public func put_Title("), false)
    @Expect(classSource.contains("public func add_Changed("), false)
    @Expect(classSource.contains("public func remove_Changed("), false)
}

@Test
func testWinrtRuntimeClassAncestorsIncludeRequiredInterfacesAndBaseClass() {
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
          "Name": "IRequired",
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
          "Name": "IDerived",
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
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IRequired"},
              "CustomAttributes": []
            }
          ],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "BaseWidget",
          "MetadataToken": "0x02000005",
          "BaseType": "System.Object",
          "IsNested": false,
          "Attributes": ["Public", "Class", "WindowsRuntime"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IBase"},
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
        },
        {
          "Namespace": "Example.Foundation",
          "Name": "DerivedWidget",
          "MetadataToken": "0x02000006",
          "BaseType": "Example.Foundation.BaseWidget",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {"Kind": "Type", "Namespace": "Example.Foundation", "Name": "IDerived"},
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
        if (record.fullName == "Example.Foundation.DerivedWidget") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("let ancestors = [Example_Foundation_IDerived.iid(), Example_Foundation_IRequired.iid(), Example_Foundation_IBase.iid(), windows_interface.IInspectable.iid(), windows_interface.IUnknown.iid()]"), true)
    @Expect(classSource.contains("public func asIDerived(): Example_Foundation_IDerived"), true)
    @Expect(classSource.contains("public func asIRequired(): Example_Foundation_IRequired"), true)
    @Expect(classSource.contains("public func asIBase(): Example_Foundation_IBase"), true)
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
    @Expect(classSource.contains("public static func CreateInstance(baseInterface: windows_interface.IInspectable, innerInterface: windows_core.OutSlot<windows_interface.IInspectable>): Example_Foundation_ComposableWidget"), true)
    @Expect(classSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_interface.IInspectable>(baseInterface))"), true)
    @Expect(classSource.contains("hr__ = unsafe { factory__.CreateInstance(__argBorrow0.asRaw(), innerInterface.borrowMut<CPointer<Unit>>(), CPointer<CPointer<Unit>>(inout result__)) }"), true)
    @Expect(classSource.contains("if (hr__.failed()) {\n            match (innerInterface.takeAbi<CPointer<Unit>>()) {\n                case Some(__arg1ValuePartial) =>\n                    if (__arg1ValuePartial.isNotNull()) {\n                        windows_core.winrtReleaseGenericOut<windows_interface.IInspectable>(__arg1ValuePartial)\n                    }\n                case None => ()\n            }\n        }"), true)
    @Expect(classSource.contains("innerInterface.write(windows_interface.IInspectable.fromAbiTakeWinrtHandle(__arg1Value))"), true)
    @Expect(classSource.contains("return Example_Foundation_ComposableWidget.fromAbiTakeWinrtHandle(result__)"), true)
    @Expect(classSource.contains("public static func CreateInstance(baseInterface: CPointer<Unit>, innerInterface: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Unit"), false)

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
    @Expect(classSource.contains("if (hr__.failed() && result__.isNotNull()) {\n            windows_core.winrtReleaseGenericOut<windows_core.HString>(result__)\n            result__ = CPointer<Unit>()\n        }"), true)
    @Expect(classSource.contains("return windows_core.HString.fromSystemHandleTake(result__)"), true)
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
              "Name": "GetItemsLegacyReference",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ParameterTypes": [
                  {
                    "Kind": "Reference",
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
    @Expect(source.contains("func GetItemsLegacyReference(itemsSize: CPointer<UInt32>, items: CPointer<CPointer<Int32>>): Int32"), true)
    @Expect(source.contains("func SetGuids(valuesSize: UInt32, values: CPointer<GUID>): Int32"), true)
    @Expect(source.contains("func GetGuids(guidsSize: CPointer<UInt32>, guids: CPointer<CPointer<GUID>>): Int32"), true)
    @Expect(source.contains("func SetItems(values: CPointer<Unit>): Int32"), false)
    @Expect(source.contains("func GetItems(items: CPointer<CPointer<Unit>>): Int32"), false)
    @Expect(source.contains("func GetItemsByRef(items: CPointer<CPointer<Unit>>): Int32"), false)
    @Expect(source.contains("func GetItemsLegacyReference(items: CPointer<CPointer<Unit>>): Int32"), false)
    @Expect(source.contains("func SetGuids(valuesSize: UInt32, values: CPointer<Unit>): Int32"), false)
    @Expect(source.contains("func GetGuids(guidsSize: CPointer<UInt32>, guids: CPointer<CPointer<Unit>>): Int32"), false)

    let outDir = ".generated/interface-array-guid-import-test"
    removeIfExists(outDir, recursive: true)
    let writer = GeneratedPackageWriter(outDir, false)
    writeImplFiles(writer, records, "windows", symbolsByName)
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
    @Expect(delegateSource.contains("public open class Tiny_Foundation_TypedEventHandler"), true)
    @Expect(delegateSource.contains("@C\npublic struct Tiny_Foundation_TypedEventHandlerVtbl"), true)
    @Expect(delegateSource.contains("public open class Tiny_Foundation_TypedEventHandler <: windows_interface.InterfaceWrapperBase"), true)
    @Expect(delegateSource.contains("windows_interface.GUID.from_values(286331153u32, 8738u16, 13107u16"), true)
    @Expect(delegateSource.contains("windows_interface.InterfaceDescriptorSchema(\"Tiny.Foundation.TypedEventHandler\", Tiny_Foundation_TypedEventHandler.iid(), windows_interface.IUnknown.descriptorSchema()"), true)
    @Expect(delegateSource.contains("windows_interface.InterfaceMethodSchema(\"Invoke\", 3"), true)
    @Expect(delegateSource.contains("public unsafe func Invoke(p0: windows_interface.IInspectable, p1: windows_interface.IInspectable): Unit"), true)
    @Expect(delegateSource.contains("public static func new(invoke: (windows_interface.IInspectable, windows_interface.IInspectable) -> Unit): Tiny_Foundation_TypedEventHandler"), true)
    @Expect(delegateSource.contains("public interface Tiny_Foundation_TypedEventHandlerInvokerErased {\n    func __winrtThunk_Invoke(p0: CPointer<Unit>, p1: CPointer<Unit>): Int32"), true)
    @Expect(delegateSource.contains("public interface Tiny_Foundation_TypedEventHandlerInvoker <: Tiny_Foundation_TypedEventHandlerInvokerErased {\n    func Invoke(p0: windows_interface.IInspectable, p1: windows_interface.IInspectable): Unit"), true)
    @Expect(delegateSource.contains("public func __winrtThunk_Invoke(p0: CPointer<Unit>, p1: CPointer<Unit>): Int32"), false)
    @Expect(delegateSource.contains("this.Invoke(windows_core.winrtProjectGenericIn<windows_interface.IInspectable>(p0), windows_core.winrtProjectGenericIn<windows_interface.IInspectable>(p1))"), true)
    @Expect(delegateSource.contains("catch (error: windows_core.WindowsException)"), true)
    @Expect(delegateSource.contains("return error.code().value"), true)
    @Expect(delegateSource.contains("catch (_: Exception)"), true)
    @Expect(delegateSource.contains("return windows_core.E_FAIL.value"), true)
    @Expect(delegateSource.contains("try (__argBorrow0 = windows_core.winrtBorrowGenericIn<windows_interface.IInspectable>(p0))"), true)
    @Expect(delegateSource.contains("private class Tiny_Foundation_TypedEventHandlerBox <: Tiny_Foundation_TypedEventHandlerInvoker & Resource"), true)
    @Expect(delegateSource.contains("windows_core.ComObject<Tiny_Foundation_TypedEventHandlerBox>.new(box, [Tiny_Foundation_TypedEventHandler.descriptorSchema()], box.vtblPtr())"), true)
    @Expect(delegateSource.contains("windows_core.asImplFromRaw<Tiny_Foundation_TypedEventHandlerInvokerErased>(instanceRaw)"), true)
    @Expect(delegateSource.contains("OwnedTiny_Foundation_TypedEventHandler(raw)"), true)
    @Expect(delegateSource.contains("private class OwnedTiny_Foundation_TypedEventHandler <: Tiny_Foundation_TypedEventHandler"), true)
    @Expect(delegateSource.contains("super(raw, takeOwnership: true, allowManualRelease: false)"), true)
    @Expect(delegateSource.contains("Tiny_Foundation_TypedEventHandler(raw, takeOwnership: false, allowManualRelease: false)"), true)
    @Expect(delegateSource.contains("extend Tiny_Foundation_TypedEventHandler <: windows_core.Interface<Tiny_Foundation_TypedEventHandler>"), true)
    @Expect(delegateSource.contains("unsupportedDelegateAuthoringReason"), false)
    @Expect(source.contains("func add_Completed(handler: CPointer<Unit>, result: CPointer<Tiny_Foundation_EventRegistrationToken>): Int32"), true)
    @Expect(source.contains("func add_Completed(handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>"), false)
    @Expect(source.contains("func add_Completed(handler: CPointer<Unit>, sender: CPointer<Unit>, args: CPointer<Unit>, result: CPointer<Tiny_Foundation_EventRegistrationToken>): Int32"), false)
}

@Test
func testWinrtDelegateHResultInvokeProjectsRuntimeClassParameter() {
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
          "Namespace": "Tiny.Storage",
          "Name": "StreamedFileDataRequest",
          "BaseType": "System.Object",
          "IsNested": false,
          "Attributes": ["Public", "Class", "WindowsRuntime"],
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
          "Namespace": "Tiny.Storage",
          "Name": "StreamedFileDataRequestedHandler",
          "BaseType": "System.MulticastDelegate",
          "IsNested": false,
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
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
              "Name": "Invoke",
              "Attributes": ["Public", "Virtual"],
              "CustomAttributes": [],
              "ImplAttributes": [],
              "RelativeVirtualAddress": 0,
              "Import": null,
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "HResult"},
                "ParameterTypes": [
                  {"Kind": "Type", "Namespace": "Tiny.Storage", "Name": "StreamedFileDataRequest"}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "stream", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
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
    for (record in records) {
        if (record.fullName == "Tiny.Storage.StreamedFileDataRequestedHandler") {
            delegateSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(delegateSource.contains("public unsafe func Invoke(stream: Tiny_Storage_StreamedFileDataRequest): Unit"), true)
    @Expect(delegateSource.contains("public static func new(invoke: (Tiny_Storage_StreamedFileDataRequest) -> Unit): Tiny_Storage_StreamedFileDataRequestedHandler"), true)
    @Expect(delegateSource.contains("public interface Tiny_Storage_StreamedFileDataRequestedHandlerInvokerErased {\n    func __winrtThunk_Invoke(stream: CPointer<Unit>): Int32"), true)
    @Expect(delegateSource.contains("public interface Tiny_Storage_StreamedFileDataRequestedHandlerInvoker <: Tiny_Storage_StreamedFileDataRequestedHandlerInvokerErased {\n    func Invoke(stream: Tiny_Storage_StreamedFileDataRequest): Unit"), true)
    @Expect(delegateSource.contains("this.Invoke(windows_core.winrtProjectGenericIn<Tiny_Storage_StreamedFileDataRequest>(stream))"), true)
    @Expect(delegateSource.contains("public static func new(invoke: (CPointer<Unit>) -> Unit)"), false)
}

@Test
func testApplyRuntimeClassGenericSubstitutionsRewritesWholeIdentifiers() {
    let substitutions = ArrayList<RuntimeClassGenericSubstitution>()
    substitutions.add(RuntimeClassGenericSubstitution("T", "windows_interface.IInspectable"))

    // A whole-identifier `T` (parameter type, generic argument, and inside a
    // generic call) is rewritten to the concrete substitution type, while
    // `T` appearing as a sub-string of larger identifiers (`Token`,
    // `winrtBorrowGenericIn`, `GetT`) is left untouched.
    let rendered = "    public func addVectorChanged(vhnd: Windows_Foundation_Collections_VectorChangedEventHandler_1<T>): " +
        "Windows_Foundation_EventRegistrationToken {\n" +
        "        try (__argBorrow0 = windows_core.winrtBorrowGenericIn<T>(vhnd)) {\n" +
        "            let value: T = GetT()\n" +
        "        }\n" +
        "    }\n"
    let result = applyRuntimeClassGenericSubstitutions(rendered, substitutions)

    @Expect(result.contains("VectorChangedEventHandler_1<windows_interface.IInspectable>"), true)
    @Expect(result.contains("winrtBorrowGenericIn<windows_interface.IInspectable>(vhnd)"), true)
    @Expect(result.contains("let value: windows_interface.IInspectable = GetT()"), true)
    // `Windows_Foundation_EventRegistrationToken` must keep its embedded `T`s.
    @Expect(result.contains("Windows_Foundation_EventRegistrationToken"), true)
    // No bare open generic parameter should survive.
    @Expect(result.contains("<T>"), false)
    @Expect(result.contains(": T "), false)
    @Expect(result.contains(": T)"), false)
}

@Test
func testApplyRuntimeClassGenericSubstitutionsNoOpWithoutSubstitutions() {
    let rendered = "    public func GetAt(index: UInt32): T {\n        return defaultInterface()\n    }\n"
    @Expect(
        applyRuntimeClassGenericSubstitutions(rendered, ArrayList<RuntimeClassGenericSubstitution>()),
        rendered
    )
}

@Test
func testRuntimeClassParameterizedDefaultInterfaceMembersUseConcreteType() {
    // A runtime class whose DEFAULT interface is a parameterized collection
    // (IObservableVector<T> closed over a concrete IThing) must render its
    // inherited members with the concrete element type, not the open generic
    // parameter that the interface definition uses.
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "Example.Collections",
          "Name": "IThing",
          "Attributes": ["Public", "Interface", "Abstract", "WindowsRuntime"],
          "BaseType": null,
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
          "Namespace": "Example.Collections",
          "Name": "IObservableVector",
          "Attributes": ["Public", "Interface", "Abstract", "WindowsRuntime"],
          "BaseType": null,
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Append",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "Signature": {
                "ReturnType": {"Kind": "Void"},
                "Parameters": [
                  {"Kind": "GenericParameter", "Name": "T"}
                ]
              },
              "CustomAttributes": [],
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null}
              ]
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [{"Name": "T"}],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Collections",
          "Name": "Bag",
          "MetadataToken": "0x02000008",
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "BaseType": "System.Object",
          "IsNested": false,
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {
                "Kind": "TypeSpecification",
                "TypeSpecification": {
                  "Signature": {
                    "Kind": "Type",
                    "Namespace": "Example.Collections",
                    "Name": "IObservableVector",
                    "TypeArguments": [
                      {"Kind": "Type", "Namespace": "Example.Collections", "Name": "IThing"}
                    ]
                  },
                  "CustomAttributes": []
                }
              },
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
        if (record.fullName == "Example.Collections.Bag") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("public class Example_Collections_Bag <: windows_interface.InterfaceWrapperBase"), true)
    @Expect(classSource.contains("public func Append(value: Example_Collections_IThing): Unit"), true)
    // The inherited member body must not leak the open generic parameter.
    @Expect(classSource.contains("public func Append(value: T)"), false)
    @Expect(classSource.contains("winrtBorrowGenericIn<Example_Collections_IThing>(value)"), true)
    @Expect(classSource.contains("winrtBorrowGenericIn<T>(value)"), false)
}

// A runtime class whose parameterized default interface closes its generic
// element over a primitive value (IVector<Single>) must bridge the type-erased
// generic GetAt OUT slot through winrtTakeGenericOut<Float32>, not the
// reference-handle fromAbiTakeWinrtHandle path (Float32 has no such method).
@Test
func testRuntimeClassGenericOutPrimitiveElementUsesGenericBridge() {
    let classSource = renderGenericCollectionRuntimeClassSource(
        "FloatBag",
        "0x02000040",
        ##"{"Kind": "Primitive", "Name": "Single"}"##
    )

    @Expect(classSource.contains("public func GetAt(index: UInt32): Float32"), true)
    @Expect(classSource.contains("windows_core.winrtTakeGenericOut<Float32>(CPointer<CPointer<Unit>>(inout result__))"), true)
    // The reference-handle bridge must not be used for a value element.
    @Expect(classSource.contains("Float32.fromAbiTakeWinrtHandle"), false)
    // Failure cleanup dispatches through the bridge (no-op for value elements).
    @Expect(classSource.contains("windows_core.winrtReleaseFailedGenericOut<Float32>(CPointer<CPointer<Unit>>(inout result__))"), true)
    // The slot must stay type-erased; no winrtReleaseGenericOut<Float32> handle release.
    @Expect(classSource.contains("winrtReleaseGenericOut<Float32>"), false)
}

// IMap/IVector closed over String returns its generic OUT through the HString
// handle bridge; winrtTakeGenericOut<windows_core.HString> resolves to the
// system-handle take path, which is the correct string ABI.
@Test
func testRuntimeClassGenericOutStringElementUsesHStringBridge() {
    let classSource = renderGenericCollectionRuntimeClassSource(
        "StringBag",
        "0x02000041",
        ##"{"Kind": "Primitive", "Name": "String"}"##
    )

    @Expect(classSource.contains("public func GetAt(index: UInt32): windows_core.HString"), true)
    @Expect(classSource.contains("windows_core.winrtTakeGenericOut<windows_core.HString>(CPointer<CPointer<Unit>>(inout result__))"), true)
    @Expect(classSource.contains("windows_core.winrtReleaseFailedGenericOut<windows_core.HString>(CPointer<CPointer<Unit>>(inout result__))"), true)
}

// IVector.GetMany is a caller-allocated fill buffer: the projected method
// exposes (itemsSize, items) and forwards them straight to the vtable slot,
// rather than the allocate-and-return (CPointer<&size>, CPointer<&data>) shape.
@Test
func testRuntimeClassGenericGetManyUsesCallerAllocatedBuffer() {
    let classSource = renderGenericCollectionRuntimeClassSource(
        "FloatBag2",
        "0x02000042",
        ##"{"Kind": "Primitive", "Name": "Single"}"##
    )

    // Projected public signature is the caller-allocated fill buffer. The
    // element is the open generic parameter, so the buffer is the type-erased
    // CPointer<Unit> the generic vtable slot accepts, not an allocate-and-return
    // pair.
    @Expect(classSource.contains("public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): UInt32"), true)
    // The buffer is forwarded straight through to the vtable slot.
    @Expect(classSource.contains("interface__.GetMany(startIndex, itemsSize, items, CPointer<UInt32>(inout result__))"), true)
    // No allocate-and-return OutSlot<Array<...>> shape for GetMany.
    @Expect(classSource.contains("items: windows_core.OutSlot<Array<Float32>>"), false)
    @Expect(classSource.contains("OutSlot<Array<"), false)
    // The element's range helpers are concretized to the closed element type so
    // value elements no-op and handle elements release.
    @Expect(classSource.contains("windows_core.winrtPrepareGenericOutRange<Float32>(items, itemsSize)"), true)
    @Expect(classSource.contains("windows_core.winrtReleaseGenericOutRange<Float32>(items, itemsSize)"), true)
}

// An array-returning runtime-class method must release its allocate-and-return
// output through the array names (__returnData / __returnSize), never the
// undeclared scalar result__ slot.
@Test
func testRuntimeClassArrayReturnFailureCleanupUsesArrayNames() {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "Example.Spatial",
          "Name": "PointInt32",
          "Attributes": ["Public", "SequentialLayout", "WindowsRuntime"],
          "BaseType": "System.ValueType",
          "CustomAttributes": [],
          "Fields": [
            {"Name": "X", "Attributes": ["Public"], "Signature": {"Kind": "Primitive", "Name": "Int32"}},
            {"Name": "Y", "Attributes": ["Public"], "Signature": {"Kind": "Primitive", "Name": "Int32"}}
          ],
          "Methods": [],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Spatial",
          "Name": "IConverter",
          "Attributes": ["Public", "Interface", "Abstract", "WindowsRuntime"],
          "BaseType": null,
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "Convert",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "Signature": {
                "ReturnType": {"Kind": "SZArray", "Type": {"Kind": "Type", "Namespace": "Example.Spatial", "Name": "PointInt32"}},
                "Parameters": []
              },
              "CustomAttributes": [],
              "Parameters": [
                {"Name": "result", "SequenceNumber": 0, "Attributes": [], "CustomAttributes": [], "DefaultValue": null}
              ]
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Spatial",
          "Name": "Converter",
          "MetadataToken": "0x02000050",
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "BaseType": "System.Object",
          "IsNested": false,
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {
                "Kind": "Type",
                "Namespace": "Example.Spatial",
                "Name": "IConverter"
              },
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
        if (record.fullName == "Example.Spatial.Converter") {
            classSource = renderSymbolImpl(record, symbolsByName)
        }
    }

    @Expect(classSource.contains("public func Convert(): Array<Example_Spatial_PointInt32>"), true)
    @Expect(classSource.contains("var __returnData = CPointer<Example_Spatial_PointInt32>()"), true)
    @Expect(classSource.contains("var __returnSize = 0u32"), true)
    // The array-return failure cleanup must use the array names, never result__.
    @Expect(classSource.contains("__returnData.isNotNull()"), true)
    @Expect(classSource.contains("result__"), false)
}

// Build an IVector-shaped parameterized default interface (GetAt -> T,
// GetMany caller-allocated) closed over `elementJson`, returning the rendered
// runtime-class source for the wrapping sealed class.
func renderGenericCollectionRuntimeClassSource(
    className: String,
    classToken: String,
    elementJson: String
): String {
    let json = ##"{
      "winmd_file": "Tiny.winmd",
      "winmd_sha256": "abcd",
      "tool_version": "1",
      "schema_version": "1",
      "source_set": "winmd_main",
      "types": [
        {
          "Namespace": "Example.Collections",
          "Name": "IVector",
          "Attributes": ["Public", "Interface", "Abstract", "WindowsRuntime"],
          "BaseType": null,
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetAt",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "Signature": {
                "ReturnType": {"Kind": "GenericParameter", "Name": "T"},
                "Parameters": [{"Kind": "Primitive", "Name": "UInt32"}]
              },
              "CustomAttributes": [],
              "Parameters": [
                {"Name": "index", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "result", "SequenceNumber": 0, "Attributes": [], "CustomAttributes": [], "DefaultValue": null}
              ]
            },
            {
              "Name": "GetMany",
              "Attributes": ["Public", "Virtual", "NewSlot", "Abstract"],
              "Signature": {
                "ReturnType": {"Kind": "Primitive", "Name": "UInt32"},
                "Parameters": [
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "SZArray", "Type": {"Kind": "GenericParameter", "Name": "T"}}
                ]
              },
              "CustomAttributes": [],
              "Parameters": [
                {"Name": "startIndex", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": [], "DefaultValue": null},
                {"Name": "items", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [{"Type": "Windows.Foundation.Metadata.LengthIsAttribute", "FixedArguments": [], "NamedArguments": []}], "DefaultValue": null},
                {"Name": "result", "SequenceNumber": 0, "Attributes": [], "CustomAttributes": [], "DefaultValue": null}
              ]
            }
          ],
          "NestedTypes": [],
          "GenericParameters": [{"Name": "T"}],
          "Events": [],
          "Properties": []
        },
        {
          "Namespace": "Example.Collections",
          "Name": "__CLASS__",
          "MetadataToken": "__TOKEN__",
          "Attributes": ["Public", "Class", "Sealed", "WindowsRuntime"],
          "BaseType": "System.Object",
          "IsNested": false,
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [
            {
              "Interface": {
                "Kind": "TypeSpecification",
                "TypeSpecification": {
                  "Signature": {
                    "Kind": "Type",
                    "Namespace": "Example.Collections",
                    "Name": "IVector",
                    "TypeArguments": [__ELEMENT__]
                  },
                  "CustomAttributes": []
                }
              },
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
    let resolved = json
        .replace("__CLASS__", className)
        .replace("__TOKEN__", classToken)
        .replace("__ELEMENT__", elementJson)
    let files = ArrayList<WinmdFileRecord>()
    files.add(parseWinmdJson(resolved, "tiny"))
    let records = buildSymbolRecords(files)
    let symbolsByName = cliTestRecordsByName(records)
    for (record in records) {
        if (record.fullName == "Example.Collections.${className}") {
            return renderSymbolImpl(record, symbolsByName)
        }
    }
    return ""
}
