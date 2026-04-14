$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$fixtureRoot = Join-Path $packageRoot "tests/fixtures/basic"
$missingCfgFixtureRoot = Join-Path $packageRoot "tests/fixtures/missing_cfg"
$workspaceRoot = Join-Path $env:TEMP ("windows-sync-smoke-" + [guid]::NewGuid().ToString())
$packageCopyRoot = Join-Path $workspaceRoot "windows-sync"
$generatedRoot = Join-Path $workspaceRoot "windows-cj"
$cfgPath = Join-Path $generatedRoot "cfg.toml"
if (Test-Path $workspaceRoot) {
    Remove-Item -Recurse -Force $workspaceRoot
}
New-Item -ItemType Directory -Force $packageCopyRoot | Out-Null
New-Item -ItemType Directory -Force $generatedRoot | Out-Null

Copy-Item (Join-Path $packageRoot "src") $packageCopyRoot -Recurse -Force
Copy-Item (Join-Path $packageRoot "cjpm.toml") (Join-Path $packageCopyRoot "cjpm.toml")
@'
[workspace]
members = ["windows-sync"]

compile-option = "--cfg ./windows-cj"

[windows-cj]
features = ["USER32"]
'@ | Set-Content -NoNewline (Join-Path $workspaceRoot "cjpm.toml")
Copy-Item (Join-Path $fixtureRoot "features.toml") (Join-Path $generatedRoot "features.toml")
Copy-Item (Join-Path $fixtureRoot "link-options.toml") (Join-Path $generatedRoot "link-options.toml")

Push-Location $packageCopyRoot
try {
    cjpm build | Out-Host
    $runOutput = cjpm run
}
finally {
    Pop-Location
}

$stdoutText = ($runOutput | Out-String).Trim()
$stdoutLines = $stdoutText -split "`r?`n"
$expectedStdoutLine = (Get-Content -Raw (Join-Path $fixtureRoot "expected_link_options.toml")).Trim()
$matchedStdoutLines = @()
foreach ($line in $stdoutLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq $expectedStdoutLine) {
        $matchedStdoutLines += $trimmed
    }
}
if ($matchedStdoutLines.Count -ne 1) {
    throw "stdout link options mismatch or ambiguous.`nExpected one exact line:`n$expectedStdoutLine`nActual:`n$stdoutText"
}
$expectedCfg = Get-Content -Raw (Join-Path $fixtureRoot "expected_cfg.toml")

if (!(Test-Path $cfgPath)) {
    throw "windows-sync did not write cfg.toml at $cfgPath"
}

$actualCfg = Get-Content -Raw $cfgPath
if ($actualCfg.Trim() -ne $expectedCfg.Trim()) {
    throw "cfg.toml mismatch.`nExpected:`n$expectedCfg`nActual:`n$actualCfg"
}

Remove-Item -Recurse -Force $workspaceRoot

$helpWorkspaceRoot = Join-Path $env:TEMP ("windows-sync-smoke-help-" + [guid]::NewGuid().ToString())
$helpPackageCopyRoot = Join-Path $helpWorkspaceRoot "windows-sync"
New-Item -ItemType Directory -Force $helpPackageCopyRoot | Out-Null
Copy-Item (Join-Path $packageRoot "src") $helpPackageCopyRoot -Recurse -Force
Copy-Item (Join-Path $packageRoot "cjpm.toml") (Join-Path $helpPackageCopyRoot "cjpm.toml")
Push-Location $helpPackageCopyRoot
try {
    cjpm build | Out-Host
    $helpOutput = cjpm run --skip-build --run-args='--help' 2>&1 | Out-String
}
finally {
    Pop-Location
}

if (($helpOutput | Out-String) -notmatch 'usage: windows-sync \[sync\] \[--workspace-root <path>\] \[--catalog-root <path>\]') {
    throw "help invocation did not print usage"
}
if (($helpOutput | Out-String) -match 'Unable to locate workspace root') {
    throw "help invocation should not require workspace discovery"
}

