package windows_cfggen

import std.collection.*
import std.fs.*
import std.sort.*

// Sole writer of cfg.toml. The catalog triplet
// (cfg_list/features/link-options.toml) is emitted per sys package by
// windows-bindgen and consumed here read-only.

public func writeCfg(path: String, resolved: ArrayList<FeatureSpec>, defaults!: ArrayList<String> = ArrayList<String>()): Unit {
    ensureParentDir(path)
    let cfgText = buildCfgText(resolved, defaults)
    File.writeTo(path, cfgText.toArray())
}

public func writeLinkOptions(path: String, linkOptions: String): Unit {
    ensureParentDir(path)
    let text = if (linkOptions.isEmpty()) { "" } else { "${linkOptions}\n" }
    File.writeTo(path, text.toArray())
}

public func updateManifestBuildOptions(manifestPath: String, linkOptions: String, cfgDir: String): Unit {
    if (linkOptions.isEmpty()) {
        if (cfgDir.isEmpty()) {
            return
        }
    }

    let lines = cfgSplitLines(String.fromUtf8(File.readFrom(manifestPath)))
    let existingOverrideCompileOption = readPackageStringOption(lines, "override-compile-option")
    let existingCompileOption = readPackageStringOption(lines, "compile-option")
    let overrideSource = match (existingOverrideCompileOption) {
        case Some(value) => value
        case None =>
            match (existingCompileOption) {
                case Some(value) => value
                case None => ""
            }
    }
    let output = ArrayList<String>()
    let linkLine = if (linkOptions.isEmpty()) { "" } else { "  link-option = \"${tomlEscape(linkOptions)}\"" }
    let overrideCompileOption = if (cfgDir.isEmpty()) { "" } else { ensureCfgCompileOption(overrideSource, cfgDir) }
    let overrideLine = if (overrideCompileOption.isEmpty()) { "" } else { "  override-compile-option = \"${tomlEscape(overrideCompileOption)}\"" }
    var inPackage = false
    var packageFound = false
    var insertedLink = linkLine.isEmpty()
    var insertedOverride = overrideLine.isEmpty()

    for (line in lines) {
        let trimmed = cfgTrimAscii(line)
        if (trimmed == "[package]") {
            packageFound = true
            inPackage = true
            output.add(line)
            continue
        }

        if (inPackage && trimmed.isEmpty() && (!insertedOverride || !insertedLink)) {
            insertPackageBuildOptionLines(output, overrideLine, linkLine, insertedOverride, insertedLink)
            insertedOverride = true
            insertedLink = true
            output.add(line)
            continue
        }

        if (inPackage && cfgStartsWith(trimmed, "[")) {
            if (!insertedOverride || !insertedLink) {
                insertPackageBuildOptionLines(output, overrideLine, linkLine, insertedOverride, insertedLink)
                insertedOverride = true
                insertedLink = true
            }
            inPackage = false
        }

        if (inPackage && cfgStartsWith(trimmed, "link-option =")) {
            if (!insertedLink && !linkLine.isEmpty()) {
                output.add(linkLine)
                insertedLink = true
            }
            continue
        }

        if (inPackage && cfgStartsWith(trimmed, "override-compile-option =")) {
            if (!insertedOverride && !overrideLine.isEmpty()) {
                output.add(overrideLine)
                insertedOverride = true
            }
            continue
        }

        output.add(line)
    }

    if (inPackage && (!insertedOverride || !insertedLink)) {
        insertPackageBuildOptionLines(output, overrideLine, linkLine, insertedOverride, insertedLink)
        insertedOverride = true
        insertedLink = true
    }

    if (!packageFound) {
        throw Exception("cannot update manifest build options: [package] section not found in ${manifestPath}")
    }

    File.writeTo(manifestPath, joinLines(output).toArray())
}

