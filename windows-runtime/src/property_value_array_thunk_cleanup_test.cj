package windows_runtime

import std.sync.{AtomicBool, AtomicInt64}
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOTIMPL, GuidValue, Result, WinError}
import windows_core as windows_core
import windows_interface as windows_interface
import windows_interface.{GUID, IInspectable}

let propertyValueArrayThunkFailingUInt16Calls = AtomicInt64(0)
let propertyValueArrayThunkFailingStringCalls = AtomicInt64(0)
let propertyValueArrayThunkFailingInspectableCalls = AtomicInt64(0)
let propertyValueArrayThunkInspectableReleaseCalls = AtomicInt64(0)
let propertyValueArrayThunkWritePartialOutputs = AtomicBool(true)
let propertyValueArrayThunkWritePartialSizes = AtomicBool(true)

func propertyValueArrayThunkNotImpl<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_NOTIMPL))
}

func propertyValueArrayThunkFail<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_FAIL))
}

func allocatePropertyValueArrayThunkData<T>(length: Int64): CPointer<T> where T <: CType {
    CPointer<T>(windows_core.coTaskMemAlloc(sizeOf<T>() * UIntNative(length)))
}

func propertyValueArrayThunkSystemString(value: String): CPointer<Unit> {
    let text = windows_core.HString(value)
    var raw = CPointer<Unit>()
    try {
        raw = text.toSystemHandleCopy()
    } finally {
        text.close()
    }
    raw
}

@C
func propertyValueArrayThunkInspectableReleaseThunk(raw: CPointer<Unit>): UInt32 {
    let oldCount = propertyValueArrayThunkInspectableReleaseCalls.fetchAdd(1)
    windows_core.coTaskMemFree(raw)
    UInt32(oldCount + 1)
}

func propertyValueArrayThunkInspectableObject(vtbl: CPointer<windows_interface.IUnknownVtbl>): CPointer<Unit> {
    let raw = windows_core.coTaskMemAlloc(sizeOf<CPointer<windows_interface.IUnknownVtbl>>())
    if (raw.isNull()) {
        return CPointer<Unit>()
    }
    unsafe { CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw).write(vtbl) }
    raw
}

open class FailingPropertyValueArrayThunkImpl <: IPropertyValue_Impl {
    private let inspectableVtbl: CPointer<windows_interface.IUnknownVtbl>

    public init(inspectableVtbl: CPointer<windows_interface.IUnknownVtbl>) {
        this.inspectableVtbl = inspectableVtbl
    }

    public func Type(): Result<PropertyType> { propertyValueArrayThunkNotImpl<PropertyType>() }
    public func IsNumericScalar(): Result<Bool> { propertyValueArrayThunkNotImpl<Bool>() }
    public func GetUInt8(): Result<UInt8> { propertyValueArrayThunkNotImpl<UInt8>() }
    public func GetInt16(): Result<Int16> { propertyValueArrayThunkNotImpl<Int16>() }
    public func GetUInt16(): Result<UInt16> { propertyValueArrayThunkNotImpl<UInt16>() }
    public func GetInt32(): Result<Int32> { propertyValueArrayThunkNotImpl<Int32>() }
    public func GetUInt32(): Result<UInt32> { propertyValueArrayThunkNotImpl<UInt32>() }
    public func GetInt64(): Result<Int64> { propertyValueArrayThunkNotImpl<Int64>() }
    public func GetUInt64(): Result<UInt64> { propertyValueArrayThunkNotImpl<UInt64>() }
    public func GetSingle(): Result<Float32> { propertyValueArrayThunkNotImpl<Float32>() }
    public func GetDouble(): Result<Float64> { propertyValueArrayThunkNotImpl<Float64>() }
    public func GetChar16(): Result<UInt16> { propertyValueArrayThunkNotImpl<UInt16>() }
    public func GetBoolean(): Result<Bool> { propertyValueArrayThunkNotImpl<Bool>() }
    public func GetString(): Result<windows_core.HString> { propertyValueArrayThunkNotImpl<windows_core.HString>() }
    public func GetGuid(): Result<GuidValue> { propertyValueArrayThunkNotImpl<GuidValue>() }
    public func GetDateTime(): Result<DateTime> { propertyValueArrayThunkNotImpl<DateTime>() }
    public func GetTimeSpan(): Result<TimeSpan> { propertyValueArrayThunkNotImpl<TimeSpan>() }
    public func GetPoint(): Result<Point> { propertyValueArrayThunkNotImpl<Point>() }
    public func GetSize(): Result<Size> { propertyValueArrayThunkNotImpl<Size>() }
    public func GetRect(): Result<Rect> { propertyValueArrayThunkNotImpl<Rect>() }

