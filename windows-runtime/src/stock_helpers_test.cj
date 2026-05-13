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
