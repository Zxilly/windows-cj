package windows

import std.collection.*
import std.fs.*

public func collectCommonFeatureNames(supportPackageDirs: ArrayList<String>): Array<String> {
    let namespaces = ArrayList<String>()
    for (supportDir in supportPackageDirs) {
        scanCjSources(supportSourceDir(supportDir), namespaces)
    }
    sortStrings(namespaces)
    let result = Array<String>(namespaces.size, repeat: "")
    var i: Int64 = 0
    while (i < Int64(namespaces.size)) {
        result[i] = namespaces[i]
        i += 1
    }
    return result
}

func supportSourceDir(supportDir: String): String {
    let direct = "${supportDir}/src"
    if (directoryExists(direct)) {
        return direct
    }
    return "../${supportDir}/src"
}

func scanCjSources(dir: String, namespaces: ArrayList<String>): Unit {
    try {
        let entries = Directory.readFrom(dir)
        for (entry in entries) {
            let child = "${dir}/${entry.name}"
            if (endsWith(child, ".cj")) {
                collectFeatureNamesFromSource(child, namespaces)
            } else {
                scanCjSources(child, namespaces)
            }
        }
    } catch (_: Exception) {
        return
    }
}

func collectFeatureNamesFromSource(path: String, namespaces: ArrayList<String>): Unit {
    let text = String.fromUtf8(File.readFrom(path))
    let lines = splitString(text, b'\n')
    for (line in lines) {
        match (featureNameFromImportLine(line)) {
            case Some(feature) => addUnique(namespaces, feature)
            case None => ()
        }
    }
}

func featureNameFromImportLine(line: String): Option<String> {
    var text = trimAscii(line)
    if (startsWith(text, "public ")) {
        text = stripPrefix(text, "public ")
        text = trimAscii(text)
    }
    if (startsWith(text, "import windows_common.")) {
        return featureNameFromWindowsImport(readImportNamespace(stripPrefix(text, "import windows_common.")))
    }
    if (startsWith(text, "import windows_gen.")) {
        return featureNameFromWindowsImport(readImportNamespace(stripPrefix(text, "import windows_gen.")))
    }
    if (startsWith(text, "import windows.")) {
        return featureNameFromWindowsImport(readImportNamespace(stripPrefix(text, "import windows.")))
    }
    return None
}

func featureNameFromWindowsImport(namespace: String): Option<String> {
    let normalized = trimTrailingDot(namespace)
    if (normalized.isEmpty()) {
        return None
    }
    let parts = splitString(normalized, b'.')
    for (part in parts) {
        if (part == "impl") {
            return None
        }
    }
    if (!parts.isEmpty() && parts[0] == "Microsoft") {
        return Some(normalized)
    }
    return Some("Windows.${normalized}")
}

func readImportNamespace(text: String): String {
    let bytes = text.toArray()
    var end: Int64 = 0
    while (end < Int64(bytes.size)) {
        let byte = bytes[end]
        if (byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'{' || byte == b';') {
            break
        }
        end += 1
    }
    return String.fromUtf8(bytes[0..end])
}

func stripPrefix(value: String, prefix: String): String {
    let bytes = value.toArray()
    let prefixBytes = prefix.toArray()
    if (!startsWith(value, prefix)) {
        return value
    }
    return String.fromUtf8(bytes[Int64(prefixBytes.size)..Int64(bytes.size)])
}

func trimAscii(value: String): String {
    let bytes = value.toArray()
    var start: Int64 = 0
    var end = Int64(bytes.size)
    while (start < end && isAsciiWhitespace(bytes[start])) {
        start += 1
    }
    while (end > start && isAsciiWhitespace(bytes[end - 1])) {
        end -= 1
    }
    return String.fromUtf8(bytes[start..end])
}

func trimTrailingDot(value: String): String {
    let bytes = value.toArray()
    var end = Int64(bytes.size)
    while (end > 0 && bytes[end - 1] == b'.') {
        end -= 1
    }
    return String.fromUtf8(bytes[0..end])
}

func isAsciiWhitespace(byte: Byte): Bool {
    return byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
}

func endsWith(value: String, suffix: String): Bool {
    let valueBytes = value.toArray()
    let suffixBytes = suffix.toArray()
    if (suffixBytes.size > valueBytes.size) {
        return false
    }
    var i: Int64 = 0
    let offset = Int64(valueBytes.size) - Int64(suffixBytes.size)
    while (i < Int64(suffixBytes.size)) {
        if (valueBytes[offset + i] != suffixBytes[i]) {
            return false
        }
        i += 1
    }
    return true
}
