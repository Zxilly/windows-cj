package windows_foundation

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOTIMPL, E_POINTER, S_OK}
import windows_interface.GUID

let propertyValueArrayAbiSizeWrites = AtomicInt64(0)

@C
func propertyValueGetGuidArrayThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<GUID>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        size.write(2u32)
        value.write(CPointer<GUID>())
    }
    propertyValueArrayAbiSizeWrites.fetchAdd(1)
    S_OK.value
}

func propertyValueArrayAbiVtbl(): IPropertyValueVtbl {
    var vtbl = IPropertyValueVtbl()
    vtbl.GetGuidArray = propertyValueGetGuidArrayThunk
    vtbl
}

func withPropertyValueArrayAbiRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IPropertyValueVtbl>(propertyValueArrayAbiVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IPropertyValueVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    action(raw)

    unsafe {
        windows_interface.freeNativeValue(objectHandle)
        windows_interface.freeNativeValue(vtblHandle)
    }
}

@Test
func testIPropertyValueGetGuidArrayPassesSizeAndValueSlots() {
    propertyValueArrayAbiSizeWrites.store(0)
    withPropertyValueArrayAbiRaw({ raw: CPointer<Unit> =>
        let view = IPropertyValue.viewOf(raw)
        var size = 0u32
        var value = CPointer<GUID>()

        unsafe { view.GetGuidArray(CPointer<UInt32>(inout size), CPointer<CPointer<GUID>>(inout value)) }

        @Expect(size, 2u32)
        @Expect(value.isNull(), true)
        @Expect(propertyValueArrayAbiSizeWrites.load(), 1)
    })
}

@Test
func testIPropertyValueDefaultVtblClearsOutSlotsBeforeNotImpl() {
    var vtbl = IPropertyValueVtbl()
    var intValue = 123i32
    @Expect(unsafe { vtbl.GetInt32(CPointer<Unit>(), CPointer<Int32>(inout intValue)) }, E_NOTIMPL.value)
    @Expect(intValue, 0i32)

    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(7u8) }
    try {
        var stringRaw = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { vtbl.GetString(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout stringRaw)) },
            E_NOTIMPL.value
        )
        @Expect(stringRaw.isNull(), true)

        var intSize = 9u32
        var intData = CPointer<Int32>(sentinel)
        @Expect(
            unsafe { vtbl.GetInt32Array(CPointer<Unit>(), CPointer<UInt32>(inout intSize), CPointer<CPointer<Int32>>(inout intData)) },
            E_NOTIMPL.value
        )
        @Expect(intSize, 0u32)
        @Expect(intData.isNull(), true)

        var stringSize = 11u32
        var stringData = CPointer<CPointer<Unit>>(sentinel)
        @Expect(
            unsafe { vtbl.GetStringArray(CPointer<Unit>(), CPointer<UInt32>(inout stringSize), CPointer<CPointer<CPointer<Unit>>>(inout stringData)) },
            E_NOTIMPL.value
        )
        @Expect(stringSize, 0u32)
        @Expect(stringData.isNull(), true)

        var inspectableSize = 13u32
        var inspectableData = CPointer<CPointer<Unit>>(sentinel)
        @Expect(
            unsafe { vtbl.GetInspectableArray(CPointer<Unit>(), CPointer<UInt32>(inout inspectableSize), CPointer<CPointer<CPointer<Unit>>>(inout inspectableData)) },
            E_NOTIMPL.value
        )
        @Expect(inspectableSize, 0u32)
        @Expect(inspectableData.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue(sentinel) }
    }
}

@Test
func testIPropertyValueStaticsDefaultVtblClearsResultBeforeNotImpl() {
    var vtbl = IPropertyValueStaticsVtbl()
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(9u8) }
    try {
        var stringResult = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { vtbl.CreateString(CPointer<Unit>(), CPointer<Unit>(), CPointer<CPointer<Unit>>(inout stringResult)) },
            E_NOTIMPL.value
        )
        @Expect(stringResult.isNull(), true)

        var inspectableResult = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { vtbl.CreateInspectable(CPointer<Unit>(), CPointer<Unit>(), CPointer<CPointer<Unit>>(inout inspectableResult)) },
            E_NOTIMPL.value
        )
        @Expect(inspectableResult.isNull(), true)

        var intArrayResult = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { vtbl.CreateInt32Array(CPointer<Unit>(), 0u32, CPointer<Int32>(), CPointer<CPointer<Unit>>(inout intArrayResult)) },
            E_NOTIMPL.value
        )
        @Expect(intArrayResult.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue(sentinel) }
    }
}
