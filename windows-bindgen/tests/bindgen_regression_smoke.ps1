$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$fixtureWin32 = Join-Path $repoRoot "windows-cj/winmd/Windows.Win32.winmd"
$fixtureWinrt = Join-Path $repoRoot "windows-cj/winmd/Windows.winmd"
$outputRoot = Join-Path $packageRoot "tests/output/bindgen_regression"
$archOut = Join-Path $outputRoot "arch"
$structArchOut = Join-Path $outputRoot "struct_arch"
$packageRefOut = Join-Path $outputRoot "package_ref"
$flatPackageOut = Join-Path $outputRoot "flat_package"
$defaultRefsOut = Join-Path $outputRoot "default_refs"
$deriveOut = Join-Path $outputRoot "derive"
$coreDepsOut = Join-Path $outputRoot "core_deps"
$specificDepsOut = Join-Path $outputRoot "specific_deps"
$winrtDefaultOut = Join-Path $outputRoot "winrt_default"
$winrtImplementOut = Join-Path $outputRoot "winrt_implement"
$winrtImplementFalseOut = Join-Path $outputRoot "winrt_implement_false"
$warningOut = Join-Path $outputRoot "warnings"

if (!(Test-Path $fixtureWin32)) {
    throw "Missing fixture winmd: $fixtureWin32"
}
if (!(Test-Path $fixtureWinrt)) {
    throw "Missing fixture winmd: $fixtureWinrt"
}

if (Test-Path $outputRoot) {
    Remove-Item -Recurse -Force $outputRoot
}
New-Item -ItemType Directory -Force $outputRoot | Out-Null

