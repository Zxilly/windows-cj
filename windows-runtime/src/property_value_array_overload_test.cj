package windows_runtime

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, GuidValue, S_OK}
import windows_core as windows_core
import windows_interface.{GUID, IInspectable}

let propertyValueArrayInt32Calls = AtomicInt64(0)
let propertyValueArrayGuidCalls = AtomicInt64(0)
let propertyValueArrayDateTimeCalls = AtomicInt64(0)
let propertyValueArrayRectCalls = AtomicInt64(0)
let propertyValueArrayStringCalls = AtomicInt64(0)
let propertyValueArrayInspectableCalls = AtomicInt64(0)

func propertyValueArrayGuidExpected(offset: UInt32): GUID {
    GUID.from_values(0xA0B0C000u32 + offset, 0x1122u16, 0x3344u16, 0x55u8, 0x66u8, 0x77u8, 0x88u8, 0x99u8, 0xAAu8, 0xBBu8, 0xCCu8)
}

func propertyValueArrayDateTime(value: Int64): DateTime {
    var result = DateTime()
    result.UniversalTime = value
    result
}

func propertyValueArrayRect(x: Float32, y: Float32, width: Float32, height: Float32): Rect {
    var result = Rect()
    result.X = x
    result.Y = y
    result.Width = width
    result.Height = height
    result
}

