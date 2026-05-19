package windows_implement

import std.sync.{AtomicBool, AtomicInt64}
import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*
import windows_result.{E_FAIL, Result}

class WeakReferenceResolveRaceDummy {}

let partialCleanupTestIid = GUID.parse("4AE50C2B-4C1D-46E5-874B-37F9A6343B90")
let partialCleanupReleaseCount = AtomicInt64(0)
let partialCleanupReentrantRelease = AtomicBool(false)
var partialCleanupRaw = CPointer<Unit>()
var partialCleanupReentrantSlot = CPointer<CPointer<Unit>>()

func takeWeakResolveProbeFromAbi(raw: CPointer<Unit>): IUnknown {
    IUnknown.fromAbiTake(raw)
}

func viewWeakResolveProbe(raw: CPointer<Unit>): IUnknown {
    IUnknown.viewOf(raw)
}

func weakResolveProbeDescriptor(): InterfaceDescriptor<IUnknown> {
    InterfaceDescriptor<IUnknown>(
        "WeakResolveProbe",
        GUID.parse("6E0C33EF-7231-4E68-A7D9-2103B8195101"),
        takeWeakResolveProbeFromAbi,
        viewWeakResolveProbe
    )
}

@C
func partialCleanupFailedQueryThunk(
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    unsafe { resultSlot.write(partialCleanupRaw) }
    E_FAIL.value
}

@C
func partialCleanupNoWriteFailedQueryThunk(
    _: CPointer<Unit>,
    _: CPointer<GUID>,
    _: CPointer<CPointer<Unit>>
): Int32 {
    E_FAIL.value
}

@C
func partialCleanupAddRefThunk(_: CPointer<Unit>): UInt32 {
    1u32
}

@C
func partialCleanupReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = partialCleanupReleaseCount.fetchAdd(1)
    if (partialCleanupReentrantRelease.load() && previous == 0) {
        releaseFailedComOutSlot(partialCleanupReentrantSlot)
    }
    UInt32(previous + 1)
}

func resetPartialCleanupState(): Unit {
    partialCleanupReleaseCount.store(0)
    partialCleanupReentrantRelease.store(false)
    partialCleanupRaw = CPointer<Unit>()
    partialCleanupReentrantSlot = CPointer<CPointer<Unit>>()
}

func partialCleanupFailedQueryVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.QueryInterface = partialCleanupFailedQueryThunk
    vtbl.AddRef = partialCleanupAddRefThunk
    vtbl.Release = partialCleanupReleaseThunk
    vtbl
}

func partialCleanupNoWriteFailedQueryVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.QueryInterface = partialCleanupNoWriteFailedQueryThunk
    vtbl.AddRef = partialCleanupAddRefThunk
    vtbl.Release = partialCleanupReleaseThunk
    vtbl
}

func partialCleanupReleaseVtbl(): IUnknownVtbl {
    var vtbl = IUnknownVtbl()
    vtbl.Release = partialCleanupReleaseThunk
    vtbl
}

func takeWeakReferenceForResolveTest(owner: ComObject<WeakReferenceResolveRaceDummy>): IWeakReference {
    var sourceRaw = CPointer<Unit>()
    let sourceHr = owner.queryInterfaceBase(IID_IWEAKREFERENCESOURCE, CPointer<CPointer<Unit>>(inout sourceRaw))
    if (sourceHr != S_OK || sourceRaw.isNull()) {
        throw Exception("expected IWeakReferenceSource")
    }

    let source = IWeakReferenceSource.fromAbiTake(sourceRaw)
    try {
        match (unsafe { source.getWeakReference() }) {
            case Result<IWeakReference>.Ok(reference) =>
                reference
            case Result<IWeakReference>.Err(_) =>
                throw Exception("expected IWeakReference")
        }
    } finally {
        source.close()
    }
}

@Test
func testWeakReferenceResolveRetainsOwnerDuringQueryInterface() {
    let owner = createComObject(WeakReferenceResolveRaceDummy(), [IID_IINSPECTABLE])
    let descriptor = weakResolveProbeDescriptor()
    let observedTemporaryOwnerRef = AtomicBool(false)

    owner.runtime.setQueryInterfaceFallback({ iid, resultSlot =>
        if (iid == descriptor.iid) {
            observedTemporaryOwnerRef.store(!owner.runtime.isReferenceCountOne())
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
        }
        E_NOINTERFACE
    })

    let weakReference = takeWeakReferenceForResolveTest(owner)
    match (unsafe { weakReference.resolve(descriptor) }) {
        case Result<IUnknown>.Ok(value) =>
            value.close()
        case Result<IUnknown>.Err(_) =>
            ()
    }

    let retainedDuringQueryInterface = observedTemporaryOwnerRef.load()
    let releasedAfterResolve = owner.runtime.isReferenceCountOne()

    weakReference.close()
    owner.close()

    @Expect(retainedDuringQueryInterface, true)
    @Expect(releasedAfterResolve, true)
}

