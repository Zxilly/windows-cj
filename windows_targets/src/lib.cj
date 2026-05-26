package windows_targets

private let bundledVersion = "0.53.0"
private let bundledGnuArchive = "libwindows.0.53.0.a"

public class UnsupportedTarget <: Exception {
    public let targetName: String
    public let reason: String

    public init(targetName: String, reason: String) {
        super("unsupported windows_targets import library target `${targetName}`: ${reason}")
        this.targetName = targetName
        this.reason = reason
    }
}

public struct ImportLibTarget {
    public let name: String
    public let operatingSystem: String
    public let arch: String
    public let toolchain: String
    public let cangjieEnv: String
    public let archiveDirectory: String
    public let archiveName: Option<String>
    public let supported: Bool

    public init(
        name: String,
        operatingSystem: String,
        arch: String,
        toolchain: String,
        cangjieEnv: String,
        archiveDirectory: String,
        archiveName: Option<String>,
        supported: Bool
    ) {
        this.name = name
        this.operatingSystem = operatingSystem
        this.arch = arch
        this.toolchain = toolchain
        this.cangjieEnv = cangjieEnv
        this.archiveDirectory = archiveDirectory
        this.archiveName = archiveName
        this.supported = supported
    }

    public func archiveRelativePath(): Option<String> {
        match (archiveName) {
            case Some(name) => Some("${archiveDirectory}/${name}")
            case None => None
        }
    }

    public func requireArchiveRelativePath(): String {
        match (archiveRelativePath()) {
            case Some(relative) => relative
            case None => throw unsupportedTarget(name)
        }
    }

    public func archivePath(root: String): Option<String> {
        match (archiveRelativePath()) {
            case Some(relative) => Some("${root}/${relative}")
            case None => None
        }
    }

    public func requireArchivePath(root: String): String {
        "${root}/${requireArchiveRelativePath()}"
    }

    public func gnuLinkOptions(root: String): Option<Array<String>> {
        if (toolchain != "gnu") {
            return None
        }
        match (archiveName) {
            case Some(name) => Some(["-L${root}/${archiveDirectory}", "-l:${name}"])
            case None => None
        }
    }

    public func requireGnuLinkOptions(root: String): Array<String> {
        if (!supported) {
            throw unsupportedTarget(name)
        }
        if (toolchain != "gnu") {
            throw UnsupportedTarget(name, "GNU linker options are not valid for ${toolchain} targets")
        }
        match (gnuLinkOptions(root)) {
            case Some(options) => options
            case None => throw unsupportedTarget(name)
        }
    }

    public func status(): String {
        if (supported) {
            return "supported"
        }
        "unsupported"
    }

    public func unsupportedReason(): Option<String> {
        if (supported) {
            return None
        }
        Some(unsupportedReasonForName(name))
    }
}

private func importLibTarget(
    name: String,
    arch: String,
    toolchain: String,
    cangjieEnv: String,
    archiveDirectory: String,
    archiveName: Option<String>,
    supported: Bool
): ImportLibTarget {
    ImportLibTarget(name, "Windows", arch, toolchain, cangjieEnv, archiveDirectory, archiveName, supported)
}

private func unsupportedReasonForName(name: String): String {
    if (name == "i686_gnu") {
        return "no bundled import library payload exists under i686_gnu/lib"
    }
    if (name == "aarch64_gnu") {
        return "no bundled import library payload exists under aarch64_gnu/lib"
    }
    if (name == "x86_64_msvc") {
        return "no bundled MSVC import library payload exists under x86_64_msvc/lib"
    }
    if (name == "i686_msvc") {
        return "no bundled MSVC import library payload exists under i686_msvc/lib"
    }
    if (name == "aarch64_msvc") {
        return "no bundled MSVC import library payload exists under aarch64_msvc/lib"
    }
    "target is not part of the windows_targets import library matrix"
}

private func unsupportedTarget(name: String): UnsupportedTarget {
    UnsupportedTarget(name, unsupportedReasonForName(name))
}

public func targetsVersion(): String {
    bundledVersion
}

public func defaultGnuArchiveName(): String {
    bundledGnuArchive
}

public func supportedImportLibTargets(): Array<ImportLibTarget> {
    [
        importLibTarget("x86_64_gnu", "x86_64", "gnu", "gnu", "x86_64_gnu/lib", Some(bundledGnuArchive), true)
    ]
}

public func unsupportedImportLibTargets(): Array<ImportLibTarget> {
    [
        importLibTarget("i686_gnu", "i686", "gnu", "gnu", "i686_gnu/lib", None, false),
        importLibTarget("aarch64_gnu", "aarch64", "gnu", "gnu", "aarch64_gnu/lib", None, false),
        importLibTarget("x86_64_msvc", "x86_64", "msvc", "", "x86_64_msvc/lib", None, false),
        importLibTarget("i686_msvc", "i686", "msvc", "", "i686_msvc/lib", None, false),
        importLibTarget("aarch64_msvc", "aarch64", "msvc", "", "aarch64_msvc/lib", None, false)
    ]
}

public func importLibTargets(): Array<ImportLibTarget> {
    let supported = supportedImportLibTargets()
    let unsupported = unsupportedImportLibTargets()
    [
        supported[0],
        unsupported[0],
        unsupported[1],
        unsupported[2],
        unsupported[3],
        unsupported[4]
    ]
}

public func findImportLibTarget(name: String): Option<ImportLibTarget> {
    for (target in importLibTargets()) {
        if (target.name == name) {
            return Some(target)
        }
    }
    None
}

public func requireImportLibTarget(name: String): ImportLibTarget {
    match (findImportLibTarget(name)) {
        case Some(target) => target
        case None => throw unsupportedTarget(name)
    }
}

public func requireSupportedImportLibTarget(name: String): ImportLibTarget {
    match (findImportLibTarget(name)) {
        case Some(target) =>
            if (target.supported) {
                return target
            }
            throw unsupportedTarget(name)
        case None => throw unsupportedTarget(name)
    }
}

public func requireImportLibArchiveRelativePath(target: ImportLibTarget): String {
    target.requireArchiveRelativePath()
}

public func requireImportLibArchivePath(target: ImportLibTarget, root: String): String {
    target.requireArchivePath(root)
}

public func requireImportLibGnuLinkOptions(target: ImportLibTarget, root: String): Array<String> {
    target.requireGnuLinkOptions(root)
}

public func findSupportedImportLibTarget(name: String): Option<ImportLibTarget> {
    match (findImportLibTarget(name)) {
        case Some(target) =>
            if (target.supported) {
                return Some(target)
            }
            None
        case None => None
    }
}

public func importLibArchiveRelativePath(target: ImportLibTarget): Option<String> {
    target.archiveRelativePath()
}

public func importLibArchivePath(target: ImportLibTarget, root: String): Option<String> {
    target.archivePath(root)
}

public func importLibGnuLinkOptions(target: ImportLibTarget, root: String): Option<Array<String>> {
    target.gnuLinkOptions(root)
}

@When[os == "Windows" && arch == "x86_64" && env == "gnu"]
public func currentImportLibTargetName(): Option<String> {
    Some("x86_64_gnu")
}

@When[os != "Windows" || arch != "x86_64" || env != "gnu"]
public func currentImportLibTargetName(): Option<String> {
    None
}

public func requireCurrentImportLibTarget(): ImportLibTarget {
    match (currentImportLibTargetName()) {
        case Some(name) => requireSupportedImportLibTarget(name)
        case None => throw UnsupportedTarget(
            "current",
            "windows_targets only bundles import libraries for x86_64 Windows GNU"
        )
    }
}
