package windows_collections
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOTIMPL, E_POINTER, EventRegistrationToken, HString, InParam, Result, WinError, WindowsException}
import windows_core as windows_core
import windows_interface as windows_interface

let collectionGenericOutThunkCleanupCalls = AtomicInt64(0)
var collectionGenericOutThunkCleanupRaw = CPointer<Unit>()

struct CollectionGenericOutThunkCleanupProbe <: windows_core.RuntimeType & windows_core.WinrtGenericType<CollectionGenericOutThunkCleanupProbe> {
    public init() {}

    public static func abiType(): String {
        "CollectionGenericOutThunkCleanupProbe"
    }

    public static func signature(): String {
        "test.collection.generic.cleanup"
    }

    public static func winrtOutputBridge(): windows_core.WinrtOutputBridge<CollectionGenericOutThunkCleanupProbe> {
        CollectionGenericOutThunkCleanupBridge()
    }
}

class CollectionGenericOutThunkCleanupBridge <: windows_core.WinrtOutputBridge<CollectionGenericOutThunkCleanupProbe> {
    public init() {}

    public override func storeOut(
        result__: CPointer<CPointer<Unit>>,
        value: CollectionGenericOutThunkCleanupProbe
    ): Int32 {
        let _ = value
        if (result__.isNull()) {
            return E_POINTER.value
        }
        unsafe { result__.write(collectionGenericOutThunkCleanupRaw) }
        E_FAIL.value
    }

    public override func releaseOutRange(
        buffer: CPointer<Unit>,
        length: UInt32
    ): Unit {
        if (buffer.isNull() || length == 0u32) {
            return
        }
        let slot = CPointer<CPointer<Unit>>(buffer)
        if (unsafe { slot.read() }.isNotNull()) {
            let _ = collectionGenericOutThunkCleanupCalls.fetchAdd(1)
            unsafe { slot.write(CPointer<Unit>()) }
        }
    }
}

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

@Test
func testCollectionGenericOutThunkCleansStoreFailure(): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(654i32) }
    try {
        collectionGenericOutThunkCleanupCalls.store(0)
        collectionGenericOutThunkCleanupRaw = CPointer<Unit>(sentinel)
        var raw = CPointer<Unit>()
        let hr = collectionGenericOutThunk<CollectionGenericOutThunkCleanupProbe>(
            CPointer<CPointer<Unit>>(inout raw),
            { => Result<CollectionGenericOutThunkCleanupProbe>.Ok(CollectionGenericOutThunkCleanupProbe()) }
        )
        @Expect(hr, E_FAIL.value)
        @Expect(raw.isNull(), true)
        @Expect(collectionGenericOutThunkCleanupCalls.load(), 1)
    } finally {
        collectionGenericOutThunkCleanupRaw = CPointer<Unit>()
        unsafe { windows_interface.freeNativeValue<Int32>(sentinel) }
    }
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

