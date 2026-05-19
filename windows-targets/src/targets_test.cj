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

func captureUnsupportedTarget(action: () -> Unit): Option<UnsupportedTarget> {
    try {
        action()
    } catch (error: UnsupportedTarget) {
        return Some(error)
    } catch (_: Exception) {
        return None
    }
    None
}

func expectUnsupportedTarget(name: String, reason: String, action: () -> Unit): Unit {
    match (captureUnsupportedTarget(action)) {
        case Some(error) =>
            @Expect(error.targetName, name)
            @Expect(error.reason, reason)
            @Expect(error.message, "unsupported windows-targets import library target `${name}`: ${reason}")
        case None => @Expect(false, true)
    }
}

@Test
func testBundledTargetMetadataIsStable() {
    @Expect(targetsVersion(), "0.53.0")
    @Expect(defaultGnuArchiveName(), "libwindows.0.53.0.a")
}

@Test
func testImportLibTargetMatrixNamesSupportedAndUnsupportedTargets() {
    let supported = supportedImportLibTargets()
    let unsupported = unsupportedImportLibTargets()
    let matrix = importLibTargets()

    @Expect(supported.size, 1)
    @Expect(unsupported.size, 5)
    @Expect(matrix.size, 6)
    @Expect(supported[0].name, "x86_64_gnu")
    @Expect(unsupported[0].name, "i686_gnu")
    @Expect(unsupported[1].name, "aarch64_gnu")
    @Expect(unsupported[2].name, "x86_64_msvc")
    @Expect(unsupported[3].name, "i686_msvc")
    @Expect(unsupported[4].name, "aarch64_msvc")
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
    @Expect(target.status(), "supported")
    @Expect(target.unsupportedReason(), None)
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
    @Expect(target.requireArchiveRelativePath(), "x86_64_gnu/lib/libwindows.0.53.0.a")
    @Expect(target.archivePath("E:/toolchain/windows-targets"), Some("E:/toolchain/windows-targets/x86_64_gnu/lib/libwindows.0.53.0.a"))
    @Expect(target.requireArchivePath("E:/toolchain/windows-targets"), "E:/toolchain/windows-targets/x86_64_gnu/lib/libwindows.0.53.0.a")
    @Expect(importLibArchiveRelativePath(target), Some("x86_64_gnu/lib/libwindows.0.53.0.a"))
    @Expect(requireImportLibArchiveRelativePath(target), "x86_64_gnu/lib/libwindows.0.53.0.a")
    @Expect(importLibArchivePath(target, "E:/toolchain/windows-targets"), Some("E:/toolchain/windows-targets/x86_64_gnu/lib/libwindows.0.53.0.a"))
    @Expect(requireImportLibArchivePath(target, "E:/toolchain/windows-targets"), "E:/toolchain/windows-targets/x86_64_gnu/lib/libwindows.0.53.0.a")

    match (target.gnuLinkOptions("E:/toolchain/windows-targets")) {
        case Some(options) =>
            @Expect(options.size, 2)
            @Expect(options[0], "-LE:/toolchain/windows-targets/x86_64_gnu/lib")
            @Expect(options[1], "-l:libwindows.0.53.0.a")
        case None => @Expect(false, true)
    }

    let requiredOptions = target.requireGnuLinkOptions("E:/toolchain/windows-targets")
    @Expect(requiredOptions.size, 2)
    @Expect(requiredOptions[0], "-LE:/toolchain/windows-targets/x86_64_gnu/lib")
    @Expect(requiredOptions[1], "-l:libwindows.0.53.0.a")

    let helperOptions = requireImportLibGnuLinkOptions(target, "E:/toolchain/windows-targets")
    @Expect(helperOptions.size, 2)
    @Expect(helperOptions[0], "-LE:/toolchain/windows-targets/x86_64_gnu/lib")
    @Expect(helperOptions[1], "-l:libwindows.0.53.0.a")
}

@Test
func testUnsupportedImportLibTargetsDoNotClaimMissingArchives() {
    for (target in unsupportedImportLibTargets()) {
        @Expect(target.operatingSystem, "Windows")
        @Expect(target.supported, false)
        @Expect(target.status(), "unsupported")
        @Expect(target.archiveName.isNone(), true)
        @Expect(target.archiveRelativePath(), None)
        @Expect(target.archivePath("E:/toolchain/windows-targets"), None)
        @Expect(target.gnuLinkOptions("E:/toolchain/windows-targets"), None)
        @Expect(target.unsupportedReason().isSome(), true)
    }
}

@Test
func testKnownUnsupportedTargetCanBeInspectedButNotRequiredAsSupported() {
    let target = requireImportLibTarget("i686_gnu")

    @Expect(target.name, "i686_gnu")
    @Expect(target.arch, "i686")
    @Expect(target.toolchain, "gnu")
    @Expect(target.supported, false)
    @Expect(findImportLibTarget("i686_gnu").isSome(), true)
    @Expect(findSupportedImportLibTarget("i686_gnu").isNone(), true)
    @Expect(findSupportedImportLibTarget("x86_64_gnu").isSome(), true)
}

@Test
func testUnsupportedImportLibTargetFailsWithTypedReason() {
    let target = requireImportLibTarget("aarch64_gnu")
    let reason = "no bundled import library payload exists under aarch64_gnu/lib"

    expectUnsupportedTarget("aarch64_gnu", reason, { => let _ = requireSupportedImportLibTarget("aarch64_gnu") })
    expectUnsupportedTarget("aarch64_gnu", reason, { => let _ = target.requireArchiveRelativePath() })
    expectUnsupportedTarget("aarch64_gnu", reason, { => let _ = target.requireArchivePath("E:/toolchain/windows-targets") })
    expectUnsupportedTarget("aarch64_gnu", reason, { => let _ = target.requireGnuLinkOptions("E:/toolchain/windows-targets") })
}

@Test
func testUnknownImportLibTargetFailsWithTypedReason() {
    let reason = "target is not part of the windows-targets import library matrix"

    @Expect(findImportLibTarget("arm64ec_msvc").isNone(), true)
    @Expect(findSupportedImportLibTarget("arm64ec_msvc").isNone(), true)
    expectUnsupportedTarget("arm64ec_msvc", reason, { => let _ = requireImportLibTarget("arm64ec_msvc") })
    expectUnsupportedTarget("arm64ec_msvc", reason, { => let _ = requireSupportedImportLibTarget("arm64ec_msvc") })
}

@When[os == "Windows" && arch == "x86_64" && env == "gnu"]
@Test
func testCurrentImportLibTargetResolvesOnSupportedWindowsGnuX64() {
    @Expect(requireCurrentImportLibTarget().name, "x86_64_gnu")
}

@When[os != "Windows" || arch != "x86_64" || env != "gnu"]
@Test
func testCurrentImportLibTargetFailsFastWhenUnsupported() {
    expectUnsupportedTarget(
        "current",
        "windows-targets only bundles import libraries for x86_64 Windows GNU",
        { => let _ = requireCurrentImportLibTarget() }
    )
    @Expect(targetsTestThrows({ => let _ = requireCurrentImportLibTarget() }), true)
}
