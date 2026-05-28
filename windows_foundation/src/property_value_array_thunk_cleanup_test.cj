package windows_foundation

import std.sync.{AtomicBool, AtomicInt64}
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOINTERFACE, E_NOTIMPL, E_POINTER, GuidValue, Result, WindowsException}
import windows_core as windows_core
import windows_core.{DateTime, DateTimeAbi, Point, PointAbi, Rect, RectAbi, Size, SizeAbi, TimeSpan, TimeSpanAbi}
import windows_interface as windows_interface
import windows_interface.{GUID, IInspectable}

let propertyValueArrayThunkFailingUInt16Calls = AtomicInt64(0)
let propertyValueArrayThunkFailingStringCalls = AtomicInt64(0)
let propertyValueArrayThunkFailingInspectableCalls = AtomicInt64(0)
let propertyValueArrayThunkInspectableReleaseCalls = AtomicInt64(0)
let propertyValueArrayThunkWritePartialOutputs = AtomicBool(true)
let propertyValueArrayThunkWritePartialSizes = AtomicBool(true)
let propertyValueArrayThunkThrowWindowsAfterPartialOutputs = AtomicBool(false)
let propertyValueArrayThunkThrowPlainAfterPartialOutputs = AtomicBool(false)

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
    public var throwWindowsOnGetString = false
    public var throwPlainOnGetString = false
    public var throwWindowsOnGetGuid = false
    public var throwPlainOnGetPoint = false

    public init(inspectableVtbl: CPointer<windows_interface.IUnknownVtbl>) {
        this.inspectableVtbl = inspectableVtbl
    }

    public func Type(): Result<PropertyType> { foundationTestNotImplemented<PropertyType>() }
    public func IsNumericScalar(): Result<Bool> { foundationTestNotImplemented<Bool>() }
    public func GetUInt8(): Result<UInt8> { foundationTestNotImplemented<UInt8>() }
    public func GetInt16(): Result<Int16> { foundationTestNotImplemented<Int16>() }
    public func GetUInt16(): Result<UInt16> { foundationTestNotImplemented<UInt16>() }
    public func GetInt32(): Result<Int32> { foundationTestNotImplemented<Int32>() }
    public func GetUInt32(): Result<UInt32> { foundationTestNotImplemented<UInt32>() }
    public func GetInt64(): Result<Int64> { foundationTestNotImplemented<Int64>() }
    public func GetUInt64(): Result<UInt64> { foundationTestNotImplemented<UInt64>() }
    public func GetSingle(): Result<Float32> { foundationTestNotImplemented<Float32>() }
    public func GetDouble(): Result<Float64> { foundationTestNotImplemented<Float64>() }
    public func GetChar16(): Result<UInt16> { foundationTestNotImplemented<UInt16>() }
    public func GetBoolean(): Result<Bool> { foundationTestNotImplemented<Bool>() }
    public func GetString(): Result<windows_core.HString> {
        if (throwWindowsOnGetString) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnGetString) {
            throw Exception("GetString failure")
        }
        foundationTestNotImplemented<windows_core.HString>()
    }
    public func GetGuid(): Result<GuidValue> {
        if (throwWindowsOnGetGuid) {
            throw WindowsException(E_POINTER)
        }
        foundationTestNotImplemented<GuidValue>()
    }
    public func GetDateTime(): Result<DateTime> { foundationTestNotImplemented<DateTime>() }
    public func GetTimeSpan(): Result<TimeSpan> { foundationTestNotImplemented<TimeSpan>() }
    public func GetPoint(): Result<Point> {
        if (throwPlainOnGetPoint) {
            throw Exception("GetPoint failure")
        }
        foundationTestNotImplemented<Point>()
    }
    public func GetSize(): Result<Size> { foundationTestNotImplemented<Size>() }
    public func GetRect(): Result<Rect> { foundationTestNotImplemented<Rect>() }

    public func GetUInt8Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt8>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetInt16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int16>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
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
        if (propertyValueArrayThunkThrowWindowsAfterPartialOutputs.load()) {
            throw WindowsException(E_POINTER)
        }
        if (propertyValueArrayThunkThrowPlainAfterPartialOutputs.load()) {
            throw Exception("GetUInt16Array failure")
        }
        foundationTestFail<Unit>()
    }

    public func GetInt32Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int32>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetUInt32Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt32>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetInt64Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int64>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetUInt64Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt64>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetSingleArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Float32>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetDoubleArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Float64>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetChar16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt16>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetBooleanArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Bool>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetStringArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<CPointer<Unit>>>): Result<Unit> {
        if (!propertyValueArrayThunkWritePartialOutputs.load()) {
            let _ = valueSize
            let _ = value
            return foundationTestFail<Unit>()
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
        if (propertyValueArrayThunkThrowWindowsAfterPartialOutputs.load()) {
            throw WindowsException(E_POINTER)
        }
        if (propertyValueArrayThunkThrowPlainAfterPartialOutputs.load()) {
            throw Exception("GetStringArray failure")
        }
        foundationTestFail<Unit>()
    }

    public func GetInspectableArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<CPointer<Unit>>>): Result<Unit> {
        if (!propertyValueArrayThunkWritePartialOutputs.load()) {
            let _ = valueSize
            let _ = value
            return foundationTestFail<Unit>()
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
        if (propertyValueArrayThunkThrowWindowsAfterPartialOutputs.load()) {
            throw WindowsException(E_POINTER)
        }
        if (propertyValueArrayThunkThrowPlainAfterPartialOutputs.load()) {
            throw Exception("GetInspectableArray failure")
        }
        foundationTestFail<Unit>()
    }

    public func GetGuidArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<GUID>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetDateTimeArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<DateTimeAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetTimeSpanArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<TimeSpanAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetPointArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<PointAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetSizeArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<SizeAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }

    public func GetRectArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<RectAbi>>): Result<Unit> {
        let _ = valueSize
        let _ = value
        foundationTestNotImplemented<Unit>()
    }
}

