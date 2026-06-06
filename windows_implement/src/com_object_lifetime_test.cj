package windows_implement

import std.sync.{AtomicBool, AtomicInt64}
import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*
import windows_result.{E_FAIL, WindowsException}
import windows_result as windows_result
import windows_strings.*

class ComObjectLifetimeDummy {}

let asInterfaceTakeFromAbiCount = AtomicInt64(0)

func resetAsInterfaceTakeFromAbiCount(): Unit {
    asInterfaceTakeFromAbiCount.store(0)
}

func trackingIUnknownTakeFromAbi(raw: CPointer<Unit>): IUnknown {
    asInterfaceTakeFromAbiCount.fetchAdd(1)
    IUnknown.fromAbiTake(raw)
}

func trackingIUnknownViewOf(raw: CPointer<Unit>): IUnknown {
    IUnknown.viewOf(raw)
}

func expectLifetimeCast(raw: CPointer<Unit>): ComObject<ComObjectLifetimeDummy> {
    match (ComObject<ComObjectLifetimeDummy>.castFromRaw(raw)) {
        case Some(value) => return value
        case None => throw Exception("expected ComObject cast to succeed")
    }
}

func fakeLifetimeGuidPointer(): CPointer<GUID> {
    unsafe { CPointer<GUID>(CPointer<UInt8>() + 0x1234) }
}

func fakeLifetimeRawPointer(): CPointer<Unit> {
    unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x5678) }
}

class ThrowingInspectableProbe <: IInspectableBase {
    public var sawClearedIids: Bool = false
    public var sawClearedTrustLevel: Bool = false
    public var writeIidsBeforeThrow: Bool = false
    public var returnFailedIids: Bool = false
    public var writeRuntimeClassNameBeforeThrow: Bool = false
    private let throwWindows: Bool
    private let partialName = HString("implement-partial-runtime-class-thunk")

    public init(throwWindows: Bool) {
        this.throwWindows = throwWindows
    }

    public func close(): Unit {
        partialName.close()
    }

    public func getIidsBase(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): Int32 {
        unsafe {
            sawClearedIids = count.read() == 0u32 && values.read().isNull()
            if (writeIidsBeforeThrow) {
                let raw = CPointer<GUID>(CoTaskMemAlloc(sizeOf<GUID>()))
                if (raw.isNotNull()) {
                    raw.write(IID_IINSPECTABLE)
                    count.write(1u32)
                    values.write(raw)
                }
            }
        }
        if (returnFailedIids) {
            return E_FAIL.value
        }
        throwConfiguredException()
    }

    public func getRuntimeClassNameBase(value: CPointer<CPointer<Unit>>): Int32 {
        if (writeRuntimeClassNameBeforeThrow) {
            unsafe { value.write(partialName.toSystemHandleCopy()) }
        }
        throwConfiguredException()
    }

    public func getTrustLevelBase(value: CPointer<Int32>): Int32 {
        unsafe {
            sawClearedTrustLevel = value.read() == 0i32
        }
        throwConfiguredException()
    }

    private func throwConfiguredException(): Int32 {
        if (throwWindows) {
            throw WindowsException(windows_result.E_POINTER)
        }
        throw Exception("inspectable probe failure")
    }
}

@Test
func testComObjectCastFromRawRetainsAndCloseReleasesOnce() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    @Expect(owner.runtime.isReferenceCountOne(), true)

    let casted = expectLifetimeCast(owner.asRaw())
    @Expect(owner.runtime.isReferenceCountOne(), false)

    casted.close()
    @Expect(owner.runtime.isReferenceCountOne(), true)
    casted.close()
    @Expect(owner.runtime.isReferenceCountOne(), true)

    let _ = owner.releaseBase()
}

@Test
func testInspectableGetIidsClearsSiblingOutSlotsOnPointerFailure() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IINSPECTABLE])
    var count = 123u32
    var iids = fakeLifetimeGuidPointer()

    let thunkNullCountHr = unsafe {
        iinspectableGetIidsThunk(
            owner.asRaw(),
            CPointer<UInt32>(),
            CPointer<CPointer<GUID>>(inout iids)
        )
    }
    @Expect(thunkNullCountHr, E_POINTER)
    @Expect(iids.isNull(), true)

    count = 123u32
    let thunkNullValuesHr = unsafe {
        iinspectableGetIidsThunk(
            owner.asRaw(),
            CPointer<UInt32>(inout count),
            CPointer<CPointer<GUID>>()
        )
    }
    @Expect(thunkNullValuesHr, E_POINTER)
    @Expect(count, 0u32)

    iids = fakeLifetimeGuidPointer()
    let baseNullCountHr = owner.runtime.getIidsBase(
        CPointer<UInt32>(),
        CPointer<CPointer<GUID>>(inout iids)
    )
    @Expect(baseNullCountHr, E_POINTER)
    @Expect(iids.isNull(), true)

    count = 123u32
    let baseNullValuesHr = owner.runtime.getIidsBase(
        CPointer<UInt32>(inout count),
        CPointer<CPointer<GUID>>()
    )
    @Expect(baseNullValuesHr, E_POINTER)
    @Expect(count, 0u32)

    owner.close()
}

