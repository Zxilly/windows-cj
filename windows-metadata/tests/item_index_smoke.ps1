$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$output = Invoke-WindowsMetadataSmokeProgram -Name "item_index" -Program @'
package windows_metadata_smoke_item_index

import windows_metadata.*
import std.collection.*

main(_args: Array<String>) {
    let winmdPath = "E:/Project/CS_Project/2026/ling/windows-cj/winmd/Windows.Win32.winmd"
    match (WinmdFile.read(winmdPath)) {
        case Some(file) =>
            let files = ArrayList<WinmdFile>()
            files.add(file)
            let index = TypeIndex(files)
            let items = ItemIndex(index)

            let fnItems = items.get("Windows.Win32.Graphics.Direct3D11", "D3D11CreateDevice")
            if (Int64(fnItems.size) != 1) {
                throw Exception("function item lookup returned wrong count")
            }
            match (items.expect("Windows.Win32.Graphics.Direct3D11", "D3D11CreateDevice")) {
                case Item.Fn(method) =>
                    if (method.name() != "D3D11CreateDevice") {
                        throw Exception("function item lookup returned wrong method")
                    }
                case _ =>
                    throw Exception("missing function item")
            }

            match (items.expect("Windows.Win32.Graphics.Direct3D11", "D3D11_16BIT_INDEX_STRIP_CUT_VALUE")) {
                case Item.Const(field) =>
                    if (field.name() != "D3D11_16BIT_INDEX_STRIP_CUT_VALUE") {
                        throw Exception("constant item lookup returned wrong field")
                    }
                case _ =>
                    throw Exception("missing constant item")
            }

            match (items.expect("Windows.Win32.Graphics.Direct3D11", "ID3D11Device")) {
                case Item.Type(ty) =>
                    if (ty.name() != "ID3D11Device") {
                        throw Exception("type item lookup returned wrong type")
                    }
                case _ =>
                    throw Exception("missing type item")
            }

            if (!items.get("Windows.Win32.Graphics.Direct3D11", "DefinitelyMissing").isEmpty()) {
                throw Exception("unexpected item for missing symbol")
            }

            var seenFunction = false
            var seenConstant = false
            for (item in items.items()) {
                match (item) {
                    case Item.Fn(method) =>
                        if (method.name() == "D3D11CreateDevice") {
                            seenFunction = true
                        }
                    case Item.Const(field) =>
                        if (field.name() == "D3D11_16BIT_INDEX_STRIP_CUT_VALUE") {
                            seenConstant = true
                        }
                    case _ => ()
                }
            }
            if (!seenFunction || !seenConstant) {
                throw Exception("items() is missing expected entries")
            }

            var namespaceFn = false
            var namespaceType = false
            for ((name, item) in items.namespace_items("Windows.Win32.Graphics.Direct3D11")) {
                match (item) {
                    case Item.Fn(method) =>
                        if (name == "D3D11CreateDevice" && method.name() == "D3D11CreateDevice") {
                            namespaceFn = true
                        }
                    case Item.Type(ty) =>
                        if (name == "ID3D11Device" && ty.name() == "ID3D11Device") {
                            namespaceType = true
                        }
                    case _ => ()
                }
            }
            if (!namespaceFn || !namespaceType) {
                throw Exception("namespace_items() is missing expected namespace entries")
            }

            println("item-index-ok")
        case None =>
            throw Exception("failed to read winmd")
    }
}
'@

if ($output -notmatch "item-index-ok") {
    throw "item index smoke output mismatch: $output"
}

Write-Host "item index smoke passed."
