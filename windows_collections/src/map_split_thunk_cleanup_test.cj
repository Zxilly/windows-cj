package windows_collections
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, Result, WinError}
import windows_core as windows_core
import windows_interface as windows_interface

let mapSplitThunkReleaseCalls = AtomicInt64(0)

@C
func mapSplitThunkReleaseThunk(raw: CPointer<Unit>): UInt32 {
    let oldCount = mapSplitThunkReleaseCalls.fetchAdd(1)
    windows_core.coTaskMemFree(raw)
    UInt32(oldCount + 1)
}

func mapSplitThunkObject(vtbl: CPointer<windows_interface.IUnknownVtbl>): CPointer<Unit> {
    let raw = windows_core.coTaskMemAlloc(sizeOf<CPointer<windows_interface.IUnknownVtbl>>())
    if (raw.isNull()) {
        return CPointer<Unit>()
    }
    unsafe { CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw).write(vtbl) }
    raw
}

class FailingSplitMapViewImpl <: IMapView_Impl<Int32, Int32> {
    private let releaseVtbl: CPointer<windows_interface.IUnknownVtbl>

    public init(releaseVtbl: CPointer<windows_interface.IUnknownVtbl>) {
        this.releaseVtbl = releaseVtbl
    }

    public func Lookup(key: Int32): Result<Int32> {
        let _ = key
        collectionTestNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        unsafe {
            first.write(mapSplitThunkObject(releaseVtbl))
            second.write(mapSplitThunkObject(releaseVtbl))
        }
        Result<Unit>.Err(WinError.fromHRESULT(E_FAIL))
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        collectionTestNotImplemented<IIterator<IKeyValuePair<Int32, Int32>>>()
    }
}

class NoWriteFailingSplitMapViewImpl <: IMapView_Impl<Int32, Int32> {
    public func Lookup(key: Int32): Result<Int32> {
        let _ = key
        collectionTestNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        let _ = first
        let _ = second
        Result<Unit>.Err(WinError.fromHRESULT(E_FAIL))
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        collectionTestNotImplemented<IIterator<IKeyValuePair<Int32, Int32>>>()
    }
}

@C
func failingMapViewSplitClientThunk(
    instanceRaw: CPointer<Unit>,
    first: CPointer<CPointer<Unit>>,
    second: CPointer<CPointer<Unit>>
): Int32 {
    if (first.isNull() || second.isNull()) {
        return windows_core.E_POINTER.value
    }
    let objectSlots = CPointer<CPointer<Unit>>(instanceRaw)
    let releaseVtbl = CPointer<windows_interface.IUnknownVtbl>(unsafe { (objectSlots + 1).read() })
    let firstRaw = mapSplitThunkObject(releaseVtbl)
    let secondRaw = mapSplitThunkObject(releaseVtbl)
    if (firstRaw.isNull() || secondRaw.isNull()) {
        if (firstRaw.isNotNull()) {
            windows_core.coTaskMemFree(firstRaw)
        }
        if (secondRaw.isNotNull()) {
            windows_core.coTaskMemFree(secondRaw)
        }
        return windows_core.E_POINTER.value
    }
    unsafe {
        first.write(firstRaw)
        second.write(secondRaw)
    }
    E_FAIL.value
}

@C
func noWriteFailingMapViewSplitClientThunk(
    _: CPointer<Unit>,
    first: CPointer<CPointer<Unit>>,
    second: CPointer<CPointer<Unit>>
): Int32 {
    if (first.isNull() || second.isNull()) {
        return windows_core.E_POINTER.value
    }
    E_FAIL.value
}

func withMapViewSplitClientRaw(
    vtbl: IMapViewVtbl,
    releaseVtbl: CPointer<windows_interface.IUnknownVtbl>,
    action: (CPointer<Unit>) -> Unit
): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IMapViewVtbl>(vtbl) }
    let objectRaw = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    if (objectRaw.isNull()) {
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        throw Exception("failed to allocate map view client test object")
    }
    unsafe {
        let slots = CPointer<CPointer<Unit>>(objectRaw)
        slots.write(CPointer<Unit>(vtblHandle))
        (slots + 1).write(CPointer<Unit>(releaseVtbl))
    }

    try {
        action(objectRaw)
    } finally {
        windows_core.coTaskMemFree(objectRaw)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}