Push-Location $helpPackageCopyRoot
try {
    $syncHelpOutput = cjpm run --skip-build --run-args='sync --help' 2>&1 | Out-String
    $syncInvalidOutput = cjpm run --skip-build --run-args='sync foo' 2>&1 | Out-String
    $missingCatalogArgOutput = cjpm run --skip-build --run-args='--catalog-root' 2>&1 | Out-String
    $malformedCatalogArgOutput = cjpm run --skip-build --run-args='--catalog-root --workspace-root' 2>&1 | Out-String
}
finally {
    Pop-Location
}

if (($syncHelpOutput | Out-String) -notmatch 'usage: windows-sync \[sync\] \[--workspace-root <path>\] \[--catalog-root <path>\]') {
    throw "sync --help did not print usage"
}
if (($syncHelpOutput | Out-String) -match 'Unable to locate workspace root') {
    throw "sync --help should not require workspace discovery"
}
if (($syncInvalidOutput | Out-String) -notmatch 'usage: windows-sync \[sync\] \[--workspace-root <path>\] \[--catalog-root <path>\]') {
    throw "sync foo did not print usage"
}
if (($syncInvalidOutput | Out-String) -match 'Unable to locate workspace root') {
    throw "sync foo should not require workspace discovery"
}
if (($missingCatalogArgOutput | Out-String) -notmatch 'usage: windows-sync \[sync\] \[--workspace-root <path>\] \[--catalog-root <path>\]') {
    throw "--catalog-root without a value did not print usage"
}
if (($missingCatalogArgOutput | Out-String) -match 'Unable to locate workspace root') {
    throw "--catalog-root without a value should not require workspace discovery"
}
if (($malformedCatalogArgOutput | Out-String) -notmatch 'usage: windows-sync \[sync\] \[--workspace-root <path>\] \[--catalog-root <path>\]') {
    throw "--catalog-root followed by another option should print usage"
}
if (($malformedCatalogArgOutput | Out-String) -match 'Unable to locate .*features\.toml|Unable to locate .*link-options\.toml') {
    throw "--catalog-root followed by another option should fail in argument parsing before catalog lookup"
}

$catalogWorkspaceRoot = Join-Path $env:TEMP ("windows sync smoke catalog " + [guid]::NewGuid().ToString())
$catalogPackageCopyRoot = Join-Path $catalogWorkspaceRoot "windows-sync"
$catalogRoot = Join-Path $catalogWorkspaceRoot "catalog"
$catalogGeneratedRoot = Join-Path $catalogRoot "nested"
New-Item -ItemType Directory -Force $catalogPackageCopyRoot | Out-Null
New-Item -ItemType Directory -Force $catalogGeneratedRoot | Out-Null
Copy-Item (Join-Path $packageRoot "src") $catalogPackageCopyRoot -Recurse -Force
Copy-Item (Join-Path $packageRoot "cjpm.toml") (Join-Path $catalogPackageCopyRoot "cjpm.toml")
@'
[workspace]
members = ["windows-sync"]

compile-option = "--cfg ./windows-cj"

[windows-cj]
features = ["USER32"]
'@ | Set-Content -NoNewline (Join-Path $catalogWorkspaceRoot "cjpm.toml")
Copy-Item (Join-Path $fixtureRoot "features.toml") (Join-Path $catalogGeneratedRoot "features.toml")
Copy-Item (Join-Path $fixtureRoot "link-options.toml") (Join-Path $catalogGeneratedRoot "link-options.toml")

Push-Location $catalogPackageCopyRoot
try {
    cjpm build | Out-Host
    $catalogOutput = cjpm run --skip-build -- --catalog-root "$catalogGeneratedRoot"
}
finally {
    Pop-Location
}

$catalogStdoutText = ($catalogOutput | Out-String).Trim()
$catalogStdoutLines = $catalogStdoutText -split "`r?`n"
$catalogMatchedStdoutLines = @()
foreach ($line in $catalogStdoutLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq $expectedStdoutLine) {
        $catalogMatchedStdoutLines += $trimmed
    }
}
if ($catalogMatchedStdoutLines.Count -ne 1) {
    throw "catalog-root stdout link options mismatch or ambiguous.`nExpected one exact line:`n$expectedStdoutLine`nActual:`n$catalogStdoutText"
}
$catalogCfgPath = Join-Path $catalogWorkspaceRoot "windows-cj/cfg.toml"
if (!(Test-Path $catalogCfgPath)) {
    throw "catalog-root run did not write cfg.toml at $catalogCfgPath"
}
$catalogActualCfg = Get-Content -Raw $catalogCfgPath
if ($catalogActualCfg.Trim() -ne $expectedCfg.Trim()) {
    throw "catalog-root cfg.toml mismatch.`nExpected:`n$expectedCfg`nActual:`n$catalogActualCfg"
}