    public func GetUInt8Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt8>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetInt16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int16>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetUInt16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt16>>): Result<Unit> {
        let data = allocatePropertyValueArrayThunkData<UInt16>(2)
        unsafe {
            data.write(11u16)
            (data + 1).write(22u16)
            valueSize.write(2u32)
            value.write(data)
        }
        propertyValueArrayThunkFailingUInt16Calls.fetchAdd(1)
        propertyValueArrayThunkFail<Unit>()
    }

    public func GetInt32Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int32>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetUInt32Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt32>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetInt64Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int64>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetUInt64Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt64>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetSingleArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Float32>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetDoubleArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Float64>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetChar16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt16>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetBooleanArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Bool>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetStringArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<CPointer<Unit>>>): Result<Unit> {
        if (!propertyValueArrayThunkWritePartialOutputs.load()) {
            let _ = valueSize
            let _ = value
            return propertyValueArrayThunkFail<Unit>()
        }
        let data = allocatePropertyValueArrayThunkData<CPointer<Unit>>(2)
        unsafe {
            data.write(propertyValueArrayThunkSystemString("left"))
            (data + 1).write(propertyValueArrayThunkSystemString("right"))
            if (propertyValueArrayThunkWritePartialSizes.load()) {
                valueSize.write(2u32)
            }
            value.write(data)
        }
        propertyValueArrayThunkFailingStringCalls.fetchAdd(1)
        propertyValueArrayThunkFail<Unit>()
    }

    public func GetInspectableArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<CPointer<Unit>>>): Result<Unit> {
        if (!propertyValueArrayThunkWritePartialOutputs.load()) {
            let _ = valueSize
            let _ = value
            return propertyValueArrayThunkFail<Unit>()
        }
        let data = allocatePropertyValueArrayThunkData<CPointer<Unit>>(2)
        let first = propertyValueArrayThunkInspectableObject(inspectableVtbl)
        let second = propertyValueArrayThunkInspectableObject(inspectableVtbl)
        unsafe {
            data.write(first)
            (data + 1).write(second)
            if (propertyValueArrayThunkWritePartialSizes.load()) {
                valueSize.write(2u32)
            }
            value.write(data)
        }
        propertyValueArrayThunkFailingInspectableCalls.fetchAdd(1)
        propertyValueArrayThunkFail<Unit>()
    }

    public func GetGuidArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<GUID>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetDateTimeArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<DateTimeAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetTimeSpanArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<TimeSpanAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetPointArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<PointAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetSizeArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<SizeAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }

    public func GetRectArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<RectAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        propertyValueArrayThunkNotImpl<Unit>()
    }
}

class FailingReferenceArrayPropertyValueArrayThunkImpl <: FailingPropertyValueArrayThunkImpl & IReferenceArray_Impl<Int32> {
    public init(inspectableVtbl: CPointer<windows_interface.IUnknownVtbl>) {
        super(inspectableVtbl)
    }

    public func Value(): Result<(UInt32, CPointer<Unit>)> {
        propertyValueArrayThunkFail<(UInt32, CPointer<Unit>)>()
    }
}

