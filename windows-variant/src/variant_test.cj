package windows_variant

import std.unittest.*
import std.unittest.testmacro.*
import windows_strings.BSTR

@Test
func variantBoolHelpersUseComTruthValues(): Unit {
    @Expect(variantBool(true), -1i16)
    @Expect(variantBool(false), 0i16)
    @Expect(variantBoolToBool(-1i16), true)
    @Expect(variantBoolToBool(1i16), true)
    @Expect(variantBoolToBool(0i16), false)
    @Expect(isVariantTrue(-1i16), true)
    @Expect(isVariantFalse(0i16), true)
}

@Test
func scalarVariantsRoundTrip(): Unit {
    let boolValue = variantFromBool(true)
    @Expect(variantVt(boolValue), VT_BOOL)
    @Expect(variantAsBool(boolValue), Some(true))
    @Expect(variantAsI4(boolValue), None)

    let i4Value = variantFromI4(-7i32)
    @Expect(variantVt(i4Value), VT_I4)
    @Expect(variantAsI4(i4Value), Some(-7i32))

    let ui4Value = variantFromUI4(42u32)
    @Expect(variantVt(ui4Value), VT_UI4)
    @Expect(variantAsUI4(ui4Value), Some(42u32))

    let i8Value = variantFromI8(-9000i64)
    @Expect(variantVt(i8Value), VT_I8)
    @Expect(variantAsI8(i8Value), Some(-9000i64))

    let r4Value = variantFromR4(1.25f32)
    @Expect(variantVt(r4Value), VT_R4)
    @Expect(variantAsR4(r4Value), Some(1.25f32))

    let r8Value = variantFromR8(2.5)
    @Expect(variantVt(r8Value), VT_R8)
    @Expect(variantAsR8(r8Value), Some(2.5))
}

@Test
func additionalScalarVariantsRoundTrip(): Unit {
    @Expect(variantAsInt8(variantFromInt8(-8i8)), Some(-8i8))
    @Expect(variantAsUInt8(variantFromUInt8(8u8)), Some(8u8))
    @Expect(variantAsInt16(variantFromInt16(-16i16)), Some(-16i16))
    @Expect(variantAsUInt16(variantFromUInt16(16u16)), Some(16u16))
    @Expect(variantAsUInt64(variantFromUInt64(64u64)), Some(64u64))
    @Expect(variantAsDate(variantFromDate(42.0)), Some(42.0))
    @Expect(variantAsError(variantFromError(-1i32)), Some(-1i32))
    @Expect(variantAsWin32Int(variantFromWin32Int(123i32)), Some(123i32))
    @Expect(variantAsWin32UInt(variantFromWin32UInt(123u32)), Some(123u32))
    @Expect(variantIsEmpty(emptyVariant()), true)
    @Expect(variantIsNull(nullVariant()), true)
    @Expect(variantIsScalar(variantFromUInt64(64u64)), true)
}

@Test
func extendedVtConstantsAreExposed(): Unit {
    @Expect(VT_BSTR, 8u16)
    @Expect(VT_DISPATCH, 9u16)
    @Expect(VT_UNKNOWN, 13u16)
    @Expect(VT_DECIMAL, 14u16)
    @Expect(VT_SAFEARRAY, 27u16)
    @Expect(VT_LPSTR, 30u16)
    @Expect(VT_LPWSTR, 31u16)
    @Expect(VT_FILETIME, 64u16)
    @Expect(VT_CLSID, 72u16)
    @Expect(VT_ARRAY, 8192u16)
    @Expect(VT_BYREF, 16384u16)
    @Expect(VT_TYPEMASK, 4095u16)
}

@Test
func bstrVariantsRoundTrip(): Unit {
    let bstrValue = variantFromString("hello")
    @Expect(variantVt(bstrValue), VT_BSTR)
    let view = variantAsBstr(bstrValue).getOrThrow()
    @Expect(view.get(), "hello")
    // Wrap so the BSTR storage is released via VariantClear.
    let owned = Variant(bstrValue)
    @Expect(owned.vt(), VT_BSTR)
    owned.close()
    @Expect(owned.isClosed(), true)
}

@Test
func variantResourceRoundTripsScalar(): Unit {
    let owned = Variant(variantFromI4(42i32))
    @Expect(owned.vt(), VT_I4)
    @Expect(variantAsI4(owned.get()), Some(42i32))
    let cloned = owned.cloneSelf()
    @Expect(cloned.vt(), VT_I4)
    @Expect(variantAsI4(cloned.get()), Some(42i32))
    owned.close()
    cloned.close()
    @Expect(owned.isClosed(), true)
    @Expect(cloned.isClosed(), true)
}

@Test
func variantCopyDeepCopiesBstr(): Unit {
    let source = Variant(variantFromString("payload"))
    let cloneCount = debugObservedVariantCopyCount()
    let dup = source.cloneSelf()
    @Expect(dup.vt(), VT_BSTR)
    @Expect(debugObservedVariantCopyCount() > cloneCount, true)
    @Expect(variantAsBstr(dup.get()).getOrThrow().get(), "payload")
    @Expect(variantAsBstr(source.get()).getOrThrow().get(), "payload")
    source.close()
    dup.close()
}

@Test
func variantClearReleasesBstrAllocation(): Unit {
    let before = debugObservedVariantClearCount()
    let owned = Variant(variantFromString("transient"))
    owned.close()
    @Expect(debugObservedVariantClearCount() > before, true)
}

@Test
func unknownDispatchSafeArrayPayloadsRoundTripRawPointers(): Unit {
    let unkPayload = variantFromUnknownRaw(CPointer<Unit>())
    @Expect(variantVt(unkPayload), VT_UNKNOWN)
    @Expect(variantAsUnknownRaw(unkPayload).getOrThrow().isNull(), true)

    let dispPayload = variantFromDispatchRaw(CPointer<Unit>())
    @Expect(variantVt(dispPayload), VT_DISPATCH)
    @Expect(variantAsDispatchRaw(dispPayload).getOrThrow().isNull(), true)

    let arrayPayload = variantFromSafeArrayRaw(CPointer<Unit>())
    @Expect(variantVt(arrayPayload), VT_SAFEARRAY)
    @Expect(variantAsSafeArrayRaw(arrayPayload).getOrThrow().isNull(), true)
}
