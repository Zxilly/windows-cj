package windows_bindgen

import std.collection.*
import std.fs.*

// CodeWriter accumulates generated Cangjie source lines
public class CodeWriter {
    var lines: ArrayList<String> = ArrayList<String>()
    var indentLevel: Int64 = 0

    public init() {}

    public func indent(): Unit {
        indentLevel += 1
    }

    public func dedent(): Unit {
        if (indentLevel > 0) {
            indentLevel -= 1
        }
    }

    func indentStr(): String {
        var s = ""
        var i: Int64 = 0
        while (i < indentLevel) {
            s += "    "
            i += 1
        }
        return s
    }

    public func writeLine(line: String): Unit {
        if (line.isEmpty()) {
            lines.add("")
        } else {
            lines.add("${indentStr()}${line}")
        }
    }

    public func writeBlankLine(): Unit {
        lines.add("")
    }

    public func writeBlock(header: String, body: () -> Unit): Unit {
        writeLine("${header} {")
        indent()
        body()
        dedent()
        writeLine("}")
    }

    public func toString(): String {
        var sb = StringBuilder()
        for (line in lines) {
            sb.append(line)
            sb.append("\n")
        }
        return sb.toString()
    }

    public func isEmpty(): Bool {
        return lines.isEmpty()
    }
}

// FileWriter manages output to a directory tree organized by namespace
public class FileWriter {
    public let outputDir: String

    public init(outputDir: String) {
        this.outputDir = outputDir
    }

    // Write a CodeWriter's content to a file under the output directory
    public func writeFile(relativePath: String, content: String): Unit {
        let fullPath = "${outputDir}/${relativePath}"
        let dir = directoryOf(fullPath)
        ensureDir(dir)
        File.writeTo(fullPath, content.toArray())
    }

    // Convert a namespace like "Windows.Win32.Foundation" to directory path "windows/win32/foundation"
    public static func namespaceToDirPath(namespace: String): String {
        let parts = splitString(namespace, b'.')
        var result = StringBuilder()
        var first = true
        for (p in parts) {
            if (!first) {
                result.append("/")
            }
            result.append(sanitizePackageSegment(p))
            first = false
        }
        return result.toString()
    }

    // Convert namespace to package name: "Windows.Win32.Foundation" -> "windows.win32.foundation"
    public static func namespaceToPackageName(namespace: String): String {
        let parts = splitString(namespace, b'.')
        let normalized = ArrayList<String>()
        for (p in parts) {
            normalized.add(sanitizePackageSegment(p))
        }
        return joinStrings(normalized, ".")
    }

    public static func namespaceToPackageRelativeParts(namespace: String): ArrayList<String> {
        let parts = splitString(namespace, b'.')
        let normalized = ArrayList<String>()
        var start: Int64 = 0
        if (!parts.isEmpty() && parts[0] == "Windows") {
            start = 1
        }

        var i = start
        while (i < Int64(parts.size)) {
            normalized.add(sanitizePackageSegment(parts[i]))
            i += 1
        }
        return normalized
    }

    public static func packageNameToRelativeParts(packageName: String, rootPackage: String): ArrayList<String> {
        let packageParts = splitString(packageName, b'.')
        let rootParts = splitString(rootPackage, b'.')
        let result = ArrayList<String>()

        var start: Int64 = 0
        if (packageParts.size >= rootParts.size) {
            var matchesRoot = true
            var i: Int64 = 0
            while (i < Int64(rootParts.size)) {
                if (packageParts[i] != rootParts[i]) {
                    matchesRoot = false
                    break
                }
                i += 1
            }
            if (matchesRoot) {
                start = Int64(rootParts.size)
            }
        }

        var i = start
        while (i < Int64(packageParts.size)) {
            result.add(packageParts[i])
            i += 1
        }
        return result
    }

    public static func packageNameToRelativeDirPath(packageName: String, rootPackage: String): String {
        return joinStrings(packageNameToRelativeParts(packageName, rootPackage), "/")
    }

    public static func namespaceToHierarchicalDirPath(namespace: String): String {
        let parts = namespaceToPackageRelativeParts(namespace)
        return joinStrings(parts, "/")
    }

    public static func namespaceToHierarchicalPackageName(namespace: String, rootPackage: String): String {
        let parts = namespaceToPackageRelativeParts(namespace)
        if (parts.isEmpty()) {
            return rootPackage
        }
        return "${rootPackage}.${joinStrings(parts, ".")}"
    }

