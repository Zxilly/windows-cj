$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$fixtureWinmd = Join-Path $repoRoot "windows-cj/winmd/Windows.Win32.winmd"
$outputRoot = Join-Path $packageRoot "tests/output/basic_projection"
$systemInformationOut = Join-Path $outputRoot "system_information"
$foundationOut = Join-Path $outputRoot "foundation"
$broadOut = Join-Path $outputRoot "win32"
$broadOutRepeat = Join-Path $outputRoot "win32_repeat"

if (!(Test-Path $fixtureWinmd)) {
    throw "Missing fixture winmd: $fixtureWinmd"
}

if (Test-Path $outputRoot) {
    Remove-Item -Recurse -Force $outputRoot
}
New-Item -ItemType Directory -Force $outputRoot | Out-Null

Push-Location $packageRoot
try {
    cjpm build | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $systemInformationOut `
        --flat `
        --filter Windows.Win32.System.SystemInformation | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $foundationOut `
        --flat `
        --filter Windows.Win32.Foundation | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $broadOut `
        --flat `
        --filter Windows.Win32 | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $broadOutRepeat `
        --flat `
        --filter Windows.Win32 | Out-Host
}
finally {
    Pop-Location
}

$generatedFile = Join-Path $systemInformationOut "SystemInformation.cj"
$featuresToml = Join-Path $systemInformationOut "features.toml"
$linkToml = Join-Path $systemInformationOut "link-options.toml"
$cfgToml = Join-Path $systemInformationOut "cfg.toml"

if (!(Test-Path $generatedFile)) {
    throw "Missing generated source file: $generatedFile"
}
if (!(Test-Path $featuresToml)) {
    throw "Missing features metadata: $featuresToml"
}
if (!(Test-Path $linkToml)) {
    throw "Missing link metadata: $linkToml"
}
if (!(Test-Path $cfgToml)) {
    throw "Missing cfg metadata: $cfgToml"
}

$features = Get-Content -Raw $featuresToml
$links = Get-Content -Raw $linkToml
$cfg = Get-Content -Raw $cfgToml
$generated = Get-Content -Raw $generatedFile

if ($generated -notmatch 'public struct IMAGE_FILE_MACHINE') {
    throw "Generated source is missing IMAGE_FILE_MACHINE"
}
if ($generated -notmatch 'public var value: UInt16') {
    throw "IMAGE_FILE_MACHINE value field is not UInt16"
}
if ($generated -notmatch 'public struct SYSTEM_INFO__Anonymous_e__Union__Anonymous_e__Struct') {
    throw "Generated source is missing the projected SYSTEM_INFO anonymous helper struct"
}
if ($generated -notmatch 'public func anonymous\(\): SYSTEM_INFO__Anonymous_e__Union__Anonymous_e__Struct') {
    throw "Generated source is missing the SYSTEM_INFO anonymous union accessor"
}