@Test
func testQueryComposableInnerClearsStaleOutputBeforeNoWriteFailure() {
    resetPartialCleanupState()
    let innerVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupNoWriteFailedQueryVtbl()) }
    let innerHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(innerVtblHandle) }
    let staleVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let staleHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    partialCleanupRaw = CPointer<Unit>(staleHandle)
    var resultRaw = partialCleanupRaw

    try {
        let hr = queryComposableInner(
            CPointer<Unit>(innerHandle),
            partialCleanupTestIid,
            CPointer<CPointer<Unit>>(inout resultRaw)
        )

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 0)
    } finally {
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            freeNativeValue<IUnknownVtbl>(staleVtblHandle)
            freeNativeValue<CPointer<IUnknownVtbl>>(innerHandle)
            freeNativeValue<IUnknownVtbl>(innerVtblHandle)
        }
        resetPartialCleanupState()
    }
}

@Test
func testQueryComposableInnerReleasesPartialOutputOnFailedQueryInterface() {
    resetPartialCleanupState()
    let innerVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupFailedQueryVtbl()) }
    let innerHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(innerVtblHandle) }
    let partialVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let partialHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(partialVtblHandle) }
    partialCleanupRaw = CPointer<Unit>(partialHandle)
    var resultRaw = CPointer<Unit>()

    try {
        let hr = queryComposableInner(
            CPointer<Unit>(innerHandle),
            partialCleanupTestIid,
            CPointer<CPointer<Unit>>(inout resultRaw)
        )

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 1)
    } finally {
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            freeNativeValue<IUnknownVtbl>(partialVtblHandle)
            freeNativeValue<CPointer<IUnknownVtbl>>(innerHandle)
            freeNativeValue<IUnknownVtbl>(innerVtblHandle)
        }
        resetPartialCleanupState()
    }
}

@Test
func testComObjectQueryFallbackClearsStaleOutputBeforeNoWriteFailure() {
    resetPartialCleanupState()
    let staleVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let staleHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    partialCleanupRaw = CPointer<Unit>(staleHandle)
    let owner = createComObject(WeakReferenceResolveRaceDummy(), [IID_IINSPECTABLE])
    var resultRaw = partialCleanupRaw

    owner.runtime.setQueryInterfaceFallback({ iid, resultSlot =>
        let _ = resultSlot
        if (iid == partialCleanupTestIid) {
            return E_FAIL.value
        }
        E_NOINTERFACE
    })

    try {
        let hr = owner.queryInterfaceBase(partialCleanupTestIid, CPointer<CPointer<Unit>>(inout resultRaw))

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 0)
    } finally {
        owner.close()
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            freeNativeValue<IUnknownVtbl>(staleVtblHandle)
        }
        resetPartialCleanupState()
    }
}

@Test
func testComObjectQueryFallbackReleasesPartialOutputOnFailedHRESULT() {
    resetPartialCleanupState()
    let partialVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let partialHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(partialVtblHandle) }
    partialCleanupRaw = CPointer<Unit>(partialHandle)
    let owner = createComObject(WeakReferenceResolveRaceDummy(), [IID_IINSPECTABLE])
    var resultRaw = CPointer<Unit>()

    owner.runtime.setQueryInterfaceFallback({ iid, resultSlot =>
        if (iid == partialCleanupTestIid) {
            unsafe { resultSlot.write(partialCleanupRaw) }
            return E_FAIL.value
        }
        E_NOINTERFACE
    })

    try {
        let hr = owner.queryInterfaceBase(partialCleanupTestIid, CPointer<CPointer<Unit>>(inout resultRaw))

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 1)
    } finally {
        owner.close()
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            freeNativeValue<IUnknownVtbl>(partialVtblHandle)
        }
        resetPartialCleanupState()
    }
}

@Test
func testReleaseFailedComOutSlotIsReleaseReentrantSafe() {
    resetPartialCleanupState()
    let partialVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let partialHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(partialVtblHandle) }
    var resultRaw = CPointer<Unit>(partialHandle)
    partialCleanupReentrantSlot = CPointer<CPointer<Unit>>(inout resultRaw)
    partialCleanupReentrantRelease.store(true)

    try {
        releaseFailedComOutSlot(partialCleanupReentrantSlot)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 1)
    } finally {
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            freeNativeValue<IUnknownVtbl>(partialVtblHandle)
        }
        resetPartialCleanupState()
    }
}

