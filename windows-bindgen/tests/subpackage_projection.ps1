$ErrorActionPreference = "Stop"

$repoRoot = "E:/Project/CS_Project/2026/ling"
$packageRoot = Join-Path $repoRoot "windows-cj/windows-bindgen"
$fixtureWin32 = Join-Path $repoRoot "ref/windows-rs/crates/libs/bindgen/default/Windows.Win32.winmd"
$outputRoot = Join-Path $packageRoot "tests/output/subpackage_projection"
$generatedPackageRoot = Join-Path $outputRoot "windows_sys_pkg"
$generatedSrcRoot = Join-Path $generatedPackageRoot "src"

if (!(Test-Path $fixtureWin32)) {
    throw "Missing fixture winmd: $fixtureWin32"
}

if (Test-Path $outputRoot) {
    Remove-Item -Recurse -Force $outputRoot
}
New-Item -ItemType Directory -Force $generatedSrcRoot | Out-Null

$cjpmToml = @'
[package]
  name = "windows_sys"
  version = "0.1.0"
  output-type = "static"
  cjc-version = "1.1.0"
'@
Set-Content -Path (Join-Path $generatedPackageRoot "cjpm.toml") -Value $cjpmToml -NoNewline

Push-Location $packageRoot
try {
    cjpm build | Out-Host
    cjpm run -- `
        --in $fixtureWin32 `
        --out $generatedSrcRoot `
        --flat `
        --sys `
        --filter Windows.Win32.Foundation `
        --filter Windows.Win32.System.Threading | Out-Host
}
finally {
    Pop-Location
}

$foundationFile = Join-Path $generatedSrcRoot "win32_foundation/mod.cj"
$threadingFile = Join-Path $generatedSrcRoot "win32_system_threading/mod.cj"
$legacyFoundationFile = Join-Path $generatedSrcRoot "foundation.cj"
$legacyThreadingFile = Join-Path $generatedSrcRoot "threading.cj"
$rootCfgFile = Join-Path $generatedPackageRoot "cfg.toml"
$rootFeaturesFile = Join-Path $generatedPackageRoot "features.toml"
$rootLinkOptionsFile = Join-Path $generatedPackageRoot "link-options.toml"
$legacyCfgFile = Join-Path $generatedSrcRoot "cfg.toml"
$legacyFeaturesFile = Join-Path $generatedSrcRoot "features.toml"
$legacyLinkOptionsFile = Join-Path $generatedSrcRoot "link-options.toml"

foreach ($path in @($foundationFile, $threadingFile)) {
    if (!(Test-Path $path)) {
        throw "Missing generated subpackage source file: $path"
    }
}

foreach ($path in @($legacyFoundationFile, $legacyThreadingFile)) {
    if (Test-Path $path) {
        throw "Legacy flat output should not be generated in src package mode: $path"
    }
}

foreach ($path in @($rootCfgFile, $rootFeaturesFile, $rootLinkOptionsFile)) {
    if (!(Test-Path $path)) {
        throw "Missing generated package-root artifact: $path"
    }
}

foreach ($path in @($legacyCfgFile, $legacyFeaturesFile, $legacyLinkOptionsFile)) {
    if (Test-Path $path) {
        throw "Subpackage package-mode artifacts should be written to package root, not src: $path"
    }
}

$foundation = Get-Content -Raw $foundationFile
$threading = Get-Content -Raw $threadingFile
$cfg = Get-Content -Raw $rootCfgFile

if ($foundation -notmatch '(?m)^package windows_sys\.win32_foundation$') {
    throw "Foundation subpackage declaration is incorrect"
}
if ($threading -notmatch '(?m)^package windows_sys\.win32_system_threading$') {
    throw "Threading subpackage declaration is incorrect"
}
if ($threading -notmatch '(?m)^import windows_sys\.win32_foundation\.\*$') {
    throw "Threading subpackage should import windows_sys.win32_foundation"
}
if ($foundation -notmatch '@When\[feat_windows_win32_foundation == "on"\]') {
    throw 'Foundation subpackage should gate namespace members with feat_windows_win32_foundation == "on"'
}
if ($foundation -notmatch '@When\[feat_kernel32 == "on"\]') {
    throw 'Foundation subpackage should gate DLL-linked members with feat_kernel32 == "on"'
}
if ($foundation -match '@CallingConv\[STDCALL\]\s*foreign\s*\{') {
    throw "Foundation subpackage should not emit unsupported @CallingConv[STDCALL] on foreign blocks"
}
if ($foundation -match '@CallingConv\[CDECL\]\s*public type') {
    throw "Foundation subpackage should not emit @CallingConv on CFunc aliases"
}
if ($cfg -notmatch '(?m)^feat_windows_win32_foundation = "on"$') {
    throw "cfg.toml should enable feat_windows_win32_foundation by default"
}
if ($cfg -notmatch '(?m)^feat_kernel32 = "on"$') {
    throw "cfg.toml should enable feat_kernel32 by default"
}

Write-Host "windows-bindgen subpackage projection smoke test passed."