$featureSections = [regex]::Matches($features, '^\[features\.([^\]]+)\]$', 'Multiline') | ForEach-Object { $_.Groups[1].Value }
if ($featureSections.Count -eq 0) {
    throw "features.toml has no [features.*] sections"
}
if (($featureSections | Where-Object { $_ -notmatch '^[A-Za-z0-9_]+$' }).Count -ne 0) {
    throw "features.toml contains non-normalized feature names"
}
$duplicateFeatureSections = $featureSections | Group-Object | Where-Object { $_.Count -gt 1 }
if ($duplicateFeatureSections.Count -ne 0) {
    throw "features.toml contains duplicate feature sections"
}
$sortedFeatureSections = @($featureSections | Sort-Object)
if ((Compare-Object -ReferenceObject $featureSections -DifferenceObject $sortedFeatureSections).Count -ne 0) {
    throw "features.toml sections are not sorted"
}
if ($features -notmatch '\[features\.KERNEL32\]') {
    throw "features.toml is missing KERNEL32 feature block"
}
if ($features -notmatch 'cfg = "KERNEL32"') {
    throw "features.toml is missing KERNEL32 cfg entry"
}
if ($features -notmatch 'deps = \[\]') {
    throw "features.toml is missing deps arrays"
}
if ($features -match 'deps = \[\s*\r?\n') {
    throw "features.toml deps should be inline arrays"
}
if ($features -notmatch 'deps = \["[A-Za-z0-9_]+') {
    throw "features.toml is missing inline dependency entries"
}
if ($links -notmatch '\[features\.KERNEL32\]') {
    throw "link-options.toml is missing KERNEL32 feature block"
}
if ($links -notmatch 'link = \["-l') {
    throw "link-options.toml is missing prefixed link entries"
}
$linkSections = [regex]::Matches($links, '^\[features\.([^\]]+)\]$', 'Multiline') | ForEach-Object { $_.Groups[1].Value }
if ($linkSections.Count -eq 0) {
    throw "link-options.toml has no [features.*] sections"
}
if (($linkSections | Where-Object { $_ -notmatch '^[A-Za-z0-9_]+$' }).Count -ne 0) {
    throw "link-options.toml contains non-normalized feature names"
}
$duplicateLinkSections = $linkSections | Group-Object | Where-Object { $_.Count -gt 1 }
if ($duplicateLinkSections.Count -ne 0) {
    throw "link-options.toml contains duplicate feature sections"
}
$sortedLinkSections = @($linkSections | Sort-Object)
if ((Compare-Object -ReferenceObject $linkSections -DifferenceObject $sortedLinkSections).Count -ne 0) {
    throw "link-options.toml sections are not sorted"
}
if ($cfg -notmatch '(?m)^KERNEL32 = "on"$') {
    throw "cfg.toml is missing KERNEL32 feature toggle"
}
$cfgFeatures = [regex]::Matches($cfg, '^([A-Za-z0-9_]+) = "on"$', 'Multiline') | ForEach-Object { $_.Groups[1].Value }
if ($cfgFeatures.Count -eq 0) {
    throw "cfg.toml has no feature toggles"
}
if (($cfgFeatures | Where-Object { $_ -notmatch '^[A-Za-z0-9_]+$' }).Count -ne 0) {
    throw "cfg.toml contains non-normalized feature names"
}
$duplicateCfgFeatures = $cfgFeatures | Group-Object | Where-Object { $_.Count -gt 1 }
if ($duplicateCfgFeatures.Count -ne 0) {
    throw "cfg.toml contains duplicate feature keys"
}
$sortedCfgFeatures = @($cfgFeatures | Sort-Object)
if ((Compare-Object -ReferenceObject $cfgFeatures -DifferenceObject $sortedCfgFeatures).Count -ne 0) {
    throw "cfg.toml toggles are not sorted"
}
if ($generated -notmatch 'GetTickCount') {
    throw "Generated source is missing GetTickCount"
}

$foundationMetadata = Join-Path $foundationOut "Metadata.cj"
$foundationFeaturesToml = Join-Path $foundationOut "features.toml"
$foundationCfgToml = Join-Path $foundationOut "cfg.toml"

if (!(Test-Path $foundationMetadata)) {
    throw "Missing foundation metadata source: $foundationMetadata"
}

$foundationFeatures = Get-Content -Raw $foundationFeaturesToml
$foundationCfg = Get-Content -Raw $foundationCfgToml
$foundationGenerated = Get-Content -Raw $foundationMetadata

if ($foundationFeatures -notmatch '\[features\.Windows_Win32_Foundation_Metadata\]') {
    throw "foundation features.toml is missing metadata namespace feature block"
}
if ($foundationCfg -notmatch '(?m)^Windows_Win32_Foundation_Metadata = "on"$') {
    throw "foundation cfg.toml is missing metadata namespace feature toggle"
}
if ($foundationGenerated -notmatch '@When\[Windows_Win32_Foundation_Metadata == "on"\]') {
    throw "foundation metadata source is missing the expected feature guard"
}
if ($generated -match '@When\[cfg\.feat\]') {
    throw "Generated source contains empty nested feature guards"
}

$broadFeaturesToml = Join-Path $broadOut "features.toml"
$broadLinkToml = Join-Path $broadOut "link-options.toml"
$broadCfgToml = Join-Path $broadOut "cfg.toml"
$broadFeatures = Get-Content -Raw $broadFeaturesToml
$broadLinks = Get-Content -Raw $broadLinkToml
$broadCfg = Get-Content -Raw $broadCfgToml

