package windows_bindgen

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.fs.*
import stdx.encoding.json.*

// Path to the small real winmd used for golden comparison.
let WDK_WINMD_PATH = "E:/Project/CS_Project/2026/ling/ref/windows-rs/crates/libs/bindgen/default/Windows.Wdk.winmd"

// WinRT metadata, used to exercise the CMOD IsConst / `const T&` reconstruction
// (RefConst -> Modified) that only appears in WinRT signatures.
let WINRT_WINMD_PATH = "E:/Project/CS_Project/2026/ling/ref/windows-rs/crates/libs/bindgen/default/Windows.winmd"

func wdkWinmdAvailable(): Bool {
    try {
        File.readFrom(WDK_WINMD_PATH)
        return true
    } catch (_: Exception) {
        return false
    }
}

func winrtWinmdAvailable(): Bool {
    try {
        File.readFrom(WINRT_WINMD_PATH)
        return true
    } catch (_: Exception) {
        return false
    }
}

// A `const Guid&` parameter (CMOD_OPT IsConst over a BYREF System.Guid) must be
// reconstructed by the native adapter as the same Modified wrapper the reference
// C# converter emits, so the rendered vtable slot stays a by-reference pointer
// rather than collapsing to a wrong by-value GUID. IGuidHelperStatics.Equals is
// the canonical case (target/value are both `const Guid&`).
@Test
func testRefConstReconstructsModifiedWrapper() {
    if (!winrtWinmdAvailable()) {
        return
    }
    let records = loadWinmdFilesNative([WINRT_WINMD_PATH])
    @Expect(Int64(records.size), 1)
    var found = false
    for (typeDef in records[0].types) {
        if (typeDef.fullName() != "Windows.Foundation.IGuidHelperStatics") {
            continue
        }
        for (method in typeDef.methods) {
            if (method.name != "Equals") {
                continue
            }
            found = true
            // Equals(const Guid& target, const Guid& value) -> two Modified params.
            @Expect(Int64(method.signature.parameters.size), 2)
            for (param in method.signature.parameters) {
                @Expect(param.kind, "Modified")
                // Modifier is System.Runtime.CompilerServices.IsConst.
                @Expect(param.modifierType.isSome(), true)
                let modifier = param.modifierType.getOrThrow()
                @Expect(modifier.kind, "Type")
                @Expect(modifier.namespace, "System.Runtime.CompilerServices")
                @Expect(modifier.name, "IsConst")
                // Unmodified type is a Reference to System.Guid (by-ref pointer).
                @Expect(param.unmodifiedType.isSome(), true)
                let unmodified = param.unmodifiedType.getOrThrow()
                @Expect(unmodified.kind, "Reference")
                @Expect(unmodified.typeSig.isSome(), true)
                let inner = unmodified.typeSig.getOrThrow()
                @Expect(inner.namespace, "System")
                @Expect(inner.name, "Guid")
            }
        }
    }
    @Expect(found, true)
}

