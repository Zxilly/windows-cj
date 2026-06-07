package windows_bindgen

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

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
    let deps = collectSupportDependencyNames("windows", selected, selectedByName)
    let cjpm = renderCjpmToml("windows", supportDeps: deps)
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
    @Expect(cjpm.contains("windows_libloading = { path = \"../../windows_libloading\" }"), true)
    @Expect(cjpm.contains("-lkernel32"), false)
}

@Test
func testPInvokeRendererSkipsForceInlineAndOrdinalImports() {
    let methods = ArrayList<MethodRecord>()
    let returnType = SignatureRecord("Primitive", name: "UInt32")
    let signature = MethodSignatureRecord(returnType)
    methods.add(MethodRecord(
        "InlineOnly",
        signature,
        methodImport: Some(MethodImportRecord("InlineOnly", "FORCEINLINE", callingConvention: "CDecl"))
    ))
    methods.add(MethodRecord(
        "OrdinalOnly",
        signature,
        methodImport: Some(MethodImportRecord("#12", "native.dll", callingConvention: "CDecl"))
    ))
    methods.add(MethodRecord(
        "GetTickCount",
        signature,
        methodImport: Some(MethodImportRecord("GetTickCount", "KERNEL32.dll", callingConvention: "CDecl"))
    ))
    let typeAttributes = ArrayList<String>()
    typeAttributes.add("Public")
    typeAttributes.add("Class")
    let typeDef = TypeDefinitionRecord(
        "Example.Native",
        "Apis",
        baseType: "System.Object",
        hasBaseType: true,
        attributes: typeAttributes,
        methods: methods
    )
    let symbol = SymbolRecord(
        "Example.Native.Apis",
        "Example.Native",
        "Apis",
        "Example_Native_Apis",
        [],
        typeDef: Some(typeDef)
    )
    let records = ArrayList<SymbolRecord>()
    records.add(symbol)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(symbol, symbolsByName)

    @Expect(source.contains("public static func GetTickCount(): UInt32"), true)
    @Expect(source.contains("windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetTickCount\")"), true)
    @Expect(source.contains("InlineOnly"), false)
    @Expect(source.contains("FORCEINLINE"), false)
    @Expect(source.contains("OrdinalOnly"), false)
    @Expect(source.contains("\"#12\""), false)
}

@Test
func testPInvokeCDeclCallingConventionUsesDefaultCFunc() {
    let symbol = cliTestPInvokeApiSymbol("CallingConventionCDecl")
    let records = ArrayList<SymbolRecord>()
    records.add(symbol)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(symbol, symbolsByName)

    @Expect(source.contains("let proc = CFunc<() -> Int32>(windows_libloading.resolveProc(\"native.dll\", \"CallNative\"))"), true)
    @Expect(source.contains("return unsafe { proc() }"), true)
}

@Test
func testPInvokeResolvedProcLocalAvoidsParameterNameCollision() {
    let parameters = ArrayList<SignatureRecord>()
    parameters.add(SignatureRecord("Primitive", name: "UInt32"))
    let metadataParameters = ArrayList<ParameterRecord>()
    metadataParameters.add(ParameterRecord("proc", sequenceNumber: 1))
    let methods = ArrayList<MethodRecord>()
    methods.add(MethodRecord(
        "CallNative",
        MethodSignatureRecord(
            SignatureRecord("Primitive", name: "Int32"),
            parameters: parameters,
            requiredParameterCount: 1
        ),
        parameters: metadataParameters,
        methodImport: Some(MethodImportRecord("CallNative", "native.dll", callingConvention: "CDecl"))
    ))
    let typeAttributes = ArrayList<String>()
    typeAttributes.add("Public")
    typeAttributes.add("Class")
    let typeDef = TypeDefinitionRecord(
        "Example.Native",
        "Apis",
        baseType: "System.Object",
        hasBaseType: true,
        attributes: typeAttributes,
        methods: methods
    )
    let symbol = SymbolRecord(
        "Example.Native.Apis",
        "Example.Native",
        "Apis",
        "Example_Native_Apis",
        [],
        typeDef: Some(typeDef)
    )
    let records = ArrayList<SymbolRecord>()
    records.add(symbol)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(symbol, symbolsByName)

    @Expect(source.contains("public static func CallNative(proc: UInt32): Int32"), true)
    @Expect(source.contains("let proc__ = CFunc<(UInt32) -> Int32>(windows_libloading.resolveProc(\"native.dll\", \"CallNative\"))"), true)
    @Expect(source.contains("return unsafe { proc__(proc) }"), true)
    @Expect(source.contains("let proc = CFunc<(UInt32) -> Int32>"), false)
}

