package windows_strings

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testNullPointerStringsAreEmptyAndLossless() {
    let wide = PCWSTR.null()
    let narrow = PCSTR.null()

    unsafe {
        @Expect(wide.isNull(), true)
        @Expect(wide.length(), 0)
        @Expect(wide.isEmpty(), true)
        @Expect(wide.toArray().size, 0)
        @Expect(wide.toString(), Some(""))

        @Expect(narrow.isNull(), true)
        @Expect(narrow.length(), 0)
        @Expect(narrow.isEmpty(), true)
        @Expect(narrow.toArray().size, 0)
        @Expect(narrow.toString(), Some(""))
    }
}

@Test
func testMutablePointersConvertToConstPointerViews() {
    let wide = PWSTR.null()
    let narrow = PSTR.null()

    @Expect(wide.toPCWSTR().isNull(), true)
    @Expect(narrow.toPCSTR().isNull(), true)
    @Expect(wide == PWSTR.default(), true)
    @Expect(narrow == PSTR.default(), true)
}

@Test
func testEmptyBstrDoesNotOwnStorageAndClosesToNull() {
    let empty = BSTR()

    @Expect(empty.length(), 0)
    @Expect(empty.byteLength(), 0u32)
    @Expect(empty.isEmpty(), true)
    @Expect(empty.ownsStorage(), false)
    @Expect(empty.asPtr().isNull(), true)
    @Expect(empty.tryToString(), Some(""))
    @Expect(empty.toWideArray().size, 0)

    empty.close()

    @Expect(empty.isClosed(), true)
    @Expect(empty.asPtr().isNull(), true)
    @Expect(empty.tryToString(), Some(""))
}

@When[os == "Windows"]
@Test
func testBstrRawConstructorsExposeOwnershipSemantics() {
    let source = BSTR("raw")
    let raw = source.intoRaw()
    let taken = BSTR.fromRawTake(raw)

    @Expect(source.isClosed(), true)
    @Expect(taken.ownsStorage(), true)
    @Expect(taken.get(), "raw")
    taken.close()

    let owner = BSTR("view")
    let view = BSTR.fromRawView(owner.asPtr())
    @Expect(view.ownsStorage(), false)
    @Expect(view.get(), "view")
    view.close()
    owner.close()
}

@When[os == "Windows"]
@Test
func testBstrCloseReleasesOwnedStorageOnce() {
    let before = debugObservedSysFreeStringCount()
    let value = BSTR("owned")

    value.close()
    let afterClose = debugObservedSysFreeStringCount()
    value.close()

    @Expect(afterClose, before + 1i32)
    @Expect(debugObservedSysFreeStringCount(), afterClose)
    @Expect(value.isClosed(), true)
    @Expect(value.ownsStorage(), false)
    @Expect(value.asPtr().isNull(), true)
    @Expect(value.length(), 0)
}
