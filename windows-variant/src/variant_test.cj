package windows_variant

import std.unittest.*
import std.unittest.testmacro.*
import windows_common.Win32.System.Com.IUnknownVtbl
import windows_strings.BSTR
import windows_strings.HString
import windows_strings.debugObservedWindowsCreateStringCount
import windows_strings.debugObservedWindowsDeleteStringCount
import windows_libloading as windows_libloading

func variantSmokeOleAut32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw VariantAbiException("failed to resolve OleAut32 smoke ABI '${name}'")
    }
}

func variantSmokeChangeType(value: VARIANT, target: VARENUM): Variant {
    let proc = variantSmokeOleAut32Proc("VariantChangeType")
    let changeFn = CFunc<(CPointer<VARIANT>, CPointer<VARIANT>, UInt16, VARENUM) -> Int32>(proc)
    var source = value
    var result = VARIANT()
    let sourcePtr = unsafe { CPointer<VARIANT>(inout source) }
    let resultPtr = unsafe { CPointer<VARIANT>(inout result) }
    variantInit(resultPtr)
    let hr = unsafe { changeFn(resultPtr, sourcePtr, 0u16, target) }
    if (hr < 0) {
        let _ = variantClear(resultPtr)
        throw VariantAbiException("VariantChangeType failed in VARIANT smoke test with HRESULT ${hr}")
    }
    Variant(result)
}

func variantSmokeSafeArrayCreateVector(vt: VARENUM, count: Int64): CPointer<Unit> {
    let proc = variantSmokeOleAut32Proc("SafeArrayCreateVector")
    let createFn = CFunc<(UInt16, Int32, UInt32) -> CPointer<Unit>>(proc)
    let handle = unsafe { createFn(vt, 0i32, UInt32(count)) }
    if (handle.isNull()) {
        throw VariantAbiException("SafeArrayCreateVector returned null in VARIANT smoke test")
    }
    handle
}

func variantSmokeSafeArrayDestroy(handle: CPointer<Unit>): Unit {
    if (handle.isNull()) {
        return
    }
    let proc = variantSmokeOleAut32Proc("SafeArrayDestroy")
    let destroyFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { destroyFn(handle) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayDestroy failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayLock(handle: CPointer<Unit>): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayLock")
    let lockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { lockFn(handle) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayLock failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayUnlock(handle: CPointer<Unit>): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayUnlock")
    let unlockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { unlockFn(handle) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayUnlock failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayPutElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayPutElement")
    let putFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { putFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayPutElement failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArrayGetElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = variantSmokeOleAut32Proc("SafeArrayGetElement")
    let getFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { getFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw VariantAbiException("SafeArrayGetElement failed in VARIANT smoke test with HRESULT ${hr}")
    }
}

func variantSmokeSafeArraySetBstr(handle: CPointer<Unit>, index: Int64, value: String): Unit {
    let bstr = BSTR(value)
    try {
        var indexSlot = Int32(index)
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        let rawUnit = unsafe { CPointer<Unit>(bstr.asPtr()) }
        variantSmokeSafeArrayPutElement(handle, indexPtr, rawUnit)
    } finally {
        bstr.close()
    }
}

func variantSmokeSafeArrayBstrText(handle: CPointer<Unit>, index: Int64): String {
    var indexSlot = Int32(index)
    let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
    var raw: CPointer<UInt16> = CPointer<UInt16>()
    let rawPtr = unsafe { CPointer<CPointer<UInt16>>(inout raw) }
    let rawPtrUnit = unsafe { CPointer<Unit>(rawPtr) }
    variantSmokeSafeArrayGetElement(handle, indexPtr, rawPtrUnit)
    let bstr = BSTR.fromRawTake(raw)
    var text = ""
    try {
        text = bstr.get()
    } finally {
        bstr.close()
    }
    text
}

func variantSmokeCreateBstrSafeArray(values: Array<String>): CPointer<Unit> {
    let handle = variantSmokeSafeArrayCreateVector(VT_BSTR, values.size)
    var completed = false
    try {
        for (i in 0..values.size) {
            variantSmokeSafeArraySetBstr(handle, i, values[i])
        }
        completed = true
    } finally {
        if (!completed) {
            variantSmokeSafeArrayDestroy(handle)
        }
    }
    handle
}

func variantSmokeFromSafeArrayRaw(vt: VARENUM, handle: CPointer<Unit>): VARIANT {
    var payload = VariantValue()
    payload.parray = handle
    variantWithPayload(VT_ARRAY | vt, payload)
}

func variantSmokeSafeArrayRaw(value: VARIANT): CPointer<Unit> {
    variantPayload(value).Anonymous.parray
}

func variantTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@C
struct ReentrantVariantUnknown {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

var reentrantVariantTarget: Option<Variant> = None
var reentrantVariantReleaseCalls: UInt32 = 0u32

@C
func reentrantVariantRelease(_: CPointer<Unit>): UInt32 {
    reentrantVariantReleaseCalls += 1u32
    if (let Some(target) <- reentrantVariantTarget) {
        target.close()
    }
    0u32
}

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
