package windows_polyfill

// Packed polyfill: byte-by-byte read/write for packed(N) fields.
// Uses byte copy instead of pointer cast to safely handle unaligned offsets.
// Caller ensures byteOffset + sizeof(T) <= capacity.

private unsafe func copyBytes(dst: CPointer<UInt8>, src: CPointer<UInt8>, size: Int64): Unit {
    var i: Int64 = 0
    while (i < size) {
        dst.write(i, src.read(i))
        i += 1
    }
}

public unsafe func packedReadUInt8(base: CPointer<UInt8>, byteOffset: Int64): UInt8 {
    return base.read(byteOffset)
}
public unsafe func packedReadInt8(base: CPointer<UInt8>, byteOffset: Int64): Int8 {
    return CPointer<Int8>(base).read(byteOffset)
}
public unsafe func packedReadUInt16(base: CPointer<UInt8>, byteOffset: Int64): UInt16 {
    var tmp: UInt16 = 0u16
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 2)
    return tmp
}
public unsafe func packedReadInt16(base: CPointer<UInt8>, byteOffset: Int64): Int16 {
    var tmp: Int16 = 0i16
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 2)
    return tmp
}
public unsafe func packedReadUInt32(base: CPointer<UInt8>, byteOffset: Int64): UInt32 {
    var tmp: UInt32 = 0u32
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 4)
    return tmp
}
public unsafe func packedReadInt32(base: CPointer<UInt8>, byteOffset: Int64): Int32 {
    var tmp: Int32 = 0i32
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 4)
    return tmp
}
public unsafe func packedReadUInt64(base: CPointer<UInt8>, byteOffset: Int64): UInt64 {
    var tmp: UInt64 = 0u64
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 8)
    return tmp
}
public unsafe func packedReadInt64(base: CPointer<UInt8>, byteOffset: Int64): Int64 {
    var tmp: Int64 = 0i64
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 8)
    return tmp
}
public unsafe func packedReadFloat32(base: CPointer<UInt8>, byteOffset: Int64): Float32 {
    var tmp: Float32 = 0.0f32
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 4)
    return tmp
}
public unsafe func packedReadFloat64(base: CPointer<UInt8>, byteOffset: Int64): Float64 {
    var tmp: Float64 = 0.0f64
    copyBytes(CPointer<UInt8>(inout tmp), base + byteOffset, 8)
    return tmp
}

public unsafe func packedWriteUInt8(base: CPointer<UInt8>, byteOffset: Int64, v: UInt8): Unit {
    base.write(byteOffset, v)
}
public unsafe func packedWriteInt8(base: CPointer<UInt8>, byteOffset: Int64, v: Int8): Unit {
    CPointer<Int8>(base).write(byteOffset, v)
}
public unsafe func packedWriteUInt16(base: CPointer<UInt8>, byteOffset: Int64, v: UInt16): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 2)
}
public unsafe func packedWriteInt16(base: CPointer<UInt8>, byteOffset: Int64, v: Int16): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 2)
}
public unsafe func packedWriteUInt32(base: CPointer<UInt8>, byteOffset: Int64, v: UInt32): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 4)
}
public unsafe func packedWriteInt32(base: CPointer<UInt8>, byteOffset: Int64, v: Int32): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 4)
}
public unsafe func packedWriteUInt64(base: CPointer<UInt8>, byteOffset: Int64, v: UInt64): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 8)
}
public unsafe func packedWriteInt64(base: CPointer<UInt8>, byteOffset: Int64, v: Int64): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 8)
}
public unsafe func packedWriteFloat32(base: CPointer<UInt8>, byteOffset: Int64, v: Float32): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 4)
}
public unsafe func packedWriteFloat64(base: CPointer<UInt8>, byteOffset: Int64, v: Float64): Unit {
    var tmp = v
    copyBytes(base + byteOffset, CPointer<UInt8>(inout tmp), 8)
}
