$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$output = Invoke-WindowsMetadataSmokeProgram -Name "reader" -Program @'
package windows_metadata_smoke_reader

import windows_metadata.*
import std.collection.*

main(_args: Array<String>) {
    let winmdPath = "E:/Project/CS_Project/2026/ling/windows-cj/winmd/Windows.Win32.winmd"
    match (WinmdFile.read(winmdPath)) {
        case Some(file) =>
            match (file.assemblyName()) {
                case Some(name) =>
                    println(name)
                case None =>
                    throw Exception("missing assembly name")
            }

            let files = ArrayList<WinmdFile>()
            files.add(file)
            let index = TypeIndex(files)
            if (!index.containsNamespace("Windows.Win32.Graphics.Direct3D10")) {
                throw Exception("missing namespace")
            }
            println("reader-ok")
        case None =>
            throw Exception("failed to read winmd")
    }
}
'@

if ($output -notmatch "reader-ok") {
    throw "reader smoke output mismatch: $output"
}

Write-Host "reader smoke passed."
