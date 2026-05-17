package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, S_OK}
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
