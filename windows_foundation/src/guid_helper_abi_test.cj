package windows_foundation

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, GuidValue, S_OK}
import windows_interface.GUID

let guidHelperEqualsValueProjectionCalls = AtomicInt64(0)

func guidHelperEqualsTarget(): GUID {
    GUID.from_values(0x10203040, 0x5060, 0x7080, 0x90, 0xA0, 0xB0, 0xC0, 0xD0, 0xE0, 0xF0, 0x11)
}

func guidHelperEqualsOther(): GUID {
    GUID.from_values(0xFFEEDDCC, 0xBBAA, 0x9988, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00)
}

@C
func guidHelperEqualsPointerThunk(
    _: CPointer<Unit>,
    target: CPointer<GUID>,
    value: CPointer<GUID>,
    result__: CPointer<Bool>
): Int32 {
    if (target.isNull() || value.isNull() || result__.isNull()) {
        return E_POINTER.value
    }
    let targetValue = unsafe { target.read() }
    let valueValue = unsafe { value.read() }
    @Expect(targetValue == guidHelperEqualsTarget(), true)
    @Expect(valueValue == guidHelperEqualsTarget(), true)
    unsafe { result__.write(targetValue == valueValue) }
    guidHelperEqualsValueProjectionCalls.fetchAdd(1)
    S_OK.value
}

func guidHelperEqualsValueProjectionVtbl(): IGuidHelperStaticsVtbl {
    var vtbl = IGuidHelperStaticsVtbl()
    vtbl.Equals = guidHelperEqualsPointerThunk
    vtbl
}

func withGuidHelperEqualsValueProjectionRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IGuidHelperStaticsVtbl>(guidHelperEqualsValueProjectionVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IGuidHelperStaticsVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    action(raw)

    unsafe {
        windows_interface.freeNativeValue(objectHandle)
        windows_interface.freeNativeValue(vtblHandle)
    }
}

@Test
func testGuidHelperEqualsProjectsGuidValuesToAbiPointers() {
    guidHelperEqualsValueProjectionCalls.store(0)
    withGuidHelperEqualsValueProjectionRaw({ raw: CPointer<Unit> =>
        let helper = IGuidHelperStatics.viewOf(raw)
        let target = GuidValue.fromRaw(guidHelperEqualsTarget())
        let value = GuidValue.fromRaw(guidHelperEqualsTarget())

        let same = unsafe { helper.Equals(target, value) }

        @Expect(same, true)
        @Expect(guidHelperEqualsValueProjectionCalls.load(), 1)
    })
}
