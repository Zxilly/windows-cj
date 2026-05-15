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
func testPublicCoTaskMemHelpersAllocateAndFree() {
    let raw = coTaskMemAlloc(UIntNative(1))
    @Expect(raw.isNotNull(), true)
    coTaskMemFree(raw)
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
    let resizedBytes = CPointer<UInt8>(resized)
    unsafe {
        @Expect(resizedBytes.read(), 0x41u8)
        @Expect((resizedBytes + 1).read(), 0x42u8)
    }
    coTaskMemFree(resized)
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
