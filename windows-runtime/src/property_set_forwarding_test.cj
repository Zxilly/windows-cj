package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOINTERFACE, E_NOTIMPL, E_POINTER, InParam, Result, S_OK, WinError, WindowsException}
import windows_core as windows_core
import windows_interface.{GUID, IInspectable, IUnknown}

let propertySetForwardingQueryCalls = AtomicInt64(0)
let propertySetForwardingAddRefCalls = AtomicInt64(0)
let propertySetForwardingReleaseCalls = AtomicInt64(0)
let propertySetForwardingSizeCalls = AtomicInt64(0)
let propertySetForwardingRemoveMapChangedCalls = AtomicInt64(0)
let propertySetForwardingFirstCalls = AtomicInt64(0)
let propertySetForwardingLastTokenValue = AtomicInt64(0)

@C
func propertySetForwardingQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (iid.isNull() || result.isNull()) {
        return E_POINTER.value
    }
    let target = unsafe { iid.read() }
    if (
        target == IPropertySet.iid() ||
        target == IMap<windows_core.HString, IInspectable>.iid() ||
        target == IMap<windows_core.HString, windows_core.HString>.iid() ||
        target == IObservableMap<windows_core.HString, IInspectable>.iid() ||
        target == IObservableMap<windows_core.HString, windows_core.HString>.iid() ||
        target == IIterable<Int32>.iid() ||
        target == IIterable<IKeyValuePair<windows_core.HString, IInspectable>>.iid() ||
        target == IIterable<IKeyValuePair<windows_core.HString, windows_core.HString>>.iid() ||
        target == IInspectable.iid() ||
        target == IUnknown.iid()
    ) {
        propertySetForwardingQueryCalls.fetchAdd(1)
        unsafe { propertySetForwardingAddRefThunk(instanceRaw) }
        unsafe { result.write(instanceRaw) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    E_NOINTERFACE.value
}

@C
func propertySetForwardingAddRefThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = propertySetForwardingAddRefCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func propertySetForwardingReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = propertySetForwardingReleaseCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func propertySetForwardingSizeThunk(
    _: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(9u32) }
    propertySetForwardingSizeCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertySetForwardingRemoveMapChangedThunk(
    _: CPointer<Unit>,
    token: EventRegistrationTokenAbi
): Int32 {
    propertySetForwardingLastTokenValue.store(token.Value)
    propertySetForwardingRemoveMapChangedCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertySetForwardingFirstThunk(
    instanceRaw: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    propertySetForwardingFirstCalls.fetchAdd(1)
    unsafe { propertySetForwardingAddRefThunk(instanceRaw) }
    unsafe { result.write(instanceRaw) }
    S_OK.value
}

func propertySetForwardingMapVtbl(): IMapVtbl {
    var vtbl = IMapVtbl()
    vtbl.base_.base_.QueryInterface = propertySetForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = propertySetForwardingAddRefThunk
    vtbl.base_.base_.Release = propertySetForwardingReleaseThunk
    vtbl.Size = propertySetForwardingSizeThunk
    vtbl
}

func propertySetForwardingObservableMapVtbl(): IObservableMapVtbl {
    var vtbl = IObservableMapVtbl()
    vtbl.base_.base_.QueryInterface = propertySetForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = propertySetForwardingAddRefThunk
    vtbl.base_.base_.Release = propertySetForwardingReleaseThunk
    vtbl.RemoveMapChanged = propertySetForwardingRemoveMapChangedThunk
    vtbl
}

func propertySetForwardingIterableVtbl(): IIterableVtbl {
    var vtbl = IIterableVtbl()
    vtbl.base_.base_.QueryInterface = propertySetForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = propertySetForwardingAddRefThunk
    vtbl.base_.base_.Release = propertySetForwardingReleaseThunk
    vtbl.First = propertySetForwardingFirstThunk
    vtbl
}

func resetPropertySetForwardingCounters(): Unit {
    propertySetForwardingQueryCalls.store(0)
    propertySetForwardingAddRefCalls.store(0)
    propertySetForwardingReleaseCalls.store(0)
    propertySetForwardingSizeCalls.store(0)
    propertySetForwardingRemoveMapChangedCalls.store(0)
    propertySetForwardingFirstCalls.store(0)
    propertySetForwardingLastTokenValue.store(0)
}

func propertySetLookupRetainNotImplemented<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_NOTIMPL))
}