@Test
func testPInvokeFunctionPointerParameterUsesCFuncSignature() {
    let callbackSignature = MethodSignatureRecord(
        SignatureRecord("Primitive", name: "Int32"),
        parameters: ArrayList<SignatureRecord>([
            SignatureRecord("Primitive", name: "Int32"),
            SignatureRecord("Pointer")
        ]),
        requiredParameterCount: 2
    )
    let parameters = ArrayList<SignatureRecord>()
    parameters.add(SignatureRecord("FunctionPointer", functionPointerSignature: Some(callbackSignature)))
    let metadataParameters = ArrayList<ParameterRecord>()
    metadataParameters.add(ParameterRecord("callback", sequenceNumber: 1))
    let methods = ArrayList<MethodRecord>()
    methods.add(MethodRecord(
        "CallWithCallback",
        MethodSignatureRecord(
            SignatureRecord("Primitive", name: "Int32"),
            parameters: parameters,
            requiredParameterCount: 1
        ),
        parameters: metadataParameters,
        methodImport: Some(MethodImportRecord("CallWithCallback", "native.dll", callingConvention: "CDecl"))
    ))
    let typeAttributes = ArrayList<String>()
    typeAttributes.add("Public")
    typeAttributes.add("Class")
    let typeDef = TypeDefinitionRecord(
        "Example.Native",
        "Apis",
        baseType: "System.Object",
        hasBaseType: true,
        attributes: typeAttributes,
        methods: methods
    )
    let symbol = SymbolRecord(
        "Example.Native.Apis",
        "Example.Native",
        "Apis",
        "Example_Native_Apis",
        [],
        typeDef: Some(typeDef)
    )
    let records = ArrayList<SymbolRecord>()
    records.add(symbol)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(symbol, symbolsByName)

    @Expect(source.contains("callback: CFunc<(Int32, CPointer<Unit>) -> Int32>"), true)
    @Expect(source.contains("let proc = CFunc<(CFunc<(Int32, CPointer<Unit>) -> Int32>) -> Int32>"), true)
    @Expect(source.contains("return unsafe { proc(callback) }"), true)
}

@Test
func testPInvokeParametersEscapeCangjieReservedIdentifiers() {
    let parameters = ArrayList<SignatureRecord>()
    parameters.add(SignatureRecord("Primitive", name: "Int32"))
    parameters.add(SignatureRecord("Primitive", name: "Int32"))
    let metadataParameters = ArrayList<ParameterRecord>()
    metadataParameters.add(ParameterRecord("prop", sequenceNumber: 1))
    metadataParameters.add(ParameterRecord("This", sequenceNumber: 2))
    let methods = ArrayList<MethodRecord>()
    methods.add(MethodRecord(
        "CallNative",
        MethodSignatureRecord(
            SignatureRecord("Primitive", name: "Int32"),
            parameters: parameters,
            requiredParameterCount: 2
        ),
        parameters: metadataParameters,
        methodImport: Some(MethodImportRecord("CallNative", "native.dll", callingConvention: "CDecl"))
    ))
    let typeAttributes = ArrayList<String>()
    typeAttributes.add("Public")
    typeAttributes.add("Class")
    let typeDef = TypeDefinitionRecord(
        "Example.Native",
        "Apis",
        baseType: "System.Object",
        hasBaseType: true,
        attributes: typeAttributes,
        methods: methods
    )
    let symbol = SymbolRecord(
        "Example.Native.Apis",
        "Example.Native",
        "Apis",
        "Example_Native_Apis",
        [],
        typeDef: Some(typeDef)
    )
    let records = ArrayList<SymbolRecord>()
    records.add(symbol)
    let symbolsByName = cliTestRecordsByName(records)
    let source = renderSymbolImpl(symbol, symbolsByName)

    @Expect(source.contains("public static func CallNative(prop_: Int32, This_: Int32): Int32"), true)
    @Expect(source.contains("return unsafe { proc(prop_, This_) }"), true)
}

