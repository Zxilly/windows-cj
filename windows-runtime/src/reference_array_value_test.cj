package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, S_OK}
import windows_core as windows_core
import windows_interface.IInspectable

let referenceArrayValueInt32Calls = AtomicInt64(0)
let referenceArrayValueDateTimeCalls = AtomicInt64(0)
let referenceArrayValueStringCalls = AtomicInt64(0)
let referenceArrayValueInspectableCalls = AtomicInt64(0)
let referenceArrayValueInspectableReleaseCalls = AtomicInt64(0)

func allocateReferenceArrayValue<T>(length: Int64): CPointer<T> where T <: CType {
    let raw = windows_core.coTaskMemAlloc(sizeOf<T>() * UIntNative(length))
    CPointer<T>(raw)
}

func referenceArrayValueDateTimeAbi(value: Int64): DateTimeAbi {
    var result = DateTimeAbi()
    result.UniversalTime = value
    result
}

func referenceArrayValueSystemString(value: String): CPointer<Unit> {
    let text = windows_core.HString(value)
    var raw = CPointer<Unit>()
    try {
        raw = text.toSystemHandleCopy()
    } finally {
        text.close()
    }
    raw
}

func closeReferenceArrayValueStrings(values: Array<windows_core.HString>): Unit {
    var index = 0
    while (index < values.size) {
        values[index].close()
        index += 1
    }
}

func closeReferenceArrayValueInspectables(values: Array<IInspectable>): Unit {
    var index = 0
    while (index < values.size) {
        values[index].close()
        index += 1
    }
}

@C
func referenceArrayValueInspectableReleaseThunk(raw: CPointer<Unit>): UInt32 {
    let oldCount = referenceArrayValueInspectableReleaseCalls.fetchAdd(1)
    windows_core.coTaskMemFree(raw)
    UInt32(oldCount + 1)
}

func referenceArrayValueInspectableObject(instanceRaw: CPointer<Unit>): CPointer<Unit> {
    let objectRaw = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>())
    if (objectRaw.isNull()) {
        return CPointer<Unit>()
    }
    unsafe {
        let vtbl = CPointer<CPointer<Unit>>(instanceRaw).read()
        CPointer<CPointer<Unit>>(objectRaw).write(vtbl)
    }
    objectRaw
}

@C
func referenceArrayValueInt32Thunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocateReferenceArrayValue<Int32>(3)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(11i32)
        (data + 1).write(22i32)
        (data + 2).write(33i32)
        size.write(3u32)
        value.write(CPointer<Unit>(data))
    }
    referenceArrayValueInt32Calls.fetchAdd(1)
    S_OK.value
}

@C
func referenceArrayValueDateTimeThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocateReferenceArrayValue<DateTimeAbi>(2)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(referenceArrayValueDateTimeAbi(101i64))
        (data + 1).write(referenceArrayValueDateTimeAbi(202i64))
        size.write(2u32)
        value.write(CPointer<Unit>(data))
    }
    referenceArrayValueDateTimeCalls.fetchAdd(1)
    S_OK.value
}

@C
func referenceArrayValueStringThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocateReferenceArrayValue<CPointer<Unit>>(3)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(referenceArrayValueSystemString("alpha"))
        (data + 1).write(CPointer<Unit>())
        (data + 2).write(referenceArrayValueSystemString("omega"))
        size.write(3u32)
        value.write(CPointer<Unit>(data))
    }
    referenceArrayValueStringCalls.fetchAdd(1)
    S_OK.value
}

@C
func referenceArrayValueInspectableThunk(
    instanceRaw: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocateReferenceArrayValue<CPointer<Unit>>(2)
    if (data.isNull()) {
        return E_POINTER.value
    }
    let first = referenceArrayValueInspectableObject(instanceRaw)
    let second = referenceArrayValueInspectableObject(instanceRaw)
    if (first.isNull() || second.isNull()) {
        if (first.isNotNull()) {
            windows_core.coTaskMemFree(first)
        }
        if (second.isNotNull()) {
            windows_core.coTaskMemFree(second)
        }
        windows_core.coTaskMemFree(CPointer<Unit>(data))
        return E_POINTER.value
    }
    unsafe {
        data.write(first)
        (data + 1).write(second)
        size.write(2u32)
        value.write(CPointer<Unit>(data))
    }
    referenceArrayValueInspectableCalls.fetchAdd(1)
    S_OK.value
}