@Test
func testEmitterRoundTripsThroughLoader() {
    // A hand-built record must serialize to JSON that the strict json_loader can
    // parse back without errors and yield an equivalent record.
    let returnType = SignatureRecord("Primitive", name: "Int32")
    let paramType = SignatureRecord(
        "Pointer",
        typeSig: Some(SignatureRecord("Type", name: "HANDLE", namespace: "Windows.Win32.Foundation", hasNamespace: true, comment: "TypeReference"))
    )
    let methodSig = MethodSignatureRecord(
        returnType,
        parameters: ArrayList<SignatureRecord>([paramType]),
        requiredParameterCount: 1,
        genericParameterCount: 0,
        header: buildSignatureHeaderForTest()
    )
    let method = MethodRecord(
        "DoThing",
        methodSig,
        attributes: ArrayList<String>(["Public", "Static"]),
        relativeVirtualAddress: 0
    )
    let field = FieldRecord(
        "Length",
        SignatureRecord("Primitive", name: "UInt32"),
        attributes: ArrayList<String>(["Public"]),
        offset: -1
    )
    let td = TypeDefinitionRecord(
        "Windows.Wdk.Foundation",
        "Sample",
        baseType: "System.ValueType",
        hasBaseType: true,
        attributes: ArrayList<String>(["Public", "SequentialLayout", "Class"]),
        fields: ArrayList<FieldRecord>([field]),
        layout: Some(TypeLayoutRecord(true, 0, 0)),
        methods: ArrayList<MethodRecord>([method]),
        supportedArchitectures: ArrayList<String>(["X86", "X64", "Arm64"])
    )
    let record = WinmdFileRecord(
        "Sample.winmd",
        "abc123",
        "1.0.0",
        "1",
        "winmd_main",
        ArrayList<TypeDefinitionRecord>([td])
    )

    let json = emitWinmdJson(record)
    let parsed = decodeWinmdFileJson(json)

    @Expect(parsed.winmdFile, "Sample.winmd")
    @Expect(parsed.winmdSha256, "abc123")
    @Expect(Int64(parsed.types.size), 1)
    let pt = parsed.types[0]
    @Expect(pt.fullName(), "Windows.Wdk.Foundation.Sample")
    @Expect(pt.baseType, "System.ValueType")
    @Expect(pt.hasBaseType, true)
    @Expect(Int64(pt.fields.size), 1)
    @Expect(pt.fields[0].offset, -1)
    @Expect(Int64(pt.methods.size), 1)
    @Expect(pt.methods[0].name, "DoThing")
    @Expect(Int64(pt.methods[0].signature.parameters.size), 1)
    @Expect(pt.methods[0].signature.parameters[0].kind, "Pointer")
}

func buildSignatureHeaderForTest(): HashMap<String, JsonValue> {
    let header = HashMap<String, JsonValue>()
    let attrs = ArrayList<JsonValue>([JsonString("None")])
    header.add("Attributes", JsonArray(attrs))
    header.add("CallingConvention", JsonString("Default"))
    header.add("HasExplicitThis", JsonBool(false))
    header.add("IsGeneric", JsonBool(false))
    header.add("IsInstance", JsonBool(false))
    header.add("Kind", JsonString("Method"))
    return header
}

@Test
func testStringEscaping() {
    let record = WinmdFileRecord(
        "x.winmd", "h", "1.0.0", "1", "winmd_main",
        ArrayList<TypeDefinitionRecord>([
            TypeDefinitionRecord(
                "",
                "<Module>",
                layout: Some(TypeLayoutRecord(true, 0, 0)),
                supportedArchitectures: ArrayList<String>(["X86", "X64", "Arm64"])
            )
        ])
    )
    let json = emitWinmdJson(record)
    // The < and > must be escaped exactly as the C# writer does.
    @Expect(json.contains("\\u003CModule\\u003E"), true)
    // BaseType must be present as explicit null on the type definition.
    @Expect(json.contains("\"BaseType\": null"), true)
    // It must still parse cleanly.
    let parsed = decodeWinmdFileJson(json)
    @Expect(parsed.types[0].name, "<Module>")
}

@Test
func testLoadWdkWinmdNative() {
    if (!wdkWinmdAvailable()) {
        return
    }
    let records = loadWinmdFilesNative([WDK_WINMD_PATH])
    @Expect(Int64(records.size), 1)
    let record = records[0]
    @Expect(record.winmdFile, "Windows.Wdk.winmd")
    @Expect(record.toolVersion, "1.0.0")
    @Expect(record.schemaVersion, "1")
    @Expect(record.sourceSet, "winmd_main")
    // The first type is always <Module>.
    @Expect(record.types[0].name, "<Module>")
    // There should be thousands of types (matches the golden's 4103).
    @Expect(Int64(record.types.size) > 4000, true)

    // The emitted JSON must round-trip through the strict loader without error.
    let json = emitWinmdJson(record)
    let parsed = decodeWinmdFileJson(json)
    @Expect(Int64(parsed.types.size), Int64(record.types.size))
}

@Test
func testWdkSha256Matches() {
    if (!wdkWinmdAvailable()) {
        return
    }
    let records = loadWinmdFilesNative([WDK_WINMD_PATH])
    // Golden SHA-256 from .generated/winmd-json-all/Windows.Wdk.json.
    @Expect(records[0].winmdSha256, "54b8e48866b0a7e066981b63bb6f82fc6947fe8c57e2b5cb4513b1537aa836c2")
}
