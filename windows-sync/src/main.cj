package windows_sync

import std.fs.*
import std.env.*

// Error types for better error reporting
enum SyncError {
    | FileNotFound(String)
    | InvalidManifest(String)
    | CatalogMissing(String)
    | InvalidCatalogRoot(String)
    | CyclicDependency(String)
    | InvalidConfiguration(String)
    | IoError(String)
}

func errorMessage(err: SyncError): String {
    match (err) {
        case FileNotFound(path) => "file not found: ${path}"
        case InvalidManifest(reason) => "invalid manifest: ${reason}"
        case CatalogMissing(path) => "catalog files missing in: ${path}"
        case InvalidCatalogRoot(reason) => "invalid catalog root: ${reason}"
        case CyclicDependency(feature) => "cyclic feature dependency detected: ${feature}"
        case InvalidConfiguration(reason) => "invalid configuration: ${reason}"
        case IoError(msg) => "I/O error: ${msg}"
    }
}

main(args: Array<String>) {
    let invocation = parseInvocation(args)
    if (invocation.help) {
        printHelp()
        return
    }
    if (!invocation.valid) {
        printHelp()
        return
    }
    if (invocation.command.isEmpty()) {
        runSync(args)
        return
    }

    if (invocation.command != "sync") {
        printHelp()
        return
    }

    runSync(args)
}

func runSync(args: Array<String>): Unit {
    let workspaceRoot = resolveWorkspaceRoot(args)
    let catalogRoot = resolveCatalogRoot(args, workspaceRoot)

    let manifestPath = joinPath(workspaceRoot, "cjpm.toml")
    let featureManifestPath = joinPath(catalogRoot, "features.toml")
    let linkManifestPath = joinPath(catalogRoot, "link-options.toml")
    let cfgPath = joinPath(workspaceRoot, "windows-cj/cfg.toml")

    let workspace = readWorkspaceManifest(manifestPath)
    let catalog = readFeatureCatalog(featureManifestPath, linkManifestPath)
    let resolved = resolveFeatureClosure(workspace.enabledFeatures, catalog)
    writeCfg(cfgPath, resolved)

    let linkOptions = formatLinkOptions(resolved)
    if (!linkOptions.isEmpty()) {
        println(linkOptions)
    }
}

func printHelp(): Unit {
    println("windows-sync: generate windows-cj/cfg.toml from cjpm.toml")
    println("usage: windows-sync [sync] [--workspace-root <path>] [--catalog-root <path>]")
    println("--catalog-root points to the directory that contains features.toml and link-options.toml")
}

func resolveWorkspaceRoot(args: Array<String>): String {
    let invocation = parseInvocation(args)
    if (!invocation.workspaceRoot.isEmpty()) {
        return invocation.workspaceRoot
    }
    return discoverWorkspaceRoot()
}

public class Invocation {
    public var valid: Bool = true
    public var help: Bool = false
    public var command: String = ""
    public var workspaceRoot: String = ""
    public var catalogRoot: String = ""

    public init() {}
}

func resolveCatalogRoot(args: Array<String>, workspaceRoot: String): String {
    let invocation = parseInvocation(args)
    if (!invocation.catalogRoot.isEmpty()) {
        validateCatalogRoot(invocation.catalogRoot)
        return invocation.catalogRoot
    }
    let defaultCatalogRoot = joinPath(workspaceRoot, "windows-cj")
    validateCatalogRoot(defaultCatalogRoot)
    return defaultCatalogRoot
}

func parseInvocation(args: Array<String>): Invocation {
    let invocation = Invocation()
    var i: Int64 = 0
    var commandSeen = false
    while (i < Int64(args.size)) {
        let arg = args[i]
        if (arg == "-h" || arg == "--help") {
            invocation.help = true
            i += 1
            continue
        }
        if (arg == "sync") {
            if (commandSeen) {
                invocation.valid = false
                return invocation
            }
            invocation.command = arg
            commandSeen = true
            i += 1
            continue
        }
        if (arg == "--workspace-root" || arg == "--catalog-root") {
            if ((i + 1) >= Int64(args.size)) {
                invocation.valid = false
                return invocation
            }
            let value = args[i + 1]
            if (isOptionToken(value)) {
                invocation.valid = false
                return invocation
            }
            if (arg == "--workspace-root") {
                invocation.workspaceRoot = value
            } else {
                invocation.catalogRoot = value
            }
            i += 2
            continue
        }
        if (startsWith(arg, "--")) {
            invocation.valid = false
            return invocation
        }
        if (!commandSeen && invocation.command.isEmpty()) {
            invocation.valid = false
            return invocation
        }
        invocation.valid = false
        return invocation
    }
    return invocation
}

func isOptionToken(token: String): Bool {
    return token == "-h" || token == "--help" || startsWith(token, "--")
}

func discoverWorkspaceRoot(): String {
    let startDir = getWorkingDirectory().toString()
    var dir = startDir
    while (!dir.isEmpty()) {
        let manifestPath = joinPath(dir, "cjpm.toml")
        if (exists(manifestPath)) {
            if (isWorkspaceManifest(manifestPath)) {
                return dir
            }
        }

        let parent = parentDir(dir)
        if (parent == dir) {
            break
        }
        dir = parent
    }
    throw Exception(errorMessage(FileNotFound("workspace root not found from ${startDir}")))
}

func validateCatalogRoot(catalogRoot: String): Unit {
    let featuresPath = joinPath(catalogRoot, "features.toml")
    let linkOptionsPath = joinPath(catalogRoot, "link-options.toml")
    if (!exists(featuresPath)) {
        throw Exception(errorMessage(InvalidCatalogRoot("features.toml not found at ${featuresPath}")))
    }
    if (!exists(linkOptionsPath)) {
        throw Exception(errorMessage(InvalidCatalogRoot("link-options.toml not found at ${linkOptionsPath}")))
    }
}

func parentDir(path: String): String {
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

func isWorkspaceManifest(path: String): Bool {
    let text = readText(path)
    for (rawLine in splitLines(text)) {
        if (trimAscii(rawLine) == "[workspace]") {
            return true
        }
    }
    return false
}