@Test
func testPInvokeUnsupportedCallingConventionIsRejected() {
    let symbol = cliTestPInvokeApiSymbol("CallingConventionStdCall")
    let records = ArrayList<SymbolRecord>()
    records.add(symbol)
    let symbolsByName = cliTestRecordsByName(records)

    @Expect(cliTestThrows({ => let _ = renderSymbolImpl(symbol, symbolsByName) }), true)
}

@Test
func testPInvokeWinApiCallingConventionRejects32BitDynamicCFunc() {
    let symbol = cliTestPInvokeApiSymbol("CallingConventionWinApi")
    let records = ArrayList<SymbolRecord>()
    records.add(symbol)
    let symbolsByName = cliTestRecordsByName(records)

    @Expect(cliTestThrows({ => let _ = renderSymbolImpl(symbol, symbolsByName, TargetAbiOptions.pointer32()) }), true)
}

@Test
func testPInvokeErgonomicResultVoidWrapperIsGeneratedFromHresult() {
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
          "Namespace": "Example.Pwrap",
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
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "reserved", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "flags", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "InitializeWinrt",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "InitializeWinrt",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "combase.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Foundation", "Name": "HResult", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "flags", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "MFCreateAttributes",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "MFCreateAttributes",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "mfplat.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Example.Pwrap", "Name": "IMFAttributes", "Comment": "TypeReference"}},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "ppMFAttributes", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [
                  {"Type": "Windows.Win32.Foundation.Metadata.ComOutPtrAttribute", "FixedArguments": [], "NamedArguments": []}
                ]},
                {"Name": "initialSize", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Pwrap.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func CoInitializeEx(reserved: CPointer<Unit>, flags: UInt32): Int32"), true)
    @Expect(source.contains("public static func CoInitializeExChecked(reserved: CPointer<Unit>, flags: UInt32): Unit {"), true)
    @Expect(source.contains("let hr__ = Example_Pwrap_Apis.CoInitializeEx(reserved, flags)"), true)
    @Expect(source.contains("windows_core.HRESULT(hr__).check()"), true)
    @Expect(source.contains("public static func InitializeWinrt(flags: UInt32): Int32"), true)
    @Expect(source.contains("public static func InitializeWinrtChecked(flags: UInt32): Unit {"), true)
    @Expect(source.contains("let hr__ = Example_Pwrap_Apis.InitializeWinrt(flags)"), true)
    @Expect(source.contains("public static func MFCreateAttributes(ppMFAttributes: CPointer<Unit>, initialSize: UInt32): Int32"), true)
    @Expect(source.contains("public static func MFCreateAttributesChecked(ppMFAttributes: CPointer<Unit>, initialSize: UInt32): Unit {"), true)
    @Expect(source.contains("if (CPointer<CPointer<Unit>>(ppMFAttributes).isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        unsafe { CPointer<CPointer<Unit>>(ppMFAttributes).write(CPointer<Unit>()) }\n        let hr__ = Example_Pwrap_Apis.MFCreateAttributes(ppMFAttributes, initialSize)"), true)
    @Expect(source.contains("if (resultHr__.failed()) {\n            windows_core.releaseFailedComOutSlot(CPointer<CPointer<Unit>>(ppMFAttributes))\n        }\n        resultHr__.check()"), true)
    @Expect(source.contains("resultHr__.check()\n        if (unsafe { CPointer<CPointer<Unit>>(ppMFAttributes).read() }.isNull()) {\n            windows_core.releaseFailedComOutSlot(CPointer<CPointer<Unit>>(ppMFAttributes))\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }"), true)
}

@Test
func testPInvokeErgonomicResultVoidWrapperPreservesMultipleSuccessHresult() {
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
          "Namespace": "Example.Pwrap",
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
              "CustomAttributes": [
                {"Type": "Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute", "FixedArguments": [], "NamedArguments": []}
              ],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CoInitializeEx",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "reserved", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "flags", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Pwrap.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func CoInitializeExChecked(reserved: CPointer<Unit>, flags: UInt32): windows_core.HRESULT {"), true)
    @Expect(source.contains("let hr__ = Example_Pwrap_Apis.CoInitializeEx(reserved, flags)"), true)
    @Expect(source.contains("let resultHr__ = windows_core.HRESULT(hr__)\n        resultHr__.check()\n        return resultHr__"), true)
    @Expect(source.contains("public static func CoInitializeExChecked(reserved: CPointer<Unit>, flags: UInt32): Unit {"), false)
}

