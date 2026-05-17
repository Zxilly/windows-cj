package windows_targets

import std.unittest.*
import std.unittest.testmacro.*

func targetsTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@Test
func testBundledTargetMetadataIsStable() {
    @Expect(targetsVersion(), "0.53.0")
    @Expect(defaultGnuArchiveName(), "libwindows.0.53.0.a")
}

@Test
func testImportLibTargetMatrixNamesCurrentAndPlannedTargets() {
    let supported = supportedImportLibTargets()
    let planned = plannedImportLibTargets()
    let matrix = importLibTargets()

    @Expect(supported.size, 1)
    @Expect(planned.size, 5)
    @Expect(matrix.size, 6)
    @Expect(supported[0].name, "x86_64_gnu")
    @Expect(planned[0].name, "i686_gnu")
    @Expect(planned[1].name, "aarch64_gnu")
    @Expect(planned[2].name, "x86_64_msvc")
    @Expect(planned[3].name, "i686_msvc")
    @Expect(planned[4].name, "aarch64_msvc")
}

@Test
func testSupportedImportLibTargetCarriesOnlyRealBundledArchive() {
    let target = requireSupportedImportLibTarget("x86_64_gnu")

    @Expect(target.operatingSystem, "Windows")
    @Expect(target.arch, "x86_64")
    @Expect(target.toolchain, "gnu")
    @Expect(target.cangjieEnv, "gnu")
    @Expect(target.archiveDirectory, "x86_64_gnu/lib")
    @Expect(target.supported, true)
    @Expect(target.archiveName.isSome(), true)
    match (target.archiveName) {
        case Some(name) => @Expect(name, defaultGnuArchiveName())
        case None => @Expect(false, true)
    }
}

@Test
func testSupportedTargetExposesArchivePathsAndLinkOptions() {
    let target = requireSupportedImportLibTarget("x86_64_gnu")

    @Expect(target.archiveRelativePath(), Some("x86_64_gnu/lib/libwindows.0.53.0.a"))
    @Expect(target.archivePath("E:/toolchain/windows-targets"), Some("E:/toolchain/windows-targets/x86_64_gnu/lib/libwindows.0.53.0.a"))
    @Expect(importLibArchiveRelativePath(target), Some("x86_64_gnu/lib/libwindows.0.53.0.a"))
    @Expect(importLibArchivePath(target, "E:/toolchain/windows-targets"), Some("E:/toolchain/windows-targets/x86_64_gnu/lib/libwindows.0.53.0.a"))

    match (target.gnuLinkOptions("E:/toolchain/windows-targets")) {
        case Some(options) =>
            @Expect(options.size, 2)
            @Expect(options[0], "-LE:/toolchain/windows-targets/x86_64_gnu/lib")
            @Expect(options[1], "-l:libwindows.0.53.0.a")
        case None => @Expect(false, true)
    }
}

@Test
func testPlannedImportLibTargetsDoNotClaimMissingArchives() {
    for (target in plannedImportLibTargets()) {
        @Expect(target.operatingSystem, "Windows")
        @Expect(target.supported, false)
        @Expect(target.archiveName.isNone(), true)
    }
}

@Test
func testUnsupportedImportLibTargetFailsFast() {
    @Expect(targetsTestThrows({ => let _ = requireSupportedImportLibTarget("aarch64_gnu") }), true)
    @Expect(findSupportedImportLibTarget("aarch64_gnu").isNone(), true)
    @Expect(findSupportedImportLibTarget("x86_64_gnu").isSome(), true)
}

@When[os == "Windows" && arch == "x86_64" && env == "gnu"]
@Test
func testCurrentImportLibTargetResolvesOnSupportedWindowsGnuX64() {
    @Expect(requireCurrentImportLibTarget().name, "x86_64_gnu")
}

@When[os != "Windows" || arch != "x86_64" || env != "gnu"]
@Test
func testCurrentImportLibTargetFailsFastWhenUnsupported() {
    @Expect(targetsTestThrows({ => let _ = requireCurrentImportLibTarget() }), true)
}
