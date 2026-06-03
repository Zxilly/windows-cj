package windows_reference

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{GuidValue, HString}
import windows_foundation.{PropertyType_Boolean, PropertyType_Int32, PropertyType_String}

@Test
func testReferenceRoundTripsPrimitiveValues() {
    let intRef = IReference<Int32>.from(42i32)
    @Expect(unsafe { intRef.Value() }, 42i32)
    @Expect(unsafe { intRef.Type() }.value, PropertyType_Int32.value)
    @Expect(unsafe { intRef.IsNumericScalar() }, true)
    @Expect(unsafe { intRef.GetInt32() }, 42i32)

    let boolRef = IReference<Bool>.from(true)
    @Expect(unsafe { boolRef.Value() }, true)
    @Expect(unsafe { boolRef.Type() }.value, PropertyType_Boolean.value)
    @Expect(unsafe { boolRef.IsNumericScalar() }, false)
}

@Test
func testReferenceRoundTripsHStringAndGuid() {
    let stringRef = IReference<HString>.from("hello")
    let value = unsafe { stringRef.Value() }
    try {
        @Expect(value.get(), "hello")
        @Expect(unsafe { stringRef.Type() }.value, PropertyType_String.value)
    } finally {
        value.close()
    }

    let guid = GuidValue.from_values(
        0x11223344u32,
        0x5566u16,
        0x7788u16,
        0x99u8,
        0xaau8,
        0xbbu8,
        0xccu8,
        0xddu8,
        0xeeu8,
        0xffu8,
        0x00u8
    )
    let guidRef = IReference<GuidValue>.from(guid)
    @Expect(unsafe { guidRef.Value() }.toString(), guid.toString())
}
