package windows_bindgen

import std.collection.*

// Flat single-package rendering.
//
// The default (nested) layout shards the selected types into one Cangjie
// subpackage per WinRT/Win32 namespace, so the package tree mirrors the
// namespace hierarchy and cross-namespace references are resolved through
// package-alias imports. Sibling namespaces that reference each other form
// import cycles, which the build tool condenses into one multi-source-package
// compile node — and that node cannot use the compiler's single-source-package
// incremental cache, so any edit forces the whole binding closure to recompile.
//
// Flat mode instead emits every selected type into ONE package (the
// `--package-name` value). With no subpackages there are no cross-package
// import cycles, so the package is an ordinary single-source-package node whose
// declaration-level incremental cache works: editing a consumer file recompiles
// only that file and skips the unchanged bindings entirely.
//
// Flattening collapses the namespace hierarchy, so two types from different
// namespaces that share a short name (e.g. Microsoft.UI.Composition.Visual vs a
// hypothetical Windows.UI.Composition.Visual) would clash. A deterministic
// disambiguation map assigns one canonical bare name per short name and a
// namespace-suffixed name to the rest; every reference is rewritten through the
// map so it points at the intended type.

// Build the full-name -> flat-name map for a flat package.
//
// Grouping is by the package-scoped short name (`symbol.name`, which already
// carries any nested-type prefix). Within a collision group exactly one symbol
// keeps the bare short name (the canonical pick) and the rest receive a
// deterministic `<short>_<namespace-with-underscores>` suffix.
//
// Canonical preference, in order:
//   1. a `Microsoft.UI.*` namespace (the surface the framework actually binds),
//   2. then the shortest namespace,
//   3. then the lexicographically smallest namespace.
// Ties beyond that cannot occur because (short name, namespace) is unique.
//
// A final uniqueness guard catches the pathological case where a suffixed name
// would collide with another group's name and appends a numeric suffix.
func buildFlatNameMap(symbols: ArrayList<SymbolRecord>): HashMap<String, String> {
    // Group full names by short name, preserving deterministic order.
    let groups = HashMap<String, ArrayList<SymbolRecord>>()
    let shortNames = ArrayList<String>()
    for (symbol in symbols) {
        match (groups.get(symbol.name)) {
            case Some(bucket) => bucket.add(symbol)
            case None =>
                let fresh = ArrayList<SymbolRecord>()
                fresh.add(symbol)
                groups.add(symbol.name, fresh)
                shortNames.add(symbol.name)
        }
    }
    sortStrings(shortNames)

    let flatNames = HashMap<String, String>()
    let usedNames = HashSet<String>()
    for (shortName in shortNames) {
        let bucket = match (groups.get(shortName)) {
            case Some(found) => found
            case None => ArrayList<SymbolRecord>()
        }
        if (bucket.size == 1) {
            let symbol = bucket[0]
            let name = uniqueFlatName(shortName, usedNames)
            flatNames.add(symbol.fullName, name)
            usedNames.add(name)
            continue
        }
        // Collision: order the group so the canonical pick is first, then assign
        // bare name to it and suffixed names to the rest.
        let ordered = orderForDisambiguation(bucket)
        var first = true
        for (symbol in ordered) {
            let candidate = if (first) {
                shortName
            } else {
                "${shortName}_${namespaceToCfgVar(symbol.namespace)}"
            }
            let name = uniqueFlatName(candidate, usedNames)
            flatNames.add(symbol.fullName, name)
            usedNames.add(name)
            first = false
        }
    }
    return flatNames
}

// Sort a collision group's symbols so the canonical pick is first. The canonical
// pick prefers a `Microsoft.UI.` namespace, then the shortest namespace, then
// the lexicographically smallest namespace.
func orderForDisambiguation(symbols: ArrayList<SymbolRecord>): ArrayList<SymbolRecord> {
    let ordered = ArrayList<SymbolRecord>()
    for (symbol in symbols) {
        ordered.add(symbol)
    }
    var i: Int64 = 1
    while (i < ordered.size) {
        let value = ordered[i]
        var j = i - 1
        while (j >= 0 && disambiguationRank(value.namespace) < disambiguationRank(ordered[j].namespace)) {
            ordered[j + 1] = ordered[j]
            j -= 1
        }
        ordered[j + 1] = value
        i += 1
    }
    return ordered
}

// Lower rank sorts earlier (more canonical). Encoded as a sortable string:
// "<microsoftFlag>|<paddedLength>|<namespace>". `microsoftFlag` is "0" for a
// `Microsoft.UI.` namespace and "1" otherwise; the padded length orders shorter
// namespaces first; the namespace itself breaks remaining ties.
func disambiguationRank(namespace: String): String {
    let microsoftFlag = if (startsWithString(namespace, "Microsoft.UI.") || namespace == "Microsoft.UI") {
        "0"
    } else {
        "1"
    }
    return "${microsoftFlag}|${padLength(namespace.size)}|${namespace}"
}

