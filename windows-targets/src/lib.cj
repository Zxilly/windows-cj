package windows_targets

private let bundledVersion = "0.53.0"
private let bundledGnuArchive = "libwindows.0.53.0.a"

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

    public func archivePath(root: String): Option<String> {
        match (archiveRelativePath()) {
            case Some(relative) => Some("${root}/${relative}")
            case None => None
        }
    }

    public func gnuLinkOptions(root: String): Option<Array<String>> {
        match (archiveName) {
            case Some(name) => Some(["-L${root}/${archiveDirectory}", "-l:${name}"])
            case None => None
        }
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

public func plannedImportLibTargets(): Array<ImportLibTarget> {
    [
        importLibTarget("i686_gnu", "i686", "gnu", "gnu", "i686_gnu/lib", None, false),
        importLibTarget("aarch64_gnu", "aarch64", "gnu", "gnu", "aarch64_gnu/lib", None, false),
        importLibTarget("x86_64_msvc", "x86_64", "msvc", "", "x86_64_msvc/lib", None, false),
        importLibTarget("i686_msvc", "i686", "msvc", "", "i686_msvc/lib", None, false),
        importLibTarget("aarch64_msvc", "aarch64", "msvc", "", "aarch64_msvc/lib", None, false)
    ]
}

public func importLibTargets(): Array<ImportLibTarget> {
    [
        supportedImportLibTargets()[0],
        plannedImportLibTargets()[0],
        plannedImportLibTargets()[1],
        plannedImportLibTargets()[2],
        plannedImportLibTargets()[3],
        plannedImportLibTargets()[4]
    ]
}

public func requireSupportedImportLibTarget(name: String): ImportLibTarget {
    for (target in supportedImportLibTargets()) {
        if (target.name == name) {
            return target
        }
    }
    throw Exception("unsupported windows-targets import library target: ${name}")
}

public func findSupportedImportLibTarget(name: String): Option<ImportLibTarget> {
    for (target in supportedImportLibTargets()) {
        if (target.name == name) {
            return Some(target)
        }
    }
    None
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
        case None => throw Exception("windows-targets only bundles import libraries for x86_64 Windows GNU")
    }
}
