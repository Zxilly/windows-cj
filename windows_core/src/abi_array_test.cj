package windows_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testProjectedAbiArrayCopiesAndCloses() {
    let values = [1i32, 2i32, 3i32]
    let array = AbiArray<Int32>.fromSlice(values)

    values[0] = 99i32
    @Expect(array.len(), 3)
    @Expect(array.get(0), 1i32)

    array.set(1, 7i32)
    let copied = array.toArray()
    @Expect(copied[0], 1i32)
    @Expect(copied[1], 7i32)
    @Expect(copied[2], 3i32)

    array.close()
    @Expect(array.isClosed(), true)
    @Expect(array.toArray().size, 0)
}

@Test
func testNativeAbiArrayIntoAbiTransfersOwnership() {
    let array = AbiArray<Int32>.withLen(2)
    array.set(0, 11i32)
    array.set(1, 22i32)

    let (raw, len) = array.intoAbi()
    @Expect(len, 2u32)
    @Expect(array.isClosed(), true)
    @Expect(raw.isNotNull(), true)
    unsafe {
        @Expect(raw.read(), 11i32)
        @Expect((raw + 1).read(), 22i32)
        CoTaskMemFree(CPointer<Unit>(raw))
    }
}

@Test
func testNativeAbiArrayCloseIsIdempotent() {
    let array = AbiArray<Int32>.withLen(1)
    array.set(0, 42i32)
    @Expect(array.asRaw().isNotNull(), true)

    array.close()
    array.close()

    @Expect(array.isClosed(), true)
    @Expect(array.asRaw().isNull(), true)
    @Expect(array.toArray().size, 0)
}

@Test
func testPublicCoTaskMemHelpersAllocateAndFree() {
    let raw = coTaskMemAlloc(UIntNative(1))
    @Expect(raw.isNotNull(), true)
    @Expect(coTaskMemAllocationSize(raw), Some(UIntNative(1)))
    coTaskMemFree(raw)
    @Expect(coTaskMemAllocationSize(raw), Option<UIntNative>.None)
}

@Test
func testPublicCoTaskMemReallocPreservesPrefixBytes() {
    let raw = coTaskMemAlloc(UIntNative(2))
    if (raw.isNull()) {
        throw Exception("coTaskMemAlloc returned null")
    }
    let bytes = CPointer<UInt8>(raw)
    unsafe {
        bytes.write(0x41u8)
        (bytes + 1).write(0x42u8)
    }

    let resized = coTaskMemRealloc(raw, UIntNative(4))
    if (resized.isNull()) {
        coTaskMemFree(raw)
        throw Exception("coTaskMemRealloc returned null")
    }
    @Expect(coTaskMemAllocationSize(raw), Option<UIntNative>.None)
    @Expect(coTaskMemAllocationSize(resized), Some(UIntNative(4)))
    let resizedBytes = CPointer<UInt8>(resized)
    unsafe {
        @Expect(resizedBytes.read(), 0x41u8)
        @Expect((resizedBytes + 1).read(), 0x42u8)
    }
    coTaskMemFree(resized)
}

@Test
func testPublicCoTaskMemReallocZeroClearsTrackedSize() {
    let raw = coTaskMemAlloc(UIntNative(16))
    if (raw.isNull()) {
        throw Exception("coTaskMemAlloc returned null")
    }
    @Expect(coTaskMemAllocationSize(raw), Some(UIntNative(16)))

    let resized = coTaskMemRealloc(raw, UIntNative(0))

    @Expect(resized.isNull(), true)
    @Expect(coTaskMemAllocationSize(raw), Option<UIntNative>.None)
    if (resized.isNotNull()) {
        coTaskMemFree(resized)
    }
}

class TrackingInt32AbiArrayStorage <: AbiArrayStorage<Int32> {
    private var values: Array<Int32>
    public var clearCount: Int64 = 0

    public init(values: Array<Int32>) {
        this.values = values
    }

    public func len(): UInt32 {
        UInt32(values.size)
    }

    public func get(index: Int64): Int32 {
        values[index]
    }

    public func set(index: Int64, value: Int32): Unit {
        values[index] = value
    }

    public func toArray(): Array<Int32> {
        values
    }

    public func replaceWith(values: Array<Int32>): Unit {
        this.values = values
    }

    public func clear(): Unit {
        clearCount += 1
        values = Array<Int32>()
    }

    public func finalizeNoThrow(): Unit {
        clear()
    }
}

@Test
func testAbiArrayReplaceWithClearsPreviousStorage() {
    let tracking = TrackingInt32AbiArrayStorage([1i32, 2i32])
    let array = AbiArray<Int32>(tracking)

    array.replaceWith([7i32])

    @Expect(tracking.clearCount, 1)
    @Expect(array.len(), 1)
    @Expect(array.get(0), 7i32)
    array.close()
}

@Test
func testProjectedAbiArrayReplaceWithClosesPreviousHStringClones() {
    let first = HString("first")
    let second = HString("second")
    let array = AbiArray<HString>.fromSlice([first])
    let freeBefore = debugObservedHStringFreeCount()

    array.replaceWith([second])
    first.close()
    @Expect(debugObservedHStringFreeCount() - freeBefore, 1)

    array.close()
    second.close()
    @Expect(debugObservedHStringFreeCount() - freeBefore, 2)
}

@Test
func testProjectedAbiArrayStorageFinalizeNoThrowClosesHStringClones() {
    let source = HString("finalize-projected")
    let storage = ProjectedAbiArrayStorage<HString>([source])
    let freeBefore = debugObservedHStringFreeCount()

    storage.finalizeNoThrow()
    source.close()

    @Expect(debugObservedHStringFreeCount() - freeBefore, 1)
}