@Test
func testPInvokeErgonomicResultValueWrapperIsGeneratedFromRetval() {
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
          "Namespace": "Example.Retval",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetCount",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetCount",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "count", "SequenceNumber": 1, "Attributes": ["Out", "Retval"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Retval.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func GetCount(count: CPointer<Int32>): Int32"), true)
    @Expect(source.contains("public static func GetCountChecked(): Int32 {"), true)
    @Expect(source.contains("Example_Retval_Apis.GetCount(CPointer<Int32>(inout result__))"), true)
    @Expect(source.contains("return result__"), true)
}

@Test
func testPInvokeErgonomicResultValueWrapperPreservesMultipleSuccessHresult() {
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
          "Namespace": "Example.Retval",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetCount",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [
                {"Type": "Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute", "FixedArguments": [], "NamedArguments": []}
              ],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetCount",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "count", "SequenceNumber": 1, "Attributes": ["Out", "Retval"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Retval.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func GetCountChecked(): (windows_core.HRESULT, Int32) {"), true)
    @Expect(source.contains("let resultHr__ = windows_core.HRESULT(hr__)\n        resultHr__.check()\n        return (resultHr__, result__)"), true)
    @Expect(source.contains("public static func GetCountChecked(): Int32 {"), false)
}

@Test
func testPInvokeErgonomicResultValueWrapperReleasesComRetvalOnFailedHRESULT() {
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
          "Namespace": "Example.Retval",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetObject",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetObject",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["Out", "Retval"], "CustomAttributes": [
                  {"Type": "Windows.Win32.Foundation.Metadata.ComOutPtrAttribute", "FixedArguments": [], "NamedArguments": []}
                ]}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Retval.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func GetObjectChecked(): CPointer<Unit> {"), true)
    @Expect(source.contains("var result__: CPointer<Unit> = CPointer<Unit>()"), true)
    @Expect(source.contains("Example_Retval_Apis.GetObject(unsafe { CPointer<Unit>(CPointer<CPointer<Unit>>(inout result__)) })"), true)
    @Expect(source.contains("let resultHr__ = windows_core.HRESULT(hr__)"), true)
    @Expect(source.contains("if (resultHr__.failed()) {\n            if (result__.isNotNull()) {\n                windows_core.releaseFailedComOutSlot(CPointer<CPointer<Unit>>(inout result__))\n            }\n        }"), true)
    @Expect(source.contains("resultHr__.check()"), true)
    @Expect(source.contains("resultHr__.check()\n        if (result__.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        return result__"), true)
    @Expect(source.contains("return result__"), true)
}

