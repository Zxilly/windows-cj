package windows_bindgen

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testParseArgsDefaultsAndDeduplicatesFeatures() {
    let defaults = parseArgs(["--input-json", "metadata.json"])
    let repeated = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Windows.Foundation",
        "--feature", "Windows.Foundation"
    ])

    @Expect(defaults.features.size, 1)
    @Expect(defaults.features[0], "all")
    @Expect(defaults.packageName, "windows")
    @Expect(defaults.inputJsonPaths[0], "metadata.json")
    @Expect(defaults.outputDir, ".generated/windows")
    @Expect(repeated.features.size, 1)
    @Expect(repeated.features[0], "Windows.Foundation")
}

@Test
func testParseArgsAcceptsInputDir() {
    let config = parseArgs(["--input-dir", ".generated/winmd-json", "--feature", "Windows.Foundation"])

    @Expect(config.inputJsonDirs.size, 1)
    @Expect(config.inputJsonDirs[0], ".generated/winmd-json")
    @Expect(config.inputJsonPaths.isEmpty(), true)
}

@Test
func testParseArgsAcceptsPositionalJsonAndJsonDir() {
    let dir = ".generated/cli-json-input-test"
    removeIfExists(dir, recursive: true)
    Directory.create(dir, recursive: true)
    File.writeTo("${dir}/metadata.json", "{}".toArray())

    let config = parseArgs(["metadata.json", dir, "--feature", "Windows.Foundation"])
    removeIfExists(dir, recursive: true)

    @Expect(config.inputJsonPaths.size, 1)
    @Expect(config.inputJsonPaths[0], "metadata.json")
    @Expect(config.inputJsonDirs.size, 1)
    @Expect(config.inputJsonDirs[0], dir)
    @Expect(config.inputWinmdPaths.isEmpty(), true)
    @Expect(config.inputWinmdDirs.isEmpty(), true)
}

@Test
func testParseArgsRecognizesWinmdInputsAndDefault() {
    let dir = ".generated/cli-winmd-input-test"
    removeIfExists(dir, recursive: true)
    Directory.create(dir, recursive: true)
    File.writeTo("${dir}/Windows.winmd", "".toArray())

    let config = parseArgs(["default", "Sample.winmd", dir])
    removeIfExists(dir, recursive: true)

    @Expect(config.defaultWinmdInput, true)
    @Expect(config.inputWinmdPaths.size, 1)
    @Expect(config.inputWinmdPaths[0], "Sample.winmd")
    @Expect(config.inputWinmdDirs.size, 1)
    @Expect(config.inputWinmdDirs[0], dir)
}

@Test
func testParseArgsPrefersWinmdDirectoryWithAuxiliaryJson() {
    let dir = ".generated/cli-mixed-winmd-input-test"
    removeIfExists(dir, recursive: true)
    Directory.create(dir, recursive: true)
    File.writeTo("${dir}/Windows.winmd", "".toArray())
    File.writeTo("${dir}/winmd-source-hashes.json", "{}".toArray())

    let config = parseArgs([dir, "--feature", "Windows.Foundation"])
    removeIfExists(dir, recursive: true)

    @Expect(config.inputWinmdDirs.size, 1)
    @Expect(config.inputWinmdDirs[0], dir)
    @Expect(config.inputJsonDirs.isEmpty(), true)
}

@Test
func testFindDefaultWinmdDirectoryChecksCandidateRoots() {
    let dir = ".generated/cli-default-winmd-input-test"
    removeIfExists(dir, recursive: true)
    Directory.create(dir, recursive: true)
    File.writeTo("${dir}/Windows.winmd", "".toArray())
    File.writeTo("${dir}/winmd-source-hashes.json", "{}".toArray())

    let candidates = ArrayList<String>()
    candidates.add(".generated/missing-default-winmd-input-test")
    candidates.add(dir)
    var selected = ""
    match (findDefaultWinmdDirectory(candidates)) {
        case Some(found) => selected = found
        case None => selected = ""
    }
    removeIfExists(dir, recursive: true)

    @Expect(selected, dir)
}

