package windows_collections
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOTIMPL, EventRegistrationTokenAbi}
import windows_interface as windows_interface

@Test
func testCollectionDefaultIteratorAndEventVtablesClearOutSlotsBeforeNotImpl() {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(1u8) }
    try {
        var iterator = IIteratorVtbl()
        var current = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { iterator.Current(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout current)) },
            E_NOTIMPL.value
        )
        @Expect(current.isNull(), true)

        var hasCurrent = true
        @Expect(
            unsafe { iterator.HasCurrent(CPointer<Unit>(), CPointer<Bool>(inout hasCurrent)) },
            E_NOTIMPL.value
        )
        @Expect(hasCurrent, false)

        var moved = true
        @Expect(
            unsafe { iterator.MoveNext(CPointer<Unit>(), CPointer<Bool>(inout moved)) },
            E_NOTIMPL.value
        )
        @Expect(moved, false)

        var manyCount = 9u32
        @Expect(
            unsafe { iterator.GetMany(CPointer<Unit>(), 1u32, CPointer<Unit>(sentinel), CPointer<UInt32>(inout manyCount)) },
            E_NOTIMPL.value
        )
        @Expect(manyCount, 0u32)

        var pair = IKeyValuePairVtbl()
        var key = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { pair.Key(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout key)) },
            E_NOTIMPL.value
        )
        @Expect(key.isNull(), true)

        var value = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { pair.Value(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout value)) },
            E_NOTIMPL.value
        )
        @Expect(value.isNull(), true)

        var mapChanged = IMapChangedEventArgsVtbl()
        var mapChange = CollectionChangeAbi(3)
        @Expect(
            unsafe { mapChanged.get_CollectionChange(CPointer<Unit>(), CPointer<CollectionChangeAbi>(inout mapChange)) },
            E_NOTIMPL.value
        )
        @Expect(mapChange.value, 0i32)

        var mapKey = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { mapChanged.Key(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout mapKey)) },
            E_NOTIMPL.value
        )
        @Expect(mapKey.isNull(), true)

        var vectorChanged = IVectorChangedEventArgsVtbl()
        var vectorChange = CollectionChangeAbi(2)
        @Expect(
            unsafe { vectorChanged.get_CollectionChange(CPointer<Unit>(), CPointer<CollectionChangeAbi>(inout vectorChange)) },
            E_NOTIMPL.value
        )
        @Expect(vectorChange.value, 0i32)

        var index = 17u32
        @Expect(
            unsafe { vectorChanged.Index(CPointer<Unit>(), CPointer<UInt32>(inout index)) },
            E_NOTIMPL.value
        )
        @Expect(index, 0u32)

        var iterable = IIterableVtbl()
        var first = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { iterable.First(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout first)) },
            E_NOTIMPL.value
        )
        @Expect(first.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

@Test
func testCollectionDefaultMapAndVectorVtablesClearOutSlotsBeforeNotImpl() {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(2u8) }
    try {
        var mapView = IMapViewVtbl()
        var mapLookup = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { mapView.Lookup(CPointer<Unit>(), CPointer<Unit>(), CPointer<CPointer<Unit>>(inout mapLookup)) },
            E_NOTIMPL.value
        )
        @Expect(mapLookup.isNull(), true)

        var mapViewSize = 5u32
        @Expect(
            unsafe { mapView.Size(CPointer<Unit>(), CPointer<UInt32>(inout mapViewSize)) },
            E_NOTIMPL.value
        )
        @Expect(mapViewSize, 0u32)

        var hasKey = true
        @Expect(
            unsafe { mapView.HasKey(CPointer<Unit>(), CPointer<Unit>(), CPointer<Bool>(inout hasKey)) },
            E_NOTIMPL.value
        )
        @Expect(hasKey, false)

        var firstSplit = CPointer<Unit>(sentinel)
        var secondSplit = CPointer<Unit>(sentinel)
        @Expect(
            unsafe {
                mapView.Split(
                    CPointer<Unit>(),
                    CPointer<CPointer<Unit>>(inout firstSplit),
                    CPointer<CPointer<Unit>>(inout secondSplit)
                )
            },
            E_NOTIMPL.value
        )
        @Expect(firstSplit.isNull(), true)
        @Expect(secondSplit.isNull(), true)

        var vectorView = IVectorViewVtbl()
        var vectorViewItem = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { vectorView.GetAt(CPointer<Unit>(), 0u32, CPointer<CPointer<Unit>>(inout vectorViewItem)) },
            E_NOTIMPL.value
        )
        @Expect(vectorViewItem.isNull(), true)

        var vectorViewSize = 7u32
        @Expect(
            unsafe { vectorView.Size(CPointer<Unit>(), CPointer<UInt32>(inout vectorViewSize)) },
            E_NOTIMPL.value
        )
        @Expect(vectorViewSize, 0u32)

        var vectorIndex = 11u32
        var vectorFound = true
        @Expect(
            unsafe {
                vectorView.IndexOf(
                    CPointer<Unit>(),
                    CPointer<Unit>(),
                    CPointer<UInt32>(inout vectorIndex),
                    CPointer<Bool>(inout vectorFound)
                )
            },
            E_NOTIMPL.value
        )
        @Expect(vectorIndex, 0u32)
        @Expect(vectorFound, false)

        var vectorViewMany = 13u32
        @Expect(
            unsafe {
                vectorView.GetMany(
                    CPointer<Unit>(),
                    0u32,
                    1u32,
                    CPointer<Unit>(sentinel),
                    CPointer<UInt32>(inout vectorViewMany)
                )
            },
            E_NOTIMPL.value
        )
        @Expect(vectorViewMany, 0u32)

        var map = IMapVtbl()
        var mapItem = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { map.Lookup(CPointer<Unit>(), CPointer<Unit>(), CPointer<CPointer<Unit>>(inout mapItem)) },
            E_NOTIMPL.value
        )
        @Expect(mapItem.isNull(), true)

        var mapSize = 19u32
        @Expect(
            unsafe { map.Size(CPointer<Unit>(), CPointer<UInt32>(inout mapSize)) },
            E_NOTIMPL.value
        )
        @Expect(mapSize, 0u32)

        var mapHasKey = true
        @Expect(
            unsafe { map.HasKey(CPointer<Unit>(), CPointer<Unit>(), CPointer<Bool>(inout mapHasKey)) },
            E_NOTIMPL.value
        )
        @Expect(mapHasKey, false)

        var mapReadonly = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { map.GetView(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout mapReadonly)) },
            E_NOTIMPL.value
        )
        @Expect(mapReadonly.isNull(), true)

        var mapInserted = true
        @Expect(
            unsafe { map.Insert(CPointer<Unit>(), CPointer<Unit>(), CPointer<Unit>(), CPointer<Bool>(inout mapInserted)) },
            E_NOTIMPL.value
        )
        @Expect(mapInserted, false)

        var vector = IVectorVtbl()
        var vectorItem = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { vector.GetAt(CPointer<Unit>(), 0u32, CPointer<CPointer<Unit>>(inout vectorItem)) },
            E_NOTIMPL.value
        )
        @Expect(vectorItem.isNull(), true)

        var vectorSize = 23u32
        @Expect(
            unsafe { vector.Size(CPointer<Unit>(), CPointer<UInt32>(inout vectorSize)) },
            E_NOTIMPL.value
        )
        @Expect(vectorSize, 0u32)

        var vectorReadonly = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { vector.GetView(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout vectorReadonly)) },
            E_NOTIMPL.value
        )
        @Expect(vectorReadonly.isNull(), true)

        var mutableVectorIndex = 29u32
        var mutableVectorFound = true
        @Expect(
            unsafe {
                vector.IndexOf(
                    CPointer<Unit>(),
                    CPointer<Unit>(),
                    CPointer<UInt32>(inout mutableVectorIndex),
                    CPointer<Bool>(inout mutableVectorFound)
                )
            },
            E_NOTIMPL.value
        )
        @Expect(mutableVectorIndex, 0u32)
        @Expect(mutableVectorFound, false)

        var vectorMany = 31u32
        @Expect(
            unsafe {
                vector.GetMany(
                    CPointer<Unit>(),
                    0u32,
                    1u32,
                    CPointer<Unit>(sentinel),
                    CPointer<UInt32>(inout vectorMany)
                )
            },
            E_NOTIMPL.value
        )
        @Expect(vectorMany, 0u32)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

@Test
func testCollectionDefaultObservableVtablesClearTokenOutSlotsBeforeNotImpl() {
    var observableMap = IObservableMapVtbl()
    var mapToken = EventRegistrationTokenAbi()
    mapToken.Value = 41i64
    @Expect(
        unsafe { observableMap.MapChanged(CPointer<Unit>(), CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout mapToken)) },
        E_NOTIMPL.value
    )
    @Expect(mapToken.Value, 0i64)

    var observableVector = IObservableVectorVtbl()
    var vectorToken = EventRegistrationTokenAbi()
    vectorToken.Value = 43i64
    @Expect(
        unsafe { observableVector.VectorChanged(CPointer<Unit>(), CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout vectorToken)) },
        E_NOTIMPL.value
    )
    @Expect(vectorToken.Value, 0i64)
}
