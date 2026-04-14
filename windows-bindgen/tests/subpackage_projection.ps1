$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$fixtureWin32 = Join-Path $repoRoot "windows-cj/winmd/Windows.Win32.winmd"
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
        --filter Windows.Win32.Security.Cryptography `
        --filter Windows.Win32.Security.Cryptography.Sip `
        --filter Windows.Win32.Security.Cryptography.Catalog | Out-Host
}
finally {
    Pop-Location
}

$foundationFile = Join-Path $generatedSrcRoot "Win32/Foundation/mod.cj"
$catalogImplFile = Join-Path $generatedSrcRoot "Win32/Security/Cryptography/impl/Catalog.cj"
$sipImplFile = Join-Path $generatedSrcRoot "Win32/Security/Cryptography/impl/Sip.cj"
$catalogFacadeFile = Join-Path $generatedSrcRoot "Win32/Security/Cryptography/Catalog/mod.cj"
$sipFacadeFile = Join-Path $generatedSrcRoot "Win32/Security/Cryptography/Sip/mod.cj"
$rootModFile = Join-Path $generatedSrcRoot "mod.cj"
$win32ModFile = Join-Path $generatedSrcRoot "Win32/mod.cj"
$securityModFile = Join-Path $generatedSrcRoot "Win32/Security/mod.cj"
$cryptographyModFile = Join-Path $generatedSrcRoot "Win32/Security/Cryptography/mod.cj"
$implModFile = Join-Path $generatedSrcRoot "Win32/Security/Cryptography/impl/mod.cj"
$rootCfgFile = Join-Path $generatedPackageRoot "cfg.toml"
$rootFeaturesFile = Join-Path $generatedPackageRoot "features.toml"
$rootLinkOptionsFile = Join-Path $generatedPackageRoot "link-options.toml"
$legacyCfgFile = Join-Path $generatedSrcRoot "cfg.toml"
$legacyFeaturesFile = Join-Path $generatedSrcRoot "features.toml"
$legacyLinkOptionsFile = Join-Path $generatedSrcRoot "link-options.toml"

foreach ($path in @($foundationFile, $catalogImplFile, $sipImplFile, $catalogFacadeFile, $sipFacadeFile)) {
    if (!(Test-Path $path)) {
        throw "Missing generated source file: $path"
    }
}

foreach ($path in @($rootModFile, $win32ModFile, $securityModFile, $cryptographyModFile, $implModFile)) {
    if (!(Test-Path $path)) {
        throw "Missing generated package layer mod.cj: $path"
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
$catalogImpl = Get-Content -Raw $catalogImplFile
$sipImpl = Get-Content -Raw $sipImplFile
$catalogFacade = Get-Content -Raw $catalogFacadeFile
$sipFacade = Get-Content -Raw $sipFacadeFile
$cfg = Get-Content -Raw $rootCfgFile

if ($foundation -notmatch '(?m)^package windows_sys\.Win32\.Foundation$') {
    throw "Foundation direct package declaration is incorrect"
}
if ($catalogImpl -notmatch '(?m)^package windows_sys\.Win32\.Security\.Cryptography\.impl$') {
    throw "Catalog impl package declaration is incorrect"
}
if ($sipImpl -notmatch '(?m)^package windows_sys\.Win32\.Security\.Cryptography\.impl$') {
    throw "Sip impl package declaration is incorrect"
}
if ($catalogFacade -notmatch '(?m)^package windows_sys\.Win32\.Security\.Cryptography\.Catalog$') {
    throw "Catalog facade package declaration is incorrect"
}
if ($sipFacade -notmatch '(?m)^package windows_sys\.Win32\.Security\.Cryptography\.Sip$') {
    throw "Sip facade package declaration is incorrect"
}
if ($catalogFacade -notmatch '(?m)^public import windows_sys\.Win32\.Security\.Cryptography\.impl\.') {
    throw "Catalog facade should re-export from cryptography impl"
}
if ($sipFacade -notmatch '(?m)^public import windows_sys\.Win32\.Security\.Cryptography\.impl\.') {
    throw "Sip facade should re-export from cryptography impl"
}
if ($catalogFacade -match '(?m)^public struct ' -or $catalogFacade -match '(?m)^public enum ' -or $catalogFacade -match '(?m)^foreign\s*\{') {
    throw "Catalog facade must not contain real ABI definitions"
}
if ($sipFacade -match '(?m)^public struct ' -or $sipFacade -match '(?m)^public enum ' -or $sipFacade -match '(?m)^foreign\s*\{') {
    throw "Sip facade must not contain real ABI definitions"
}
if ($foundation -notmatch '@When\[Windows_Win32_Foundation == "on"\]') {
    throw 'Foundation direct package should gate namespace members with Windows_Win32_Foundation == "on"'
}
if ($foundation -notmatch '@When\[KERNEL32 == "on"\]') {
    throw 'Foundation direct package should gate DLL-linked members with KERNEL32 == "on"'
}
if ($foundation -match '@CallingConv\[STDCALL\]\s*foreign\s*\{') {
    throw "Foundation direct package should not emit unsupported @CallingConv[STDCALL] on foreign blocks"
}
if ($foundation -match '@CallingConv\[CDECL\]\s*public type') {
    throw "Foundation direct package should not emit @CallingConv on CFunc aliases"
}
if ($cfg -notmatch '(?m)^Windows_Win32_Foundation = "on"$') {
    throw "cfg.toml should enable Windows_Win32_Foundation by default"
}
if ($cfg -notmatch '(?m)^KERNEL32 = "on"$') {
    throw "cfg.toml should enable KERNEL32 by default"
}
if (Get-ChildItem -Path $generatedSrcRoot -Recurse -Filter "__package__.cj" | Select-Object -First 1) {
    throw "__package__.cj stubs should not be generated"
}

Write-Host "windows-bindgen mixed direct/impl facade projection smoke test passed."
