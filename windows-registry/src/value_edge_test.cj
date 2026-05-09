package windows_registry

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testRegistryValueRejectsMalformedIntegerByteLengths() {
    let shortU32 = Value([1u8, 2u8, 3u8], Type.U32)
    let shortU64 = Value([1u8, 2u8, 3u8, 4u8], Type.U64)

    @Expect(shortU32.toU32().isErr(), true)
    @Expect(shortU32.toU64().isErr(), true)
    @Expect(shortU64.toU64().isErr(), true)
}

@Test
func testRegistryValueRejectsU64ToU32Overflow() {
    let overflow = Value.fromU64(0x0000000100000000u64)
    let fits = Value.fromU64(0x00000000FFFFFFFFu64)

    @Expect(overflow.toU32().isErr(), true)
    @Expect(fits.toU32().unwrap(), 0xFFFFFFFFu32)
}

@Test
func testRegistryValueStringAndMultiStringEdges() {
    let unterminated = Value([0x41u8, 0x00u8], Type.String)
    let emptyMulti = Value.fromMultiString([])
    let single = Value.fromString("one")

    @Expect(unterminated.toStringValue().unwrap(), "A")
    @Expect(emptyMulti.toMultiString().unwrap().size, 0)
    @Expect(single.toMultiString().unwrap().size, 1)
    @Expect(single.toMultiString().unwrap()[0], "one")
    @Expect(Value.fromBytes([1u8]).toStringValue().isErr(), true)
}
