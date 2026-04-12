$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$output = Invoke-WindowsMetadataSmokeProgram -Name "signatures" -Program @'
package windows_metadata_smoke_signatures

import windows_metadata.*
import std.collection.*

main(_args: Array<String>) {
    let file = WinmdFile(ByteReader([0u8, 1u8]))
    let sigBytes = [ELEMENT_TYPE_BOOLEAN]
    let sigReader = BlobReader(sigBytes, 0, Int64(sigBytes.size))
    match (sigReader.readTypeCode(file, [])) {
        case MetadataType.Boolean =>
            ()
        case _ =>
            throw Exception("primitive signature parse failed")
    }

    let packedTy = MetadataType.Packed(MetadataType.ValueName(TypeName.named("Windows.Win32.Foundation", "RECT")), 1u16)
    match (packedTy) {
        case MetadataType.Packed(MetadataType.ValueName(rectTy), 1u16) =>
            if (!rectTy.matches("Windows.Win32.Foundation", "RECT")) {
                throw Exception("packed type target mismatch")
            }
        case _ =>
            throw Exception("packed type construction failed")
    }

    let unionTy = MetadataType.Union(TypeName.named("Windows.Win32.System.Variant", "VARIANT"))
    match (unionTy) {
        case MetadataType.Union(unionName) =>
            if (!unionName.matches("Windows.Win32.System.Variant", "VARIANT")) {
                throw Exception("union type target mismatch")
            }
        case _ =>
            throw Exception("union type construction failed")
    }

    let valueBytes = [1u8]
    let valueReader = BlobReader(valueBytes, 0, Int64(valueBytes.size))
    match (readMetadataValue(valueReader, MetadataType.Boolean)) {
        case MetadataValue.ValBool(true) =>
            ()
        case _ =>
            throw Exception("bool value parse failed")
    }

    let surrogateBytes = [61u8, 216u8, 0u8, 222u8]
    let surrogateReader = BlobReader(surrogateBytes, 0, Int64(surrogateBytes.size))
    if (surrogateReader.readUtf16() != "${Rune(0x1F600u32)}") {
        throw Exception("utf16 surrogate pair decode failed")
    }

    let winmdPath = "E:/Project/CS_Project/2026/ling/windows-cj/winmd/Windows.Win32.winmd"
    match (WinmdFile.read(winmdPath)) {
        case Some(winmdFile) =>
            let files = ArrayList<WinmdFile>()
            files.add(winmdFile)
            let index = TypeIndex(files)
            let assocEntry = index.expect("Windows.Win32.Foundation.Metadata", "AssociatedConstantAttribute")
            let assocAttr = TypeDefRef(index, assocEntry[0], assocEntry[1])

            match (assocAttr.findAttribute("AttributeUsageAttribute")) {
                case Some(attrRow) =>
                    let values = index.attributeValues(assocAttr.fileIdx, attrRow)
                    if (Int64(values.size) != 2) {
                        throw Exception("attribute value count mismatch")
                    }
                    if (values[0][0] != "") {
                        throw Exception("expected positional argument marker to be empty")
                    }
                    match (values[0][1]) {
                        case MetadataValue.ValEnum(enumTy, MetadataValue.ValI32(16)) =>
                            if (!enumTy.matches("System", "AttributeTargets")) {
                                throw Exception("attribute positional enum type mismatch")
                            }
                        case _ =>
                            throw Exception("attribute positional argument mismatch")
                    }
                    if (values[1][0] != "AllowMultiple") {
                        throw Exception("attribute named argument name mismatch")
                    }
                    match (values[1][1]) {
                        case MetadataValue.ValBool(true) =>
                            println("signatures-ok")
                        case _ =>
                            throw Exception("attribute named argument value mismatch")
                    }
                case None =>
                    throw Exception("missing AttributeUsageAttribute")
            }
        case None =>
            throw Exception("failed to read winmd")
    }
}
'@

if ($output -notmatch "signatures-ok") {
    throw "signatures smoke output mismatch: $output"
}

Write-Host "signatures smoke passed."
