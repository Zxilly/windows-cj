package windows_cfggen

import std.collection.*
import std.fs.*

public func writeCfg(path: String, resolved: ArrayList<FeatureSpec>, defaults!: ArrayList<String> = ArrayList<String>()): Unit {
    ensureParentDir(path)
    let cfgText = buildCfgText(resolved, defaults)
    File.writeTo(path, cfgText.toArray())
}

let windowsTargetsArchiveName = "libwindows.0.53.0.a"

public func formatLinkOptions(resolved: ArrayList<FeatureSpec>, catalogRoot: String): String {
    match (tryWindowsTargetsLinkOptions(catalogRoot)) {
        case Some(linkOptions) => linkOptions
        case None => formatRawLinkOptions(resolved)
    }
}

func formatRawLinkOptions(resolved: ArrayList<FeatureSpec>): String {
    let items = ArrayList<String>()
    let seen = HashMap<String, Bool>()

    for (spec in resolved) {
        for (link in spec.links) {
            if (!seen.contains(link)) {
                seen.add(link, true)
                items.add(link)
            }
        }
    }

    return joinWithSpace(items)
}

func tryWindowsTargetsLinkOptions(catalogRoot: String): Option<String> {
    if (catalogRoot.isEmpty()) {
        return None
    }

    let targetsRoot = joinPath(cfgParentDir(catalogRoot), "windows-targets")
    let libDir = joinPath(joinPath(targetsRoot, "x86_64_gnu"), "lib")
    let archivePath = joinPath(libDir, windowsTargetsArchiveName)
    if (!exists(archivePath)) {
        return None
    }

    return Some("-L${normalizeLinkPath(libDir)} -l:${windowsTargetsArchiveName}")
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
    if (base.isEmpty()) {
        return child
    }
    let last = base[base.size - 1]
    if (last == b'/' || last == b'\\') {
        return "${base}${child}"
    }
    return "${base}/${child}"
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
    var i: Int64 = 1
    while (i < Int64(values.size)) {
        let key = values[i]
        var j = i - 1
        while (j >= 0 && values[j] > key) {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = key
        i += 1
    }
}