    public static func namespaceToGroupedFileStem(namespace: String, packageNamespace: String): String {
        let namespaceParts = namespaceToPackageRelativeParts(namespace)
        let packageParts = namespaceToPackageRelativeParts(packageNamespace)
        if (namespaceParts.size <= packageParts.size) {
            return "mod"
        }

        let suffix = ArrayList<String>()
        var i = Int64(packageParts.size)
        while (i < Int64(namespaceParts.size)) {
            suffix.add(namespaceParts[i])
            i += 1
        }
        if (suffix.isEmpty()) {
            return "mod"
        }
        return joinStrings(suffix, "_")
    }
}

// Get directory portion of a path
func directoryOf(path: String): String {
    let arr = path.toArray()
    var lastSep: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'/' || arr[i] == b'\\') {
            lastSep = i
        }
        i += 1
    }
    if (lastSep >= 0) {
        return String.fromUtf8(arr[0..lastSep])
    }
    return "."
}

// Ensure directory exists (recursive)
func ensureDir(dirPath: String): Unit {
    if (directoryExists(dirPath)) {
        return
    }
    var attempt: Int64 = 0
    while (attempt < 8) {
        try {
            Directory.create(dirPath, recursive: true)
            return
        } catch (err: Exception) {
            if (directoryExists(dirPath)) {
                return
            }
            if (attempt == 7) {
                throw err
            }
        }
        attempt += 1
    }
}

func directoryExists(path: String): Bool {
    try {
        Directory.readFrom(path)
        return true
    } catch (_: Exception) {
        return false
    }
}

// Split a string by a separator byte
public func splitString(s: String, sep: Byte): ArrayList<String> {
    let arr = s.toArray()
    var result = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == sep) {
            if (i > start) {
                result.add(String.fromUtf8(arr[start..i]))
            }
            start = i + 1
        }
        i += 1
    }
    if (start < Int64(arr.size)) {
        result.add(String.fromUtf8(arr[start..Int64(arr.size)]))
    }
    return result
}

func byteListToString(bytes: ArrayList<Byte>): String {
    var arr = Array<Byte>(bytes.size, {_ => b'0'})
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        arr[i] = bytes[i]
        i += 1
    }
    return String.fromUtf8(arr)
}

public func writeAvailabilityAttributes(w: CodeWriter, feature: String, arches: String): Unit {
    writeAvailabilityForTags(w, feature, architectureCfgTags(arches))
}

public func writeAvailabilityForTags(w: CodeWriter, feature: String, tags: ArrayList<String>): Unit {
    let condition = availabilityCondition(feature, tags)
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
}

public func availabilityCondition(feature: String, tags: ArrayList<String>): String {
    let conditions = ArrayList<String>()
    if (!feature.isEmpty()) {
        conditions.add("${feature} == \"on\"")
    }

    let uniqueTags = uniqueStrings(tags)
    if (uniqueTags.size == 1) {
        conditions.add(availabilityTagCondition(uniqueTags[0]))
    } else if (!uniqueTags.isEmpty()) {
        let options = ArrayList<String>()
        for (tag in uniqueTags) {
            options.add(availabilityTagCondition(tag))
        }
        conditions.add("(${joinStrings(options, " || ")})")
    }

    if (conditions.isEmpty()) {
        return ""
    }
    return joinStrings(conditions, " && ")
}

func availabilityTagCondition(tag: String): String {
    match (tag) {
        case "arch_x86_64" => return "arch == \"x86_64\""
        case "arch_arm64" => return "arch == \"aarch64\""
        case _ => return tag
    }
}

func uniqueStrings(values: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (value in values) {
        var seen = false
        for (existing in result) {
            if (existing == value) {
                seen = true
                break
            }
        }
        if (!seen) {
            result.add(value)
        }
    }
    return result
}

public func architectureCfgTags(arches: String): ArrayList<String> {
    let result = ArrayList<String>()
    let mask = parseInt64OrZero(arches)
    if (mask <= 0 || mask == 7) {
        return result
    }
    if ((mask & 2) != 0) {
        result.add("arch_x86_64")
    }
    if ((mask & 4) != 0) {
        result.add("arch_arm64")
    }
    return result
}

public func isUnsupportedOnlyArchitecture(arches: String): Bool {
    let mask = parseInt64OrZero(arches)
    if (mask <= 0 || mask == 7) {
        return false
    }
    return (mask & 6) == 0
}

func parseInt64OrZero(text: String): Int64 {
    if (text.isEmpty()) {
        return 0
    }

    let arr = text.toArray()
    var value: Int64 = 0
    var negative = false
    var i: Int64 = 0
    if (arr[0] == b'-') {
        negative = true
        i = 1
    }

    while (i < Int64(arr.size)) {
        let ch = arr[i]
        if (ch < b'0' || ch > b'9') {
            return 0
        }
        value = value * 10 + Int64(ch - b'0')
        i += 1
    }

    if (negative) {
        return -value
    }
    return value
}