class FailingReferenceArrayPropertyValueArrayThunkImpl <: FailingPropertyValueArrayThunkImpl & IReferenceArray_Impl<Int32> {
    public var throwWindowsOnValue = false
    public var throwPlainOnValue = false

    public init(inspectableVtbl: CPointer<windows_interface.IUnknownVtbl>) {
        super(inspectableVtbl)
    }

    public func Value(): Result<(UInt32, CPointer<Unit>)> {
        if (throwWindowsOnValue) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnValue) {
            throw Exception("IReferenceArray.Value failure")
        }
        foundationTestFail<(UInt32, CPointer<Unit>)>()
    }
}

class FailingReferencePropertyValueScalarThunkImpl <: FailingPropertyValueArrayThunkImpl & IReference_Impl<Float32> {
    public var throwWindowsOnValue = false
    public var throwPlainOnValue = false

    public init(inspectableVtbl: CPointer<windows_interface.IUnknownVtbl>) {
        super(inspectableVtbl)
    }

    public func Value(): Result<Float32> {
        if (throwWindowsOnValue) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnValue) {
            throw Exception("IReference.Value failure")
        }
        foundationTestFail<Float32>()
    }
}

func assertPropertyValueScalarThunksClearStaleOutputs(impl: IPropertyValue_Impl): Unit {
    var propertyType = PropertyTypeAbi(99)
    @Expect(impl.__winrtThunk_Type(CPointer<PropertyTypeAbi>(inout propertyType)), E_NOTIMPL.value)
    @Expect(propertyType.value, 0i32)

    var numeric = true
    @Expect(impl.__winrtThunk_IsNumericScalar(CPointer<Bool>(inout numeric)), E_NOTIMPL.value)
    @Expect(numeric, false)

    var guid = GUID(1u32, 2u16, 3u16, 4u8, 5u8, 6u8, 7u8, 8u8, 9u8, 10u8, 11u8)
    @Expect(impl.__winrtThunk_GetGuid(CPointer<GUID>(inout guid)), E_NOTIMPL.value)
    @Expect(guid.isZero(), true)

    var point = PointAbi()
    point.X = 12.0f32
    point.Y = 34.0f32
    @Expect(impl.__winrtThunk_GetPoint(CPointer<PointAbi>(inout point)), E_NOTIMPL.value)
    @Expect(point.X, 0.0f32)
    @Expect(point.Y, 0.0f32)
}

