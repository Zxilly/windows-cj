package windows_propvariant

import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.GUID
import windows_interface.IUnknownVtbl
import windows_strings.BSTR
import windows_strings.HString
import windows_strings.decodeWideFromPointer
import windows_strings.debugObservedWindowsCreateStringCount
import windows_strings.debugObservedWindowsDeleteStringCount
import windows_libloading as windows_libloading

func propVariantSmokeOleAut32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw PropVariantAbiException("failed to resolve OleAut32 smoke ABI '${name}'")
    }
}

func propVariantSmokePropsysProc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("propsys.dll", name)
    } catch (_: Exception) {
        throw PropVariantAbiException("failed to resolve Propsys smoke ABI '${name}'")
    }
}

func propVariantSmokeToString(value: PROPVARIANT): String {
    let proc = propVariantSmokePropsysProc("PropVariantToString")
    let toStringFn = CFunc<(CPointer<PROPVARIANT>, CPointer<UInt16>, UInt32) -> Int32>(proc)
    var local = value
    var buffer = Array<UInt16>(128, { _ => 0u16 })
    let valuePtr = unsafe { CPointer<PROPVARIANT>(inout local) }
    let handle = unsafe { acquireArrayRawData(buffer) }
    try {
        let hr = unsafe { toStringFn(valuePtr, handle.pointer, UInt32(buffer.size)) }
        if (hr < 0) {
            throw PropVariantAbiException("PropVariantToString failed in PROPVARIANT smoke test with HRESULT ${hr}")
        }
        decodeWideFromPointer(handle.pointer)
    } finally {
        unsafe { releaseArrayRawData(handle) }
    }
}