func insertPackageBuildOptionLines(
    output: ArrayList<String>,
    overrideLine: String,
    linkLine: String,
    insertedOverride: Bool,
    insertedLink: Bool
): Unit {
    if (!insertedOverride && !overrideLine.isEmpty()) {
        output.add(overrideLine)
    }
    if (!insertedLink && !linkLine.isEmpty()) {
        output.add(linkLine)
    }
}

let windowsTargetsArchiveName = "libwindows.0.53.0.a"

public func formatLinkOptions(resolved: ArrayList<FeatureSpec>, catalogRoots: ArrayList<String>): String {
    let items = ArrayList<String>()
    let seen = HashMap<String, Bool>()
    let fastPathRoots = HashMap<String, Bool>()

    for (catalogRoot in catalogRoots) {
        let normalizedRoot = normalizeCatalogRoot(catalogRoot)
        match (tryWindowsTargetsLinkOptions(normalizedRoot)) {
            case Some(linkOptions) =>
                fastPathRoots.add(normalizedRoot, true)
                appendUniqueLinkOption(items, seen, linkOptions)
            case None => ()
        }
    }

    appendRawLinkOptions(items, seen, resolved, fastPathRoots)
    return joinWithSpace(items)
}

func appendRawLinkOptions(
    items: ArrayList<String>,
    seen: HashMap<String, Bool>,
    resolved: ArrayList<FeatureSpec>,
    fastPathRoots: HashMap<String, Bool>
): Unit {
    for (spec in resolved) {
        var i: Int64 = 0
        while (i < Int64(spec.links.size)) {
            let linkRoot = normalizeCatalogRoot(spec.linkRoots[i])
            if (!fastPathRoots.contains(linkRoot) && tryWindowsTargetsLinkOptions(linkRoot).isNone()) {
                appendUniqueLinkOption(items, seen, spec.links[i])
            }
            i += 1
        }
    }
}

func appendUniqueLinkOption(items: ArrayList<String>, seen: HashMap<String, Bool>, linkOption: String): Unit {
    if (!seen.contains(linkOption)) {
        seen.add(linkOption, true)
        items.add(linkOption)
    }
}

func tryWindowsTargetsLinkOptions(catalogRoot: String): Option<String> {
    let normalizedRoot = normalizeCatalogRoot(catalogRoot)
    if (normalizedRoot.isEmpty()) {
        return None
    }
    let catalogName = baseName(normalizedRoot)
    if (catalogName != "windows-sys" && catalogName != "windows") {
        return None
    }

    let targetsRoot = joinPath(cfgParentDir(normalizedRoot), "windows-targets")
    let libDir = joinPath(joinPath(targetsRoot, "x86_64_gnu"), "lib")
    let archivePath = joinPath(libDir, windowsTargetsArchiveName)
    if (!exists(archivePath)) {
        return None
    }

    return Some("-L${normalizeLinkPath(libDir)} -l:${windowsTargetsArchiveName}")
}

func normalizeCatalogRoot(path: String): String {
    if (path.isEmpty()) {
        return path
    }
    var normalized = Path(path).normalize().toString()
    try {
        normalized = canonicalize(path).toString()
    } catch (e: Exception) {
        let _ = e
    }
    return normalized
}

func baseName(path: String): String {
    let bytes = path.toArray()
    var end = Int64(bytes.size)
    while (end > 0 && (bytes[end - 1] == b'/' || bytes[end - 1] == b'\\')) {
        end -= 1
    }
    var start = end - 1
    while (start >= 0 && bytes[start] != b'/' && bytes[start] != b'\\') {
        start -= 1
    }
    return String.fromUtf8(bytes[(start + 1)..end])
}

func buildCfgText(resolved: ArrayList<FeatureSpec>, defaults: ArrayList<String>): String {
    let orderedKeys = ArrayList<String>()
    let values = HashMap<String, String>()
    for (key in defaults) {
        if (!values.contains(key)) {
            orderedKeys.add(key)
        }
        values[key] = "off"
    }
    for (spec in resolved) {
        if (!values.contains(spec.cfg)) {
            orderedKeys.add(spec.cfg)
        }
        values[spec.cfg] = "on"
    }
    cfgSortStrings(orderedKeys)

    var text = ""
    for (key in orderedKeys) {
        text += "${key} = \"${values[key]}\"\n"
    }
    return text
}

