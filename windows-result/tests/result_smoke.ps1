$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$packagePath = ($packageRoot -replace '\\', '/')
$outputRoot = Join-Path $packageRoot "tests/output/result_smoke"
$bindingsSourcePath = Join-Path $packageRoot "src/bindings.cj"
$comSourcePath = Join-Path $packageRoot "src/com.cj"
$bstrSourcePath = Join-Path $packageRoot "src/bstr.cj"
$panicSourcePath = Join-Path $packageRoot "src/panic.cj"

function Reset-Directory([string]$Path) {
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
    }
    New-Item -ItemType Directory -Force $Path | Out-Null
}

function Write-TestPackage([string]$Root, [string]$Name, [string]$MainSource) {
    $srcRoot = Join-Path $Root "src"
    Reset-Directory $srcRoot

    $manifest = @"
[package]
  name = "$Name"
  version = "0.1.0"
  output-type = "executable"
  cjc-version = "1.1.0"
  compile-option = "-loleaut32 -lwindowsapp"

[dependencies]
  windows_result = { path = "$packagePath" }
"@

    Set-Content -Path (Join-Path $Root "cjpm.toml") -Value $manifest -NoNewline
    Set-Content -Path (Join-Path $srcRoot "main.cj") -Value $MainSource -NoNewline
}

function Invoke-Cjpm([string]$Root, [string[]]$Arguments, [bool]$ExpectSuccess = $true) {
    Push-Location $Root
    try {
        $stdoutPath = [System.IO.Path]::GetTempFileName()
        $stderrPath = [System.IO.Path]::GetTempFileName()
        try {
            $process = Start-Process -FilePath "cjpm" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
            $stdoutText = if (Test-Path $stdoutPath) { Get-Content -Raw $stdoutPath } else { "" }
            $stderrText = if (Test-Path $stderrPath) { Get-Content -Raw $stderrPath } else { "" }
            $captured = $stdoutText + $stderrText
            if ($captured.Length -gt 0) {
                $captured | Out-Host
            }
            $exitCode = $process.ExitCode
        } finally {
            Remove-Item $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
        }
    } finally {
        Pop-Location
    }

    if ($ExpectSuccess -and $exitCode -ne 0) {
        throw "cjpm $($Arguments -join ' ') failed"
    }
    if (-not $ExpectSuccess -and $exitCode -eq 0) {
        throw "cjpm $($Arguments -join ' ') was expected to fail"
    }

    $captured
}

Reset-Directory $outputRoot
Reset-Directory (Join-Path $packageRoot "target/test-full")
Reset-Directory (Join-Path $packageRoot "target/test-slim")

$bindingsSource = Get-Content -Raw $bindingsSourcePath
if ($bindingsSource -notmatch '@CallingConv\[STDCALL\]' -and $bindingsSource -notmatch '@FastNative') {
    throw "bindings.cj should use direct foreign bindings with an explicit FFI annotation for Win32/COM entry points"
}
if ($bindingsSource -match 'func loadRuntimeModule\(|func resolveProc\(|func sysAllocStringLenProc\(|func roOriginateErrorWProc\(') {
    throw "bindings.cj should not keep dynamic LoadLibrary/GetProcAddress shims for BSTR/COM error APIs"
}
if ($bindingsSource -notmatch '@When\[\(?os == "Windows"') {
    throw "bindings.cj should be protected by Windows-only conditional compilation"
}

$comSource = Get-Content -Raw $comSourcePath
if ($comSource -notmatch '@When\[\(?os == "Windows"') {
    throw "com.cj should be protected by Windows-only conditional compilation"
}

$bstrSource = Get-Content -Raw $bstrSourcePath
if ($bstrSource -notmatch '@When\[\(?os == "Windows"') {
    throw "bstr.cj should be protected by Windows-only conditional compilation"
}

$panicSource = Get-Content -Raw $panicSourcePath
if ($panicSource -match 'eprintln\s*\(') {
    throw "panic.cj should not simulate panic with eprintln + exit"
}

$publicAppRoot = Join-Path $outputRoot "public_app"
$hiddenApiRoot = Join-Path $outputRoot "hidden_api"
$abortProbeRoot = Join-Path $outputRoot "abort_probe"

$publicAppMain = @'
package result_smoke_public_app

import windows_result.*
import windows_result.Error as WinError

foreign func SetLastError(dwErrCode: UInt32): Unit

func expect(condition: Bool, message: String): Unit {
    if (!condition) {
        throw Exception(message)
    }
}