$broadFeatureSections = [regex]::Matches($broadFeatures, '^\[features\.([^\]]+)\]$', 'Multiline') | ForEach-Object { $_.Groups[1].Value }
if ($broadFeatureSections.Count -eq 0) {
    throw "broad features.toml has no [features.*] sections"
}
$broadDuplicateFeatureSections = $broadFeatureSections | Group-Object | Where-Object { $_.Count -gt 1 }
if ($broadDuplicateFeatureSections.Count -ne 0) {
    throw "broad features.toml contains duplicate feature sections"
}
$broadSortedFeatureSections = @($broadFeatureSections | Sort-Object)
if ((Compare-Object -ReferenceObject $broadFeatureSections -DifferenceObject $broadSortedFeatureSections).Count -ne 0) {
    throw "broad features.toml sections are not sorted"
}

$broadLinkSections = [regex]::Matches($broadLinks, '^\[features\.([^\]]+)\]$', 'Multiline') | ForEach-Object { $_.Groups[1].Value }
if ($broadLinkSections.Count -eq 0) {
    throw "broad link-options.toml has no [features.*] sections"
}
$broadDuplicateLinkSections = $broadLinkSections | Group-Object | Where-Object { $_.Count -gt 1 }
if ($broadDuplicateLinkSections.Count -ne 0) {
    throw "broad link-options.toml contains duplicate feature sections"
}
$broadSortedLinkSections = @($broadLinkSections | Sort-Object)
if ((Compare-Object -ReferenceObject $broadLinkSections -DifferenceObject $broadSortedLinkSections).Count -ne 0) {
    throw "broad link-options.toml sections are not sorted"
}

$broadCfgFeatures = [regex]::Matches($broadCfg, '^([A-Za-z0-9_]+) = "on"$', 'Multiline') | ForEach-Object { $_.Groups[1].Value }
if ($broadCfgFeatures.Count -eq 0) {
    throw "broad cfg.toml has no feature toggles"
}
$broadDuplicateCfgFeatures = $broadCfgFeatures | Group-Object | Where-Object { $_.Count -gt 1 }
if ($broadDuplicateCfgFeatures.Count -ne 0) {
    throw "broad cfg.toml contains duplicate feature keys"
}
$broadSortedCfgFeatures = @($broadCfgFeatures | Sort-Object)
if ((Compare-Object -ReferenceObject $broadCfgFeatures -DifferenceObject $broadSortedCfgFeatures).Count -ne 0) {
    throw "broad cfg.toml toggles are not sorted"
}

$hypervisorFile = Join-Path $broadOut "Hypervisor.cj"
if (!(Test-Path $hypervisorFile)) {
    throw "Missing hypervisor source: $hypervisorFile"
}
$hypervisor = Get-Content -Raw $hypervisorFile
if ($hypervisor -notmatch 'public var Anonymous: WHV_X64_FP_CONTROL_STATUS_REGISTER__Anonymous_e__Struct__Anonymous_e__Union = WHV_X64_FP_CONTROL_STATUS_REGISTER__Anonymous_e__Struct__Anonymous_e__Union\(\)') {
    throw "Hypervisor FP control register outer anonymous field shape regressed"
}
if ($hypervisor -notmatch 'public var Anonymous: WHV_X64_XMM_CONTROL_STATUS_REGISTER__Anonymous_e__Struct__Anonymous_e__Union = WHV_X64_XMM_CONTROL_STATUS_REGISTER__Anonymous_e__Struct__Anonymous_e__Union\(\)') {
    throw "Hypervisor XMM control register outer anonymous field shape regressed"
}

$variantFile = Join-Path $broadOut "Variant.cj"
if (!(Test-Path $variantFile)) {
    throw "Missing variant source: $variantFile"
}
$variant = Get-Content -Raw $variantFile
if ($variant -notmatch 'public var Anonymous: VARIANT__Anonymous_e__Union = VARIANT__Anonymous_e__Union\(\)') {
    throw "VARIANT outer anonymous union shape regressed"
}
if ($variant -notmatch 'public var Anonymous: VARIANT__Anonymous_e__Union__Anonymous_e__Struct__Anonymous_e__Union = VARIANT__Anonymous_e__Union__Anonymous_e__Struct__Anonymous_e__Union\(\)') {
    throw "VARIANT nested anonymous union shape regressed"
}