public func readCfgKeys(path: String): ArrayList<String> {
    let result = ArrayList<String>()
    if (!exists(path)) {
        return result
    }

    let text = String.fromUtf8(File.readFrom(path))
    let lines = cfgSplitLines(text)
    for (line in lines) {
        let trimmed = cfgTrimAscii(line)
        if (trimmed.isEmpty() || cfgStartsWith(trimmed, "#")) {
            continue
        }
        match (trimmed.indexOf("=", 0)) {
            case Some(pos) =>
                let key = cfgTrimAscii(trimmed[0..pos])
                if (!key.isEmpty() && !cfgContainsString(result, key)) {
                    result.add(key)
                }
            case None => ()
        }
    }
    return result
}

func joinWithSpace(items: ArrayList<String>): String {
    var text = ""
    var i: Int64 = 0
    while (i < Int64(items.size)) {
        if (i > 0) {
            text += " "
        }
        text += items[i]
        i += 1
    }
    return text
}

func joinLines(lines: ArrayList<String>): String {
    var text = ""
    for (line in lines) {
        text += line
        text += "\n"
    }
    return text
}

func tomlEscape(value: String): String {
    let bytes = value.toArray()
    var result = ""
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'\\') {
            result += "\\\\"
        } else if (bytes[i] == b'"') {
            result += "\\\""
        } else {
            let ch = bytes[i]
            result += String.fromUtf8(Array<Byte>(1, { _ => ch }))
        }
        i += 1
    }
    return result
}

func readPackageStringOption(lines: ArrayList<String>, key: String): Option<String> {
    let prefix = "${key} ="
    var inPackage = false
    for (line in lines) {
        let trimmed = cfgTrimAscii(line)
        if (trimmed == "[package]") {
            inPackage = true
            continue
        }
        if (inPackage && cfgStartsWith(trimmed, "[")) {
            return None
        }
        if (inPackage && cfgStartsWith(trimmed, prefix)) {
            return parseTomlStringValue(trimmed)
        }
    }
    return None
}

func parseTomlStringValue(line: String): Option<String> {
    match (line.indexOf("=", 0)) {
        case Some(pos) =>
            let raw = cfgTrimAscii(line[(pos + 1)..])
            let bytes = raw.toArray()
            if (Int64(bytes.size) < 2 || bytes[0] != b'"' || bytes[Int64(bytes.size) - 1] != b'"') {
                return None
            }
            return Some(tomlUnescape(raw[1..(Int64(bytes.size) - 1)]))
        case None => return None
    }
}

func tomlUnescape(value: String): String {
    let bytes = value.toArray()
    var result = ""
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'\\' && (i + 1) < Int64(bytes.size)) {
            i += 1
        }
        let ch = bytes[i]
        result += String.fromUtf8(Array<Byte>(1, { _ => ch }))
        i += 1
    }
    return result
}

func ensureCfgCompileOption(source: String, cfgDir: String): String {
    let tokens = splitAsciiWhitespace(source)
    let output = ArrayList<String>()
    output.add("--cfg")
    output.add(cfgDir)

    var i: Int64 = 0
    while (i < Int64(tokens.size)) {
        let token = tokens[i]
        if (token == "--cfg") {
            i += 2
            continue
        }
        if (cfgStartsWith(token, "--cfg=")) {
            i += 1
            continue
        }
        output.add(token)
        i += 1
    }

    return joinWithSpace(output)
}

