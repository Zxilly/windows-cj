$ErrorActionPreference = "Stop"

$repoRoot = "E:/Project/CS_Project/2026/ling"
$workRoot = Join-Path $repoRoot "windows-cj/windows-interface/tests/output/alignment_smoke/app"

Push-Location $workRoot
try {
    cjpm build | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm build failed"
    }

    $runOutput = cjpm run 2>&1 | Tee-Object -Variable interfaceAlignmentOutput | Out-String
    $interfaceAlignmentOutput | Out-Host
    if ($LASTEXITCODE -ne 0 -or $runOutput -match "An exception has occurred") {
        throw "cjpm run failed"
    }
}
finally {
    Pop-Location
}

Write-Host "windows-interface alignment smoke test passed."
