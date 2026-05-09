package windows

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

func jsonTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

func minimalWinmdJson(types: String): String {
    return "{" +
        "\"winmd_file\":\"Windows.winmd\"," +
        "\"winmd_sha256\":\"abc123\"," +
        "\"tool_version\":\"test-tool\"," +
        "\"schema_version\":\"1\"," +
        "\"source_set\":\"sdk\"," +
        "\"types\":" + types +
        "}"
}

@Test
func testDecodeWinmdFileAppliesTypeDefaults() {
    let record = decodeWinmdFileJson(minimalWinmdJson("[{\"Namespace\":\"Example.Core\",\"Name\":\"Widget\"}]"))

    @Expect(record.winmdFile, "Windows.winmd")
    @Expect(record.winmdSha256, "abc123")
    @Expect(record.toolVersion, "test-tool")
    @Expect(record.schemaVersion, "1")
    @Expect(record.sourceSet, "sdk")
    @Expect(record.types.size, 1)
    @Expect(record.types[0].namespace, "Example.Core")
    @Expect(record.types[0].name, "Widget")
    @Expect(record.types[0].fullName(), "Example.Core.Widget")
    @Expect(record.types[0].metadataToken, "")
    @Expect(record.types[0].isNested, false)
    @Expect(record.types[0].attributes.size, 0)
    @Expect(record.types[0].sourceSet, "winmd_main")
}

@Test
func testDecodeWinmdFileAcceptsAliasesAndModuleShapes() {
    let json = minimalWinmdJson("[" +
        "{" +
        "\"Namespace\":\"Example.Core\"," +
        "\"Name\":\"Widget\"," +
        "\"Methods\":[" +
        "{" +
        "\"Name\":\"Create\"," +
        "\"Signature\":{\"ReturnType\":{\"Kind\":\"Void\"},\"ParameterTypes\":[{\"Kind\":\"I32\"}],\"RequiredParameterCount\":1}," +
        "\"Import\":{\"Name\":\"CreateWidget\",\"Module\":{\"Name\":\"widget.dll\"},\"Attributes\":[\"PreserveSig\"]}" +
        "}," +
        "{" +
        "\"Name\":\"Destroy\"," +
        "\"Signature\":{\"ReturnType\":{\"Kind\":\"Void\"},\"Parameters\":[{\"Kind\":\"Handle\"}]}," +
        "\"MethodImport\":{\"Name\":\"DestroyWidget\",\"Module\":\"widget.dll\"}" +
        "}" +
        "]" +
        "}" +
        "]")

    let record = decodeWinmdFileJson(json)
    let methods = record.types[0].methods

    @Expect(methods.size, 2)
    @Expect(methods[0].signature.parameters.size, 1)
    @Expect(methods[0].signature.parameters[0].kind, "I32")
    @Expect(methods[0].signature.requiredParameterCount, 1)
    @Expect(methods[1].signature.parameters[0].kind, "Handle")
    match (methods[0].methodImport) {
        case Some(import_) =>
            @Expect(import_.name, "CreateWidget")
            @Expect(import_.moduleName, "widget.dll")
            @Expect(import_.moduleReference.isSome(), true)
            @Expect(import_.attributes[0], "PreserveSig")
        case None => @Expect(true, false)
    }
    match (methods[1].methodImport) {
        case Some(import_) =>
            @Expect(import_.name, "DestroyWidget")
            @Expect(import_.moduleName, "widget.dll")
            @Expect(import_.moduleReference.isNone(), true)
        case None => @Expect(true, false)
    }
}

@Test
func testDecodeWinmdFileRejectsMissingRequiredAndUnknownFields() {
    @Expect(jsonTestThrows({ => let _ = decodeWinmdFileJson(minimalWinmdJson("[{\"Name\":\"Widget\"}]")) }), true)
    @Expect(jsonTestThrows({ => let _ = decodeWinmdFileJson(minimalWinmdJson("[{\"Namespace\":\"Example\",\"Name\":\"Widget\",\"Extra\":1}]")) }), true)
}

@Test
func testLoadWinmdJsonFilesReturnsRecordPerPath() {
    let dir = ".generated/json-loader-test"
    removeIfExists(dir, recursive: true)
    Directory.create(dir, recursive: true)
    let firstPath = "${dir}/first.json"
    let secondPath = "${dir}/second.json"
    File.writeTo(firstPath, minimalWinmdJson("[{\"Namespace\":\"Example.One\",\"Name\":\"First\"}]").toArray())
    File.writeTo(secondPath, minimalWinmdJson("[{\"Namespace\":\"Example.Two\",\"Name\":\"Second\"}]").toArray())

    let records = loadWinmdJsonFiles([firstPath, secondPath, firstPath])

    @Expect(records.size, 3)
    @Expect(records[0].types[0].fullName(), "Example.One.First")
    @Expect(records[1].types[0].fullName(), "Example.Two.Second")
    @Expect(records[2].types[0].fullName(), "Example.One.First")
    removeIfExists(dir, recursive: true)
}
