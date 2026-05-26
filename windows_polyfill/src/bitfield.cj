package windows_polyfill

func bitMaskUInt64(bitWidth: Int64): UInt64 {
    if (bitWidth <= 0) {
        return 0u64
    }
    if (bitWidth >= 64) {
        return UInt64.Max
    }
    return (1u64 << bitWidth) - 1u64
}

func bitfieldReadRaw(storage: UInt64, bitOffset: Int64, bitWidth: Int64): UInt64 {
    return (storage >> bitOffset) & bitMaskUInt64(bitWidth)
}

func bitfieldWriteRaw(storage: UInt64, bitOffset: Int64, bitWidth: Int64, value: UInt64): UInt64 {
    let valueMask = bitMaskUInt64(bitWidth)
    let shiftedMask = valueMask << bitOffset
    let cleared = storage & !shiftedMask
    let shiftedValue = (value & valueMask) << bitOffset
    return cleared | shiftedValue
}

public func bitfieldReadUInt8(storage: UInt8, bitOffset: Int64, bitWidth: Int64): UInt8 {
    return UInt8(bitfieldReadRaw(UInt64(storage), bitOffset, bitWidth))
}

public func bitfieldWriteUInt8(storage: UInt8, bitOffset: Int64, bitWidth: Int64, value: UInt8): UInt8 {
    return UInt8(bitfieldWriteRaw(UInt64(storage), bitOffset, bitWidth, UInt64(value)))
}

public func bitfieldReadUInt16(storage: UInt16, bitOffset: Int64, bitWidth: Int64): UInt16 {
    return UInt16(bitfieldReadRaw(UInt64(storage), bitOffset, bitWidth))
}

public func bitfieldWriteUInt16(storage: UInt16, bitOffset: Int64, bitWidth: Int64, value: UInt16): UInt16 {
    return UInt16(bitfieldWriteRaw(UInt64(storage), bitOffset, bitWidth, UInt64(value)))
}

public func bitfieldReadUInt32(storage: UInt32, bitOffset: Int64, bitWidth: Int64): UInt32 {
    return UInt32(bitfieldReadRaw(UInt64(storage), bitOffset, bitWidth))
}

public func bitfieldWriteUInt32(storage: UInt32, bitOffset: Int64, bitWidth: Int64, value: UInt32): UInt32 {
    return UInt32(bitfieldWriteRaw(UInt64(storage), bitOffset, bitWidth, UInt64(value)))
}

public func bitfieldReadUInt64(storage: UInt64, bitOffset: Int64, bitWidth: Int64): UInt64 {
    return bitfieldReadRaw(storage, bitOffset, bitWidth)
}

public func bitfieldWriteUInt64(storage: UInt64, bitOffset: Int64, bitWidth: Int64, value: UInt64): UInt64 {
    return bitfieldWriteRaw(storage, bitOffset, bitWidth, value)
}
