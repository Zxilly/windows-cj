package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testBitfieldReadUInt32() {
    let storage = 0b10110100u32

    @Expect(bitfieldReadUInt32(storage, 2, 3), 0b101u32)
}

@Test
func testBitfieldWriteUInt32PreservesNeighbors() {
    let storage = 0xFFFF0000u32
    let written = bitfieldWriteUInt32(storage, 4, 8, 0xABu32)

    @Expect(written, 0xFFFF0AB0u32)
}

@Test
func testBitfieldWriteUInt64MasksValueToWidth() {
    let written = bitfieldWriteUInt64(0u64, 16, 4, 0x3Fu64)

    @Expect(written, 0x000F0000u64)
}
