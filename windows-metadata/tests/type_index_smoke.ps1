$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$output = Invoke-WindowsMetadataSmokeProgram -Name "type_index" -Program @'
package windows_metadata_smoke_type_index

import windows_metadata.*
import windows_metadata.writer.*
import std.collection.*

func manualMethodOwner(index: TypeIndex, fileIdx: Int64, methodRow: Int64): (String, String) {
    let file = index.getFile(fileIdx)
    let (typeStart, typeEnd) = file.typeDefRange()
    var typeRow = typeStart
    while (typeRow < typeEnd) {
        let (methodStart, methodEnd) = index.typeDefMethods(fileIdx, typeRow)
        if (methodStart <= methodRow && methodRow < methodEnd) {
            return (index.typeDefNamespace(fileIdx, typeRow), index.typeDefName(fileIdx, typeRow))
        }
        typeRow += 1
    }
    throw Exception("manual method owner not found")
}

main(_args: Array<String>) {
    let winmdPath = "E:/Project/CS_Project/2026/ling/windows-cj/winmd/Windows.Win32.winmd"
    match (WinmdFile.read(winmdPath)) {
        case Some(file) =>
            let files = ArrayList<WinmdFile>()
            files.add(file)
            let index = TypeIndex(files)
            if (!index.containsNamespace("Windows.Win32.Graphics.Direct3D12")) {
                throw Exception("missing namespace")
            }
            let rows = index.get("Windows.Win32.Graphics.Direct3D12", "ID3D12Device10")
            if (rows.isEmpty()) {
                throw Exception("missing type index entry")
            }
            let typeRef = TypeDefRef(index, rows[0][0], rows[0][1])
            let methods = typeRef.methods()
            if (methods.isEmpty()) {
                throw Exception("missing methods for owner smoke")
            }

            let firstMethod = methods[0]
            let (firstExpectedNamespace, firstExpectedName) = manualMethodOwner(index, firstMethod.fileIdx, firstMethod.row)
            if (firstMethod.owner().namespace() != firstExpectedNamespace || firstMethod.owner().name() != firstExpectedName) {
                throw Exception("first method owner mismatch")
            }

            let lastMethod = methods[methods.size - 1]
            let (lastExpectedNamespace, lastExpectedName) = manualMethodOwner(index, lastMethod.fileIdx, lastMethod.row)
            if (lastMethod.owner().namespace() != lastExpectedNamespace || lastMethod.owner().name() != lastExpectedName) {
                throw Exception("last method owner mismatch")
            }
        case None =>
            throw Exception("failed to read winmd")
    }

    let windowsWinmdPath = "E:/Project/CS_Project/2026/ling/windows-cj/winmd/Windows.winmd"
    match (WinmdFile.read(windowsWinmdPath)) {
        case Some(windowsFile) =>
            let files = ArrayList<WinmdFile>()
            files.add(windowsFile)
            let index = TypeIndex(files)
            let typeSpec = TypeSpec(index, 0, 4)

            match (typeSpec.ty()) {
                case MetadataType.ClassName(tn) =>
                    if (!tn.matches("Windows.Foundation.Collections", "IIterable")) {
                        throw Exception("typespec root name mismatch")
                    }
                    if (Int64(tn.generics.size) != 1) {
                        throw Exception("typespec generic arity mismatch")
                    }
                    match (tn.generics[0]) {
                        case MetadataType.ClassName(inner) =>
                            if (!inner.matches("Windows.Foundation.Collections", "IKeyValuePair")) {
                                throw Exception("typespec nested generic mismatch")
                            }
                        case _ =>
                            throw Exception("typespec nested generic kind mismatch")
                    }
                case _ =>
                    throw Exception("typespec parse mismatch")
            }

            let syntheticPath = "type_index_method_attr.winmd"
            let writer = WinmdWriter("type_index_smoke")
            let _attributeType = writer.typeDef("Smoke", "SyntheticAttribute", TypeAttributes.Public)
            let ctorSig = MethodSignature()
            ctorSig.flags = MethodCallAttributes.HASTHIS.value
            ctorSig.returnType = MetadataType.Void
            let ctorRow = writer.methodDef(".ctor", ctorSig, MethodAttributes.Public, MethodImplAttributes(0u16))
            let targetType = writer.typeDef("Smoke", "SyntheticTarget", TypeAttributes.Public)
            writer.attribute(TABLE_TYPE_DEF, targetType, TABLE_METHOD_DEF, ctorRow, ArrayList<(String, MetadataValue)>())
            writer.writeTo(syntheticPath)

            match (WinmdFile.read(syntheticPath)) {
                case Some(syntheticFile) =>
                    let syntheticFiles = ArrayList<WinmdFile>()
                    syntheticFiles.add(syntheticFile)
                    let syntheticIndex = TypeIndex(syntheticFiles)
                    let attrs = syntheticIndex.getAttributesFor(TABLE_TYPE_DEF, 0, targetType)
                    if (attrs.size != 1) {
                        throw Exception("synthetic method-backed attribute count mismatch")
                    }
                    if (syntheticIndex.attributeNamespace(0, attrs[0]) != "Smoke") {
                        throw Exception("method-backed attribute namespace mismatch")
                    }
                    if (syntheticIndex.attributeName(0, attrs[0]) != "SyntheticAttribute") {
                        throw Exception("method-backed attribute name mismatch")
                    }
                case None =>
                    throw Exception("failed to read synthetic method-backed attribute winmd")
            }

            println("type-index-ok")
        case None =>
            throw Exception("failed to read windows winmd")
    }
}
'@

if ($output -notmatch "type-index-ok") {
    throw "type index smoke output mismatch: $output"
}

Write-Host "type index smoke passed."
