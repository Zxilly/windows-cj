package windows_bindgen

import std.collection.*

// Per-namespace conditional-compilation gating.
//
// Each WinRT/Win32 namespace maps to one Cangjie cfg variable whose name is the
// namespace with '.' replaced by '_' (e.g. "Microsoft.UI.Composition" ->
// "Microsoft_UI_Composition"). The generator decorates every top-level
// declaration it emits into the windows_sys.impl package, and every facade
// re-export, with `@When[<ns_var> == "on"]`. When the variable is "off" (the
// default in the per-package cfg.toml) the declaration is removed during the
// compiler's ConditionalCompilation phase, so it never reaches Semantic / CHIR /
// CodeGen / llc. Consumers opt in to the namespaces they need (mirroring the
// reference projection's per-namespace feature flags), shrinking the otherwise
// monolithic impl package down to only the namespaces actually used.

// The sentinel cfg variable used for symbols whose namespace is empty. Empty
// namespaces are not expected in practice, but the generator stays total.
let ROOT_NAMESPACE_CFG_VAR = "Windows_root"

// Translate a namespace into its cfg variable identifier. Identifiers must be
// valid Cangjie identifiers; '.' is the only separator in namespaces and maps to
// '_'. An empty namespace maps to the root sentinel.
func namespaceToCfgVar(namespace: String): String {
    if (namespace.isEmpty()) {
        return ROOT_NAMESPACE_CFG_VAR
    }
    let bytes = namespace.toArray()
    let out = Array<Byte>(bytes.size, { index =>
        let byte = bytes[index]
        if (byte == b'.') {
            b'_'
        } else {
            byte
        }
    })
    return String.fromUtf8(out)
}

// Render the `@When[<ns_var> == "on"]` decorator line for a namespace.
func cfgGateAnnotation(namespace: String): String {
    return "@When[${namespaceToCfgVar(namespace)} == \"on\"]"
}

// The impl subpackage name for a namespace. The monolithic impl package is split
// into per-namespace subpackages `<packageName>.impl.<ns_var>` so a consumer that
// enables only a few namespaces compiles (and even parses, once cjpm skips the
// disabled subpackages) only those subpackages instead of the whole impl. The
// directory mirrors the package: `src/impl/<ns_var>`.
func implSubpackageName(packageName: String, namespace: String): String {
    return "${packageName}.impl.${namespaceToCfgVar(namespace)}"
}

func implSubpackageDirectory(namespace: String): String {
    return "src/impl/${namespaceToCfgVar(namespace)}"
}

// Render the per-symbol gate prefix (`@When[<ns_var> == "on"]\n`) that the
// symbol renderers structurally prepend at the start of every top-level
// declaration they emit. Computed once per symbol from its namespace and threaded
// into the renderers as a `gate` argument, this replaces the old source-text
// scanner: the gate is emitted at the exact points the declarations are produced,
// so no fragile column-0 line classification is needed and no declaration shape
// (e.g. generic `extend<T>`) can be missed.
//
// An empty `gate` (used by callers that render ungated source, e.g. unit tests)
// prepends nothing, leaving the declaration untouched.
func gatePrefix(namespace: String): String {
    return "${cfgGateAnnotation(namespace)}\n"
}

// Render a cfg.toml body listing each cfg variable defaulting to "off". This is
// the opt-in baseline: with everything off the impl package compiles to (nearly)
// nothing. The feature-selection tool rewrites these values to enable namespaces.
func renderCfgToml(cfgVars: ArrayList<String>): String {
    var content = ""
    for (cfgVar in cfgVars) {
        content += "${cfgVar} = \"off\"\n"
    }
    return content
}

// Collect the full set of cfg variables that any generated declaration in the
// package may reference, sorted. Includes every namespace's variable plus the
// synthetic native-helper namespaces (e.g. Native.AppRuntime) so each package's
// cfg.toml defines them all. An undefined cfg variable in `@When` is a compile
// error, so every package directory carrying gated code must define the complete
// set (extra definitions are harmless).
func collectAllCfgVars(
    symbols: ArrayList<SymbolRecord>,
    extraNamespaces: ArrayList<String>
): ArrayList<String> {
    let vars = ArrayList<String>()
    for (symbol in symbols) {
        addUnique(vars, namespaceToCfgVar(symbol.namespace))
    }
    for (namespace in extraNamespaces) {
        addUnique(vars, namespaceToCfgVar(namespace))
    }
    sortStrings(vars)
    return vars
}

// The directory of a generated file path (everything before the last '/'), or
// "" for a top-level file.
func directoryOfRelativePath(relativePath: String): String {
    let bytes = relativePath.toArray()
    var i = Int64(bytes.size) - 1
    while (i >= 0) {
        if (bytes[i] == b'/') {
            return String.fromUtf8(bytes[0..i])
        }
        i -= 1
    }
    return ""
}

