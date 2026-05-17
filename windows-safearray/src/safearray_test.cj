package windows_safearray

import std.unittest.*
import std.unittest.testmacro.*
import windows_strings.BSTR
import windows_variant.Variant
import windows_variant.VARIANT
import windows_variant.VT_BSTR
import windows_variant.VT_I4
import windows_variant.VT_R8
import windows_variant.VT_VARIANT
import windows_variant.variantFromI4
import windows_variant.variantFromString
import windows_variant.variantAsBstr
import windows_variant.variantAsI4
import windows_variant.variantVt

@Test
func fadfConstantsExposeRustValues(): Unit {
    @Expect(FADF_AUTO, 0x0001u16)
    @Expect(FADF_STATIC, 0x0002u16)
    @Expect(FADF_EMBEDDED, 0x0004u16)
    @Expect(FADF_FIXEDSIZE, 0x0010u16)
    @Expect(FADF_RECORD, 0x0020u16)
    @Expect(FADF_HAVEIID, 0x0040u16)
    @Expect(FADF_HAVEVARTYPE, 0x0080u16)
    @Expect(FADF_BSTR, 0x0100u16)
    @Expect(FADF_UNKNOWN, 0x0200u16)
    @Expect(FADF_DISPATCH, 0x0400u16)
    @Expect(FADF_VARIANT, 0x0800u16)
}

@Test
func boundHelperPopulatesFields(): Unit {
    let bound = makeBound(7u32, lowerBound: 3i32)
    @Expect(bound.cElements, 7u32)
    @Expect(bound.lLbound, 3i32)
}

@Test
func createVectorAndDestroyRoundTrips(): Unit {
    let createsBefore = debugObservedSafeArrayCreateCount()
    let destroysBefore = debugObservedSafeArrayDestroyCount()
    let arr = SafeArray.createVector(VT_I4, 0i32, 4u32)
    @Expect(arr.isNull(), false)
    @Expect(arr.dim(), 1u32)
    @Expect(arr.lbound(1u32), 0i32)
    @Expect(arr.ubound(1u32), 3i32)
    @Expect(arr.length(), 4)
    @Expect(arr.vartype(), VT_I4)
    @Expect(debugObservedSafeArrayCreateCount() > createsBefore, true)
    arr.close()
    @Expect(arr.isClosed(), true)
    @Expect(debugObservedSafeArrayDestroyCount() > destroysBefore, true)
}

@Test
func createMultiDimUsesBoundsArray(): Unit {
    let bounds: Array<SAFEARRAYBOUND> = [makeBound(3u32), makeBound(2u32)]
    let arr = SafeArray.create(VT_R8, bounds)
    @Expect(arr.dim(), 2u32)
    @Expect(arr.ubound(1u32), 2i32)
    @Expect(arr.ubound(2u32), 1i32)
    arr.close()
}

@Test
func lockUnlockBalancesCount(): Unit {
    let arr = SafeArray.createVector(VT_I4, 0i32, 2u32)
    @Expect(arr.lockCount(), 0u32)
    arr.lock()
    @Expect(arr.lockCount(), 1u32)
    arr.lock()
    @Expect(arr.lockCount(), 2u32)
    arr.unlock()
    @Expect(arr.lockCount(), 1u32)
    arr.unlock()
    @Expect(arr.lockCount(), 0u32)
    arr.close()
}

@Test
func withSafeArrayHelperUnlocksOnReturn(): Unit {
    let arr = SafeArray.createVector(VT_I4, 0i32, 2u32)
    @Expect(arr.lockCount(), 0u32)
    let observed = withSafeArray(arr) { a => a.lockCount() }
    @Expect(observed, 1u32)
    @Expect(arr.lockCount(), 0u32)
    arr.close()
}

@Test
func withSafeArrayHelperUnlocksOnThrow(): Unit {
    let arr = SafeArray.createVector(VT_I4, 0i32, 2u32)
    try {
        withSafeArray(arr) { _ =>
            throw Exception("boom")
        }
    } catch (_: Exception) {}
    @Expect(arr.lockCount(), 0u32)
    arr.close()
}

@Test
func withSafeArrayDataExposesDataPointer(): Unit {
    let arr = SafeArray.createVector(VT_I4, 0i32, 4u32)
    let accessesBefore = debugObservedSafeArrayAccessCount()
    let unaccessesBefore = debugObservedSafeArrayUnaccessCount()
    withSafeArrayData(arr) { ptr =>
        @Expect(ptr.isNotNull(), true)
    }
    @Expect(debugObservedSafeArrayAccessCount() > accessesBefore, true)
    @Expect(debugObservedSafeArrayUnaccessCount() > unaccessesBefore, true)
    arr.close()
}

