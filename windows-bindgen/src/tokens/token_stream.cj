package windows_bindgen.tokens

import std.collection.*

public class TokenStream {
    private let parts: ArrayList<String>

    public init() {
        this.parts = ArrayList<String>()
    }

    public static func fromString(value: String): TokenStream {
        let stream = TokenStream()
        stream.append(value)
        return stream
    }

    public func append(value: String): Unit {
        if (!value.isEmpty()) {
            parts.add(value)
        }
    }

    public func appendLine(value: String): Unit {
        parts.add("${value}\n")
    }

    public func appendBlankLine(): Unit {
        parts.add("\n")
    }

    public func appendSpace(): Unit {
        parts.add(" ")
    }

    public func appendTokens(other: TokenStream): Unit {
        append(other.toString())
    }

    public func combine(other: TokenStream): TokenStream {
        let result = TokenStream()
        result.appendTokens(this)
        result.appendTokens(other)
        return result
    }

    public func isEmpty(): Bool {
        parts.isEmpty()
    }

    public func toString(): String {
        let builder = StringBuilder()
        for (part in parts) {
            builder.append(part)
        }
        return builder.toString()
    }
}

public func joinTokenStreams(streams: ArrayList<TokenStream>, separator: String): TokenStream {
    let result = TokenStream()
    var first = true
    for (stream in streams) {
        if (!first && !separator.isEmpty()) {
            result.append(separator)
        }
        result.appendTokens(stream)
        first = false
    }
    return result
}

public func delimitedTokenStream(prefix: String, body: TokenStream, suffix: String): TokenStream {
    let result = TokenStream()
    result.append(prefix)
    result.appendTokens(body)
    result.append(suffix)
    return result
}
