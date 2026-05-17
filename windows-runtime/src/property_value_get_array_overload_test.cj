package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, GuidValue, S_OK}
import windows_core as windows_core
import windows_interface.{GUID, IInspectable}

let propertyValueGetArrayInt32Calls = AtomicInt64(0)
let propertyValueGetArrayGuidCalls = AtomicInt64(0)
let propertyValueGetArrayDateTimeCalls = AtomicInt64(0)
let propertyValueGetArrayRectCalls = AtomicInt64(0)
let propertyValueGetArrayStringCalls = AtomicInt64(0)
let propertyValueGetArrayInspectableCalls = AtomicInt64(0)
let propertyValueGetArrayInspectableReleaseCalls = AtomicInt64(0)

func propertyValueGetArrayGuidExpected(offset: UInt32): GUID {
    GUID.from_values(0xB0C0D000u32 + offset, 0x2211u16, 0x4433u16, 0x66u8, 0x55u8, 0x88u8, 0x77u8, 0xAAu8, 0x99u8, 0xCCu8, 0xBBu8)
}

func propertyValueGetArrayDateTimeAbi(value: Int64): DateTimeAbi {
    var result = DateTimeAbi()
    result.UniversalTime = value
    result
}

func propertyValueGetArrayRectAbi(x: Float32, y: Float32, width: Float32, height: Float32): RectAbi {
    var result = RectAbi()
    result.X = x
    result.Y = y
    result.Width = width
    result.Height = height
    result
}

func allocatePropertyValueGetArray<T>(length: Int64): CPointer<T> where T <: CType {
    let raw = windows_core.coTaskMemAlloc(sizeOf<T>() * UIntNative(length))
    CPointer<T>(raw)
}

func propertyValueGetArraySystemString(value: String): CPointer<Unit> {
    let text = windows_core.HString(value)
    var raw = CPointer<Unit>()
    try {
        raw = text.toSystemHandleCopy()
    } finally {
        text.close()
    }
    raw
}

func closePropertyValueGetArrayStrings(values: Array<windows_core.HString>): Unit {
    var index = 0
    while (index < values.size) {
        values[index].close()
        index += 1
    }
}

func closePropertyValueGetArrayInspectables(values: Array<Option<IInspectable>>): Unit {
    var index = 0
    while (index < values.size) {
        match (values[index]) {
            case Some(value) => value.close()
            case None => ()
        }
        index += 1
    }
}

func expectPropertyValueGetArrayInspectableSome(value: Option<IInspectable>): IInspectable {
    match (value) {
        case Some(item) => item
        case None => throw Exception("expected inspectable value")
    }
}

func expectPropertyValueGetArrayInspectableNone(value: Option<IInspectable>): Unit {
    match (value) {
        case Some(_) => throw Exception("expected null inspectable value")
        case None => ()
    }
}

@C
func propertyValueGetArrayInspectableReleaseThunk(raw: CPointer<Unit>): UInt32 {
    let oldCount = propertyValueGetArrayInspectableReleaseCalls.fetchAdd(1)
    windows_core.coTaskMemFree(raw)
    UInt32(oldCount + 1)
}