@Test
func cloneSelfDeepCopiesDescriptor(): Unit {
    let arr = SafeArrayOfInt32.fromArray([10i32, 20i32, 30i32])
    let dup = SafeArrayOfInt32.fromRaw(arr.raw().cloneSelf().intoRaw())
    @Expect(dup.length(), 3)
    @Expect(dup.get(0), 10i32)
    @Expect(dup.get(1), 20i32)
    @Expect(dup.get(2), 30i32)
    // mutate clone, original should remain unchanged
    dup.set(0, -1i32)
    @Expect(arr.get(0), 10i32)
    arr.close()
    dup.close()
}

@Test
func intoRawTransfersOwnership(): Unit {
    let arr = SafeArray.createVector(VT_I4, 0i32, 1u32)
    let raw = arr.intoRaw()
    @Expect(arr.isClosed(), true)
    @Expect(raw.isNotNull(), true)
    // Re-take ownership so the descriptor is properly destroyed.
    let again = SafeArray(raw)
    again.close()
}

@Test
func safeArrayOfInt32RoundTrips(): Unit {
    let arr = SafeArrayOfInt32.fromArray([1i32, 2i32, 3i32, 4i32])
    @Expect(arr.length(), 4)
    @Expect(arr.get(0), 1i32)
    @Expect(arr.get(3), 4i32)
    arr.set(2, 99i32)
    @Expect(arr.get(2), 99i32)
    let dump = arr.toArray()
    @Expect(dump.size, 4)
    @Expect(dump[2], 99i32)
    arr.close()
}

@Test
func safeArrayOfFloat64RoundTrips(): Unit {
    let arr = SafeArrayOfFloat64.fromArray([1.5, 2.25, -3.125])
    @Expect(arr.length(), 3)
    @Expect(arr.get(0), 1.5)
    arr.set(1, 7.5)
    @Expect(arr.get(1), 7.5)
    arr.close()
}

@Test
func safeArrayOfStringsCopiesEachBstr(): Unit {
    let arr = SafeArrayOfStrings.fromArray(["alpha", "beta", "gamma"])
    @Expect(arr.length(), 3)
    let v0 = arr.get(0)
    try {
        @Expect(v0.get(), "alpha")
    } finally {
        v0.close()
    }
    let v2 = arr.get(2)
    try {
        @Expect(v2.get(), "gamma")
    } finally {
        v2.close()
    }
    arr.set(1, "BETA")
    let v1 = arr.get(1)
    try {
        @Expect(v1.get(), "BETA")
    } finally {
        v1.close()
    }
    let dump = arr.toArray()
    @Expect(dump[0], "alpha")
    @Expect(dump[1], "BETA")
    arr.close()
}

@Test
func safeArrayOfVariantsDeepCopiesElements(): Unit {
    let arr = SafeArrayOfVariants.withLength(2)
    @Expect(arr.length(), 2)

    let intVar = Variant(variantFromI4(42i32))
    arr.setRaw(0, intVar.get())
    // intVar is still owned by us — close it independently.
    intVar.close()

    let strVar = Variant(variantFromString("hello"))
    arr.setRaw(1, strVar.get())
    strVar.close()

    let got0 = Variant(arr.get(0))
    @Expect(got0.vt(), VT_I4)
    @Expect(variantAsI4(got0.get()), Some(42i32))
    got0.close()

    let got1 = Variant(arr.get(1))
    @Expect(got1.vt(), VT_BSTR)
    let bstrView = variantAsBstr(got1.get()).getOrThrow()
    @Expect(bstrView.get(), "hello")
    got1.close()

    arr.close()
}

@Test
func featuresFlagExposedForVariantArray(): Unit {
    let arr = SafeArrayOfVariants.withLength(0)
    let flags = arr.raw().features()
    @Expect((flags & FADF_VARIANT) != 0u16, true)
    @Expect((flags & FADF_HAVEVARTYPE) != 0u16, true)
    arr.close()
}

@Test
func vartypeReportsVtForBstrArray(): Unit {
    let arr = SafeArrayOfStrings.withLength(1)
    @Expect(arr.raw().vartype(), VT_BSTR)
    arr.close()
}