func propVariantSmokeToInt32(value: PROPVARIANT): Int32 {
    let proc = propVariantSmokePropsysProc("PropVariantToInt32")
    let toInt32Fn = CFunc<(CPointer<PROPVARIANT>, CPointer<Int32>) -> Int32>(proc)
    var local = value
    var result: Int32 = 0
    let valuePtr = unsafe { CPointer<PROPVARIANT>(inout local) }
    let resultPtr = unsafe { CPointer<Int32>(inout result) }
    let hr = unsafe { toInt32Fn(valuePtr, resultPtr) }
    if (hr < 0) {
        throw PropVariantAbiException("PropVariantToInt32 failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
    result
}

func propVariantSmokeSafeArrayCreateVector(vt: VARENUM, count: Int64): CPointer<Unit> {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayCreateVector")
    let createFn = CFunc<(UInt16, Int32, UInt32) -> CPointer<Unit>>(proc)
    let handle = unsafe { createFn(vt, 0i32, UInt32(count)) }
    if (handle.isNull()) {
        throw PropVariantAbiException("SafeArrayCreateVector returned null in PROPVARIANT smoke test")
    }
    handle
}

func propVariantSmokeSafeArrayDestroy(handle: CPointer<Unit>): Unit {
    if (handle.isNull()) {
        return
    }
    let proc = propVariantSmokeOleAut32Proc("SafeArrayDestroy")
    let destroyFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { destroyFn(handle) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayDestroy failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayLock(handle: CPointer<Unit>): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayLock")
    let lockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { lockFn(handle) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayLock failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayUnlock(handle: CPointer<Unit>): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayUnlock")
    let unlockFn = CFunc<(CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { unlockFn(handle) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayUnlock failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayPutElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayPutElement")
    let putFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { putFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayPutElement failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArrayGetElement(
    handle: CPointer<Unit>,
    indexPtr: CPointer<Int32>,
    dataPtr: CPointer<Unit>
): Unit {
    let proc = propVariantSmokeOleAut32Proc("SafeArrayGetElement")
    let getFn = CFunc<(CPointer<Unit>, CPointer<Int32>, CPointer<Unit>) -> Int32>(proc)
    let hr = unsafe { getFn(handle, indexPtr, dataPtr) }
    if (hr < 0) {
        throw PropVariantAbiException("SafeArrayGetElement failed in PROPVARIANT smoke test with HRESULT ${hr}")
    }
}

func propVariantSmokeSafeArraySetBstr(handle: CPointer<Unit>, index: Int64, value: String): Unit {
    let bstr = BSTR(value)
    try {
        var indexSlot = Int32(index)
        let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
        let rawUnit = unsafe { CPointer<Unit>(bstr.asPtr()) }
        propVariantSmokeSafeArrayPutElement(handle, indexPtr, rawUnit)
    } finally {
        bstr.close()
    }
}

func propVariantSmokeSafeArrayBstrText(handle: CPointer<Unit>, index: Int64): String {
    var indexSlot = Int32(index)
    let indexPtr = unsafe { CPointer<Int32>(inout indexSlot) }
    var raw: CPointer<UInt16> = CPointer<UInt16>()
    let rawPtr = unsafe { CPointer<CPointer<UInt16>>(inout raw) }
    let rawPtrUnit = unsafe { CPointer<Unit>(rawPtr) }
    propVariantSmokeSafeArrayGetElement(handle, indexPtr, rawPtrUnit)
    let bstr = BSTR.fromRawTake(raw)
    var text = ""
    try {
        text = bstr.get()
    } finally {
        bstr.close()
    }
    text
}

func propVariantSmokeCreateBstrSafeArray(values: Array<String>): CPointer<Unit> {
    let handle = propVariantSmokeSafeArrayCreateVector(VT_BSTR, values.size)
    var completed = false
    try {
        for (i in 0..values.size) {
            propVariantSmokeSafeArraySetBstr(handle, i, values[i])
        }
        completed = true
    } finally {
        if (!completed) {
            propVariantSmokeSafeArrayDestroy(handle)
        }
    }
    handle
}

func propVariantSmokeFromSafeArrayRaw(vt: VARENUM, handle: CPointer<Unit>): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_ARRAY | vt))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        writePayloadPointer(payloadBase(slotPtr), 0, handle)
    }
    result
}

func propVariantSmokeSafeArrayRaw(value: PROPVARIANT): CPointer<Unit> {
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        readPayloadPointer(payloadBase(slotPtr), 0)
    }
}

func propVariantTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@C
struct ReentrantPropVariantUnknown {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

var reentrantPropVariantTarget: Option<PropVariant> = None
var reentrantPropVariantReleaseCalls: UInt32 = 0u32

@C
func reentrantPropVariantRelease(_: CPointer<Unit>): UInt32 {
    reentrantPropVariantReleaseCalls += 1u32
    if (let Some(target) <- reentrantPropVariantTarget) {
        target.close()
    }
    0u32
}

@Test
func scalarPropVariantsRoundTrip(): Unit {
    let boolValue = propVariantFromBool(true)
    @Expect(propVariantVt(boolValue), VT_BOOL)
    @Expect(propVariantAsBool(boolValue), Some(true))
    @Expect(propVariantAsInt32(boolValue), None)

    let i4Value = propVariantFromInt32(-7i32)
    @Expect(propVariantVt(i4Value), VT_I4)
    @Expect(propVariantAsInt32(i4Value), Some(-7i32))

    let ui4Value = propVariantFromUInt32(42u32)
    @Expect(propVariantVt(ui4Value), VT_UI4)
    @Expect(propVariantAsUInt32(ui4Value), Some(42u32))

    let i8Value = propVariantFromInt64(-9000i64)
    @Expect(propVariantVt(i8Value), VT_I8)
    @Expect(propVariantAsInt64(i8Value), Some(-9000i64))

    let r4Value = propVariantFromFloat32(1.25f32)
    @Expect(propVariantVt(r4Value), VT_R4)
    @Expect(propVariantAsFloat32(r4Value), Some(1.25f32))

    let r8Value = propVariantFromFloat64(2.5)
    @Expect(propVariantVt(r8Value), VT_R8)
    @Expect(propVariantAsFloat64(r8Value), Some(2.5))
}

@Test
func additionalScalarPropVariantsRoundTrip(): Unit {
    @Expect(propVariantAsInt8(propVariantFromInt8(-8i8)), Some(-8i8))
    @Expect(propVariantAsUInt8(propVariantFromUInt8(8u8)), Some(8u8))
    @Expect(propVariantAsInt16(propVariantFromInt16(-16i16)), Some(-16i16))
    @Expect(propVariantAsUInt16(propVariantFromUInt16(16u16)), Some(16u16))
    @Expect(propVariantAsUInt64(propVariantFromUInt64(64u64)), Some(64u64))
    @Expect(propVariantAsError(propVariantFromError(-1i32)), Some(-1i32))
    @Expect(propVariantIsEmpty(emptyPropVariant()), true)
    @Expect(propVariantIsNull(nullPropVariant()), true)
    @Expect(propVariantIsScalar(propVariantFromUInt64(64u64)), true)
}

@Test
func extendedPropVtConstantsAreExposed(): Unit {
    @Expect(VT_LPSTR, 30u16)
    @Expect(VT_LPWSTR, 31u16)
    @Expect(VT_FILETIME, 64u16)
    @Expect(VT_BLOB, 65u16)
    @Expect(VT_STREAM, 66u16)
    @Expect(VT_STORAGE, 67u16)
    @Expect(VT_STREAMED_OBJECT, 68u16)
    @Expect(VT_STORED_OBJECT, 69u16)
    @Expect(VT_BLOB_OBJECT, 70u16)
    @Expect(VT_CF, 71u16)
    @Expect(VT_CLSID, 72u16)
    @Expect(VT_VECTOR, 4096u16)
    @Expect(VT_ARRAY, 8192u16)
}

@Test
func fileTimePropVariantRoundTrips(): Unit {
    let pv = propVariantFromFileTimeParts(0x12345678u32, 0xABCDEF01u32)
    @Expect(propVariantVt(pv), VT_FILETIME)
    let result = propVariantAsFileTime(pv).getOrThrow()
    @Expect(result.dwLowDateTime, 0x12345678u32)
    @Expect(result.dwHighDateTime, 0xABCDEF01u32)
}

@Test
func clsidPropVariantRoundTrips(): Unit {
    let original = GUID(0x12345678u32, 0xABCDu16, 0xEF01u16,
        0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8)
    var holder = PropVariant(propVariantFromClsid(original))
    @Expect(holder.vt(), VT_CLSID)
    let read = propVariantAsClsid(holder.get()).getOrThrow()
    @Expect(read.data1, 0x12345678u32)
    @Expect(read.data2, 0xABCDu16)
    @Expect(read.data3, 0xEF01u16)
    @Expect(read.data4[0], 0x01u8)
    @Expect(read.data4[7], 0x08u8)
    holder.close()
    @Expect(holder.isClosed(), true)
}

@Test
func wideStringPropVariantRoundTrips(): Unit {
    var owned = PropVariant(propVariantFromString("hello-shell-property"))
    @Expect(owned.vt(), VT_LPWSTR)
    let text = propVariantAsString(owned.get()).getOrThrow()
    @Expect(text, "hello-shell-property")
    owned.close()
    @Expect(owned.isClosed(), true)
}

@Test
func ansiStringPropVariantRoundTrips(): Unit {
    let bytes = [0x70u8, 0x6Bu8, 0x65u8, 0x79u8] // "pkey"
    var owned = PropVariant(propVariantFromStringAnsi(bytes))
    @Expect(owned.vt(), VT_LPSTR)
    let text = propVariantAsString(owned.get()).getOrThrow()
    @Expect(text, "pkey")
    owned.close()
}

@Test
func blobPropVariantRoundTrips(): Unit {
    let payload = [0xDEu8, 0xADu8, 0xBEu8, 0xEFu8]
    var owned = PropVariant(propVariantFromBytes(payload))
    @Expect(owned.vt(), VT_BLOB)
    let read = propVariantAsBytes(owned.get()).getOrThrow()
    @Expect(read.size, 4)
    @Expect(read[0], 0xDEu8)
    @Expect(read[1], 0xADu8)
    @Expect(read[2], 0xBEu8)
    @Expect(read[3], 0xEFu8)
    owned.close()
}

@Test
func bstrPropVariantRoundTrips(): Unit {
    let bstrValue = propVariantFromBstrString("hello-bstr")
    @Expect(propVariantVt(bstrValue), VT_BSTR)
    let view = propVariantAsBstr(bstrValue).getOrThrow()
    @Expect(view.get(), "hello-bstr")
    var owned = PropVariant(bstrValue)
    @Expect(owned.vt(), VT_BSTR)
    owned.close()
    @Expect(owned.isClosed(), true)
}

@Test
func propVariantResourceRoundTripsScalar(): Unit {
    var owned = PropVariant(propVariantFromInt32(42i32))
    @Expect(owned.vt(), VT_I4)
    @Expect(propVariantAsInt32(owned.get()), Some(42i32))
    let cloned = owned.cloneSelf()
    @Expect(cloned.vt(), VT_I4)
    @Expect(propVariantAsInt32(cloned.get()), Some(42i32))
    owned.close()
    cloned.close()
    @Expect(owned.isClosed(), true)
    @Expect(cloned.isClosed(), true)
}

@Test
func propVariantCopyDeepCopiesLpwstr(): Unit {
    var source = PropVariant(propVariantFromString("payload"))
    let cloneCount = debugObservedPropVariantCopyCount()
    let dup = source.cloneSelf()
    @Expect(dup.vt(), VT_LPWSTR)
    @Expect(debugObservedPropVariantCopyCount() > cloneCount, true)
    @Expect(propVariantAsString(dup.get()).getOrThrow(), "payload")
    @Expect(propVariantAsString(source.get()).getOrThrow(), "payload")
    source.close()
    dup.close()
}

@Test
func propVariantClearReleasesLpwstrAllocation(): Unit {
    let before = debugObservedPropVariantClearCount()
    var owned = PropVariant(propVariantFromString("transient"))
    owned.close()
    let afterClose = debugObservedPropVariantClearCount()
    @Expect(afterClose > before, true)
    owned.close()
    @Expect(debugObservedPropVariantClearCount(), afterClose)
}

@When[os == "Windows"]
@Test
func propsysConsumesCangjiePropVariants(): Unit {
    let text = PropVariant(propVariantFromString("shell-property-roundtrip"))
    let number = PropVariant(propVariantFromInt32(314i32))
    try {
        @Expect(propVariantSmokeToString(text.get()), "shell-property-roundtrip")
        @Expect(propVariantSmokeToInt32(number.get()), 314i32)
    } finally {
        text.close()
        number.close()
    }
}

@Test
func propVariantCloseIsReleaseReentrantSafe(): Unit {
    ensurePropVariantClearAbiResolved()
    var vtbl = IUnknownVtbl()
    vtbl.Release = reentrantPropVariantRelease
    var object = ReentrantPropVariantUnknown()
    object.lpVtbl = CPointer<IUnknownVtbl>(inout vtbl)
    reentrantPropVariantReleaseCalls = 0u32

    let owned = PropVariant(propVariantFromUnknownRaw(CPointer<Unit>(inout object)))
    reentrantPropVariantTarget = Some(owned)
    try {
        owned.close()
        @Expect(owned.isClosed(), true)
        @Expect(reentrantPropVariantReleaseCalls, 1u32)
    } finally {
        reentrantPropVariantTarget = None
    }
}

@Test
func propVariantCopyAndClearDeepCopiesBstrSafeArray(): Unit {
    ensurePropVariantClearAbiResolved()
    let clearBefore = debugObservedPropVariantClearCount()
    let copyBefore = debugObservedPropVariantCopyCount()
    let raw = propVariantSmokeCreateBstrSafeArray(["first", "second"])
    let source = PropVariant(propVariantSmokeFromSafeArrayRaw(VT_BSTR, raw))
    let dup = source.cloneSelf()
    try {
        @Expect(source.vt(), VT_ARRAY | VT_BSTR)
        @Expect(dup.vt(), VT_ARRAY | VT_BSTR)
        @Expect(debugObservedPropVariantCopyCount() > copyBefore, true)

        let sourceArray = propVariantSmokeSafeArrayRaw(source.get())
        let dupArray = propVariantSmokeSafeArrayRaw(dup.get())
        @Expect(propVariantSmokeSafeArrayBstrText(sourceArray, 0), "first")
        @Expect(propVariantSmokeSafeArrayBstrText(dupArray, 0), "first")

        propVariantSmokeSafeArraySetBstr(sourceArray, 0, "replaced")
        @Expect(propVariantSmokeSafeArrayBstrText(sourceArray, 0), "replaced")
        @Expect(propVariantSmokeSafeArrayBstrText(dupArray, 0), "first")
    } finally {
        source.close()
        dup.close()
    }

    let clearAfter = debugObservedPropVariantClearCount()
    @Expect(clearAfter >= clearBefore + 2i32, true)
    source.close()
    dup.close()
    @Expect(debugObservedPropVariantClearCount(), clearAfter)
    @Expect(source.isClosed(), true)
    @Expect(dup.isClosed(), true)
}

@Test
func propVariantCloseRetainsPayloadWhenClearFails(): Unit {
    ensurePropVariantClearAbiResolved()
    let raw = propVariantSmokeCreateBstrSafeArray(["locked"])
    propVariantSmokeSafeArrayLock(raw)
    let owned = PropVariant(propVariantSmokeFromSafeArrayRaw(VT_BSTR, raw))

    @Expect(propVariantTestThrows({ => owned.close() }), true)
    @Expect(owned.isClosed(), false)
    @Expect(owned.vt(), VT_ARRAY | VT_BSTR)
    @Expect(propVariantSmokeSafeArrayRaw(owned.get()).toUIntNative(), raw.toUIntNative())

    propVariantSmokeSafeArrayUnlock(raw)
    owned.close()
    @Expect(owned.isClosed(), true)
}

@When[os == "Windows"]
@Test
func hstringSystemHandleFeedsPropVariantStringsWithExplicitClose(): Unit {
    let createBefore = debugObservedWindowsCreateStringCount()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    let clearBefore = debugObservedPropVariantClearCount()
    let source = HString("propvariant-hstring")
    let raw = source.toSystemHandleCopy()
    let projected = HString.fromSystemHandleTake(raw)
    let wide = PropVariant(propVariantFromString(projected.get()))
    let bstr = PropVariant(propVariantFromBstrString(projected.get()))
    let wideClone = wide.cloneSelf()
    let bstrClone = bstr.cloneSelf()

    try {
        @Expect(debugObservedWindowsCreateStringCount(), createBefore + 1i32)
        @Expect(debugObservedWindowsDeleteStringCount(), deleteBefore + 1i32)
        @Expect(wide.vt(), VT_LPWSTR)
        @Expect(bstr.vt(), VT_BSTR)
        @Expect(wideClone.vt(), VT_LPWSTR)
        @Expect(bstrClone.vt(), VT_BSTR)
        @Expect(propVariantAsString(wideClone.get()).getOrThrow(), "propvariant-hstring")
        @Expect(propVariantAsBstr(bstrClone.get()).getOrThrow().get(), "propvariant-hstring")
    } finally {
        wide.close()
        bstr.close()
        wideClone.close()
        bstrClone.close()
        projected.close()
        source.close()
    }

    let clearAfter = debugObservedPropVariantClearCount()
    @Expect(clearAfter >= clearBefore + 4i32, true)
    wide.close()
    bstr.close()
    wideClone.close()
    bstrClone.close()
    @Expect(debugObservedPropVariantClearCount(), clearAfter)
    @Expect(projected.isClosed(), true)
    @Expect(source.isClosed(), true)
}

@Test
func unknownDispatchStreamStoragePayloadsRoundTripRawPointers(): Unit {
    let unkPayload = propVariantFromUnknownRaw(CPointer<Unit>())
    @Expect(propVariantVt(unkPayload), VT_UNKNOWN)
    @Expect(propVariantAsUnknownRaw(unkPayload).getOrThrow().isNull(), true)

    let dispPayload = propVariantFromDispatchRaw(CPointer<Unit>())
    @Expect(propVariantVt(dispPayload), VT_DISPATCH)
    @Expect(propVariantAsDispatchRaw(dispPayload).getOrThrow().isNull(), true)

    let streamPayload = propVariantFromStreamRaw(CPointer<Unit>())
    @Expect(propVariantVt(streamPayload), VT_STREAM)
    @Expect(propVariantAsStreamRaw(streamPayload).getOrThrow().isNull(), true)

    let storagePayload = propVariantFromStorageRaw(CPointer<Unit>())
    @Expect(propVariantVt(storagePayload), VT_STORAGE)
    @Expect(propVariantAsStorageRaw(storagePayload).getOrThrow().isNull(), true)
}
