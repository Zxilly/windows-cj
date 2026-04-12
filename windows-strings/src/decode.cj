package windows_strings

/// A lightweight wrapper for values that should render via string interpolation.
public class StringDisplay <: ToString {
    private let text: String

    public init(text: String) {
        this.text = text
    }

    public func toString(): String {
        text
    }
}

func compareWideUnits(left: Array<UInt16>, right: Array<UInt16>): Ordering {
    let leftSize = left.size
    let rightSize = right.size
    let sharedSize = if (leftSize < rightSize) { leftSize } else { rightSize }
    var index: Int64 = 0
    while (index < sharedSize) {
        if (left[index] < right[index]) {
            return Ordering.LT
        }
        if (left[index] > right[index]) {
            return Ordering.GT
        }
        index += 1
    }
    if (leftSize < rightSize) {
        return Ordering.LT
    }
    if (leftSize > rightSize) {
        return Ordering.GT
    }
    Ordering.EQ
}

func hashWideUnits(units: Array<UInt16>): Int64 {
    const seed = 146959810i64
    const prime = 16777619i64
    const modulo = 2147483647i64
    var hash = seed
    for (unit in units) {
        hash = ((hash * prime) + Int64(unit)) % modulo
    }
    hash
}

public func utf16LogicalLength(utf16: Array<UInt16>): Int64 {
    var i: Int64 = 0
    let len = utf16.size
    while (i < len) {
        if (utf16[i] == 0u16) {
            return i
        }
        i += 1
    }
    len
}

public func narrowPointerLength(ptr: CPointer<UInt8>): Int64 {
    unsafe {
        if (ptr.isNull()) {
            return 0
        }
        var len: Int64 = 0
        while ((ptr + len).read() != 0u8) {
            len += 1
        }
        len
    }
}

public func widePointerLength(ptr: CPointer<UInt16>): Int64 {
    unsafe {
        if (ptr.isNull()) {
            return 0
        }
        var len: Int64 = 0
        while ((ptr + len).read() != 0u16) {
            len += 1
        }
        len
    }
}

public func copyWideArray(data: Array<UInt16>, length!: Int64 = -1): Array<UInt16> {
    let fullLength = Int64(data.size)
    var actualLength = length
    if (actualLength < 0 || actualLength > fullLength) {
        actualLength = fullLength
    }
    var result = Array<UInt16>(actualLength, repeat: 0u16)
    var index: Int64 = 0
    while (index < actualLength) {
        result[index] = data[index]
        index += 1
    }
    result
}

public func copyAnsiArray(data: Array<UInt8>, length!: Int64 = -1): Array<UInt8> {
    let fullLength = Int64(data.size)
    var actualLength = length
    if (actualLength < 0 || actualLength > fullLength) {
        actualLength = fullLength
    }
    var result = Array<UInt8>(actualLength, repeat: 0u8)
    var index: Int64 = 0
    while (index < actualLength) {
        result[index] = data[index]
        index += 1
    }
    result
}

public func appendWideNull(data: Array<UInt16>): Array<UInt16> {
    let len = Int64(data.size)
    var result = Array<UInt16>(len + 1, repeat: 0u16)
    var index: Int64 = 0
    while (index < len) {
        result[index] = data[index]
        index += 1
    }
    result
}

public func encodeUtf16Units(s: String): Array<UInt16> {
    let withNull = encodeUtf16WithNull(s)
    copyWideArray(withNull, length: Int64(withNull.size) - 1)
}

public func copyWideFromPointer(ptr: CPointer<UInt16>, length: Int64): Array<UInt16> {
    unsafe {
        if (ptr.isNull() || length <= 0) {
            return Array<UInt16>(0, repeat: 0u16)
        }
        var result = Array<UInt16>(length, repeat: 0u16)
        var index: Int64 = 0
        while (index < length) {
            result[index] = (ptr + index).read()
            index += 1
        }
        result
    }
}

public func copyAnsiFromPointer(ptr: CPointer<UInt8>, length: Int64): Array<UInt8> {
    unsafe {
        if (ptr.isNull() || length <= 0) {
            return Array<UInt8>(0, repeat: 0u8)
        }
        var result = Array<UInt8>(length, repeat: 0u8)
        var index: Int64 = 0
        while (index < length) {
            result[index] = (ptr + index).read()
            index += 1
        }
        result
    }
}

public func decodeWideFromPointer(ptr: CPointer<UInt16>, length!: Int64 = -1): String {
    var actualLength = length
    if (actualLength < 0) {
        actualLength = widePointerLength(ptr)
    }
    decodeUtf16(copyWideFromPointer(ptr, actualLength))
}

public func decodeAnsiFromPointer(ptr: CPointer<UInt8>, length!: Int64 = -1): String {
    var actualLength = length
    if (actualLength < 0) {
        actualLength = narrowPointerLength(ptr)
    }
    decodeUtf8Lossy(copyAnsiFromPointer(ptr, actualLength))
}

public func tryDecodeAnsiFromPointer(ptr: CPointer<UInt8>, length!: Int64 = -1): Option<String> {
    var actualLength = length
    if (actualLength < 0) {
        actualLength = narrowPointerLength(ptr)
    }
    tryDecodeUtf8(copyAnsiFromPointer(ptr, actualLength))
}

