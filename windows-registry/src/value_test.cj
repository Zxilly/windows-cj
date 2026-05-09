package windows_registry

import std.unittest.*
import std.unittest.testmacro.*
import windows_common.Win32.Foundation as Win32Foundation

@Test
func testRegistryTypeRawRoundTrip() {
    @Expect(Type.fromRaw(4u32) == Type.U32, true)
    @Expect(Type.fromRaw(11u32) == Type.U64, true)
    @Expect(Type.fromRaw(1u32) == Type.String, true)
    @Expect(Type.fromRaw(0xFEEDu32) == Type.Other(0xFEEDu32), true)
    @Expect(Type.Other(0xFEEDu32).toRaw(), 0xFEEDu32)
}

@Test
func testRegistryValueConversionsUseLittleEndianStorage() {
    let dword = Value.fromU32(0x12345678u32)
    let qword = Value.fromU64(0x0102030405060708u64)
    let text = Value.fromString("AB")
    let multi = Value.fromMultiString(["A", "B"])

    @Expect(dword.bytes()[0], 0x78u8)
    @Expect(dword.bytes()[3], 0x12u8)
    @Expect(dword.toU32().unwrap(), 0x12345678u32)
    @Expect(qword.bytes()[0], 0x08u8)
    @Expect(qword.toU64().unwrap(), 0x0102030405060708u64)
    @Expect(text.toStringValue().unwrap(), "AB")
    @Expect(multi.toMultiString().unwrap().size, 2)
    @Expect(multi.toMultiString().unwrap()[1], "B")
}

@Test
func testRegistryAbiTypesComeFromWindowsCommon() {
    @Expect(sizeOf<FILETIME>(), sizeOf<Win32Foundation.FILETIME>())
}
