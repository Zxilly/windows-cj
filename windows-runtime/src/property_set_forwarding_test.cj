package windows_runtime

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, E_POINTER, S_OK}
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
        target == IObservableMap<windows_core.HString, IInspectable>.iid() ||
        target == IIterable<IKeyValuePair<windows_core.HString, IInspectable>>.iid() ||
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

func withPropertySetForwardingMapRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IMapVtbl>(1, { _ => propertySetForwardingMapVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IMapVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

func withPropertySetForwardingObservableMapRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IObservableMapVtbl>(1, { _ => propertySetForwardingObservableMapVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IObservableMapVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

func withPropertySetForwardingIterableRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IIterableVtbl>(1, { _ => propertySetForwardingIterableVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IIterableVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
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