func referenceArrayValueVtbl(
    action: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<Unit>>) -> Int32>
): IReferenceArrayVtbl {
    var vtbl = IReferenceArrayVtbl()
    vtbl.base_.base_.Release = referenceArrayValueInspectableReleaseThunk
    vtbl.Value = action
    vtbl
}

func withReferenceArrayValueRaw(
    vtbl: IReferenceArrayVtbl,
    action: (CPointer<Unit>) -> Unit
): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IReferenceArrayVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IReferenceArrayVtbl>>(vtblHandle) }
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
func testIReferenceArrayValueReturnsCopyArray() {
    referenceArrayValueInt32Calls.store(0)
    withReferenceArrayValueRaw(referenceArrayValueVtbl(referenceArrayValueInt32Thunk), { raw: CPointer<Unit> =>
        let reference = IReferenceArray<Int32>.viewOf(raw)

        let values = unsafe { reference.Value() }

        @Expect(values.size, 3)
        @Expect(values[0], 11i32)
        @Expect(values[1], 22i32)
        @Expect(values[2], 33i32)
        @Expect(referenceArrayValueInt32Calls.load(), 1)
    })
}

@Test
func testIReferenceArrayValueReturnsProjectedCopyArray() {
    referenceArrayValueDateTimeCalls.store(0)
    withReferenceArrayValueRaw(referenceArrayValueVtbl(referenceArrayValueDateTimeThunk), { raw: CPointer<Unit> =>
        let reference = IReferenceArray<DateTime>.viewOf(raw)

        let values = unsafe { reference.Value() }

        @Expect(values.size, 2)
        @Expect(values[0].UniversalTime, 101i64)
        @Expect(values[1].UniversalTime, 202i64)
        @Expect(referenceArrayValueDateTimeCalls.load(), 1)
    })
}

@Test
func testIReferenceArrayValueReturnsHStringArray() {
    referenceArrayValueStringCalls.store(0)
    withReferenceArrayValueRaw(referenceArrayValueVtbl(referenceArrayValueStringThunk), { raw: CPointer<Unit> =>
        let reference = IReferenceArray<windows_core.HString>.viewOf(raw)
        let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()

        let values = unsafe { reference.Value() }
        try {
            @Expect(values.size, 3)
            @Expect(values[0].get(), "alpha")
            @Expect(values[1].get(), "")
            @Expect(values[2].get(), "omega")
            @Expect(referenceArrayValueStringCalls.load(), 1)
            @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore >= 2, true)
        } finally {
            closeReferenceArrayValueStrings(values)
        }
    })
}

@Test
func testIReferenceArrayValueReturnsInspectableArray() {
    referenceArrayValueInspectableCalls.store(0)
    referenceArrayValueInspectableReleaseCalls.store(0)
    withReferenceArrayValueRaw(referenceArrayValueVtbl(referenceArrayValueInspectableThunk), { raw: CPointer<Unit> =>
        let reference = IReferenceArray<IInspectable>.viewOf(raw)

        let values = unsafe { reference.Value() }
        try {
            @Expect(values.size, 2)
            @Expect(values[0].asRaw().isNotNull(), true)
            @Expect(values[1].asRaw().isNotNull(), true)
            @Expect(values[0].asRaw().toUIntNative() == values[1].asRaw().toUIntNative(), false)
            @Expect(referenceArrayValueInspectableCalls.load(), 1)
            @Expect(referenceArrayValueInspectableReleaseCalls.load(), 0)
        } finally {
            closeReferenceArrayValueInspectables(values)
        }
        @Expect(referenceArrayValueInspectableReleaseCalls.load(), 2)
    })
}
