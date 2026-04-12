$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$output = Invoke-WindowsMetadataSmokeProgram -Name "writer" -Program @'
package windows_metadata_smoke_writer

import windows_metadata.*
import windows_metadata.writer.*
import std.collection.*

main(_args: Array<String>) {
    let outputPath = "./writer-smoke.winmd"
    let writer = WinmdWriter("WriterSmoke")

    let signature = MethodSignature()
    signature.returnType = MetadataType.Boolean
    signature.paramTypes.add(MetadataType.I32)

    writer.typeDef("Test", "Holder", TypeAttributes.Public)
    writer.methodDef("Check", signature, MethodAttributes.Public, MethodImplAttributes(0u16))
    let vectorSpec = writer.typeSpec("Test", "Vector", [MetadataType.I32])
    let vectorSpecAgain = writer.typeSpec("Test", "Vector", [MetadataType.I32])
    if (vectorSpec != vectorSpecAgain) {
        throw Exception("typespec dedup should return the same row")
    }
    writer.writeTo(outputPath)

    match (WinmdFile.read(outputPath)) {
        case Some(file) =>
            match (file.assemblyName()) {
                case Some(name) =>
                    if (name != "WriterSmoke") {
                        throw Exception("writer assembly name mismatch")
                    }
                case None =>
                    throw Exception("writer assembly name missing")
            }

            if (file.tables[TABLE_TYPE_DEF].len < 2) {
                throw Exception("writer type definitions missing")
            }
            if (file.tables[TABLE_METHOD_DEF].len != 1) {
                throw Exception("writer method definition count mismatch")
            }
            if (file.tables[TABLE_TYPE_SPEC].len != 1) {
                throw Exception("writer typespec count mismatch")
            }

            let files = ArrayList<WinmdFile>()
            files.add(file)
            let index = TypeIndex(files)
            if (!index.contains("Test", "Holder")) {
                throw Exception("writer type index entry missing")
            }
        case None =>
            throw Exception("failed to read writer output")
    }

    println("writer-ok")
}
'@

if ($output -notmatch "writer-ok") {
    throw "writer smoke output mismatch: $output"
}

Write-Host "writer smoke passed."
