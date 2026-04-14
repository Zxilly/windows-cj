package windows_bindgen

import std.collection.*

let CANGJIE_KEYWORDS = HashSet<String>([
    "as", "abstract", "break",
    "Bool", "case", "catch",
    "class", "const", "continue",
    "Rune", "do", "else",
    "enum", "extend", "for",
    "func", "false", "finally",
    "foreign", "Float16", "Float32",
    "Float64", "if", "in",
    "is", "init", "import",
    "interface", "Int8", "Int16",
    "Int32", "Int64", "IntNative",
    "let", "mut", "main",
    "macro", "match", "Nothing",
    "open", "operator", "override",
    "prop", "public", "package",
    "private", "protected", "quote",
    "redef", "return", "spawn",
    "super", "static", "struct",
    "synchronized", "try", "this",
    "true", "type", "throw",
    "This", "unsafe", "Unit",
    "UInt8", "UInt16", "UInt32",
    "UInt64", "UIntNative", "var",
    "VArray", "where", "while"
])

public func isCangjieKeyword(name: String): Bool {
    CANGJIE_KEYWORDS.contains(name)
}

// Sanitize a name to be a valid non-raw Cangjie identifier.
public func sanitizeIdentifier(name: String): String {
    if (name.isEmpty()) {
        return "_"
    }

    var result = name
    if (isCangjieKeyword(result)) {
        result = "${result}_"
    }

    let arr = result.toArray()
    if (arr.size > 0) {
        let first = arr[0]
        if (!((first >= b'a' && first <= b'z') || (first >= b'A' && first <= b'Z') || first == b'_')) {
            result = "_${result}"
        }
    }
    return result
}

// Package segments must be ordinary identifiers, so they use the same escape
// strategy as other generated identifiers rather than raw identifiers.
public func sanitizePackageSegment(name: String): String {
    return sanitizeIdentifier(name)
}

// Use raw identifiers for source-visible top-level names when they collide with
// keywords so generated APIs preserve WinMD names.
public func escapeSourceIdentifier(name: String): String {
    if (name.isEmpty()) {
        return "_"
    }
    if (isCangjieKeyword(name)) {
        return "`${name}`"
    }
    return sanitizeIdentifier(name)
}
