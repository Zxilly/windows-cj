$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$output = Invoke-WindowsMetadataSmokeProgram -Name "attributes" -Program @'
package windows_metadata_smoke_attributes

import windows_metadata.*

main(_args: Array<String>) {
    if (!TypeAttributes.Public.contains(TypeAttributes.Public)) {
        throw Exception("type attribute contains failed")
    }
    if (!TypeAttributes.NestedPublic.isNested()) {
        throw Exception("type attribute nested detection failed")
    }
    if (!MethodAttributes.Public.contains(MethodAttributes.Public)) {
        throw Exception("method attribute contains failed")
    }
    if (!ParamAttributes.Optional.contains(ParamAttributes.Optional)) {
        throw Exception("param attribute contains failed")
    }

    println("attributes-ok")
}
'@

if ($output -notmatch "attributes-ok") {
    throw "attributes smoke output mismatch: $output"
}

Write-Host "attributes smoke passed."
