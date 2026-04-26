package windows_targets

private let bundledVersion = "0.53.0"
private let bundledGnuArchive = "libwindows.0.53.0.a"

public func targetsVersion(): String {
    bundledVersion
}

public func defaultGnuArchiveName(): String {
    bundledGnuArchive
}