@Test
func testDefaultWinmdInputErrorMentionsEmbeddedResourceFallback() {
    let candidates = ArrayList<String>()
    candidates.add("missing-a")
    candidates.add("missing-b")

    let message = defaultWinmdInputError(candidates)

    @Expect(message.contains("embedded WinMD resources were not linked"), true)
    @Expect(message.contains("missing-a, missing-b"), true)
}

@Test
func testWinmdPositionalInputsAreAcceptedForNativeParsing() {
    let config = parseArgs([
        "default",
        "Sample.winmd"
    ])

    @Expect(config.defaultWinmdInput, true)
    @Expect(config.inputWinmdPaths.size, 1)
    @Expect(config.inputWinmdPaths[0], "Sample.winmd")
    @Expect(cliTestThrows({ => validateMetadataInputs(config) }), false)
}

@Test
func testLoadSymbolRecordsParsesBundledWinmdNatively() {
    // A real bundled .winmd is parsed via the native reader
    // (loadWinmdFilesNative) and produces SymbolRecords. Skipped gracefully if
    // the bundled metadata is not present in this checkout.
    let winmd = "../winmd/Windows.Wdk.winmd"
    if (cliTestThrows({ => let _ = File.readFrom(winmd) })) {
        return
    }
    let config = parseArgs([winmd, "--feature", "Windows.Wdk.Devices.Bluetooth"])

    let records = loadSymbolRecords(config)
    @Expect(records.isEmpty(), false)

    var found = false
    for (record in records) {
        if (record.fullName == "Windows.Wdk.Devices.Bluetooth.Apis") {
            found = true
            break
        }
    }
    @Expect(found, true)
}

@Test
func testLoadSymbolRecordsParsesWinmdInputsNativelyWithoutConverter() {
    // A positional .winmd is parsed natively. A missing file fails inside the
    // native reader, proving the native path is taken.
    let directMessage = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs(["Sample.winmd"])) })
    // --input-json still expects already-converted JSON, never a raw .winmd.
    let jsonFlagMessage = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs(["--input-json", "Sample.WINMD"])) })

    @Expect(directMessage.contains("failed to read winmd file"), true)
    @Expect(directMessage.contains("requires an explicit converter"), false)
    @Expect(jsonFlagMessage.contains("--input-json expects converted JSON"), true)
    @Expect(jsonFlagMessage.contains("parse it natively"), true)
}

@Test
func testInputDirWithWinmdOnlyDirectoryIsParsedNatively() {
    // A directory holding only .winmd files (here an empty placeholder) is
    // routed to the native reader. The empty file fails to parse, confirming the
    // native path was taken.
    let dir = ".generated/cli-winmd-dir-test"
    removeIfExists(dir, recursive: true)
    Directory.create(dir, recursive: true)
    File.writeTo("${dir}/Windows.winmd", "".toArray())

    let message = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs(["--input-dir", dir])) })
    removeIfExists(dir, recursive: true)

    @Expect(message.contains("failed to read winmd file"), true)
    @Expect(message.contains("requires an explicit converter"), false)
}

@Test
func testLoadSymbolRecordsRejectsMissingInputWithDefaultWorkflow() {
    let message = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs([])) })

    @Expect(message.contains("no metadata input provided"), true)
    @Expect(message.contains("windows_bindgen default --feature"), true)
}

@Test
func testUsageTextDocumentsJsonAndWinmdWorkflow() {
    let help = usageText()

    @Expect(help.contains("metadata.json | json-dir | default | metadata.winmd | winmd-dir"), true)
    @Expect(help.contains("--winmd-to-json"), false)
    @Expect(help.contains("Parsed natively by the built-in Cangjie .winmd reader"), true)
    @Expect(help.contains("embedded WinMD resources"), true)
}