class PropertySetLookupRetainTestImpl <: IPropertySet_Impl {
    private let value: IInspectable
    public var failMapChanged: Bool = false
    public var throwWindowsOnMapChanged: Bool = false
    public var throwPlainOnRemoveMapChanged: Bool = false

    public init(value: IInspectable) {
        this.value = value
    }

    public func MapChanged(
        vhnd: InParam<MapChangedEventHandler<windows_core.HString, IInspectable>>
    ): Result<EventRegistrationToken> {
        let _ = vhnd
        if (throwWindowsOnMapChanged) {
            throw WindowsException(E_POINTER)
        }
        if (failMapChanged) {
            return Result<EventRegistrationToken>.Err(WinError.fromHRESULT(E_FAIL))
        }
        propertySetLookupRetainNotImplemented<EventRegistrationToken>()
    }

    public func RemoveMapChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        if (throwPlainOnRemoveMapChanged) {
            throw Exception("PropertySet RemoveMapChanged failure")
        }
        propertySetLookupRetainNotImplemented<Unit>()
    }

    public func Lookup(key: windows_core.HString): Result<IInspectable> {
        let _ = key
        Result<IInspectable>.Ok(value)
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(1u32)
    }

    public func HasKey(key: windows_core.HString): Result<Bool> {
        let _ = key
        Result<Bool>.Ok(true)
    }

    public func GetView(): Result<IMapView<windows_core.HString, IInspectable>> {
        propertySetLookupRetainNotImplemented<IMapView<windows_core.HString, IInspectable>>()
    }

    public func Insert(key: windows_core.HString, value: IInspectable): Result<Bool> {
        let _ = key
        let _ = value
        propertySetLookupRetainNotImplemented<Bool>()
    }

    public func Remove(key: windows_core.HString): Result<Unit> {
        let _ = key
        propertySetLookupRetainNotImplemented<Unit>()
    }

    public func Clear(): Result<Unit> {
        propertySetLookupRetainNotImplemented<Unit>()
    }

    public func First(): Result<IIterator<IKeyValuePair<windows_core.HString, IInspectable>>> {
        propertySetLookupRetainNotImplemented<IIterator<IKeyValuePair<windows_core.HString, IInspectable>>>()
    }
}

func withPropertySetForwardingMapRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IMapVtbl>(propertySetForwardingMapVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IMapVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)
    try {
        action(raw)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withPropertySetForwardingObservableMapRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IObservableMapVtbl>(propertySetForwardingObservableMapVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IObservableMapVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)
    try {
        action(raw)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withPropertySetForwardingIterableRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IIterableVtbl>(propertySetForwardingIterableVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IIterableVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)
    try {
        action(raw)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

@Test
func testIPropertySetLookupThunkRetainsReturnedInspectableWithoutClosingCachedWrapper() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingMapRaw({ raw: CPointer<Unit> =>
        let cached = IInspectable.viewOf(raw)
        let impl = PropertySetLookupRetainTestImpl(cached)
        let key = windows_core.HString("cached")
        let keyRaw = key.toSystemHandleCopy()
        var result = CPointer<Unit>()

        try {
            let hr = impl.__winrtThunk_Lookup(keyRaw, CPointer<CPointer<Unit>>(inout result))

            @Expect(hr, S_OK.value)
            @Expect(result.isNotNull(), true)
            @Expect(cached.isClosed(), false)
            @Expect(propertySetForwardingAddRefCalls.load(), 1)
        } finally {
            if (result.isNotNull()) {
                IInspectable.fromAbiTake(result).close()
            }
            windows_core.releaseSystemHStringHandle(keyRaw)
            key.close()
        }
    })
}

@Test
func testIPropertySetEventThunksClearTokenAndTranslateExceptions() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingMapRaw({ raw: CPointer<Unit> =>
        let cached = IInspectable.viewOf(raw)
        let impl = PropertySetLookupRetainTestImpl(cached)

        impl.failMapChanged = true
        var failToken = EventRegistrationTokenAbi()
        failToken.Value = 123i64
        let failHr = impl.__winrtThunk_MapChanged(CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout failToken))
        @Expect(failHr, E_FAIL.value)
        @Expect(failToken.Value, 0i64)
        impl.failMapChanged = false

        impl.throwWindowsOnMapChanged = true
        var throwToken = EventRegistrationTokenAbi()
        throwToken.Value = 456i64
        let throwHr = impl.__winrtThunk_MapChanged(CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout throwToken))
        @Expect(throwHr, E_POINTER.value)
        @Expect(throwToken.Value, 0i64)
        impl.throwWindowsOnMapChanged = false

        impl.throwPlainOnRemoveMapChanged = true
        var token = EventRegistrationTokenAbi()
        token.Value = 9i64
        @Expect(impl.__winrtThunk_RemoveMapChanged(token), E_FAIL.value)
        impl.throwPlainOnRemoveMapChanged = false
    })
}

