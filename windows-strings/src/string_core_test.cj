package windows_strings

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testUtf16AndUtf8Helpers() {
    let wide = encodeUtf16WithNull("AB")
    let copied = copyWideArray(wide, length: 2)
    let appended = appendWideNull([0x41u16, 0x42u16])

    @Expect(wide.size, 3)
    @Expect(wide[0], 0x41u16)
    @Expect(wide[2], 0u16)
    @Expect(copied.size, 2)
    @Expect(decodeUtf16(copied), "AB")
    @Expect(appended[2], 0u16)
    @Expect(decodeUtf8Lossy([0x41u8, 0x42u8]), "AB")
}

@Test
func testHStringCloneAndBuilderRoundTrip() {
    let source = HString("Cangjie")
    let clone = source.clone()
    let builder = HStringBuilder(2)

    builder.set(0, 0x41u16)
    builder.set(1, 0x42u16)

    @Expect(source.get(), "Cangjie")
    @Expect(clone.get(), "Cangjie")
    @Expect(source == clone, true)
    @Expect(builder.toHString().get(), "AB")

    clone.close()
    source.close()
    builder.close()
    @Expect(clone.isClosed(), true)
    @Expect(source.isClosed(), true)
}
