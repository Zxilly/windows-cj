package windows_strings

public class NarrowStringFactory {
    private let data: Array<UInt8>

    public init(s: String) {
        data = encodeUtf8WithNull(s)
    }

    public func length(): Int64 {
        Int64(data.size) - 1
    }

    public func withPtr<R>(action: (PCSTR) -> R): R {
        unsafe {
            let handle = acquireArrayRawData(data)
            try {
                action(PCSTR.fromRaw(handle.pointer))
            } finally {
                releaseArrayRawData(handle)
            }
        }
    }
}

public class WideStringFactory {
    private let data: Array<UInt16>

    public init(s: String) {
        data = encodeUtf16WithNull(s)
    }

    public func length(): Int64 {
        utf16LogicalLength(data)
    }

    public func value(): CWideString {
        CWideString(copyWideArray(data))
    }

    public func withPtr<R>(action: (PCWSTR) -> R): R {
        unsafe {
            let handle = acquireArrayRawData(data)
            try {
                action(PCWSTR.fromRaw(handle.pointer))
            } finally {
                releaseArrayRawData(handle)
            }
        }
    }
}

public class HStringFactory {
    private let units: Array<UInt16>
    private var cachedValue: Option<HString> = None

    public init(s: String) {
        units = encodeUtf16Units(s)
    }

    public func length(): Int64 {
        Int64(units.size)
    }

    public func value(): HString {
        match (cachedValue) {
            case Some(value) =>
                if (!value.isClosed()) {
                    return value
                }
            case None => ()
        }
        let created = HString.fromReferenceWide(units)
        cachedValue = Some(created)
        created
    }

    public func withPtr<R>(action: (PCWSTR) -> R): R {
        let data = appendWideNull(units)
        unsafe {
            let handle = acquireArrayRawData(data)
            try {
                action(PCWSTR.fromRaw(handle.pointer))
            } finally {
                releaseArrayRawData(handle)
            }
        }
    }
}

public func wideStringFactory(s: String): WideStringFactory {
    WideStringFactory(s)
}

public func narrowStringFactory(s: String): NarrowStringFactory {
    NarrowStringFactory(s)
}

public func hStringFactory(s: String): HStringFactory {
    HStringFactory(s)
}

func encodeUtf8WithNull(s: String): Array<UInt8> {
    let bytes: Array<UInt8> = s.toArray()
    let length = Int64(bytes.size)
    var result = Array<UInt8>(length + 1, repeat: 0u8)
    var index: Int64 = 0
    while (index < length) {
        result[index] = bytes[index]
        index += 1
    }
    result
}

public func decodeUtf8Char(bytes: Array<UInt8>, pos: Int64): Option<(UInt32, Int64)> {
    if (pos >= bytes.size) {
        return None
    }

    var nextPos = pos + 1
    let ch = UInt32(bytes[pos])
    if (ch <= 0x7Fu32) {
        return Some((ch, nextPos))
    }
    if ((ch & 0xE0u32) == 0xC0u32) {
        if (bytes.size - pos < 2) {
            return None
        }
        let ch2 = UInt32(bytes[nextPos])
        nextPos += 1
        if ((ch2 & 0xC0u32) != 0x80u32) {
            return None
        }
        let result = ((ch & 0x1Fu32) << 6) | (ch2 & 0x3Fu32)
        if (result <= 0x7Fu32) {
            return None
        }
        return Some((result, nextPos))
    }
    if ((ch & 0xF0u32) == 0xE0u32) {
        if (bytes.size - pos < 3) {
            return None
        }
        let ch2 = UInt32(bytes[nextPos])
        nextPos += 1
        let ch3 = UInt32(bytes[nextPos])
        nextPos += 1
        if ((ch2 & 0xC0u32) != 0x80u32 || (ch3 & 0xC0u32) != 0x80u32) {
            return None
        }
        let result = ((ch & 0x0Fu32) << 12) | ((ch2 & 0x3Fu32) << 6) | (ch3 & 0x3Fu32)
        if (result <= 0x7FFu32 || (result >= 0xD800u32 && result <= 0xDFFFu32)) {
            return None
        }
        return Some((result, nextPos))
    }
    if ((ch & 0xF8u32) == 0xF0u32) {
        if (bytes.size - pos < 4) {
            return None
        }
        let ch2 = UInt32(bytes[nextPos])
        nextPos += 1
        let ch3 = UInt32(bytes[nextPos])
        nextPos += 1
        let ch4 = UInt32(bytes[nextPos])
        nextPos += 1
        if ((ch2 & 0xC0u32) != 0x80u32 ||
            (ch3 & 0xC0u32) != 0x80u32 ||
            (ch4 & 0xC0u32) != 0x80u32) {
            return None
        }
        let result =
            ((ch & 0x07u32) << 18) | ((ch2 & 0x3Fu32) << 12) | ((ch3 & 0x3Fu32) << 6) | (ch4 & 0x3Fu32)
        if (result <= 0xFFFFu32 || result > 0x10FFFFu32) {
            return None
        }
        return Some((result, nextPos))
    }
    None
}

public func utf16Len(bytes: Array<UInt8>): Int64 {
    var pos: Int64 = 0
    var len: Int64 = 0
    while (true) {
        match (decodeUtf8Char(bytes, pos)) {
            case Some(decoded) =>
                let (codePoint, newPos) = decoded
                pos = newPos
                len += if (codePoint <= 0xFFFFu32) { 1 } else { 2 }
            case None =>
                break
        }
    }
    return len
}

// Convenience literal helpers used by higher-level wrappers.
public func wideStringLiteral(s: String): CWideString {
    wideStringFactory(s).value()
}

public func pcstrLiteral(s: String): NarrowStringFactory {
    narrowStringFactory(s)
}

public func hStringLiteral(s: String): HString {
    hStringFactory(s).value()
}
