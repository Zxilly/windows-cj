package windows_interface

import windows_result.{Result, E_INVALIDARG}
import windows_result.Error as WinErrorResult

foreign {
    func LoadLibraryW(lpLibFileName: CPointer<UInt16>): CPointer<Unit>
    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>
}

let UUID_CREATE_LOCAL_ONLY_STATUS: Int32 = 1824i32
let RPCRT4_DLL_NAME: Array<UInt16> = [
    0x0072u16, 0x0070u16, 0x0063u16, 0x0072u16, 0x0074u16, 0x0034u16,
    0x002Eu16, 0x0064u16, 0x006Cu16, 0x006Cu16, 0u16
]
let UUID_CREATE_PROC_NAME: Array<UInt8> = [
    0x55u8, 0x75u8, 0x69u8, 0x64u8, 0x43u8, 0x72u8,
    0x65u8, 0x61u8, 0x74u8, 0x65u8, 0u8
]
let GUID_SIGNATURE_NAMESPACE: Array<UInt8> = [
    0x11u8, 0xF4u8, 0x7Au8, 0xD5u8,
    0x7Bu8, 0x73u8, 0x42u8, 0xC0u8,
    0xABu8, 0xAEu8, 0x87u8, 0x8Bu8,
    0x1Eu8, 0x16u8, 0xADu8, 0xEEu8
]

var cachedRpcrt4Module: CPointer<Unit> = CPointer<Unit>()
var cachedUuidCreateProc: CPointer<Unit> = CPointer<Unit>()

public struct UInt128 {
    public let high: UInt64
    public let low: UInt64

    public init(high: UInt64, low: UInt64) {
        this.high = high
        this.low = low
    }
}

@C
public struct GUID {
    public var data1: UInt32 = 0
    public var data2: UInt16 = 0
    public var data3: UInt16 = 0
    public var data4: VArray<UInt8, $8> = VArray<UInt8, $8>(repeat: 0)

    public init() {}

    public init(
        data1: UInt32,
        data2: UInt16,
        data3: UInt16,
        data4_0: UInt8,
        data4_1: UInt8,
        data4_2: UInt8,
        data4_3: UInt8,
        data4_4: UInt8,
        data4_5: UInt8,
        data4_6: UInt8,
        data4_7: UInt8
    ) {
        this.data1 = data1
        this.data2 = data2
        this.data3 = data3
        this.data4[0] = data4_0
        this.data4[1] = data4_1
        this.data4[2] = data4_2
        this.data4[3] = data4_3
        this.data4[4] = data4_4
        this.data4[5] = data4_5
        this.data4[6] = data4_6
        this.data4[7] = data4_7
    }

    public static func zeroed(): GUID {
        GUID()
    }

    public static func fromValues(
        data1: UInt32,
        data2: UInt16,
        data3: UInt16,
        data4_0: UInt8,
        data4_1: UInt8,
        data4_2: UInt8,
        data4_3: UInt8,
        data4_4: UInt8,
        data4_5: UInt8,
        data4_6: UInt8,
        data4_7: UInt8
    ): GUID {
        GUID(data1, data2, data3, data4_0, data4_1, data4_2, data4_3, data4_4, data4_5, data4_6, data4_7)
    }

    public static func fromU128(high: UInt64, low: UInt64): GUID {
        GUID(
            UInt32(high >> 32),
            UInt16((high >> 16) & 0xFFFFu64),
            UInt16(high & 0xFFFFu64),
            UInt8((low >> 56) & 0xFFu64),
            UInt8((low >> 48) & 0xFFu64),
            UInt8((low >> 40) & 0xFFu64),
            UInt8((low >> 32) & 0xFFu64),
            UInt8((low >> 24) & 0xFFu64),
            UInt8((low >> 16) & 0xFFu64),
            UInt8((low >> 8) & 0xFFu64),
            UInt8(low & 0xFFu64)
        )
    }