// The package name for a gated source directory (`src/Win32/Foundation` ->
// `windows_sys.Win32.Foundation`, `src/Native/AppRuntime` ->
// `windows_sys.Native.AppRuntime`). The directory layout already encodes the
// namespace (Windows-rooted namespaces have their root stripped by
// namespaceToDirectory), so replacing the `src` segment with the package name and
// '/' with '.' reconstructs the package exactly.
func packageNameForGatedDirectory(directory: String, packageName: String): String {
    let parts = splitString(directory, b'/')
    let rebuilt = ArrayList<String>()
    var index: Int64 = 0
    while (index < Int64(parts.size)) {
        if (index == 0 && parts[index] == "src") {
            rebuilt.add(packageName)
        } else {
            rebuilt.add(parts[index])
        }
        index += 1
    }
    return joinStrings(rebuilt, ".")
}

// Render a one-line source file that establishes an unconditional package-level
// dependency edge from a facade/native-helper package to its impl subpackage.
//
// cjpm derives build order from package imports, but a cross-package import that
// is `@When`-gated is treated as a soft edge: under the package scheduler the
// importing package can be compiled before the impl subpackage (or a sibling
// facade) has produced its `.cjo`, yielding spurious "can not find package"
// failures that only clear on a rebuild. An unconditional package alias import
// (referencing the impl subpackage, not any gated symbol) pins the edge so the
// impl subpackage is always built first, which also stabilises the order of the
// sibling facades the native helpers import. The alias is unused; `-Woff unused`
// suppresses the warning.
//
// After the impl monolith was split into per-namespace subpackages, a facade for
// namespace N edges to its own impl subpackage `<packageName>.impl.<ns_var(N)>`
// rather than the (now-nonexistent) monolithic `<packageName>.impl`. The caller
// supplies the concrete target subpackage for the directory.
func renderImplDependencyEdgeFile(directory: String, packageName: String, implSubpackage: String): String {
    let pkg = packageNameForGatedDirectory(directory, packageName)
    return "package ${pkg}\n\nimport ${implSubpackage} as ${packageName}_impl_edge\n"
}

// Render the cross-impl wildcard imports for namespace N's impl subpackage.
//
// After the split, a symbol in `impl.<ns_var(N)>` that references a symbol in
// namespace M lives in a different package `impl.<ns_var(M)>` and is no longer
// in scope by its bare mangled name. For each M that N depends on (from the same
// namespace-dependency graph that drives namespace-deps.json), emit a gated
// wildcard import of M's impl subpackage. The import is gated on M's cfg
// variable so that when M is disabled the import is removed (it would otherwise
// reference a package whose declarations were all compiled away). Impl symbol
// names are globally-unique mangled names, so the wildcard imports never clash.
// These imports are cyclic across sibling impl subpackages, which the circular
// subpackage compilation support handles.
//
// `deps` is the sorted set of namespaces N depends on (already excludes N
// itself). Self-imports and the root sentinel namespace's own bucket are
// skipped. The output is deterministic because `deps` is pre-sorted.
func renderCrossImplImports(
    packageName: String,
    fromNamespace: String,
    deps: ArrayList<String>
): String {
    var content = ""
    for (toNamespace in deps) {
        if (toNamespace == fromNamespace) {
            continue
        }
        let gateVar = namespaceToCfgVar(toNamespace)
        let target = implSubpackageName(packageName, toNamespace)
        content += "@When[${gateVar} == \"on\"]\n"
        content += "import ${target}.*\n"
    }
    return content
}

// Distinct directories that contain a gated Cangjie source file (any `.cj`
// except the bare `mod.cj` package anchors, which carry no gated declarations
// and therefore reference no cfg variables). Each such directory is a compiled
// package and needs its own cfg.toml defining every cfg variable.
func gatedSourceDirectories(writtenFiles: ArrayList<String>): ArrayList<String> {
    let directories = ArrayList<String>()
    for (relativePath in writtenFiles) {
        if (!endsWithString(relativePath, ".cj")) {
            continue
        }
        if (endsWithString(relativePath, "/mod.cj") || relativePath == "mod.cj") {
            continue
        }
        addUnique(directories, directoryOfRelativePath(relativePath))
    }
    sortStrings(directories)
    return directories
}

// Compute namespace -> namespace dependency edges from the per-symbol dependency
// lists (base types, field types, method projection types, attribute types). The
// result maps each namespace to the sorted set of other namespaces it references.
// A consumer enabling a namespace must also enable this transitive closure; the
// emitted namespace-deps.json lets the selection tool compute it.
func computeNamespaceDependencies(
    symbols: ArrayList<SymbolRecord>,
    symbolsByName: HashMap<String, SymbolRecord>
): HashMap<String, ArrayList<String>> {
    let edges = HashMap<String, ArrayList<String>>()
    for (symbol in symbols) {
        let fromNs = symbol.namespace
        let bucket = match (edges.get(fromNs)) {
            case Some(existing) => existing
            case None =>
                let fresh = ArrayList<String>()
                edges.add(fromNs, fresh)
                fresh
        }
        for (dependency in symbol.dependencies) {
            match (symbolsByName.get(dependency)) {
                case Some(depRecord) =>
                    let toNs = depRecord.namespace
                    if (toNs != fromNs) {
                        addUnique(bucket, toNs)
                    }
                case None => ()
            }
        }
    }
    for ((_, deps) in edges) {
        sortStrings(deps)
    }
    return edges
}

