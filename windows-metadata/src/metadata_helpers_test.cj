package windows_metadata

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testCodedIndexSizeThresholdAndRoundTrip() {
    @Expect(codedIndexSize([16383, 1, 0]), 2)
    @Expect(codedIndexSize([16384, 1, 0]), 4)

    let encoded = encodeCodedIndex(1, 41, CODED_TYPE_DEF_OR_REF_BITS)
    let (table, row) = decodeCodedIndex(encoded, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)

    @Expect(table, TABLE_TYPE_REF)
    @Expect(row, 41)
}

@Test
func testHasCustomAttributeEncodingReturnsNoneForUnsupportedTable() {
    match (encodeHasCustomAttribute(TABLE_METHOD_DEF, 4)) {
        case Some(value) => @Expect(value, encodeCodedIndex(0, 4, CODED_HAS_CUSTOM_ATTRIBUTE_BITS))
        case None => @Expect(false, true)
    }

    match (encodeHasCustomAttribute(TABLE_COUNT, 0)) {
        case Some(_) => @Expect(false, true)
        case None => @Expect(true, true)
    }
}

@Test
func testBlobReaderCompressedAndUtf16EdgeCases() {
    let single = BlobReader([0x7Fu8], 0, 1)
    let two = BlobReader([0x80u8, 0x80u8], 0, 2)
    let four = BlobReader([0xC0u8, 0x00u8, 0x40u8, 0x00u8], 0, 4)
    let utf16 = BlobReader([0x41u8, 0x00u8, 0x3Du8, 0xD8u8, 0x00u8, 0xDEu8], 0, 6)

    @Expect(single.readCompressed(), 0x7F)
    @Expect(two.readCompressed(), 0x80)
    @Expect(four.readCompressed(), 0x4000)
    @Expect(utf16.readUtf16(), "A${Rune(0x1F600u32)}")
}
