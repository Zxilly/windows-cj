package windows_runtime

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, E_POINTER, S_OK}
import windows_core as windows_core
import windows_interface.{GUID, IInspectable, IUnknown}

let referencePropertyValueForwardingQueryCalls = AtomicInt64(0)
let referencePropertyValueForwardingAddRefCalls = AtomicInt64(0)
let referencePropertyValueForwardingReleaseCalls = AtomicInt64(0)
let referencePropertyValueForwardingGetSingleCalls = AtomicInt64(0)
let referencePropertyValueForwardingGetInt32ArrayCalls = AtomicInt64(0)

@C
func referencePropertyValueForwardingQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (iid.isNull() || result.isNull()) {
        return E_POINTER.value
    }
    let target = unsafe { iid.read() }
    if (
        target == IPropertyValue.iid() ||
        target == IReference<Float32>.iid() ||
        target == IInspectable.iid() ||
        target == IUnknown.iid()
    ) {
        referencePropertyValueForwardingQueryCalls.fetchAdd(1)
        unsafe { referencePropertyValueForwardingAddRefThunk(instanceRaw) }
        unsafe { result.write(instanceRaw) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    E_NOINTERFACE.value
}

@C
func referencePropertyValueForwardingAddRefThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = referencePropertyValueForwardingAddRefCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func referencePropertyValueForwardingReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = referencePropertyValueForwardingReleaseCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func referencePropertyValueForwardingGetSingleThunk(
    _: CPointer<Unit>,
    result: CPointer<Float32>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(7.5f32) }
    referencePropertyValueForwardingGetSingleCalls.fetchAdd(1)
    S_OK.value
}

@C
func referencePropertyValueForwardingGetInt32ArrayThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<Int32>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = windows_core.coTaskMemAlloc(sizeOf<Int32>() * UIntNative(2))
    if (data.isNull()) {
        return E_POINTER.value
    }
    let items = CPointer<Int32>(data)
    unsafe {
        items.write(42i32)
        (items + 1).write(84i32)
        size.write(2u32)
        value.write(items)
    }
    referencePropertyValueForwardingGetInt32ArrayCalls.fetchAdd(1)
    S_OK.value
}

func referencePropertyValueForwardingVtbl(): IPropertyValueVtbl {
    var vtbl = IPropertyValueVtbl()
    vtbl.base_.base_.QueryInterface = referencePropertyValueForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = referencePropertyValueForwardingAddRefThunk
    vtbl.base_.base_.Release = referencePropertyValueForwardingReleaseThunk
    vtbl.GetSingle = referencePropertyValueForwardingGetSingleThunk
    vtbl.GetInt32Array = referencePropertyValueForwardingGetInt32ArrayThunk
    vtbl
}

func resetReferencePropertyValueForwardingCounters(): Unit {
    referencePropertyValueForwardingQueryCalls.store(0)
    referencePropertyValueForwardingAddRefCalls.store(0)
    referencePropertyValueForwardingReleaseCalls.store(0)
    referencePropertyValueForwardingGetSingleCalls.store(0)
    referencePropertyValueForwardingGetInt32ArrayCalls.store(0)
}

func withReferencePropertyValueForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IPropertyValueVtbl>(1, { _ => referencePropertyValueForwardingVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IPropertyValueVtbl>>(1, { _ => vtblHandle.pointer })) }
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
func testIReferenceForwardsScalarPropertyValueReads() {
    resetReferencePropertyValueForwardingCounters()
    withReferencePropertyValueForwardingRaw({ raw: CPointer<Unit> =>
        let reference = IReference<Float32>.viewOf(raw)

        let value = unsafe { reference.GetSingle() }

        @Expect(value, 7.5f32)
        @Expect(referencePropertyValueForwardingGetSingleCalls.load(), 1)
        @Expect(referencePropertyValueForwardingQueryCalls.load(), 1)
        @Expect(referencePropertyValueForwardingAddRefCalls.load(), 1)
        @Expect(referencePropertyValueForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testIReferenceForwardsArrayPropertyValueReads() {
    resetReferencePropertyValueForwardingCounters()
    withReferencePropertyValueForwardingRaw({ raw: CPointer<Unit> =>
        let reference = IReference<Float32>.viewOf(raw)

        let values = unsafe { reference.GetInt32Array() }

        @Expect(values.size, 2)
        @Expect(values[0], 42i32)
        @Expect(values[1], 84i32)
        @Expect(referencePropertyValueForwardingGetInt32ArrayCalls.load(), 1)
        @Expect(referencePropertyValueForwardingQueryCalls.load(), 1)
        @Expect(referencePropertyValueForwardingAddRefCalls.load(), 1)
        @Expect(referencePropertyValueForwardingReleaseCalls.load(), 1)
    })
}