@Test
func testIInspectableThunksTranslateWindowsExceptionsAndClearOutSlots() {
    let probe = ThrowingInspectableProbe(true)
    let raw = fakeLifetimeRawPointer()
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        var count = 123u32
        var iids = fakeLifetimeGuidPointer()
        let iidsHr = unsafe {
            iinspectableGetIidsThunk(
                raw,
                CPointer<UInt32>(inout count),
                CPointer<CPointer<GUID>>(inout iids)
            )
        }
        @Expect(iidsHr, windows_result.E_POINTER.value)
        @Expect(count, 0u32)
        @Expect(iids.isNull(), true)
        @Expect(probe.sawClearedIids, true)

        var trustLevel = 77i32
        let trustHr = unsafe {
            iinspectableGetTrustLevelThunk(raw, CPointer<Int32>(inout trustLevel))
        }
        @Expect(trustHr, windows_result.E_POINTER.value)
        @Expect(trustLevel, 0i32)
        @Expect(probe.sawClearedTrustLevel, true)
    } finally {
        comRegistryRemove(raw.toUIntNative())
        probe.close()
    }
}

@Test
func testIInspectableThunksTranslatePlainExceptionsAndClearOutSlots() {
    let probe = ThrowingInspectableProbe(false)
    let raw = fakeLifetimeRawPointer()
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        var count = 123u32
        var iids = fakeLifetimeGuidPointer()
        let iidsHr = unsafe {
            iinspectableGetIidsThunk(
                raw,
                CPointer<UInt32>(inout count),
                CPointer<CPointer<GUID>>(inout iids)
            )
        }
        @Expect(iidsHr, E_FAIL.value)
        @Expect(count, 0u32)
        @Expect(iids.isNull(), true)
        @Expect(probe.sawClearedIids, true)

        var trustLevel = 77i32
        let trustHr = unsafe {
            iinspectableGetTrustLevelThunk(raw, CPointer<Int32>(inout trustLevel))
        }
        @Expect(trustHr, E_FAIL.value)
        @Expect(trustLevel, 0i32)
        @Expect(probe.sawClearedTrustLevel, true)

        var nameRaw = fakeLifetimeRawPointer()
        let nameHr = unsafe {
            iinspectableGetRuntimeClassNameThunk(raw, CPointer<CPointer<Unit>>(inout nameRaw))
        }
        @Expect(nameHr, E_FAIL.value)
        @Expect(nameRaw.isNull(), true)
    } finally {
        comRegistryRemove(raw.toUIntNative())
        probe.close()
    }
}

@When[os == "Windows"]
@Test
func testIInspectableGetIidsThunkReleasesPartialIidArrayOnFailedHRESULT() {
    let probe = ThrowingInspectableProbe(false)
    probe.writeIidsBeforeThrow = true
    probe.returnFailedIids = true
    let raw = fakeLifetimeRawPointer()
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        let freeBefore = debugObservedCoTaskMemFreeCount()
        var count = 123u32
        var iids = CPointer<GUID>()
        let hr = unsafe {
            iinspectableGetIidsThunk(
                raw,
                CPointer<UInt32>(inout count),
                CPointer<CPointer<GUID>>(inout iids)
            )
        }
        @Expect(hr, E_FAIL.value)
        @Expect(count, 0u32)
        @Expect(iids.isNull(), true)
        @Expect(debugObservedCoTaskMemFreeCount() - freeBefore, 1)
    } finally {
        comRegistryRemove(raw.toUIntNative())
        probe.close()
    }
}

@When[os == "Windows"]
@Test
func testIInspectableGetIidsThunkReleasesPartialIidArrayOnThrownException() {
    let probe = ThrowingInspectableProbe(true)
    probe.writeIidsBeforeThrow = true
    let raw = fakeLifetimeRawPointer()
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        let freeBefore = debugObservedCoTaskMemFreeCount()
        var count = 123u32
        var iids = CPointer<GUID>()
        let hr = unsafe {
            iinspectableGetIidsThunk(
                raw,
                CPointer<UInt32>(inout count),
                CPointer<CPointer<GUID>>(inout iids)
            )
        }
        @Expect(hr, windows_result.E_POINTER.value)
        @Expect(count, 0u32)
        @Expect(iids.isNull(), true)
        @Expect(debugObservedCoTaskMemFreeCount() - freeBefore, 1)
    } finally {
        comRegistryRemove(raw.toUIntNative())
        probe.close()
    }
}

