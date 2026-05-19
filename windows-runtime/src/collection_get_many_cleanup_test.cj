package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOTIMPL, HString, InParam, Result, WindowsException, WinError}
import windows_core as windows_core
import windows_interface as windows_interface

@C
func failingIteratorGetManyHString(
    instanceRaw: CPointer<Unit>,
    itemsSize: UInt32,
    items: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    let _ = instanceRaw
    if (itemsSize == 0u32 || items.isNull() || result.isNull()) {
        return E_FAIL.value
    }
    let value = HString("iterator-partial")
    let raw = value.toSystemHandleCopy()
    value.close()
    unsafe {
        CPointer<CPointer<Unit>>(items).write(raw)
        result.write(1u32)
    }
    E_FAIL.value
}

@C
func noWriteFailingIteratorGetManyHString(
    instanceRaw: CPointer<Unit>,
    itemsSize: UInt32,
    items: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    let _ = instanceRaw
    if (itemsSize == 0u32 || items.isNull() || result.isNull()) {
        return E_FAIL.value
    }
    unsafe { result.write(1u32) }
    E_FAIL.value
}

@C
func failingIteratorGetManyHStringWithoutCount(
    instanceRaw: CPointer<Unit>,
    itemsSize: UInt32,
    items: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    let _ = instanceRaw
    if (itemsSize == 0u32 || items.isNull() || result.isNull()) {
        return E_FAIL.value
    }
    let value = HString("iterator-partial-no-count")
    let raw = value.toSystemHandleCopy()
    value.close()
    unsafe { CPointer<CPointer<Unit>>(items).write(raw) }
    E_FAIL.value
}

@C
func failingVectorGetManyHString(
    instanceRaw: CPointer<Unit>,
    startIndex: UInt32,
    itemsSize: UInt32,
    items: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    let _ = startIndex
    unsafe { failingIteratorGetManyHString(instanceRaw, itemsSize, items, result) }
}

@C
func noWriteFailingVectorGetManyHString(
    instanceRaw: CPointer<Unit>,
    startIndex: UInt32,
    itemsSize: UInt32,
    items: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    let _ = startIndex
    unsafe { noWriteFailingIteratorGetManyHString(instanceRaw, itemsSize, items, result) }
}

@C
func failingVectorGetManyHStringWithoutCount(
    instanceRaw: CPointer<Unit>,
    startIndex: UInt32,
    itemsSize: UInt32,
    items: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    let _ = startIndex
    unsafe { failingIteratorGetManyHStringWithoutCount(instanceRaw, itemsSize, items, result) }
}

func withIteratorGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IIteratorVtbl()
    vtbl.GetMany = failingIteratorGetManyHString
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IIteratorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IIteratorVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withNoWriteFailingIteratorGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IIteratorVtbl()
    vtbl.GetMany = noWriteFailingIteratorGetManyHString
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IIteratorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IIteratorVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withNoCountFailingIteratorGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IIteratorVtbl()
    vtbl.GetMany = failingIteratorGetManyHStringWithoutCount
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IIteratorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IIteratorVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withVectorViewGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IVectorViewVtbl()
    vtbl.GetMany = failingVectorGetManyHString
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorViewVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorViewVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withNoWriteFailingVectorViewGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IVectorViewVtbl()
    vtbl.GetMany = noWriteFailingVectorGetManyHString
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorViewVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorViewVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withNoCountFailingVectorViewGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IVectorViewVtbl()
    vtbl.GetMany = failingVectorGetManyHStringWithoutCount
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorViewVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorViewVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withVectorGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IVectorVtbl()
    vtbl.GetMany = failingVectorGetManyHString
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withNoCountFailingVectorGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IVectorVtbl()
    vtbl.GetMany = failingVectorGetManyHStringWithoutCount
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func withNoWriteFailingVectorGetManyRaw(action: (CPointer<Unit>) -> Unit): Unit {
    var vtbl = IVectorVtbl()
    vtbl.GetMany = noWriteFailingVectorGetManyHString
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorVtbl>>(vtblHandle) }
    try {
        action(CPointer<Unit>(objectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

func assertFailedGetManyReleasesHStringSlot(action: (CPointer<Unit>) -> UInt32): Unit {
    let buffer = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe {
        slots.write(CPointer<Unit>())
        (slots + 1).write(CPointer<Unit>())
    }
    let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
    try {
        var failed = false
        try {
            let count = action(buffer)
            let _ = count
        } catch (_: WindowsException) {
            failed = true
        }
        @Expect(failed, true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        let remaining = unsafe { slots.read() }
        if (remaining.isNotNull()) {
            windows_core.releaseSystemHStringHandle(remaining)
        }
        windows_core.coTaskMemFree(buffer)
    }
}

func assertFailedGetManyClearsStaleHStringSlot(action: (CPointer<Unit>) -> UInt32): Unit {
    let buffer = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    let stale = HString("stale-get-many")
    let staleRaw = stale.toSystemHandleCopy()
    stale.close()
    unsafe {
        slots.write(staleRaw)
        (slots + 1).write(CPointer<Unit>())
    }
    let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
    try {
        var failed = false
        try {
            let count = action(buffer)
            let _ = count
        } catch (_: WindowsException) {
            failed = true
        }
        @Expect(failed, true)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 0)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        windows_core.releaseSystemHStringHandle(staleRaw)
        windows_core.coTaskMemFree(buffer)
    }
}

func failedProducerGetManyHString(items: CPointer<Unit>, writeOutput: Bool): Result<UInt32> {
    if (writeOutput && items.isNotNull()) {
        let value = HString("producer-partial")
        let raw = value.toSystemHandleCopy()
        value.close()
        unsafe { CPointer<CPointer<Unit>>(items).write(raw) }
    }
    Result<UInt32>.Err(WinError.fromHRESULT(E_FAIL))
}

class FailingProducerIteratorGetManyImpl <: IIterator_Impl<HString> {
    private let writeOutput: Bool

    public init(writeOutput: Bool) {
        this.writeOutput = writeOutput
    }

    public func Current(): Result<HString> {
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func HasCurrent(): Result<Bool> {
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func MoveNext(): Result<Bool> {
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetMany(itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = itemsSize
        failedProducerGetManyHString(items, writeOutput)
    }
}

class FailingProducerVectorViewGetManyImpl <: IVectorView_Impl<HString> {
    private let writeOutput: Bool

    public init(writeOutput: Bool) {
        this.writeOutput = writeOutput
    }

    public func GetAt(index: UInt32): Result<HString> {
        let _ = index
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func IndexOf(value: HString, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        let _ = index
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = itemsSize
        failedProducerGetManyHString(items, writeOutput)
    }

    public func First(): Result<IIterator<HString>> {
        Result<IIterator<HString>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerVectorGetManyImpl <: IVector_Impl<HString> {
    private let writeOutput: Bool

    public init(writeOutput: Bool) {
        this.writeOutput = writeOutput
    }

    public func GetAt(index: UInt32): Result<HString> {
        let _ = index
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetView(): Result<IVectorView<HString>> {
        Result<IVectorView<HString>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func IndexOf(value: HString, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        let _ = index
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func SetAt(index: UInt32, value: HString): Result<Unit> {
        let _ = index
        let _ = value
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func InsertAt(index: UInt32, value: HString): Result<Unit> {
        let _ = index
        let _ = value
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Append(value: HString): Result<Unit> {
        let _ = value
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func RemoveAtEnd(): Result<Unit> {
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = itemsSize
        failedProducerGetManyHString(items, writeOutput)
    }

    public func ReplaceAll(itemsSize: UInt32, items: CPointer<Unit>): Result<Unit> {
        let _ = itemsSize
        let _ = items
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func First(): Result<IIterator<HString>> {
        Result<IIterator<HString>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerObservableVectorGetManyImpl <: IObservableVector_Impl<HString> {
    private let writeOutput: Bool

    public init(writeOutput: Bool) {
        this.writeOutput = writeOutput
    }

    public func VectorChanged(vhnd: InParam<VectorChangedEventHandler<HString>>): Result<EventRegistrationToken> {
        let _ = vhnd
        Result<EventRegistrationToken>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func RemoveVectorChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetAt(index: UInt32): Result<HString> {
        let _ = index
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetView(): Result<IVectorView<HString>> {
        Result<IVectorView<HString>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func IndexOf(value: HString, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        let _ = index
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func SetAt(index: UInt32, value: HString): Result<Unit> {
        let _ = index
        let _ = value
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func InsertAt(index: UInt32, value: HString): Result<Unit> {
        let _ = index
        let _ = value
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Append(value: HString): Result<Unit> {
        let _ = value
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func RemoveAtEnd(): Result<Unit> {
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = itemsSize
        failedProducerGetManyHString(items, writeOutput)
    }

    public func ReplaceAll(itemsSize: UInt32, items: CPointer<Unit>): Result<Unit> {
        let _ = itemsSize
        let _ = items
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func First(): Result<IIterator<HString>> {
        Result<IIterator<HString>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

func assertProducerGetManyThunkReleasesFailedPartialOutput(action: (CPointer<Unit>, CPointer<UInt32>) -> Int32): Unit {
    let buffer = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe {
        slots.write(CPointer<Unit>())
        (slots + 1).write(CPointer<Unit>())
    }
    var result = 123u32
    let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
    try {
        let hr = action(buffer, CPointer<UInt32>(inout result))
        @Expect(hr, E_FAIL.value)
        @Expect(result, 0u32)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        let remaining = unsafe { slots.read() }
        if (remaining.isNotNull()) {
            windows_core.releaseSystemHStringHandle(remaining)
        }
        windows_core.coTaskMemFree(buffer)
    }
}

func assertProducerGetManyThunkClearsStaleSlotBeforeNoWriteFailure(action: (CPointer<Unit>, CPointer<UInt32>) -> Int32): Unit {
    let buffer = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    let stale = HString("producer-stale")
    let staleRaw = stale.toSystemHandleCopy()
    stale.close()
    unsafe {
        slots.write(staleRaw)
        (slots + 1).write(CPointer<Unit>())
    }
    var result = 123u32
    let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
    try {
        let hr = action(buffer, CPointer<UInt32>(inout result))
        @Expect(hr, E_FAIL.value)
        @Expect(result, 0u32)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 0)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        windows_core.releaseSystemHStringHandle(staleRaw)
        windows_core.coTaskMemFree(buffer)
    }
}

func assertProducerSingleOutThunkClearsStaleSlotBeforeFailure(action: (CPointer<CPointer<Unit>>) -> Int32): Unit {
    let stale = HString("producer-single-stale")
    let staleRaw = stale.toSystemHandleCopy()
    stale.close()
    var result = staleRaw
    let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
    try {
        let hr = action(CPointer<CPointer<Unit>>(inout result))
        @Expect(hr, E_NOTIMPL.value)
        @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 0)
        @Expect(result.isNull(), true)
    } finally {
        windows_core.releaseSystemHStringHandle(staleRaw)
    }
}

@When[os == "Windows"]
@Test
func testIIteratorGetManyClearsStaleSlotsBeforeNoWriteFailure() {
    withNoWriteFailingIteratorGetManyRaw({ raw: CPointer<Unit> =>
        let iterator = IIterator<HString>.viewOf(raw)
        assertFailedGetManyClearsStaleHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { iterator.GetMany(2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIVectorViewGetManyClearsStaleSlotsBeforeNoWriteFailure() {
    withNoWriteFailingVectorViewGetManyRaw({ raw: CPointer<Unit> =>
        let view = IVectorView<HString>.viewOf(raw)
        assertFailedGetManyClearsStaleHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { view.GetMany(0u32, 2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIVectorGetManyClearsStaleSlotsBeforeNoWriteFailure() {
    withNoWriteFailingVectorGetManyRaw({ raw: CPointer<Unit> =>
        let vector = IVector<HString>.viewOf(raw)
        assertFailedGetManyClearsStaleHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { vector.GetMany(0u32, 2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIIteratorGetManyReleasesFailedPartialOutputs() {
    withIteratorGetManyRaw({ raw: CPointer<Unit> =>
        let iterator = IIterator<HString>.viewOf(raw)
        assertFailedGetManyReleasesHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { iterator.GetMany(2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIIteratorGetManyReleasesFailedPartialOutputsWithoutReturnedCount() {
    withNoCountFailingIteratorGetManyRaw({ raw: CPointer<Unit> =>
        let iterator = IIterator<HString>.viewOf(raw)
        assertFailedGetManyReleasesHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { iterator.GetMany(2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIVectorViewGetManyReleasesFailedPartialOutputs() {
    withVectorViewGetManyRaw({ raw: CPointer<Unit> =>
        let view = IVectorView<HString>.viewOf(raw)
        assertFailedGetManyReleasesHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { view.GetMany(0u32, 2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIVectorViewGetManyReleasesFailedPartialOutputsWithoutReturnedCount() {
    withNoCountFailingVectorViewGetManyRaw({ raw: CPointer<Unit> =>
        let view = IVectorView<HString>.viewOf(raw)
        assertFailedGetManyReleasesHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { view.GetMany(0u32, 2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIVectorGetManyReleasesFailedPartialOutputs() {
    withVectorGetManyRaw({ raw: CPointer<Unit> =>
        let vector = IVector<HString>.viewOf(raw)
        assertFailedGetManyReleasesHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { vector.GetMany(0u32, 2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIVectorGetManyReleasesFailedPartialOutputsWithoutReturnedCount() {
    withNoCountFailingVectorGetManyRaw({ raw: CPointer<Unit> =>
        let vector = IVector<HString>.viewOf(raw)
        assertFailedGetManyReleasesHStringSlot({ buffer: CPointer<Unit> =>
            unsafe { vector.GetMany(0u32, 2u32, buffer) }
        })
    })
}

@When[os == "Windows"]
@Test
func testIIteratorProducerGetManyReleasesFailedPartialOutputs() {
    let impl = FailingProducerIteratorGetManyImpl(true)
    assertProducerGetManyThunkReleasesFailedPartialOutput({ buffer: CPointer<Unit>, result: CPointer<UInt32> =>
        impl.__winrtThunk_GetMany(2u32, buffer, result)
    })
}

@When[os == "Windows"]
@Test
func testIIteratorProducerGetManyClearsStaleSlotsBeforeNoWriteFailure() {
    let impl = FailingProducerIteratorGetManyImpl(false)
    assertProducerGetManyThunkClearsStaleSlotBeforeNoWriteFailure({ buffer: CPointer<Unit>, result: CPointer<UInt32> =>
        impl.__winrtThunk_GetMany(2u32, buffer, result)
    })
}

@When[os == "Windows"]
@Test
func testIIteratorProducerCurrentClearsStaleSlotBeforeFailure() {
    let impl = FailingProducerIteratorGetManyImpl(false)
    assertProducerSingleOutThunkClearsStaleSlotBeforeFailure({ result: CPointer<CPointer<Unit>> =>
        impl.__winrtThunk_Current(result)
    })
}

@When[os == "Windows"]
@Test
func testIVectorViewProducerGetManyReleasesFailedPartialOutputs() {
    let impl = FailingProducerVectorViewGetManyImpl(true)
    assertProducerGetManyThunkReleasesFailedPartialOutput({ buffer: CPointer<Unit>, result: CPointer<UInt32> =>
        impl.__winrtThunk_GetMany(0u32, 2u32, buffer, result)
    })
}

@When[os == "Windows"]
@Test
func testIVectorProducerGetManyReleasesFailedPartialOutputs() {
    let impl = FailingProducerVectorGetManyImpl(true)
    assertProducerGetManyThunkReleasesFailedPartialOutput({ buffer: CPointer<Unit>, result: CPointer<UInt32> =>
        impl.__winrtThunk_GetMany(0u32, 2u32, buffer, result)
    })
}

@When[os == "Windows"]
@Test
func testIVectorViewProducerGetAtClearsStaleSlotBeforeFailure() {
    let impl = FailingProducerVectorViewGetManyImpl(false)
    assertProducerSingleOutThunkClearsStaleSlotBeforeFailure({ result: CPointer<CPointer<Unit>> =>
        impl.__winrtThunk_GetAt(0u32, result)
    })
}

@When[os == "Windows"]
@Test
func testIVectorViewProducerFirstClearsStaleSlotBeforeFailure() {
    let impl = FailingProducerVectorViewGetManyImpl(false)
    assertProducerSingleOutThunkClearsStaleSlotBeforeFailure({ result: CPointer<CPointer<Unit>> =>
        impl.__winrtThunk_First(result)
    })
}

@When[os == "Windows"]
@Test
func testIObservableVectorProducerGetManyReleasesFailedPartialOutputs() {
    let impl = FailingProducerObservableVectorGetManyImpl(true)
    assertProducerGetManyThunkReleasesFailedPartialOutput({ buffer: CPointer<Unit>, result: CPointer<UInt32> =>
        impl.__winrtThunk_GetMany(0u32, 2u32, buffer, result)
    })
}
