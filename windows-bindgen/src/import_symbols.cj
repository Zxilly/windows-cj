package windows_bindgen

import std.collection.*
import std.fs.*
import std.process.*

let bundledGnuArchiveName = "libwindows.0.53.0.a"

public func loadBundledImportSymbols(): HashSet<String> {
    let symbols = HashSet<String>()
    let archive = findBundledGnuArchive()
    if (archive.isEmpty()) {
        return symbols
    }

    if (loadSymbolsWithTool("llvm-nm", archive, symbols)) {
        return symbols
    }
    loadSymbolsWithTool("nm", archive, symbols)
    return symbols
}

func findBundledGnuArchive(): String {
    let candidates = [
        "../windows-targets/x86_64_gnu/lib/${bundledGnuArchiveName}",
        "windows-targets/x86_64_gnu/lib/${bundledGnuArchiveName}",
        "../${bundledGnuArchiveName}",
        bundledGnuArchiveName
    ]
    for (candidate in candidates) {
        if (exists(candidate)) {
            return candidate
        }
    }
    return ""
}

func loadSymbolsWithTool(tool: String, archive: String, symbols: HashSet<String>): Bool {
    try {
        let (exitCode, stdout, _) = executeWithOutput(tool, [archive])
        if (exitCode != 0) {
            return false
        }
        for (line in symbolSplitLines(String.fromUtf8(stdout))) {
            addNmSymbol(symbols, line)
        }
        return true
    } catch (_: Exception) {
        return false
    }
}

func addNmSymbol(symbols: HashSet<String>, line: String): Unit {
    let token = lastToken(line)
    if (token.isEmpty()) {
        return
    }
    symbols.add(token)
    let importPrefix = "__imp_"
    if (symbolStartsWith(token, importPrefix)) {
        symbols.add(token[Int64(importPrefix.size)..Int64(token.size)])
    }
}

func lastToken(line: String): String {
    let trimmed = symbolTrimAscii(line)
    if (trimmed.isEmpty()) {
        return ""
    }

    let bytes = trimmed.toArray()
    var start: Int64 = Int64(bytes.size) - 1
    while (start >= 0 && !symbolIsAsciiSpace(bytes[start])) {
        start -= 1
    }
    return trimmed[(start + 1)..Int64(trimmed.size)]
}

func symbolSplitLines(text: String): ArrayList<String> {
    let bytes = text.toArray()
    let lines = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'\n') {
            let end = if (i > start && bytes[i - 1] == b'\r') { i - 1 } else { i }
            lines.add(String.fromUtf8(bytes[start..end]))
            start = i + 1
        }
        i += 1
    }
    if (start < Int64(bytes.size)) {
        let end = if (bytes[Int64(bytes.size) - 1] == b'\r') { Int64(bytes.size) - 1 } else { Int64(bytes.size) }
        lines.add(String.fromUtf8(bytes[start..end]))
    }
    return lines
}

func symbolTrimAscii(text: String): String {
    let bytes = text.toArray()
    var start: Int64 = 0
    var end = Int64(bytes.size)
    while (start < end && symbolIsAsciiSpace(bytes[start])) {
        start += 1
    }
    while (end > start && symbolIsAsciiSpace(bytes[end - 1])) {
        end -= 1
    }
    return String.fromUtf8(bytes[start..end])
}

func symbolIsAsciiSpace(ch: Byte): Bool {
    return ch == b' ' || ch == b'\t' || ch == b'\r' || ch == b'\n'
}

func symbolStartsWith(text: String, prefix: String): Bool {
    if (text.size < prefix.size) {
        return false
    }
    let textBytes = text.toArray()
    let prefixBytes = prefix.toArray()
    var i: Int64 = 0
    while (i < Int64(prefixBytes.size)) {
        if (textBytes[i] != prefixBytes[i]) {
            return false
        }
        i += 1
    }
    return true
}