$explicitWorkspaceRoot = Join-Path $env:TEMP ("windows sync smoke catalog explicit workspace " + [guid]::NewGuid().ToString())
$explicitRunnerRoot = Join-Path $env:TEMP ("windows sync smoke catalog explicit runner " + [guid]::NewGuid().ToString())
$explicitPackageCopyRoot = Join-Path $explicitRunnerRoot "windows-sync"
$explicitCatalogRoot = Join-Path $explicitWorkspaceRoot "catalog root"
New-Item -ItemType Directory -Force $explicitPackageCopyRoot | Out-Null
New-Item -ItemType Directory -Force $explicitCatalogRoot | Out-Null
Copy-Item (Join-Path $packageRoot "src") $explicitPackageCopyRoot -Recurse -Force
Copy-Item (Join-Path $packageRoot "cjpm.toml") (Join-Path $explicitPackageCopyRoot "cjpm.toml")
@'
[workspace]
members = ["windows-sync"]

compile-option = "--cfg ./windows-cj"

[windows-cj]
features = ["USER32"]
'@ | Set-Content -NoNewline (Join-Path $explicitWorkspaceRoot "cjpm.toml")
Copy-Item (Join-Path $fixtureRoot "features.toml") (Join-Path $explicitCatalogRoot "features.toml")
Copy-Item (Join-Path $fixtureRoot "link-options.toml") (Join-Path $explicitCatalogRoot "link-options.toml")

Push-Location $explicitPackageCopyRoot
try {
    cjpm build | Out-Host
    $explicitOutput = cjpm run --skip-build -- --workspace-root "$explicitWorkspaceRoot" --catalog-root "$explicitCatalogRoot"
}
finally {
    Pop-Location
}

$explicitStdoutText = ($explicitOutput | Out-String).Trim()
$explicitStdoutLines = $explicitStdoutText -split "`r?`n"
$explicitMatchedStdoutLines = @()
foreach ($line in $explicitStdoutLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq $expectedStdoutLine) {
        $explicitMatchedStdoutLines += $trimmed
    }
}
if ($explicitMatchedStdoutLines.Count -ne 1) {
    throw "explicit workspace+catalog stdout link options mismatch or ambiguous.`nExpected one exact line:`n$expectedStdoutLine`nActual:`n$explicitStdoutText"
}
$explicitCfgPath = Join-Path $explicitWorkspaceRoot "windows-cj/cfg.toml"
if (!(Test-Path $explicitCfgPath)) {
    throw "explicit workspace+catalog run did not write cfg.toml at $explicitCfgPath"
}
$explicitActualCfg = Get-Content -Raw $explicitCfgPath
if ($explicitActualCfg.Trim() -ne $expectedCfg.Trim()) {
    throw "explicit workspace+catalog cfg.toml mismatch.`nExpected:`n$expectedCfg`nActual:`n$explicitActualCfg"
}

$missingCatalogWorkspaceRoot = Join-Path $env:TEMP ("windows sync smoke missing catalog " + [guid]::NewGuid().ToString())
$missingCatalogPackageCopyRoot = Join-Path $missingCatalogWorkspaceRoot "windows-sync"
$missingCatalogRoot = Join-Path $missingCatalogWorkspaceRoot "catalog root"
New-Item -ItemType Directory -Force $missingCatalogPackageCopyRoot | Out-Null
New-Item -ItemType Directory -Force $missingCatalogRoot | Out-Null
Copy-Item (Join-Path $packageRoot "src") $missingCatalogPackageCopyRoot -Recurse -Force
Copy-Item (Join-Path $packageRoot "cjpm.toml") (Join-Path $missingCatalogPackageCopyRoot "cjpm.toml")
@'
[workspace]
members = ["windows-sync"]

