package windows_bindgen

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

func cliTestExceptionMessage(action: () -> Unit): String {
    try {
        action()
    } catch (err: Exception) {
        return "${err}"
    }
    return ""
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

func cliTestPInvokeApiSymbol(conventionAttribute: String): SymbolRecord {
    let importAttributes = ArrayList<String>()
    importAttributes.add("ExactSpelling")
    if (!conventionAttribute.isEmpty()) {
        importAttributes.add(conventionAttribute)
    }
    let methods = ArrayList<MethodRecord>()
    methods.add(MethodRecord(
        "CallNative",
        MethodSignatureRecord(SignatureRecord("Primitive", name: "Int32")),
        methodImport: Some(MethodImportRecord("CallNative", "native.dll", attributes: importAttributes))
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
    return SymbolRecord(
        "Example.Native.Apis",
        "Example.Native",
        "Apis",
        "Example_Native_Apis",
        [],
        typeDef: Some(typeDef)
    )
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

func cliTestExpectWin32ScalarRawAbi(fullName: String, expected: String) {
    match (win32ScalarRawAbiTypeByFullName(fullName)) {
        case Some(actual) => @Expect(actual, expected)
        case None => @Expect("<none>", expected)
    }
}