func assertPropertyValueScalarThunksClearThrownOutputs(impl: FailingPropertyValueArrayThunkImpl): Unit {
    impl.throwWindowsOnGetString = true
    let windowsStaleString = propertyValueArrayThunkSystemString("windows-stale")
    var windowsStringResult = windowsStaleString
    let windowsDeleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
    try {
        @Expect(impl.__winrtThunk_GetString(CPointer<CPointer<Unit>>(inout windowsStringResult)), E_POINTER.value)
        @Expect(windowsStringResult.isNull(), true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - windowsDeleteBefore, 0)
    } finally {
        windows_core.releaseSystemHStringHandle(windowsStaleString)
        impl.throwWindowsOnGetString = false
    }

    impl.throwPlainOnGetString = true
    let plainStaleString = propertyValueArrayThunkSystemString("plain-stale")
    var plainStringResult = plainStaleString
    let plainDeleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
    try {
        @Expect(impl.__winrtThunk_GetString(CPointer<CPointer<Unit>>(inout plainStringResult)), E_FAIL.value)
        @Expect(plainStringResult.isNull(), true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - plainDeleteBefore, 0)
    } finally {
        windows_core.releaseSystemHStringHandle(plainStaleString)
        impl.throwPlainOnGetString = false
    }

    impl.throwWindowsOnGetGuid = true
    var guid = GUID(1u32, 2u16, 3u16, 4u8, 5u8, 6u8, 7u8, 8u8, 9u8, 10u8, 11u8)
    @Expect(impl.__winrtThunk_GetGuid(CPointer<GUID>(inout guid)), E_POINTER.value)
    @Expect(guid.isZero(), true)
    impl.throwWindowsOnGetGuid = false

    impl.throwPlainOnGetPoint = true
    var point = PointAbi()
    point.X = 12.0f32
    point.Y = 34.0f32
    @Expect(impl.__winrtThunk_GetPoint(CPointer<PointAbi>(inout point)), E_FAIL.value)
    @Expect(point.X, 0.0f32)
    @Expect(point.Y, 0.0f32)
    impl.throwPlainOnGetPoint = false
}

func assertPropertyValueArrayThunksCleanThrownPartialOutputs(impl: IPropertyValue_Impl): Unit {
    propertyValueArrayThunkWritePartialOutputs.store(true)
    propertyValueArrayThunkWritePartialSizes.store(true)

    propertyValueArrayThunkThrowWindowsAfterPartialOutputs.store(true)
    propertyValueArrayThunkThrowPlainAfterPartialOutputs.store(false)
    propertyValueArrayThunkFailingUInt16Calls.store(0)
    var primitiveSize = 99u32
    var primitiveData = CPointer<UInt16>()
    let primitiveHr = impl.__winrtThunk_GetUInt16Array(
        CPointer<UInt32>(inout primitiveSize),
        CPointer<CPointer<UInt16>>(inout primitiveData)
    )
    @Expect(primitiveHr, E_POINTER.value)
    @Expect(primitiveSize, 0u32)
    @Expect(primitiveData.isNull(), true)
    @Expect(propertyValueArrayThunkFailingUInt16Calls.load(), 1)

    propertyValueArrayThunkThrowWindowsAfterPartialOutputs.store(false)
    propertyValueArrayThunkThrowPlainAfterPartialOutputs.store(true)
    propertyValueArrayThunkFailingStringCalls.store(0)
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

    propertyValueArrayThunkFailingInspectableCalls.store(0)
    propertyValueArrayThunkInspectableReleaseCalls.store(0)
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

    propertyValueArrayThunkThrowPlainAfterPartialOutputs.store(false)
}