@Test
func testParseArgsAcceptsFiltersWithoutDefaultAllFeature() {
    let config = parseArgs([
        "--input-json", "metadata.json",
        "--filter", "Widget",
        "--filter", "!Hidden"
    ])

    @Expect(config.features.isEmpty(), true)
    @Expect(config.filters.size, 2)
    @Expect(config.filters[0], "Widget")
    @Expect(config.filters[1], "!Hidden")
}

@Test
func testParseArgsPrintLinkOptionsFlag() {
    let config = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Windows.Foundation",
        "--print-link-options"
    ])

    @Expect(config.printLinkOptions, true)
    @Expect(config.features.size, 1)
    @Expect(config.features[0], "Windows.Foundation")
}

@Test
func testParseArgsCommonModeDefaultsOutputAndFeatures() {
    let config = parseArgs(["--input-json", "metadata.json", "--common"])

    @Expect(config.common, true)
    @Expect(config.packageName, "windows_common")
    @Expect(config.outputDir, "windows_common")
    @Expect(config.features.isEmpty(), true)
    @Expect(config.supportPackageDirs.isEmpty(), false)
}

@Test
func testParseArgsPackageNameOverride() {
    let config = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Windows.Win32.Foundation",
        "--sys",
        "--package-name", "raw_slice"
    ])

    @Expect(config.sys, true)
    @Expect(config.packageName, "raw_slice")
}

@Test
func testParseArgsRejectsBadArguments() {
    @Expect(cliTestThrows({ => let _ = parseArgs(["--feature"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--filter"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--input-json"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--input-dir"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--winmd-to-json"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--winmd-to-json", "x"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--unknown"]) }), true)
}

@Test
func testParseArgsAcceptsSysImplementNoCommentFlags() {
    let config = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Example.Foundation",
        "--sys",
        "--implement",
        "--no-comment"
    ])

    @Expect(config.sys, true)
    @Expect(config.implement, true)
    @Expect(config.noComment, true)
}

@Test
func testParseArgsCollectsDeriveAndReferenceFlags() {
    let config = parseArgs([
        "--input-json", "metadata.json",
        "--feature", "Example.Foundation",
        "--derive", "guid_access,flags_ops",
        "--derive", "extra",
        "--reference", "windows_collections,flat,Windows.Foundation.Collections",
        "--reference", "windows_numerics,flat,Windows.Foundation.Numerics"
    ])

    @Expect(config.derives.size, 3)
    @Expect(config.derives[0], "guid_access")
    @Expect(config.derives[1], "flags_ops")
    @Expect(config.derives[2], "extra")
    @Expect(config.referenceArgs.size, 2)
    @Expect(config.referenceArgs[0], "windows_collections,flat,Windows.Foundation.Collections")
}

@Test
func testParseArgsRejectsMissingValuesForNewFlags() {
    @Expect(cliTestThrows({ => let _ = parseArgs(["--package-name"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--derive"]) }), true)
    @Expect(cliTestThrows({ => let _ = parseArgs(["--reference"]) }), true)
}

@Test
func testReferenceStageParsesAndValidates() {
    let stage = ReferenceStage.parse("windows_collections,flat,Windows.Foundation.Collections")
    @Expect(stage.name, "windows_collections")
    @Expect(stage.style, "flat")
    @Expect(stage.path, "Windows.Foundation.Collections")

    let windowsStage = ReferenceStage.parse("windows")
    @Expect(windowsStage.name, "windows")
    @Expect(windowsStage.style, "skip-root")
    @Expect(windowsStage.path, "Windows")

    @Expect(cliTestThrows({ => let _ = ReferenceStage.parse("only-two,parts") }), true)
    @Expect(cliTestThrows({ => let _ = ReferenceStage.parse("name,bogus,Namespace") }), true)
}