    public static func from_u128(value: UInt128): GUID {
        fromU128(value.high, value.low)
    }

    // 调用系统 UUID 生成器创建一个新的 GUID。
    public static func generate(): GUID {
        var guid = GUID.zeroed()
        let uuidCreate = CFunc<(CPointer<GUID>) -> Int32>(uuidCreateProc())
        let status = unsafe { uuidCreate(CPointer<GUID>(inout guid)) }
        if (status == 0i32 || status == UUID_CREATE_LOCAL_ONLY_STATUS) {
            return guid
        }
        throw Exception("UuidCreate failed with status ${status}")
    }

    public static func new(): Result<GUID> {
        var guid = GUID.zeroed()
        let uuidCreate = CFunc<(CPointer<GUID>) -> Int32>(uuidCreateProc())
        let status = unsafe { uuidCreate(CPointer<GUID>(inout guid)) }
        if (status == 0i32 || status == UUID_CREATE_LOCAL_ONLY_STATUS) {
            return Result<GUID>.Ok(guid)
        }
        Result<GUID>.Err(WinErrorResult.fromWin32(UInt32(status)))
    }

    public static func fromSignature(signature: String): GUID {
        guidFromSignatureBytes(signature.toArray())
    }

    public static func from_signature(signature: String): GUID {
        fromSignature(signature)
    }

    // 解析标准 xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx 形式的 GUID 字符串。
    public static func fromString(s: String): Option<GUID> {
        let bytes = s.toArray()
        if (bytes.size != 36) {
            return None
        }
        if (bytes[8] != b'-' || bytes[13] != b'-' || bytes[18] != b'-' || bytes[23] != b'-') {
            return None
        }

        match (parseGuidHex(bytes, 0, 8)) {
            case Some(data1) =>
                match (parseGuidHex(bytes, 9, 4)) {
                    case Some(data2) =>
                        match (parseGuidHex(bytes, 14, 4)) {
                            case Some(data3) =>
                                match (parseGuidHex(bytes, 19, 2)) {
                                    case Some(data4_0) =>
                                        match (parseGuidHex(bytes, 21, 2)) {
                                            case Some(data4_1) =>
                                                match (parseGuidHex(bytes, 24, 2)) {
                                                    case Some(data4_2) =>
                                                        match (parseGuidHex(bytes, 26, 2)) {
                                                            case Some(data4_3) =>
                                                                match (parseGuidHex(bytes, 28, 2)) {
                                                                    case Some(data4_4) =>
                                                                        match (parseGuidHex(bytes, 30, 2)) {
                                                                            case Some(data4_5) =>
                                                                                match (parseGuidHex(bytes, 32, 2)) {
                                                                                    case Some(data4_6) =>
                                                                                        match (parseGuidHex(bytes, 34, 2)) {
                                                                                            case Some(data4_7) =>
                                                                                                Some(
                                                                                                    GUID.fromValues(
                                                                                                        UInt32(data1),
                                                                                                        UInt16(data2),
                                                                                                        UInt16(data3),
                                                                                                        UInt8(data4_0),
                                                                                                        UInt8(data4_1),
                                                                                                        UInt8(data4_2),
                                                                                                        UInt8(data4_3),
                                                                                                        UInt8(data4_4),
                                                                                                        UInt8(data4_5),
                                                                                                        UInt8(data4_6),
                                                                                                        UInt8(data4_7)
                                                                                                    )
                                                                                                )
                                                                                            case None =>
                                                                                                None
                                                                                        }
                                                                                    case None =>
                                                                                        None
                                                                                }
                                                                            case None =>
                                                                                None
                                                                        }
                                                                    case None =>
                                                                        None
                                                                }
                                                            case None =>
                                                                None
                                                        }
                                                    case None =>
                                                        None
                                                }
                                            case None =>
                                                None
                                        }
                                    case None =>
                                        None
                                }
                            case None =>
                                None
                        }
                    case None =>
                        None
                }
            case None =>
                None
        }
    }

