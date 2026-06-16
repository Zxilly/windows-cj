package windows_bindgen

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

func collectSupportLinkOptions(supportDeps: ArrayList<String>): ArrayList<String> {
    let options = ArrayList<String>()
    for (dependency in stableSupportDependencyNames()) {
        if (contains(supportDeps, dependency)) {
            for (option in stableSupportDependencyLinkOptions(dependency)) {
                addUnique(options, option)
            }
        }
    }
    return options
}

func stableSupportDependencyLinkOptions(_: String): Array<String> {
    []
}

func renderStableDependencyLines(prefix: String, supportDeps: ArrayList<String>): String {
    var content = ""
    for (dependency in stableSupportDependencyNames()) {
        if (contains(supportDeps, dependency)) {
            content += "  ${dependency} = { path = \"${prefix}/${stableSupportDependencyPath(dependency)}\" }\n"
        }
    }
    return content
}

func collectSupportDependencyNamesFromGeneratedNativeHelpers(
    packageName: String,
    dependencies: ArrayList<String>,
    files: ArrayList<GeneratedNativeHelperFile>
): Unit {
    for (file in files) {
        collectSupportDependencyNamesFromSource(packageName, dependencies, file.content)
    }
}

func collectSupportDependencyNamesFromSource(
    packageName: String,
    dependencies: ArrayList<String>,
    source: String
): Unit {
    if (source.contains("@Interface[")) {
        if (packageName != "windows_core") {
            addUnique(dependencies, "windows_core")
        }
        if (packageName != "windows_interface") {
            addUnique(dependencies, "windows_interface")
        }
    }
    if (implChunkNeedsGuidImport(source) && packageName != "windows_interface") {
        addUnique(dependencies, "windows_interface")
    }
    for (dependency in stableSupportDependencyNames()) {
        if (dependency != packageName && source.contains("${dependency}.")) {
            addUnique(dependencies, dependency)
        }
    }
}

func stableSupportDependencyNames(): Array<String> {
    return [
        "windows_collections",
        "windows_sys",
        "windows_core",
        "windows_foundation",
        "windows_future",
        "windows_implement",
        "windows_interface",
        "windows_libloading",
        "windows_polyfill",
        "windows_result",
        "windows_strings"
    ]
}

func stableSupportDependencyPath(dependency: String): String {
    match (dependency) {
        case "windows_collections" => return "windows_collections"
        case "windows_sys" => return "windows_sys"
        case "windows_core" => return "windows_core"
        case "windows_foundation" => return "windows_foundation"
        case "windows_future" => return "windows_future"
        case "windows_implement" => return "windows_implement"
        case "windows_interface" => return "windows_interface"
        case "windows_libloading" => return "windows_libloading"
        case "windows_polyfill" => return "windows_polyfill"
        case "windows_result" => return "windows_result"
        case "windows_strings" => return "windows_strings"
        case _ => return dependency
    }
}

func supportSourceDir(supportDir: String): String {
    let direct = "${supportDir}/src"
    if (directoryExists(direct)) {
        return direct
    }
    let sibling = "../${supportDir}/src"
    if (directoryExists(sibling)) {
        return sibling
    }
    throw Exception("support package src not found: ${supportDir}")
}

func scanCjSources(dir: String, namespaces: ArrayList<String>): Unit {
    let entries = Directory.readFrom(dir)
    for (entry in entries) {
        let child = "${dir}/${entry.name}"
        if (endsWith(child, ".cj")) {
            collectFeatureNamesFromSource(child, namespaces)
        } else if (directoryExists(child)) {
            scanCjSources(child, namespaces)
        }
    }
}

func collectFeatureNamesFromSource(path: String, namespaces: ArrayList<String>): Unit {
    let text = String.fromUtf8(File.readFrom(path))
    let lines = splitString(text, b'\n')
    var groupedImportBase = ""
    var inGroupedImport = false
    for (line in lines) {
        if (inGroupedImport) {
            collectGroupedImportFeatures(groupedImportBase, line, namespaces)
            if (containsByte(line, b'}')) {
                inGroupedImport = false
                groupedImportBase = ""
            }
            continue
        }
        match (windowsImportPayload(line)) {
            case Some(payload) =>
                match (collectImportPayloadFeatures(payload, namespaces)) {
                    case Some(base) =>
                        groupedImportBase = base
                        inGroupedImport = true
                    case None => ()
                }
            case None => ()
        }
    }
}

func windowsImportPayload(line: String): Option<String> {
    var text = trimAscii(line)
    if (startsWith(text, "public ")) {
        text = stripPrefix(text, "public ")
        text = trimAscii(text)
    }
    if (startsWith(text, "import windows_sys.")) {
        return Some(stripPrefix(text, "import windows_sys."))
    }
    if (startsWith(text, "import windows.")) {
        return Some(stripPrefix(text, "import windows."))
    }
    return None
}

func collectImportPayloadFeatures(payload: String, namespaces: ArrayList<String>): Option<String> {
    let bytes = payload.toArray()
    let brace = indexOfByte(payload, b'{')
    if (brace < 0) {
        match (featureNameFromWindowsImport(readImportNamespace(payload))) {
            case Some(feature) => addUnique(namespaces, feature)
            case None => ()
        }
        return None
    }

    let base = trimTrailingDot(trimAscii(String.fromUtf8(bytes[0..brace])))
    let close = indexOfByteFrom(payload, b'}', brace + 1)
    if (close >= 0) {
        collectGroupedImportFeatures(base, String.fromUtf8(bytes[(brace + 1)..close]), namespaces)
        return None
    }

    collectGroupedImportFeatures(base, String.fromUtf8(bytes[(brace + 1)..Int64(bytes.size)]), namespaces)
    return Some(base)
}

func collectGroupedImportFeatures(base: String, line: String, namespaces: ArrayList<String>): Unit {
    let beforeClose = beforeFirstByte(line, b'}')
    for (item in splitString(beforeClose, b',')) {
        let name = groupedImportItemName(item)
        if (name.isEmpty()) {
            continue
        }
        let imported = if (base.isEmpty()) {
            name
        } else {
            "${base}.${name}"
        }
        match (featureNameFromWindowsImport(imported)) {
            case Some(feature) => addUnique(namespaces, feature)
            case None => ()
        }
    }
}

func groupedImportItemName(item: String): String {
    var name = readImportNamespace(trimAscii(item))
    if (endsWith(name, "Vtbl")) {
        let bytes = name.toArray()
        name = String.fromUtf8(bytes[0..(Int64(bytes.size) - 4)])
    }
    return name
}

func featureNameFromWindowsImport(namespace: String): Option<String> {
    let normalized = trimTrailingDot(namespace)
    if (normalized.isEmpty()) {
        return None
    }
    let parts = splitString(normalized, b'.')
    for (part in parts) {
        if (part == "impl" || part == "Native") {
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
        if (byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'{' || byte == b'}' || byte == b';') {
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

func containsByte(value: String, needle: Byte): Bool {
    return indexOfByte(value, needle) >= 0
}

func indexOfByte(value: String, needle: Byte): Int64 {
    indexOfByteFrom(value, needle, 0)
}

func indexOfByteFrom(value: String, needle: Byte, start: Int64): Int64 {
    let bytes = value.toArray()
    var i = start
    while (i < Int64(bytes.size)) {
        if (bytes[i] == needle) {
            return i
        }
        i += 1
    }
    return -1
}

func beforeFirstByte(value: String, needle: Byte): String {
    let index = indexOfByte(value, needle)
    if (index < 0) {
        return value
    }
    let bytes = value.toArray()
    return String.fromUtf8(bytes[0..index])
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
