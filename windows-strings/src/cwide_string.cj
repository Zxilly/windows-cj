package windows_strings

import std.collection.*

// CWideString — UTF-16 string helper for Win32-style interop.
public class CWideString <: Resource {
    private var data: Array<UInt16>
    private var closed: Bool = false

    public init(s: String) {
        data = encodeUtf16WithNull(s)
    }

    public init(data: Array<UInt16>) {
        this.data = data
    }

    public func length(): Int64 {
        utf16LogicalLength(data)
    }

    public func withPtr<R>(action: (CPointer<UInt16>) -> R): R {
        unsafe {
            let handle = acquireArrayRawData(data)
            try {
                action(handle.pointer)
            } finally {
                releaseArrayRawData(handle)
            }
        }
    }

    public static func fromPointer(ptr: CPointer<UInt16>): String {
        unsafe {
            if (ptr.isNull()) {
                return ""
            }
            var len: Int64 = 0
            while ((ptr + len).read() != 0u16) {
                len += 1
            }
            if (len == 0) {
                return ""
            }
            var utf16 = Array<UInt16>(len, repeat: 0u16)
            var i: Int64 = 0
            while (i < len) {
                utf16[i] = (ptr + i).read()
                i += 1
            }
            decodeUtf16(utf16)
        }
    }

    public static func literal(s: String): CWideString {
        CWideString(s)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        closed = true
    }
}

public func encodeUtf16WithNull(s: String): Array<UInt16> {
    let bytes = s.toArray()
    var units = ArrayList<UInt16>()
    var i: Int64 = 0
    var expected: Int64 = 0
    var codePoint: UInt32 = 0
    var minCodePoint: UInt32 = 0

    while (i < Int64(bytes.size)) {
        let ub = UInt32(bytes[i])
        if (expected == 0) {
            if (ub <= 0x7Fu32) {
                appendUtf16CodePoint(units, ub)
            } else if (ub >= 0xC2u32 && ub <= 0xDFu32) {
                expected = 1
                codePoint = ub & 0x1Fu32
                minCodePoint = 0x80u32
            } else if (ub >= 0xE0u32 && ub <= 0xEFu32) {
                expected = 2
                codePoint = ub & 0x0Fu32
                minCodePoint = 0x800u32
            } else if (ub >= 0xF0u32 && ub <= 0xF4u32) {
                expected = 3
                codePoint = ub & 0x07u32
                minCodePoint = 0x10000u32
            } else {
                appendUtf16CodePoint(units, 0xFFFDu32)
            }
        } else {
            if ((ub & 0xC0u32) != 0x80u32) {
                // Invalid continuation byte: emit replacement char and re-process current byte.
                appendUtf16CodePoint(units, 0xFFFDu32)
                expected = 0
                codePoint = 0u32
                minCodePoint = 0u32
                // Do NOT increment i — re-process this byte as a new sequence leader.
                continue
            }
            codePoint = (codePoint << 6) | (ub & 0x3Fu32)
            expected -= 1
            if (expected == 0) {
                if (codePoint < minCodePoint || codePoint > 0x10FFFFu32 ||
                    (codePoint >= 0xD800u32 && codePoint <= 0xDFFFu32)) {
                    appendUtf16CodePoint(units, 0xFFFDu32)
                } else {
                    appendUtf16CodePoint(units, codePoint)
                }
                codePoint = 0u32
                minCodePoint = 0u32
            }
        }
        i += 1
    }

    if (expected != 0) {
        appendUtf16CodePoint(units, 0xFFFDu32)
    }

    var result = Array<UInt16>(units.size + 1, repeat: 0u16)
    var idx: Int64 = 0
    while (idx < Int64(units.size)) {
        result[idx] = units[idx]
        idx += 1
    }
    result
}

func appendUtf16CodePoint(units: ArrayList<UInt16>, cp: UInt32): Unit {
    if (cp <= 0xFFFFu32) {
        units.add(UInt16(cp))
    } else {
        let adjusted = cp - 0x10000u32
        units.add(UInt16(0xD800u32 + (adjusted >> 10)))
        units.add(UInt16(0xDC00u32 + (adjusted & 0x3FFu32)))
    }
}