    public static func parse(s: String): GUID {
        match (fromString(s)) {
            case Some(value) =>
                value
            case None =>
                throw IllegalArgumentException("invalid GUID string")
        }
    }

    public static func tryFrom(source: String): Result<GUID> {
        match (fromString(source)) {
            case Some(value) =>
                Result<GUID>.Ok(value)
            case None =>
                Result<GUID>.Err(WinErrorResult(E_INVALIDARG))
        }
    }

    public operator func ==(other: GUID): Bool {
        if (data1 != other.data1 || data2 != other.data2 || data3 != other.data3) {
            return false
        }
        var i: Int64 = 0
        while (i < 8) {
            if (data4[i] != other.data4[i]) {
                return false
            }
            i += 1
        }
        true
    }

    public operator func !=(other: GUID): Bool {
        !(this == other)
    }

    public func isZero(): Bool {
        this == GUID.zeroed()
    }

    public func hashCode(): Int64 {
        let (high, low) = toU128()
        Int64((high ^ low) & 0x7FFFFFFFFFFFFFFFu64)
    }

    public func toString(): String {
        let d1 = padHexUpper(UInt64(data1), 8)
        let d2 = padHexUpper(UInt64(data2), 4)
        let d3 = padHexUpper(UInt64(data3), 4)
        let d4a = padHexUpper(UInt64(data4[0]), 2) + padHexUpper(UInt64(data4[1]), 2)
        var d4b = ""
        var i: Int64 = 2
        while (i < 8) {
            d4b += padHexUpper(UInt64(data4[i]), 2)
            i += 1
        }
        "${d1}-${d2}-${d3}-${d4a}-${d4b}"
    }

    public func toU128(): (UInt64, UInt64) {
        let high = (UInt64(data1) << 32) | (UInt64(data2) << 16) | UInt64(data3)
        var low = UInt64(data4[0]) << 56
        low |= UInt64(data4[1]) << 48
        low |= UInt64(data4[2]) << 40
        low |= UInt64(data4[3]) << 32
        low |= UInt64(data4[4]) << 24
        low |= UInt64(data4[5]) << 16
        low |= UInt64(data4[6]) << 8
        low |= UInt64(data4[7])
        (high, low)
    }

    public func to_u128(): UInt128 {
        let (high, low) = toU128()
        UInt128(high, low)
    }
}

public let GUID_ZERO = GUID.zeroed()
public let IID_IUNKNOWN = GUID.fromValues(0u32, 0u16, 0u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)
public let IID_IINSPECTABLE = GUID.fromValues(0xAF86E2E0u32, 0xB12Du16, 0x4C6Au16, 0x9Cu8, 0x5Au8, 0xD7u8, 0xAAu8, 0x65u8, 0x10u8, 0x1Eu8, 0x90u8)
public let IID_IACTIVATIONFACTORY = GUID.fromValues(0x00000035u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)

func padHexUpper(value: UInt64, width: Int64): String {
    let digits = "0123456789ABCDEF".toArray()
    var result = Array<Byte>(width, { _ => b'0' })
    var v = value
    var i = width - 1
    while (i >= 0 && v > 0u64) {
        result[i] = digits[Int64(v & 0xFu64)]
        v = v >> 4
        i -= 1
    }
    String.fromUtf8(result)
}

func parseGuidHex(bytes: Array<Byte>, start: Int64, length: Int64): Option<UInt64> {
    var value: UInt64 = 0u64
    var index = start
    let end = start + length
    while (index < end) {
        match (parseGuidHexDigit(bytes[index])) {
            case Some(digit) =>
                value = (value << 4) | UInt64(digit)
            case None =>
                return None
        }
        index += 1
    }
    Some(value)
}