$cloudFiltersFile = Join-Path $broadOut "CloudFilters.cj"
if (!(Test-Path $cloudFiltersFile)) {
    throw "Missing cloud filters source: $cloudFiltersFile"
}
$cloudFilters = Get-Content -Raw $cloudFiltersFile
if ($cloudFilters -notmatch 'public var Anonymous: CF_CALLBACK_PARAMETERS__Anonymous_e__Union = CF_CALLBACK_PARAMETERS__Anonymous_e__Union\(\)') {
    throw "CF_CALLBACK_PARAMETERS outer anonymous union shape regressed"
}
if ($cloudFilters -notmatch 'public var Anonymous: CF_CALLBACK_PARAMETERS__Anonymous_e__Union__Cancel_e__Struct__Anonymous_e__Union = CF_CALLBACK_PARAMETERS__Anonymous_e__Union__Cancel_e__Struct__Anonymous_e__Union\(\)') {
    throw "CF_CALLBACK_PARAMETERS nested anonymous union shape regressed"
}
if ($cloudFilters -notmatch 'public func fetchData\(\): CF_CALLBACK_PARAMETERS__Anonymous_e__Union__FetchData_e__Struct') {
    throw "CF_CALLBACK_PARAMETERS fetchData branch projection regressed"
}

$accessibilityFile = Join-Path $broadOut "Accessibility.cj"
if (!(Test-Path $accessibilityFile)) {
    throw "Missing accessibility source: $accessibilityFile"
}
$accessibility = Get-Content -Raw $accessibilityFile
if ($accessibility -notmatch 'func takeIAccessibleFromAbi\(raw: CPointer<Unit>\): IAccessible') {
    throw "Generated COM interfaces are missing ABI-take helpers"
}
if ($accessibility -notmatch 'func viewIAccessible\(raw: CPointer<Unit>\): IAccessible') {
    throw "Generated COM interfaces are missing call-bound view helpers"
}
if ($accessibility -notmatch 'public class IAccessible <: ComInterface & Resource') {
    throw "Generated COM interfaces should implement Resource semantics"
}
if ($accessibility -notmatch 'public static func fromAbiTake\(raw: CPointer<Unit>\): IAccessible') {
    throw "Generated COM interfaces are missing ABI-take constructors"
}
if ($accessibility -notmatch 'public static func viewOf\(raw: CPointer<Unit>\): IAccessible') {
    throw "Generated COM interfaces are missing call-bound view constructors"
}
if ($accessibility -notmatch 'public static func descriptor\(\): InterfaceDescriptor<IAccessible>') {
    throw "Generated COM interfaces are missing interface descriptors"
}
if ($accessibility -notmatch 'public unsafe func query<T>\(descriptor: InterfaceDescriptor<T>\): Option<T>') {
    throw "Generated COM interfaces are missing generic QueryInterface helpers"
}
if ($accessibility -notmatch 'private let ownsHandle_: Bool') {
    throw "Generated COM interfaces are missing ownership tracking"
}
if ($accessibility -notmatch 'public func close\(\): Unit') {
    throw "Generated COM interfaces are missing close wrappers"
}

$hashTargets = @(
    "features.toml",
    "link-options.toml",
    "cfg.toml",
    "CloudFilters.cj",
    "Hypervisor.cj",
    "Variant.cj"
)
foreach ($relPath in $hashTargets) {
    $first = Get-FileHash -Algorithm SHA256 (Join-Path $broadOut $relPath)
    $second = Get-FileHash -Algorithm SHA256 (Join-Path $broadOutRepeat $relPath)
    if ($first.Hash -ne $second.Hash) {
        throw "win32 generation is not stable for $relPath"
    }
}

$broadSources = Get-ChildItem -Recurse -Filter *.cj $broadOut
$signedLiteralMatch = $broadSources | Select-String -Pattern ' = -[0-9]+(i32|i64)?' | Select-Object -First 1
if ($null -eq $signedLiteralMatch) {
    throw "Broad Windows.Win32 generation did not emit any signed literal constants"
}

Write-Host "windows-bindgen basic projection smoke test passed."
