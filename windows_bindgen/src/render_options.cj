package windows_bindgen

import std.collection.*

public class ReferenceStage {
    public let name: String
    public let style: String
    public let path: String

    public init(name: String, style: String, path: String) {
        this.name = name
        this.style = style
        this.path = path
    }

    public static func parse(arg: String): ReferenceStage {
        var input = arg
        if (input == "windows") {
            input = "windows,skip-root,Windows"
        }
        let parts = splitString(input, b',')
        if (parts.size != 3) {
            throw Exception("--reference must be `<package>,<style>,<namespace>`")
        }
        let style = parts[1]
        if (style != "flat" && style != "full" && style != "skip-root") {
            throw Exception("--reference style must be flat|full|skip-root, got `${style}`")
        }
        return ReferenceStage(parts[0], style, parts[2])
    }
}

public class RenderOptions {
    public var sys: Bool
    public var implement: Bool
    public var noComment: Bool
    public var ergonomicWrappers: Bool
    public let derives: ArrayList<String>
    public let references: ArrayList<ReferenceStage>

    public init() {
        this.sys = false
        this.implement = false
        this.noComment = false
        this.ergonomicWrappers = false
        this.derives = ArrayList<String>()
        this.references = ArrayList<ReferenceStage>()
    }

    public static func defaults(): RenderOptions {
        return RenderOptions()
    }

    public static func cliDefaults(): RenderOptions {
        let options = RenderOptions()
        options.ergonomicWrappers = true
        return options
    }

    public func hasDerive(name: String): Bool {
        for (value in derives) {
            if (value == name) {
                return true
            }
        }
        return false
    }
}

public func referenceMatchesFullName(stage: ReferenceStage, namespace: String, name: String, fullName: String): Bool {
    let pattern = stage.path
    if (pattern == "all") {
        return true
    }
    if (stringContainsByte(pattern, b'*')) {
        return wildcardMatchesString(pattern, fullName) ||
            wildcardMatchesString(pattern, namespace) ||
            wildcardMatchesString(pattern, name)
    }
    if (fullName == pattern || name == pattern) {
        return true
    }
    return namespace == pattern
}

public func referenceContainsRecord(references: ArrayList<ReferenceStage>, record: SymbolRecord): Option<ReferenceStage> {
    for (stage in references) {
        if (referenceMatchesFullName(stage, record.namespace, record.name, record.fullName)) {
            return Some(stage)
        }
    }
    return None
}

public func referenceMatchingFullName(
    references: ArrayList<ReferenceStage>,
    namespace: String,
    name: String,
    fullName: String
): Option<ReferenceStage> {
    for (stage in references) {
        if (referenceMatchesFullName(stage, namespace, name, fullName)) {
            return Some(stage)
        }
    }
    return None
}

var activeReferences: ArrayList<ReferenceStage> = ArrayList<ReferenceStage>()

public func setActiveReferences(references: ArrayList<ReferenceStage>): Unit {
    activeReferences = references
}

public func clearActiveReferences(): Unit {
    activeReferences = ArrayList<ReferenceStage>()
}

public func currentReferences(): ArrayList<ReferenceStage> {
    return activeReferences
}

// Namespace-aware rendering context for the nested-package layout.
//
// When set (non-empty `activeRenderNamespace`), every type reference is resolved
// to its short, package-scoped name instead of the globally-flat mangled name:
// a reference to a type in the same namespace renders as the bare short name, and
// a reference to a type in another windows_sys namespace renders as
// `<ns_var>.<short>` -- a package-alias qualified access matching the
// `import windows_sys.<NsPath> as <ns_var>` the writer emits. The short name and
// owning namespace come from the authoritative symbol record (not string-split
// from the full name), so nested types -- whose short name carries the parent
// prefix and whose namespace is the enclosing namespace -- resolve correctly.
//
// Left empty (the default) the renderer keeps the old globally-flat mangled
// names, so the standalone unit tests and non-common generation modes are
// unaffected.
var activeRenderNamespace: String = ""
var activeSymbolsByName: HashMap<String, SymbolRecord> = HashMap<String, SymbolRecord>()

public func setNamespaceAwareRendering(
    namespace: String,
    symbolsByName: HashMap<String, SymbolRecord>
): Unit {
    activeRenderNamespace = namespace
    activeSymbolsByName = symbolsByName
}

public func clearNamespaceAwareRendering(): Unit {
    activeRenderNamespace = ""
    activeSymbolsByName = HashMap<String, SymbolRecord>()
}

public func qualifyMangledFullName(fullName: String): String {
    let mangled = mangleFullName(fullName)
    return qualifyMangledFullName(fullName, mangled)
}

public func qualifyMangledFullName(fullName: String, mangled: String): String {
    if (!activeReferences.isEmpty()) {
        let namespace = namespaceOfFullName(fullName)
        let leafName = leafOfFullName(fullName)
        match (referenceMatchingFullName(activeReferences, namespace, leafName, fullName)) {
            case Some(stage) => return "${stage.name}.${mangled}"
            case None => ()
        }
    }
    if (!activeRenderNamespace.isEmpty()) {
        match (activeSymbolsByName.get(fullName)) {
            case Some(symbol) =>
                if (symbol.namespace == activeRenderNamespace) {
                    // Same-namespace reference: emit the short name. The compiler resolves a
                    // same-named member past the type in type, constructor-call, and
                    // static-access position, so no flat-name fallback is needed.
                    return symbol.name
                }
                return "${namespaceToCfgVar(symbol.namespace)}.${symbol.name}"
            case None => ()
        }
    }
    return mangled
}

func namespaceOfFullName(fullName: String): String {
    let bytes = fullName.toArray()
    var i = Int64(bytes.size) - 1
    while (i >= 0) {
        if (bytes[i] == b'.') {
            return String.fromUtf8(bytes[0..i])
        }
        i -= 1
    }
    return ""
}

func leafOfFullName(fullName: String): String {
    let bytes = fullName.toArray()
    var i = Int64(bytes.size) - 1
    while (i >= 0) {
        if (bytes[i] == b'.') {
            return String.fromUtf8(bytes[(i + 1)..Int64(bytes.size)])
        }
        i -= 1
    }
    return fullName
}