main(): Unit {
    let loadFlags: LOAD_LIBRARY_FLAGS = LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
    expect(loadFlags == LOAD_LIBRARY_SEARCH_DEFAULT_DIRS, "LOAD_LIBRARY_FLAGS should be public")

    let accessDenied = HRESULT.fromWin32(5u32)
    expect(accessDenied == E_ACCESSDENIED, "HRESULT.fromWin32 should preserve public HRESULT behavior")

    let boolFalse = BOOL(false)
    unsafe { SetLastError(5u32) }
    let boolResult = boolFalse.ok()
    expect(boolResult.isErr(), "BOOL.ok() should produce Err on FALSE")

    let win32 = WIN32_ERROR(5u32)
    expect(win32.toHRESULT() == accessDenied, "WIN32_ERROR.toHRESULT should remain public")
    expect(WinError.from(win32).code() == accessDenied, "Error.from(WIN32_ERROR) should remain public")

    let nt = NTSTATUS(-1073741819i32)
    expect(nt.toHRESULT().message() != "", "NTSTATUS-backed HRESULT.message() should still resolve system text")

    let rpc = RPC_STATUS(5i32)
    expect(rpc.toHRESULT() == accessDenied, "RPC_STATUS should map through FACILITY_WIN32")

    let customError = WinError.new(E_FAIL, "public custom failure")
    expect(customError.code() == E_FAIL, "Error.new should preserve HRESULT")
    expect(customError.message() == "public custom failure", "Error.new should surface custom text in full mode")

    customError.intoThread()
    let roundTripped = WinError.fromHRESULTWithInfo(E_FAIL)
    expect(roundTripped.as_ptr().isNotNull(), "Error.fromHRESULTWithInfo should keep COM error info in full mode")
    expect(roundTripped.message() == "public custom failure", "Error.fromHRESULTWithInfo should recover thread error info")

    let okResult = Result<Int32>.Ok(7i32)
    let errResult = Result<Int32>.Err(WinError.fromHRESULT(E_FAIL))
    expect(okResult.unwrap() == 7i32, "Result.unwrap() should return the success value")
    expect(errResult.unwrapErr().code() == E_FAIL, "Result.unwrapErr() should return the stored Error")
}
'@

$hiddenApiMain = @'
package result_smoke_hidden_api

import windows_result.*
import windows_result.Error as WinError

main(): Unit {
    let _ = GUID.zeroed()
    let _ = BasicString()
    let _ = HeapString()
    let _ = ComHandle<IUnknown>(CPointer<IUnknown>())
    let _ = IUnknownVtbl()
    let _ = WindowsException(WinError.fromHRESULT(E_FAIL))
}
'@

$abortProbeMain = @'
package result_smoke_abort_probe

import windows_result.*
import windows_result.Error as WinError

main(): Unit {
    try {
        let _ = Result<Int32>.Err(WinError.fromHRESULT(E_FAIL)).unwrap()
        println("returned")
    } catch (_: Exception) {
        println("caught")
    }
}
'@

Write-TestPackage $publicAppRoot "result_smoke_public_app" $publicAppMain
Write-TestPackage $hiddenApiRoot "result_smoke_hidden_api" $hiddenApiMain
Write-TestPackage $abortProbeRoot "result_smoke_abort_probe" $abortProbeMain

Invoke-Cjpm $packageRoot @("test", "--no-run", "--target-dir", "target/test-full")
Invoke-Cjpm $packageRoot @("test", "--skip-build", "--target-dir", "target/test-full")
Invoke-Cjpm $packageRoot @("test", "--slim", "--no-run", "--target-dir", "target/test-slim")
Invoke-Cjpm $packageRoot @("test", "--slim", "--skip-build", "--target-dir", "target/test-slim")

Invoke-Cjpm $publicAppRoot @("build")
$publicRunOutput = Invoke-Cjpm $publicAppRoot @("run")
if ($publicRunOutput -match "An exception has occurred") {
    throw "public smoke app threw an exception"
}

$hiddenBuildOutput = Invoke-Cjpm $hiddenApiRoot @("build") $false
if ($hiddenBuildOutput -notmatch "undeclared|cannot access|inaccessible|undefined") {
    throw "hidden API probe failed for an unexpected reason"
}

Invoke-Cjpm $abortProbeRoot @("build")
$abortRunOutput = Invoke-Cjpm $abortProbeRoot @("run")
if ($abortRunOutput -notmatch "caught") {
    throw "Result.unwrap() should now throw a catchable Exception on failure"
}
if ($abortRunOutput -match "returned|An exception has occurred") {
    throw "Result.unwrap() should throw exactly once and be catchable by Exception"
}

Write-Host "windows-result smoke test passed."