func padLength(value: Int64): String {
    var s = "${value}"
    while (s.size < 6) {
        s = "0${s}"
    }
    return s
}

func uniqueFlatName(candidate: String, used: HashSet<String>): String {
    if (!used.contains(candidate)) {
        return candidate
    }
    var index: Int64 = 2
    var result = "${candidate}_${index}"
    while (used.contains(result)) {
        index += 1
        result = "${candidate}_${index}"
    }
    return result
}

// A view of the symbol whose declaration name (`name` and `implName`) is its
// disambiguated flat name. The flat layout emits the declaration directly in the
// single package under this name; references resolve through the flat-name map.
func flatNameSymbol(symbol: SymbolRecord, flatNames: HashMap<String, String>): SymbolRecord {
    let flatName = match (flatNames.get(symbol.fullName)) {
        case Some(found) => found
        case None => symbol.name
    }
    return SymbolRecord(
        symbol.fullName,
        symbol.namespace,
        flatName,
        flatName,
        symbol.dependencies,
        implSource: symbol.implSource,
        metadataToken: symbol.metadataToken,
        typeDef: symbol.typeDef
    )
}

// Render one symbol's impl source for the flat layout: declaration under its
// flat name, every type reference resolved through the flat-name map, no `@When`
// gate (a flat package carries no per-namespace gating).
func renderFlatImplSource(
    symbol: SymbolRecord,
    flatNames: HashMap<String, String>,
    symbolsByName: HashMap<String, SymbolRecord>,
    options: RenderOptions
): String {
    setFlatRendering(flatNames)
    let rendered = renderSymbolImplWithGate(
        flatNameSymbol(symbol, flatNames),
        symbolsByName,
        options,
        TargetAbiOptions.defaults(),
        ""
    )
    clearFlatRendering()
    return rendered
}

// Write the flat single package. Every selected type is emitted into the package
// `packageName`, chunked at 512 declarations into `src/symbols_<i>.cj`; the
// package anchor is `src/mod.cj`. Native P/Invoke helper functions (if any) are
// rendered into `src/native_helpers.cj` in the same package. No subpackages, no
// facade re-exports, no cross-impl imports, no `@When` gating.
func writeFlatPackage(
    writer: GeneratedPackageWriter,
    selected: ArrayList<SymbolRecord>,
    nativeSelected: ArrayList<SymbolRecord>,
    packageName: String,
    selectedByName: HashMap<String, SymbolRecord>,
    nativeSelectedByName: HashMap<String, SymbolRecord>,
    options: RenderOptions,
    common: Bool
): HashMap<String, String> {
    let flatNames = buildFlatNameMap(selected)

    // Stable declaration order: sort by full name so output is deterministic.
    let ordered = ArrayList<SymbolRecord>()
    for (symbol in selected) {
        ordered.add(symbol)
    }
    sortSymbolsByFullName(ordered)

    writer.writeFile("src/mod.cj", "package ${packageName}\n")

    var chunkIndex: Int64 = 0
    var count: Int64 = 0
    var body = ""
    var flags = FlatImportFlags()
    for (symbol in ordered) {
        let rendered = renderFlatImplSource(symbol, flatNames, selectedByName, options)
        scanFlatImportFlags(flags, rendered)
        body += rendered
        body += "\n\n"
        count += 1
        if (count >= 512) {
            writer.writeFile("src/symbols_${chunkIndex}.cj", renderFlatChunk(packageName, body, flags))
            chunkIndex += 1
            count = 0
            body = ""
            flags = FlatImportFlags()
        }
    }
    if (count > 0) {
        writer.writeFile("src/symbols_${chunkIndex}.cj", renderFlatChunk(packageName, body, flags))
    }

    if (common) {
        writeFlatNativeHelpers(writer, nativeSelected, packageName, flatNames, nativeSelectedByName)
    }

    return flatNames
}

class FlatImportFlags {
    public var polyfill: Bool = false
    public var core: Bool = false
    public var libloading: Bool = false
    public var interfacePackage: Bool = false
    public var interfaceGuid: Bool = false
    public var interfaceMacros: Bool = false
    public var strings: Bool = false
}

func scanFlatImportFlags(flags: FlatImportFlags, rendered: String): Unit {
    if (rendered.contains("windows_polyfill.")) {
        flags.polyfill = true
    }
    if (rendered.contains("windows_core.")) {
        flags.core = true
    }
    if (rendered.contains("windows_libloading.")) {
        flags.libloading = true
    }
    if (rendered.contains("windows_interface.")) {
        flags.interfacePackage = true
    }
    if (implChunkNeedsGuidImport(rendered)) {
        flags.interfaceGuid = true
    }
    if (rendered.contains("@Interface[")) {
        flags.interfaceMacros = true
    }
    if (rendered.contains("windows_strings.")) {
        flags.strings = true
    }
}

