package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*

// ---------------------------------------------------------------------------
// FlagSetU32 tests
// ---------------------------------------------------------------------------

// Test: OR merges bits from two flag sets
@Test
func testFlagSetU32Or() {
    let a = FlagSetU32(0x01u32)
    let b = FlagSetU32(0x02u32)
    let c = a | b
    @Expect(c.value, 0x03u32)
}

// Test: AND extracts common bits
@Test
func testFlagSetU32And() {
    let a = FlagSetU32(0x0Fu32)
    let b = FlagSetU32(0x03u32)
    let c = a & b
    @Expect(c.value, 0x03u32)
}

// Test: ! is bitwise complement (not boolean NOT)
// !(0x0F) & 0xFF == 0xF0 (lower byte: bits 7-4 set, bits 3-0 clear)
@Test
func testFlagSetU32BitwiseNot() {
    let a = FlagSetU32(0x0Fu32)
    let notA = !a
    let masked = notA.value & 0xFFu32
    @Expect(masked, 0xF0u32)
}

// Test: ! flips all bits — full 32-bit complement
@Test
func testFlagSetU32BitwiseNotFull() {
    let a = FlagSetU32(0x00000000u32)
    let notA = !a
    @Expect(notA.value, UInt32.Max)
}

// Test: contains() positive — flag is present
@Test
func testFlagSetU32ContainsTrue() {
    let flags = FlagSetU32(0x07u32)   // bits 0,1,2 set
    let check = FlagSetU32(0x05u32)   // bits 0,2 set
    @Expect(flags.contains(check), true)
}

// Test: contains() negative — flag not present
@Test
func testFlagSetU32ContainsFalse() {
    let flags = FlagSetU32(0x06u32)   // bits 1,2 set
    let check = FlagSetU32(0x05u32)   // needs bits 0,2 — bit 0 missing
    @Expect(flags.contains(check), false)
}

// Test: contains() with zero — zero is always contained
@Test
func testFlagSetU32ContainsZero() {
    let flags = FlagSetU32(0x00u32)
    @Expect(flags.contains(FlagSetU32(0x00u32)), true)
}

// ---------------------------------------------------------------------------
// FlagSetU64 tests
// ---------------------------------------------------------------------------

// Test: OR merges high bits in U64
@Test
func testFlagSetU64Or() {
    let a = FlagSetU64(0x100000000u64)
    let b = FlagSetU64(0x000000001u64)
    let c = a | b
    @Expect(c.value, 0x100000001u64)
}

// Test: ! bitwise complement on U64
@Test
func testFlagSetU64BitwiseNot() {
    let a = FlagSetU64(0u64)
    let notA = !a
    @Expect(notA.value, UInt64.Max)
}

// Test: contains() for U64
@Test
func testFlagSetU64Contains() {
    let flags = FlagSetU64(0xFFFFFFFFFFFFFFFFu64)
    let check = FlagSetU64(0x8000000000000001u64)
    @Expect(flags.contains(check), true)
}

// ---------------------------------------------------------------------------
// FlagSetI32 tests
// ---------------------------------------------------------------------------

// Test: OR on I32
@Test
func testFlagSetI32Or() {
    let a = FlagSetI32(0x10i32)
    let b = FlagSetI32(0x01i32)
    let c = a | b
    @Expect(c.value, 0x11i32)
}

// Test: ! on I32 — complement of 0 is -1 (all bits set in two's complement)
@Test
func testFlagSetI32BitwiseNot() {
    let a = FlagSetI32(0i32)
    let notA = !a
    @Expect(notA.value, -1i32)
}

// Test: contains() on I32 positive
@Test
func testFlagSetI32Contains() {
    let flags = FlagSetI32(0x0Fi32)
    let check = FlagSetI32(0x05i32)
    @Expect(flags.contains(check), true)
}

// Test: contains() on I32 negative
@Test
func testFlagSetI32ContainsFalse() {
    let flags = FlagSetI32(0x04i32)
    let check = FlagSetI32(0x05i32)  // needs bit 0 which is not set
    @Expect(flags.contains(check), false)
}

// ---------------------------------------------------------------------------
// FlagSetI64 tests
// ---------------------------------------------------------------------------

// Test: OR on I64
@Test
func testFlagSetI64Or() {
    let a = FlagSetI64(0x0000000100000000i64)
    let b = FlagSetI64(0x0000000000000001i64)
    let c = a | b
    @Expect(c.value, 0x0000000100000001i64)
}

// Test: ! on I64 — complement of -1 is 0
@Test
func testFlagSetI64BitwiseNotMinusOne() {
    let a = FlagSetI64(-1i64)
    let notA = !a
    @Expect(notA.value, 0i64)
}

// Test: contains() on I64
@Test
func testFlagSetI64Contains() {
    let flags = FlagSetI64(0x0000000F0000000Fi64)
    let check = FlagSetI64(0x0000000100000001i64)
    @Expect(flags.contains(check), true)
}
