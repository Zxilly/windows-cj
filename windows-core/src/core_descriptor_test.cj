package windows_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testGuidValueRoundTripAndInvalidParse() {
    let guid = GuidValue.from_values(
        0x00112233u32,
        0x4455u16,
        0x6677u16,
        0x88u8,
        0x99u8,
        0xAAu8,
        0xBBu8,
        0xCCu8,
        0xDDu8,
        0xEEu8,
        0xFFu8
    )
    let roundTrip = GuidValue.from_u128(guid.to_u128())

    @Expect(guid.isZero(), false)
    @Expect(roundTrip == guid, true)
    @Expect(guid.toString(), "00112233-4455-6677-8899-AABBCCDDEEFF")
    @Expect(GuidValue.fromString("00112233-4455-6677-8899-AABBCCDDEEFF").isSome(), true)
    @Expect(GuidValue.fromString("00112233-4455-6677-8899-AABBCCDDEEFZ").isNone(), true)
}

@Test
func testHResultConstantsExposeSuccessAndFailureBits() {
    @Expect(S_OK.value, 0i32)
    @Expect(S_FALSE.isOk(), true)
    @Expect(E_POINTER.isErr(), true)
    @Expect(E_POINTER.toString(), "0x80004003")
    @Expect(REGDB_E_CLASSNOTREG.value, -2147221164i32)
    @Expect(CO_E_NOTINITIALIZED.value, -2147221008i32)
}

@Test
func testIUnknownDescriptorAndNullAbiBasics() {
    let descriptor = IUnknown.descriptor()

    @Expect(descriptor.descriptorName(), "IUnknown")
    @Expect(descriptor.descriptorIid() == IUnknown.IID(), true)
    @Expect(descriptor.descriptorIid().toString(), "00000000-0000-0000-C000-000000000046")
    @Expect(IUnknown.UNKNOWN(), true)
    @Expect(IUnknown.abiType(), "pointer")
    @Expect(IUnknown.isNullAbi(CPointer<Unit>()), true)
    @Expect(IUnknown.fromAbi(CPointer<Unit>()).isErr(), true)
}
