package windows_runtime

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, E_POINTER, S_OK}
import windows_core as windows_core
import windows_interface.{GUID, IInspectable, IUnknown}

let referenceArrayPropertyValueForwardingQueryCalls = AtomicInt64(0)
let referenceArrayPropertyValueForwardingAddRefCalls = AtomicInt64(0)
let referenceArrayPropertyValueForwardingReleaseCalls = AtomicInt64(0)
let referenceArrayPropertyValueForwardingGetSingleCalls = AtomicInt64(0)
let referenceArrayPropertyValueForwardingGetInt32ArrayCalls = AtomicInt64(0)

@C
func referenceArrayPropertyValueForwardingQueryInterfaceThunk(
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
        target == IReferenceArray<Float32>.iid() ||
        target == IInspectable.iid() ||
        target == IUnknown.iid()
    ) {
        referenceArrayPropertyValueForwardingQueryCalls.fetchAdd(1)
        unsafe { referenceArrayPropertyValueForwardingAddRefThunk(instanceRaw) }
        unsafe { result.write(instanceRaw) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    E_NOINTERFACE.value
}

@C
func referenceArrayPropertyValueForwardingAddRefThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = referenceArrayPropertyValueForwardingAddRefCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func referenceArrayPropertyValueForwardingReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = referenceArrayPropertyValueForwardingReleaseCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func referenceArrayPropertyValueForwardingGetSingleThunk(
    _: CPointer<Unit>,
    result: CPointer<Float32>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(7.5f32) }
    referenceArrayPropertyValueForwardingGetSingleCalls.fetchAdd(1)
    S_OK.value
}

@C
func referenceArrayPropertyValueForwardingGetInt32ArrayThunk(
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
    referenceArrayPropertyValueForwardingGetInt32ArrayCalls.fetchAdd(1)
    S_OK.value
}

func referenceArrayPropertyValueForwardingVtbl(): IPropertyValueVtbl {
    var vtbl = IPropertyValueVtbl()
    vtbl.base_.base_.QueryInterface = referenceArrayPropertyValueForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = referenceArrayPropertyValueForwardingAddRefThunk
    vtbl.base_.base_.Release = referenceArrayPropertyValueForwardingReleaseThunk
    vtbl.GetSingle = referenceArrayPropertyValueForwardingGetSingleThunk
    vtbl.GetInt32Array = referenceArrayPropertyValueForwardingGetInt32ArrayThunk
    vtbl
}

func resetReferenceArrayPropertyValueForwardingCounters(): Unit {
    referenceArrayPropertyValueForwardingQueryCalls.store(0)
    referenceArrayPropertyValueForwardingAddRefCalls.store(0)
    referenceArrayPropertyValueForwardingReleaseCalls.store(0)
    referenceArrayPropertyValueForwardingGetSingleCalls.store(0)
    referenceArrayPropertyValueForwardingGetInt32ArrayCalls.store(0)
}

func withReferenceArrayPropertyValueForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IPropertyValueVtbl>(1, { _ => referenceArrayPropertyValueForwardingVtbl() })) }
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
func testIReferenceArrayForwardsScalarPropertyValueReads() {
    resetReferenceArrayPropertyValueForwardingCounters()
    withReferenceArrayPropertyValueForwardingRaw({ raw: CPointer<Unit> =>
        let reference = IReferenceArray<Float32>.viewOf(raw)

        let value = unsafe { reference.GetSingle() }

        @Expect(value, 7.5f32)
        @Expect(referenceArrayPropertyValueForwardingGetSingleCalls.load(), 1)
        @Expect(referenceArrayPropertyValueForwardingQueryCalls.load(), 1)
        @Expect(referenceArrayPropertyValueForwardingAddRefCalls.load(), 1)
        @Expect(referenceArrayPropertyValueForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testIReferenceArrayForwardsArrayPropertyValueReads() {
    resetReferenceArrayPropertyValueForwardingCounters()
    withReferenceArrayPropertyValueForwardingRaw({ raw: CPointer<Unit> =>
        let reference = IReferenceArray<Float32>.viewOf(raw)

        let values = unsafe { reference.GetInt32Array() }

        @Expect(values.size, 2)
        @Expect(values[0], 42i32)
        @Expect(values[1], 84i32)
        @Expect(referenceArrayPropertyValueForwardingGetInt32ArrayCalls.load(), 1)
        @Expect(referenceArrayPropertyValueForwardingQueryCalls.load(), 1)
        @Expect(referenceArrayPropertyValueForwardingAddRefCalls.load(), 1)
        @Expect(referenceArrayPropertyValueForwardingReleaseCalls.load(), 1)
    })
}
