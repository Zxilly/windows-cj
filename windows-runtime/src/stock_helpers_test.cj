package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, HString, S_OK}

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
    @Expect(vectorCount, 99u32)

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
    @Expect(iteratorCount, 99u32)

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
