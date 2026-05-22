package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, E_POINTER, HString, Result, S_OK, comRegistryLookup, rootRegistryKeyFromRaw}

class StockTestStringableImpl <: IStringable_Impl & Resource {
    private let value: HString
    private let vtblHandle: CPointer<IStringableVtbl>
    private var closed: Bool = false

    public init(text: String) {
        this.value = HString(text)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IStringableVtbl>(IStringableVtbl.new<StockTestStringableImpl>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func ToString(): Result<HString> {
        Result<HString>.Ok(value)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        value.close()
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }
}

func createStockTestStringable(text: String): IStringable {
    let impl = StockTestStringableImpl(text)
    createStockInterface<StockTestStringableImpl, IStringable>(
        impl,
        IStringable.descriptorSchema(),
        IStringable.descriptor(),
        impl.vtblPtr()
    )
}

@Test
func testStringableVtblNoneBranchClearsHStringOutput() {
    let vtbl = IStringableVtbl.new<StockTestStringableImpl>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IStringableVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IStringableVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(321i32) }
    var result = CPointer<Unit>(sentinel)

    try {
        let hr = unsafe { vtbl.ToString(CPointer<Unit>(objectHandle), CPointer<CPointer<Unit>>(inout result)) }

        @Expect(hr, E_NOINTERFACE.value)
        @Expect(result.isNull(), true)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

@Test
func testStockIteratorSnapshotsSourceAndAdvancesCursor() {
    let source = ArrayList<Int32>([1i32, 2i32])
    let iterator = toIterator<Int32>(source)
    source.add(3i32)

    @Expect(unsafe { iterator.HasCurrent() }, true)
    @Expect(unsafe { iterator.Current() }, 1i32)
    @Expect(unsafe { iterator.MoveNext() }, true)
    @Expect(unsafe { iterator.Current() }, 2i32)
    @Expect(unsafe { iterator.MoveNext() }, false)
    @Expect(unsafe { iterator.HasCurrent() }, false)
}

@Test
func testStockReturnedInterfaceCloseRemovesRegistryEntry() {
    let iterator = toIterator<Int32>([1i32])
    let raw = iterator.asRaw()
    let key = unsafe { rootRegistryKeyFromRaw(raw) }

    @Expect(comRegistryLookup(key).isSome(), true)
    iterator.close()
    @Expect(comRegistryLookup(key).isNone(), true)
}

@Test
func testStockInterfaceCreationFailureClosesInnerResource() {
    let impl = StockTestStringableImpl("failed")

    try {
        let iterator = createStockInterface<StockTestStringableImpl, IIterator<IStringable>>(
            impl,
            IStringable.descriptorSchema(),
            IIterator<IStringable>.descriptor(),
            impl.vtblPtr()
        )
        iterator.close()
        @Expect(true, false)
    } catch (e: Exception) {
        let _ = e
    }

    @Expect(impl.isClosed(), true)
}

@Test
func testStockMultiInterfaceCreationFailureClosesInnerResource() {
    let impl = StockTestStringableImpl("failed")

    try {
        let iterator = createStockInterfaceMulti<StockTestStringableImpl, IIterator<IStringable>>(
            impl,
            [IStringable.descriptorSchema()],
            IIterator<IStringable>.descriptor(),
            [impl.vtblPtr()]
        )
        iterator.close()
        @Expect(true, false)
    } catch (e: Exception) {
        let _ = e
    }

    @Expect(impl.isClosed(), true)
}

@Test
func testStockHStringValuesAreIndependentOfSourceHandles() {
    let first = HString("first")
    let second = HString("second")
    let view = toVectorView<HString>([first, second])

    first.close()
    second.close()

    let firstFromView = unsafe { view.GetAt(0u32) }
    let secondFromView = unsafe { view.GetAt(1u32) }
    @Expect(firstFromView.get(), "first")
    @Expect(secondFromView.get(), "second")

    firstFromView.close()
    secondFromView.close()
    view.close()
}

@Test
func testStockHStringMapEntriesAreIndependentOfSourceHandles() {
    let key = HString("key")
    let value = HString("value")
    let view = toMapView<HString, HString>([(key, value)])

    key.close()
    value.close()

    let lookupKey = HString("key")
    let valueFromView = unsafe { view.Lookup(lookupKey) }
    @Expect(valueFromView.get(), "value")

    valueFromView.close()
    lookupKey.close()
    view.close()
}

@Test
func testStockInterfaceValuesRetainIndependentReference() {
    let source = createStockTestStringable("stable")
    let iterator = toIterator<IStringable>([source])

    source.close()

    let current = unsafe { iterator.Current() }
    let text = unsafe { current.ToString() }
    @Expect(text.get(), "stable")

    text.close()
    current.close()
    iterator.close()
}

@Test
func testStockIterableCloseReleasesInterfaceSnapshot() {
    let source = createStockTestStringable("iterable")
    let key = unsafe { rootRegistryKeyFromRaw(source.asRaw()) }
    let iterable = toIterable<IStringable>([source])

    source.close()
    @Expect(comRegistryLookup(key).isSome(), true)

    iterable.close()
    @Expect(comRegistryLookup(key).isNone(), true)
}

@Test
func testStockMapViewCloseReleasesInterfaceSnapshots() {
    let sourceKey = HString("key")
    let sourceValue = createStockTestStringable("mapped")
    let valueRegistryKey = unsafe { rootRegistryKeyFromRaw(sourceValue.asRaw()) }
    let view = toMapView<HString, IStringable>([(sourceKey, sourceValue)])

    sourceKey.close()
    sourceValue.close()
    @Expect(comRegistryLookup(valueRegistryKey).isSome(), true)

    view.close()
    @Expect(comRegistryLookup(valueRegistryKey).isNone(), true)
}

@Test
func testStockListSnapshotFailureReleasesPartialInterfaceClones() {
    let first = createStockTestStringable("first")
    let second = createStockTestStringable("second")
    let firstRegistryKey = unsafe { rootRegistryKeyFromRaw(first.asRaw()) }

    second.close()

    try {
        let iterator = toIterator<IStringable>([first, second])
        iterator.close()
        @Expect(true, false)
    } catch (e: Exception) {
        let _ = e
    }

    first.close()
    @Expect(comRegistryLookup(firstRegistryKey).isNone(), true)
}

@Test
func testStockPairSnapshotFailureReleasesPartialInterfaceClone() {
    let key = createStockTestStringable("key")
    let value = createStockTestStringable("value")
    let keyRegistryKey = unsafe { rootRegistryKeyFromRaw(key.asRaw()) }

    value.close()

    try {
        let pair = toKeyValuePair<IStringable, IStringable>(key, value)
        pair.close()
        @Expect(true, false)
    } catch (e: Exception) {
        let _ = e
    }

    key.close()
    @Expect(comRegistryLookup(keyRegistryKey).isNone(), true)
}

@Test
func testStockVectorViewIndexOfClearsMissingIndex() {
    let first = HString("first")
    let second = HString("second")
    let missing = HString("missing")
    let view = toVectorView<HString>([first, second])
    var index = 99u32

    @Expect(unsafe { view.Size() }, 2u32)
    @Expect(unsafe { view.GetAt(1u32) } == second, true)
    @Expect(unsafe { view.IndexOf(second, CPointer<UInt32>(inout index)) }, true)
    @Expect(index, 1u32)

    index = 99u32
    @Expect(unsafe { view.IndexOf(missing, CPointer<UInt32>(inout index)) }, false)
    @Expect(index, 0u32)

    first.close()
    second.close()
    missing.close()
}

@Test
func testStockCopyVectorViewIndexOfUsesDirectValueAbi() {
    let view = toVectorView([0i32, 2i32])
    var wrapperIndex = 99u32

    @Expect(unsafe { view.Size() }, 2u32)
    @Expect(unsafe { view.IndexOf(2i32, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)

    var directIndex = 99u32
    var directFound = false
    let vtbl = unsafe { view.vtbl() }
    let directIndexOf = CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let directHr = unsafe { directIndexOf(
        view.asRaw(),
        0i32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }

    @Expect(directHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}

@Test
func testStockGetManyRejectsNullBufferWithNonZeroCapacity() {
    let first = HString("first")
    let vectorView = toVectorView<HString>([first])
    let iterator = toIterator<HString>([first])

    var vectorCount = 99u32
    let vectorVtbl = unsafe { vectorView.vtbl() }
    let vectorHr = unsafe { vectorVtbl.GetMany(
        vectorView.asRaw(),
        0u32,
        1u32,
        CPointer<Unit>(),
        CPointer<UInt32>(inout vectorCount)
    ) }
    @Expect(vectorHr, E_POINTER.value)
    @Expect(vectorCount, 0u32)

    vectorCount = 99u32
    let vectorEmptyHr = unsafe { vectorVtbl.GetMany(
        vectorView.asRaw(),
        0u32,
        0u32,
        CPointer<Unit>(),
        CPointer<UInt32>(inout vectorCount)
    ) }
    @Expect(vectorEmptyHr, S_OK.value)
    @Expect(vectorCount, 0u32)

    var iteratorCount = 99u32
    let iteratorVtbl = unsafe { iterator.vtbl() }
    let iteratorHr = unsafe { iteratorVtbl.GetMany(
        iterator.asRaw(),
        1u32,
        CPointer<Unit>(),
        CPointer<UInt32>(inout iteratorCount)
    ) }
    @Expect(iteratorHr, E_POINTER.value)
    @Expect(iteratorCount, 0u32)

    iteratorCount = 99u32
    let iteratorEmptyHr = unsafe { iteratorVtbl.GetMany(
        iterator.asRaw(),
        0u32,
        CPointer<Unit>(),
        CPointer<UInt32>(inout iteratorCount)
    ) }
    @Expect(iteratorEmptyHr, S_OK.value)
    @Expect(iteratorCount, 0u32)

    iterator.close()
    vectorView.close()
    first.close()
}

@Test
func testStockMapViewLookupAndPairIterationUseSnapshot() {
    let one = HString("one")
    let two = HString("two")
    let three = HString("three")
    let entries = ArrayList<(HString, Int32)>([(one, 10i32), (two, 20i32)])
    let view = toMapView<HString, Int32>(entries)
    entries.add((three, 30i32))

    var keyText = ""
    var valueSum = 0i32
    let pairs = view.iterator()
    while (true) {
        match (pairs.next()) {
            case Some(pair) =>
                keyText = keyText + unsafe { pair.Key() }.get()
                valueSum += unsafe { pair.Value() }
            case None =>
                break
        }
    }

    @Expect(unsafe { view.Size() }, 2u32)
    @Expect(unsafe { view.HasKey(two) }, true)
    @Expect(unsafe { view.Lookup(two) }, 20i32)
    @Expect(unsafe { view.HasKey(three) }, false)
    @Expect(keyText, "onetwo")
    @Expect(valueSum, 30i32)

    one.close()
    two.close()
    three.close()
}

@Test
func testStockInt32MapViewUsesDirectKeyAbi() {
    let entries = ArrayList<(Int32, Int32)>([(1i32, 10i32), (2i32, 20i32)])
    let view = toMapView(entries)
    entries.add((3i32, 30i32))

    @Expect(unsafe { view.Size() }, 2u32)
    @Expect(unsafe { view.HasKey(2i32) }, true)
    @Expect(unsafe { view.Lookup(2i32) }, 20i32)

    var directValue = 0i32
    let vtbl = unsafe { view.vtbl() }
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<Int32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 10i32)

    var directFound = true
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 3i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    view.close()
}

@Test
func testStockInt32HStringMapViewUsesDirectKeyAbi() {
    let one = HString("one")
    let two = HString("two")
    let entries = ArrayList<(Int32, HString)>([(1i32, one), (2i32, two)])
    let view = toMapView(entries)

    @Expect(unsafe { view.Size() }, 2u32)
    @Expect(unsafe { view.HasKey(2i32) }, true)
    let wrapperValue = unsafe { view.Lookup(2i32) }
    @Expect(wrapperValue.get(), "two")
    wrapperValue.close()

    var directRaw = CPointer<Unit>()
    let vtbl = unsafe { view.vtbl() }
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(
        CPointer<Unit>(vtbl.Lookup)
    )
    let lookupHr = unsafe {
        directLookup(view.asRaw(), 1i32, CPointer<CPointer<Unit>>(inout directRaw))
    }
    @Expect(lookupHr, S_OK.value)
    let directValue = HString.fromSystemHandleTake(directRaw)
    @Expect(directValue.get(), "one")
    directValue.close()

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 3i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    view.close()
    one.close()
    two.close()
}
