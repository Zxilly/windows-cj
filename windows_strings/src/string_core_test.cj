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
    @Expect(decodeUtf8Lossy([0xE2u8]), "${Rune(0xFFFDu32)}")
    @Expect(decodeUtf8Lossy([0x41u8, 0xE2u8]), "A${Rune(0xFFFDu32)}")
}

@Test
func testHStringCloneAndBuilderRoundTrip() {
    let source = HString("Cangjie")
    let clone = source.clone()
    let builder = HStringBuilder(2)

    builder.set(0, 0x41u16)
    builder.set(1, 0x42u16)
    let built = builder.toHString()

    @Expect(source.get(), "Cangjie")
    @Expect(clone.get(), "Cangjie")
    @Expect(source == clone, true)
    @Expect(built.get(), "AB")

    built.close()
    clone.close()
    source.close()
    builder.close()
    @Expect(built.isClosed(), true)
    @Expect(clone.isClosed(), true)
    @Expect(source.isClosed(), true)
}

@Test
func testHStringCloseReleasesOwnedStorageOnce() {
    let before = debugObservedHStringFreeCount()
    let value = HString("owned")

    value.close()
    let afterClose = debugObservedHStringFreeCount()
    value.close()

    @Expect(afterClose, before + 1i32)
    @Expect(debugObservedHStringFreeCount(), afterClose)
    @Expect(value.isClosed(), true)
    @Expect(value.asRaw().isNull(), true)
    @Expect(value.length(), 0)
}

@Test
func testHStringBuilderCloseReleasesOwnedStorageOnce() {
    let before = debugObservedHStringFreeCount()
    let builder = HStringBuilder(1)

    builder.close()
    let afterClose = debugObservedHStringFreeCount()
    builder.close()

    @Expect(afterClose, before + 1i32)
    @Expect(debugObservedHStringFreeCount(), afterClose)
    @Expect(builder.isClosed(), true)
    @Expect(builder.asRaw().isNull(), true)
    @Expect(builder.length(), 0)
}

@Test
func testHStringLocalHeaderTakeConsumesLocalHeader() {
    let source = HString("local")
    let raw = source.intoRaw()
    let projected = HString.fromLocalHeaderTake(raw)

    @Expect(source.isClosed(), true)
    @Expect(projected.get(), "local")

    projected.close()
}

@When[os == "Windows"]
@Test
func testHStringSystemHandleCopyRoundTripsThroughSystemOwnership() {
    let source = HString("system")
    let raw = source.toSystemHandleCopy()
    let projected = HString.fromSystemHandleTake(raw)

    @Expect(projected.get(), "system")
    @Expect(source.get(), "system")

    projected.close()
    source.close()
}

@When[os == "Windows"]
@Test
func testHStringAbiTakeConsumesSystemHandle() {
    let source = HString("abi")
    let raw = source.toSystemHandleCopy()
    let projected = HString.fromAbiTake(raw)

    @Expect(projected.get(), "abi")
    @Expect(source.get(), "abi")

    projected.close()
    source.close()
}

@When[os == "Windows"]
@Test
func testHStringSystemHandleBorrowCopyLeavesSourceHandleLive() {
    let source = HString("borrowed")
    let raw = source.toSystemHandleCopy()
    let borrowed = HString.fromSystemHandleCopy(raw)
    let consumed = HString.fromSystemHandleTake(raw)

    @Expect(borrowed.get(), "borrowed")
    @Expect(consumed.get(), "borrowed")
    @Expect(source.get(), "borrowed")

    consumed.close()
    borrowed.close()
    source.close()
}
