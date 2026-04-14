package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*

// Test: UInt32 at unaligned offset=1 (packed(1) scenario)
@Test
func testPackedUInt32UnalignedOffset1() {
    var storage = VArray<UInt8, $16>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        packedWriteUInt32(p, 1, 0xDEADBEEFu32)
        let v = packedReadUInt32(p, 1)
        @Expect(v, 0xDEADBEEFu32)
    }
}

// Test: Float64 at unaligned offset=3 (packed float safety)
@Test
func testPackedFloat64UnalignedOffset3() {
    var storage = VArray<UInt8, $16>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        packedWriteFloat64(p, 3, 1.23456789f64)
        let v = packedReadFloat64(p, 3)
        let diff = if (v > 1.23456789f64) { v - 1.23456789f64 } else { 1.23456789f64 - v }
        @Expect(diff < 1e-10f64, true)
    }
}

// Test: UInt16 at offset=5 (boundary case)
@Test
func testPackedUInt16Offset5() {
    var storage = VArray<UInt8, $16>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        packedWriteUInt16(p, 5, 0xABCDu16)
        let v = packedReadUInt16(p, 5)
        @Expect(v, 0xABCDu16)
    }
}

// Test: Int32 negative value at unaligned offset=2
@Test
func testPackedInt32NegativeUnaligned() {
    var storage = VArray<UInt8, $8>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        packedWriteInt32(p, 2, -999i32)
        let v = packedReadInt32(p, 2)
        @Expect(v, -999i32)
    }
}

// Test: UInt64 at unaligned offset=1
@Test
func testPackedUInt64UnalignedOffset1() {
    var storage = VArray<UInt8, $16>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        packedWriteUInt64(p, 1, 0xCAFEBABEDEADu64)
        let v = packedReadUInt64(p, 1)
        @Expect(v, 0xCAFEBABEDEADu64)
    }
}

// Test: packed write does NOT clobber adjacent bytes outside its range
@Test
func testPackedUInt32DoesNotClobberNeighbors() {
    var storage = VArray<UInt8, $8>(repeat: 0xFFu8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        // Write 4 bytes at offset 2; bytes at 0,1,6,7 must stay 0xFF
        packedWriteUInt32(p, 2, 0x00000000u32)
        @Expect(p.read(0), 0xFFu8)
        @Expect(p.read(1), 0xFFu8)
        @Expect(p.read(6), 0xFFu8)
        @Expect(p.read(7), 0xFFu8)
    }
}

// Test: Float32 round-trip at unaligned offset=1
@Test
func testPackedFloat32UnalignedOffset1() {
    var storage = VArray<UInt8, $8>(repeat: 0u8)
    unsafe {
        let p = CPointer<UInt8>(inout storage)
        packedWriteFloat32(p, 1, 3.14f32)
        let v = packedReadFloat32(p, 1)
        let diff = if (v > 3.14f32) { v - 3.14f32 } else { 3.14f32 - v }
        @Expect(diff < 0.0001f32, true)
    }
}