@When[os == "Windows"]
@Test
func testIInspectableRuntimeClassNameThunkReleasesPartialHandleOnThrownWindowsException() {
    let probe = ThrowingInspectableProbe(true)
    probe.writeRuntimeClassNameBeforeThrow = true
    let raw = fakeLifetimeRawPointer()
    comRegistryInsert(raw.toUIntNative(), probe)

    try {
        let deleteBefore = debugObservedWindowsDeleteStringCount()
        var nameRaw = CPointer<Unit>()
        let hr = unsafe {
            iinspectableGetRuntimeClassNameThunk(raw, CPointer<CPointer<Unit>>(inout nameRaw))
        }
        @Expect(hr, windows_result.E_POINTER.value)
        @Expect(nameRaw.isNull(), true)
        @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
    } finally {
        comRegistryRemove(raw.toUIntNative())
        probe.close()
    }
}

@Test
func testComObjectCloseRemovesRegistryAndIsIdempotent() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    let raw = owner.asRaw()
    let key = unsafe { rootRegistryKeyFromRaw(raw) }
    @Expect(comRegistryLookup(key).isSome(), true)

    owner.close()
    @Expect(owner.asRaw().isNull(), true)
    @Expect(comRegistryLookup(key).isNone(), true)

    owner.close()
    @Expect(owner.asRaw().isNull(), true)
}

@Test
func testComObjectFinalizerDropCleanupRemovesUnescapedOwnerRegistry() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    let raw = owner.asRaw()
    let key = unsafe { rootRegistryKeyFromRaw(raw) }
    @Expect(owner.runtime.isReferenceCountOne(), true)
    @Expect(comRegistryLookup(key).isSome(), true)

    @Expect(owner.runtime.tryFinalizeOwnerDrop(), true)
    @Expect(owner.runtime.isDestroyed(), true)
    @Expect(owner.asRaw().isNull(), true)
    @Expect(comRegistryLookup(key).isNone(), true)
    @Expect(implementActionThrows({ => owner.close() }), false)
}

@Test
func testComObjectFinalizerDropCleanupSkipsWhenRegistryLockIsBusy() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    let raw = owner.asRaw()
    let key = unsafe { rootRegistryKeyFromRaw(raw) }
    let locked = AtomicBool(false)
    let releaseLock = AtomicBool(false)
    let lockHolder = spawn {
        comRegistryMutex.lock()
        locked.store(true)
        while (!releaseLock.load()) {}
        comRegistryMutex.unlock()
    }

    while (!locked.load()) {}
    try {
        @Expect(owner.runtime.tryFinalizeOwnerDrop(), false)
        @Expect(owner.runtime.isReferenceCountOne(), true)
        @Expect(owner.runtime.isDestroyed(), false)
    } finally {
        releaseLock.store(true)
        lockHolder.get()
    }

    @Expect(comRegistryLookup(key).isSome(), true)
    owner.close()
    @Expect(owner.runtime.isDestroyed(), true)
    @Expect(comRegistryLookup(key).isNone(), true)
}

@Test
func testComObjectObservesExternalVtableReleaseToZero() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    let raw = owner.asRaw()
    var result = CPointer<Unit>()

    let releaseCount = unsafe { iunknownReleaseThunk(raw) }
    @Expect(releaseCount, 0u32)
    @Expect(owner.isClosed(), true)
    @Expect(owner.asRaw().isNull(), true)
    @Expect(owner.queryInterfaceBase(IID_IUNKNOWN, CPointer<CPointer<Unit>>(inout result)), E_NOINTERFACE)
    @Expect(result.isNull(), true)
    @Expect(implementActionThrows({ => owner.close() }), false)
    @Expect(implementActionThrows({ => let _ = owner.releaseBase() }), false)
}

@Test
func testComObjectAsInterfaceUsesBorrowedViewWithoutOwningWrapper() {
    resetAsInterfaceTakeFromAbiCount()
    let descriptor = InterfaceDescriptor<IUnknown>(
        "IUnknown",
        IID_IUNKNOWN,
        trackingIUnknownTakeFromAbi,
        trackingIUnknownViewOf
    )
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])

    let view = owner.asInterface(descriptor)

    @Expect(asInterfaceTakeFromAbiCount.load(), 0)
    @Expect(view.release(), 0u32)
    @Expect(owner.runtime.isReferenceCountOne(), true)
    owner.close()
}

@Test
func testComObjectIntoInterfaceKeepsOwnedQueryInterfaceReference() {
    resetAsInterfaceTakeFromAbiCount()
    let descriptor = InterfaceDescriptor<IUnknown>(
        "IUnknown",
        IID_IUNKNOWN,
        trackingIUnknownTakeFromAbi,
        trackingIUnknownViewOf
    )
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])

    let owned = owner.intoInterface(descriptor)

    @Expect(asInterfaceTakeFromAbiCount.load(), 1)
    @Expect(owner.isClosed(), true)
    @Expect(owner.runtime.isReferenceCountOne(), true)
    @Expect(owned.release(), 0u32)
    @Expect(owner.runtime.isDestroyed(), true)
    owner.close()
}
