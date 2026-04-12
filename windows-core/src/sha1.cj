package windows_core

import std.collection.*

let GUID_SIGNATURE_NAMESPACE: Array<UInt8> = [
    0x11u8, 0xF4u8, 0x7Au8, 0xD5u8,
    0x7Bu8, 0x73u8, 0x42u8, 0xC0u8,
    0xABu8, 0xAEu8, 0x87u8, 0x8Bu8,
    0x1Eu8, 0x16u8, 0xADu8, 0xEEu8
]

public class ConstBuffer {
    private let data = ArrayList<UInt8>()

    public init() {}

    public static func fromBytes(bytes: Array<UInt8>): ConstBuffer {
        let buffer = ConstBuffer()
        buffer.pushSlice(bytes)
        buffer
    }

    public static func fromUtf8(text: String): ConstBuffer {
        ConstBuffer.fromBytes(text.toArray())
    }

    public func clone(): ConstBuffer {
        ConstBuffer.fromBytes(toArray())
    }

    public func length(): Int64 {
        data.size
    }

    public func isEmpty(): Bool {
        data.size == 0
    }

    public func push(value: UInt8): Unit {
        data.add(value)
    }

    public func pushSlice(values: Array<UInt8>): Unit {
        for (value in values) {
            data.add(value)
        }
    }

    public func pushUtf8(text: String): Unit {
        pushSlice(text.toArray())
    }

    public func pushOther(other: ConstBuffer): Unit {
        pushSlice(other.toArray())
    }

    public func pushGuid(guid: GUID): Unit {
        push(b'{')
        pushHexUInt32(guid.data1)
        push(b'-')
        pushHexUInt16(guid.data2)
        push(b'-')
        pushHexUInt16(guid.data3)
        push(b'-')
        pushHexUInt8(guid.data4[0])
        pushHexUInt8(guid.data4[1])
        push(b'-')
        pushHexUInt8(guid.data4[2])
        pushHexUInt8(guid.data4[3])
        pushHexUInt8(guid.data4[4])
        pushHexUInt8(guid.data4[5])
        pushHexUInt8(guid.data4[6])
        pushHexUInt8(guid.data4[7])
        push(b'}')
    }

    public func toArray(): Array<UInt8> {
        let result = Array<UInt8>(data.size, repeat: 0u8)
        var index = 0
        while (index < data.size) {
            result[index] = data[index]
            index += 1
        }
        result
    }

    private func pushHexUInt8(value: UInt8): Unit {
        push(hexDigit((value >> 4) & 0x0Fu8))
        push(hexDigit(value & 0x0Fu8))
    }

    private func pushHexUInt16(value: UInt16): Unit {
        pushHexUInt8(UInt8((value >> 8) & 0x00FFu16))
        pushHexUInt8(UInt8(value & 0x00FFu16))
    }

    private func pushHexUInt32(value: UInt32): Unit {
        pushHexUInt16(UInt16((value >> 16) & 0x0000FFFFu32))
        pushHexUInt16(UInt16(value & 0x0000FFFFu32))
    }
}

public struct Sha1Digest <: ToString {
    private let bytes_: Array<UInt8>

    public init(bytes: Array<UInt8>) {
        if (bytes.size != 20) {
            throw IllegalArgumentException("SHA1 digest must contain exactly 20 bytes")
        }
        bytes_ = bytes
    }

    public func bytes(): Array<UInt8> {
        let result = Array<UInt8>(bytes_.size, repeat: 0u8)
        var index = 0
        while (index < bytes_.size) {
            result[index] = bytes_[index]
            index += 1
        }
        result
    }

    public func toString(): String {
        let digits = "0123456789abcdef".toArray()
        let out = Array<Byte>(40, repeat: b'0')
        var index = 0
        while (index < bytes_.size) {
            let byteValue = bytes_[index]
            out[index * 2] = digits[Int64((byteValue >> 4) & 0x0Fu8)]
            out[index * 2 + 1] = digits[Int64(byteValue & 0x0Fu8)]
            index += 1
        }
        String.fromUtf8(out)
    }
}

public func sha1(data: ConstBuffer): Sha1Digest {
    let input = data.toArray()
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
            schedule[wordIndex] = rotateLeft(
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
            let f = selectRoundFunction(round, b, c, d)
            let k = selectRoundConstant(round)
            let temp = addMod32(
                addMod32(
                    addMod32(rotateLeft(a, 5), f),
                    e
                ),
                addMod32(k, schedule[round])
            )
            e = d
            d = c
            c = rotateLeft(b, 30)
            b = a
            a = temp
            round += 1
        }

        h0 = addMod32(h0, a)
        h1 = addMod32(h1, b)
        h2 = addMod32(h2, c)
        h3 = addMod32(h3, d)
        h4 = addMod32(h4, e)

        blockStart += 64
    }

    let bytes = Array<UInt8>(20, repeat: 0u8)
    writeUInt32BigEndian(bytes, 0, h0)
    writeUInt32BigEndian(bytes, 4, h1)
    writeUInt32BigEndian(bytes, 8, h2)
    writeUInt32BigEndian(bytes, 12, h3)
    writeUInt32BigEndian(bytes, 16, h4)
    Sha1Digest(bytes)
}

public func guidFromSignature(signature: ConstBuffer): GUID {
    let buffer = ConstBuffer.fromBytes(GUID_SIGNATURE_NAMESPACE)
    buffer.pushOther(signature)
    let digest = sha1(buffer).bytes()

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

func rotateLeft(value: UInt32, bits: Int64): UInt32 {
    (value << bits) | (value >> (32 - bits))
}

func addMod32(left: UInt32, right: UInt32): UInt32 {
    UInt32((UInt64(left) + UInt64(right)) & 0xFFFFFFFFu64)
}

func selectRoundFunction(round: Int64, b: UInt32, c: UInt32, d: UInt32): UInt32 {
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

func selectRoundConstant(round: Int64): UInt32 {
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

func writeUInt32BigEndian(target: Array<UInt8>, offset: Int64, value: UInt32): Unit {
    target[offset] = UInt8((value >> 24) & 0xFFu32)
    target[offset + 1] = UInt8((value >> 16) & 0xFFu32)
    target[offset + 2] = UInt8((value >> 8) & 0xFFu32)
    target[offset + 3] = UInt8(value & 0xFFu32)
}

func hexDigit(value: UInt8): UInt8 {
    if (value < 10u8) {
        return UInt8(UInt32(b'0') + UInt32(value))
    }
    UInt8(UInt32(b'a') + UInt32(value - 10u8))
}