func throwingProducerGetManyHString(items: CPointer<Unit>, writeOutput: Bool): Result<UInt32> {
    if (writeOutput && items.isNotNull()) {
        let value = HString("producer-throw")
        let raw = value.toSystemHandleCopy()
        value.close()
        unsafe { CPointer<CPointer<Unit>>(items).write(raw) }
    }
    throw Exception("GetMany failure")
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
    public var throwWindowsOnGetAt = false
    public var throwPlainOnClear = false
    public var throwPlainOnGetMany = false

    public init(writeOutput: Bool) {
        this.writeOutput = writeOutput
    }

    public func GetAt(index: UInt32): Result<HString> {
        let _ = index
        if (throwWindowsOnGetAt) {
            throw WindowsException(E_POINTER)
        }
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
        if (throwPlainOnClear) {
            throw Exception("Clear failure")
        }
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = itemsSize
        if (throwPlainOnGetMany) {
            return throwingProducerGetManyHString(items, writeOutput)
        }
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

class ThrowingProducerIteratorScalarImpl <: IIterator_Impl<HString> {
    public func Current(): Result<HString> {
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func HasCurrent(): Result<Bool> {
        throw WindowsException(E_FAIL)
    }

    public func MoveNext(): Result<Bool> {
        throw Exception("MoveNext failure")
    }

    public func GetMany(itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = itemsSize
        let _ = items
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerMapChangedEventArgsScalarImpl <: IMapChangedEventArgs_Impl<HString> {
    public func get_CollectionChange(): Result<CollectionChange> {
        Result<CollectionChange>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Key(): Result<HString> {
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerVectorChangedEventArgsScalarImpl <: IVectorChangedEventArgs_Impl {
    public func get_CollectionChange(): Result<CollectionChange> {
        Result<CollectionChange>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Index(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerMapViewScalarImpl <: IMapView_Impl<Int32, HString> {
    public func Lookup(key: Int32): Result<HString> {
        let _ = key
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        let _ = first
        let _ = second
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerMapScalarImpl <: IMap_Impl<Int32, HString> {
    public func Lookup(key: Int32): Result<HString> {
        let _ = key
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetView(): Result<IMapView<Int32, HString>> {
        Result<IMapView<Int32, HString>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Insert(key: Int32, value: HString): Result<Bool> {
        let _ = key
        let _ = value
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Remove(key: Int32): Result<Unit> {
        let _ = key
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerObservableMapScalarImpl <: IObservableMap_Impl<Int32, HString> {
    public func MapChanged(vhnd: InParam<MapChangedEventHandler<Int32, HString>>): Result<EventRegistrationToken> {
        let _ = vhnd
        Result<EventRegistrationToken>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func RemoveMapChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Lookup(key: Int32): Result<HString> {
        let _ = key
        Result<HString>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetView(): Result<IMapView<Int32, HString>> {
        Result<IMapView<Int32, HString>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Insert(key: Int32, value: HString): Result<Bool> {
        let _ = key
        let _ = value
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Remove(key: Int32): Result<Unit> {
        let _ = key
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }
}

class FailingProducerPropertySetScalarImpl <: IPropertySet_Impl {
    public func MapChanged(
        vhnd: InParam<MapChangedEventHandler<HString, windows_interface.IInspectable>>
    ): Result<EventRegistrationToken> {
        let _ = vhnd
        Result<EventRegistrationToken>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func RemoveMapChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Lookup(key: HString): Result<windows_interface.IInspectable> {
        let _ = key
        Result<windows_interface.IInspectable>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func HasKey(key: HString): Result<Bool> {
        let _ = key
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func GetView(): Result<IMapView<HString, windows_interface.IInspectable>> {
        Result<IMapView<HString, windows_interface.IInspectable>>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Insert(key: HString, value: windows_interface.IInspectable): Result<Bool> {
        let _ = key
        let _ = value
        Result<Bool>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Remove(key: HString): Result<Unit> {
        let _ = key
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Err(WinError.fromHRESULT(E_NOTIMPL))
    }

    public func First(): Result<IIterator<IKeyValuePair<HString, windows_interface.IInspectable>>> {
        Result<IIterator<IKeyValuePair<HString, windows_interface.IInspectable>>>.Err(WinError.fromHRESULT(E_NOTIMPL))
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

func assertProducerBoolOutThunkClearsStaleBeforeFailure(
    action: (CPointer<Bool>) -> Int32,
    expectedHr: Int32
): Unit {
    var result = true
    let hr = action(CPointer<Bool>(inout result))
    @Expect(hr, expectedHr)
    @Expect(result, false)
}

func assertProducerUInt32OutThunkClearsStaleBeforeFailure(
    action: (CPointer<UInt32>) -> Int32,
    expectedHr: Int32
): Unit {
    var result = 123u32
    let hr = action(CPointer<UInt32>(inout result))
    @Expect(hr, expectedHr)
    @Expect(result, 0u32)
}

func assertProducerCollectionChangeOutThunkClearsStaleBeforeFailure(
    action: (CPointer<CollectionChangeAbi>) -> Int32,
    expectedHr: Int32
): Unit {
    var result = CollectionChangeAbi(3)
    let hr = action(CPointer<CollectionChangeAbi>(inout result))
    @Expect(hr, expectedHr)
    @Expect(result.value, 0i32)
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
func testIIteratorProducerBoolThunksClearStaleOutputsBeforeFailure() {
    let impl = FailingProducerIteratorGetManyImpl(false)
    assertProducerBoolOutThunkClearsStaleBeforeFailure({ result: CPointer<Bool> =>
        impl.__winrtThunk_HasCurrent(result)
    }, E_NOTIMPL.value)
    assertProducerBoolOutThunkClearsStaleBeforeFailure({ result: CPointer<Bool> =>
        impl.__winrtThunk_MoveNext(result)
    }, E_NOTIMPL.value)
}

@When[os == "Windows"]
@Test
func testIIteratorProducerBoolThunksClearStaleOutputsBeforeThrownExceptions() {
    let impl = ThrowingProducerIteratorScalarImpl()
    assertProducerBoolOutThunkClearsStaleBeforeFailure({ result: CPointer<Bool> =>
        impl.__winrtThunk_HasCurrent(result)
    }, E_FAIL.value)
    assertProducerBoolOutThunkClearsStaleBeforeFailure({ result: CPointer<Bool> =>
        impl.__winrtThunk_MoveNext(result)
    }, E_FAIL.value)
}

@When[os == "Windows"]
@Test
func testCollectionChangedProducerScalarThunksClearStaleOutputsBeforeFailure() {
    let mapArgs = FailingProducerMapChangedEventArgsScalarImpl()
    assertProducerCollectionChangeOutThunkClearsStaleBeforeFailure({ result: CPointer<CollectionChangeAbi> =>
        mapArgs.__winrtThunk_get_CollectionChange(result)
    }, E_NOTIMPL.value)

    let vectorArgs = FailingProducerVectorChangedEventArgsScalarImpl()
    assertProducerCollectionChangeOutThunkClearsStaleBeforeFailure({ result: CPointer<CollectionChangeAbi> =>
        vectorArgs.__winrtThunk_get_CollectionChange(result)
    }, E_NOTIMPL.value)
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        vectorArgs.__winrtThunk_Index(result)
    }, E_NOTIMPL.value)
}

@When[os == "Windows"]
@Test
func testCollectionProducerSizeThunksClearStaleOutputsBeforeFailure() {
    let mapView = FailingProducerMapViewScalarImpl()
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        mapView.__winrtThunk_Size(result)
    }, E_NOTIMPL.value)

    let map = FailingProducerMapScalarImpl()
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        map.__winrtThunk_Size(result)
    }, E_NOTIMPL.value)

    let vectorView = FailingProducerVectorViewGetManyImpl(false)
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        vectorView.__winrtThunk_Size(result)
    }, E_NOTIMPL.value)

    let vector = FailingProducerVectorGetManyImpl(false)
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        vector.__winrtThunk_Size(result)
    }, E_NOTIMPL.value)

    let observableMap = FailingProducerObservableMapScalarImpl()
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        observableMap.__winrtThunk_Size(result)
    }, E_NOTIMPL.value)

    let observableVector = FailingProducerObservableVectorGetManyImpl(false)
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        observableVector.__winrtThunk_Size(result)
    }, E_NOTIMPL.value)

    let propertySet = FailingProducerPropertySetScalarImpl()
    assertProducerUInt32OutThunkClearsStaleBeforeFailure({ result: CPointer<UInt32> =>
        propertySet.__winrtThunk_Size(result)
    }, E_NOTIMPL.value)
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
func testIVectorProducerManualThunksTranslateThrownExceptions() {
    let impl = FailingProducerVectorGetManyImpl(true)
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(123i32) }
    try {
        impl.throwWindowsOnGetAt = true
        var raw = CPointer<Unit>(sentinel)
        @Expect(impl.__winrtThunk_GetAt(0u32, CPointer<CPointer<Unit>>(inout raw)), E_POINTER.value)
        @Expect(raw.isNull(), true)
        impl.throwWindowsOnGetAt = false

        impl.throwPlainOnClear = true
        @Expect(impl.__winrtThunk_Clear(), E_FAIL.value)
        impl.throwPlainOnClear = false

        impl.throwPlainOnGetMany = true
        let buffer = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>())
        let slots = CPointer<CPointer<Unit>>(buffer)
        unsafe { slots.write(CPointer<Unit>()) }
        var count = 99u32
        let deleteBefore = windows_core.debugObservedWindowsDeleteStringCount()
        try {
            let hr = impl.__winrtThunk_GetMany(0u32, 1u32, buffer, CPointer<UInt32>(inout count))
            @Expect(hr, E_FAIL.value)
            @Expect(count, 0u32)
            @Expect(unsafe { slots.read() }.isNull(), true)
            @Expect(windows_core.debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
        } finally {
            windows_core.coTaskMemFree(buffer)
        }
        impl.throwPlainOnGetMany = false
    } finally {
        impl.throwWindowsOnGetAt = false
        impl.throwPlainOnClear = false
        impl.throwPlainOnGetMany = false
        unsafe { windows_interface.freeNativeValue(sentinel) }
    }
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
