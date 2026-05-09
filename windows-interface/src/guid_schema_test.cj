package windows_interface

import std.unittest.*
import std.unittest.testmacro.*

func optionStringEquals(value: Option<String>, expected: String): Bool {
    match (value) {
        case Some(actual) => actual == expected
        case None => false
    }
}

@Test
func testGuidParsingAndRoundTrip() {
    let parsed = GUID.parse("00112233-4455-6677-8899-AABBCCDDEEFF")
    let roundTrip = GUID.from_u128(parsed.to_u128())

    @Expect(parsed.data1, 0x00112233u32)
    @Expect(parsed.data2, 0x4455u16)
    @Expect(parsed.data3, 0x6677u16)
    @Expect(parsed.data4[0], 0x88u8)
    @Expect(parsed.data4[7], 0xFFu8)
    @Expect(roundTrip == parsed, true)
    @Expect(parsed.toString(), "00112233-4455-6677-8899-AABBCCDDEEFF")
    @Expect(GUID.fromString("not-a-guid").isNone(), true)
}

@Test
func testDescriptorSchemaExpandsDirectBaseAndExtraAncestors() {
    let base = InterfaceDescriptorSchema(
        "IBase",
        GUID.parse("00000001-0000-0000-C000-000000000046"),
        "IBaseVtbl",
        "IBase",
        "IBase_Impl",
        []
    )
    let extraIid = GUID.parse("00000002-0000-0000-C000-000000000046")
    let derived = InterfaceDescriptorSchema(
        "IDerived",
        GUID.parse("00000003-0000-0000-C000-000000000046"),
        base,
        ["IExtra", "IBase"],
        [extraIid, base.iid],
        "IDerivedVtbl",
        "IDerived",
        "IDerived_Impl",
        [InterfaceMethodSchema("Call", 6, [], "Int32")]
    )

    @Expect(optionStringEquals(derived.baseInterfaceName, "IBase"), true)
    @Expect(derived.ancestorInterfaceNames.size, 2)
    @Expect(derived.ancestorInterfaceNames[0], "IBase")
    @Expect(derived.ancestorInterfaceNames[1], "IExtra")
    @Expect(derived.ancestorIids.size, 2)
    @Expect(derived.methods[0].name, "Call")
}