func propertyValueGetArrayInspectableObject(instanceRaw: CPointer<Unit>): CPointer<Unit> {
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
func propertyValueGetInt32ArrayThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<Int32>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocatePropertyValueGetArray<Int32>(3)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(10i32)
        (data + 1).write(20i32)
        (data + 2).write(30i32)
        size.write(3u32)
        value.write(data)
    }
    propertyValueGetArrayInt32Calls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueGetStringArrayHighLevelThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<CPointer<Unit>>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocatePropertyValueGetArray<CPointer<Unit>>(3)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(propertyValueGetArraySystemString("left"))
        (data + 1).write(CPointer<Unit>())
        (data + 2).write(propertyValueGetArraySystemString("right"))
        size.write(3u32)
        value.write(data)
    }
    propertyValueGetArrayStringCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueGetInspectableArrayHighLevelThunk(
    instanceRaw: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<CPointer<Unit>>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocatePropertyValueGetArray<CPointer<Unit>>(3)
    if (data.isNull()) {
        return E_POINTER.value
    }
    let first = propertyValueGetArrayInspectableObject(instanceRaw)
    let third = propertyValueGetArrayInspectableObject(instanceRaw)
    if (first.isNull() || third.isNull()) {
        if (first.isNotNull()) {
            windows_core.coTaskMemFree(first)
        }
        if (third.isNotNull()) {
            windows_core.coTaskMemFree(third)
        }
        windows_core.coTaskMemFree(CPointer<Unit>(data))
        return E_POINTER.value
    }
    unsafe {
        data.write(first)
        (data + 1).write(CPointer<Unit>())
        (data + 2).write(third)
        size.write(3u32)
        value.write(data)
    }
    propertyValueGetArrayInspectableCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueGetGuidArrayHighLevelThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<GUID>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocatePropertyValueGetArray<GUID>(2)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(propertyValueGetArrayGuidExpected(1u32))
        (data + 1).write(propertyValueGetArrayGuidExpected(2u32))
        size.write(2u32)
        value.write(data)
    }
    propertyValueGetArrayGuidCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueGetDateTimeArrayThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<DateTimeAbi>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocatePropertyValueGetArray<DateTimeAbi>(2)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(propertyValueGetArrayDateTimeAbi(111i64))
        (data + 1).write(propertyValueGetArrayDateTimeAbi(222i64))
        size.write(2u32)
        value.write(data)
    }
    propertyValueGetArrayDateTimeCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueGetRectArrayThunk(
    _: CPointer<Unit>,
    size: CPointer<UInt32>,
    value: CPointer<CPointer<RectAbi>>
): Int32 {
    if (size.isNull() || value.isNull()) {
        return E_POINTER.value
    }
    let data = allocatePropertyValueGetArray<RectAbi>(2)
    if (data.isNull()) {
        return E_POINTER.value
    }
    unsafe {
        data.write(propertyValueGetArrayRectAbi(1.0f32, 2.0f32, 3.0f32, 4.0f32))
        (data + 1).write(propertyValueGetArrayRectAbi(5.0f32, 6.0f32, 7.0f32, 8.0f32))
        size.write(2u32)
        value.write(data)
    }
    propertyValueGetArrayRectCalls.fetchAdd(1)
    S_OK.value
}

func propertyValueGetArrayOverloadVtbl(): IPropertyValueVtbl {
    var vtbl = IPropertyValueVtbl()
    vtbl.base_.base_.Release = propertyValueGetArrayInspectableReleaseThunk
    vtbl.GetInt32Array = propertyValueGetInt32ArrayThunk
    vtbl.GetStringArray = propertyValueGetStringArrayHighLevelThunk
    vtbl.GetInspectableArray = propertyValueGetInspectableArrayHighLevelThunk
    vtbl.GetGuidArray = propertyValueGetGuidArrayHighLevelThunk
    vtbl.GetDateTimeArray = propertyValueGetDateTimeArrayThunk
    vtbl.GetRectArray = propertyValueGetRectArrayThunk
    vtbl
}

func withPropertyValueGetArrayOverloadRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IPropertyValueVtbl>(propertyValueGetArrayOverloadVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IPropertyValueVtbl>>(vtblHandle) }
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
func testIPropertyValueGetArrayOverloadsReturnPrimitiveManagedArrays() {
    propertyValueGetArrayInt32Calls.store(0)
    withPropertyValueGetArrayOverloadRaw({ raw: CPointer<Unit> =>
        let propertyValue = IPropertyValue.viewOf(raw)

        let values = unsafe { propertyValue.GetInt32Array() }

        @Expect(values.size, 3)
        @Expect(values[0], 10i32)
        @Expect(values[1], 20i32)
        @Expect(values[2], 30i32)
        @Expect(propertyValueGetArrayInt32Calls.load(), 1)
    })
}