func splitAsciiWhitespace(text: String): ArrayList<String> {
    let bytes = text.toArray()
    let tokens = ArrayList<String>()
    var start: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (cfgIsAsciiSpace(bytes[i])) {
            if (start >= 0) {
                tokens.add(String.fromUtf8(bytes[start..i]))
                start = -1
            }
        } else if (start < 0) {
            start = i
        }
        i += 1
    }
    if (start >= 0) {
        tokens.add(String.fromUtf8(bytes[start..Int64(bytes.size)]))
    }
    return tokens
}

func ensureParentDir(path: String): Unit {
    let dir = directoryOf(path)
    if (!exists(dir)) {
        Directory.create(dir, recursive: true)
    }
}

func directoryOf(path: String): String {
    let bytes = path.toArray()
    var lastSep: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'/' || bytes[i] == b'\\') {
            lastSep = i
        }
        i += 1
    }
    if (lastSep >= 0) {
        return String.fromUtf8(bytes[0..lastSep])
    }
    return "."
}

func cfgParentDir(path: String): String {
    let bytes = path.toArray()
    var lastSep: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'/' || bytes[i] == b'\\') {
            lastSep = i
        }
        i += 1
    }
    if (lastSep <= 0) {
        return path
    }
    return String.fromUtf8(bytes[0..lastSep])
}

func normalizeLinkPath(path: String): String {
    let bytes = path.toArray()
    let normalized = Array<Byte>(
        bytes.size,
        {
            i =>
                if (bytes[i] == b'\\') {
                    b'/'
                } else {
                    bytes[i]
                }
        }
    )
    return String.fromUtf8(normalized)
}

public func joinPath(base: String, child: String): String {
    if (isAbsolutePath(child)) {
        return child
    }
    if (base.isEmpty()) {
        return child
    }
    let last = base[base.size - 1]
    if (last == b'/' || last == b'\\') {
        return "${base}${child}"
    }
    return "${base}/${child}"
}

func isAbsolutePath(path: String): Bool {
    if (path.isEmpty()) {
        return false
    }
    let bytes = path.toArray()
    if (bytes[0] == b'/' || bytes[0] == b'\\') {
        return true
    }
    return Int64(bytes.size) >= 2 && bytes[1] == b':'
}

func cfgSplitLines(text: String): ArrayList<String> {
    let bytes = text.toArray()
    let lines = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'\n') {
            let end = if (i > start && bytes[i - 1] == b'\r') { i - 1 } else { i }
            lines.add(String.fromUtf8(bytes[start..end]))
            start = i + 1
        }
        i += 1
    }
    if (start < Int64(bytes.size)) {
        let end = if (bytes[Int64(bytes.size) - 1] == b'\r') { Int64(bytes.size) - 1 } else { Int64(bytes.size) }
        lines.add(String.fromUtf8(bytes[start..end]))
    }
    return lines
}

func cfgTrimAscii(text: String): String {
    let bytes = text.toArray()
    var start: Int64 = 0
    var end = Int64(bytes.size)
    while (start < end && cfgIsAsciiSpace(bytes[start])) {
        start += 1
    }
    while (end > start && cfgIsAsciiSpace(bytes[end - 1])) {
        end -= 1
    }
    return String.fromUtf8(bytes[start..end])
}

func cfgIsAsciiSpace(ch: Byte): Bool {
    return ch == b' ' || ch == b'\t' || ch == b'\r' || ch == b'\n'
}

func cfgStartsWith(text: String, prefix: String): Bool {
    if (text.size < prefix.size) {
        return false
    }
    let textBytes = text.toArray()
    let prefixBytes = prefix.toArray()
    var i: Int64 = 0
    while (i < Int64(prefixBytes.size)) {
        if (textBytes[i] != prefixBytes[i]) {
            return false
        }
        i += 1
    }
    return true
}

func cfgContainsString(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func cfgSortStrings(values: ArrayList<String>): Unit {
    sort<String>(values, by: { a: String, b: String =>
        if (a < b) {
            return Ordering.LT
        }
        if (a > b) {
            return Ordering.GT
        }
        Ordering.EQ
    })
}
