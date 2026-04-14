$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $workspaceRoot
$manifestPath = Join-Path $workspaceRoot "cjpm.toml"
$outputRoot = Join-Path $workspaceRoot "tests/output/wave-a"
$generatedRoot = Join-Path $outputRoot "generated"
$integrationWorkspaceRoot = Join-Path $outputRoot "workspace"
$integrationCfgDir = Join-Path $integrationWorkspaceRoot "windows-cj"
$integrationCfgPath = Join-Path $integrationCfgDir "cfg.toml"

if (!(Test-Path $manifestPath)) {
    throw "Missing root manifest: $manifestPath"
}

$manifest = Get-Content -Raw $manifestPath
if ($manifest -notmatch 'compile-option = "--cfg \./windows-cj"') {
    throw "Root manifest is missing compile-option = ""--cfg ./windows-cj"""
}
if ($manifest -notmatch '\[windows-cj\]') {
    throw "Root manifest is missing [windows-cj] table"
}
if ($manifest -notmatch 'features = \[') {
    throw "Root manifest is missing [windows-cj].features"
}

if (Test-Path $outputRoot) {
    Remove-Item -Recurse -Force $outputRoot
}
New-Item -ItemType Directory -Force $generatedRoot | Out-Null
New-Item -ItemType Directory -Force $integrationCfgDir | Out-Null

@'
[workspace]
members = []

compile-option = "--cfg ./windows-cj"

[windows-cj]
features = ["Windows_Win32_Foundation"]
'@ | Set-Content -NoNewline (Join-Path $integrationWorkspaceRoot "cjpm.toml")

$bindgenDir = Join-Path $workspaceRoot "windows-bindgen"
$syncDir = Join-Path $workspaceRoot "windows-sync"
$winmdPath = Join-Path $workspaceRoot "winmd/Windows.Win32.winmd"

Push-Location $bindgenDir
try {
    cjpm build | Out-Host
    cjpm run -- `
        --in $winmdPath `
        --out $generatedRoot `
        --filter Windows.Win32.Foundation `
        --sys | Out-Host
}
finally {
    Pop-Location
}

$featuresToml = Join-Path $generatedRoot "features.toml"
$linkToml = Join-Path $generatedRoot "link-options.toml"
if (!(Test-Path $featuresToml)) {
    throw "bindgen did not produce features.toml"
}
if (!(Test-Path $linkToml)) {
    throw "bindgen did not produce link-options.toml"
}

$featuresContent = Get-Content -Raw $featuresToml
$linkContent = Get-Content -Raw $linkToml

if ($featuresContent -notmatch '\[features\.Windows_Win32_Foundation\]') {
    throw "bindgen features.toml is missing the Windows.Win32.Foundation namespace feature block"
}
if ($featuresContent -notmatch 'cfg = "Windows_Win32_Foundation"') {
    throw "bindgen features.toml is missing the Foundation cfg entry"
}
if ($featuresContent -notmatch 'deps = \["API_MS_WIN_CORE_HANDLE_L1_1_0", "KERNEL32", "NTDLL", "OLEAUT32", "USER32"\]') {
    throw "bindgen features.toml is missing the expected Foundation dependency closure"
}
if ($linkContent -notmatch '\[features\.KERNEL32\]') {
    throw "bindgen link-options.toml is missing the kernel32 feature block"
}
if ($linkContent -notmatch 'link = \["-lkernel32"\]') {
    throw "bindgen link-options.toml is missing the kernel32 link entry"
}

Push-Location $syncDir
try {
    cjpm build | Out-Host
    $syncStdout = cjpm run --skip-build -- --workspace-root "$integrationWorkspaceRoot" --catalog-root "$generatedRoot"
}
finally {
    Pop-Location
}

if (!(Test-Path $integrationCfgPath)) {
    throw "windows-sync did not write cfg.toml at $integrationCfgPath"
}

$expectedCfg = @'
API_MS_WIN_CORE_HANDLE_L1_1_0 = "on"
KERNEL32 = "on"
NTDLL = "on"
OLEAUT32 = "on"
USER32 = "on"
Windows_Win32_Foundation = "on"
'@

$cfgContent = Get-Content -Raw $integrationCfgPath
if ($cfgContent.Trim() -ne $expectedCfg.Trim()) {
    throw "windows-sync cfg.toml mismatch.`nExpected:`n$expectedCfg`nActual:`n$cfgContent"
}

$stdoutText = ($syncStdout | Out-String).Trim()
$stdoutLines = $stdoutText -split "`r?`n"
$expectedStdoutLine = '-lapi-ms-win-core-handle-l1-1-0 -lkernel32 -lntdll -loleaut32 -luser32'
$matchedStdoutLines = @()
foreach ($line in $stdoutLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq $expectedStdoutLine) {
        $matchedStdoutLines += $trimmed
    }
}
if ($matchedStdoutLines.Count -ne 1) {
    throw "windows-sync stdout link options mismatch or ambiguous.`nExpected one exact line:`n$expectedStdoutLine`nActual:`n$stdoutText"
}

Write-Host "Wave A integration checks passed."