compile-option = "--cfg ./windows-cj"

[windows-cj]
features = ["USER32"]
'@ | Set-Content -NoNewline (Join-Path $missingCatalogWorkspaceRoot "cjpm.toml")
Copy-Item (Join-Path $fixtureRoot "features.toml") (Join-Path $missingCatalogRoot "features.toml")

Push-Location $missingCatalogPackageCopyRoot
try {
    cjpm build | Out-Host
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $missingCatalogOutput = & cjpm run --skip-build -- --catalog-root "$missingCatalogRoot" 2>&1 | Out-String
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}
finally {
    Pop-Location
}

if (($missingCatalogOutput | Out-String) -notmatch 'An exception has occurred:') {
    throw "missing-catalog failure did not surface as an exception"
}
if (($missingCatalogOutput | Out-String) -notmatch 'link-options.toml') {
    throw "missing-catalog failure message did not mention the missing catalog file"
}

$workspaceRoot = Join-Path $env:TEMP ("windows-sync-smoke-noworkspace-" + [guid]::NewGuid().ToString())
$packageCopyRoot = Join-Path $workspaceRoot "windows-sync"
New-Item -ItemType Directory -Force $packageCopyRoot | Out-Null
Copy-Item (Join-Path $packageRoot "src") $packageCopyRoot -Recurse -Force
Copy-Item (Join-Path $packageRoot "cjpm.toml") (Join-Path $packageCopyRoot "cjpm.toml")
Copy-Item (Join-Path $fixtureRoot "features.toml") (Join-Path $workspaceRoot "features.toml")
Copy-Item (Join-Path $fixtureRoot "link-options.toml") (Join-Path $workspaceRoot "link-options.toml")

Push-Location $packageCopyRoot
try {
    cjpm build | Out-Host
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $missingWorkspaceOutput = & cjpm run 2>&1 | Out-String
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}
finally {
    Pop-Location
}

if (($missingWorkspaceOutput | Out-String) -notmatch 'An exception has occurred:') {
    throw "missing-workspace failure did not surface as an exception"
}
if (($missingWorkspaceOutput | Out-String) -notmatch 'Exception: Unable to locate workspace root') {
    throw "missing-workspace failure message did not mention workspace discovery"
}

$workspaceRoot = Join-Path $env:TEMP ("windows-sync-smoke-missingcfg-" + [guid]::NewGuid().ToString())
$packageCopyRoot = Join-Path $workspaceRoot "windows-sync"
$generatedRoot = Join-Path $workspaceRoot "windows-cj"
$cfgPath = Join-Path $generatedRoot "cfg.toml"
New-Item -ItemType Directory -Force $packageCopyRoot | Out-Null
New-Item -ItemType Directory -Force $generatedRoot | Out-Null
Copy-Item (Join-Path $packageRoot "src") $packageCopyRoot -Recurse -Force
Copy-Item (Join-Path $packageRoot "cjpm.toml") (Join-Path $packageCopyRoot "cjpm.toml")
@'
[workspace]
members = ["windows-sync"]

compile-option = "--cfg ./windows-cj"

[windows-cj]
features = ["USER32"]
'@ | Set-Content -NoNewline (Join-Path $workspaceRoot "cjpm.toml")
Copy-Item (Join-Path $missingCfgFixtureRoot "features.toml") (Join-Path $generatedRoot "features.toml")
Copy-Item (Join-Path $missingCfgFixtureRoot "link-options.toml") (Join-Path $generatedRoot "link-options.toml")

Push-Location $packageCopyRoot
try {
    cjpm build | Out-Host
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $missingCfgOutput = & cjpm run 2>&1 | Out-String
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}
finally {
    Pop-Location
}

if (($missingCfgOutput | Out-String) -notmatch 'An exception has occurred:') {
    throw "missing-cfg failure did not surface as an exception"
}
if (($missingCfgOutput | Out-String) -notmatch 'Exception: Feature USER32 missing cfg') {
    throw "missing-cfg failure message did not mention the missing cfg contract"
}

Write-Host "windows-sync smoke checks passed."