// Decode a UTF-16 array into a Cangjie String.
public func decodeUtf16(utf16: Array<UInt16>): String {
    var result = ""
    var index: Int64 = 0
    let len = utf16.size
    while (index < len) {
        let unit = utf16[index]
        if (unit >= 0xD800u16 && unit <= 0xDBFFu16) {
            if (index + 1 < len) {
                let low = utf16[index + 1]
                if (low >= 0xDC00u16 && low <= 0xDFFFu16) {
                    let cp = 0x10000u32 + ((UInt32(unit) - 0xD800u32) << 10) + (UInt32(low) - 0xDC00u32)
                    result += "${Rune(cp)}"
                    index += 2
                } else {
                    result += "${Rune(0xFFFDu32)}"
                    index += 1
                }
            } else {
                result += "${Rune(0xFFFDu32)}"
                index += 1
            }
        } else if (unit >= 0xDC00u16 && unit <= 0xDFFFu16) {
            result += "${Rune(0xFFFDu32)}"
            index += 1
        } else {
            result += "${Rune(UInt32(unit))}"
            index += 1
        }
    }
    result
}

public func decodeUtf8Lossy(bytes: Array<UInt8>): String {
    var result = ""
    var index: Int64 = 0
    let len = Int64(bytes.size)
    while (index < len) {
        let first = UInt32(bytes[index])
        if (first <= 0x7Fu32) {
            result += "${Rune(first)}"
            index += 1
            continue
        }

        var expected: Int64 = 0
        var codePoint: UInt32 = 0u32
        var minCodePoint: UInt32 = 0u32
        if (first >= 0xC2u32 && first <= 0xDFu32) {
            expected = 1
            codePoint = first & 0x1Fu32
            minCodePoint = 0x80u32
        } else if (first >= 0xE0u32 && first <= 0xEFu32) {
            expected = 2
            codePoint = first & 0x0Fu32
            minCodePoint = 0x800u32
        } else if (first >= 0xF0u32 && first <= 0xF4u32) {
            expected = 3
            codePoint = first & 0x07u32
            minCodePoint = 0x10000u32
        } else {
            result += "${Rune(0xFFFDu32)}"
            index += 1
            continue
        }

        if (index + expected >= len) {
            break
        }

        var probe: Int64 = 1
        var valid = true
        while (probe <= expected) {
            let next = UInt32(bytes[index + probe])
            if ((next & 0xC0u32) != 0x80u32) {
                valid = false
                break
            }
            codePoint = (codePoint << 6) | (next & 0x3Fu32)
            probe += 1
        }

        if (!valid || codePoint < minCodePoint || codePoint > 0x10FFFFu32 ||
            (codePoint >= 0xD800u32 && codePoint <= 0xDFFFu32)) {
            result += "${Rune(0xFFFDu32)}"
            // Only replace the invalid sequence once. Valid continuation bytes
            // already consumed while probing should not be re-processed.
            index += probe
            continue
        }

        result += "${Rune(codePoint)}"
        index += expected + 1
    }
    result
}

public func tryDecodeUtf8(bytes: Array<UInt8>): Option<String> {
    var result = ""
    var index: Int64 = 0
    let len = Int64(bytes.size)
    while (index < len) {
        let first = UInt32(bytes[index])
        if (first <= 0x7Fu32) {
            result += "${Rune(first)}"
            index += 1
            continue
        }

        var expected: Int64 = 0
        var codePoint: UInt32 = 0u32
        var minCodePoint: UInt32 = 0u32
        if (first >= 0xC2u32 && first <= 0xDFu32) {
            expected = 1
            codePoint = first & 0x1Fu32
            minCodePoint = 0x80u32
        } else if (first >= 0xE0u32 && first <= 0xEFu32) {
            expected = 2
            codePoint = first & 0x0Fu32
            minCodePoint = 0x800u32
        } else if (first >= 0xF0u32 && first <= 0xF4u32) {
            expected = 3
            codePoint = first & 0x07u32
            minCodePoint = 0x10000u32
        } else {
            return None
        }

        if (index + expected >= len) {
            return None
        }

        var probe: Int64 = 1
        while (probe <= expected) {
            let next = UInt32(bytes[index + probe])
            if ((next & 0xC0u32) != 0x80u32) {
                return None
            }
            codePoint = (codePoint << 6) | (next & 0x3Fu32)
            probe += 1
        }

        if (codePoint < minCodePoint || codePoint > 0x10FFFFu32 ||
            (codePoint >= 0xD800u32 && codePoint <= 0xDFFFu32)) {
            return None
        }

        result += "${Rune(codePoint)}"
        index += expected + 1
    }
    Some(result)
}

// Lossless UTF-16 decoding: returns None if any invalid surrogate pair is detected.
public func tryDecodeUtf16(utf16: Array<UInt16>): Option<String> {
    var result = ""
    var index: Int64 = 0
    let len = utf16.size
    while (index < len) {
        let unit = utf16[index]
        if (unit >= 0xD800u16 && unit <= 0xDBFFu16) {
            // High surrogate: must be followed by low surrogate
            if (index + 1 >= len) {
                return None
            }
            let low = utf16[index + 1]
            if (low >= 0xDC00u16 && low <= 0xDFFFu16) {
                let cp = 0x10000u32 + ((UInt32(unit) - 0xD800u32) << 10) + (UInt32(low) - 0xDC00u32)
                result += "${Rune(cp)}"
                index += 2
            } else {
                // High surrogate not followed by low surrogate
                return None
            }
        } else if (unit >= 0xDC00u16 && unit <= 0xDFFFu16) {
            // Lone low surrogate
            return None
        } else {
            result += "${Rune(UInt32(unit))}"
            index += 1
        }
    }
    Some(result)
}

// Lossless UTF-16 decoding from pointer: returns None if any invalid surrogate pair is detected.
public func tryDecodeWideFromPointer(ptr: CPointer<UInt16>, length!: Int64 = -1): Option<String> {
    var actualLength = length
    if (actualLength < 0) {
        actualLength = widePointerLength(ptr)
    }
    tryDecodeUtf16(copyWideFromPointer(ptr, actualLength))
}
