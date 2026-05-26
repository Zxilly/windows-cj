package windows_registry

import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_result.*

func readRegistrySourceForTesting(): String {
    try {
        return String.fromUtf8(File.readFrom("windows_registry/src/lib.cj"))
    } catch (_: Exception) {
        return String.fromUtf8(File.readFrom("src/lib.cj"))
    }
}

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

// Multi-SZ 解码语义：仓颉版本将连续 NUL 视为终止符，不会为 buffer 末尾的双 NUL 间隙
// 多产出一个空字符串元素。fromMultiString(["A","B"]) 编码为 [A,0,B,0,0]（双 NUL 结尾），
// 解析时遇到第二个 0（与 start 重合）即终止，结果恰好是 ["A","B"]。该测试锁定该终止规则，
// 防止未来误改为"按 NUL 分割整段 wide 数据"（那样会多出一个尾部空字符串元素）。
@Test
func testRegistryMultiStringDecodeTerminatesOnDoubleNull() {
    let value = Value.fromMultiString(["A", "B"])
    let decoded = value.toMultiString().unwrap()
    @Expect(decoded.size, 2)
    @Expect(decoded[0], "A")
    @Expect(decoded[1], "B")

    // 显式构造带尾部双 NUL 的 buffer，确认即使原始字节是
    // [A,0,B,0,0,0]（额外尾部 NUL），仍然只产出 ["A","B"]，不会多出空字符串。
    let withTrailing = Value(
        [0x41u8, 0x00u8, 0x00u8, 0x00u8, 0x42u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8],
        Type.MultiString
    )
    let trailing = withTrailing.toMultiString().unwrap()
    @Expect(trailing.size, 2)
    @Expect(trailing[0], "A")
    @Expect(trailing[1], "B")
}

@Test
func testRegistryStringRejectsInvalidUtf16() {
    let oddLength = Value([0x41u8], Type.String)
    let loneHigh = Value([0x00u8, 0xD8u8, 0x00u8, 0x00u8], Type.String)
    let highThenScalar = Value([0x00u8, 0xD8u8, 0x41u8, 0x00u8], Type.String)
    let loneLow = Value([0x00u8, 0xDCu8], Type.ExpandString)

    @Expect(oddLength.toStringValue().isErr(), true)
    @Expect(loneHigh.toStringValue().isErr(), true)
    @Expect(highThenScalar.toStringValue().isErr(), true)

    match (loneLow.toStringValue()) {
        case Result<String>.Ok(_) => @Fail("expected invalid UTF-16 to fail")
        case Result<String>.Err(error) =>
            match (WIN32_ERROR.from(error)) {
                case Some(code) => @Expect(code.value, 13u32)
                case None => @Fail("expected a Win32 invalid data error")
            }
    }
}

@Test
func testRegistryOwnedInvalidResourcesCloseIdempotently() {
    let transaction = Transaction.fromRaw(HANDLE())
    let key = Key.fromRaw(HKEY())

    transaction.close()
    transaction.close()
    key.close()
    key.close()

    @Expect(transaction.isClosed(), true)
    @Expect(key.isClosed(), true)
    @Expect(transaction.asRaw().Value.isNull(), true)
    @Expect(key.asRaw().Value.isNull(), true)
}

@Test
func testRegistryCloseClearsOwnedSlotsBeforeNativeClose() {
    let source = readRegistrySourceForTesting()
    let transactionClose = "let closing = handle\n        closed = true\n        handle = HANDLE()\n        closeHandleNoThrow(closing)"
    let transactionCloseCrLf = "let closing = handle\r\n        closed = true\r\n        handle = HANDLE()\r\n        closeHandleNoThrow(closing)"
    let keyClose = "let closing = handle\n        closed = true\n        handle = HKEY()\n        closeRegistryKeyNoThrow(closing)"
    let keyCloseCrLf = "let closing = handle\r\n        closed = true\r\n        handle = HKEY()\r\n        closeRegistryKeyNoThrow(closing)"

    @Expect(source.contains(transactionClose) || source.contains(transactionCloseCrLf), true)
    @Expect(source.contains(keyClose) || source.contains(keyCloseCrLf), true)
}

@Test
func testRegistryBorrowedRootKeysDoNotClose() {
    CURRENT_USER.close()
    CURRENT_USER.close()

    @Expect(CURRENT_USER.isClosed(), false)
    @Expect(CURRENT_USER.asRaw().Value.isNotNull(), true)
}
