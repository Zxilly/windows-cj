package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testBitfieldZeroWidthAndFullWidthEdges() {
    @Expect(bitfieldReadUInt32(0xFFFFFFFFu32, 4, 0), 0u32)
    @Expect(bitfieldWriteUInt32(0x12345678u32, 8, 0, 0xFFu32), 0x12345678u32)
    @Expect(bitfieldReadUInt64(UInt64.Max, 0, 64), UInt64.Max)
    @Expect(bitfieldWriteUInt64(0u64, 0, 64, UInt64.Max), UInt64.Max)
}

@Test
func testHrQueryOptionalDistinguishesNoInterfaceFromFailure() {
    match (hrQueryOptional<Int32>(E_NOINTERFACE, 5i32)) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }

    match (hrQueryOptional<Int32>(S_OK, 7i32)) {
        case Some(value) => @Expect(value, 7i32)
        case None => @Expect(false, true)
    }

    var code = 0i32
    try {
        let _ = hrQueryOptional<Int32>(-2147467259i32, 9i32)
    } catch (e: HResultException) {
        code = e.code
    }
    @Expect(code, -2147467259i32)
}
