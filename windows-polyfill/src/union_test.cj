package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*

// Test: UInt32 write and read at offset 0
@Test
func testUInt32WriteRead() {
    var storage = VArray<UInt8, $16>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        unionWriteUInt32(p, 0, 0x12345678u32)
        let v = unionReadUInt32(p, 0)
        @Expect(v, 0x12345678u32)
    }
}

// Test: UInt64 write and read at byte offset 8 (second slot in 16-byte storage)
@Test
func testUInt64AtOffset8() {
    var storage = VArray<UInt8, $16>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        unionWriteUInt64(p, 8, 0xDEADBEEFCAFEu64)
        let v = unionReadUInt64(p, 8)
        @Expect(v, 0xDEADBEEFCAFEu64)
    }
}

// Test: UInt8 byte-level granularity write and read
@Test
func testUInt8ByteGranularity() {
    var storage = VArray<UInt8, $8>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        unionWriteUInt8(p, 0, 0xAAu8)
        unionWriteUInt8(p, 1, 0xBBu8)
        unionWriteUInt8(p, 2, 0xCCu8)
        unionWriteUInt8(p, 3, 0xDDu8)
        @Expect(unionReadUInt8(p, 0), 0xAAu8)
        @Expect(unionReadUInt8(p, 1), 0xBBu8)
        @Expect(unionReadUInt8(p, 2), 0xCCu8)
        @Expect(unionReadUInt8(p, 3), 0xDDu8)
    }
}

// Test: overlapping view — write UInt32, read back as two UInt16 (little-endian)
@Test
func testOverlappingUInt32AsUInt16() {
    var storage = VArray<UInt8, $4>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        // 0x00010002 in little-endian: bytes [02, 00, 01, 00]
        unionWriteUInt32(p, 0, 0x00010002u32)
        let lo = unionReadUInt16(p, 0)  // bytes 0-1 -> 0x0002
        let hi = unionReadUInt16(p, 2)  // bytes 2-3 -> 0x0001
        @Expect(lo, 0x0002u16)
        @Expect(hi, 0x0001u16)
    }
}

// Test: Float32 write and read
@Test
func testFloat32WriteRead() {
    var storage = VArray<UInt8, $4>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        unionWriteFloat32(p, 0, 3.14f32)
        let v = unionReadFloat32(p, 0)
        // Allow small epsilon for float comparison
        let diff = if (v > 3.14f32) { v - 3.14f32 } else { 3.14f32 - v }
        @Expect(diff < 0.0001f32, true)
    }
}

// Test: Int32 negative value round-trip
@Test
func testInt32Negative() {
    var storage = VArray<UInt8, $8>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        unionWriteInt32(p, 0, -42i32)
        let v = unionReadInt32(p, 0)
        @Expect(v, -42i32)
    }
}
