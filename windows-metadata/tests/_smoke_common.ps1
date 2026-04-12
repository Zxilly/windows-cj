$ErrorActionPreference = "Stop"

function New-WindowsMetadataSmokeProject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Program,
        [string[]]$SupportFiles = @()
    )

    $repoRoot = "E:/Project/CS_Project/2026/ling"
    $packageRoot = Join-Path $repoRoot "windows-cj/windows-metadata"
    $scratchRoot = Join-Path $env:TEMP "windows-metadata-smoke-$Name-$([Guid]::NewGuid().ToString('N'))"
    $srcRoot = Join-Path $scratchRoot "src"

    New-Item -ItemType Directory -Force $srcRoot | Out-Null

    $manifest = @"
[package]
  name = "windows_metadata_smoke_$Name"
  version = "0.1.0"
  output-type = "executable"
  cjc-version = "1.1.0"

[dependencies]
  windows_metadata = { path = "$($packageRoot -replace '\\', '/')" }
"@

    Set-Content -LiteralPath (Join-Path $scratchRoot "cjpm.toml") -Value $manifest -Encoding utf8
    Set-Content -LiteralPath (Join-Path $srcRoot "main.cj") -Value $Program -Encoding utf8
    foreach ($supportFile in $SupportFiles) {
        if (!(Test-Path $supportFile)) {
            throw "Missing smoke support file: $supportFile"
        }

        $supportName = [IO.Path]::GetFileName($supportFile)
        $supportContent = Get-Content -Raw $supportFile
        $supportContent = $supportContent.Replace("__SMOKE_PACKAGE__", "windows_metadata_smoke_$Name")
        Set-Content -LiteralPath (Join-Path $srcRoot $supportName) -Value $supportContent -Encoding utf8
    }

    return $scratchRoot
}

function Invoke-WindowsMetadataSmokeProgram {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Program,
        [string[]]$SupportFiles = @()
    )

    $scratchRoot = New-WindowsMetadataSmokeProject -Name $Name -Program $Program -SupportFiles $SupportFiles

    Push-Location $scratchRoot
    try {
        $prevErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $buildOutput = & cjpm build 2>&1 | Out-String
            $buildExitCode = $LASTEXITCODE
            $runOutput = & cjpm run 2>&1 | Out-String
            $runExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $prevErrorActionPreference
        }

        if ($buildExitCode -ne 0) {
            throw "cjpm build failed in $scratchRoot`n$buildOutput"
        }
        if ($buildOutput -notmatch "cjpm build success") {
            throw "cjpm build did not report success in $scratchRoot`n$buildOutput"
        }
        if ($runExitCode -ne 0) {
            throw "cjpm run failed in $scratchRoot`n$runOutput"
        }
        return $runOutput.Trim()
    }
    finally {
        Pop-Location
    }
}