func assertReferenceValueThunksClearOutputsAndTranslateThrownExceptions(
    referenceImpl: FailingReferencePropertyValueScalarThunkImpl,
    referenceArrayImpl: FailingReferenceArrayPropertyValueArrayThunkImpl
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(987i32) }
    try {
        referenceImpl.throwWindowsOnValue = true
        var valueRaw = CPointer<Unit>(sentinel)
        @Expect(
            referenceImpl.__winrtThunk_Value(CPointer<CPointer<Unit>>(inout valueRaw)),
            E_POINTER.value
        )
        @Expect(valueRaw.isNull(), true)
        referenceImpl.throwWindowsOnValue = false

        referenceImpl.throwPlainOnValue = true
        valueRaw = CPointer<Unit>(sentinel)
        @Expect(
            referenceImpl.__winrtThunk_Value(CPointer<CPointer<Unit>>(inout valueRaw)),
            E_FAIL.value
        )
        @Expect(valueRaw.isNull(), true)
        referenceImpl.throwPlainOnValue = false

        referenceArrayImpl.throwWindowsOnValue = true
        var valueSize = 5u32
        var arrayRaw = CPointer<Unit>(sentinel)
        @Expect(
            referenceArrayImpl.__winrtThunk_Value(
                CPointer<UInt32>(inout valueSize),
                CPointer<CPointer<Unit>>(inout arrayRaw)
            ),
            E_POINTER.value
        )
        @Expect(valueSize, 0u32)
        @Expect(arrayRaw.isNull(), true)
        referenceArrayImpl.throwWindowsOnValue = false

        referenceArrayImpl.throwPlainOnValue = true
        valueSize = 5u32
        arrayRaw = CPointer<Unit>(sentinel)
        @Expect(
            referenceArrayImpl.__winrtThunk_Value(
                CPointer<UInt32>(inout valueSize),
                CPointer<CPointer<Unit>>(inout arrayRaw)
            ),
            E_FAIL.value
        )
        @Expect(valueSize, 0u32)
        @Expect(arrayRaw.isNull(), true)
        referenceArrayImpl.throwPlainOnValue = false
    } finally {
        referenceImpl.throwWindowsOnValue = false
        referenceImpl.throwPlainOnValue = false
        referenceArrayImpl.throwWindowsOnValue = false
        referenceArrayImpl.throwPlainOnValue = false
        unsafe { windows_interface.freeNativeValue(sentinel) }
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
func testIPropertyValueArrayThunksCleanThrownPartialOutputs() {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    try {
        let impl = FailingPropertyValueArrayThunkImpl(vtblHandle)
        assertPropertyValueArrayThunksCleanThrownPartialOutputs(impl)
    } finally {
        propertyValueArrayThunkWritePartialOutputs.store(true)
        propertyValueArrayThunkWritePartialSizes.store(true)
        propertyValueArrayThunkThrowWindowsAfterPartialOutputs.store(false)
        propertyValueArrayThunkThrowPlainAfterPartialOutputs.store(false)
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
func testPropertyValueArrayThunksClearSiblingOutSlotsOnPointerFailure() {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(987i32) }
    try {
        let propertyImpl = FailingPropertyValueArrayThunkImpl(vtblHandle)
        var primitiveData = CPointer<UInt16>(sentinel)
        let primitiveNullSizeHr = propertyImpl.__winrtThunk_GetUInt16Array(
            CPointer<UInt32>(),
            CPointer<CPointer<UInt16>>(inout primitiveData)
        )
        @Expect(primitiveNullSizeHr, E_POINTER.value)
        @Expect(primitiveData.isNull(), true)

        var primitiveSize = 7u32
        let primitiveNullDataHr = propertyImpl.__winrtThunk_GetUInt16Array(
            CPointer<UInt32>(inout primitiveSize),
            CPointer<CPointer<UInt16>>()
        )
        @Expect(primitiveNullDataHr, E_POINTER.value)
        @Expect(primitiveSize, 0u32)

        let referenceArrayImpl = FailingReferenceArrayPropertyValueArrayThunkImpl(vtblHandle)
        var referenceData = CPointer<Unit>(sentinel)
        let referenceNullSizeHr = referenceArrayImpl.__winrtThunk_Value(
            CPointer<UInt32>(),
            CPointer<CPointer<Unit>>(inout referenceData)
        )
        @Expect(referenceNullSizeHr, E_POINTER.value)
        @Expect(referenceData.isNull(), true)

        var referenceSize = 9u32
        let referenceNullDataHr = referenceArrayImpl.__winrtThunk_Value(
            CPointer<UInt32>(inout referenceSize),
            CPointer<CPointer<Unit>>()
        )
        @Expect(referenceNullDataHr, E_POINTER.value)
        @Expect(referenceSize, 0u32)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(vtblHandle)
        }
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
func testIPropertyValueScalarThunksClearOutputsAndTranslateThrownExceptions() {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    try {
        let impl = FailingPropertyValueArrayThunkImpl(vtblHandle)
        assertPropertyValueScalarThunksClearStaleOutputs(impl)
        assertPropertyValueScalarThunksClearThrownOutputs(impl)
    } finally {
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}

@Test
func testIPropertyValueVtblNoneBranchClearsScalarStringAndArrayOutputs() {
    let vtbl = IPropertyValueVtbl.new<FailingPropertyValueArrayThunkImpl>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IPropertyValueVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IPropertyValueVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(987i32) }
    let raw = CPointer<Unit>(objectHandle)
    var boolResult = true
    var stringResult = CPointer<Unit>(sentinel)
    var arraySize = 5u32
    var arrayResult = CPointer<UInt16>(CPointer<Unit>(sentinel))

    try {
        let boolHr = unsafe { vtbl.GetBoolean(raw, CPointer<Bool>(inout boolResult)) }
        @Expect(boolHr, E_NOINTERFACE.value)
        @Expect(boolResult, false)

        let stringHr = unsafe { vtbl.GetString(raw, CPointer<CPointer<Unit>>(inout stringResult)) }
        @Expect(stringHr, E_NOINTERFACE.value)
        @Expect(stringResult.isNull(), true)

        let arrayHr = unsafe {
            vtbl.GetUInt16Array(raw, CPointer<UInt32>(inout arraySize), CPointer<CPointer<UInt16>>(inout arrayResult))
        }
        @Expect(arrayHr, E_NOINTERFACE.value)
        @Expect(arraySize, 0u32)
        @Expect(arrayResult.isNull(), true)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

@Test
func testInheritedPropertyValueScalarThunksClearOutputsAndTranslateThrownExceptions() {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    try {
        let referenceImpl = FailingReferencePropertyValueScalarThunkImpl(vtblHandle)
        assertPropertyValueScalarThunksClearStaleOutputs(referenceImpl)
        assertPropertyValueScalarThunksClearThrownOutputs(referenceImpl)

        let referenceArrayImpl = FailingReferenceArrayPropertyValueArrayThunkImpl(vtblHandle)
        assertPropertyValueScalarThunksClearStaleOutputs(referenceArrayImpl)
        assertPropertyValueScalarThunksClearThrownOutputs(referenceArrayImpl)
        assertReferenceValueThunksClearOutputsAndTranslateThrownExceptions(referenceImpl, referenceArrayImpl)
    } finally {
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

@Test
func testInheritedPropertyValueArrayThunksCleanThrownPartialOutputs() {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = propertyValueArrayThunkInspectableReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    try {
        let referenceImpl = FailingReferencePropertyValueScalarThunkImpl(vtblHandle)
        assertPropertyValueArrayThunksCleanThrownPartialOutputs(referenceImpl)

        let referenceArrayImpl = FailingReferenceArrayPropertyValueArrayThunkImpl(vtblHandle)
        assertPropertyValueArrayThunksCleanThrownPartialOutputs(referenceArrayImpl)
    } finally {
        propertyValueArrayThunkWritePartialOutputs.store(true)
        propertyValueArrayThunkWritePartialSizes.store(true)
        propertyValueArrayThunkThrowWindowsAfterPartialOutputs.store(false)
        propertyValueArrayThunkThrowPlainAfterPartialOutputs.store(false)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}
