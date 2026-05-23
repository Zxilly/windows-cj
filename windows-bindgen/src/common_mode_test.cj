package windows_bindgen

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

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
    @Expect(helper.contains("return unsafe { proc(0u32, value) }"), true)
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
    @Expect(helper.contains("return unsafe { proc(0u32, values) }"), true)
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
func testCommonNativeHelperFilesRenderSetLastErrorCheckedBoolWrapper() {
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
                "Attributes": ["ExactSpelling", "CallingConventionWinApi", "SetLastError"],
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

    @Expect(helper.contains("import windows_core as windows_core"), true)
    @Expect(helper.contains("public func SetEnabled(enabled: Bool): Bool"), true)
    @Expect(helper.contains("public func SetEnabledChecked(enabled: Bool): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (SetEnabled(enabled))"), true)
    @Expect(helper.contains("windows_core.Result<Unit>.Err(windows_core.errorFromThread())"), true)
}

@Test
func testCommonNativeHelperFilesRenderHResultCheckedWrapper() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let parameterTypes = ArrayList<SignatureRecord>()
    parameterTypes.add(pointerSignature(voidSignature()))
    parameterTypes.add(primitiveSignature("UInt32"))
    let parameters = ArrayList<ParameterRecord>()
    parameters.add(ParameterRecord("reserved", sequenceNumber: 1))
    parameters.add(ParameterRecord("flags", sequenceNumber: 2))
    let method = MethodRecord(
        "CoInitializeEx",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: parameterTypes,
            requiredParameterCount: 2
        ),
        parameters: parameters,
        methodImport: Some(MethodImportRecord("CoInitializeEx", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", method))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("import windows_core as windows_core"), true)
    @Expect(helper.contains("public func CoInitializeEx(reserved: CPointer<Unit>, flags: UInt32): Int32"), true)
    @Expect(helper.contains("public func CoInitializeExChecked(reserved: CPointer<Unit>, flags: UInt32): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("windows_core.HRESULT(CoInitializeEx(reserved, flags)).ok()"), true)
}

@Test
func testCommonNativeHelperFilesRenderMultipleSuccessHResultCheckedWrapper() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let parameterTypes = ArrayList<SignatureRecord>()
    parameterTypes.add(pointerSignature(voidSignature()))
    parameterTypes.add(primitiveSignature("UInt32"))
    let parameters = ArrayList<ParameterRecord>()
    parameters.add(ParameterRecord("reserved", sequenceNumber: 1))
    parameters.add(ParameterRecord("flags", sequenceNumber: 2))
    let customAttributes = ArrayList<CustomAttributeRecord>()
    customAttributes.add(CustomAttributeRecord("Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute"))
    let method = MethodRecord(
        "CoInitializeEx",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: parameterTypes,
            requiredParameterCount: 2
        ),
        parameters: parameters,
        customAttributes: customAttributes,
        methodImport: Some(MethodImportRecord("CoInitializeEx", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", method))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("public func CoInitializeExChecked(reserved: CPointer<Unit>, flags: UInt32): windows_core.Result<windows_core.HRESULT>"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(CoInitializeEx(reserved, flags))"), true)
    @Expect(helper.contains("return windows_core.Result<windows_core.HRESULT>.Err(windows_core.errorFromHRESULT(resultHr__))"), true)
    @Expect(helper.contains("windows_core.Result<windows_core.HRESULT>.Ok(resultHr__)"), true)
    @Expect(helper.contains("windows_core.HRESULT(CoInitializeEx(reserved, flags)).ok()"), false)
}

@Test
func testCommonNativeHelperFilesRenderMultiQiHResultCheckedWrappersPreserveStatus() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let instanceParameterTypes = ArrayList<SignatureRecord>()
    instanceParameterTypes.add(pointerSignature(typeSignature("System", "Guid")))
    instanceParameterTypes.add(typeSignature("Windows.Win32.System.Com", "IUnknown"))
    instanceParameterTypes.add(primitiveSignature("UInt32"))
    instanceParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.System.Com", "COSERVERINFO")))
    instanceParameterTypes.add(primitiveSignature("UInt32"))
    instanceParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.System.Com", "MULTI_QI")))
    let instanceParameters = ArrayList<ParameterRecord>()
    instanceParameters.add(ParameterRecord("Clsid", sequenceNumber: 1))
    instanceParameters.add(ParameterRecord("punkOuter", sequenceNumber: 2))
    instanceParameters.add(ParameterRecord("dwClsCtx", sequenceNumber: 3))
    instanceParameters.add(ParameterRecord("pServerInfo", sequenceNumber: 4))
    instanceParameters.add(ParameterRecord("dwCount", sequenceNumber: 5))
    instanceParameters.add(ParameterRecord("pResults", sequenceNumber: 6))
    let instanceMethod = MethodRecord(
        "CoCreateInstanceEx",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: instanceParameterTypes,
            requiredParameterCount: 6
        ),
        parameters: instanceParameters,
        methodImport: Some(MethodImportRecord("CoCreateInstanceEx", "OLE32.dll", attributes: importAttributes))
    )

    let appParameterTypes = ArrayList<SignatureRecord>()
    appParameterTypes.add(pointerSignature(typeSignature("System", "Guid")))
    appParameterTypes.add(typeSignature("Windows.Win32.System.Com", "IUnknown"))
    appParameterTypes.add(primitiveSignature("UInt32"))
    appParameterTypes.add(pointerSignature(voidSignature()))
    appParameterTypes.add(primitiveSignature("UInt32"))
    appParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.System.Com", "MULTI_QI")))
    let appParameters = ArrayList<ParameterRecord>()
    appParameters.add(ParameterRecord("Clsid", sequenceNumber: 1))
    appParameters.add(ParameterRecord("punkOuter", sequenceNumber: 2))
    appParameters.add(ParameterRecord("dwClsCtx", sequenceNumber: 3))
    appParameters.add(ParameterRecord("reserved", sequenceNumber: 4))
    appParameters.add(ParameterRecord("dwCount", sequenceNumber: 5))
    appParameters.add(ParameterRecord("pResults", sequenceNumber: 6))
    let appMethod = MethodRecord(
        "CoCreateInstanceFromApp",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: appParameterTypes,
            requiredParameterCount: 6
        ),
        parameters: appParameters,
        methodImport: Some(MethodImportRecord("CoCreateInstanceFromApp", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", instanceMethod))
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", appMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("public func CoCreateInstanceExChecked("), true)
    @Expect(helper.contains("public func CoCreateInstanceFromAppChecked("), true)
    @Expect(cliTestCountOccurrences(helper, "): windows_core.Result<windows_core.HRESULT>"), 2)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(CoCreateInstanceEx(Clsid, punkOuter, dwClsCtx, pServerInfo, dwCount, pResults))"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(CoCreateInstanceFromApp(Clsid, punkOuter, dwClsCtx, reserved, dwCount, pResults))"), true)
    @Expect(helper.contains("windows_core.Result<windows_core.HRESULT>.Ok(resultHr__)"), true)
    @Expect(helper.contains("windows_core.HRESULT(CoCreateInstanceEx(Clsid, punkOuter, dwClsCtx, pServerInfo, dwCount, pResults)).ok()"), false)
    @Expect(helper.contains("windows_core.HRESULT(CoCreateInstanceFromApp(Clsid, punkOuter, dwClsCtx, reserved, dwCount, pResults)).ok()"), false)
}

@Test
func testCommonNativeHelperFilesRenderHResultComOutPtrCheckedWrapper() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let parameterTypes = ArrayList<SignatureRecord>()
    parameterTypes.add(pointerSignature(pointerSignature(voidSignature())))
    parameterTypes.add(primitiveSignature("UInt32"))

    let outAttributes = ArrayList<String>()
    outAttributes.add("Out")
    let comOutAttributes = ArrayList<CustomAttributeRecord>()
    comOutAttributes.add(CustomAttributeRecord("Windows.Win32.Foundation.Metadata.ComOutPtrAttribute"))
    let parameters = ArrayList<ParameterRecord>()
    parameters.add(ParameterRecord("ppv", sequenceNumber: 1, attributes: outAttributes, customAttributes: comOutAttributes))
    parameters.add(ParameterRecord("flags", sequenceNumber: 2))
    let method = MethodRecord(
        "CreateObject",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: parameterTypes,
            requiredParameterCount: 2
        ),
        parameters: parameters,
        methodImport: Some(MethodImportRecord("CreateObject", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", method))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("public func CreateObject(ppv: CPointer<CPointer<Unit>>, flags: UInt32): Int32"), true)
    @Expect(helper.contains("public func CreateObjectChecked(ppv: CPointer<CPointer<Unit>>, flags: UInt32): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (ppv.isNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    unsafe { ppv.write(CPointer<Unit>()) }"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(CreateObject(ppv, flags))"), true)
    @Expect(helper.contains("if (resultHr__.failed()) {\n        windows_core.releaseFailedComOutSlot(ppv)\n        return resultHr__.ok()\n    }"), true)
    @Expect(helper.contains("if (unsafe { ppv.read() }.isNull()) {\n        windows_core.releaseFailedComOutSlot(ppv)\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
}

@Test
func testCommonNativeHelperFilesRenderHResultOwnedPwstrOutCheckedWrapper() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let outAttributes = ArrayList<String>()
    outAttributes.add("Out")

    let threadParameterTypes = ArrayList<SignatureRecord>()
    threadParameterTypes.add(pointerSignature(voidSignature()))
    threadParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.Foundation", "PWSTR")))
    let threadParameters = ArrayList<ParameterRecord>()
    threadParameters.add(ParameterRecord("hThread", sequenceNumber: 1))
    threadParameters.add(ParameterRecord("ppszThreadDescription", sequenceNumber: 2, attributes: outAttributes))
    let threadMethod = MethodRecord(
        "GetThreadDescription",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: threadParameterTypes,
            requiredParameterCount: 2
        ),
        parameters: threadParameters,
        methodImport: Some(MethodImportRecord("GetThreadDescription", "KERNEL32.dll", attributes: importAttributes))
    )

    let guidParameterTypes = ArrayList<SignatureRecord>()
    guidParameterTypes.add(pointerSignature(typeSignature("System", "Guid")))
    guidParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.Foundation", "PWSTR")))
    let guidParameters = ArrayList<ParameterRecord>()
    guidParameters.add(ParameterRecord("rclsid", sequenceNumber: 1))
    guidParameters.add(ParameterRecord("lplpsz", sequenceNumber: 2, attributes: outAttributes))
    let guidMethod = MethodRecord(
        "StringFromCLSID",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: guidParameterTypes,
            requiredParameterCount: 2
        ),
        parameters: guidParameters,
        methodImport: Some(MethodImportRecord("StringFromCLSID", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", threadMethod))
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", guidMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("public func GetThreadDescriptionChecked(hThread: CPointer<Unit>, ppszThreadDescription: CPointer<CPointer<UInt16>>): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("windows_core.HRESULT(GetThreadDescription(hThread, ppszThreadDescription)).ok()"), false)
    @Expect(helper.contains("if (CPointer<CPointer<Unit>>(ppszThreadDescription).isNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    unsafe { CPointer<CPointer<Unit>>(ppszThreadDescription).write(CPointer<Unit>()) }"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(GetThreadDescription(hThread, ppszThreadDescription))"), true)
    @Expect(helper.contains("windows_libloading.resolveProc(\"KERNEL32.dll\", \"LocalFree\")"), true)
    @Expect(helper.contains("if (unsafe { CPointer<CPointer<Unit>>(ppszThreadDescription).read() }.isNull())"), true)
    @Expect(helper.contains("public func StringFromCLSIDChecked(rclsid: CPointer<GUID>, lplpsz: CPointer<CPointer<UInt16>>): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("windows_core.HRESULT(StringFromCLSID(rclsid, lplpsz)).ok()"), false)
    @Expect(helper.contains("windows_libloading.resolveProc(\"OLE32.dll\", \"CoTaskMemFree\")"), true)
    @Expect(helper.contains("unsafe { CPointer<CPointer<Unit>>(lplpsz).write(CPointer<Unit>()) }"), true)
}

@Test
func testCommonNativeHelperFilesRenderHResultOwnedPointerOutCheckedWrapper() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let outAttributes = ArrayList<String>()
    outAttributes.add("Out")
    let inOutAttributes = ArrayList<String>()
    inOutAttributes.add("In")
    inOutAttributes.add("Out")

    let securityParameterTypes = ArrayList<SignatureRecord>()
    securityParameterTypes.add(primitiveSignature("Int32"))
    securityParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.Security", "PSECURITY_DESCRIPTOR")))
    let securityParameters = ArrayList<ParameterRecord>()
    securityParameters.add(ParameterRecord("comSDType", sequenceNumber: 1))
    securityParameters.add(ParameterRecord("ppSD", sequenceNumber: 2, attributes: inOutAttributes))
    let securityMethod = MethodRecord(
        "CoGetSystemSecurityPermissions",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: securityParameterTypes,
            requiredParameterCount: 2
        ),
        parameters: securityParameters,
        methodImport: Some(MethodImportRecord("CoGetSystemSecurityPermissions", "OLE32.dll", attributes: importAttributes))
    )

    let authParameterTypes = ArrayList<SignatureRecord>()
    authParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    authParameterTypes.add(pointerSignature(pointerSignature(typeSignature("Windows.Win32.System.Com", "SOLE_AUTHENTICATION_SERVICE"))))
    let authParameters = ArrayList<ParameterRecord>()
    authParameters.add(ParameterRecord("pcAuthSvc", sequenceNumber: 1, attributes: outAttributes))
    authParameters.add(ParameterRecord("asAuthSvc", sequenceNumber: 2, attributes: outAttributes))
    let authMethod = MethodRecord(
        "CoQueryAuthenticationServices",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: authParameterTypes,
            requiredParameterCount: 2
        ),
        parameters: authParameters,
        methodImport: Some(MethodImportRecord("CoQueryAuthenticationServices", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", securityMethod))
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", authMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("windows_core.HRESULT(CoGetSystemSecurityPermissions(comSDType, ppSD)).ok()"), false)
    @Expect(helper.contains("windows_core.HRESULT(CoQueryAuthenticationServices(pcAuthSvc, asAuthSvc)).ok()"), false)
    @Expect(helper.contains("if (ppSD.isNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    unsafe { ppSD.write(CPointer<Unit>()) }"), true)
    @Expect(helper.contains("if (CPointer<CPointer<Unit>>(asAuthSvc).isNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    unsafe { CPointer<CPointer<Unit>>(asAuthSvc).write(CPointer<Unit>()) }"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(CoGetSystemSecurityPermissions(comSDType, ppSD))"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(CoQueryAuthenticationServices(pcAuthSvc, asAuthSvc))"), true)
    @Expect(cliTestCountOccurrences(helper, "windows_libloading.resolveProc(\"KERNEL32.dll\", \"LocalFree\")"), 2)
    @Expect(cliTestCountOccurrences(helper, "windows_libloading.resolveProc(\"OLE32.dll\", \"CoTaskMemFree\")"), 2)
    @Expect(helper.contains("if (unsafe { ppSD.read() }.isNull())"), true)
    @Expect(helper.contains("if (unsafe { CPointer<CPointer<Unit>>(asAuthSvc).read() }.isNull())"), true)
    @Expect(helper.contains("windows_core.releaseFailedComOutSlot(ppSD)"), false)
    @Expect(helper.contains("windows_core.releaseFailedComOutSlot(asAuthSvc)"), false)
}

@Test
func testCommonNativeHelperFilesRenderCoQueryBlanketOptionalOutCleanup() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let inAttributes = ArrayList<String>()
    inAttributes.add("In")
    let optionalOutAttributes = ArrayList<String>()
    optionalOutAttributes.add("Out")
    optionalOutAttributes.add("Optional")
    let optionalInOutAttributes = ArrayList<String>()
    optionalInOutAttributes.add("In")
    optionalInOutAttributes.add("Out")
    optionalInOutAttributes.add("Optional")

    let proxyParameterTypes = ArrayList<SignatureRecord>()
    proxyParameterTypes.add(typeSignature("Windows.Win32.System.Com", "IUnknown"))
    proxyParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    proxyParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    proxyParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.Foundation", "PWSTR")))
    proxyParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    proxyParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    proxyParameterTypes.add(pointerSignature(pointerSignature(voidSignature())))
    proxyParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    let proxyParameters = ArrayList<ParameterRecord>()
    proxyParameters.add(ParameterRecord("pProxy", sequenceNumber: 1, attributes: inAttributes))
    proxyParameters.add(ParameterRecord("pwAuthnSvc", sequenceNumber: 2, attributes: optionalOutAttributes))
    proxyParameters.add(ParameterRecord("pAuthzSvc", sequenceNumber: 3, attributes: optionalOutAttributes))
    proxyParameters.add(ParameterRecord("pServerPrincName", sequenceNumber: 4, attributes: optionalOutAttributes))
    proxyParameters.add(ParameterRecord("pAuthnLevel", sequenceNumber: 5, attributes: optionalOutAttributes))
    proxyParameters.add(ParameterRecord("pImpLevel", sequenceNumber: 6, attributes: optionalOutAttributes))
    proxyParameters.add(ParameterRecord("pAuthInfo", sequenceNumber: 7, attributes: optionalOutAttributes))
    proxyParameters.add(ParameterRecord("pCapabilites", sequenceNumber: 8, attributes: optionalOutAttributes))
    let proxyMethod = MethodRecord(
        "CoQueryProxyBlanket",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: proxyParameterTypes,
            requiredParameterCount: 8
        ),
        parameters: proxyParameters,
        methodImport: Some(MethodImportRecord("CoQueryProxyBlanket", "OLE32.dll", attributes: importAttributes))
    )

    let clientParameterTypes = ArrayList<SignatureRecord>()
    clientParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    clientParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    clientParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.Foundation", "PWSTR")))
    clientParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    clientParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    clientParameterTypes.add(pointerSignature(pointerSignature(voidSignature())))
    clientParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    let clientParameters = ArrayList<ParameterRecord>()
    clientParameters.add(ParameterRecord("pAuthnSvc", sequenceNumber: 1, attributes: optionalOutAttributes))
    clientParameters.add(ParameterRecord("pAuthzSvc", sequenceNumber: 2, attributes: optionalOutAttributes))
    clientParameters.add(ParameterRecord("pServerPrincName", sequenceNumber: 3, attributes: optionalOutAttributes))
    clientParameters.add(ParameterRecord("pAuthnLevel", sequenceNumber: 4, attributes: optionalOutAttributes))
    clientParameters.add(ParameterRecord("pImpLevel", sequenceNumber: 5, attributes: optionalOutAttributes))
    clientParameters.add(ParameterRecord("pPrivs", sequenceNumber: 6, attributes: optionalOutAttributes))
    clientParameters.add(ParameterRecord("pCapabilities", sequenceNumber: 7, attributes: optionalInOutAttributes))
    let clientMethod = MethodRecord(
        "CoQueryClientBlanket",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: clientParameterTypes,
            requiredParameterCount: 7
        ),
        parameters: clientParameters,
        methodImport: Some(MethodImportRecord("CoQueryClientBlanket", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", proxyMethod))
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", clientMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("public func CoQueryProxyBlanketChecked("), true)
    @Expect(helper.contains("public func CoQueryClientBlanketChecked("), true)
    @Expect(helper.contains("windows_core.HRESULT(CoQueryProxyBlanket(pProxy, pwAuthnSvc, pAuthzSvc, pServerPrincName, pAuthnLevel, pImpLevel, pAuthInfo, pCapabilites)).ok()"), false)
    @Expect(helper.contains("windows_core.HRESULT(CoQueryClientBlanket(pAuthnSvc, pAuthzSvc, pServerPrincName, pAuthnLevel, pImpLevel, pPrivs, pCapabilities)).ok()"), false)
    @Expect(helper.contains("if (CPointer<CPointer<Unit>>(pServerPrincName).isNull())"), false)
    @Expect(helper.contains("if (unsafe { CPointer<CPointer<Unit>>(pServerPrincName).read() }.isNull())"), false)
    @Expect(cliTestCountOccurrences(helper, "if (CPointer<CPointer<Unit>>(pServerPrincName).isNotNull())"), 4)
    @Expect(cliTestCountOccurrences(helper, "windows_libloading.resolveProc(\"OLE32.dll\", \"CoTaskMemFree\")"), 2)
    @Expect(cliTestCountOccurrences(helper, "pAuthInfo.write(CPointer<Unit>())"), 2)
    @Expect(cliTestCountOccurrences(helper, "pPrivs.write(CPointer<Unit>())"), 2)
    @Expect(helper.contains("windows_core.releaseFailedComOutSlot(pAuthInfo)"), false)
    @Expect(helper.contains("windows_core.releaseFailedComOutSlot(pPrivs)"), false)
    @Expect(helper.contains("if (pAuthInfo.isNull())"), false)
    @Expect(helper.contains("if (pPrivs.isNull())"), false)
    @Expect(helper.contains("pCapabilities.write(CPointer<Unit>())"), false)
    @Expect(helper.contains("pCapabilites.write(CPointer<Unit>())"), false)
}

@Test
func testCommonNativeHelperFilesRenderRtwqOptionalScalarKeyCleanup() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let inAttributes = ArrayList<String>()
    inAttributes.add("In")
    let optionalOutAttributes = ArrayList<String>()
    optionalOutAttributes.add("Out")
    optionalOutAttributes.add("Optional")

    let waitingParameterTypes = ArrayList<SignatureRecord>()
    waitingParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    waitingParameterTypes.add(primitiveSignature("Int32"))
    waitingParameterTypes.add(pointerSignature(voidSignature()))
    waitingParameterTypes.add(pointerSignature(primitiveSignature("UInt64")))
    let waitingParameters = ArrayList<ParameterRecord>()
    waitingParameters.add(ParameterRecord("hEvent", sequenceNumber: 1, attributes: inAttributes))
    waitingParameters.add(ParameterRecord("lPriority", sequenceNumber: 2, attributes: inAttributes))
    waitingParameters.add(ParameterRecord("result", sequenceNumber: 3, attributes: inAttributes))
    waitingParameters.add(ParameterRecord("key", sequenceNumber: 4, attributes: optionalOutAttributes))
    let waitingMethod = MethodRecord(
        "RtwqPutWaitingWorkItem",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: waitingParameterTypes,
            requiredParameterCount: 4
        ),
        parameters: waitingParameters,
        methodImport: Some(MethodImportRecord("RtwqPutWaitingWorkItem", "RTWorkQ.dll", attributes: importAttributes))
    )

    let scheduleParameterTypes = ArrayList<SignatureRecord>()
    scheduleParameterTypes.add(pointerSignature(voidSignature()))
    scheduleParameterTypes.add(primitiveSignature("Int64"))
    scheduleParameterTypes.add(pointerSignature(primitiveSignature("UInt64")))
    let scheduleParameters = ArrayList<ParameterRecord>()
    scheduleParameters.add(ParameterRecord("result", sequenceNumber: 1, attributes: inAttributes))
    scheduleParameters.add(ParameterRecord("Timeout", sequenceNumber: 2, attributes: inAttributes))
    scheduleParameters.add(ParameterRecord("key", sequenceNumber: 3, attributes: optionalOutAttributes))
    let scheduleMethod = MethodRecord(
        "RtwqScheduleWorkItem",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: scheduleParameterTypes,
            requiredParameterCount: 3
        ),
        parameters: scheduleParameters,
        methodImport: Some(MethodImportRecord("RtwqScheduleWorkItem", "RTWorkQ.dll", attributes: importAttributes))
    )

    let periodicParameterTypes = ArrayList<SignatureRecord>()
    periodicParameterTypes.add(pointerSignature(voidSignature()))
    periodicParameterTypes.add(typeSignature("Windows.Win32.System.Com", "IUnknown"))
    periodicParameterTypes.add(pointerSignature(primitiveSignature("UInt32")))
    let periodicParameters = ArrayList<ParameterRecord>()
    periodicParameters.add(ParameterRecord("Callback", sequenceNumber: 1, attributes: inAttributes))
    periodicParameters.add(ParameterRecord("context", sequenceNumber: 2, attributes: inAttributes))
    periodicParameters.add(ParameterRecord("key", sequenceNumber: 3, attributes: optionalOutAttributes))
    let periodicMethod = MethodRecord(
        "RtwqAddPeriodicCallback",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: periodicParameterTypes,
            requiredParameterCount: 3
        ),
        parameters: periodicParameters,
        methodImport: Some(MethodImportRecord("RtwqAddPeriodicCallback", "RTWorkQ.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", waitingMethod))
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", scheduleMethod))
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", periodicMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("public func RtwqPutWaitingWorkItemChecked("), true)
    @Expect(helper.contains("public func RtwqScheduleWorkItemChecked("), true)
    @Expect(helper.contains("public func RtwqAddPeriodicCallbackChecked("), true)
    @Expect(helper.contains("windows_core.HRESULT(RtwqPutWaitingWorkItem(hEvent, lPriority, result, key)).ok()"), false)
    @Expect(helper.contains("windows_core.HRESULT(RtwqScheduleWorkItem(result, Timeout, key)).ok()"), false)
    @Expect(helper.contains("windows_core.HRESULT(RtwqAddPeriodicCallback(Callback, context, key)).ok()"), false)
    @Expect(helper.contains("if (key.isNull())"), false)
    @Expect(cliTestCountOccurrences(helper, "unsafe { key.write(0u64) }"), 4)
    @Expect(cliTestCountOccurrences(helper, "unsafe { key.write(0u32) }"), 2)
    @Expect(helper.contains("windows_core.releaseFailedComOutSlot(key)"), false)
    @Expect(helper.contains("if (unsafe { key.read() }.isNull())"), false)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(RtwqPutWaitingWorkItem(hEvent, lPriority, result, key))"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(RtwqScheduleWorkItem(result, Timeout, key))"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(RtwqAddPeriodicCallback(Callback, context, key))"), true)
}

@Test
func testCommonNativeHelperFilesRenderHResultMultiComOutPtrCheckedWrapperClearsSiblingsBeforeEPointer() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let parameterTypes = ArrayList<SignatureRecord>()
    parameterTypes.add(pointerSignature(pointerSignature(voidSignature())))
    parameterTypes.add(pointerSignature(pointerSignature(voidSignature())))

    let outAttributes = ArrayList<String>()
    outAttributes.add("Out")
    let comOutAttributes = ArrayList<CustomAttributeRecord>()
    comOutAttributes.add(CustomAttributeRecord("Windows.Win32.Foundation.Metadata.ComOutPtrAttribute"))
    let parameters = ArrayList<ParameterRecord>()
    parameters.add(ParameterRecord("first", sequenceNumber: 1, attributes: outAttributes, customAttributes: comOutAttributes))
    parameters.add(ParameterRecord("second", sequenceNumber: 2, attributes: outAttributes, customAttributes: comOutAttributes))
    let method = MethodRecord(
        "CreatePair",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: parameterTypes,
            requiredParameterCount: 2
        ),
        parameters: parameters,
        methodImport: Some(MethodImportRecord("CreatePair", "OLE32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", method))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("public func CreatePairChecked(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("var nullComOutSlot__ = false\n    if (first.isNull()) {\n        nullComOutSlot__ = true\n    } else {\n        unsafe { first.write(CPointer<Unit>()) }\n    }\n    if (second.isNull()) {\n        nullComOutSlot__ = true\n    } else {\n        unsafe { second.write(CPointer<Unit>()) }\n    }\n    if (nullComOutSlot__) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    let resultHr__ = windows_core.HRESULT(CreatePair(first, second))"), true)
    @Expect(helper.contains("if (first.isNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))"), false)
    @Expect(helper.contains("if (resultHr__.failed()) {\n        windows_core.releaseFailedComOutSlot(first)\n        windows_core.releaseFailedComOutSlot(second)\n        return resultHr__.ok()\n    }"), true)
    @Expect(helper.contains("if (unsafe { first.read() }.isNull()) {\n        windows_core.releaseFailedComOutSlot(first)\n        windows_core.releaseFailedComOutSlot(second)\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }"), true)
}

@Test
func testCommonNativeHelperFilesInferHResultComInterfaceOutPtrCheckedWrapper() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("CallingConventionWinApi")

    let parameterTypes = ArrayList<SignatureRecord>()
    parameterTypes.add(pointerSignature(typeSignature("Example.Native", "IDataAdviseHolder")))

    let outAttributes = ArrayList<String>()
    outAttributes.add("Out")
    let parameters = ArrayList<ParameterRecord>()
    parameters.add(ParameterRecord("ppDAHolder", sequenceNumber: 1, attributes: outAttributes))
    let method = MethodRecord(
        "CreateDataAdviseHolder",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HRESULT"),
            parameters: parameterTypes,
            requiredParameterCount: 1
        ),
        parameters: parameters,
        methodImport: Some(MethodImportRecord("CreateDataAdviseHolder", "OLE32.dll", attributes: importAttributes))
    )

    let interfaceAttributes = ArrayList<String>()
    interfaceAttributes.add("Public")
    interfaceAttributes.add("AutoLayout")
    interfaceAttributes.add("Interface")
    interfaceAttributes.add("Abstract")
    let interfaceType = TypeDefinitionRecord(
        "Example.Native",
        "IDataAdviseHolder",
        attributes: interfaceAttributes
    )
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add("Example.Native.IDataAdviseHolder", SymbolRecord(
        "Example.Native.IDataAdviseHolder",
        "Example.Native",
        "IDataAdviseHolder",
        "Example_Native_IDataAdviseHolder",
        [],
        typeDef: Some(interfaceType)
    ))

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Example.Native", "Example.Native.Apis", method))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Example.Native",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("public func CreateDataAdviseHolder(ppDAHolder: CPointer<CPointer<Unit>>): Int32"), true)
    @Expect(helper.contains("public func CreateDataAdviseHolderChecked(ppDAHolder: CPointer<CPointer<Unit>>): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("windows_core.HRESULT(CreateDataAdviseHolder(ppDAHolder)).ok()"), false)
    @Expect(helper.contains("if (ppDAHolder.isNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    unsafe { ppDAHolder.write(CPointer<Unit>()) }"), true)
    @Expect(helper.contains("let resultHr__ = windows_core.HRESULT(CreateDataAdviseHolder(ppDAHolder))"), true)
    @Expect(helper.contains("if (resultHr__.failed()) {\n        windows_core.releaseFailedComOutSlot(ppDAHolder)\n        return resultHr__.ok()\n    }"), true)
    @Expect(helper.contains("if (unsafe { ppDAHolder.read() }.isNull()) {\n        windows_core.releaseFailedComOutSlot(ppDAHolder)\n        return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
}

@Test
func testCommonNativeHelperFilesRenderWin32FoundationCheckedHandleWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let boolFields = ArrayList<FieldRecord>()
    boolFields.add(FieldRecord("Value", primitiveSignature("Int32"), attributes: publicFieldAttributes))

    let handleType = TypeDefinitionRecord(
        "Windows.Win32.Foundation",
        "HANDLE",
        baseType: "System.ValueType",
        hasBaseType: true,
        attributes: valueTypeAttributes,
        fields: handleFields
    )
    let boolType = TypeDefinitionRecord(
        "Windows.Win32.Foundation",
        "BOOL",
        baseType: "System.ValueType",
        hasBaseType: true,
        attributes: valueTypeAttributes,
        fields: boolFields
    )
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.HANDLE",
        SymbolRecord(
            "Windows.Win32.Foundation.HANDLE",
            "Windows.Win32.Foundation",
            "HANDLE",
            "Windows_Win32_Foundation_HANDLE",
            [],
            typeDef: Some(handleType)
        )
    )
    symbolsByName.add(
        "Windows.Win32.Foundation.BOOL",
        SymbolRecord(
            "Windows.Win32.Foundation.BOOL",
            "Windows.Win32.Foundation",
            "BOOL",
            "Windows_Win32_Foundation_BOOL",
            [],
            typeDef: Some(boolType)
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let closeParameterTypes = ArrayList<SignatureRecord>()
    closeParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    let closeParameters = ArrayList<ParameterRecord>()
    closeParameters.add(ParameterRecord("hObject", sequenceNumber: 1))
    let closeMethod = MethodRecord(
        "CloseHandle",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: closeParameterTypes,
            requiredParameterCount: 1
        ),
        parameters: closeParameters,
        methodImport: Some(MethodImportRecord("CloseHandle", "KERNEL32.dll", attributes: importAttributes))
    )

    let duplicateParameterTypes = ArrayList<SignatureRecord>()
    duplicateParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    duplicateParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    duplicateParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    duplicateParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.Foundation", "HANDLE")))
    duplicateParameterTypes.add(primitiveSignature("UInt32"))
    duplicateParameterTypes.add(typeSignature("Windows.Win32.Foundation", "BOOL"))
    duplicateParameterTypes.add(primitiveSignature("UInt32"))
    let duplicateParameters = ArrayList<ParameterRecord>()
    duplicateParameters.add(ParameterRecord("hSourceProcessHandle", sequenceNumber: 1))
    duplicateParameters.add(ParameterRecord("hSourceHandle", sequenceNumber: 2))
    duplicateParameters.add(ParameterRecord("hTargetProcessHandle", sequenceNumber: 3))
    duplicateParameters.add(ParameterRecord("lpTargetHandle", sequenceNumber: 4))
    duplicateParameters.add(ParameterRecord("dwDesiredAccess", sequenceNumber: 5))
    duplicateParameters.add(ParameterRecord("bInheritHandle", sequenceNumber: 6))
    duplicateParameters.add(ParameterRecord("dwOptions", sequenceNumber: 7))
    let duplicateMethod = MethodRecord(
        "DuplicateHandle",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: duplicateParameterTypes,
            requiredParameterCount: 7
        ),
        parameters: duplicateParameters,
        methodImport: Some(MethodImportRecord("DuplicateHandle", "KERNEL32.dll", attributes: importAttributes))
    )

    let openProcessParameterTypes = ArrayList<SignatureRecord>()
    openProcessParameterTypes.add(primitiveSignature("UInt32"))
    openProcessParameterTypes.add(typeSignature("Windows.Win32.Foundation", "BOOL"))
    openProcessParameterTypes.add(primitiveSignature("UInt32"))
    let openProcessParameters = ArrayList<ParameterRecord>()
    openProcessParameters.add(ParameterRecord("dwDesiredAccess", sequenceNumber: 1))
    openProcessParameters.add(ParameterRecord("bInheritHandle", sequenceNumber: 2))
    openProcessParameters.add(ParameterRecord("dwProcessId", sequenceNumber: 3))
    let openProcessMethod = MethodRecord(
        "OpenProcess",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HANDLE"),
            parameters: openProcessParameterTypes,
            requiredParameterCount: 3
        ),
        parameters: openProcessParameters,
        methodImport: Some(MethodImportRecord("OpenProcess", "KERNEL32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.Foundation", "Windows.Win32.Foundation.Apis", closeMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Foundation", "Windows.Win32.Foundation.Apis", duplicateMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Foundation", "Windows.Win32.Foundation.Apis", openProcessMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("public func CloseHandle(hObject: HANDLE): Bool"), true)
    @Expect(helper.contains("public func CloseHandleChecked(hObject: HANDLE): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (CloseHandle(hObject))"), true)
    @Expect(helper.contains("public func DuplicateHandle(hSourceProcessHandle: HANDLE, hSourceHandle: HANDLE, hTargetProcessHandle: HANDLE, lpTargetHandle: CPointer<HANDLE>, dwDesiredAccess: UInt32, bInheritHandle: Bool, dwOptions: UInt32): Bool"), true)
    @Expect(helper.contains("public func DuplicateHandleChecked(hSourceProcessHandle: HANDLE, hSourceHandle: HANDLE, hTargetProcessHandle: HANDLE, lpTargetHandle: CPointer<HANDLE>, dwDesiredAccess: UInt32, bInheritHandle: Bool, dwOptions: UInt32): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (DuplicateHandle(hSourceProcessHandle, hSourceHandle, hTargetProcessHandle, lpTargetHandle, dwDesiredAccess, bInheritHandle, dwOptions))"), true)
    @Expect(helper.contains("public func OpenProcess(dwDesiredAccess: UInt32, bInheritHandle: Bool, dwProcessId: UInt32): HANDLE"), true)
    @Expect(helper.contains("public func OpenProcessChecked(dwDesiredAccess: UInt32, bInheritHandle: Bool, dwProcessId: UInt32): windows_core.Result<HANDLE>"), true)
    @Expect(helper.contains("let result__ = OpenProcess(dwDesiredAccess, bInheritHandle, dwProcessId)\n    if (result__.Value.isNull()) {\n        return windows_core.Result<HANDLE>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<HANDLE>.Ok(result__)"), true)
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorBoolFalseSuccessStatusWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let boolFields = ArrayList<FieldRecord>()
    boolFields.add(FieldRecord("Value", primitiveSignature("Int32"), attributes: publicFieldAttributes))
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.BOOL",
        SymbolRecord(
            "Windows.Win32.Foundation.BOOL",
            "Windows.Win32.Foundation",
            "BOOL",
            "Windows_Win32_Foundation_BOOL",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "BOOL",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: boolFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")
    let timeoutBoolNames = ArrayList<String>()
    timeoutBoolNames.add("SleepConditionVariableCS")
    timeoutBoolNames.add("SleepConditionVariableSRW")
    timeoutBoolNames.add("WaitOnAddress")

    let specs = ArrayList<NativeFunctionSpec>()
    for (name in timeoutBoolNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                typeSignature("Windows.Win32.Foundation", "BOOL"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "KERNEL32.dll", attributes: importAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Threading",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    for (name in timeoutBoolNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<Bool>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__) {\n        return windows_core.Result<Bool>.Ok(true)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 1460u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    windows_core.Result<Bool>.Err(windows_core.errorFromWin32(lastError__))"), true)
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), false)
    }

    let pendingBoolNames = ArrayList<String>()
    pendingBoolNames.add("DeleteTimerQueueTimer")
    pendingBoolNames.add("UnregisterWait")
    pendingBoolNames.add("UnregisterWaitEx")

    let pendingSpecs = ArrayList<NativeFunctionSpec>()
    for (name in pendingBoolNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                typeSignature("Windows.Win32.Foundation", "BOOL"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "KERNEL32.dll", attributes: importAttributes))
        )
        pendingSpecs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    let pendingHelper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Threading",
        pendingSpecs,
        symbolsByName
    )

    @Expect(pendingHelper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    for (name in pendingBoolNames) {
        @Expect(pendingHelper.contains("public func ${name}Checked(): windows_core.Result<Bool>"), true)
        @Expect(pendingHelper.contains("let result__ = ${name}()\n    if (result__) {\n        return windows_core.Result<Bool>.Ok(true)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 997u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    windows_core.Result<Bool>.Err(windows_core.errorFromWin32(lastError__))"), true)
        @Expect(pendingHelper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), false)
    }

    let ioBoolNames = ArrayList<String>()
    ioBoolNames.add("DeviceIoControl")
    ioBoolNames.add("GetThreadWaitChain")
    ioBoolNames.add("HandleLogFull")
    ioBoolNames.add("LockFileEx")
    ioBoolNames.add("ReadFile")
    ioBoolNames.add("ReadFileScatter")
    ioBoolNames.add("TransactNamedPipe")
    ioBoolNames.add("WaitCommEvent")
    ioBoolNames.add("WinUsb_ReadPipe")
    ioBoolNames.add("WinUsb_WritePipe")
    ioBoolNames.add("WriteFile")
    ioBoolNames.add("WriteFileGather")

    let ioSpecs = ArrayList<NativeFunctionSpec>()
    for (name in ioBoolNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                typeSignature("Windows.Win32.Foundation", "BOOL"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "KERNEL32.dll", attributes: importAttributes))
        )
        ioSpecs.add(NativeFunctionSpec("Windows.Win32.System.IO", "Windows.Win32.System.IO.Apis", method))
    }
    let ioHelper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.IO",
        ioSpecs,
        symbolsByName
    )

    @Expect(ioHelper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    for (name in ioBoolNames) {
        @Expect(ioHelper.contains("public func ${name}Checked(): windows_core.Result<Bool>"), true)
        @Expect(ioHelper.contains("let result__ = ${name}()\n    if (result__) {\n        return windows_core.Result<Bool>.Ok(true)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 997u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    windows_core.Result<Bool>.Err(windows_core.errorFromWin32(lastError__))"), true)
        @Expect(ioHelper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), false)
    }

    let connectMethod = MethodRecord(
        "ConnectNamedPipe",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("ConnectNamedPipe", "KERNEL32.dll", attributes: importAttributes))
    )
    let connectSpecs = ArrayList<NativeFunctionSpec>()
    connectSpecs.add(NativeFunctionSpec("Windows.Win32.System.Pipes", "Windows.Win32.System.Pipes.Apis", connectMethod))
    let connectHelper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Pipes",
        connectSpecs,
        symbolsByName
    )

    @Expect(connectHelper.contains("public func ConnectNamedPipeChecked(): windows_core.Result<Bool>"), true)
    @Expect(connectHelper.contains("if (lastError__ == 997u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    if (lastError__ == 535u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }"), true)
    @Expect(connectHelper.contains("public func ConnectNamedPipeChecked(): windows_core.Result<Unit>"), false)

    let overlappedResultMethod = MethodRecord(
        "GetOverlappedResult",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetOverlappedResult", "KERNEL32.dll", attributes: importAttributes))
    )
    let overlappedResultExMethod = MethodRecord(
        "GetOverlappedResultEx",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetOverlappedResultEx", "KERNEL32.dll", attributes: importAttributes))
    )
    let overlappedSpecs = ArrayList<NativeFunctionSpec>()
    overlappedSpecs.add(NativeFunctionSpec("Windows.Win32.System.IO", "Windows.Win32.System.IO.Apis", overlappedResultMethod))
    overlappedSpecs.add(NativeFunctionSpec("Windows.Win32.System.IO", "Windows.Win32.System.IO.Apis", overlappedResultExMethod))
    let overlappedHelper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.IO",
        overlappedSpecs,
        symbolsByName
    )

    @Expect(overlappedHelper.contains("public func GetOverlappedResultChecked(): windows_core.Result<Bool>"), true)
    @Expect(overlappedHelper.contains("if (lastError__ == 996u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }"), true)
    @Expect(overlappedHelper.contains("public func GetOverlappedResultExChecked(): windows_core.Result<Bool>"), true)
    @Expect(overlappedHelper.contains("if (lastError__ == 996u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    if (lastError__ == 192u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    if (lastError__ == 258u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }"), true)
    @Expect(overlappedHelper.contains("public func GetOverlappedResultChecked(): windows_core.Result<Unit>"), false)
    @Expect(overlappedHelper.contains("public func GetOverlappedResultExChecked(): windows_core.Result<Unit>"), false)

    let completionStatusMethod = MethodRecord(
        "GetQueuedCompletionStatus",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetQueuedCompletionStatus", "KERNEL32.dll", attributes: importAttributes))
    )
    let completionStatusExMethod = MethodRecord(
        "GetQueuedCompletionStatusEx",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetQueuedCompletionStatusEx", "KERNEL32.dll", attributes: importAttributes))
    )
    let completionStatusSpecs = ArrayList<NativeFunctionSpec>()
    completionStatusSpecs.add(NativeFunctionSpec("Windows.Win32.System.IO", "Windows.Win32.System.IO.Apis", completionStatusMethod))
    completionStatusSpecs.add(NativeFunctionSpec("Windows.Win32.System.IO", "Windows.Win32.System.IO.Apis", completionStatusExMethod))
    let completionStatusHelper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.IO",
        completionStatusSpecs,
        symbolsByName
    )

    @Expect(completionStatusHelper.contains("public func GetQueuedCompletionStatusChecked"), false)
    @Expect(completionStatusHelper.contains("public func GetQueuedCompletionStatusExChecked(): windows_core.Result<Bool>"), true)
    @Expect(completionStatusHelper.contains("if (lastError__ == 258u32) {\n        return windows_core.Result<Bool>.Ok(false)\n    }"), true)
    @Expect(completionStatusHelper.contains("public func GetQueuedCompletionStatusExChecked(): windows_core.Result<Unit>"), false)

    let winHttpResendNames = ArrayList<String>()
    winHttpResendNames.add("WinHttpReceiveResponse")
    winHttpResendNames.add("WinHttpSendRequest")
    let winHttpResendSpecs = ArrayList<NativeFunctionSpec>()
    for (name in winHttpResendNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                typeSignature("Windows.Win32.Foundation", "BOOL"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "WINHTTP.dll", attributes: importAttributes))
        )
        winHttpResendSpecs.add(NativeFunctionSpec("Windows.Win32.Networking.WinHttp", "Windows.Win32.Networking.WinHttp.Apis", method))
    }
    let winHttpResendHelper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Networking.WinHttp",
        winHttpResendSpecs,
        symbolsByName
    )

    @Expect(winHttpResendHelper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    for (name in winHttpResendNames) {
        @Expect(winHttpResendHelper.contains("public func ${name}Checked(): windows_core.Result<UInt32>"), true)
        @Expect(winHttpResendHelper.contains("let result__ = ${name}()\n    if (result__) {\n        return windows_core.Result<UInt32>.Ok(0u32)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 12032u32) {\n        return windows_core.Result<UInt32>.Ok(lastError__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(lastError__))"), true)
        @Expect(winHttpResendHelper.contains("public func ${name}Checked(): windows_core.Result<Bool>"), false)
        @Expect(winHttpResendHelper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), false)
    }

    let winHttpBufferProbeNames = ArrayList<String>()
    winHttpBufferProbeNames.add("WinHttpCrackUrl")
    winHttpBufferProbeNames.add("WinHttpCreateUrl")
    winHttpBufferProbeNames.add("WinHttpQueryHeaders")
    winHttpBufferProbeNames.add("WinHttpQueryOption")
    let winHttpBufferProbeSpecs = ArrayList<NativeFunctionSpec>()
    for (name in winHttpBufferProbeNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                typeSignature("Windows.Win32.Foundation", "BOOL"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "WINHTTP.dll", attributes: importAttributes))
        )
        winHttpBufferProbeSpecs.add(NativeFunctionSpec("Windows.Win32.Networking.WinHttp", "Windows.Win32.Networking.WinHttp.Apis", method))
    }
    let winHttpBufferProbeHelper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Networking.WinHttp",
        winHttpBufferProbeSpecs,
        symbolsByName
    )

    @Expect(winHttpBufferProbeHelper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    for (name in winHttpBufferProbeNames) {
        @Expect(winHttpBufferProbeHelper.contains("public func ${name}Checked(): windows_core.Result<UInt32>"), true)
        if (name == "WinHttpQueryHeaders") {
            @Expect(winHttpBufferProbeHelper.contains("let result__ = ${name}()\n    if (result__) {\n        return windows_core.Result<UInt32>.Ok(0u32)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 122u32 || lastError__ == 12150u32) {\n        return windows_core.Result<UInt32>.Ok(lastError__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(lastError__))"), true)
        } else {
            @Expect(winHttpBufferProbeHelper.contains("let result__ = ${name}()\n    if (result__) {\n        return windows_core.Result<UInt32>.Ok(0u32)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 122u32) {\n        return windows_core.Result<UInt32>.Ok(lastError__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(lastError__))"), true)
        }
        @Expect(winHttpBufferProbeHelper.contains("public func ${name}Checked(): windows_core.Result<Bool>"), false)
        @Expect(winHttpBufferProbeHelper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), false)
    }
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorInvalidHandleWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.HANDLE",
        SymbolRecord(
            "Windows.Win32.Foundation.HANDLE",
            "Windows.Win32.Foundation",
            "HANDLE",
            "Windows_Win32_Foundation_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")
    let invalidHandleNames = ArrayList<String>()
    invalidHandleNames.add("CreateFileA")
    invalidHandleNames.add("CreateFileW")
    invalidHandleNames.add("FindFirstChangeNotificationA")
    invalidHandleNames.add("FindFirstChangeNotificationW")
    invalidHandleNames.add("FindFirstFileA")
    invalidHandleNames.add("FindFirstFileW")
    invalidHandleNames.add("FindFirstFileExA")
    invalidHandleNames.add("FindFirstFileExW")
    invalidHandleNames.add("FindFirstFileNameW")
    invalidHandleNames.add("FindFirstFileNameTransactedW")
    invalidHandleNames.add("FindFirstFileTransactedA")
    invalidHandleNames.add("FindFirstFileTransactedW")
    invalidHandleNames.add("FindFirstStreamW")
    invalidHandleNames.add("FindFirstStreamTransactedW")
    invalidHandleNames.add("FindFirstVolumeA")
    invalidHandleNames.add("FindFirstVolumeW")
    invalidHandleNames.add("FindFirstVolumeMountPointA")
    invalidHandleNames.add("FindFirstVolumeMountPointW")

    let specs = ArrayList<NativeFunctionSpec>()
    for (name in invalidHandleNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                typeSignature("Windows.Win32.Foundation", "HANDLE"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "KERNEL32.dll", attributes: importAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.Storage.FileSystem", "Windows.Win32.Storage.FileSystem.Apis", method))
    }
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Storage.FileSystem",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("import windows_polyfill as windows_polyfill"), true)
    for (name in invalidHandleNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<HANDLE>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (windows_polyfill.handlePointerIsMinusOne(result__.Value)) {\n        return windows_core.Result<HANDLE>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<HANDLE>.Ok(result__)"), true)
    }
    @Expect(helper.contains("result__.Value.isNull()"), false)
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorNullSuccessHandleWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.HGLOBAL",
        SymbolRecord(
            "Windows.Win32.Foundation.HGLOBAL",
            "Windows.Win32.Foundation",
            "HGLOBAL",
            "Windows_Win32_Foundation_HGLOBAL",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "HGLOBAL",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Foundation.HLOCAL",
        SymbolRecord(
            "Windows.Win32.Foundation.HLOCAL",
            "Windows.Win32.Foundation",
            "HLOCAL",
            "Windows_Win32_Foundation_HLOCAL",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "HLOCAL",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let globalParameterTypes = ArrayList<SignatureRecord>()
    globalParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HGLOBAL"))
    let globalParameters = ArrayList<ParameterRecord>()
    globalParameters.add(ParameterRecord("hMem", sequenceNumber: 1))
    let globalMethod = MethodRecord(
        "GlobalFree",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HGLOBAL"),
            parameters: globalParameterTypes,
            requiredParameterCount: 1
        ),
        parameters: globalParameters,
        methodImport: Some(MethodImportRecord("GlobalFree", "KERNEL32.dll", attributes: importAttributes))
    )

    let localParameterTypes = ArrayList<SignatureRecord>()
    localParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HLOCAL"))
    let localParameters = ArrayList<ParameterRecord>()
    localParameters.add(ParameterRecord("hMem", sequenceNumber: 1))
    let localAttributes = ArrayList<CustomAttributeRecord>()
    localAttributes.add(CustomAttributeRecord("Windows.Win32.Foundation.Metadata.CanReturnErrorsAsSuccessAttribute"))
    let localMethod = MethodRecord(
        "LocalFree",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HLOCAL"),
            parameters: localParameterTypes,
            requiredParameterCount: 1
        ),
        parameters: localParameters,
        customAttributes: localAttributes,
        methodImport: Some(MethodImportRecord("LocalFree", "KERNEL32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.Foundation", "Windows.Win32.Foundation.Apis", globalMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Foundation", "Windows.Win32.Foundation.Apis", localMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Foundation",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("public func GlobalFreeChecked(hMem: HGLOBAL): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = GlobalFree(hMem)\n    if (result__.Value.isNotNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func LocalFreeChecked(hMem: HLOCAL): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = LocalFree(hMem)\n    if (result__.Value.isNotNull()) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorCheckedServiceHandleWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.System.Services.SC_HANDLE",
        SymbolRecord(
            "Windows.Win32.System.Services.SC_HANDLE",
            "Windows.Win32.System.Services",
            "SC_HANDLE",
            "Windows_Win32_System_Services_SC_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.System.Services",
                "SC_HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.System.Services.SERVICE_STATUS_HANDLE",
        SymbolRecord(
            "Windows.Win32.System.Services.SERVICE_STATUS_HANDLE",
            "Windows.Win32.System.Services",
            "SERVICE_STATUS_HANDLE",
            "Windows_Win32_System_Services_SERVICE_STATUS_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.System.Services",
                "SERVICE_STATUS_HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let openManagerParameterTypes = ArrayList<SignatureRecord>()
    openManagerParameterTypes.add(typeSignature("Windows.Win32.Foundation", "PWSTR"))
    openManagerParameterTypes.add(typeSignature("Windows.Win32.Foundation", "PWSTR"))
    openManagerParameterTypes.add(primitiveSignature("UInt32"))
    let openManagerParameters = ArrayList<ParameterRecord>()
    openManagerParameters.add(ParameterRecord("lpMachineName", sequenceNumber: 1))
    openManagerParameters.add(ParameterRecord("lpDatabaseName", sequenceNumber: 2))
    openManagerParameters.add(ParameterRecord("dwDesiredAccess", sequenceNumber: 3))
    let openManagerMethod = MethodRecord(
        "OpenSCManagerW",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.System.Services", "SC_HANDLE"),
            parameters: openManagerParameterTypes,
            requiredParameterCount: 3
        ),
        parameters: openManagerParameters,
        methodImport: Some(MethodImportRecord("OpenSCManagerW", "ADVAPI32.dll", attributes: importAttributes))
    )

    let registerMethod = MethodRecord(
        "RegisterServiceCtrlHandlerW",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.System.Services", "SERVICE_STATUS_HANDLE"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("RegisterServiceCtrlHandlerW", "ADVAPI32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.System.Services", "Windows.Win32.System.Services.Apis", openManagerMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Services", "Windows.Win32.System.Services.Apis", registerMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Services",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("public func OpenSCManagerW(lpMachineName: windows_strings.PWSTR, lpDatabaseName: windows_strings.PWSTR, dwDesiredAccess: UInt32): SC_HANDLE"), true)
    @Expect(helper.contains("public func OpenSCManagerWChecked(lpMachineName: windows_strings.PWSTR, lpDatabaseName: windows_strings.PWSTR, dwDesiredAccess: UInt32): windows_core.Result<SC_HANDLE>"), true)
    @Expect(helper.contains("let result__ = OpenSCManagerW(lpMachineName, lpDatabaseName, dwDesiredAccess)\n    if (result__.Value.isNull()) {\n        return windows_core.Result<SC_HANDLE>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<SC_HANDLE>.Ok(result__)"), true)
    @Expect(helper.contains("public func RegisterServiceCtrlHandlerWChecked(): windows_core.Result<SERVICE_STATUS_HANDLE>"), true)
    @Expect(helper.contains("let result__ = RegisterServiceCtrlHandlerW()\n    if (result__.Value.isNull()) {\n        return windows_core.Result<SERVICE_STATUS_HANDLE>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<SERVICE_STATUS_HANDLE>.Ok(result__)"), true)
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorCheckedThreadingPointerHandleWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.System.Threading.PTP_POOL",
        SymbolRecord(
            "Windows.Win32.System.Threading.PTP_POOL",
            "Windows.Win32.System.Threading",
            "PTP_POOL",
            "Windows_Win32_System_Threading_PTP_POOL",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.System.Threading",
                "PTP_POOL",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.System.Threading.AVRT_TASK_HANDLE",
        SymbolRecord(
            "Windows.Win32.System.Threading.AVRT_TASK_HANDLE",
            "Windows.Win32.System.Threading",
            "AVRT_TASK_HANDLE",
            "Windows_Win32_System_Threading_AVRT_TASK_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.System.Threading",
                "AVRT_TASK_HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let createThreadpoolMethod = MethodRecord(
        "CreateThreadpool",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.System.Threading", "PTP_POOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("CreateThreadpool", "KERNEL32.dll", attributes: importAttributes))
    )
    let avrtMethod = MethodRecord(
        "AvSetMmThreadCharacteristicsW",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.System.Threading", "AVRT_TASK_HANDLE"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("AvSetMmThreadCharacteristicsW", "AVRT.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", createThreadpoolMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", avrtMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Threading",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("public func CreateThreadpoolChecked(): windows_core.Result<PTP_POOL>"), true)
    @Expect(helper.contains("let result__ = CreateThreadpool()\n    if (result__.Value.isNull()) {\n        return windows_core.Result<PTP_POOL>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<PTP_POOL>.Ok(result__)"), true)
    @Expect(helper.contains("public func AvSetMmThreadCharacteristicsWChecked(): windows_core.Result<AVRT_TASK_HANDLE>"), true)
    @Expect(helper.contains("let result__ = AvSetMmThreadCharacteristicsW()\n    if (result__.Value.isNull()) {\n        return windows_core.Result<AVRT_TASK_HANDLE>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<AVRT_TASK_HANDLE>.Ok(result__)"), true)
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorWaitEventWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")
    let enumAttributes = ArrayList<String>()
    enumAttributes.add("Public")
    enumAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let boolFields = ArrayList<FieldRecord>()
    boolFields.add(FieldRecord("Value", primitiveSignature("Int32"), attributes: publicFieldAttributes))
    let waitEventFields = ArrayList<FieldRecord>()
    waitEventFields.add(FieldRecord("value__", primitiveSignature("UInt32"), attributes: publicFieldAttributes))

    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.HANDLE",
        SymbolRecord(
            "Windows.Win32.Foundation.HANDLE",
            "Windows.Win32.Foundation",
            "HANDLE",
            "Windows_Win32_Foundation_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Foundation.BOOL",
        SymbolRecord(
            "Windows.Win32.Foundation.BOOL",
            "Windows.Win32.Foundation",
            "BOOL",
            "Windows_Win32_Foundation_BOOL",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "BOOL",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: boolFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Foundation.WAIT_EVENT",
        SymbolRecord(
            "Windows.Win32.Foundation.WAIT_EVENT",
            "Windows.Win32.Foundation",
            "WAIT_EVENT",
            "Windows_Win32_Foundation_WAIT_EVENT",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "WAIT_EVENT",
                baseType: "System.Enum",
                hasBaseType: true,
                attributes: enumAttributes,
                fields: waitEventFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")
    let waitAttributes = ArrayList<CustomAttributeRecord>()
    waitAttributes.add(CustomAttributeRecord("Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute"))

    let singleParameterTypes = ArrayList<SignatureRecord>()
    singleParameterTypes.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    singleParameterTypes.add(primitiveSignature("UInt32"))
    let singleParameters = ArrayList<ParameterRecord>()
    singleParameters.add(ParameterRecord("hHandle", sequenceNumber: 1))
    singleParameters.add(ParameterRecord("dwMilliseconds", sequenceNumber: 2))
    let singleMethod = MethodRecord(
        "WaitForSingleObject",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "WAIT_EVENT"),
            parameters: singleParameterTypes,
            requiredParameterCount: 2
        ),
        parameters: singleParameters,
        customAttributes: waitAttributes,
        methodImport: Some(MethodImportRecord("WaitForSingleObject", "KERNEL32.dll", attributes: importAttributes))
    )

    let multipleParameterTypes = ArrayList<SignatureRecord>()
    multipleParameterTypes.add(primitiveSignature("UInt32"))
    multipleParameterTypes.add(pointerSignature(typeSignature("Windows.Win32.Foundation", "HANDLE")))
    multipleParameterTypes.add(typeSignature("Windows.Win32.Foundation", "BOOL"))
    multipleParameterTypes.add(primitiveSignature("UInt32"))
    let multipleParameters = ArrayList<ParameterRecord>()
    multipleParameters.add(ParameterRecord("nCount", sequenceNumber: 1))
    multipleParameters.add(ParameterRecord("lpHandles", sequenceNumber: 2))
    multipleParameters.add(ParameterRecord("bWaitAll", sequenceNumber: 3))
    multipleParameters.add(ParameterRecord("dwMilliseconds", sequenceNumber: 4))
    let multipleMethod = MethodRecord(
        "WaitForMultipleObjects",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "WAIT_EVENT"),
            parameters: multipleParameterTypes,
            requiredParameterCount: 4
        ),
        parameters: multipleParameters,
        customAttributes: waitAttributes,
        methodImport: Some(MethodImportRecord("WaitForMultipleObjects", "KERNEL32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", singleMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", multipleMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Threading",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("import windows_common.Win32.Foundation.WAIT_EVENT"), true)
    @Expect(helper.contains("public func WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: UInt32): UInt32"), true)
    @Expect(helper.contains("public func WaitForSingleObjectChecked(hHandle: HANDLE, dwMilliseconds: UInt32): windows_core.Result<WAIT_EVENT>"), true)
    @Expect(helper.contains("let result__ = WaitForSingleObject(hHandle, dwMilliseconds)\n    if (result__ == 0xFFFFFFFFu32) {\n        return windows_core.Result<WAIT_EVENT>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<WAIT_EVENT>.Ok(result__)"), true)
    @Expect(helper.contains("public func WaitForMultipleObjectsChecked(nCount: UInt32, lpHandles: CPointer<HANDLE>, bWaitAll: Bool, dwMilliseconds: UInt32): windows_core.Result<WAIT_EVENT>"), true)
    @Expect(helper.contains("if (result__ == 0xFFFFFFFFu32)"), true)
    @Expect(helper.contains("WAIT_TIMEOUT"), false)
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorScalarAndPointerSentinelWrappers() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))

    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.HANDLE",
        SymbolRecord(
            "Windows.Win32.Foundation.HANDLE",
            "Windows.Win32.Foundation",
            "HANDLE",
            "Windows_Win32_Foundation_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let tlsParameters = ArrayList<SignatureRecord>()
    tlsParameters.add(primitiveSignature("UInt32"))
    let tlsMetadata = ArrayList<ParameterRecord>()
    tlsMetadata.add(ParameterRecord("dwTlsIndex", sequenceNumber: 1))
    let tlsMethod = MethodRecord(
        "TlsGetValue",
        MethodSignatureRecord(
            pointerSignature(voidSignature()),
            parameters: tlsParameters,
            requiredParameterCount: 1
        ),
        parameters: tlsMetadata,
        methodImport: Some(MethodImportRecord("TlsGetValue", "KERNEL32.dll", attributes: importAttributes))
    )

    let flsGetValueParameters = ArrayList<SignatureRecord>()
    flsGetValueParameters.add(primitiveSignature("UInt32"))
    let flsGetValueMetadata = ArrayList<ParameterRecord>()
    flsGetValueMetadata.add(ParameterRecord("dwFlsIndex", sequenceNumber: 1))
    let flsGetValueMethod = MethodRecord(
        "FlsGetValue",
        MethodSignatureRecord(
            pointerSignature(voidSignature()),
            parameters: flsGetValueParameters,
            requiredParameterCount: 1
        ),
        parameters: flsGetValueMetadata,
        methodImport: Some(MethodImportRecord("FlsGetValue", "KERNEL32.dll", attributes: importAttributes))
    )

    let allocMethod = MethodRecord(
        "FlsAlloc",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("FlsAlloc", "KERNEL32.dll", attributes: importAttributes))
    )

    let priorityParameters = ArrayList<SignatureRecord>()
    priorityParameters.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    let priorityMetadata = ArrayList<ParameterRecord>()
    priorityMetadata.add(ParameterRecord("hThread", sequenceNumber: 1))
    let priorityMethod = MethodRecord(
        "GetThreadPriority",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: priorityParameters,
            requiredParameterCount: 1
        ),
        parameters: priorityMetadata,
        methodImport: Some(MethodImportRecord("GetThreadPriority", "KERNEL32.dll", attributes: importAttributes))
    )
    let priorityClassMethod = MethodRecord(
        "GetPriorityClass",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: priorityParameters,
            requiredParameterCount: 1
        ),
        parameters: priorityMetadata,
        methodImport: Some(MethodImportRecord("GetPriorityClass", "KERNEL32.dll", attributes: importAttributes))
    )

    let idealProcessorParameters = ArrayList<SignatureRecord>()
    idealProcessorParameters.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    idealProcessorParameters.add(primitiveSignature("UInt32"))
    let idealProcessorMetadata = ArrayList<ParameterRecord>()
    idealProcessorMetadata.add(ParameterRecord("hThread", sequenceNumber: 1))
    idealProcessorMetadata.add(ParameterRecord("dwIdealProcessor", sequenceNumber: 2))
    let idealProcessorMethod = MethodRecord(
        "SetThreadIdealProcessor",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: idealProcessorParameters,
            requiredParameterCount: 2
        ),
        parameters: idealProcessorMetadata,
        methodImport: Some(MethodImportRecord("SetThreadIdealProcessor", "KERNEL32.dll", attributes: importAttributes))
    )

    let processorCountParameters = ArrayList<SignatureRecord>()
    processorCountParameters.add(primitiveSignature("UInt16"))
    let processorCountMetadata = ArrayList<ParameterRecord>()
    processorCountMetadata.add(ParameterRecord("GroupNumber", sequenceNumber: 1))
    let activeProcessorCountMethod = MethodRecord(
        "GetActiveProcessorCount",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: processorCountParameters,
            requiredParameterCount: 1
        ),
        parameters: processorCountMetadata,
        methodImport: Some(MethodImportRecord("GetActiveProcessorCount", "KERNEL32.dll", attributes: importAttributes))
    )
    let maximumProcessorCountMethod = MethodRecord(
        "GetMaximumProcessorCount",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: processorCountParameters,
            requiredParameterCount: 1
        ),
        parameters: processorCountMetadata,
        methodImport: Some(MethodImportRecord("GetMaximumProcessorCount", "KERNEL32.dll", attributes: importAttributes))
    )

    let guiResourceParameters = ArrayList<SignatureRecord>()
    guiResourceParameters.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    guiResourceParameters.add(primitiveSignature("UInt32"))
    let guiResourceMetadata = ArrayList<ParameterRecord>()
    guiResourceMetadata.add(ParameterRecord("hProcess", sequenceNumber: 1))
    guiResourceMetadata.add(ParameterRecord("uiFlags", sequenceNumber: 2))
    let guiResourceMethod = MethodRecord(
        "GetGuiResources",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: guiResourceParameters,
            requiredParameterCount: 2
        ),
        parameters: guiResourceMetadata,
        methodImport: Some(MethodImportRecord("GetGuiResources", "USER32.dll", attributes: importAttributes))
    )

    let waitInputIdleImportAttributes = ArrayList<String>()
    waitInputIdleImportAttributes.add("ExactSpelling")
    waitInputIdleImportAttributes.add("CallingConventionWinApi")
    let waitInputIdleParameters = ArrayList<SignatureRecord>()
    waitInputIdleParameters.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    waitInputIdleParameters.add(primitiveSignature("UInt32"))
    let waitInputIdleMetadata = ArrayList<ParameterRecord>()
    waitInputIdleMetadata.add(ParameterRecord("hProcess", sequenceNumber: 1))
    waitInputIdleMetadata.add(ParameterRecord("dwMilliseconds", sequenceNumber: 2))
    let waitInputIdleMethod = MethodRecord(
        "WaitForInputIdle",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: waitInputIdleParameters,
            requiredParameterCount: 2
        ),
        parameters: waitInputIdleMetadata,
        methodImport: Some(MethodImportRecord("WaitForInputIdle", "USER32.dll", attributes: waitInputIdleImportAttributes))
    )

    let winExecParameters = ArrayList<SignatureRecord>()
    winExecParameters.add(typeSignature("Windows.Win32.Foundation", "PSTR"))
    winExecParameters.add(primitiveSignature("UInt32"))
    let winExecMetadata = ArrayList<ParameterRecord>()
    winExecMetadata.add(ParameterRecord("lpCmdLine", sequenceNumber: 1))
    winExecMetadata.add(ParameterRecord("uCmdShow", sequenceNumber: 2))
    let winExecMethod = MethodRecord(
        "WinExec",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: winExecParameters,
            requiredParameterCount: 2
        ),
        parameters: winExecMetadata,
        methodImport: Some(MethodImportRecord("WinExec", "KERNEL32.dll", attributes: waitInputIdleImportAttributes))
    )

    let directErrorImportAttributes = ArrayList<String>()
    directErrorImportAttributes.add("ExactSpelling")
    directErrorImportAttributes.add("CallingConventionWinApi")
    let httpInitializeMethod = MethodRecord(
        "HttpInitialize",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("HttpInitialize", "HTTPAPI.dll", attributes: directErrorImportAttributes))
    )
    let httpReceiveRequestMethod = MethodRecord(
        "HttpReceiveHttpRequest",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("HttpReceiveHttpRequest", "HTTPAPI.dll", attributes: directErrorImportAttributes))
    )
    let httpReceiveEntityBodyMethod = MethodRecord(
        "HttpReceiveRequestEntityBody",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("HttpReceiveRequestEntityBody", "HTTPAPI.dll", attributes: directErrorImportAttributes))
    )
    let httpSendResponseMethod = MethodRecord(
        "HttpSendHttpResponse",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("HttpSendHttpResponse", "HTTPAPI.dll", attributes: directErrorImportAttributes))
    )
    let httpSendEntityBodyMethod = MethodRecord(
        "HttpSendResponseEntityBody",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("HttpSendResponseEntityBody", "HTTPAPI.dll", attributes: directErrorImportAttributes))
    )
    let webSocketSendMethod = MethodRecord(
        "WinHttpWebSocketSend",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpWebSocketSend", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let winHttpReadDataExMethod = MethodRecord(
        "WinHttpReadDataEx",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpReadDataEx", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let winHttpAddRequestHeadersExMethod = MethodRecord(
        "WinHttpAddRequestHeadersEx",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpAddRequestHeadersEx", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let winHttpGetProxyForUrlExMethod = MethodRecord(
        "WinHttpGetProxyForUrlEx",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpGetProxyForUrlEx", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let winHttpGetProxyForUrlEx2Method = MethodRecord(
        "WinHttpGetProxyForUrlEx2",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpGetProxyForUrlEx2", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let winHttpGetProxySettingsExMethod = MethodRecord(
        "WinHttpGetProxySettingsEx",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpGetProxySettingsEx", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let winHttpQueryHeadersExMethod = MethodRecord(
        "WinHttpQueryHeadersEx",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpQueryHeadersEx", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let webSocketReceiveMethod = MethodRecord(
        "WinHttpWebSocketReceive",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpWebSocketReceive", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let webSocketQueryCloseStatusMethod = MethodRecord(
        "WinHttpWebSocketQueryCloseStatus",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WinHttpWebSocketQueryCloseStatus", "WINHTTP.dll", attributes: directErrorImportAttributes))
    )
    let processSocketNotificationsMethod = MethodRecord(
        "ProcessSocketNotifications",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("ProcessSocketNotifications", "WS2_32.dll", attributes: directErrorImportAttributes))
    )
    let dnsSetApplicationSettingsMethod = MethodRecord(
        "DnsSetApplicationSettings",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsSetApplicationSettings", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsQueryAMethod = MethodRecord(
        "DnsQuery_A",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsQuery_A", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsQueryUtf8Method = MethodRecord(
        "DnsQuery_UTF8",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsQuery_UTF8", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsQueryWMethod = MethodRecord(
        "DnsQuery_W",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsQuery_W", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsQueryConfigMethod = MethodRecord(
        "DnsQueryConfig",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsQueryConfig", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsQueryExMethod = MethodRecord(
        "DnsQueryEx",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsQueryEx", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsCancelQueryMethod = MethodRecord(
        "DnsCancelQuery",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsCancelQuery", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsQueryRawMethod = MethodRecord(
        "DnsQueryRaw",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsQueryRaw", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsCancelQueryRawMethod = MethodRecord(
        "DnsCancelQueryRaw",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsCancelQueryRaw", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsServiceBrowseMethod = MethodRecord(
        "DnsServiceBrowse",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsServiceBrowse", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsServiceBrowseCancelMethod = MethodRecord(
        "DnsServiceBrowseCancel",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsServiceBrowseCancel", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsServiceResolveMethod = MethodRecord(
        "DnsServiceResolve",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsServiceResolve", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsServiceResolveCancelMethod = MethodRecord(
        "DnsServiceResolveCancel",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsServiceResolveCancel", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsStartMulticastQueryMethod = MethodRecord(
        "DnsStartMulticastQuery",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsStartMulticastQuery", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsStopMulticastQueryMethod = MethodRecord(
        "DnsStopMulticastQuery",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsStopMulticastQuery", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsServiceRegisterMethod = MethodRecord(
        "DnsServiceRegister",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsServiceRegister", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )
    let dnsServiceDeRegisterMethod = MethodRecord(
        "DnsServiceDeRegister",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("DnsServiceDeRegister", "DNSAPI.dll", attributes: directErrorImportAttributes))
    )

    let dnsDirectStatusUnitNames = ArrayList<String>()
    dnsDirectStatusUnitNames.add("DnsAcquireContextHandle_W")
    dnsDirectStatusUnitNames.add("DnsAcquireContextHandle_A")
    dnsDirectStatusUnitNames.add("DnsModifyRecordsInSet_W")
    dnsDirectStatusUnitNames.add("DnsModifyRecordsInSet_A")
    dnsDirectStatusUnitNames.add("DnsModifyRecordsInSet_UTF8")
    dnsDirectStatusUnitNames.add("DnsReplaceRecordSetW")
    dnsDirectStatusUnitNames.add("DnsReplaceRecordSetA")
    dnsDirectStatusUnitNames.add("DnsReplaceRecordSetUTF8")
    dnsDirectStatusUnitNames.add("DnsExtractRecordsFromMessage_W")
    dnsDirectStatusUnitNames.add("DnsExtractRecordsFromMessage_UTF8")
    dnsDirectStatusUnitNames.add("DnsIsFlatRecord")

    let dnsDirectUInt32UnitNames = ArrayList<String>()
    dnsDirectUInt32UnitNames.add("DnsGetApplicationSettings")
    dnsDirectUInt32UnitNames.add("DnsGetProxyInformation")

    let dnsValidateNameStatusNames = ArrayList<String>()
    dnsValidateNameStatusNames.add("DnsValidateName_W")
    dnsValidateNameStatusNames.add("DnsValidateName_A")
    dnsValidateNameStatusNames.add("DnsValidateName_UTF8")

    let fiberMethod = MethodRecord(
        "CreateFiberEx",
        MethodSignatureRecord(
            pointerSignature(voidSignature()),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("CreateFiberEx", "KERNEL32.dll", attributes: importAttributes))
    )
    let affinityParameters = ArrayList<SignatureRecord>()
    affinityParameters.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    affinityParameters.add(primitiveSignature("UIntPtr"))
    let affinityMetadata = ArrayList<ParameterRecord>()
    affinityMetadata.add(ParameterRecord("hThread", sequenceNumber: 1))
    affinityMetadata.add(ParameterRecord("dwThreadAffinityMask", sequenceNumber: 2))
    let affinityMethod = MethodRecord(
        "SetThreadAffinityMask",
        MethodSignatureRecord(
            primitiveSignature("UIntPtr"),
            parameters: affinityParameters,
            requiredParameterCount: 2
        ),
        parameters: affinityMetadata,
        methodImport: Some(MethodImportRecord("SetThreadAffinityMask", "KERNEL32.dll", attributes: importAttributes))
    )

    let httpDirectStatusUnitNames = ArrayList<String>()
    httpDirectStatusUnitNames.add("HttpCancelHttpRequest")
    httpDirectStatusUnitNames.add("HttpSetServiceConfiguration")
    httpDirectStatusUnitNames.add("HttpUpdateServiceConfiguration")
    httpDirectStatusUnitNames.add("HttpDeleteServiceConfiguration")

    let httpBufferProbeStatusNames = ArrayList<String>()
    httpBufferProbeStatusNames.add("HttpQueryRequestQueueProperty")
    httpBufferProbeStatusNames.add("HttpQueryServerSessionProperty")
    httpBufferProbeStatusNames.add("HttpQueryUrlGroupProperty")

    let httpAsyncStatusNames = ArrayList<String>()
    httpAsyncStatusNames.add("HttpSetRequestProperty")
    httpAsyncStatusNames.add("HttpWaitForDisconnect")
    httpAsyncStatusNames.add("HttpWaitForDisconnectEx")
    httpAsyncStatusNames.add("HttpWaitForDemandStart")
    httpAsyncStatusNames.add("HttpFlushResponseCache")
    httpAsyncStatusNames.add("HttpAddFragmentToCache")

    let httpAsyncBufferStatusNames = ArrayList<String>()
    httpAsyncBufferStatusNames.add("HttpReceiveClientCertificate")
    httpAsyncBufferStatusNames.add("HttpReadFragmentFromCache")

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", tlsMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", flsGetValueMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", allocMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", priorityMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", priorityClassMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", idealProcessorMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", activeProcessorCountMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", maximumProcessorCountMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", guiResourceMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", waitInputIdleMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", winExecMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", httpInitializeMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", httpReceiveRequestMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", httpReceiveEntityBodyMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", httpSendResponseMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", httpSendEntityBodyMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", webSocketSendMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", winHttpReadDataExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", winHttpAddRequestHeadersExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", winHttpGetProxyForUrlExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", winHttpGetProxyForUrlEx2Method))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", winHttpGetProxySettingsExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", winHttpQueryHeadersExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", webSocketReceiveMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", webSocketQueryCloseStatusMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", processSocketNotificationsMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsSetApplicationSettingsMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsQueryAMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsQueryUtf8Method))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsQueryWMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsQueryConfigMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsQueryExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsCancelQueryMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsQueryRawMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsCancelQueryRawMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsServiceBrowseMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsServiceBrowseCancelMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsServiceResolveMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsServiceResolveCancelMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsStartMulticastQueryMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsStopMulticastQueryMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsServiceRegisterMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", dnsServiceDeRegisterMethod))
    for (name in dnsDirectStatusUnitNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                primitiveSignature("Int32"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "DNSAPI.dll", attributes: directErrorImportAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    for (name in dnsDirectUInt32UnitNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                primitiveSignature("UInt32"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "DNSAPI.dll", attributes: directErrorImportAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    for (name in dnsValidateNameStatusNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                primitiveSignature("Int32"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "DNSAPI.dll", attributes: directErrorImportAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    for (name in httpDirectStatusUnitNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                primitiveSignature("UInt32"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "HTTPAPI.dll", attributes: directErrorImportAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    for (name in httpBufferProbeStatusNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                primitiveSignature("UInt32"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "HTTPAPI.dll", attributes: directErrorImportAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    for (name in httpAsyncStatusNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                primitiveSignature("UInt32"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "HTTPAPI.dll", attributes: directErrorImportAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    for (name in httpAsyncBufferStatusNames) {
        let method = MethodRecord(
            name,
            MethodSignatureRecord(
                primitiveSignature("UInt32"),
                parameters: ArrayList<SignatureRecord>(),
                requiredParameterCount: 0
            ),
            methodImport: Some(MethodImportRecord(name, "HTTPAPI.dll", attributes: directErrorImportAttributes))
        )
        specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", method))
    }
    let httpQueryRequestPropertyMethod = MethodRecord(
        "HttpQueryRequestProperty",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("HttpQueryRequestProperty", "HTTPAPI.dll", attributes: directErrorImportAttributes))
    )
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", httpQueryRequestPropertyMethod))
    let httpQueryServiceConfigurationMethod = MethodRecord(
        "HttpQueryServiceConfiguration",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("HttpQueryServiceConfiguration", "HTTPAPI.dll", attributes: directErrorImportAttributes))
    )
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", httpQueryServiceConfigurationMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", fiberMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.System.Threading", "Windows.Win32.System.Threading.Apis", affinityMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.System.Threading",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    @Expect(helper.contains("import windows_common.Win32.Foundation.SetLastError"), false)
    @Expect(helper.contains("import windows_strings as windows_strings"), true)
    @Expect(helper.contains("public func TlsGetValueChecked(dwTlsIndex: UInt32): windows_core.Result<CPointer<Unit>>"), true)
    @Expect(helper.contains("let setLastErrorProc__ = CFunc<(UInt32) -> Unit>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"SetLastError\"))\n    unsafe { setLastErrorProc__(0u32) }\n    let result__ = TlsGetValue(dwTlsIndex)\n    if (result__.isNotNull()) {\n        return windows_core.Result<CPointer<Unit>>.Ok(result__)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 0u32) {\n        return windows_core.Result<CPointer<Unit>>.Ok(result__)\n    }\n    windows_core.Result<CPointer<Unit>>.Err(windows_core.errorFromWin32(lastError__))"), true)
    @Expect(helper.contains("public func FlsGetValueChecked(dwFlsIndex: UInt32): windows_core.Result<CPointer<Unit>>"), true)
    @Expect(helper.contains("let setLastErrorProc__ = CFunc<(UInt32) -> Unit>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"SetLastError\"))\n    unsafe { setLastErrorProc__(0u32) }\n    let result__ = FlsGetValue(dwFlsIndex)\n    if (result__.isNotNull()) {\n        return windows_core.Result<CPointer<Unit>>.Ok(result__)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 0u32) {\n        return windows_core.Result<CPointer<Unit>>.Ok(result__)\n    }\n    windows_core.Result<CPointer<Unit>>.Err(windows_core.errorFromWin32(lastError__))"), true)
    @Expect(helper.contains("public func FlsAllocChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = FlsAlloc()\n    if (result__ == 0xFFFFFFFFu32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetThreadPriorityChecked(hThread: HANDLE): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = GetThreadPriority(hThread)\n    if (result__ == 2147483647) {\n        return windows_core.Result<Int32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetPriorityClassChecked(hThread: HANDLE): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = GetPriorityClass(hThread)\n    if (result__ == 0u32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func SetThreadIdealProcessorChecked(hThread: HANDLE, dwIdealProcessor: UInt32): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = SetThreadIdealProcessor(hThread, dwIdealProcessor)\n    if (result__ == 0xFFFFFFFFu32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetActiveProcessorCountChecked(GroupNumber: UInt16): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = GetActiveProcessorCount(GroupNumber)\n    if (result__ == 0u32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetMaximumProcessorCountChecked(GroupNumber: UInt16): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = GetMaximumProcessorCount(GroupNumber)\n    if (result__ == 0u32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetGuiResourcesChecked(hProcess: HANDLE, uiFlags: UInt32): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let setLastErrorProc__ = CFunc<(UInt32) -> Unit>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"SetLastError\"))\n    unsafe { setLastErrorProc__(0u32) }\n    let result__ = GetGuiResources(hProcess, uiFlags)\n    if (result__ != 0u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 0u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(lastError__))"), true)
    @Expect(helper.contains("public func WaitForInputIdleChecked(hProcess: HANDLE, dwMilliseconds: UInt32): windows_core.Result<WAIT_EVENT>"), true)
    @Expect(helper.contains("let result__ = WaitForInputIdle(hProcess, dwMilliseconds)\n    if (result__ == 0xFFFFFFFFu32) {\n        return windows_core.Result<WAIT_EVENT>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<WAIT_EVENT>.Ok(result__)"), true)
    @Expect(helper.contains("public func WinExecChecked(lpCmdLine: windows_strings.PSTR, uCmdShow: UInt32): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = WinExec(lpCmdLine, uCmdShow)\n    if (result__ <= 31u32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func HttpInitializeChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = HttpInitialize()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    for (name in httpDirectStatusUnitNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    }
    for (name in httpBufferProbeStatusNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<UInt32>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__ == 0u32 || result__ == 234u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    }
    for (name in httpAsyncStatusNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<UInt32>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__ == 0u32 || result__ == 997u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    }
    for (name in httpAsyncBufferStatusNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<UInt32>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__ == 0u32 || result__ == 997u32 || result__ == 122u32 || result__ == 234u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    }
    @Expect(helper.contains("public func HttpQueryRequestPropertyChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = HttpQueryRequestProperty()\n    if (result__ == 0u32 || result__ == 997u32 || result__ == 234u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func HttpQueryServiceConfigurationChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = HttpQueryServiceConfiguration()\n    if (result__ == 0u32 || result__ == 122u32 || result__ == 234u32 || result__ == 259u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func HttpReceiveHttpRequestChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = HttpReceiveHttpRequest()\n    if (result__ == 0u32 || result__ == 997u32 || result__ == 234u32 || result__ == 38u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func HttpReceiveRequestEntityBodyChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = HttpReceiveRequestEntityBody()\n    if (result__ == 0u32 || result__ == 997u32 || result__ == 38u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func HttpSendHttpResponseChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = HttpSendHttpResponse()\n    if (result__ == 0u32 || result__ == 997u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func HttpSendResponseEntityBodyChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = HttpSendResponseEntityBody()\n    if (result__ == 0u32 || result__ == 997u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func WinHttpWebSocketSendChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WinHttpWebSocketSend()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WinHttpReadDataExChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WinHttpReadDataEx()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WinHttpAddRequestHeadersExChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WinHttpAddRequestHeadersEx()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WinHttpGetProxyForUrlExChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = WinHttpGetProxyForUrlEx()\n    if (result__ == 997u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func WinHttpGetProxyForUrlEx2Checked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = WinHttpGetProxyForUrlEx2()\n    if (result__ == 997u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func WinHttpGetProxySettingsExChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = WinHttpGetProxySettingsEx()\n    if (result__ == 997u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func WinHttpQueryHeadersExChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = WinHttpQueryHeadersEx()\n    if (result__ == 0u32 || result__ == 122u32 || result__ == 12150u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func WinHttpWebSocketReceiveChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WinHttpWebSocketReceive()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WinHttpWebSocketQueryCloseStatusChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = WinHttpWebSocketQueryCloseStatus()\n    if (result__ == 0u32 || result__ == 122u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func ProcessSocketNotificationsChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = ProcessSocketNotifications()\n    if (result__ == 0u32 || result__ == 258u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func DnsSetApplicationSettingsChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = DnsSetApplicationSettings()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    for (name in dnsDirectUInt32UnitNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__ != 0u32) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(result__))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    }
    @Expect(helper.contains("public func DnsQuery_AChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = DnsQuery_A()\n    if (result__ == 0u32 || result__ == 9501u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func DnsQuery_UTF8Checked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = DnsQuery_UTF8()\n    if (result__ == 0u32 || result__ == 9501u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func DnsQuery_WChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = DnsQuery_W()\n    if (result__ == 0u32 || result__ == 9501u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func DnsQueryConfigChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = DnsQueryConfig()\n    if (result__ == 0 || result__ == 234) {\n        return windows_core.Result<Int32>.Ok(result__)\n    }\n    windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))"), true)
    @Expect(helper.contains("public func DnsQueryExChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = DnsQueryEx()\n    if (result__ == 0 || result__ == 9501 || result__ == 9506) {\n        return windows_core.Result<Int32>.Ok(result__)\n    }\n    windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))"), true)
    @Expect(helper.contains("public func DnsCancelQueryChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = DnsCancelQuery()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func DnsQueryRawChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = DnsQueryRaw()\n    if (result__ == 0 || result__ == 9506) {\n        return windows_core.Result<Int32>.Ok(result__)\n    }\n    windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))"), true)
    @Expect(helper.contains("public func DnsCancelQueryRawChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = DnsCancelQueryRaw()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    for (name in dnsDirectStatusUnitNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<Unit>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    }
    for (name in dnsValidateNameStatusNames) {
        @Expect(helper.contains("public func ${name}Checked(): windows_core.Result<Int32>"), true)
        @Expect(helper.contains("let result__ = ${name}()\n    if (result__ == 0 || result__ == 9556) {\n        return windows_core.Result<Int32>.Ok(result__)\n    }\n    windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))"), true)
    }
    @Expect(helper.contains("public func DnsServiceBrowseChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = DnsServiceBrowse()\n    if (result__ == 9506) {\n        return windows_core.Result<Int32>.Ok(result__)\n    }\n    windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))"), true)
    @Expect(helper.contains("public func DnsServiceBrowseCancelChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = DnsServiceBrowseCancel()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func DnsServiceResolveChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = DnsServiceResolve()\n    if (result__ == 9506) {\n        return windows_core.Result<Int32>.Ok(result__)\n    }\n    windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))"), true)
    @Expect(helper.contains("public func DnsServiceResolveCancelChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = DnsServiceResolveCancel()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func DnsStartMulticastQueryChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = DnsStartMulticastQuery()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func DnsStopMulticastQueryChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = DnsStopMulticastQuery()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func DnsServiceRegisterChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = DnsServiceRegister()\n    if (result__ == 0u32 || result__ == 9506u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func DnsServiceDeRegisterChecked(): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = DnsServiceDeRegister()\n    if (result__ == 0u32 || result__ == 9506u32) {\n        return windows_core.Result<UInt32>.Ok(result__)\n    }\n    windows_core.Result<UInt32>.Err(windows_core.errorFromWin32(result__))"), true)
    @Expect(helper.contains("public func CreateFiberExChecked(): windows_core.Result<CPointer<Unit>>"), true)
    @Expect(helper.contains("let result__ = CreateFiberEx()\n    if (result__.isNull()) {\n        return windows_core.Result<CPointer<Unit>>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<CPointer<Unit>>.Ok(result__)"), true)
    @Expect(helper.contains("public func SetThreadAffinityMaskChecked(hThread: HANDLE, dwThreadAffinityMask: UIntNative): windows_core.Result<UIntNative>"), true)
    @Expect(helper.contains("let result__ = SetThreadAffinityMask(hThread, dwThreadAffinityMask)\n    if (result__ == 0) {\n        return windows_core.Result<UIntNative>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UIntNative>.Ok(result__)"), true)
}

@Test
func testCommonNativeHelperFilesRenderWinSockSocketErrorCheckedWrapper() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")
    let enumAttributes = ArrayList<String>()
    enumAttributes.add("Public")
    enumAttributes.add("Sealed")
    let boolFields = ArrayList<FieldRecord>()
    boolFields.add(FieldRecord("Value", primitiveSignature("Int32"), attributes: publicFieldAttributes))
    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let wsaEventFields = ArrayList<FieldRecord>()
    wsaEventFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let waitEventFields = ArrayList<FieldRecord>()
    waitEventFields.add(FieldRecord("value__", primitiveSignature("UInt32"), attributes: publicFieldAttributes))
    let socketFields = ArrayList<FieldRecord>()
    socketFields.add(FieldRecord("Value", primitiveSignature("UIntPtr"), attributes: publicFieldAttributes))
    let hostentFields = ArrayList<FieldRecord>()
    hostentFields.add(FieldRecord("h_name", pointerSignature(primitiveSignature("UInt8")), attributes: publicFieldAttributes))
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.BOOL",
        SymbolRecord(
            "Windows.Win32.Foundation.BOOL",
            "Windows.Win32.Foundation",
            "BOOL",
            "Windows_Win32_Foundation_BOOL",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "BOOL",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: boolFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Foundation.WAIT_EVENT",
        SymbolRecord(
            "Windows.Win32.Foundation.WAIT_EVENT",
            "Windows.Win32.Foundation",
            "WAIT_EVENT",
            "Windows_Win32_Foundation_WAIT_EVENT",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "WAIT_EVENT",
                baseType: "System.Enum",
                hasBaseType: true,
                attributes: enumAttributes,
                fields: waitEventFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Foundation.HANDLE",
        SymbolRecord(
            "Windows.Win32.Foundation.HANDLE",
            "Windows.Win32.Foundation",
            "HANDLE",
            "Windows_Win32_Foundation_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Networking.WinSock.SOCKET",
        SymbolRecord(
            "Windows.Win32.Networking.WinSock.SOCKET",
            "Windows.Win32.Networking.WinSock",
            "SOCKET",
            "Windows_Win32_Networking_WinSock_SOCKET",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Networking.WinSock",
                "SOCKET",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: socketFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Networking.WinSock.WSAEVENT",
        SymbolRecord(
            "Windows.Win32.Networking.WinSock.WSAEVENT",
            "Windows.Win32.Networking.WinSock",
            "WSAEVENT",
            "Windows_Win32_Networking_WinSock_WSAEVENT",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Networking.WinSock",
                "WSAEVENT",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: wsaEventFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Networking.WinSock.HOSTENT",
        SymbolRecord(
            "Windows.Win32.Networking.WinSock.HOSTENT",
            "Windows.Win32.Networking.WinSock",
            "HOSTENT",
            "Windows_Win32_Networking_WinSock_HOSTENT",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Networking.WinSock",
                "HOSTENT",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: hostentFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")
    let importAttributesNoSetLastError = ArrayList<String>()
    importAttributesNoSetLastError.add("ExactSpelling")
    importAttributesNoSetLastError.add("CallingConventionWinApi")

    let connectParameters = ArrayList<SignatureRecord>()
    connectParameters.add(primitiveSignature("UIntPtr"))
    connectParameters.add(pointerSignature(voidSignature()))
    connectParameters.add(primitiveSignature("Int32"))
    let connectMetadata = ArrayList<ParameterRecord>()
    connectMetadata.add(ParameterRecord("s", sequenceNumber: 1))
    connectMetadata.add(ParameterRecord("name", sequenceNumber: 2))
    connectMetadata.add(ParameterRecord("namelen", sequenceNumber: 3))
    let connectMethod = MethodRecord(
        "connect",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: connectParameters,
            requiredParameterCount: 3
        ),
        parameters: connectMetadata,
        methodImport: Some(MethodImportRecord("connect", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaEventSelectMethod = MethodRecord(
        "WSAEventSelect",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAEventSelect", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaRecvMethod = MethodRecord(
        "WSARecv",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSARecv", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaRecvExMethod = MethodRecord(
        "WSARecvEx",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSARecvEx", "MSWSOCK.dll", attributes: importAttributes))
    )
    let getAddressByNameMethod = MethodRecord(
        "GetAddressByNameA",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetAddressByNameA", "MSWSOCK.dll", attributes: importAttributes))
    )
    let getTypeByNameMethod = MethodRecord(
        "GetTypeByNameA",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetTypeByNameA", "MSWSOCK.dll", attributes: importAttributes))
    )
    let setServiceMethod = MethodRecord(
        "SetServiceA",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("SetServiceA", "MSWSOCK.dll", attributes: importAttributes))
    )
    let wscEnumNameSpaceProviders32Method = MethodRecord(
        "WSCEnumNameSpaceProviders32",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSCEnumNameSpaceProviders32", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )
    let inetPtonMethod = MethodRecord(
        "inet_pton",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("inet_pton", "WS2_32.dll", attributes: importAttributes))
    )
    let inetPtonWMethod = MethodRecord(
        "InetPtonW",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("InetPtonW", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )
    let wsaStartupMethod = MethodRecord(
        "WSAStartup",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAStartup", "WS2_32.dll", attributes: importAttributes))
    )
    let wscWriteProviderOrderMethod = MethodRecord(
        "WSCWriteProviderOrder",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSCWriteProviderOrder", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )
    let wscInstallNameSpaceMethod = MethodRecord(
        "WSCInstallNameSpace",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSCInstallNameSpace", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )
    let getAddrInfoExAMethod = MethodRecord(
        "GetAddrInfoExA",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetAddrInfoExA", "WS2_32.dll", attributes: importAttributes))
    )
    let getAddrInfoExWMethod = MethodRecord(
        "GetAddrInfoExW",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetAddrInfoExW", "WS2_32.dll", attributes: importAttributes))
    )
    let getAddrInfoExCancelMethod = MethodRecord(
        "GetAddrInfoExCancel",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetAddrInfoExCancel", "WS2_32.dll", attributes: importAttributes))
    )
    let setAddrInfoExAMethod = MethodRecord(
        "SetAddrInfoExA",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("SetAddrInfoExA", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )
    let setAddrInfoExWMethod = MethodRecord(
        "SetAddrInfoExW",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("SetAddrInfoExW", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )
    let getAddrInfoExOverlappedResultMethod = MethodRecord(
        "GetAddrInfoExOverlappedResult",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetAddrInfoExOverlappedResult", "WS2_32.dll", attributes: importAttributes))
    )
    let lpErrnoParameters = ArrayList<SignatureRecord>()
    lpErrnoParameters.add(pointerSignature(primitiveSignature("Int32")))
    let lpErrnoMetadata = ArrayList<ParameterRecord>()
    lpErrnoMetadata.add(ParameterRecord("lpErrno", sequenceNumber: 1))
    let wscEnumProtocolsMethod = MethodRecord(
        "WSCEnumProtocols",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: lpErrnoParameters,
            requiredParameterCount: 1
        ),
        parameters: lpErrnoMetadata,
        methodImport: Some(MethodImportRecord("WSCEnumProtocols", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )
    let wscDeinstallProviderMethod = MethodRecord(
        "WSCDeinstallProvider",
        MethodSignatureRecord(
            primitiveSignature("Int32"),
            parameters: lpErrnoParameters,
            requiredParameterCount: 1
        ),
        parameters: lpErrnoMetadata,
        methodImport: Some(MethodImportRecord("WSCDeinstallProvider", "WS2_32.dll", attributes: importAttributesNoSetLastError))
    )

    let socketMethod = MethodRecord(
        "socket",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Networking.WinSock", "SOCKET"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("socket", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaResetEventMethod = MethodRecord(
        "WSAResetEvent",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAResetEvent", "WS2_32.dll", attributes: importAttributes))
    )
    let acceptExMethod = MethodRecord(
        "AcceptEx",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("AcceptEx", "MSWSOCK.dll", attributes: importAttributesNoSetLastError))
    )
    let transmitFileMethod = MethodRecord(
        "TransmitFile",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("TransmitFile", "MSWSOCK.dll", attributes: importAttributesNoSetLastError))
    )
    let wsaIsBlockingMethod = MethodRecord(
        "WSAIsBlocking",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAIsBlocking", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaWaitForMultipleEventsMethod = MethodRecord(
        "WSAWaitForMultipleEvents",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "WAIT_EVENT"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAWaitForMultipleEvents", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaCreateEventMethod = MethodRecord(
        "WSACreateEvent",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Networking.WinSock", "WSAEVENT"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSACreateEvent", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaAsyncGetHostByNameMethod = MethodRecord(
        "WSAAsyncGetHostByName",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "HANDLE"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAAsyncGetHostByName", "WS2_32.dll", attributes: importAttributes))
    )
    let getHostByNameMethod = MethodRecord(
        "gethostbyname",
        MethodSignatureRecord(
            pointerSignature(typeSignature("Windows.Win32.Networking.WinSock", "HOSTENT")),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("gethostbyname", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaAcceptMethod = MethodRecord(
        "WSAAccept",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Networking.WinSock", "SOCKET"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAAccept", "WS2_32.dll", attributes: importAttributes))
    )
    let wsaJoinLeafMethod = MethodRecord(
        "WSAJoinLeaf",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Networking.WinSock", "SOCKET"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("WSAJoinLeaf", "WS2_32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", connectMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaEventSelectMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaRecvMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaRecvExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", getAddressByNameMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", getTypeByNameMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", setServiceMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wscEnumNameSpaceProviders32Method))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", inetPtonMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", inetPtonWMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaStartupMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wscWriteProviderOrderMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wscInstallNameSpaceMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", getAddrInfoExAMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", getAddrInfoExWMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", getAddrInfoExCancelMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", setAddrInfoExAMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", setAddrInfoExWMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", getAddrInfoExOverlappedResultMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wscEnumProtocolsMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wscDeinstallProviderMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", socketMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaResetEventMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", acceptExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", transmitFileMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaIsBlockingMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaWaitForMultipleEventsMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaCreateEventMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaAsyncGetHostByNameMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", getHostByNameMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaAcceptMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Networking.WinSock", "Windows.Win32.Networking.WinSock.Apis", wsaJoinLeafMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Networking.WinSock",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("import windows_core as windows_core"), true)
    @Expect(helper.contains("import windows_polyfill as windows_polyfill"), true)
    @Expect(helper.contains("import windows_common.Win32.Foundation.WAIT_EVENT"), true)
    @Expect(helper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    @Expect(helper.contains("public func connectChecked(s: UIntNative, name: CPointer<Unit>, namelen: Int32): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = connect(s, name, namelen)\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WSAEventSelectChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WSAEventSelect()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WSARecvChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WSARecv()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        if (error__ == 997) {\n            return windows_core.Result<Unit>.Ok(())\n        }\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WSARecvExChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = WSARecvEx()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetAddressByNameAChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = GetAddressByNameA()\n    if (result__ == -1) {\n        return windows_core.Result<Int32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetTypeByNameAChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = GetTypeByNameA()\n    if (result__ == -1) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func SetServiceAChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = SetServiceA()\n    if (result__ == -1) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WSCEnumNameSpaceProviders32Checked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = WSCEnumNameSpaceProviders32()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func inet_ptonChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = inet_pton()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func InetPtonWChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = InetPtonW()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func WSAStartupChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WSAStartup()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WSCWriteProviderOrderChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WSCWriteProviderOrder()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WSCInstallNameSpaceChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WSCInstallNameSpace()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func GetAddrInfoExAChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = GetAddrInfoExA()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func GetAddrInfoExWChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = GetAddrInfoExW()\n    if (result__ != 0 && result__ != 997) {\n        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetAddrInfoExCancelChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = GetAddrInfoExCancel()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func SetAddrInfoExAChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = SetAddrInfoExA()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func SetAddrInfoExWChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = SetAddrInfoExW()\n    if (result__ != 0) {\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func GetAddrInfoExOverlappedResultChecked(): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = GetAddrInfoExOverlappedResult()\n    if (result__ != 0 && result__ != 10036) {\n        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(result__)))\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func WSCEnumProtocolsChecked(lpErrno: CPointer<Int32>): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = WSCEnumProtocols(lpErrno)\n    if (result__ == -1) {\n        if (lpErrno.isNull()) {\n            return windows_core.Result<Int32>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n        }\n        let error__ = unsafe { lpErrno.read() }\n        return windows_core.Result<Int32>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func WSCDeinstallProviderChecked(lpErrno: CPointer<Int32>): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("let result__ = WSCDeinstallProvider(lpErrno)\n    if (result__ == -1) {\n        if (lpErrno.isNull()) {\n            return windows_core.Result<Unit>.Err(windows_core.errorFromHRESULT(windows_core.E_POINTER))\n        }\n        let error__ = unsafe { lpErrno.read() }\n        return windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<Unit>.Ok(())"), true)
    @Expect(helper.contains("public func WSAResetEventChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (WSAResetEvent()) {\n        return windows_core.Result<Unit>.Ok(())\n    }\n    let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n    let error__ = unsafe { errorProc__() }\n    windows_core.Result<Unit>.Err(windows_core.errorFromWin32(UInt32(error__)))"), true)
    @Expect(helper.contains("public func AcceptExChecked(): windows_core.Result<Bool>"), true)
    @Expect(helper.contains("let result__ = AcceptEx()\n    if (result__) {\n        return windows_core.Result<Bool>.Ok(true)\n    }\n    let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n    let error__ = unsafe { errorProc__() }\n    if (error__ == 997) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    windows_core.Result<Bool>.Err(windows_core.errorFromWin32(UInt32(error__)))"), true)
    @Expect(helper.contains("public func TransmitFileChecked(): windows_core.Result<Bool>"), true)
    @Expect(helper.contains("let result__ = TransmitFile()\n    if (result__) {\n        return windows_core.Result<Bool>.Ok(true)\n    }\n    let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n    let error__ = unsafe { errorProc__() }\n    if (error__ == 997) {\n        return windows_core.Result<Bool>.Ok(false)\n    }\n    windows_core.Result<Bool>.Err(windows_core.errorFromWin32(UInt32(error__)))"), true)
    @Expect(helper.contains("public func AcceptExChecked(): windows_core.Result<Unit>"), false)
    @Expect(helper.contains("public func TransmitFileChecked(): windows_core.Result<Unit>"), false)
    @Expect(helper.contains("public func WSAIsBlockingChecked"), false)
    @Expect(helper.contains("public func WSAWaitForMultipleEventsChecked(): windows_core.Result<WAIT_EVENT>"), true)
    @Expect(helper.contains("let result__ = WSAWaitForMultipleEvents()\n    if (result__ == 0xFFFFFFFFu32) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<WAIT_EVENT>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<WAIT_EVENT>.Ok(result__)"), true)
    @Expect(helper.contains("public func WSACreateEventChecked(): windows_core.Result<WSAEVENT>"), true)
    @Expect(helper.contains("let result__ = WSACreateEvent()\n    if (result__.Value.isNull()) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<WSAEVENT>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<WSAEVENT>.Ok(result__)"), true)
    @Expect(helper.contains("public func WSAAsyncGetHostByNameChecked(): windows_core.Result<HANDLE>"), true)
    @Expect(helper.contains("let result__ = WSAAsyncGetHostByName()\n    if (result__.Value.isNull()) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<HANDLE>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<HANDLE>.Ok(result__)"), true)
    @Expect(helper.contains("public func gethostbynameChecked(): windows_core.Result<CPointer<HOSTENT>>"), true)
    @Expect(helper.contains("let result__ = gethostbyname()\n    if (result__.isNull()) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<CPointer<HOSTENT>>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<CPointer<HOSTENT>>.Ok(result__)"), true)
    @Expect(helper.contains("public func socketChecked(): windows_core.Result<SOCKET>"), true)
    @Expect(helper.contains("let result__ = socket()\n    if (windows_polyfill.handlePointerIsMinusOne(result__.Value)) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<SOCKET>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<SOCKET>.Ok(result__)"), true)
    @Expect(helper.contains("public func WSAAcceptChecked(): windows_core.Result<SOCKET>"), true)
    @Expect(helper.contains("let result__ = WSAAccept()\n    if (windows_polyfill.handlePointerIsMinusOne(result__.Value)) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<SOCKET>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<SOCKET>.Ok(result__)"), true)
    @Expect(helper.contains("public func WSAJoinLeafChecked(): windows_core.Result<SOCKET>"), true)
    @Expect(helper.contains("let result__ = WSAJoinLeaf()\n    if (windows_polyfill.handlePointerIsMinusOne(result__.Value)) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))\n        let error__ = unsafe { errorProc__() }\n        return windows_core.Result<SOCKET>.Err(windows_core.errorFromWin32(UInt32(error__)))\n    }\n    windows_core.Result<SOCKET>.Ok(result__)"), true)
    @Expect(helper.contains("handlePointerFromInt(-1i64).toUIntNative()"), false)
    @Expect(helper.contains("let result__ = WSARecvEx()\n    if (result__ == -1) {\n        return windows_core.Result<Int32>.Err(windows_core.errorFromThread())"), false)
    @Expect(helper.contains("let result__ = GetAddressByNameA()\n    if (result__ == -1) {\n        let errorProc__ = CFunc<() -> Int32>(windows_libloading.resolveProc(\"WS2_32.dll\", \"WSAGetLastError\"))"), false)
}

@Test
func testCommonNativeHelperFilesRenderSetLastErrorTypedPointerNullWrapper() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let certContextFields = ArrayList<FieldRecord>()
    certContextFields.add(FieldRecord("dwCertEncodingType", primitiveSignature("UInt32"), attributes: publicFieldAttributes))
    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Security.Cryptography.CERT_CONTEXT",
        SymbolRecord(
            "Windows.Win32.Security.Cryptography.CERT_CONTEXT",
            "Windows.Win32.Security.Cryptography",
            "CERT_CONTEXT",
            "Windows_Win32_Security_Cryptography_CERT_CONTEXT",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Security.Cryptography",
                "CERT_CONTEXT",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: certContextFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let certParameters = ArrayList<SignatureRecord>()
    certParameters.add(primitiveSignature("UInt32"))
    certParameters.add(pointerSignature(primitiveSignature("Byte")))
    certParameters.add(primitiveSignature("UInt32"))
    let certMetadata = ArrayList<ParameterRecord>()
    certMetadata.add(ParameterRecord("dwCertEncodingType", sequenceNumber: 1))
    certMetadata.add(ParameterRecord("pbCertEncoded", sequenceNumber: 2))
    certMetadata.add(ParameterRecord("cbCertEncoded", sequenceNumber: 3))
    let certMethod = MethodRecord(
        "CertCreateCertificateContext",
        MethodSignatureRecord(
            pointerSignature(typeSignature("Windows.Win32.Security.Cryptography", "CERT_CONTEXT")),
            parameters: certParameters,
            requiredParameterCount: 3
        ),
        parameters: certMetadata,
        methodImport: Some(MethodImportRecord("CertCreateCertificateContext", "CRYPT32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.Security.Cryptography", "Windows.Win32.Security.Cryptography.Apis", certMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Security.Cryptography",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("public func CertCreateCertificateContextChecked("), true)
    @Expect(helper.contains("): windows_core.Result<CPointer<CERT_CONTEXT>>"), true)
    @Expect(helper.contains("let result__ = CertCreateCertificateContext(dwCertEncodingType, pbCertEncoded, cbCertEncoded)\n    if (result__.isNull()) {\n        return windows_core.Result<CPointer<CERT_CONTEXT>>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<CPointer<CERT_CONTEXT>>.Ok(result__)"), true)
    @Expect(helper.contains("windows_core.Result<CPointer<Unit>>.Err(windows_core.errorFromThread())"), false)
}

@Test
func testCommonNativeHelperFilesRenderSendMessageTimeoutCheckedWrapper() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let parameters = ArrayList<SignatureRecord>()
    parameters.add(typeSignature("Windows.Win32.Foundation", "HWND"))
    parameters.add(primitiveSignature("UInt32"))
    parameters.add(typeSignature("Windows.Win32.Foundation", "WPARAM"))
    parameters.add(typeSignature("Windows.Win32.Foundation", "LPARAM"))
    parameters.add(primitiveSignature("UInt32"))
    parameters.add(primitiveSignature("UInt32"))
    parameters.add(pointerSignature(primitiveSignature("UIntPtr")))
    let metadata = ArrayList<ParameterRecord>()
    metadata.add(ParameterRecord("hWnd", sequenceNumber: 1))
    metadata.add(ParameterRecord("Msg", sequenceNumber: 2))
    metadata.add(ParameterRecord("wParam", sequenceNumber: 3))
    metadata.add(ParameterRecord("lParam", sequenceNumber: 4))
    metadata.add(ParameterRecord("fuFlags", sequenceNumber: 5))
    metadata.add(ParameterRecord("uTimeout", sequenceNumber: 6))
    metadata.add(ParameterRecord("lpdwResult", sequenceNumber: 7))
    let method = MethodRecord(
        "SendMessageTimeoutW",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "LRESULT"),
            parameters: parameters,
            requiredParameterCount: 7
        ),
        parameters: metadata,
        methodImport: Some(MethodImportRecord("SendMessageTimeoutW", "USER32.dll", attributes: importAttributes))
    )
    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.UI.WindowsAndMessaging", "Windows.Win32.UI.WindowsAndMessaging.Apis", method))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.UI.WindowsAndMessaging",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("import windows_common.Win32.Foundation.GetLastError"), false)
    @Expect(helper.contains("import windows_common.Win32.Foundation.SetLastError"), false)
    @Expect(helper.contains("public func SendMessageTimeoutW(hWnd: CPointer<Unit>, Msg: UInt32, wParam: UIntNative, lParam: IntNative, fuFlags: UInt32, uTimeout: UInt32, lpdwResult: CPointer<UIntNative>): IntNative"), true)
    @Expect(helper.contains("public func SendMessageTimeoutWChecked(hWnd: CPointer<Unit>, Msg: UInt32, wParam: UIntNative, lParam: IntNative, fuFlags: UInt32, uTimeout: UInt32, lpdwResult: CPointer<UIntNative>): windows_core.Result<IntNative>"), true)
    @Expect(helper.contains("let setLastErrorProc__ = CFunc<(UInt32) -> Unit>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"SetLastError\"))\n    unsafe { setLastErrorProc__(0u32) }\n    let result__ = SendMessageTimeoutW(hWnd, Msg, wParam, lParam, fuFlags, uTimeout, lpdwResult)\n    if (result__ != 0) {\n        return windows_core.Result<IntNative>.Ok(result__)\n    }\n    let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n    let lastError__ = unsafe { getLastErrorProc__() }\n    if (lastError__ == 0u32) {\n        return windows_core.Result<IntNative>.Err(windows_core.errorFromHRESULT(windows_core.E_FAIL))\n    }\n    windows_core.Result<IntNative>.Err(windows_core.errorFromWin32(lastError__))"), true)
}

@Test
func testCommonNativeHelperFilesRenderFileSystemUInt32SentinelWrappers() {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let fileAttributesParameters = ArrayList<SignatureRecord>()
    fileAttributesParameters.add(typeSignature("Windows.Win32.Foundation", "PWSTR"))
    let fileAttributesMetadata = ArrayList<ParameterRecord>()
    fileAttributesMetadata.add(ParameterRecord("lpFileName", sequenceNumber: 1))
    let fileAttributesMethod = MethodRecord(
        "GetFileAttributesW",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: fileAttributesParameters,
            requiredParameterCount: 1
        ),
        parameters: fileAttributesMetadata,
        methodImport: Some(MethodImportRecord("GetFileAttributesW", "KERNEL32.dll", attributes: importAttributes))
    )

    let versionSizeParameters = ArrayList<SignatureRecord>()
    versionSizeParameters.add(typeSignature("Windows.Win32.Foundation", "PWSTR"))
    versionSizeParameters.add(pointerSignature(primitiveSignature("UInt32")))
    let versionSizeMetadata = ArrayList<ParameterRecord>()
    versionSizeMetadata.add(ParameterRecord("lptstrFilename", sequenceNumber: 1))
    versionSizeMetadata.add(ParameterRecord("lpdwHandle", sequenceNumber: 2))
    let versionSizeMethod = MethodRecord(
        "GetFileVersionInfoSizeW",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: versionSizeParameters,
            requiredParameterCount: 2
        ),
        parameters: versionSizeMetadata,
        methodImport: Some(MethodImportRecord("GetFileVersionInfoSizeW", "VERSION.dll", attributes: importAttributes))
    )

    let queryDosDeviceParameters = ArrayList<SignatureRecord>()
    queryDosDeviceParameters.add(typeSignature("Windows.Win32.Foundation", "PWSTR"))
    queryDosDeviceParameters.add(typeSignature("Windows.Win32.Foundation", "PWSTR"))
    queryDosDeviceParameters.add(primitiveSignature("UInt32"))
    let queryDosDeviceMetadata = ArrayList<ParameterRecord>()
    queryDosDeviceMetadata.add(ParameterRecord("lpDeviceName", sequenceNumber: 1))
    queryDosDeviceMetadata.add(ParameterRecord("lpTargetPath", sequenceNumber: 2))
    queryDosDeviceMetadata.add(ParameterRecord("ucchMax", sequenceNumber: 3))
    let queryDosDeviceMethod = MethodRecord(
        "QueryDosDeviceW",
        MethodSignatureRecord(
            primitiveSignature("UInt32"),
            parameters: queryDosDeviceParameters,
            requiredParameterCount: 3
        ),
        parameters: queryDosDeviceMetadata,
        methodImport: Some(MethodImportRecord("QueryDosDeviceW", "KERNEL32.dll", attributes: importAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.Storage.FileSystem", "Windows.Win32.Storage.FileSystem.Apis", fileAttributesMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Storage.FileSystem", "Windows.Win32.Storage.FileSystem.Apis", versionSizeMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Storage.FileSystem", "Windows.Win32.Storage.FileSystem.Apis", queryDosDeviceMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Storage.FileSystem",
        specs,
        HashMap<String, SymbolRecord>()
    )

    @Expect(helper.contains("import windows_strings as windows_strings"), true)
    @Expect(helper.contains("public func GetFileAttributesWChecked(lpFileName: windows_strings.PWSTR): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = GetFileAttributesW(lpFileName)\n    if (result__ == 0xFFFFFFFFu32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func GetFileVersionInfoSizeWChecked(lptstrFilename: windows_strings.PWSTR, lpdwHandle: CPointer<UInt32>): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = GetFileVersionInfoSizeW(lptstrFilename, lpdwHandle)\n    if (result__ == 0u32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
    @Expect(helper.contains("public func QueryDosDeviceWChecked(lpDeviceName: windows_strings.PWSTR, lpTargetPath: windows_strings.PWSTR, ucchMax: UInt32): windows_core.Result<UInt32>"), true)
    @Expect(helper.contains("let result__ = QueryDosDeviceW(lpDeviceName, lpTargetPath, ucchMax)\n    if (result__ == 0u32) {\n        return windows_core.Result<UInt32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<UInt32>.Ok(result__)"), true)
}

@Test
func testCommonNativeHelperFilesSkipCheckedWrapperForSetLastErrorBoolPredicates() {
    let publicFieldAttributes = ArrayList<String>()
    publicFieldAttributes.add("Public")
    let valueTypeAttributes = ArrayList<String>()
    valueTypeAttributes.add("Public")
    valueTypeAttributes.add("SequentialLayout")
    valueTypeAttributes.add("Sealed")

    let handleFields = ArrayList<FieldRecord>()
    handleFields.add(FieldRecord("Value", pointerSignature(voidSignature()), attributes: publicFieldAttributes))
    let boolFields = ArrayList<FieldRecord>()
    boolFields.add(FieldRecord("Value", primitiveSignature("Int32"), attributes: publicFieldAttributes))

    let symbolsByName = HashMap<String, SymbolRecord>()
    symbolsByName.add(
        "Windows.Win32.Foundation.HANDLE",
        SymbolRecord(
            "Windows.Win32.Foundation.HANDLE",
            "Windows.Win32.Foundation",
            "HANDLE",
            "Windows_Win32_Foundation_HANDLE",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "HANDLE",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: handleFields
            ))
        )
    )
    symbolsByName.add(
        "Windows.Win32.Foundation.BOOL",
        SymbolRecord(
            "Windows.Win32.Foundation.BOOL",
            "Windows.Win32.Foundation",
            "BOOL",
            "Windows_Win32_Foundation_BOOL",
            [],
            typeDef: Some(TypeDefinitionRecord(
                "Windows.Win32.Foundation",
                "BOOL",
                baseType: "System.ValueType",
                hasBaseType: true,
                attributes: valueTypeAttributes,
                fields: boolFields
            ))
        )
    )

    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    importAttributes.add("SetLastError")
    importAttributes.add("CallingConventionWinApi")

    let parameterTypes = ArrayList<SignatureRecord>()
    parameterTypes.add(typeSignature("Windows.Win32.Foundation", "HANDLE"))
    let parameters = ArrayList<ParameterRecord>()
    parameters.add(ParameterRecord("TokenHandle", sequenceNumber: 1))
    let method = MethodRecord(
        "IsTokenRestricted",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: parameterTypes,
            requiredParameterCount: 1
        ),
        parameters: parameters,
        methodImport: Some(MethodImportRecord("IsTokenRestricted", "ADVAPI32.dll", attributes: importAttributes))
    )
    let canMethod = MethodRecord(
        "CanAccessToken",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: parameterTypes,
            requiredParameterCount: 1
        ),
        parameters: parameters,
        methodImport: Some(MethodImportRecord("CanAccessToken", "ADVAPI32.dll", attributes: importAttributes))
    )
    let outAttributes = ArrayList<String>()
    outAttributes.add("Out")
    let multipleSuccessAttributes = ArrayList<CustomAttributeRecord>()
    multipleSuccessAttributes.add(CustomAttributeRecord("Windows.Win32.Foundation.Metadata.CanReturnMultipleSuccessValuesAttribute"))
    let messageParameterTypes = ArrayList<SignatureRecord>()
    messageParameterTypes.add(pointerSignature(voidSignature()))
    let messageParameters = ArrayList<ParameterRecord>()
    messageParameters.add(ParameterRecord("lpMsg", sequenceNumber: 1, attributes: outAttributes))
    let messageMethod = MethodRecord(
        "GetMessageW",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: messageParameterTypes,
            requiredParameterCount: 1
        ),
        parameters: messageParameters,
        customAttributes: multipleSuccessAttributes,
        methodImport: Some(MethodImportRecord("GetMessageW", "USER32.dll", attributes: importAttributes))
    )
    let trackPopupMethod = MethodRecord(
        "TrackPopupMenu",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        parameters: ArrayList<ParameterRecord>(),
        customAttributes: multipleSuccessAttributes,
        methodImport: Some(MethodImportRecord("TrackPopupMenu", "USER32.dll", attributes: importAttributes))
    )
    let trackPopupExMethod = MethodRecord(
        "TrackPopupMenuEx",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        parameters: ArrayList<ParameterRecord>(),
        customAttributes: multipleSuccessAttributes,
        methodImport: Some(MethodImportRecord("TrackPopupMenuEx", "USER32.dll", attributes: importAttributes))
    )
    let cancelMethod = MethodRecord(
        "CancelWaitableTimer",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: parameterTypes,
            requiredParameterCount: 1
        ),
        parameters: parameters,
        methodImport: Some(MethodImportRecord("CancelWaitableTimer", "KERNEL32.dll", attributes: importAttributes))
    )
    let plainImportAttributes = ArrayList<String>()
    plainImportAttributes.add("ExactSpelling")
    plainImportAttributes.add("CallingConventionWinApi")
    let attachParameterTypes = ArrayList<SignatureRecord>()
    attachParameterTypes.add(primitiveSignature("UInt32"))
    attachParameterTypes.add(primitiveSignature("UInt32"))
    attachParameterTypes.add(typeSignature("Windows.Win32.Foundation", "BOOL"))
    let attachParameters = ArrayList<ParameterRecord>()
    attachParameters.add(ParameterRecord("idAttach", sequenceNumber: 1))
    attachParameters.add(ParameterRecord("idAttachTo", sequenceNumber: 2))
    attachParameters.add(ParameterRecord("fAttach", sequenceNumber: 3))
    let attachMethod = MethodRecord(
        "AttachThreadInput",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: attachParameterTypes,
            requiredParameterCount: 3
        ),
        parameters: attachParameters,
        customAttributes: multipleSuccessAttributes,
        methodImport: Some(MethodImportRecord("AttachThreadInput", "USER32.dll", attributes: plainImportAttributes))
    )
    let getCachedSigningLevelMethod = MethodRecord(
        "GetCachedSigningLevel",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("GetCachedSigningLevel", "KERNEL32.dll", attributes: plainImportAttributes))
    )
    let setCachedSigningLevelMethod = MethodRecord(
        "SetCachedSigningLevel",
        MethodSignatureRecord(
            typeSignature("Windows.Win32.Foundation", "BOOL"),
            parameters: ArrayList<SignatureRecord>(),
            requiredParameterCount: 0
        ),
        methodImport: Some(MethodImportRecord("SetCachedSigningLevel", "KERNEL32.dll", attributes: plainImportAttributes))
    )

    let specs = ArrayList<NativeFunctionSpec>()
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", method))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", canMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", messageMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", trackPopupMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", trackPopupExMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", cancelMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", attachMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", getCachedSigningLevelMethod))
    specs.add(NativeFunctionSpec("Windows.Win32.Security", "Windows.Win32.Security.Apis", setCachedSigningLevelMethod))
    let helper = renderNativeHelperNamespaceSource(
        "windows_common",
        "Windows.Win32.Security",
        specs,
        symbolsByName
    )

    @Expect(helper.contains("public func IsTokenRestricted(TokenHandle: HANDLE): Bool"), true)
    @Expect(helper.contains("public func IsTokenRestrictedChecked"), false)
    @Expect(helper.contains("public func CanAccessToken(TokenHandle: HANDLE): Bool"), true)
    @Expect(helper.contains("public func CanAccessTokenChecked"), false)
    @Expect(helper.contains("public func GetMessageW(lpMsg: CPointer<Unit>): Int32"), true)
    @Expect(helper.contains("public func GetMessageWChecked(lpMsg: CPointer<Unit>): windows_core.Result<Int32>"), true)
    @Expect(helper.contains("let result__ = GetMessageW(lpMsg)\n    if (result__ == -1) {\n        return windows_core.Result<Int32>.Err(windows_core.errorFromThread())\n    }\n    windows_core.Result<Int32>.Ok(result__)"), true)
    @Expect(helper.contains("public func TrackPopupMenu(): Int32"), true)
    @Expect(helper.contains("public func TrackPopupMenuChecked"), false)
    @Expect(helper.contains("public func TrackPopupMenuEx(): Int32"), true)
    @Expect(helper.contains("public func TrackPopupMenuExChecked"), false)
    @Expect(helper.contains("public func CancelWaitableTimerChecked(TokenHandle: HANDLE): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (CancelWaitableTimer(TokenHandle))"), true)
    @Expect(helper.contains("public func AttachThreadInputChecked(idAttach: UInt32, idAttachTo: UInt32, fAttach: Bool): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (AttachThreadInput(idAttach, idAttachTo, fAttach))"), true)
    @Expect(helper.contains("public func GetCachedSigningLevelChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (GetCachedSigningLevel())"), true)
    @Expect(helper.contains("public func SetCachedSigningLevelChecked(): windows_core.Result<Unit>"), true)
    @Expect(helper.contains("if (SetCachedSigningLevel())"), true)
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
    @Expect(win32Content.contains("public func UseWin32HResultChecked(hr: Int32): windows_core.Result<Unit>"), true)
    @Expect(win32Content.contains("windows_core.HRESULT(UseWin32HResult(hr)).ok()"), true)
    @Expect(foundationContent.contains("public func UseFoundationHResultChecked(hr: Int32): windows_core.Result<Unit>"), true)
    @Expect(foundationContent.contains("windows_core.HRESULT(UseFoundationHResult(hr)).ok()"), true)
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
            {"Name": "M12", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "M21", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "M22", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "M31", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null},
            {"Name": "M32", "Signature": {"Kind": "Primitive", "Name": "Float32"}, "Attributes": ["Public"], "CustomAttributes": [], "DefaultValue": null}
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
        "Windows.Win32.Graphics.Direct2D.Common",
        "Windows.Win32.Graphics.Direct2D.Common.Apis",
        nativeMethod(
            "UseVector4",
            "UseVector4",
            "example.dll",
            typeSignature("Windows.Win32.Graphics.Direct2D.Common", "D2D_VECTOR_4F"),
            [NativeParameterSeed("matrix", typeSignature("Windows.Win32.Graphics.Direct2D.Common", "D2D_MATRIX_3X2_F"))]
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
    @Expect(direct2d.contains("import windows_common.Foundation.Numerics.Matrix3x2"), true)
    @Expect(direct2d.contains("import windows_common.Foundation.Numerics.Vector4"), true)
    @Expect(direct2d.contains("public func UsePoint(point: Vector2): Vector2"), true)
    @Expect(direct2d.contains("public func UseVector4(matrix: Matrix3x2): Vector4"), true)
    @Expect(direct2d.contains("let proc = CFunc<(Vector2) -> Vector2>"), true)
    @Expect(direct2d.contains("let proc = CFunc<(Matrix3x2) -> Vector4>"), true)
    @Expect(direct2d.contains("return unsafe { proc(point) }"), true)
    @Expect(direct2d.contains("return unsafe { proc(matrix) }"), true)
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

    let writer = GeneratedPackageWriter("__windows_cj_dry_run__", true)
    writeImplFiles(writer, selected, "windows_common", selectedByName)
    writeFacadeFiles(writer, "Windows.Foundation.Numerics", selected, "windows_common")
    let numericsImpl = writer.writtenFileContent.get("src/impl/symbols_0.cj").getOrThrow()
    let numericsFacade = writer.writtenFileContent.get("src/Foundation/Numerics/facade_0.cj").getOrThrow()
    @Expect(numericsFacade.contains("import windows_common.impl.{Windows_Foundation_Numerics_Matrix3x2"), true)
    @Expect(numericsFacade.contains("Windows_Foundation_Numerics_Vector4}"), true)
    @Expect(numericsFacade.contains("public type Matrix3x2 = Windows_Foundation_Numerics_Matrix3x2"), true)
    @Expect(numericsFacade.contains("public type Vector4 = Windows_Foundation_Numerics_Vector4"), true)
    @Expect(numericsImpl.contains("public struct Windows_Foundation_Numerics_Matrix3x2"), true)
    @Expect(numericsImpl.contains("public var M32: Float32 = 0.0"), true)
    @Expect(numericsImpl.contains("public struct Windows_Foundation_Numerics_Vector4"), true)
    @Expect(numericsImpl.contains("public var W: Float32 = 0.0"), true)

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