Push-Location $packageRoot
try {
    cjpm build | Out-Host

    cjpm run -- `
        --in $fixtureWin32 `
        --out $archOut `
        --flat `
        --filter Windows.Win32.UI.WindowsAndMessaging | Out-Host

    $prevErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $structArchRun = & cjpm run -- `
            --in $fixtureWin32 `
            --out $structArchOut `
            --flat `
            --filter Windows.Win32.Devices.DeviceAndDriverInstallation 2>&1
    }
    finally {
        $ErrorActionPreference = $prevErrorActionPreference
    }
    $structArchRun | Out-Host

    cjpm run -- `
        --in $fixtureWinrt `
        --out $packageRefOut `
        --no-sys `
        --high-level `
        --package `
        --reference refpkg,skip-root,Windows.Foundation `
        --filter Windows.Storage | Out-Host

    cjpm run -- `
        --in $fixtureWin32 `
        --out $flatPackageOut `
        --flat `
        --sys `
        --package windows_sys `
        --filter Windows.Win32.Foundation `
        --filter Windows.Win32.System.SystemInformation | Out-Host

    cjpm run -- `
        --in $fixtureWinrt `
        --out $defaultRefsOut `
        --no-sys `
        --high-level `
        --package `
        --filter Windows.Storage | Out-Host

    cjpm run -- `
        --in $fixtureWinrt `
        --out $deriveOut `
        --flat `
        --no-sys `
        --high-level `
        --derive Windows.Foundation.DateTime=Eq,Hash `
        --derive Windows.Storage.FileAttributes=Eq,Hash `
        --filter Windows.Storage.IStorageItem | Out-Host

    cjpm run -- `
        --in $fixtureWin32 `
        --out $coreDepsOut `
        --flat `
        --no-sys `
        --high-level `
        --filter Windows.Win32.Storage.Packaging.Appx | Out-Host

    cjpm run -- `
        --in $fixtureWin32 `
        --out $specificDepsOut `
        --flat `
        --no-sys `
        --high-level `
        --specific-deps `
        --filter Windows.Win32.Storage.Packaging.Appx | Out-Host

    cjpm run -- `
        --in $fixtureWinrt `
        --out $winrtDefaultOut `
        --flat `
        --no-sys `
        --high-level `
        --filter Windows.Foundation | Out-Host

    cjpm run -- `
        --in $fixtureWinrt `
        --out $winrtImplementOut `
        --flat `
        --no-sys `
        --high-level `
        --implement `
        --filter Windows.Foundation | Out-Host

    cjpm run -- `
        --in $fixtureWinrt `
        --out $winrtImplementFalseOut `
        --flat `
        --no-sys `
        --high-level `
        --implement false `
        --filter Windows.Foundation | Out-Host

    $prevErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $warningRun = & cjpm run -- `
            --in $fixtureWinrt `
            --out $warningOut `
            --flat `
            --no-sys `
            --high-level `
            --no-deps `
            --filter Windows.Storage.IStorageItem 2>&1
    }
    finally {
        $ErrorActionPreference = $prevErrorActionPreference
    }
    $warningRun | Out-Host

    $invalidReferenceStdout = Join-Path $outputRoot "invalid_reference.stdout.log"
    $invalidReferenceStderr = Join-Path $outputRoot "invalid_reference.stderr.log"
    $invalidReferenceProcess = Start-Process `
        -FilePath "cjpm" `
        -ArgumentList @(
            "run",
            "--",
            "--in", $fixtureWinrt,
            "--out", (Join-Path $outputRoot "invalid_reference"),
            "--flat",
            "--no-sys",
            "--high-level",
            "--reference", "invalid",
            "--filter", "Windows.Storage.StorageFile"
        ) `
        -WorkingDirectory $packageRoot `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $invalidReferenceStdout `
        -RedirectStandardError $invalidReferenceStderr
    $invalidReferenceExitCode = $invalidReferenceProcess.ExitCode
    $invalidReferenceRun = @()
    if (Test-Path $invalidReferenceStdout) {
        $invalidReferenceRun += Get-Content -Raw $invalidReferenceStdout
    }
    if (Test-Path $invalidReferenceStderr) {
        $invalidReferenceRun += Get-Content -Raw $invalidReferenceStderr
    }
    $invalidReferenceRun | Out-Host
}
finally {
    Pop-Location
}

$windowsAndMessagingFile = Join-Path $archOut "WindowsAndMessaging.cj"
$deviceInstallFile = Join-Path $structArchOut "DeviceAndDriverInstallation.cj"
$storageFile = Join-Path $packageRefOut "src/Windows/Storage/mod.cj"
$flatPackageFoundationFile = Join-Path $flatPackageOut "Foundation.cj"
$flatPackageSystemInformationFile = Join-Path $flatPackageOut "SystemInformation.cj"
$defaultRefsStorageFile = Join-Path $defaultRefsOut "src/Windows/Storage/mod.cj"
$deriveStorageFile = Join-Path $deriveOut "Storage.cj"
$deriveFoundationFile = Join-Path $deriveOut "Foundation.cj"
$coreDepsAppxFile = Join-Path $coreDepsOut "Appx.cj"
$coreDepsFoundationFile = Join-Path $coreDepsOut "Foundation.cj"
$specificDepsAppxFile = Join-Path $specificDepsOut "Appx.cj"
$specificDepsFoundationFile = Join-Path $specificDepsOut "Foundation.cj"
$defaultRefsFoundationCollectionsFile = Join-Path $defaultRefsOut "src/Windows/Foundation/Collections/mod.cj"
$invalidReferenceStorageFile = Join-Path (Join-Path $outputRoot "invalid_reference") "Storage.cj"
$winrtDefaultFile = Join-Path $winrtDefaultOut "Foundation.cj"
$winrtImplementFile = Join-Path $winrtImplementOut "Foundation.cj"
$winrtImplementFalseFile = Join-Path $winrtImplementFalseOut "Foundation.cj"

foreach ($path in @($windowsAndMessagingFile, $deviceInstallFile, $storageFile, $flatPackageFoundationFile, $flatPackageSystemInformationFile, $defaultRefsStorageFile, $deriveStorageFile, $deriveFoundationFile, $coreDepsAppxFile, $specificDepsAppxFile, $winrtDefaultFile, $winrtImplementFile, $winrtImplementFalseFile)) {
    if (!(Test-Path $path)) {
        throw "Missing generated source file: $path"
    }
}

$windowsAndMessaging = Get-Content -Raw $windowsAndMessagingFile
$deviceInstall = Get-Content -Raw $deviceInstallFile
$storage = Get-Content -Raw $storageFile
$flatPackageFoundation = Get-Content -Raw $flatPackageFoundationFile
$flatPackageSystemInformation = Get-Content -Raw $flatPackageSystemInformationFile
$defaultRefsStorage = Get-Content -Raw $defaultRefsStorageFile
$deriveStorage = Get-Content -Raw $deriveStorageFile
$deriveFoundation = Get-Content -Raw $deriveFoundationFile
$coreDepsAppx = Get-Content -Raw $coreDepsAppxFile
$specificDepsFoundation = Get-Content -Raw $specificDepsFoundationFile
$specificDepsAppx = Get-Content -Raw $specificDepsAppxFile
$winrtDefault = Get-Content -Raw $winrtDefaultFile
$winrtImplement = Get-Content -Raw $winrtImplementFile
$winrtImplementFalse = Get-Content -Raw $winrtImplementFalseFile
$warningText = ($warningRun | Out-String)
$structArchText = ($structArchRun | Out-String)
$invalidReferenceText = ($invalidReferenceRun | Out-String)

if ($windowsAndMessaging -notmatch '(?s)@When\[USER32 == "on" && \(arch == "x86_64" \|\| arch == "aarch64"\)\].*?func GetWindowLongPtrA') {
    throw "GetWindowLongPtrA is missing the expected x86_64/arm64ec item-level cfg guard"
}
if ($windowsAndMessaging -notmatch '(?s)@When\[USER32 == "on" && \(arch == "x86_64" \|\| arch == "aarch64"\)\].*?func GetWindowLongPtrW') {
    throw "GetWindowLongPtrW is missing the expected x86_64/arm64ec item-level cfg guard"
}
if ($windowsAndMessaging -match '@When\[cfg\.') {
    throw "windows_and_messaging.cj still contains legacy cfg-based guards"
}

if ($deviceInstall -notmatch '(?s)@When\[Windows_Win32_Devices_DeviceAndDriverInstallation == "on" && \(arch == "x86_64" \|\| arch == "aarch64"\)\]\s*(?://[^\r\n]*\s*)*@C\s+public struct SP_CLASSINSTALL_HEADER') {
    throw "SP_CLASSINSTALL_HEADER is missing the expected x86_64/aarch64 type cfg guard"
}
if ($deviceInstall -match '@When\[cfg\.') {
    throw "device_and_driver_installation.cj still contains legacy cfg-based guards"
}
if ($deviceInstall -notmatch '(?s)// WARNING: union simulated as byte array \(size-equivalent, not type-safe\)\s*@C\s+public struct SP_ALTPLATFORM_INFO_V2__Anonymous_e__Union\s*\{\s*public var _raw: VArray<UInt16, \$1> = VArray<UInt16, \$1>\(repeat: 0\)') {
    throw "ExplicitLayout unions should use aligned raw storage in struct_arch output"
}
if ($deviceInstall -notmatch '(?s)public struct SP_ALTPLATFORM_INFO_V2__Anonymous_e__Union\s*\{.*?public func reserved\(\): UInt16') {
    throw "Simulated unions should expose accessors for their aligned views"
}
if ($deviceInstall -notmatch '// packed\(1\)') {
    throw "Packed structs should retain their packed(n) comments"
}
if ($structArchText -notmatch 'skipping packed layout') {
    throw "Packed layout warnings were not emitted"
}
if ($structArchText -notmatch 'simulating union layout') {
    throw "Union simulation warnings were not emitted"
}

if ($flatPackageFoundation -notmatch '(?s)// WARNING: union simulated as byte array \(size-equivalent, not type-safe\)\s*@C\s+public struct DECIMAL__Anonymous1_e__Union\s*\{\s*public var _raw: VArray<UInt16, \$1> = VArray<UInt16, \$1>\(repeat: 0\)') {
    throw "DECIMAL first union view should use aligned UInt16 raw storage"
}
if ($flatPackageFoundation -notmatch '(?s)public struct DECIMAL__Anonymous1_e__Union\s*\{.*?public func anonymous\(\): DECIMAL__Anonymous1_e__Union__Anonymous_e__Struct') {
    throw "DECIMAL first union view is missing the anonymous-struct accessor"
}
if ($flatPackageFoundation -notmatch '(?s)// WARNING: union simulated as byte array \(size-equivalent, not type-safe\)\s*@C\s+public struct DECIMAL__Anonymous2_e__Union\s*\{\s*public var _raw: VArray<UInt64, \$1> = VArray<UInt64, \$1>\(repeat: 0\)') {
    throw "DECIMAL second union view should use aligned UInt64 raw storage"
}
if ($flatPackageFoundation -notmatch '(?s)public struct DECIMAL__Anonymous2_e__Union\s*\{.*?public func lo64\(\): UInt64') {
    throw "DECIMAL second union view is missing the Lo64 accessor"
}
if ($windowsAndMessaging -notmatch '(?s)// WARNING: union simulated as byte array \(size-equivalent, not type-safe\)\s*@C\s+public struct MENUTEMPLATEEX__Anonymous_e__Union\s*\{\s*public var _raw: VArray<UInt32, \$6> = VArray<UInt32, \$6>\(repeat: 0\)') {
    throw "MENUTEMPLATEEX union should use aligned UInt32 raw storage"
}
if ($windowsAndMessaging -notmatch '(?s)public struct MENUTEMPLATEEX__Anonymous_e__Union\s*\{.*?public func menu\(\): MENUTEMPLATEEX__Anonymous_e__Union__Menu_e__Struct') {
    throw "MENUTEMPLATEEX union is missing the Menu accessor"
}
if ($windowsAndMessaging -notmatch '(?s)public struct MENUTEMPLATEEX__Anonymous_e__Union\s*\{.*?public func menuEx\(\): MENUTEMPLATEEX__Anonymous_e__Union__MenuEx_e__Struct') {
    throw "MENUTEMPLATEEX union is missing the MenuEx accessor"
}

if ($storage -notmatch '(?m)^package Windows\.Storage$') {
    throw "Generated package mode did not preserve the namespace-derived package name"
}
if ($flatPackageFoundation -notmatch '(?m)^package windows_sys$') {
    throw "Flat package override did not rewrite Foundation to package windows_sys"
}
if ($flatPackageSystemInformation -notmatch '(?m)^package windows_sys$') {
    throw "Flat package override did not rewrite SystemInformation to package windows_sys"
}
if ($flatPackageSystemInformation -match '(?m)^package Windows\.Win32\.System\.SystemInformation$') {
    throw "Flat package override still emitted namespace-derived package names"
}
if ($flatPackageSystemInformation -match '(?m)^import Windows\.Win32\.Foundation\.\*$') {
    throw "Flat package override still emitted namespace-derived Foundation imports"
}
if ($storage -notmatch 'refpkg\.Foundation') {
    throw "Generated WinRT projection did not rewrite referenced Windows.Foundation types"
}
if (Test-Path (Join-Path $packageRefOut "src/Windows/Foundation/mod.cj")) {
    throw "Package reference run should not generate Windows.Foundation packages that were mapped to references"
}
if (Test-Path $defaultRefsFoundationCollectionsFile) {
    throw "Default references should prevent local Windows.Foundation.Collections generation"
}
if ($defaultRefsStorage -notmatch 'windows_collections\.') {
    throw "Default references should rewrite Windows.Foundation.Collections dependencies"
}
if ($defaultRefsStorage -notmatch 'windows_future\.IAsync(Action|Operation)') {
    throw "Default references should rewrite Windows.Foundation async dependencies"
}

if ($deriveStorage -notmatch '(?m)^import std\.deriving\.\*$') {
    throw "Derived enum namespace is missing std.deriving import"
}
if ($deriveFoundation -notmatch '(?m)^import std\.deriving\.\*$') {
    throw "Derived struct namespace is missing std.deriving import"
}
if ($deriveStorage -notmatch '(?s)@Derive\[Equatable, Hashable\]\s*@C\s+public struct FileAttributes') {
    throw "Generated enum output did not inject the expected @Derive attributes"
}
if ($deriveFoundation -notmatch '(?s)@Derive\[Equatable, Hashable\]\s*@C\s+public struct DateTime') {
    throw "Generated struct output did not inject the expected @Derive attributes"
}
if ($coreDepsAppx -notmatch 'windows_core\.WIN32_ERROR') {
    throw "Default dependency naming should route WIN32_ERROR through windows_core"
}
if ($specificDepsAppx -notmatch 'windows_result\.WIN32_ERROR') {
    throw "specific-deps should route WIN32_ERROR through windows_result"
}
if ($specificDepsAppx -match 'windows_core\.WIN32_ERROR') {
    throw "specific-deps output still routes WIN32_ERROR through windows_core"
}
if ((Test-Path $coreDepsFoundationFile) -and ((Get-Content -Raw $coreDepsFoundationFile) -match '(?m)^(public struct WIN32_ERROR|public type NTSTATUS\b)')) {
    throw "Default dependency references should prevent local WIN32_ERROR/NTSTATUS generation"
}
if ((Test-Path $specificDepsFoundationFile) -and ($specificDepsFoundation -match '(?m)^(public struct WIN32_ERROR|public type NTSTATUS\b)')) {
    throw "specific-deps references should prevent local WIN32_ERROR/NTSTATUS generation"
}

if ($winrtDefault -notmatch 'public interface IClosable_Impl') {
    throw "Non-exclusive WinRT interfaces should emit implementation surfaces by default"
}
if ($winrtDefault -match '(?s)@CallingConv\[STDCALL\]\s*@C\s+public struct IClosableVtbl') {
    throw "WinRT vtable structs should not carry @CallingConv[STDCALL] annotations"
}
if ($winrtDefault -notmatch 'public static func new<Identity>\(offset!: Int64 = 0\): IClosableVtbl where Identity <: IClosable_Impl') {
    throw "Non-exclusive WinRT interfaces are missing generated vtbl builders"
}
if ($winrtDefault -notmatch '(?s)public class IClosable .*?public static func matches\(iid: GUID\): Bool') {
    throw "WinRT interfaces are missing generated matches methods"
}
if ($winrtDefault -match 'public interface IUriRuntimeClass_Impl') {
    throw "Exclusive WinRT interfaces should not emit implementation surfaces without --implement"
}
if ($winrtImplement -notmatch 'public interface IUriRuntimeClass_Impl') {
    throw "Exclusive WinRT interfaces should emit implementation surfaces when --implement is enabled"
}
if ($winrtImplementFalse -match 'public interface IUriRuntimeClass_Impl') {
    throw "Explicit --implement false should keep exclusive WinRT implementation surfaces disabled"
}
if ($winrtDefault -notmatch 'return defaultInterface\(\)\.AbsoluteUri\(\)') {
    throw "WinRT classes should project default interface methods from required interfaces"
}
if ($winrtDefault -notmatch 'return asIStringable\(\)\.ToString\(\)') {
    throw "WinRT classes should project methods from non-default required interfaces"
}
if ($winrtImplement -notmatch 'return defaultInterface\(\)\.AbsoluteUri\(\)') {
    throw "WinRT class default interface methods regressed under --implement"
}
if ($winrtImplementFalse -notmatch 'return defaultInterface\(\)\.AbsoluteUri\(\)') {
    throw "Explicit --implement false should not remove WinRT class projection methods"
}

if ($warningText -notmatch 'skipping `Windows\.Storage\.IStorageItem\.') {
    throw "Missing dependency warnings were not surfaced for filtered WinRT methods"
}
if (Test-Path (Join-Path $warningOut "System.cj")) {
    throw "no-deps should not generate dependency namespaces such as Windows.System"
}
if (Test-Path (Join-Path $warningOut "Streams.cj")) {
    throw "no-deps should not generate dependency namespaces such as Windows.Storage.Streams"
}
if ($invalidReferenceText -notmatch '--reference') {
    throw "Invalid --reference failure did not mention the bad reference format"
}
if ($invalidReferenceText -notmatch 'An exception has occurred') {
    throw "Invalid --reference input should stop generation with an exception"
}
if (Test-Path $invalidReferenceStorageFile) {
    throw "Invalid --reference input should fail before writing generated sources"
}

Write-Host "windows-bindgen regression smoke test passed."