func parseGuidHexDigit(digit: Byte): Option<Int64> {
    if (digit >= b'0' && digit <= b'9') {
        return Some(Int64(digit - b'0'))
    }
    if (digit >= b'A' && digit <= b'F') {
        return Some(10 + Int64(digit - b'A'))
    }
    if (digit >= b'a' && digit <= b'f') {
        return Some(10 + Int64(digit - b'a'))
    }
    None
}

func uuidCreateProc(): CPointer<Unit> {
    if (cachedUuidCreateProc.isNotNull()) {
        return cachedUuidCreateProc
    }

    let module = rpcrt4Module()
    unsafe {
        let handle = acquireArrayRawData(UUID_CREATE_PROC_NAME)
        try {
            let proc = GetProcAddress(module, handle.pointer)
            if (proc.isNull()) {
                throw Exception("failed to resolve UuidCreate")
            }
            cachedUuidCreateProc = proc
            return proc
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func rpcrt4Module(): CPointer<Unit> {
    if (cachedRpcrt4Module.isNotNull()) {
        return cachedRpcrt4Module
    }

    unsafe {
        let handle = acquireArrayRawData(RPCRT4_DLL_NAME)
        try {
            let module = LoadLibraryW(handle.pointer)
            if (module.isNull()) {
                throw Exception("failed to load rpcrt4.dll")
            }
            cachedRpcrt4Module = module
            return module
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func guidFromSignatureBytes(signature: Array<UInt8>): GUID {
    let buffer = Array<UInt8>(GUID_SIGNATURE_NAMESPACE.size + signature.size, repeat: 0u8)
    var index = 0
    while (index < GUID_SIGNATURE_NAMESPACE.size) {
        buffer[index] = GUID_SIGNATURE_NAMESPACE[index]
        index += 1
    }
    var signatureIndex = 0
    while (signatureIndex < signature.size) {
        buffer[index + signatureIndex] = signature[signatureIndex]
        signatureIndex += 1
    }

    let digest = sha1Bytes(buffer)
    let first =
        (UInt32(digest[0]) << 24) |
        (UInt32(digest[1]) << 16) |
        (UInt32(digest[2]) << 8) |
        UInt32(digest[3])
    let second = UInt16((UInt16(digest[4]) << 8) | UInt16(digest[5]))
    var third = UInt16((UInt16(digest[6]) << 8) | UInt16(digest[7]))
    third = UInt16((third & 0x0FFFu16) | 0x5000u16)
    let fourth = UInt8((digest[8] & 0x3Fu8) | 0x80u8)

    GUID.fromValues(
        first,
        second,
        third,
        fourth,
        digest[9],
        digest[10],
        digest[11],
        digest[12],
        digest[13],
        digest[14],
        digest[15]
    )
}

func sha1Bytes(input: Array<UInt8>): Array<UInt8> {
    let originalLength = input.size
    let bitLength = UInt64(originalLength) * 8u64

    var paddedLength = originalLength + 1 + 8
    let remainder = paddedLength % 64
    if (remainder != 0) {
        paddedLength += 64 - remainder
    }

    let padded = Array<UInt8>(paddedLength, repeat: 0u8)
    var copyIndex = 0
    while (copyIndex < originalLength) {
        padded[copyIndex] = input[copyIndex]
        copyIndex += 1
    }
    padded[originalLength] = 0x80u8

    let lengthOffset = paddedLength - 8
    padded[lengthOffset] = UInt8((bitLength >> 56) & 0xFFu64)
    padded[lengthOffset + 1] = UInt8((bitLength >> 48) & 0xFFu64)
    padded[lengthOffset + 2] = UInt8((bitLength >> 40) & 0xFFu64)
    padded[lengthOffset + 3] = UInt8((bitLength >> 32) & 0xFFu64)
    padded[lengthOffset + 4] = UInt8((bitLength >> 24) & 0xFFu64)
    padded[lengthOffset + 5] = UInt8((bitLength >> 16) & 0xFFu64)
    padded[lengthOffset + 6] = UInt8((bitLength >> 8) & 0xFFu64)
    padded[lengthOffset + 7] = UInt8(bitLength & 0xFFu64)

    var h0 = 0x67452301u32
    var h1 = 0xEFCDAB89u32
    var h2 = 0x98BADCFEu32
    var h3 = 0x10325476u32
    var h4 = 0xC3D2E1F0u32
    let schedule = Array<UInt32>(80, repeat: 0u32)

    var blockStart = 0
    while (blockStart < paddedLength) {
        var wordIndex = 0
        while (wordIndex < 16) {
            let base = blockStart + wordIndex * 4
            schedule[wordIndex] =
                (UInt32(padded[base]) << 24) |
                (UInt32(padded[base + 1]) << 16) |
                (UInt32(padded[base + 2]) << 8) |
                UInt32(padded[base + 3])
            wordIndex += 1
        }

        wordIndex = 16
        while (wordIndex < 80) {
            schedule[wordIndex] = guidRotateLeft(
                schedule[wordIndex - 3] ^
                schedule[wordIndex - 8] ^
                schedule[wordIndex - 14] ^
                schedule[wordIndex - 16],
                1
            )
            wordIndex += 1
        }

        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4

        var round = 0
        while (round < 80) {
            let f = guidSelectRoundFunction(round, b, c, d)
            let k = guidSelectRoundConstant(round)
            let temp = guidAddMod32(
                guidAddMod32(
                    guidAddMod32(guidRotateLeft(a, 5), f),
                    e
                ),
                guidAddMod32(k, schedule[round])
            )
            e = d
            d = c
            c = guidRotateLeft(b, 30)
            b = a
            a = temp
            round += 1
        }

        h0 = guidAddMod32(h0, a)
        h1 = guidAddMod32(h1, b)
        h2 = guidAddMod32(h2, c)
        h3 = guidAddMod32(h3, d)
        h4 = guidAddMod32(h4, e)
        blockStart += 64
    }

    let bytes = Array<UInt8>(20, repeat: 0u8)
    writeGuidUInt32BigEndian(bytes, 0, h0)
    writeGuidUInt32BigEndian(bytes, 4, h1)
    writeGuidUInt32BigEndian(bytes, 8, h2)
    writeGuidUInt32BigEndian(bytes, 12, h3)
    writeGuidUInt32BigEndian(bytes, 16, h4)
    bytes
}

func guidRotateLeft(value: UInt32, bits: Int64): UInt32 {
    (value << bits) | (value >> (32 - bits))
}

func guidAddMod32(left: UInt32, right: UInt32): UInt32 {
    UInt32((UInt64(left) + UInt64(right)) & 0xFFFFFFFFu64)
}

func guidSelectRoundFunction(round: Int64, b: UInt32, c: UInt32, d: UInt32): UInt32 {
    if (round < 20) {
        let notB = b ^ 0xFFFFFFFFu32
        return (b & c) | (notB & d)
    }
    if (round < 40) {
        return b ^ c ^ d
    }
    if (round < 60) {
        return (b & c) | (b & d) | (c & d)
    }
    b ^ c ^ d
}

func guidSelectRoundConstant(round: Int64): UInt32 {
    if (round < 20) {
        return 0x5A827999u32
    }
    if (round < 40) {
        return 0x6ED9EBA1u32
    }
    if (round < 60) {
        return 0x8F1BBCDCu32
    }
    0xCA62C1D6u32
}

func writeGuidUInt32BigEndian(target: Array<UInt8>, offset: Int64, value: UInt32): Unit {
    target[offset] = UInt8((value >> 24) & 0xFFu32)
    target[offset + 1] = UInt8((value >> 16) & 0xFFu32)
    target[offset + 2] = UInt8((value >> 8) & 0xFFu32)
    target[offset + 3] = UInt8(value & 0xFFu32)
}
