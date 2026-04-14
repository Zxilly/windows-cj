$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$fixtureWinmd = Join-Path $repoRoot "windows-cj/winmd/Windows.Win32.winmd"
$outputRoot = Join-Path $packageRoot "tests/output/alignment_smoke"
$apiFilteredOut = Join-Path $outputRoot "api_filtered"
$highLevelOut = Join-Path $outputRoot "high_level"
$shortNameOut = Join-Path $outputRoot "short_name"
$identityOut = Join-Path $outputRoot "identity"

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
        --out $apiFilteredOut `
        --flat `
        --filter Windows.Win32.UI.Accessibility.IAccessible | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $shortNameOut `
        --flat `
        --filter GetTickCount | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $identityOut `
        --flat `
        --filter Windows.Win32.Security.Authentication.Identity | Out-Host
    cjpm run -- `
        --in $fixtureWinmd `
        --out $highLevelOut `
        --flat `
        --no-sys `
        --high-level `
        --filter Windows.Win32.Foundation | Out-Host
}
finally {
    Pop-Location
}

$apiFilteredFile = Join-Path $apiFilteredOut "Accessibility.cj"
if (!(Test-Path $apiFilteredFile)) {
    throw "API-level filter did not generate accessibility output"
}
$variantFile = Join-Path $apiFilteredOut "Variant.cj"
if (!(Test-Path $variantFile)) {
    throw "API-level filter did not generate dependent variant output"
}
$shortNameFile = Join-Path $shortNameOut "SystemInformation.cj"
if (!(Test-Path $shortNameFile)) {
    throw "Short-name filter did not expand to the owning namespace"
}
$identityFile = Join-Path $identityOut "Identity.cj"
if (!(Test-Path $identityFile)) {
    throw "Identity namespace filter did not generate identity output"
}

$apiFiltered = Get-Content -Raw $apiFilteredFile
$variant = Get-Content -Raw $variantFile
$shortName = Get-Content -Raw $shortNameFile
$identity = Get-Content -Raw $identityFile
if ($apiFiltered -notmatch 'public class IAccessible <: ComInterface & Resource') {
    throw "API-level filter did not retain the requested type"
}
if ($apiFiltered -notmatch 'public unsafe func accParent\(') {
    throw "Normalized getter name was not generated"
}
if ($apiFiltered -match 'public unsafe func get_accParent\(') {
    throw "Raw getter name is still present in API-filtered output"
}
if ($apiFiltered -notmatch 'public unsafe func SetaccName\(') {
    throw "Normalized setter name was not generated"
}
if ($apiFiltered -match '(?s)@CallingConv\[STDCALL\]\s*@C\s+public struct IAccessibleVtbl') {
    throw "COM vtable entries should not carry @CallingConv[STDCALL] annotations"
}
if ($variant -notmatch '(?s)// WARNING: union simulated as byte array \(size-equivalent, not type-safe\)\s*@C\s+public struct VARIANT__Anonymous_e__Union\s*\{\s*public var _raw: VArray<UInt64, \$3> = VArray<UInt64, \$3>\(repeat: 0\)') {
    throw "VARIANT union should choose aligned UInt64 raw storage for its 24-byte union payload"
}
if ($variant -notmatch '(?s)public struct VARIANT__Anonymous_e__Union\s*\{[^}]*public func anonymous\(\): VARIANT__Anonymous_e__Union__Anonymous_e__Struct') {
    throw "VARIANT union should expose an accessor for the anonymous struct view"
}
if ($variant -notmatch '(?s)public struct VARIANT__Anonymous_e__Union\s*\{.*?public mut func set_anonymous\(val: VARIANT__Anonymous_e__Union__Anonymous_e__Struct\): Unit') {
    throw "VARIANT union should expose a setter for the anonymous struct view"
}
if ($variant -notmatch '(?s)public struct VARIANT__Anonymous_e__Union\s*\{.*?public mut func set_decVal\(val: win32_foundation\.DECIMAL\): Unit') {
    throw "VARIANT union should expose a setter for the DECIMAL view"
}
if ($variant -notmatch '(?s)// WARNING: union simulated as byte array \(size-equivalent, not type-safe\)\s*@C\s+public struct VARIANT__Anonymous_e__Union__Anonymous_e__Struct__Anonymous_e__Union\s*\{\s*public var _raw: VArray<UInt64, \$2> = VArray<UInt64, \$2>\(repeat: 0\)') {
    throw "Nested VARIANT unions should also choose aligned UInt64 raw storage"
}
if ($variant -notmatch '(?s)public struct VARIANT__Anonymous_e__Union__Anonymous_e__Struct__Anonymous_e__Union\s*\{.*?public mut func set_llVal\(val: Int64\): Unit') {
    throw "Nested VARIANT unions should expose setters for primitive views"
}
if ($shortName -notmatch '(?m)^    func GetTickCount\(\): UInt32$') {
    throw "Short-name filter did not retain GetTickCount from its namespace"
}
if ($identity -notmatch '(?m)^    func SystemFunction036\(RandomBuffer: CPointer<Unit>, RandomBufferLength: UInt32\): .*BOOLEAN$') {
    throw "foreign declarations should use ImplMap.importName when the import symbol differs"
}
if ($identity -notmatch '(?m)^unsafe func RtlGenRandom\(RandomBuffer: CPointer<Unit>, RandomBufferLength: UInt32\): .*BOOLEAN \{$') {
    throw "Import-name remapping should preserve the metadata method name via an unsafe wrapper"
}

$highLevelFile = Join-Path $highLevelOut "Foundation.cj"
if (!(Test-Path $highLevelFile)) {
    throw "High-level projection mode did not generate foundation output"
}

$highLevel = Get-Content -Raw $highLevelFile
if ($highLevel -notmatch 'Generation mode: high-level') {
    throw "High-level projection mode did not use the high-level pipeline"
}
if ($highLevel -notmatch '(?s)public struct DECIMAL__Anonymous1_e__Union\s*\{\s*public var _raw: VArray<UInt16, \$1> = VArray<UInt16, \$1>\(repeat: 0\)') {
    throw "DECIMAL 2-byte union should use UInt16 raw storage to preserve alignment"
}
if ($highLevel -notmatch '(?s)public struct DECIMAL__Anonymous1_e__Union\s*\{.*?public mut func set_signscale\(val: UInt16\): Unit') {
    throw "DECIMAL 2-byte union should expose a setter for signscale"
}
if ($highLevel -notmatch '(?s)public struct DECIMAL__Anonymous2_e__Union\s*\{\s*public var _raw: VArray<UInt64, \$1> = VArray<UInt64, \$1>\(repeat: 0\)') {
    throw "DECIMAL 8-byte union should use UInt64 raw storage to preserve alignment"
}
if ($highLevel -notmatch '(?s)public struct DECIMAL__Anonymous2_e__Union\s*\{.*?public mut func set_lo64\(val: UInt64\): Unit') {
    throw "DECIMAL 8-byte union should expose a setter for lo64"
}

Write-Host "windows-bindgen alignment smoke test passed."
