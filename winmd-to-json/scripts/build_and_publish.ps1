<#
.SYNOPSIS
    Build and publish winmd-to-json self-contained exe.

.DESCRIPTION
    Runs `dotnet publish -c Release` and verifies the output exe exists.
    Designed for Windows x64 host (matching the windows-cj target platform).

.PARAMETER Configuration
    Build configuration. Default: Release.

.EXAMPLE
    pwsh windows-cj/winmd-to-json/scripts/build_and_publish.ps1
#>
param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$projectFile = Join-Path $projectRoot "winmd-to-json.csproj"

if (-not (Test-Path $projectFile)) {
    throw "csproj not found: $projectFile"
}

Write-Host "Publishing $projectFile (Configuration=$Configuration)..."
& dotnet publish $projectFile -c $Configuration `
    -o (Join-Path $projectRoot "bin")

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

$expectedExe = Join-Path $projectRoot "bin/winmd-to-json.exe"
if (-not (Test-Path $expectedExe)) {
    throw "Expected published exe not found: $expectedExe"
}

Write-Host "OK: $expectedExe"
