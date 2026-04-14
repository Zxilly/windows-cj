package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*

// ---------------------------------------------------------------------------
// handleIsInvalidRaw tests
// ---------------------------------------------------------------------------

// NULL (0) is invalid
@Test
func testHandleIsInvalidRawNull() {
    @Expect(handleIsInvalidRaw(IntNative(0)), true)
}

// INVALID_HANDLE_VALUE (-1) is invalid
@Test
func testHandleIsInvalidRawMinusOne() {
    @Expect(handleIsInvalidRaw(IntNative(-1)), true)
}

// A real handle value is not invalid
@Test
func testHandleIsInvalidRawValid() {
    @Expect(handleIsInvalidRaw(IntNative(0x1234)), false)
}

// ---------------------------------------------------------------------------
// handleIsNullRaw tests
// ---------------------------------------------------------------------------

// NULL (0) is null
@Test
func testHandleIsNullRawZero() {
    @Expect(handleIsNullRaw(IntNative(0)), true)
}

// -1 is NOT null (it is INVALID_HANDLE_VALUE, not NULL)
@Test
func testHandleIsNullRawMinusOne() {
    @Expect(handleIsNullRaw(IntNative(-1)), false)
}

// A real handle value is not null
@Test
func testHandleIsNullRawValid() {
    @Expect(handleIsNullRaw(IntNative(0x1234)), false)
}

// ---------------------------------------------------------------------------
// handleIsMinusOneRaw tests
// ---------------------------------------------------------------------------

// -1 is minus-one
@Test
func testHandleIsMinusOneRawMinusOne() {
    @Expect(handleIsMinusOneRaw(IntNative(-1)), true)
}

// 0 is not minus-one
@Test
func testHandleIsMinusOneRawZero() {
    @Expect(handleIsMinusOneRaw(IntNative(0)), false)
}

// A real handle is not minus-one
@Test
func testHandleIsMinusOneRawValid() {
    @Expect(handleIsMinusOneRaw(IntNative(0x1234)), false)
}

// ---------------------------------------------------------------------------
// INVALID_HANDLE_VALUE_RAW constant test
// ---------------------------------------------------------------------------

@Test
func testInvalidHandleValueRaw() {
    @Expect(INVALID_HANDLE_VALUE_RAW, IntNative(-1))
}
