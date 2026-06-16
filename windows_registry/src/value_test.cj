package windows_registry

import std.unittest.*
import std.unittest.testmacro.*
import windows_sys.Win32.Foundation as Win32Foundation
import windows_sys.Win32.System.Threading as Win32Threading
import windows_strings.HString

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

@When[os == "Windows"]
@Test
func testRegistryHkcuVolatileKeyRoundTripSmoke() {
    let path = "Software\\windows-cj-tests\\registry-smoke-${Win32Threading.GetCurrentProcessId()}-${Win32Threading.GetCurrentThreadId()}"
    let key = CURRENT_USER.options().read().write().create().volatile().open(path).unwrap()

    try {
        key.setU32("u32", 0x12345678u32).unwrap()
        key.setU64("u64", 0x0102030405060708u64).unwrap()
        key.setString("text", "registry smoke").unwrap()
        key.setMultiString("multi", ["one", "two"]).unwrap()

        @Expect(key.getType("u32").unwrap() == Type.U32, true)
        @Expect(key.getU32("u32").unwrap(), 0x12345678u32)
        @Expect(key.getU64("u64").unwrap(), 0x0102030405060708u64)
        @Expect(key.getString("text").unwrap(), "registry smoke")

        // getHString 走 HStringBuilder 零拷贝直写路径，结果应与 getString 相同。
        let hstr = key.getHString("text").unwrap()
        try {
            @Expect(hstr.toString(), "registry smoke")
        } finally {
            hstr.close()
        }
        key.setHString("hwide", HString("wide hstring value")).unwrap()
        let hwide = key.getHString("hwide").unwrap()
        try {
            @Expect(hwide.toString(), "wide hstring value")
        } finally {
            hwide.close()
        }
        // 拒绝非 String/ExpandString 类型 (DWORD)。
        @Expect(key.getHString("u64").isErr(), true)

        let multi = key.getMultiString("multi").unwrap()
        @Expect(multi.size, 2)
        @Expect(multi[0], "one")
        @Expect(multi[1], "two")

        key.removeValue("u32").unwrap()
        @Expect(key.getU32("u32").isErr(), true)

        let reopened = CURRENT_USER.open(path).unwrap()
        try {
            @Expect(reopened.getString("text").unwrap(), "registry smoke")
        } finally {
            reopened.close()
        }
    } finally {
        key.close()
        let _ = CURRENT_USER.removeTree(path)
    }
}
