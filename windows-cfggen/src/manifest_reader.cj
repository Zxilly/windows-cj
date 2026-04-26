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

func parseLinkManifest(path: String): HashMap<String, FeatureSpec> {
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
    for (value in values) {
        if (value == path) {
            return
        }
    }
    values.add(path)
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


public func collectCfgRoots(workspaceRoot: String, workspaceManifestPath: String): ArrayList<String> {
    let roots = ArrayList<String>()
    let seen = HashMap<String, Bool>()

    appendCfgRoot(workspaceRoot, roots, seen)
    let workspaceMembers = parseWorkspaceMemberRoots(workspaceRoot, workspaceManifestPath)
    for (memberRoot in workspaceMembers) {
        appendCfgRoot(memberRoot, roots, seen)
    }

    var i: Int64 = 0
    while (i < Int64(roots.size)) {
        let root = roots[i]
        let manifestPath = joinPath(root, "cjpm.toml")
        if (exists(manifestPath)) {
            let dependencyRoots = parseLocalDependencyRoots(root, manifestPath)
            for (dependencyRoot in dependencyRoots) {
                appendCfgRoot(dependencyRoot, roots, seen)
            }
        }
        i += 1
    }

    return roots
}

func parseWorkspaceMemberRoots(workspaceRoot: String, manifestPath: String): ArrayList<String> {
    let roots = ArrayList<String>()
    let text = readText(manifestPath)
    let lines = splitLines(text)
    var inWorkspace = false
    var i: Int64 = 0

    while (i < Int64(lines.size)) {
        let line = trimAscii(lines[i])
        if (line.isEmpty() || startsWith(line, "#")) {
            i += 1
            continue
        }
        if (line == "[workspace]") {
            inWorkspace = true
            i += 1
            continue
        }
        if (startsWith(line, "[")) {
            if (inWorkspace) {
                break
            }
            i += 1
            continue
        }
        if (inWorkspace && startsWith(line, "members =")) {
            let (members, endIndex) = parseStringArrayWithContinuation(lines, i)
            for (member in members) {
                roots.add(joinPath(workspaceRoot, member))
            }
            i = endIndex + 1
            continue
        }
        i += 1
    }

    return roots
}

func parseLocalDependencyRoots(packageRoot: String, manifestPath: String): ArrayList<String> {
    let roots = ArrayList<String>()
    let text = readText(manifestPath)
    let lines = splitLines(text)
    var inDependencySection = false
    var i: Int64 = 0

    while (i < Int64(lines.size)) {
        let line = trimAscii(lines[i])
        if (line.isEmpty() || startsWith(line, "#")) {
            i += 1
            continue
        }
        if (startsWith(line, "[")) {
            inDependencySection = isDependencySection(line)
            i += 1
            continue
        }
        if (inDependencySection) {
            let dependencyPath = extractDependencyPath(line)
            if (!dependencyPath.isEmpty()) {
                roots.add(resolveRelativePath(packageRoot, dependencyPath))
            }
        }
        i += 1
    }

    return roots
}

func isDependencySection(line: String): Bool {
    if (!startsWith(line, "[") || !endsWith(line, "]")) {
        return false
    }
    let section = line[1..Int64(line.size) - 1]
    return section == "dependencies" || section == "dev-dependencies" || section == "build-dependencies"
}

func extractDependencyPath(line: String): String {
    let bytes = line.toArray()
    var i: Int64 = 0
    while ((i + 3) < Int64(bytes.size)) {
        if (bytes[i] == b'p' && bytes[i + 1] == b'a' && bytes[i + 2] == b't' && bytes[i + 3] == b'h') {
            var j = i + 4
            while (j < Int64(bytes.size) && isAsciiSpace(bytes[j])) {
                j += 1
            }
            if (j < Int64(bytes.size) && bytes[j] == b'=') {
                j += 1
                while (j < Int64(bytes.size) && isAsciiSpace(bytes[j])) {
                    j += 1
                }
                if (j < Int64(bytes.size) && bytes[j] == b'"') {
                    let start = j + 1
                    j += 1
                    while (j < Int64(bytes.size) && bytes[j] != b'"') {
                        j += 1
                    }
                    if (j < Int64(bytes.size)) {
                        return String.fromUtf8(bytes[start..j])
                    }
                }
            }
        }
        i += 1
    }
    return ""
}

func resolveRelativePath(base: String, child: String): String {
    if (isAbsolutePath(child)) {
        return child
    }
    return joinPath(base, child)
}

func appendCfgRoot(root: String, roots: ArrayList<String>, seen: HashMap<String, Bool>): Unit {
    let manifestPath = joinPath(root, "cjpm.toml")
    if (!exists(manifestPath)) {
        return
    }
    let normalizedRoot = normalizeRootPath(root)
    if (seen.contains(normalizedRoot)) {
        return
    }
    seen.add(normalizedRoot, true)
    roots.add(normalizedRoot)
}

func normalizeRootPath(path: String): String {
    return canonicalize(path).toString()
}

func isAbsolutePath(path: String): Bool {
    if (path.isEmpty()) {
        return false
    }
    let bytes = path.toArray()
    if (bytes[0] == b'/' || bytes[0] == b'\\') {
        return true
    }
    if (Int64(bytes.size) >= 2 && bytes[1] == b':') {
        return true
    }
    return false
}