@C
func propertyValueCreateInt32ArrayThunk(
    _: CPointer<Unit>,
    valueSize: UInt32,
    value: CPointer<Int32>,
    result__: CPointer<CPointer<Unit>>
): Int32 {
    if (value.isNull() || result__.isNull()) {
        return E_POINTER.value
    }
    @Expect(valueSize, 3u32)
    @Expect(unsafe { value.read(0) }, 10i32)
    @Expect(unsafe { value.read(1) }, 20i32)
    @Expect(unsafe { value.read(2) }, 30i32)
    unsafe { result__.write(CPointer<Unit>()) }
    propertyValueArrayInt32Calls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueCreateGuidArrayThunk(
    _: CPointer<Unit>,
    valueSize: UInt32,
    value: CPointer<GUID>,
    result__: CPointer<CPointer<Unit>>
): Int32 {
    if (value.isNull() || result__.isNull()) {
        return E_POINTER.value
    }
    @Expect(valueSize, 2u32)
    @Expect(unsafe { value.read(0) } == propertyValueArrayGuidExpected(1u32), true)
    @Expect(unsafe { value.read(1) } == propertyValueArrayGuidExpected(2u32), true)
    unsafe { result__.write(CPointer<Unit>()) }
    propertyValueArrayGuidCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueCreateDateTimeArrayThunk(
    _: CPointer<Unit>,
    valueSize: UInt32,
    value: CPointer<DateTimeAbi>,
    result__: CPointer<CPointer<Unit>>
): Int32 {
    if (value.isNull() || result__.isNull()) {
        return E_POINTER.value
    }
    @Expect(valueSize, 2u32)
    @Expect(unsafe { value.read(0) }.UniversalTime, 111i64)
    @Expect(unsafe { value.read(1) }.UniversalTime, 222i64)
    unsafe { result__.write(CPointer<Unit>()) }
    propertyValueArrayDateTimeCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueCreateRectArrayThunk(
    _: CPointer<Unit>,
    valueSize: UInt32,
    value: CPointer<RectAbi>,
    result__: CPointer<CPointer<Unit>>
): Int32 {
    if (value.isNull() || result__.isNull()) {
        return E_POINTER.value
    }
    @Expect(valueSize, 2u32)
    let first = unsafe { value.read(0) }
    let second = unsafe { value.read(1) }
    @Expect(first.X, 1.0f32)
    @Expect(first.Y, 2.0f32)
    @Expect(first.Width, 3.0f32)
    @Expect(first.Height, 4.0f32)
    @Expect(second.X, 5.0f32)
    @Expect(second.Y, 6.0f32)
    @Expect(second.Width, 7.0f32)
    @Expect(second.Height, 8.0f32)
    unsafe { result__.write(CPointer<Unit>()) }
    propertyValueArrayRectCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueCreateStringArrayThunk(
    _: CPointer<Unit>,
    valueSize: UInt32,
    value: CPointer<CPointer<Unit>>,
    result__: CPointer<CPointer<Unit>>
): Int32 {
    if (value.isNull() || result__.isNull()) {
        return E_POINTER.value
    }
    @Expect(valueSize, 3u32)
    let first = windows_core.HString.fromSystemHandleCopy(unsafe { value.read(0) })
    let second = windows_core.HString.fromSystemHandleCopy(unsafe { value.read(1) })
    let third = windows_core.HString.fromSystemHandleCopy(unsafe { value.read(2) })
    try {
        @Expect(first.get(), "alpha")
        @Expect(second.get(), "")
        @Expect(third.get(), "omega")
    } finally {
        first.close()
        second.close()
        third.close()
    }
    unsafe { result__.write(CPointer<Unit>()) }
    propertyValueArrayStringCalls.fetchAdd(1)
    S_OK.value
}

@C
func propertyValueCreateInspectableArrayThunk(
    _: CPointer<Unit>,
    valueSize: UInt32,
    value: CPointer<CPointer<Unit>>,
    result__: CPointer<CPointer<Unit>>
): Int32 {
    if (value.isNull() || result__.isNull()) {
        return E_POINTER.value
    }
    @Expect(valueSize, 3u32)
    let first = unsafe { value.read(0) }
    let second = unsafe { value.read(1) }
    let third = unsafe { value.read(2) }
    @Expect(first.isNotNull(), true)
    @Expect(second.isNull(), true)
    @Expect(third.isNotNull(), true)
    unsafe { result__.write(CPointer<Unit>()) }
    propertyValueArrayInspectableCalls.fetchAdd(1)
    S_OK.value
}

func propertyValueArrayOverloadVtbl(): IPropertyValueStaticsVtbl {
    var vtbl = IPropertyValueStaticsVtbl()
    vtbl.CreateInt32Array = propertyValueCreateInt32ArrayThunk
    vtbl.CreateGuidArray = propertyValueCreateGuidArrayThunk
    vtbl.CreateDateTimeArray = propertyValueCreateDateTimeArrayThunk
    vtbl.CreateRectArray = propertyValueCreateRectArrayThunk
    vtbl.CreateStringArray = propertyValueCreateStringArrayThunk
    vtbl.CreateInspectableArray = propertyValueCreateInspectableArrayThunk
    vtbl
}

func withPropertyValueArrayOverloadRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IPropertyValueStaticsVtbl>(1, { _ => propertyValueArrayOverloadVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IPropertyValueStaticsVtbl>>(1, { _ => vtblHandle.pointer })) }
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

func withPropertyValueInspectableArrayInputs(action: (IInspectable, IInspectable) -> Unit): Unit {
    let firstHandle = unsafe { acquireArrayRawData(Array<CPointer<Unit>>(1, { _ => CPointer<Unit>() })) }
    let secondHandle = unsafe { acquireArrayRawData(Array<CPointer<Unit>>(1, { _ => CPointer<Unit>() })) }

    try {
        action(IInspectable.viewOf(CPointer<Unit>(firstHandle.pointer)), IInspectable.viewOf(CPointer<Unit>(secondHandle.pointer)))
    } finally {
        unsafe {
            releaseArrayRawData(secondHandle)
            releaseArrayRawData(firstHandle)
        }
    }
}

@Test
func testPropertyValueStaticsCreateArrayOverloadsStagePrimitiveArrays() {
    propertyValueArrayInt32Calls.store(0)
    withPropertyValueArrayOverloadRaw({ raw: CPointer<Unit> =>
        let statics = IPropertyValueStatics.viewOf(raw)
        let values: Array<Int32> = [10i32, 20i32, 30i32]

        let _ = unsafe { statics.CreateInt32Array(values) }

        @Expect(propertyValueArrayInt32Calls.load(), 1)
    })
}

@Test
func testPropertyValueStaticsCreateArrayOverloadsProjectCopyStructArrays() {
    propertyValueArrayGuidCalls.store(0)
    propertyValueArrayDateTimeCalls.store(0)
    propertyValueArrayRectCalls.store(0)

    withPropertyValueArrayOverloadRaw({ raw: CPointer<Unit> =>
        let statics = IPropertyValueStatics.viewOf(raw)
        let guidValues = [
            GuidValue.fromRaw(propertyValueArrayGuidExpected(1u32)),
            GuidValue.fromRaw(propertyValueArrayGuidExpected(2u32))
        ]
        let dateTimeValues = [
            propertyValueArrayDateTime(111i64),
            propertyValueArrayDateTime(222i64)
        ]
        let rectValues = [
            propertyValueArrayRect(1.0f32, 2.0f32, 3.0f32, 4.0f32),
            propertyValueArrayRect(5.0f32, 6.0f32, 7.0f32, 8.0f32)
        ]

        let _ = unsafe { statics.CreateGuidArray(guidValues) }
        let _ = unsafe { statics.CreateDateTimeArray(dateTimeValues) }
        let _ = unsafe { statics.CreateRectArray(rectValues) }

        @Expect(propertyValueArrayGuidCalls.load(), 1)
        @Expect(propertyValueArrayDateTimeCalls.load(), 1)
        @Expect(propertyValueArrayRectCalls.load(), 1)
    })
}

@Test
func testPropertyValueStaticsCreateArrayOverloadsStageStringArrayHandles() {
    propertyValueArrayStringCalls.store(0)
    withPropertyValueArrayOverloadRaw({ raw: CPointer<Unit> =>
        let statics = IPropertyValueStatics.viewOf(raw)
        let first = windows_core.HString("alpha")
        let second = windows_core.HString()
        let third = windows_core.HString("omega")
        let createBefore = windows_core.debugObservedWindowsCreateStringCount()
        let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
        try {
            let _ = unsafe { statics.CreateStringArray([first, second, third]) }
        } finally {
            first.close()
            second.close()
            third.close()
        }

        @Expect(propertyValueArrayStringCalls.load(), 1)
        @Expect(windows_core.debugObservedWindowsCreateStringCount() - createBefore >= 2, true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore >= 2, true)
    })
}

@Test
func testPropertyValueStaticsCreateArrayOverloadsStageInspectableOptionArray() {
    propertyValueArrayInspectableCalls.store(0)
    withPropertyValueArrayOverloadRaw({ raw: CPointer<Unit> =>
        let statics = IPropertyValueStatics.viewOf(raw)
        withPropertyValueInspectableArrayInputs({ first: IInspectable, third: IInspectable =>
            let values: Array<Option<IInspectable>> = [Some(first), None, Some(third)]

            let _ = unsafe { statics.CreateInspectableArray(values) }

            @Expect(propertyValueArrayInspectableCalls.load(), 1)
        })
    })
}