// Augment the namespace dependency edges by scanning each symbol's rendered impl
// source for references to other symbols' mangled type names. The metadata-level
// dependency lists miss references introduced purely by rendering (projected
// collection/invoker helpers, base-type extends, interop glue), so a closure
// computed from them alone can omit edges and break compilation when a namespace
// is enabled without one it actually references at the source level. Scanning the
// emitted code captures exactly what is referenced, making the graph complete.
//
// `implNameToNamespace` maps every native symbol's mangled impl name to its
// namespace. For each symbol, every maximal identifier token in its source is
// looked up; a hit in a different namespace records an edge. The bucket for the
// symbol's own namespace is created so isolated namespaces still appear as keys.
func augmentNamespaceDependenciesFromSource(
    edges: HashMap<String, ArrayList<String>>,
    fromNamespace: String,
    source: String,
    implNameToNamespace: HashMap<String, String>
): Unit {
    let bucket = match (edges.get(fromNamespace)) {
        case Some(existing) => existing
        case None =>
            let fresh = ArrayList<String>()
            edges.add(fromNamespace, fresh)
            fresh
    }
    let bytes = source.toArray()
    let size = Int64(bytes.size)
    var i: Int64 = 0
    while (i < size) {
        if (!isIdentifierByte(bytes[i])) {
            i += 1
            continue
        }
        var j = i + 1
        while (j < size && isIdentifierByte(bytes[j])) {
            j += 1
        }
        let token = String.fromUtf8(bytes[i..j])
        match (implNameToNamespace.get(token)) {
            case Some(toNs) =>
                if (toNs != fromNamespace) {
                    addUnique(bucket, toNs)
                }
            case None => ()
        }
        i = j
    }
}

// Build the mangled-impl-name -> namespace map used by the source scanner. Only
// non-empty impl names are recorded; collisions keep the first (impl names are
// unique by construction).
func buildImplNameToNamespace(symbols: ArrayList<SymbolRecord>): HashMap<String, String> {
    let map = HashMap<String, String>()
    for (symbol in symbols) {
        if (!symbol.implName.isEmpty() && !map.contains(symbol.implName)) {
            map.add(symbol.implName, symbol.namespace)
        }
    }
    return map
}

// Sort every dependency bucket in place (call after augmentation).
func sortNamespaceDependencyBuckets(edges: HashMap<String, ArrayList<String>>): Unit {
    for ((_, deps) in edges) {
        sortStrings(deps)
    }
}

// Render the subpackage -> cfg-variable map as deterministic JSON. This is the
// build tool's source of truth for which compiled subpackages are gated by which
// cfg variable, so it can skip parsing the subpackages whose variable is "off".
// It covers every per-namespace impl subpackage (`<packageName>.impl.<ns_var>`)
// and every facade subpackage (`<packageName>.<Ns...>`), each mapped to its cfg
// variable. Keys are sorted for stable output.
//
// `subpackageToCfgVar` is the full mapping; the root package name itself (a
// facade with no namespace parts) is excluded by the caller because it carries no
// gated declarations.
func renderSubpackageNamespacesJson(
    rootPackageName: String,
    subpackageToCfgVar: HashMap<String, String>
): String {
    let keys = ArrayList<String>()
    for ((subpackage, _) in subpackageToCfgVar) {
        keys.add(subpackage)
    }
    sortStrings(keys)
    var content = "{\n"
    content += "  \"package\": \"${jsonEscape(rootPackageName)}\",\n"
    content += "  \"gated_subpackages\": {"
    if (keys.isEmpty()) {
        content += "}\n}\n"
        return content
    }
    content += "\n"
    var index: Int64 = 0
    while (index < Int64(keys.size)) {
        let key = keys[index]
        let cfgVar = match (subpackageToCfgVar.get(key)) {
            case Some(found) => found
            case None => ""
        }
        content += "    \"${jsonEscape(key)}\": \"${jsonEscape(cfgVar)}\""
        if (index + 1 < Int64(keys.size)) {
            content += ","
        }
        content += "\n"
        index += 1
    }
    content += "  }\n}\n"
    return content
}

// Render the namespace dependency map as deterministic JSON:
//   { "Namespace.A": ["Namespace.B", "Namespace.C"], ... }
// Keys and value arrays are sorted so output is stable across runs.
func renderNamespaceDepsJson(edges: HashMap<String, ArrayList<String>>): String {
    let keys = ArrayList<String>()
    for ((ns, _) in edges) {
        keys.add(ns)
    }
    sortStrings(keys)
    if (keys.isEmpty()) {
        return "{}\n"
    }
    var content = "{\n"
    var index: Int64 = 0
    while (index < Int64(keys.size)) {
        let key = keys[index]
        let deps = match (edges.get(key)) {
            case Some(found) => found
            case None => ArrayList<String>()
        }
        content += "  \"${jsonEscape(key)}\": ${jsonStringArray(deps)}"
        if (index + 1 < Int64(keys.size)) {
            content += ","
        }
        content += "\n"
        index += 1
    }
    content += "}\n"
    return content
}