@Test
func testWeakReferenceSourceQueryInterfaceClearsStaleOutputBeforeNoWriteOwnerFailure() {
    resetPartialCleanupState()
    let staleVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let staleHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    partialCleanupRaw = CPointer<Unit>(staleHandle)
    let owner = createComObject(WeakReferenceResolveRaceDummy(), [IID_IINSPECTABLE])
    var sourceRaw = CPointer<Unit>()
    var resultRaw = partialCleanupRaw
    var iid = partialCleanupTestIid

    owner.runtime.setQueryInterfaceFallback({ requested, resultSlot =>
        let _ = resultSlot
        if (requested == partialCleanupTestIid) {
            return E_FAIL.value
        }
        E_NOINTERFACE
    })

    let sourceHr = owner.queryInterfaceBase(IID_IWEAKREFERENCESOURCE, CPointer<CPointer<Unit>>(inout sourceRaw))
    if (sourceHr != S_OK || sourceRaw.isNull()) {
        owner.close()
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            freeNativeValue<IUnknownVtbl>(staleVtblHandle)
        }
        resetPartialCleanupState()
        throw Exception("expected IWeakReferenceSource")
    }

    let source = IWeakReferenceSource.fromAbiTake(sourceRaw)
    try {
        let sourceRawValue = source.asRaw()
        let sourceVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceSourceVtbl>>(sourceRawValue).read() }
        let sourceVtbl = unsafe { sourceVtblPtr.read() }
        let hr = unsafe {
            sourceVtbl.base_.QueryInterface(
                sourceRawValue,
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout resultRaw)
            )
        }

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 0)
    } finally {
        source.close()
        owner.close()
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            freeNativeValue<IUnknownVtbl>(staleVtblHandle)
        }
        resetPartialCleanupState()
    }
}

@Test
func testWeakReferenceResolveThunkClearsStaleOutputBeforeNoWriteOwnerFailure() {
    resetPartialCleanupState()
    let staleVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let staleHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(staleVtblHandle) }
    partialCleanupRaw = CPointer<Unit>(staleHandle)
    let owner = createComObject(WeakReferenceResolveRaceDummy(), [IID_IINSPECTABLE])
    var resultRaw = partialCleanupRaw
    var iid = partialCleanupTestIid

    owner.runtime.setQueryInterfaceFallback({ requested, resultSlot =>
        let _ = resultSlot
        if (requested == partialCleanupTestIid) {
            return E_FAIL.value
        }
        E_NOINTERFACE
    })

    let weakReference = takeWeakReferenceForResolveTest(owner)
    try {
        let weakRaw = weakReference.asRaw()
        let weakVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceVtbl>>(weakRaw).read() }
        let weakVtbl = unsafe { weakVtblPtr.read() }
        let hr = unsafe {
            weakVtbl.Resolve(weakRaw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout resultRaw))
        }

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 0)
    } finally {
        weakReference.close()
        owner.close()
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(staleHandle)
            freeNativeValue<IUnknownVtbl>(staleVtblHandle)
        }
        resetPartialCleanupState()
    }
}

@Test
func testWeakReferenceResolveThunkReleasesPartialOwnerOutputOnFailedHRESULT() {
    resetPartialCleanupState()
    let partialVtblHandle = unsafe { allocateNativeValue<IUnknownVtbl>(partialCleanupReleaseVtbl()) }
    let partialHandle = unsafe { allocateNativeValue<CPointer<IUnknownVtbl>>(partialVtblHandle) }
    partialCleanupRaw = CPointer<Unit>(partialHandle)
    let owner = createComObject(WeakReferenceResolveRaceDummy(), [IID_IINSPECTABLE])
    var resultRaw = CPointer<Unit>()
    var iid = partialCleanupTestIid

    owner.runtime.setQueryInterfaceFallback({ requested, resultSlot =>
        if (requested == partialCleanupTestIid) {
            unsafe { resultSlot.write(partialCleanupRaw) }
            return E_FAIL.value
        }
        E_NOINTERFACE
    })

    let weakReference = takeWeakReferenceForResolveTest(owner)
    try {
        let weakRaw = weakReference.asRaw()
        let weakVtblPtr = unsafe { CPointer<CPointer<IWeakReferenceVtbl>>(weakRaw).read() }
        let weakVtbl = unsafe { weakVtblPtr.read() }
        let hr = unsafe {
            weakVtbl.Resolve(weakRaw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout resultRaw))
        }

        @Expect(hr, E_FAIL.value)
        @Expect(resultRaw.isNull(), true)
        @Expect(partialCleanupReleaseCount.load(), 1)
    } finally {
        weakReference.close()
        owner.close()
        unsafe {
            freeNativeValue<CPointer<IUnknownVtbl>>(partialHandle)
            freeNativeValue<IUnknownVtbl>(partialVtblHandle)
        }
        resetPartialCleanupState()
    }
}