@Test
func testIPropertyValueArrayThunksCleanFailedPartialOutputs() {
    propertyValueArrayThunkWritePartialOutputs.store(true)
    propertyValueArrayThunkFailingUInt16Calls.store(0)
    propertyValueArrayThunkFailingStringCalls.store(0)
    propertyValueArrayThunkFailingInspectableCalls.store(0)
    propertyValueArrayThunkInspectableReleaseCalls.store(0)

    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    try {
        let impl = FailingPropertyValueArrayThunkImpl(vtblHandle)

        var primitiveSize = 99u32
        var primitiveData = CPointer<UInt16>()
        let primitiveHr = impl.__winrtThunk_GetUInt16Array(
            CPointer<UInt32>(inout primitiveSize),
            CPointer<CPointer<UInt16>>(inout primitiveData)
        )
        @Expect(primitiveHr, E_FAIL.value)
        @Expect(primitiveSize, 0u32)
        @Expect(primitiveData.isNull(), true)
        @Expect(propertyValueArrayThunkFailingUInt16Calls.load(), 1)

        var stringSize = 99u32
        var stringData = CPointer<CPointer<Unit>>()
        let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
        let stringHr = impl.__winrtThunk_GetStringArray(
            CPointer<UInt32>(inout stringSize),
            CPointer<CPointer<CPointer<Unit>>>(inout stringData)
        )
        @Expect(stringHr, E_FAIL.value)
        @Expect(stringSize, 0u32)
        @Expect(stringData.isNull(), true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 2)
        @Expect(propertyValueArrayThunkFailingStringCalls.load(), 1)

        var inspectableSize = 99u32
        var inspectableData = CPointer<CPointer<Unit>>()
        let inspectableHr = impl.__winrtThunk_GetInspectableArray(
            CPointer<UInt32>(inout inspectableSize),
            CPointer<CPointer<CPointer<Unit>>>(inout inspectableData)
        )
        @Expect(inspectableHr, E_FAIL.value)
        @Expect(inspectableSize, 0u32)
        @Expect(inspectableData.isNull(), true)
        @Expect(propertyValueArrayThunkInspectableReleaseCalls.load(), 2)
        @Expect(propertyValueArrayThunkFailingInspectableCalls.load(), 1)
    } finally {
        propertyValueArrayThunkWritePartialOutputs.store(true)
        propertyValueArrayThunkWritePartialSizes.store(true)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}

@Test
func testIPropertyValueArrayThunksCleanFailedPartialOutputsWithoutReturnedSize() {
    propertyValueArrayThunkWritePartialOutputs.store(true)
    propertyValueArrayThunkWritePartialSizes.store(false)
    propertyValueArrayThunkFailingStringCalls.store(0)
    propertyValueArrayThunkFailingInspectableCalls.store(0)
    propertyValueArrayThunkInspectableReleaseCalls.store(0)

    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    try {
        let impl = FailingPropertyValueArrayThunkImpl(vtblHandle)

        var stringSize = 99u32
        var stringData = CPointer<CPointer<Unit>>()
        let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
        let stringHr = impl.__winrtThunk_GetStringArray(
            CPointer<UInt32>(inout stringSize),
            CPointer<CPointer<CPointer<Unit>>>(inout stringData)
        )
        @Expect(stringHr, E_FAIL.value)
        @Expect(stringSize, 0u32)
        @Expect(stringData.isNull(), true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 2)
        @Expect(propertyValueArrayThunkFailingStringCalls.load(), 1)

        var inspectableSize = 99u32
        var inspectableData = CPointer<CPointer<Unit>>()
        let inspectableHr = impl.__winrtThunk_GetInspectableArray(
            CPointer<UInt32>(inout inspectableSize),
            CPointer<CPointer<CPointer<Unit>>>(inout inspectableData)
        )
        @Expect(inspectableHr, E_FAIL.value)
        @Expect(inspectableSize, 0u32)
        @Expect(inspectableData.isNull(), true)
        @Expect(propertyValueArrayThunkInspectableReleaseCalls.load(), 2)
        @Expect(propertyValueArrayThunkFailingInspectableCalls.load(), 1)
    } finally {
        propertyValueArrayThunkWritePartialOutputs.store(true)
        propertyValueArrayThunkWritePartialSizes.store(true)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}

@Test
func testIPropertyValueArrayThunksClearStaleOutputsBeforeNoWriteFailure() {
    propertyValueArrayThunkWritePartialOutputs.store(false)
    propertyValueArrayThunkInspectableReleaseCalls.store(0)

    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    let staleStringArray = allocatePropertyValueArrayThunkData<CPointer<Unit>>(1)
    let staleStringRaw = propertyValueArrayThunkSystemString("stale")
    let staleInspectableArray = allocatePropertyValueArrayThunkData<CPointer<Unit>>(1)
    let staleInspectableRaw = propertyValueArrayThunkInspectableObject(vtblHandle)
    unsafe {
        staleStringArray.write(staleStringRaw)
        staleInspectableArray.write(staleInspectableRaw)
    }

    try {
        let impl = FailingPropertyValueArrayThunkImpl(vtblHandle)

        var stringSize = 1u32
        var stringData = staleStringArray
        let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
        let stringHr = impl.__winrtThunk_GetStringArray(
            CPointer<UInt32>(inout stringSize),
            CPointer<CPointer<CPointer<Unit>>>(inout stringData)
        )
        @Expect(stringHr, E_FAIL.value)
        @Expect(stringSize, 0u32)
        @Expect(stringData.isNull(), true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 0)

        var inspectableSize = 1u32
        var inspectableData = staleInspectableArray
        let inspectableHr = impl.__winrtThunk_GetInspectableArray(
            CPointer<UInt32>(inout inspectableSize),
            CPointer<CPointer<CPointer<Unit>>>(inout inspectableData)
        )
        @Expect(inspectableHr, E_FAIL.value)
        @Expect(inspectableSize, 0u32)
        @Expect(inspectableData.isNull(), true)
        @Expect(propertyValueArrayThunkInspectableReleaseCalls.load(), 0)
    } finally {
        let staleString = windows_core.HString.fromSystemHandleTake(staleStringRaw)
        staleString.close()
        if (staleInspectableRaw.isNotNull()) {
            windows_core.coTaskMemFree(staleInspectableRaw)
        }
        windows_core.coTaskMemFree(CPointer<Unit>(staleStringArray))
        windows_core.coTaskMemFree(CPointer<Unit>(staleInspectableArray))
        propertyValueArrayThunkWritePartialOutputs.store(true)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}

@Test
func testIPropertyValueStringThunkClearsStaleOutputBeforeNoWriteFailure() {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    let staleRaw = propertyValueArrayThunkSystemString("stale-string")
    var result = staleRaw
    let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()

    try {
        let impl = FailingPropertyValueArrayThunkImpl(vtblHandle)
        let hr = impl.__winrtThunk_GetString(CPointer<CPointer<Unit>>(inout result))

        @Expect(hr, E_NOTIMPL.value)
        @Expect(result.isNull(), true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 0)
    } finally {
        windows_core.releaseSystemHStringHandle(staleRaw)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}

@Test
func testInheritedPropertyValueArrayThunkClearsStaleOutputBeforeNoWriteFailure() {
    propertyValueArrayThunkWritePartialOutputs.store(false)
    propertyValueArrayThunkInspectableReleaseCalls.store(0)

    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    let staleArray = allocatePropertyValueArrayThunkData<CPointer<Unit>>(1)
    let staleRaw = propertyValueArrayThunkInspectableObject(vtblHandle)
    unsafe { staleArray.write(staleRaw) }

    try {
        let impl = FailingReferenceArrayPropertyValueArrayThunkImpl(vtblHandle)
        var size = 1u32
        var data = staleArray

        let hr = impl.__winrtThunk_GetInspectableArray(
            CPointer<UInt32>(inout size),
            CPointer<CPointer<CPointer<Unit>>>(inout data)
        )

        @Expect(hr, E_FAIL.value)
        @Expect(size, 0u32)
        @Expect(data.isNull(), true)
        @Expect(propertyValueArrayThunkInspectableReleaseCalls.load(), 0)
    } finally {
        if (staleRaw.isNotNull()) {
            windows_core.coTaskMemFree(staleRaw)
        }
        windows_core.coTaskMemFree(CPointer<Unit>(staleArray))
        propertyValueArrayThunkWritePartialOutputs.store(true)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}