func withMapSplitReleaseVtbl(action: (CPointer<windows_interface.IUnknownVtbl>) -> Unit): Unit {
    mapSplitThunkReleaseCalls.store(0)
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = mapSplitThunkReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    try {
        action(vtblHandle)
    } finally {
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}

func withOwnedMapSplitOutputs(
    releaseVtbl: CPointer<windows_interface.IUnknownVtbl>,
    action: (CPointer<Unit>, CPointer<Unit>) -> Unit
): Unit {
    let firstOwned = mapSplitThunkObject(releaseVtbl)
    let secondOwned = mapSplitThunkObject(releaseVtbl)
    try {
        action(firstOwned, secondOwned)
    } finally {
        if (firstOwned.isNotNull()) {
            windows_core.coTaskMemFree(firstOwned)
        }
        if (secondOwned.isNotNull()) {
            windows_core.coTaskMemFree(secondOwned)
        }
    }
}

func expectMapSplitOutputsCleared(first: CPointer<Unit>, second: CPointer<Unit>, releaseCalls: Int64): Unit {
    @Expect(first.isNull(), true)
    @Expect(second.isNull(), true)
    @Expect(mapSplitThunkReleaseCalls.load(), releaseCalls)
}

@Test
func testIMapViewSplitClientClearsStaleOutputsBeforeNoWriteFailure() {
    withMapSplitReleaseVtbl({ releaseVtblHandle: CPointer<windows_interface.IUnknownVtbl> =>
        withOwnedMapSplitOutputs(releaseVtblHandle, { firstOwned: CPointer<Unit>, secondOwned: CPointer<Unit> =>
            var mapVtbl = IMapViewVtbl()
            mapVtbl.Split = noWriteFailingMapViewSplitClientThunk

            withMapViewSplitClientRaw(mapVtbl, releaseVtblHandle, { raw: CPointer<Unit> =>
                let view = IMapView<Int32, Int32>.viewOf(raw)
                var first = firstOwned
                var second = secondOwned
                var failed = false
                try {
                    unsafe {
                        view.Split(CPointer<CPointer<Unit>>(inout first), CPointer<CPointer<Unit>>(inout second))
                    }
                    throw Exception("expected failing IMapView.Split")
                } catch (_: windows_core.WindowsException) {
                    failed = true
                }

                @Expect(failed, true)
                expectMapSplitOutputsCleared(first, second, 0)
            })
        })
    })
}

@Test
func testIMapViewSplitThunkClearsStaleOutputsBeforeNoWriteFailure() {
    withMapSplitReleaseVtbl({ vtblHandle: CPointer<windows_interface.IUnknownVtbl> =>
        withOwnedMapSplitOutputs(vtblHandle, { firstOwned: CPointer<Unit>, secondOwned: CPointer<Unit> =>
            let impl = NoWriteFailingSplitMapViewImpl()
            var first = firstOwned
            var second = secondOwned

            let hr = impl.__winrtThunk_Split(
                CPointer<CPointer<Unit>>(inout first),
                CPointer<CPointer<Unit>>(inout second)
            )

            @Expect(hr, E_FAIL.value)
            expectMapSplitOutputsCleared(first, second, 0)
        })
    })
}

@Test
func testIMapViewSplitThunkReleasesFailedPartialOutputs() {
    withMapSplitReleaseVtbl({ vtblHandle: CPointer<windows_interface.IUnknownVtbl> =>
        let impl = FailingSplitMapViewImpl(vtblHandle)
        var first = CPointer<Unit>()
        var second = CPointer<Unit>()

        let hr = impl.__winrtThunk_Split(CPointer<CPointer<Unit>>(inout first), CPointer<CPointer<Unit>>(inout second))

        @Expect(hr, E_FAIL.value)
        expectMapSplitOutputsCleared(first, second, 2)
    })
}

@Test
func testIMapViewSplitClientReleasesFailedPartialOutputs() {
    withMapSplitReleaseVtbl({ releaseVtblHandle: CPointer<windows_interface.IUnknownVtbl> =>
        var mapVtbl = IMapViewVtbl()
        mapVtbl.Split = failingMapViewSplitClientThunk

        withMapViewSplitClientRaw(mapVtbl, releaseVtblHandle, { raw: CPointer<Unit> =>
            let view = IMapView<Int32, Int32>.viewOf(raw)
            var first = CPointer<Unit>()
            var second = CPointer<Unit>()
            var failed = false
            try {
                unsafe {
                    view.Split(CPointer<CPointer<Unit>>(inout first), CPointer<CPointer<Unit>>(inout second))
                }
                throw Exception("expected failing IMapView.Split")
            } catch (_: windows_core.WindowsException) {
                failed = true
            }

            @Expect(failed, true)
            expectMapSplitOutputsCleared(first, second, 2)
        })
    })
}
