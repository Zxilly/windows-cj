package windows_sync

import std.collection.*
import std.fs.*

public class WorkspaceManifest {
    public var enabledFeatures: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class FeatureSpec {
    public var name: String
    public var cfg: String = ""
    public var deps: ArrayList<String> = ArrayList<String>()
    public var links: ArrayList<String> = ArrayList<String>()

    public init(name: String) {
        this.name = name
    }
}

public func readWorkspaceManifest(path: String): WorkspaceManifest {
    let manifest = WorkspaceManifest()
    let text = readText(path)
    var inWindowsCfg = false

    for (rawLine in splitLines(text)) {
        let line = trimAscii(rawLine)
        if (line.isEmpty() || startsWith(line, "#")) {
            continue
        }
        if (line == "[windows-cj]") {
            inWindowsCfg = true
            continue
        }
        if (startsWith(line, "[") && line != "[windows-cj]") {
            if (inWindowsCfg) {
                break
            }
            continue
        }
        if (inWindowsCfg && startsWith(line, "features =")) {
            manifest.enabledFeatures.add(all: parseStringArray(line))
        }
    }

    return manifest
}

public func readFeatureCatalog(featuresPath: String, linkOptionsPath: String): HashMap<String, FeatureSpec> {
    let catalog = parseFeatureManifest(featuresPath)
    let linkCatalog = parseLinkManifest(linkOptionsPath)

    for (entry in linkCatalog) {
        let (name, linkSpec) = entry
        if (!catalog.contains(name)) {
            catalog.add(name, linkSpec)
            continue
        }
        let spec = catalog.get(name).getOrThrow()
        for (link in linkSpec.links) {
            spec.links.add(link)
        }
    }

    validateFeatureCatalog(catalog)
    return catalog
}

func validateFeatureCatalog(catalog: HashMap<String, FeatureSpec>): Unit {
    for (entry in catalog) {
        let (name, spec) = entry
        if (spec.cfg.isEmpty()) {
            throw Exception("invalid manifest: feature '${name}' missing cfg configuration")
        }
    }
}

func parseFeatureManifest(path: String): HashMap<String, FeatureSpec> {
    let catalog = HashMap<String, FeatureSpec>()
    let text = readText(path)
    var current: FeatureSpec = FeatureSpec("")
    var active = false

    for (rawLine in splitLines(text)) {
        let line = trimAscii(rawLine)
        if (line.isEmpty() || startsWith(line, "#")) {
            continue
        }
        if (startsWith(line, "[features.") && endsWith(line, "]")) {
            let name = line[10..Int64(line.size) - 1]
            current = FeatureSpec(name)
            catalog.add(name, current)
            active = true
            continue
        }
        if (!active) {
            continue
        }
        if (startsWith(line, "cfg =")) {
            current.cfg = parseStringValue(line)
        } else if (startsWith(line, "deps =")) {
            current.deps = parseStringArray(line)
        }
    }

    return catalog
}

func parseLinkManifest(path: String): HashMap<String, FeatureSpec> {
    let catalog = HashMap<String, FeatureSpec>()
    let text = readText(path)
    var current: FeatureSpec = FeatureSpec("")
    var active = false

    for (rawLine in splitLines(text)) {
        let line = trimAscii(rawLine)
        if (line.isEmpty() || startsWith(line, "#")) {
            continue
        }
        if (startsWith(line, "[features.") && endsWith(line, "]")) {
            let name = line[10..Int64(line.size) - 1]
            current = FeatureSpec(name)
            catalog.add(name, current)
            active = true
            continue
        }
        if (!active) {
            continue
        }
        if (startsWith(line, "link =")) {
            current.links = parseStringArray(line)
        }
    }

    return catalog
}

func readText(path: String): String {
    return String.fromUtf8(File.readFrom(path))
}

func splitLines(text: String): ArrayList<String> {
    let bytes = text.toArray()
    var lines = ArrayList<String>()
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

func parseStringValue(line: String): String {
    let eq = line.indexOf("=", 0)
    if (let Some(pos) <- eq) {
        return unquote(trimAscii(line[(pos + 1)..Int64(line.size)]))
    }
    return ""
}

func parseStringArray(line: String): ArrayList<String> {
    let eq = line.indexOf("=", 0)
    if (let Some(pos) <- eq) {
        let value = trimAscii(line[(pos + 1)..Int64(line.size)])
        return parseArrayValue(value)
    }
    return ArrayList<String>()
}

func parseArrayValue(value: String): ArrayList<String> {
    let trimmed = trimAscii(value)
    var result = ArrayList<String>()
    if (trimmed.size < 2) {
        return result
    }
    if (trimmed[0] != b'[' || trimmed[Int64(trimmed.size) - 1] != b']') {
        return result
    }
    let inner = trimmed[1..Int64(trimmed.size) - 1]
    var token = ""
    var inQuotes = false
    var i: Int64 = 0
    while (i < Int64(inner.size)) {
        let ch = inner[i]
        if (ch == b'"') {
            inQuotes = !inQuotes
        } else if (ch == b',' && !inQuotes) {
            let item = trimAscii(token)
            if (!item.isEmpty()) {
                result.add(unquote(item))
            }
            token = ""
        } else {
            token += String.fromUtf8(Array<Byte>(1, { _ => ch }))
        }
        i += 1
    }
    let last = trimAscii(token)
    if (!last.isEmpty()) {
        result.add(unquote(last))
    }
    return result
}

func unquote(text: String): String {
    let trimmed = trimAscii(text)
    if (trimmed.size >= 2 && trimmed[0] == b'"' && trimmed[Int64(trimmed.size) - 1] == b'"') {
        return trimmed[1..Int64(trimmed.size) - 1]
    }
    return trimmed
}

func trimAscii(text: String): String {
    let bytes = text.toArray()
    var start: Int64 = 0
    var end = Int64(bytes.size)
    while (start < end && isAsciiSpace(bytes[start])) {
        start += 1
    }
    while (end > start && isAsciiSpace(bytes[end - 1])) {
        end -= 1
    }
    return String.fromUtf8(bytes[start..end])
}

func isAsciiSpace(ch: Byte): Bool {
    return ch == b' ' || ch == b'\t' || ch == b'\r' || ch == b'\n'
}

func startsWith(text: String, prefix: String): Bool {
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

func endsWith(text: String, suffix: String): Bool {
    if (text.size < suffix.size) {
        return false
    }
    let textBytes = text.toArray()
    let suffixBytes = suffix.toArray()
    let offset = Int64(textBytes.size) - Int64(suffixBytes.size)
    var i: Int64 = 0
    while (i < Int64(suffixBytes.size)) {
        if (textBytes[offset + i] != suffixBytes[i]) {
            return false
        }
        i += 1
    }
    return true
}
