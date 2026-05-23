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
func testParseArgsAcceptsExplicitWinmdConverter() {
    let config = parseArgs([
        "--winmd-to-json", "../winmd-to-json/bin/winmd-to-json.exe",
        "Sample.winmd"
    ])

    @Expect(config.winmdToJsonPath, "../winmd-to-json/bin/winmd-to-json.exe")
    @Expect(config.inputWinmdPaths.size, 1)
    @Expect(config.inputWinmdPaths[0], "Sample.winmd")
}

@Test
func testWinmdInputsAreAllowedWhenConverterIsExplicit() {
    let config = parseArgs([
        "--winmd-to-json", "../winmd-to-json/bin/winmd-to-json.exe",
        "default",
        "Sample.winmd"
    ])

    @Expect(cliTestThrows({ => validateMetadataInputs(config, true) }), false)
}

@Test
func testEnvironmentWinmdToJsonPathUsesDocumentedVariable() {
    let resolved = environmentWinmdToJsonPath([
        ("Path", "ignored"),
        ("windows_cj_winmd_to_json", "converter.exe")
    ])
    let empty = environmentWinmdToJsonPath([
        (WINMD_TO_JSON_ENV, "")
    ])

    match (resolved) {
        case Some(path) => @Expect(path, "converter.exe")
        case None => @Expect(true, false)
    }
    match (empty) {
        case Some(_) => @Expect(true, false)
        case None => @Expect(true, true)
    }
}

@Test
func testLoadSymbolRecordsRejectsWinmdInputsWithConverterPath() {
    let directMessage = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs(["Sample.winmd"])) })
    let defaultMessage = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs(["default"])) })
    let jsonFlagMessage = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs(["--input-json", "Sample.WINMD"])) })

    @Expect(directMessage.contains("WinMD input 'Sample.winmd' requires an explicit converter"), true)
    @Expect(directMessage.contains("--winmd-to-json ../winmd-to-json/bin/winmd-to-json.exe"), true)
    @Expect(defaultMessage.contains("default WinMD input requires an explicit converter"), true)
    @Expect(defaultMessage.contains(WINMD_TO_JSON_ENV), true)
    @Expect(jsonFlagMessage.contains("--input-json expects converted JSON"), true)
}

@Test
func testInputDirRejectsWinmdOnlyDirectoryWithWorkflow() {
    let dir = ".generated/cli-winmd-dir-test"
    removeIfExists(dir, recursive: true)
    Directory.create(dir, recursive: true)
    File.writeTo("${dir}/Windows.winmd", "".toArray())

    let message = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs(["--input-dir", dir])) })
    removeIfExists(dir, recursive: true)

    @Expect(message.contains("WinMD directory '${dir}' requires an explicit converter"), true)
    @Expect(message.contains("--winmd-to-json ../winmd-to-json/bin/winmd-to-json.exe"), true)
}

@Test
func testLoadSymbolRecordsRejectsMissingInputWithDefaultWorkflow() {
    let message = cliTestExceptionMessage({ => let _ = loadSymbolRecords(parseArgs([])) })

    @Expect(message.contains("no metadata JSON input provided"), true)
    @Expect(message.contains("windows-bindgen default --winmd-to-json"), true)
}

@Test
func testUsageTextDocumentsJsonAndWinmdWorkflow() {
    let help = usageText()

    @Expect(help.contains("metadata.json | json-dir | default | metadata.winmd | winmd-dir"), true)
    @Expect(help.contains("--winmd-to-json <converter>"), true)
    @Expect(help.contains(WINMD_TO_JSON_ENV), true)
    @Expect(help.contains("Native WinMD parsing is not implemented here"), true)
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
    @Expect(config.outputDir, "windows-common")
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