@Test
func testIPropertySetForwardsMapReadsThroughQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingMapRaw({ raw: CPointer<Unit> =>
        let propertySet = IPropertySet.viewOf(raw)

        let value = unsafe { propertySet.Size() }

        @Expect(value, 9u32)
        @Expect(propertySetForwardingSizeCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 1)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testPropertySetRuntimeForwardsMapReadsThroughQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingMapRaw({ raw: CPointer<Unit> =>
        let propertySet = PropertySet.viewOf(raw)

        let value = unsafe { propertySet.Size() }

        @Expect(value, 9u32)
        @Expect(propertySetForwardingSizeCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 1)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testValueSetRuntimeForwardsMapReadsThroughQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingMapRaw({ raw: CPointer<Unit> =>
        let valueSet = ValueSet.viewOf(raw)

        let value = unsafe { valueSet.Size() }

        @Expect(value, 9u32)
        @Expect(propertySetForwardingSizeCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 1)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testStringMapRuntimeForwardsMapReadsThroughQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingMapRaw({ raw: CPointer<Unit> =>
        let stringMap = StringMap.viewOf(raw)

        let value = unsafe { stringMap.Size() }

        @Expect(value, 9u32)
        @Expect(propertySetForwardingSizeCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 1)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testIPropertySetForwardsObservableMapRemoveThroughQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingObservableMapRaw({ raw: CPointer<Unit> =>
        let propertySet = IPropertySet.viewOf(raw)
        var token = EventRegistrationToken()
        token.Value = 77i64

        unsafe { propertySet.RemoveMapChanged(token) }

        @Expect(propertySetForwardingRemoveMapChangedCalls.load(), 1)
        @Expect(propertySetForwardingLastTokenValue.load(), 77i64)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 1)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testIPropertySetForwardsIterableFirstThroughQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingIterableRaw({ raw: CPointer<Unit> =>
        let propertySet = IPropertySet.viewOf(raw)

        let iterator = unsafe { propertySet.First() }
        iterator.close()

        @Expect(propertySetForwardingFirstCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 2)
        @Expect(propertySetForwardingReleaseCalls.load(), 2)
    })
}

@Test
func testPropertySetRuntimeIteratorReleasesIterableQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingIterableRaw({ raw: CPointer<Unit> =>
        let propertySet = PropertySet.viewOf(raw)

        let _ = propertySet.intoIterator()

        @Expect(propertySetForwardingFirstCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 2)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testIMapIteratorReleasesIterableQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingIterableRaw({ raw: CPointer<Unit> =>
        let map = IMap<windows_core.HString, IInspectable>.viewOf(raw)

        let _ = map.intoIterator()

        @Expect(propertySetForwardingFirstCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 2)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testIVectorIteratorReleasesIterableQueryInterface() {
    resetPropertySetForwardingCounters()
    withPropertySetForwardingIterableRaw({ raw: CPointer<Unit> =>
        let vector = IVector<Int32>.viewOf(raw)

        let _ = vector.intoIterator()

        @Expect(propertySetForwardingFirstCalls.load(), 1)
        @Expect(propertySetForwardingQueryCalls.load(), 1)
        @Expect(propertySetForwardingAddRefCalls.load(), 2)
        @Expect(propertySetForwardingReleaseCalls.load(), 1)
    })
}
