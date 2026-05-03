package windows_cfggen

import std.collection.*
import std.fs.*

public class WorkspaceManifest {
    public var enabledFeatures: ArrayList<String> = ArrayList<String>()
    public var localPackageRoots: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class FeatureSpec {
    public var name: String
    public var cfg: String = ""
    public var deps: ArrayList<String> = ArrayList<String>()
    public var links: ArrayList<String> = ArrayList<String>()
    public var linkRoots: ArrayList<String> = ArrayList<String>()

    public init(name: String) {
        this.name = name
    }
}

public func readWorkspaceManifest(path: String): WorkspaceManifest {
    let manifest = WorkspaceManifest()
    let text = readText(path)
    let lines = splitLines(text)
    let manifestRoot = manifestDir(path)
    var activeTable = ""
    var i: Int64 = 0

    while (i < Int64(lines.size)) {
        let line = trimAscii(lines[i])
        if (line.isEmpty() || startsWith(line, "#")) {
            i += 1
            continue
        }
        if (line == "[workspace]") {
            activeTable = "workspace"
            i += 1
            continue
        }
        if (line == "[windows-cj]") {
            activeTable = "windows-cj"
            i += 1
            continue
        }
        if (line == "[dependencies]" || line == "[dev-dependencies]" || line == "[build-dependencies]") {
            activeTable = "dependencies"
            i += 1
            continue
        }
        if (startsWith(line, "[")) {
            activeTable = ""
            i += 1
            continue
        }
        match (activeTable) {
            case "workspace" =>
                if (startsWith(line, "members =")) {
                    let (members, endIndex) = parseStringArrayWithContinuation(lines, i)
                    for (member in members) {
                        addUniquePath(manifest.localPackageRoots, joinPath(manifestRoot, member))
                    }
                    i = endIndex + 1
                    continue
                }
            case "windows-cj" =>
                if (startsWith(line, "features =")) {
                    let (features, endIndex) = parseStringArrayWithContinuation(lines, i)
                    manifest.enabledFeatures.add(all: features)
                    i = endIndex + 1
                    continue
                }
            case "dependencies" =>
                let dependencyRoot = parsePathDependencyRoot(line, manifestRoot)
                if (!dependencyRoot.isEmpty()) {
                    addUniquePath(manifest.localPackageRoots, dependencyRoot)
                }
            case _ => ()
        }
        i += 1
    }

    return manifest
}

public func readFeatureCatalog(featuresPath: String, linkOptionsPath: String): HashMap<String, FeatureSpec> {
    let catalog = parseFeatureManifest(featuresPath)
    let linkCatalog = parseLinkManifest(linkOptionsPath, manifestDir(linkOptionsPath))

    for (entry in linkCatalog) {
        let (name, linkSpec) = entry
        if (!catalog.contains(name)) {
            catalog.add(name, linkSpec)
            continue
        }
        let spec = catalog.get(name).getOrThrow()
        var i: Int64 = 0
        while (i < Int64(linkSpec.links.size)) {
            spec.links.add(linkSpec.links[i])
            spec.linkRoots.add(linkSpec.linkRoots[i])
            i += 1
        }
    }

    validateFeatureCatalog(catalog)
    return catalog
}

public func mergeFeatureCatalogs(catalogs: ArrayList<HashMap<String, FeatureSpec>>): HashMap<String, FeatureSpec> {
    let merged = HashMap<String, FeatureSpec>()
    for (catalog in catalogs) {
        for (entry in catalog) {
            let (name, spec) = entry
            if (!merged.contains(name)) {
                merged.add(name, cloneFeatureSpec(spec))
                continue
            }

            let existing = merged.get(name).getOrThrow()
            if (existing.cfg != spec.cfg) {
                throw Exception("feature ${name} has conflicting cfg values: ${existing.cfg} and ${spec.cfg}")
            }
            addUniqueStrings(existing.deps, spec.deps)
            addUniqueLinks(existing, spec)
        }
    }
    validateFeatureCatalog(merged)
    return merged
}

func cloneFeatureSpec(spec: FeatureSpec): FeatureSpec {
    let clone = FeatureSpec(spec.name)
    clone.cfg = spec.cfg
    clone.deps = cloneStringList(spec.deps)
    clone.links = cloneStringList(spec.links)
    clone.linkRoots = cloneStringList(spec.linkRoots)
    return clone
}

func cloneStringList(values: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (value in values) {
        result.add(value)
    }
    return result
}

func addUniqueStrings(target: ArrayList<String>, values: ArrayList<String>): Unit {
    for (value in values) {
        if (!containsString(target, value)) {
            target.add(value)
        }
    }
}

func addUniqueLinks(target: FeatureSpec, source: FeatureSpec): Unit {
    var i: Int64 = 0
    while (i < Int64(source.links.size)) {
        let link = source.links[i]
        let root = source.linkRoots[i]
        if (!containsLink(target, link, root)) {
            target.links.add(link)
            target.linkRoots.add(root)
        }
        i += 1
    }
}

func containsString(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func containsLink(spec: FeatureSpec, link: String, root: String): Bool {
    var i: Int64 = 0
    while (i < Int64(spec.links.size)) {
        if (spec.links[i] == link && spec.linkRoots[i] == root) {
            return true
        }
        i += 1
    }
    return false
}

func validateFeatureCatalog(catalog: HashMap<String, FeatureSpec>): Unit {
    for (entry in catalog) {
        let (name, spec) = entry
        if (spec.cfg.isEmpty()) {
            throw Exception("Feature ${name} missing cfg")
        }
    }
}

func parseFeatureManifest(path: String): HashMap<String, FeatureSpec> {
    let catalog = HashMap<String, FeatureSpec>()
    let text = readText(path)
    let lines = splitLines(text)
    var current: FeatureSpec = FeatureSpec("")
    var active = false
    var i: Int64 = 0

    while (i < Int64(lines.size)) {
        let line = trimAscii(lines[i])
        if (line.isEmpty() || startsWith(line, "#")) {
            i += 1
            continue
        }
        if (startsWith(line, "[features.") && endsWith(line, "]")) {
            let name = line[10..Int64(line.size) - 1]
            current = FeatureSpec(name)
            catalog.add(name, current)
            active = true
            i += 1
            continue
        }
        if (!active) {
            i += 1
            continue
        }
        if (startsWith(line, "cfg =")) {
            current.cfg = parseStringValue(line)
        } else if (startsWith(line, "deps =")) {
            let (deps, endIndex) = parseStringArrayWithContinuation(lines, i)
            current.deps = deps
            i = endIndex + 1
            continue
        }
        i += 1
    }

    return catalog
}

func parseLinkManifest(path: String, catalogRoot: String): HashMap<String, FeatureSpec> {
    let catalog = HashMap<String, FeatureSpec>()
    let text = readText(path)
    let lines = splitLines(text)
    var current: FeatureSpec = FeatureSpec("")
    var active = false
    var i: Int64 = 0

    while (i < Int64(lines.size)) {
        let line = trimAscii(lines[i])
        if (line.isEmpty() || startsWith(line, "#")) {
            i += 1
            continue
        }
        if (startsWith(line, "[features.") && endsWith(line, "]")) {
            let name = line[10..Int64(line.size) - 1]
            current = FeatureSpec(name)
            catalog.add(name, current)
            active = true
            i += 1
            continue
        }
        if (!active) {
            i += 1
            continue
        }
        if (startsWith(line, "link =")) {
            let (links, endIndex) = parseStringArrayWithContinuation(lines, i)
            current.links = links
            current.linkRoots = ArrayList<String>()
            for (link in links) {
                current.linkRoots.add(catalogRoot)
            }
            i = endIndex + 1
            continue
        }
        i += 1
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

func parseStringArrayWithContinuation(lines: ArrayList<String>, startIndex: Int64): (ArrayList<String>, Int64) {
    let line = trimAscii(lines[startIndex])
    let eq = line.indexOf("=", 0)
    if (let Some(pos) <- eq) {
        var value = trimAscii(line[(pos + 1)..Int64(line.size)])
        var endIndex = startIndex
        while (!arrayLiteralClosed(value) && (endIndex + 1) < Int64(lines.size)) {
            endIndex += 1
            let continuation = trimAscii(lines[endIndex])
            if (continuation.isEmpty() || startsWith(continuation, "#")) {
                continue
            }
            if (!value.isEmpty()) {
                value += " "
            }
            value += continuation
        }
        return (parseArrayValue(value), endIndex)
    }
    return (ArrayList<String>(), startIndex)
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

func arrayLiteralClosed(value: String): Bool {
    let bytes = value.toArray()
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b']') {
            return true
        }
        i += 1
    }
    return false
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

func parsePathDependencyRoot(line: String, manifestRoot: String): String {
    if (!line.contains("{")) {
        return ""
    }
    match (parseInlineTableQuotedValue(line, "path")) {
        case Some(pathValue) =>
            if (pathValue.isEmpty()) {
                return ""
            }
            return joinPath(manifestRoot, pathValue)
        case None => return ""
    }
}

func parseInlineTableQuotedValue(line: String, key: String): Option<String> {
    match (line.indexOf(key, 0)) {
        case Some(keyPos) =>
            let tail = line[keyPos..Int64(line.size)]
            match (tail.indexOf("=", 0)) {
                case Some(eqPos) =>
                    let value = trimAscii(tail[eqPos + 1..Int64(tail.size)])
                    return Some(parseQuotedPrefix(value))
                case None => return None
            }
        case None => return None
    }
}

func parseQuotedPrefix(text: String): String {
    if (text.size < 2 || text[0] != b'"') {
        return ""
    }

    var i: Int64 = 1
    while (i < Int64(text.size)) {
        if (text[i] == b'"') {
            return text[1..i]
        }
        i += 1
    }
    return ""
}

func addUniquePath(values: ArrayList<String>, path: String): Unit {
    if (path.isEmpty()) {
        return
    }
    var normalized = Path(path).normalize().toString()
    try {
        normalized = canonicalize(path).toString()
    } catch (e: Exception) {
        let _ = e
    }
    for (value in values) {
        if (value == normalized) {
            return
        }
    }
    values.add(normalized)
}

public func collectLocalPackageRoots(workspaceRoot: String, workspace: WorkspaceManifest): ArrayList<String> {
    let roots = ArrayList<String>()
    addUniquePath(roots, workspaceRoot)
    for (root in workspace.localPackageRoots) {
        addUniquePath(roots, root)
    }

    var i: Int64 = 0
    while (i < Int64(roots.size)) {
        let manifestPath = joinPath(roots[i], "cjpm.toml")
        if (exists(manifestPath)) {
            let dependencyRoots = parseDependencyRootsFromManifest(manifestPath)
            for (dependencyRoot in dependencyRoots) {
                addUniquePath(roots, dependencyRoot)
            }
        }
        i += 1
    }

    return roots
}

func parseDependencyRootsFromManifest(path: String): ArrayList<String> {
    let roots = ArrayList<String>()
    let text = readText(path)
    let lines = splitLines(text)
    let root = manifestDir(path)
    var activeTable = ""
    var i: Int64 = 0

    while (i < Int64(lines.size)) {
        let line = trimAscii(lines[i])
        if (line.isEmpty() || startsWith(line, "#")) {
            i += 1
            continue
        }
        if (line == "[dependencies]" || line == "[dev-dependencies]" || line == "[build-dependencies]") {
            activeTable = "dependencies"
            i += 1
            continue
        }
        if (startsWith(line, "[")) {
            activeTable = ""
            i += 1
            continue
        }
        if (activeTable == "dependencies") {
            let dependencyRoot = parsePathDependencyRoot(line, root)
            if (!dependencyRoot.isEmpty()) {
                addUniquePath(roots, dependencyRoot)
            }
        }
        i += 1
    }

    return roots
}

func manifestDir(path: String): String {
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
        return "."
    }
    return String.fromUtf8(bytes[0..lastSep])
}
