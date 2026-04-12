package windows_bindgen

import std.collection.*
import std.fs.*

public func readFileLines(path: String): ArrayList<String> {
    let content = String.fromUtf8(File.readFrom(path))
    let result = ArrayList<String>()
    let bytes = content.toArray()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'\n') {
            let end = if (i > start && bytes[i - 1] == b'\r') { i - 1 } else { i }
            result.add(String.fromUtf8(bytes[start..end]))
            start = i + 1
        }
        i += 1
    }
    if (start <= Int64(bytes.size)) {
        result.add(String.fromUtf8(bytes[start..Int64(bytes.size)]))
    }
    return result
}

public func writeTextFile(outputDir: String, relativePath: String, content: String): Unit {
    FileWriter(outputDir).writeFile(relativePath, content)
}

public func jsonEscape(value: String): String {
    let bytes = value.toArray()
    let result = ArrayList<Byte>()
    for (byte in bytes) {
        if (byte == b'\\') {
            result.add(b'\\')
            result.add(b'\\')
        } else if (byte == b'"') {
            result.add(b'\\')
            result.add(b'"')
        } else if (byte == b'\n') {
            result.add(b'\\')
            result.add(b'n')
        } else if (byte == b'\r') {
            result.add(b'\\')
            result.add(b'r')
        } else if (byte == b'\t') {
            result.add(b'\\')
            result.add(b't')
        } else {
            result.add(byte)
        }
    }
    let escaped = Array<Byte>(result.size, { i => result[i] })
    return String.fromUtf8(escaped)
}
