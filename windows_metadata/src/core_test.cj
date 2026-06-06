package windows_metadata

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testByteReaderUsesLittleEndianAndNullTerminatedStrings() {
    let reader = ByteReader([
        0x78u8, 0x56u8, 0x34u8, 0x12u8,
        0xEFu8, 0xCDu8, 0xABu8, 0x90u8,
        0x41u8, 0x42u8, 0u8, 0x43u8
    ])

    @Expect(reader.readUInt16(0), 0x5678u16)
    @Expect(reader.readUInt32(0), 0x12345678u32)
    @Expect(reader.readUInt64(0), 0x90ABCDEF12345678u64)
    @Expect(reader.readNullTermStr(8), "AB")
    @Expect(reader.readByWidth(2, 2), 0x1234i64)
    @Expect(reader.readByWidth(0, 4), 0x12345678i64)
}

@Test
func testMetadataTypeStableKeysAndTypeNameDefinitions() {
    let genericArgs = ArrayList<MetadataType>()
    genericArgs.add(MetadataType.ClassName(TypeName.named("Windows.Foundation", "Uri")))
    let name = TypeName("Windows.Foundation.Collections", "IVector`1", genericArgs)

    @Expect(name.definition().toString(), "Windows.Foundation.Collections.IVector")
    @Expect(name.definitionMatches("Windows.Foundation.Collections", "IVector"), true)
    @Expect(metadataTypeStableKey(MetadataType.MdArray(MetadataType.U32)), "array:U32")
    @Expect(
        metadataTypeStableKey(MetadataType.PtrConst(MetadataType.ValueName(name), 2)),
        "ptrconst:2:value:Windows.Foundation.Collections.IVector`1<class:Windows.Foundation.Uri>"
    )
}