@Test
func testIPropertyValueGetArrayOverloadsReturnStringManagedArrays() {
    propertyValueGetArrayStringCalls.store(0)
    withPropertyValueGetArrayOverloadRaw({ raw: CPointer<Unit> =>
        let propertyValue = IPropertyValue.viewOf(raw)
        let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()

        let values = unsafe { propertyValue.GetStringArray() }
        try {
            @Expect(values.size, 3)
            @Expect(values[0].get(), "left")
            @Expect(values[1].get(), "")
            @Expect(values[2].get(), "right")
            @Expect(propertyValueGetArrayStringCalls.load(), 1)
            @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore >= 2, true)
        } finally {
            closePropertyValueGetArrayStrings(values)
        }
    })
}

@Test
func testIPropertyValueGetArrayOverloadsReturnInspectableOptionArrays() {
    propertyValueGetArrayInspectableCalls.store(0)
    propertyValueGetArrayInspectableReleaseCalls.store(0)
    withPropertyValueGetArrayOverloadRaw({ raw: CPointer<Unit> =>
        let propertyValue = IPropertyValue.viewOf(raw)

        let values = unsafe { propertyValue.GetInspectableArray() }
        try {
            @Expect(values.size, 3)
            let first = expectPropertyValueGetArrayInspectableSome(values[0])
            expectPropertyValueGetArrayInspectableNone(values[1])
            let third = expectPropertyValueGetArrayInspectableSome(values[2])
            @Expect(first.asRaw().isNotNull(), true)
            @Expect(third.asRaw().isNotNull(), true)
            @Expect(first.asRaw().toUIntNative() == third.asRaw().toUIntNative(), false)
            @Expect(propertyValueGetArrayInspectableCalls.load(), 1)
            @Expect(propertyValueGetArrayInspectableReleaseCalls.load(), 0)
        } finally {
            closePropertyValueGetArrayInspectables(values)
        }
        @Expect(propertyValueGetArrayInspectableReleaseCalls.load(), 2)
    })
}

@Test
func testIPropertyValueGetArrayOverloadsProjectCopyStructArrays() {
    propertyValueGetArrayGuidCalls.store(0)
    propertyValueGetArrayDateTimeCalls.store(0)
    propertyValueGetArrayRectCalls.store(0)

    withPropertyValueGetArrayOverloadRaw({ raw: CPointer<Unit> =>
        let propertyValue = IPropertyValue.viewOf(raw)

        let guidValues = unsafe { propertyValue.GetGuidArray() }
        let dateTimeValues = unsafe { propertyValue.GetDateTimeArray() }
        let rectValues = unsafe { propertyValue.GetRectArray() }

        @Expect(guidValues.size, 2)
        @Expect(guidValues[0] == GuidValue.fromRaw(propertyValueGetArrayGuidExpected(1u32)), true)
        @Expect(guidValues[1] == GuidValue.fromRaw(propertyValueGetArrayGuidExpected(2u32)), true)

        @Expect(dateTimeValues.size, 2)
        @Expect(dateTimeValues[0].UniversalTime, 111i64)
        @Expect(dateTimeValues[1].UniversalTime, 222i64)

        @Expect(rectValues.size, 2)
        @Expect(rectValues[0].X, 1.0f32)
        @Expect(rectValues[0].Y, 2.0f32)
        @Expect(rectValues[0].Width, 3.0f32)
        @Expect(rectValues[0].Height, 4.0f32)
        @Expect(rectValues[1].X, 5.0f32)
        @Expect(rectValues[1].Y, 6.0f32)
        @Expect(rectValues[1].Width, 7.0f32)
        @Expect(rectValues[1].Height, 8.0f32)

        @Expect(propertyValueGetArrayGuidCalls.load(), 1)
        @Expect(propertyValueGetArrayDateTimeCalls.load(), 1)
        @Expect(propertyValueGetArrayRectCalls.load(), 1)
    })
}