@When[os == "Windows"]
@Test
func testNativeAbiArrayStorageFinalizeNoThrowClosesState() {
    let raw = unsafe { CoTaskMemAlloc(sizeOf<Int32>()) }
    if (raw.isNull()) {
        throw Exception("CoTaskMemAlloc returned null")
    }
    let storage = NativeAbiArrayStorage<Int32>(CPointer<Int32>(raw), 1u32)

    storage.finalizeNoThrow()

    @Expect(storage.isClosed(), true)
    @Expect(storage.rawOrNull().isNull(), true)
}

@Test
func testAbiArrayReplaceWithClonesInputBeforeClearingOldStorage() {
    // Regression guard: replaceWith must clone its inputs before calling
    // clear() on the old storage. Today get() returns an owned wrapper so
    // `fetched` and the storage entry are independent, but if get() ever
    // regressed to returning an alias, a clear-then-replace order would
    // close the very wrapper just handed to replaceWith. Keeping this test
    // makes that regression observable.
    let original = HString("shared")
    let array = AbiArray<HString>.fromSlice([original])
    let fetched = array.get(0)

    array.replaceWith([fetched])

    @Expect(array.get(0).get(), "shared")
    // fetched is an independent owned wrapper; replaceWith must not close it.
    @Expect(fetched.isClosed(), false)

    fetched.close()
    original.close()
    array.close()
}

@Test
func testProjectedAbiArrayGetReturnsOwnedHStringClone() {
    // Contract probe: AbiArray<HString>.get() must return an owned wrapper
    // independent of the storage's wrapper. Closing the returned value must
    // not corrupt the storage — every wrapper handed out has exactly one
    // clear releaser (the caller).
    let original = HString("get-owned")
    let array = AbiArray<HString>.fromSlice([original])

    let fetched = array.get(0)
    fetched.close()

    // Closing the caller's wrapper must not mark the storage entry as closed
    // nor invalidate subsequent reads.
    @Expect(array.get(0).isClosed(), false)
    @Expect(array.get(0).get(), "get-owned")

    array.close()
    original.close()
}

@Test
func testArrayProxyCopyArrayNullDataTargetClosesStagedStorage() {
    var length = 0u32
    let tracking = TrackingInt32AbiArrayStorage([10i32, 20i32])

    try (proxy = unsafe { arrayProxy<Int32>(CPointer<CPointer<Int32>>(), CPointer<UInt32>(inout length)) }) {
        proxy.value().storage = tracking
    }

    @Expect(length, 2u32)
    @Expect(tracking.clearCount, 1)
}

@Test
func testArrayProxyObjectNullDataTargetClosesHStringProjectionClone() {
    var length = 0u32
    let source = HString("proxy-null-object")
    let freeBefore = debugObservedHStringFreeCount()

    try (proxy = unsafe { arrayProxy<HString>(CPointer<CPointer<Unit>>(), CPointer<UInt32>(inout length)) }) {
        proxy.value().replaceWith([source])
    }

    @Expect(length, 1u32)
    source.close()
    @Expect(debugObservedHStringFreeCount() - freeBefore, 1)
}

@Test
func testArrayProxyCloseIsIdempotent() {
    var length = 0u32
    let tracking = TrackingInt32AbiArrayStorage([10i32, 20i32])
    let proxy = unsafe { arrayProxy<Int32>(CPointer<CPointer<Int32>>(), CPointer<UInt32>(inout length)) }
    proxy.value().storage = tracking

    proxy.close()
    proxy.close()

    @Expect(proxy.isClosed(), true)
    @Expect(length, 2u32)
    @Expect(tracking.clearCount, 1)
}

@When[os == "Windows"]
@Test
func testArrayProxyPublishesHStringElementsAsSystemHandles() {
    var rawItems = CPointer<Unit>()
    var length = 0u32

    try (proxy = unsafe { arrayProxy<HString>(CPointer<CPointer<Unit>>(inout rawItems), CPointer<UInt32>(inout length)) }) {
        proxy.value().replaceWith([HString("one"), HString("two")])
    }

    @Expect(length, 2u32)
    @Expect(rawItems.isNotNull(), true)

    let slots = CPointer<CPointer<Unit>>(rawItems)
    let first = HString.fromSystemHandleTake(unsafe { slots.read() })
    let second = HString.fromSystemHandleTake(unsafe { (slots + 1).read() })

    @Expect(first.get(), "one")
    @Expect(second.get(), "two")

    first.close()
    second.close()
    unsafe { CoTaskMemFree(rawItems) }
}

@When[os == "Windows"]
@Test
func testArrayProxyPublishesHStringElementsClosesProjectionClone() {
    var rawItems = CPointer<Unit>()
    var length = 0u32
    let source = HString("proxy-object")
    let freeBefore = debugObservedHStringFreeCount()

    try (proxy = unsafe { arrayProxy<HString>(CPointer<CPointer<Unit>>(inout rawItems), CPointer<UInt32>(inout length)) }) {
        proxy.value().replaceWith([source])
    }

    @Expect(length, 1u32)
    source.close()
    @Expect(debugObservedHStringFreeCount() - freeBefore, 1)

    let slots = CPointer<CPointer<Unit>>(rawItems)
    releaseSystemHStringHandle(unsafe { slots.read() })
    unsafe { CoTaskMemFree(rawItems) }
}
