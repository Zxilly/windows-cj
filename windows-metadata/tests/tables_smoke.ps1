$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$output = Invoke-WindowsMetadataSmokeProgram -Name "tables" -Program @'
package windows_metadata_smoke_tables

import windows_metadata.*
import std.collection.*

main(_args: Array<String>) {
    let compact = codedIndexSize([1, 1, 1])
    if (compact != 2) {
        throw Exception("unexpected coded index size")
    }

    let table = Table()
    table.len = 3
    if (table.indexWidth() != 2) {
        throw Exception("unexpected index width")
    }

    let encoded = encodeCodedIndex(2, 5, CODED_TYPE_DEF_OR_REF_BITS)
    let decoded = decodeCodedIndex(encoded, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)
    if (decoded[0] != TABLE_TYPE_SPEC || decoded[1] != 5) {
        throw Exception("coded index round-trip failed")
    }

    let winmdPath = "E:/Project/CS_Project/2026/ling/windows-cj/winmd/Windows.Win32.winmd"
    match (WinmdFile.read(winmdPath)) {
        case Some(file) =>
            let attrBlob = file.getBlob(0, TABLE_ATTRIBUTE, 2)
            let prolog = attrBlob.readU16()
            if (prolog != 1u16) {
                throw Exception("unexpected attribute blob prolog")
            }
            let osPlatform = attrBlob.readUtf8()
            if (osPlatform != "windows8.0") {
                throw Exception("unexpected attribute blob text")
            }

            let sigBlob = file.getBlob(0, TABLE_METHOD_DEF, 4)
            let sigFlags = sigBlob.readU8()
            let paramCount = sigBlob.readCompressed()
            if (sigFlags != 0u8) {
                throw Exception("unexpected method signature flags")
            }
            if (paramCount != 1) {
                throw Exception("unexpected method signature parameter count")
            }

            let files = ArrayList<WinmdFile>()
            files.add(file)
            let index = TypeIndex(files)

            let assocEntry = index.expect("Windows.Win32.Foundation.Metadata", "AssociatedConstantAttribute")
            let assocAttr = TypeDefRef(index, assocEntry[0], assocEntry[1])
            if (!assocAttr.hasAttribute("AttributeUsageAttribute")) {
                throw Exception("expected attribute lookup to succeed")
            }
            if (assocAttr.findAttribute("DefinitelyMissing").isSome()) {
                throw Exception("unexpected attribute lookup hit")
            }

            let archEntries = index.get("Windows.Win32.System.Kernel", "SLIST_HEADER")
            if (archEntries.isEmpty()) {
                throw Exception("missing architecture sample type")
            }
            let archType = TypeDefRef(index, archEntries[0][0], archEntries[0][1])
            if (archType.arches() == "0") {
                throw Exception("supported architecture parse mismatch")
            }
        case None =>
            throw Exception("failed to read winmd")
    }

    println("tables-ok")
}
'@

if ($output -notmatch "tables-ok") {
    throw "tables smoke output mismatch: $output"
}

Write-Host "tables smoke passed."
