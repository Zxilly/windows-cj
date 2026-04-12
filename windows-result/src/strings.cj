package windows_result

import std.collection.*

func appendUtf16CodePoint(units: ArrayList<UInt16>, codePoint: UInt32): Unit {
    if (codePoint <= 0xFFFFu32) {
        units.add(UInt16(codePoint))
    } else {
        let adjusted = codePoint - 0x10000u32
        units.add(UInt16(0xD800u32 + (adjusted >> 10)))
        units.add(UInt16(0xDC00u32 + (adjusted & 0x3FFu32)))
    }
}

func encodeUtf16WithNull(text: String): Array<UInt16> {
    let bytes = text.toArray()
    var units = ArrayList<UInt16>()
    var index: Int64 = 0
    var expected: Int64 = 0
    var codePoint: UInt32 = 0u32
    var minCodePoint: UInt32 = 0u32

    while (index < Int64(bytes.size)) {
        let byteValue = UInt32(bytes[index])
        if (expected == 0) {
            if (byteValue <= 0x7Fu32) {
                appendUtf16CodePoint(units, byteValue)
            } else if (byteValue >= 0xC2u32 && byteValue <= 0xDFu32) {
                expected = 1
                codePoint = byteValue & 0x1Fu32
                minCodePoint = 0x80u32
            } else if (byteValue >= 0xE0u32 && byteValue <= 0xEFu32) {
                expected = 2
                codePoint = byteValue & 0x0Fu32
                minCodePoint = 0x800u32
            } else if (byteValue >= 0xF0u32 && byteValue <= 0xF4u32) {
                expected = 3
                codePoint = byteValue & 0x07u32
                minCodePoint = 0x10000u32
            } else {
                appendUtf16CodePoint(units, 0xFFFDu32)
            }
        } else {
            if ((byteValue & 0xC0u32) != 0x80u32) {
                appendUtf16CodePoint(units, 0xFFFDu32)
                expected = 0
                codePoint = 0u32
                minCodePoint = 0u32
                continue
            }

            codePoint = (codePoint << 6) | (byteValue & 0x3Fu32)
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
        index += 1
    }

    if (expected != 0) {
        appendUtf16CodePoint(units, 0xFFFDu32)
    }

    var result = Array<UInt16>(units.size + 1, repeat: 0u16)
    var unitIndex: Int64 = 0
    while (unitIndex < Int64(units.size)) {
        result[unitIndex] = units[unitIndex]
        unitIndex += 1
    }
    result
}

func encodeUtf16Units(text: String): Array<UInt16> {
    let withNull = encodeUtf16WithNull(text)
    let logicalLength = Int64(withNull.size) - 1
    if (logicalLength <= 0) {
        return Array<UInt16>(0, repeat: 0u16)
    }

    var result = Array<UInt16>(logicalLength, repeat: 0u16)
    var index: Int64 = 0
    while (index < logicalLength) {
        result[index] = withNull[index]
        index += 1
    }
    result
}

func widePointerLength(ptr: CPointer<UInt16>): Int64 {
    unsafe {
        if (ptr.isNull()) {
            return 0
        }

        var length: Int64 = 0
        while ((ptr + length).read() != 0u16) {
            length += 1
        }
        length
    }
}

func copyWideFromPointer(ptr: CPointer<UInt16>, length: Int64): Array<UInt16> {
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

func decodeUtf16(units: Array<UInt16>): String {
    var result = ""
    var index: Int64 = 0
    let length = units.size

    while (index < length) {
        let unit = units[index]
        if (unit >= 0xD800u16 && unit <= 0xDBFFu16 && index + 1 < length) {
            let low = units[index + 1]
            if (low >= 0xDC00u16 && low <= 0xDFFFu16) {
                let codePoint = 0x10000u32 + ((UInt32(unit) - 0xD800u32) << 10) + (UInt32(low) - 0xDC00u32)
                result += "${Rune(codePoint)}"
                index += 2
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

func tryDecodeUtf16(units: Array<UInt16>): Option<String> {
    var result = ""
    var index: Int64 = 0
    let length = units.size

    while (index < length) {
        let unit = units[index]
        if (unit >= 0xD800u16 && unit <= 0xDBFFu16) {
            if (index + 1 >= length) {
                return None
            }

            let low = units[index + 1]
            if (low < 0xDC00u16 || low > 0xDFFFu16) {
                return None
            }

            let codePoint = 0x10000u32 + ((UInt32(unit) - 0xD800u32) << 10) + (UInt32(low) - 0xDC00u32)
            result += "${Rune(codePoint)}"
            index += 2
        } else if (unit >= 0xDC00u16 && unit <= 0xDFFFu16) {
            return None
        } else {
            result += "${Rune(UInt32(unit))}"
            index += 1
        }
    }

    Some(result)
}

func wide_trim_end(units: Array<UInt16>): Array<UInt16> {
    var trimmedLength = Int64(units.size)
    while (trimmedLength > 0) {
        let last = units[trimmedLength - 1]
        if (last == 0x0020u16 || last == 0x0009u16 || last == 0x000Au16 ||
            last == 0x000Bu16 || last == 0x000Cu16 || last == 0x000Du16) {
            trimmedLength -= 1
        } else {
            break
        }
    }

    if (trimmedLength == Int64(units.size)) {
        return units
    }

    if (trimmedLength <= 0) {
        return Array<UInt16>(0, repeat: 0u16)
    }

    var result = Array<UInt16>(trimmedLength, repeat: 0u16)
    var index: Int64 = 0
    while (index < trimmedLength) {
        result[index] = units[index]
        index += 1
    }
    result
}

class HeapString <: Resource & ToString {
    private var ptr: CPointer<UInt16> = CPointer<UInt16>()
    private var closed: Bool = false

    public init() {}

    init(ptr: CPointer<UInt16>) {
        this.ptr = ptr
    }

    public static func fromRaw(ptr: CPointer<UInt16>): HeapString {
        HeapString(ptr)
    }

    func currentLength(length: Int64): Int64 {
        if (closed || ptr.isNull()) {
            return 0
        }

        if (length >= 0) {
            return length
        }
        widePointerLength(ptr)
    }

    public func asRaw(): CPointer<UInt16> {
        if (closed) {
            return CPointer<UInt16>()
        }
        ptr
    }

    public func toWideArray(length!: Int64 = -1): Array<UInt16> {
        copyWideFromPointer(asRaw(), currentLength(length))
    }

    public func decode(length!: Int64 = -1): String {
        decodeUtf16(toWideArray(length: length))
    }

    public func toString(): String {
        decode()
    }

    public func isEmpty(length!: Int64 = -1): Bool {
        currentLength(length) == 0
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed && ptr.isNotNull()) {
            unsafe {
                HeapFree(GetProcessHeap(), 0u32, CPointer<Unit>(ptr))
            }
        }
        ptr = CPointer<UInt16>()
        closed = true
    }

    public func close(): Unit {
        if (!closed && ptr.isNotNull()) {
            unsafe {
                HeapFree(GetProcessHeap(), 0u32, CPointer<Unit>(ptr))
            }
        }
        ptr = CPointer<UInt16>()
        closed = true
    }
}