@Test
func testPInvokeErgonomicResultValueWrapperReleasesLeadingComOutOnFailedHRESULT() {
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
          "Namespace": "Example.Retval",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetPair",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetPair",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}},
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "object", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": [
                  {"Type": "Windows.Win32.Foundation.Metadata.ComOutPtrAttribute", "FixedArguments": [], "NamedArguments": []}
                ]},
                {"Name": "ok", "SequenceNumber": 2, "Attributes": ["Out", "Retval"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Retval.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func GetPairChecked(object: CPointer<Unit>): Int32 {"), true)
    @Expect(source.contains("if (CPointer<CPointer<Unit>>(object).isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        unsafe { CPointer<CPointer<Unit>>(object).write(CPointer<Unit>()) }\n        let hr__ = Example_Retval_Apis.GetPair(object, CPointer<Int32>(inout result__))"), true)
    @Expect(source.contains("let resultHr__ = windows_core.HRESULT(hr__)"), true)
    @Expect(source.contains("if (resultHr__.failed()) {\n            windows_core.releaseFailedComOutSlot(CPointer<CPointer<Unit>>(object))\n        }\n        resultHr__.check()"), true)
    @Expect(source.contains("resultHr__.check()\n        if (unsafe { CPointer<CPointer<Unit>>(object).read() }.isNull()) {\n            windows_core.releaseFailedComOutSlot(CPointer<CPointer<Unit>>(object))\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        return result__"), true)
    @Expect(source.contains("return result__"), true)
}

@Test
func testPInvokeErgonomicResultValueWrapperReleasesStringHandleRetvalsOnFailedHRESULT() {
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
          "Namespace": "Example.Retval",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "GetName",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetName",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "HSTRING", "Comment": "TypeReference"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["Out", "Retval"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "GetBstr",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetBstr",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "oleaut32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR", "Comment": "TypeReference"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "value", "SequenceNumber": 1, "Attributes": ["Out", "Retval"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Retval.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func GetNameChecked(): windows_core.HString {"), true)
    @Expect(source.contains("let hr__ = Example_Retval_Apis.GetName(CPointer<CPointer<Unit>>(inout result__))"), true)
    @Expect(source.contains("if (resultHr__.failed()) {\n            if (result__.isNotNull()) {\n                windows_core.releaseSystemHStringHandle(result__)\n                result__ = CPointer<Unit>()\n            }\n        }\n        resultHr__.check()"), true)
    @Expect(source.contains("return windows_core.HString.fromSystemHandleTake(result__)"), true)
    @Expect(source.contains("public static func GetBstrChecked(): windows_strings.BSTR {"), true)
    @Expect(source.contains("let hr__ = Example_Retval_Apis.GetBstr(CPointer<CPointer<Unit>>(inout result__))"), true)
    @Expect(source.contains("if (resultHr__.failed()) {\n            if (result__.isNotNull()) {\n                let failedBstr__ = windows_strings.BSTR.fromRawTake(CPointer<UInt16>(result__))\n                failedBstr__.close()\n                result__ = CPointer<Unit>()\n            }\n        }\n        resultHr__.check()"), true)
    @Expect(source.contains("return windows_strings.BSTR.fromRawTake(CPointer<UInt16>(result__))"), true)
}

@Test
func testPInvokeErgonomicWrappersReleaseLeadingStringHandleOutsOnFailedHRESULT() {
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
          "Namespace": "Example.Retval",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "FillStrings",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "FillStrings",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "HSTRING", "Comment": "TypeReference"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR", "Comment": "TypeReference"}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "name", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": []},
                {"Name": "text", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "TryFillStrings",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "TryFillStrings",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.System.WinRT", "Name": "HSTRING", "Comment": "TypeReference"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BSTR", "Comment": "TypeReference"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"}}
                ],
                "RequiredParameterCount": 3
              },
              "Parameters": [
                {"Name": "name", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": []},
                {"Name": "text", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": []},
                {"Name": "ok", "SequenceNumber": 3, "Attributes": ["Out", "Retval"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Retval.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func FillStringsChecked(name: CPointer<CPointer<Unit>>, text: CPointer<CPointer<Unit>>): Unit {"), true)
    @Expect(source.contains("var nullOutSlot__ = false\n        if (name.isNull()) {\n            nullOutSlot__ = true\n        } else {\n            unsafe { name.write(CPointer<Unit>()) }\n        }\n        if (text.isNull()) {\n            nullOutSlot__ = true\n        } else {\n            unsafe { text.write(CPointer<Unit>()) }\n        }\n        if (nullOutSlot__) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        let hr__ = Example_Retval_Apis.FillStrings(name, text)"), true)
    @Expect(source.contains("if (name.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        unsafe { name.write(CPointer<Unit>()) }\n        if (text.isNull())"), false)
    @Expect(source.contains("public static func TryFillStringsChecked(name: CPointer<CPointer<Unit>>, text: CPointer<CPointer<Unit>>): Int32 {"), true)
    @Expect(source.contains("let hr__ = Example_Retval_Apis.TryFillStrings(name, text, CPointer<Int32>(inout result__))"), true)
    @Expect(source.contains("if (name.isNotNull()) {\n                let failedString__ = unsafe { name.read() }\n                if (failedString__.isNotNull()) {\n                    windows_core.releaseSystemHStringHandle(failedString__)\n                    unsafe { name.write(CPointer<Unit>()) }\n                }\n            }"), true)
    @Expect(source.contains("if (text.isNotNull()) {\n                let failedString__ = unsafe { text.read() }\n                if (failedString__.isNotNull()) {\n                    let failedBstr__ = windows_strings.BSTR.fromRawTake(CPointer<UInt16>(failedString__))\n                    failedBstr__.close()\n                    unsafe { text.write(CPointer<Unit>()) }\n                }\n            }"), true)
    @Expect(cliTestCountOccurrences(source, "windows_core.releaseSystemHStringHandle(failedString__)"), 2)
    @Expect(cliTestCountOccurrences(source, "failedBstr__.close()"), 2)
}

@Test
func testPInvokeErgonomicQueryWrapperHandlesIidPlusComOutPtr() {
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
          "Namespace": "Example.Query",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CoCreateInstance",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CoCreateInstance",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "ole32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid", "Comment": "TypeReference"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "riid", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "ppv", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [
                  {"Type": "Windows.Win32.Foundation.Metadata.ComOutPtrAttribute", "FixedArguments": [], "NamedArguments": []}
                ]}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Query.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func CoCreateInstance("), true)
    @Expect(source.contains("public static func CoCreateInstanceChecked<T>"), true)
    @Expect(source.contains(": T where T <: windows_interface.ComInterface"), true)
    @Expect(source.contains("var iid__ = descriptor.iid"), true)
    @Expect(source.contains("var raw__: CPointer<Unit> = CPointer<Unit>()"), true)
    @Expect(source.contains("let resultHr__ = windows_core.HRESULT(hr__)"), true)
    @Expect(source.contains("if (resultHr__.failed() && raw__.isNotNull()) {\n            let _ = descriptor.releasePointer(raw__)\n            raw__ = CPointer<Unit>()\n        }"), true)
    @Expect(source.contains("resultHr__.check()"), true)
    @Expect(source.contains("resultHr__.check()\n        if (raw__.isNull()) {\n            throw windows_core.WindowsException(windows_core.E_POINTER)\n        }\n        return descriptor.takeFromAbi(raw__)"), true)
    @Expect(source.contains("descriptor.takeFromAbi(raw__)"), true)
}

@Test
func testPInvokeErgonomicQueryWrapperRejectsClassIdComOutPtrShape() {
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
          "Namespace": "Example.Query",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CreateByClassId",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CreateByClassId",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid", "Comment": "TypeReference"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "rclsid", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "ppv", "SequenceNumber": 2, "Attributes": ["Out"], "CustomAttributes": [
                  {"Type": "Windows.Win32.Foundation.Metadata.ComOutPtrAttribute", "FixedArguments": [], "NamedArguments": []}
                ]}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Query.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func CreateByClassId("), true)
    @Expect(source.contains("public static func CreateByClassIdChecked<T>"), false)
    @Expect(source.contains("descriptor: windows_interface.InterfaceDescriptor<T>"), false)
    @Expect(source.contains("public static func CreateByClassIdChecked("), true)
    @Expect(source.contains("unsafe { CPointer<CPointer<Unit>>(ppv).write(CPointer<Unit>()) }\n        let hr__ = Example_Query_Apis.CreateByClassId(rclsid, ppv)"), true)
    @Expect(source.contains("let resultHr__ = windows_core.HRESULT(hr__)"), true)
    @Expect(source.contains("if (resultHr__.failed()) {\n            windows_core.releaseFailedComOutSlot(CPointer<CPointer<Unit>>(ppv))\n        }\n        resultHr__.check()"), true)
    @Expect(source.contains("let hr__ = Example_Query_Apis.CreateByClassId(rclsid, ppv)"), true)
}

@Test
func testPInvokeErgonomicQueryWrapperPreservesLeadingParameters() {
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
          "Namespace": "Example.Query",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CreateWithContext",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CreateWithContext",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "example.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "HRESULT", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Pointer", "Type": {"Kind": "Type", "Namespace": "System", "Name": "Guid", "Comment": "TypeReference"}},
                  {"Kind": "Pointer", "Type": {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}}
                ],
                "RequiredParameterCount": 4
              },
              "Parameters": [
                {"Name": "context", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "flags", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "riid", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "ppv", "SequenceNumber": 4, "Attributes": ["Out"], "CustomAttributes": [
                  {"Type": "Windows.Win32.Foundation.Metadata.ComOutPtrAttribute", "FixedArguments": [], "NamedArguments": []}
                ]}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.Query.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func CreateWithContextChecked<T>(context: CPointer<Unit>, flags: UInt32, descriptor: windows_interface.InterfaceDescriptor<T>): T where T <: windows_interface.ComInterface"), true)
    @Expect(source.contains("let hr__ = Example_Query_Apis.CreateWithContext(context, flags, unsafe { CPointer<Unit>(CPointer<windows_interface.GUID>(inout iid__)) }, unsafe { CPointer<Unit>(CPointer<CPointer<Unit>>(inout raw__)) })"), true)
    @Expect(source.contains("return descriptor.takeFromAbi(raw__)"), true)
}

@Test
func testPInvokeErgonomicLastErrorWrapperWrapsBoolWithErrorFromThread() {
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
          "Namespace": "Example.LastErr",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "CloseHandle",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CloseHandle",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "handle", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "IsTokenRestricted",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "IsTokenRestricted",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "advapi32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "token", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "CancelWaitableTimer",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "CancelWaitableTimer",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "handle", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "ReadFile",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "ReadFile",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "ConnectNamedPipe",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "ConnectNamedPipe",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "GetQueuedCompletionStatus",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetQueuedCompletionStatus",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "GetQueuedCompletionStatusEx",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetQueuedCompletionStatusEx",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "GetMessageW",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [
                {"Type": "Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute", "FixedArguments": [], "NamedArguments": []}
              ],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "GetMessageW",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "user32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}}
                ],
                "RequiredParameterCount": 1
              },
              "Parameters": [
                {"Name": "lpMsg", "SequenceNumber": 1, "Attributes": ["Out"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "TrackPopupMenu",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [
                {"Type": "Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute", "FixedArguments": [], "NamedArguments": []}
              ],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "TrackPopupMenu",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "user32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "TrackPopupMenuEx",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [
                {"Type": "Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute", "FixedArguments": [], "NamedArguments": []}
              ],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "TrackPopupMenuEx",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "user32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "AttachThreadInput",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [
                {"Type": "Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute", "FixedArguments": [], "NamedArguments": []}
              ],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "AttachThreadInput",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi"],
                "Module": {"Name": "user32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Primitive", "Name": "UInt32"},
                  {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"}
                ],
                "RequiredParameterCount": 3
              },
              "Parameters": [
                {"Name": "idAttach", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "idAttachTo", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "fAttach", "SequenceNumber": 3, "Attributes": ["In"], "CustomAttributes": []}
              ],
              "GenericParameters": []
            },
            {
              "Name": "ClosePrivateNamespace",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "ClosePrivateNamespace",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "kernel32.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOLEAN", "Comment": "TypeReference"},
                "ParameterTypes": [
                  {"Kind": "Pointer", "Type": {"Kind": "Primitive", "Name": "Void"}},
                  {"Kind": "Primitive", "Name": "UInt32"}
                ],
                "RequiredParameterCount": 2
              },
              "Parameters": [
                {"Name": "handle", "SequenceNumber": 1, "Attributes": ["In"], "CustomAttributes": []},
                {"Name": "flags", "SequenceNumber": 2, "Attributes": ["In"], "CustomAttributes": []}
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
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.LastErr.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func CloseHandle(handle: CPointer<Unit>): Int32"), true)
    @Expect(source.contains("public static func CloseHandleChecked(handle: CPointer<Unit>): Unit {"), true)
    @Expect(source.contains("let ok__ = Example_LastErr_Apis.CloseHandle(handle)"), true)
    @Expect(source.contains("if (ok__ == 0) {"), true)
    @Expect(source.contains("throw windows_core.WindowsException(windows_core.errorFromThread())"), true)
    @Expect(source.contains("public static func IsTokenRestricted(token: CPointer<Unit>): Int32"), true)
    @Expect(source.contains("public static func IsTokenRestrictedChecked"), false)
    @Expect(source.contains("public static func CancelWaitableTimerChecked(handle: CPointer<Unit>): Unit {"), true)
    @Expect(source.contains("let ok__ = Example_LastErr_Apis.CancelWaitableTimer(handle)"), true)
    @Expect(source.contains("public static func ReadFileChecked(): Bool {"), true)
    @Expect(source.contains("let ok__ = Example_LastErr_Apis.ReadFile()"), true)
    @Expect(source.contains("if (ok__ != 0) {\n            return true\n        }\n        let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n        let lastError__ = unsafe { getLastErrorProc__() }\n        if (lastError__ == 997u32) {\n            return false\n        }\n        throw windows_core.WindowsException(windows_core.errorFromWin32(lastError__))"), true)
    @Expect(source.contains("public static func ConnectNamedPipeChecked(): Bool {"), true)
    @Expect(source.contains("if (lastError__ == 997u32) {\n            return false\n        }\n        if (lastError__ == 535u32) {\n            return false\n        }"), true)
    @Expect(source.contains("public static func GetQueuedCompletionStatus(): Int32"), true)
    @Expect(source.contains("public static func GetQueuedCompletionStatusChecked"), false)
    @Expect(source.contains("public static func GetQueuedCompletionStatusExChecked(): Bool {"), true)
    @Expect(source.contains("let ok__ = Example_LastErr_Apis.GetQueuedCompletionStatusEx()"), true)
    @Expect(source.contains("if (lastError__ == 258u32) {\n            return false\n        }"), true)
    @Expect(source.contains("public static func GetMessageW(lpMsg: CPointer<Unit>): Int32"), true)
    @Expect(source.contains("public static func GetMessageWChecked"), false)
    @Expect(source.contains("public static func TrackPopupMenu(): Int32"), true)
    @Expect(source.contains("public static func TrackPopupMenuChecked"), false)
    @Expect(source.contains("public static func TrackPopupMenuEx(): Int32"), true)
    @Expect(source.contains("public static func TrackPopupMenuExChecked"), false)
    @Expect(source.contains("public static func AttachThreadInputChecked(idAttach: UInt32, idAttachTo: UInt32, fAttach: Int32): Unit {"), true)
    @Expect(source.contains("let ok__ = Example_LastErr_Apis.AttachThreadInput(idAttach, idAttachTo, fAttach)"), true)
    @Expect(source.contains("public static func ClosePrivateNamespace(handle: CPointer<Unit>, flags: UInt32): UInt8"), true)
    @Expect(source.contains("public static func ClosePrivateNamespaceChecked(handle: CPointer<Unit>, flags: UInt32): Unit {"), true)
    @Expect(source.contains("let ok__ = Example_LastErr_Apis.ClosePrivateNamespace(handle, flags)"), true)
    @Expect(source.contains("if (ok__ == 0u8) {"), true)
}

@Test
func testPInvokeErgonomicWinHttpBoolStatusWrapperPreservesResendStatus() {
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
          "Namespace": "Example.WinHttp",
          "Name": "Apis",
          "BaseType": null,
          "IsNested": false,
          "Attributes": ["Public", "Class"],
          "CustomAttributes": [],
          "Fields": [],
          "InterfaceImplementations": [],
          "Methods": [
            {
              "Name": "WinHttpReceiveResponse",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "WinHttpReceiveResponse",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "WINHTTP.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
                "ParameterTypes": [],
                "RequiredParameterCount": 0
              },
              "Parameters": [],
              "GenericParameters": []
            },
            {
              "Name": "WinHttpQueryOption",
              "Attributes": ["Public", "Static", "PinvokeImpl"],
              "CustomAttributes": [],
              "ImplAttributes": ["IL", "Managed"],
              "RelativeVirtualAddress": 0,
              "Import": {
                "Name": "WinHttpQueryOption",
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
                "Module": {"Name": "WINHTTP.dll", "CustomAttributes": []}
              },
              "Signature": {
                "ReturnType": {"Kind": "Type", "Namespace": "Windows.Win32.Foundation", "Name": "BOOL", "Comment": "TypeReference"},
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
    let symbolsByName = cliTestRecordsByName(records)
    let options = RenderOptions.cliDefaults()
    var source = ""
    for (record in records) {
        if (record.fullName == "Example.WinHttp.Apis") {
            source = renderSymbolImpl(record, symbolsByName, options)
        }
    }

    @Expect(source.contains("public static func WinHttpReceiveResponseChecked(): UInt32 {"), true)
    @Expect(source.contains("let ok__ = Example_WinHttp_Apis.WinHttpReceiveResponse()"), true)
    @Expect(source.contains("if (ok__ != 0) {\n            return 0u32\n        }\n        let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n        let lastError__ = unsafe { getLastErrorProc__() }\n        if (lastError__ == 12032u32) {\n            return lastError__\n        }\n        throw windows_core.WindowsException(windows_core.errorFromWin32(lastError__))"), true)
    @Expect(source.contains("public static func WinHttpReceiveResponseChecked(): Bool"), false)
    @Expect(source.contains("public static func WinHttpQueryOptionChecked(): UInt32 {"), true)
    @Expect(source.contains("let ok__ = Example_WinHttp_Apis.WinHttpQueryOption()"), true)
    @Expect(source.contains("if (lastError__ == 122u32) {\n            return lastError__\n        }"), true)
    @Expect(source.contains("public static func WinHttpQueryOptionChecked(): Bool"), false)
}