func renderFlatChunk(packageName: String, body: String, flags: FlatImportFlags): String {
    var content = "package ${packageName}\n\n"
    if (flags.core || flags.interfaceMacros) {
        content += "import windows_core as windows_core\n"
    }
    if (flags.interfaceGuid) {
        content += "import windows_interface.GUID\n"
    }
    if (flags.interfacePackage || flags.interfaceMacros) {
        content += "import windows_interface as windows_interface\n"
    }
    if (flags.interfaceMacros) {
        content += "import windows_interface.IInspectable\n"
        content += "import windows_interface.macros.Interface\n"
    }
    if (flags.polyfill) {
        content += "import windows_polyfill as windows_polyfill\n"
    }
    if (flags.libloading) {
        content += "import windows_libloading as windows_libloading\n"
    }
    if (flags.strings) {
        content += "import windows_strings as windows_strings\n"
    }
    if (flags.core || flags.polyfill || flags.libloading || flags.interfacePackage ||
        flags.interfaceGuid || flags.interfaceMacros || flags.strings) {
        content += "\n"
    }
    content += body
    return content
}

// Render the native P/Invoke helper functions into one flat-package file. The
// helpers reference binding types by their disambiguated flat names (the
// flat-rendering context is active while rendering each function body) and live
// in the same package, so they need NO cross-package import of binding types and
// NO `@When` gate — only the support-package imports their bodies use.
func writeFlatNativeHelpers(
    writer: GeneratedPackageWriter,
    nativeSelected: ArrayList<SymbolRecord>,
    packageName: String,
    flatNames: HashMap<String, String>,
    symbolsByName: HashMap<String, SymbolRecord>
): Unit {
    let specs = ArrayList<NativeFunctionSpec>()
    let seen = HashSet<String>()
    for (spec in appRuntimeNativeFunctionSpecs()) {
        addFlatNativeSpec(specs, seen, spec)
    }
    for (spec in syntheticCommonNativeFunctionSpecs()) {
        addFlatNativeSpec(specs, seen, spec)
    }
    for (spec in nativeFunctionSpecsFromSymbols(nativeSelected)) {
        addFlatNativeSpec(specs, seen, spec)
    }
    if (specs.isEmpty()) {
        return
    }

    setFlatRendering(flatNames)
    var body = ""
    var needsCore = false
    var needsPolyfill = false
    var needsStrings = false
    var needsInterface = false
    var needsGuid = false
    for (spec in specs) {
        let rendered = renderNativeFunction(spec, symbolsByName, "")
        body += rendered + "\n"
        if (rendered.contains("windows_core.")) {
            needsCore = true
        }
        if (rendered.contains("windows_polyfill.")) {
            needsPolyfill = true
        }
        if (rendered.contains("windows_strings.")) {
            needsStrings = true
        }
        if (rendered.contains("windows_interface.GUID") || implChunkNeedsGuidImport(rendered)) {
            needsGuid = true
        }
        if (rendered.contains("windows_interface.")) {
            needsInterface = true
        }
    }
    clearFlatRendering()

    var content = "package ${packageName}\n\n"
    content += "import windows_libloading as windows_libloading\n"
    if (needsCore) {
        content += "import windows_core as windows_core\n"
    }
    if (needsGuid) {
        content += "import windows_interface.GUID\n"
    }
    if (needsInterface) {
        content += "import windows_interface as windows_interface\n"
    }
    if (needsPolyfill) {
        content += "import windows_polyfill as windows_polyfill\n"
    }
    if (needsStrings) {
        content += "import windows_strings as windows_strings\n"
    }
    content += "\n"
    content += body
    writer.writeFile("src/native_helpers.cj", content)
}

func addFlatNativeSpec(
    specs: ArrayList<NativeFunctionSpec>,
    seen: HashSet<String>,
    spec: NativeFunctionSpec
): Unit {
    let key = "${spec.ownerFullName}::${spec.method.name}"
    if (seen.contains(key)) {
        return
    }
    seen.add(key)
    specs.add(spec)
}

// Render the full-name -> flat-name disambiguation map as a JSON object, keyed
// by the metadata full name (e.g. "Microsoft.UI.Xaml.Controls.NumberBox") with
// the declared flat name as the value. Keys are sorted for stable output.
func renderFlatNameMapJson(selected: ArrayList<SymbolRecord>, flatNames: HashMap<String, String>): String {
    let keys = ArrayList<String>()
    for (symbol in selected) {
        keys.add(symbol.fullName)
    }
    sortStrings(keys)
    if (keys.isEmpty()) {
        return "{}\n"
    }
    var content = "{\n"
    var index: Int64 = 0
    while (index < keys.size) {
        let key = keys[index]
        let value = match (flatNames.get(key)) {
            case Some(found) => found
            case None => key
        }
        content += "  \"${jsonEscape(key)}\": \"${jsonEscape(value)}\""
        if (index + 1 < keys.size) {
            content += ","
        }
        content += "\n"
        index += 1
    }
    content += "}\n"
    return content
}
