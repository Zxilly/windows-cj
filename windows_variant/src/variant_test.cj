package windows_variant

import std.unittest.*
import std.unittest.testmacro.*
import windows_sys.Win32.System.Com.IUnknownVtbl
import windows_strings.HString
import windows_strings.debugObservedWindowsCreateStringCount
import windows_strings.debugObservedWindowsDeleteStringCount

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
    let afterClose = debugObservedVariantClearCount()
    @Expect(afterClose > before, true)
    owned.close()
    @Expect(debugObservedVariantClearCount(), afterClose)
}

@When[os == "Windows"]
@Test
func oleautVariantChangeTypeConsumesCangjieVariants(): Unit {
    let textSource = Variant(variantFromString("42"))
    let numberSource = Variant(variantFromI4(7i32))
    let numberResult = variantSmokeChangeType(textSource.get(), VT_I4)
    let textResult = variantSmokeChangeType(numberSource.get(), VT_BSTR)
    try {
        @Expect(numberResult.vt(), VT_I4)
        @Expect(variantAsI4(numberResult.get()), Some(42i32))
        @Expect(textResult.vt(), VT_BSTR)
        @Expect(variantAsBstr(textResult.get()).getOrThrow().get(), "7")
    } finally {
        textSource.close()
        numberSource.close()
        numberResult.close()
        textResult.close()
    }
}

@Test
func variantCloseIsReleaseReentrantSafe(): Unit {
    ensureVariantClearAbiResolved()
    var vtbl = IUnknownVtbl()
    vtbl.Release = reentrantVariantRelease
    var object = ReentrantVariantUnknown()
    object.lpVtbl = CPointer<IUnknownVtbl>(inout vtbl)
    reentrantVariantReleaseCalls = 0u32

    let owned = Variant(variantFromUnknownRaw(CPointer<Unit>(inout object)))
    reentrantVariantTarget = Some(owned)
    try {
        owned.close()
        @Expect(owned.isClosed(), true)
        @Expect(reentrantVariantReleaseCalls, 1u32)
    } finally {
        reentrantVariantTarget = None
    }
}

@Test
func variantCopyAndClearDeepCopiesBstrSafeArray(): Unit {
    ensureVariantClearAbiResolved()
    let clearBefore = debugObservedVariantClearCount()
    let copyBefore = debugObservedVariantCopyCount()
    let raw = variantSmokeCreateBstrSafeArray(["left", "right"])
    let source = Variant(variantSmokeFromSafeArrayRaw(VT_BSTR, raw))
    let dup = source.cloneSelf()
    try {
        @Expect(source.vt(), VT_ARRAY | VT_BSTR)
        @Expect(dup.vt(), VT_ARRAY | VT_BSTR)
        @Expect(debugObservedVariantCopyCount() > copyBefore, true)

        let sourceArray = variantSmokeSafeArrayRaw(source.get())
        let dupArray = variantSmokeSafeArrayRaw(dup.get())
        @Expect(variantSmokeSafeArrayBstrText(sourceArray, 0), "left")
        @Expect(variantSmokeSafeArrayBstrText(dupArray, 0), "left")

        variantSmokeSafeArraySetBstr(sourceArray, 0, "changed")
        @Expect(variantSmokeSafeArrayBstrText(sourceArray, 0), "changed")
        @Expect(variantSmokeSafeArrayBstrText(dupArray, 0), "left")
    } finally {
        source.close()
        dup.close()
    }

    let clearAfter = debugObservedVariantClearCount()
    @Expect(clearAfter >= clearBefore + 2i32, true)
    source.close()
    dup.close()
    @Expect(debugObservedVariantClearCount(), clearAfter)
    @Expect(source.isClosed(), true)
    @Expect(dup.isClosed(), true)
}

@Test
func variantCloseRetainsPayloadWhenClearFails(): Unit {
    ensureVariantClearAbiResolved()
    let raw = variantSmokeCreateBstrSafeArray(["locked"])
    variantSmokeSafeArrayLock(raw)
    let owned = Variant(variantSmokeFromSafeArrayRaw(VT_BSTR, raw))

    @Expect(variantTestThrows({ => owned.close() }), true)
    @Expect(owned.isClosed(), false)
    @Expect(owned.vt(), VT_ARRAY | VT_BSTR)
    @Expect(variantSmokeSafeArrayRaw(owned.get()).toUIntNative(), raw.toUIntNative())

    variantSmokeSafeArrayUnlock(raw)
    owned.close()
    @Expect(owned.isClosed(), true)
}

@When[os == "Windows"]
@Test
func hstringSystemHandleFeedsBstrVariantWithExplicitClose(): Unit {
    let createBefore = debugObservedWindowsCreateStringCount()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    let source = HString("variant-hstring")
    let raw = source.toSystemHandleCopy()
    let projected = HString.fromSystemHandleTake(raw)
    let owned = Variant(variantFromString(projected.get()))

    try {
        @Expect(debugObservedWindowsCreateStringCount(), createBefore + 1i32)
        @Expect(debugObservedWindowsDeleteStringCount(), deleteBefore + 1i32)
        @Expect(owned.vt(), VT_BSTR)
        @Expect(variantAsBstr(owned.get()).getOrThrow().get(), "variant-hstring")
    } finally {
        owned.close()
        projected.close()
        source.close()
    }

    @Expect(owned.isClosed(), true)
    @Expect(projected.isClosed(), true)
    @Expect(source.isClosed(), true)
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
