package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOTIMPL, InParam, Result, S_OK, WinError}
import windows_interface.IInspectable

func collectionOutRetainNotImplemented<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_NOTIMPL))
}

func closeCollectionComOut(raw: CPointer<Unit>): Unit {
    if (raw.isNotNull()) {
        IInspectable.fromAbiTake(raw).close()
    }
}

class CachedIterableFirstRetainTestImpl <: IIterable_Impl<Int32> {
    private let iterator: IIterator<Int32>

    public init(iterator: IIterator<Int32>) {
        this.iterator = iterator
    }

    public func First(): Result<IIterator<Int32>> {
        Result<IIterator<Int32>>.Ok(iterator)
    }
}

class CachedVectorViewFirstRetainTestImpl <: IVectorView_Impl<Int32> {
    private let iterator: IIterator<Int32>

    public init(iterator: IIterator<Int32>) {
        this.iterator = iterator
    }

    public func First(): Result<IIterator<Int32>> {
        Result<IIterator<Int32>>.Ok(iterator)
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let _ = index
        collectionOutRetainNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func IndexOf(value: Int32, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        let _ = index
        collectionOutRetainNotImplemented<Bool>()
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = itemsSize
        let _ = items
        collectionOutRetainNotImplemented<UInt32>()
    }
}

class CachedMapViewFirstRetainTestImpl <: IMapView_Impl<Int32, Int32> {
    private let iterator: IIterator<IKeyValuePair<Int32, Int32>>

    public init(iterator: IIterator<IKeyValuePair<Int32, Int32>>) {
        this.iterator = iterator
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        Result<IIterator<IKeyValuePair<Int32, Int32>>>.Ok(iterator)
    }

    public func Lookup(key: Int32): Result<Int32> {
        let _ = key
        collectionOutRetainNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        let _ = first
        let _ = second
        collectionOutRetainNotImplemented<Unit>()
    }
}

class CachedVectorOutRetainTestImpl <: IVector_Impl<Int32> {
    private let view: IVectorView<Int32>
    private let iterator: IIterator<Int32>

    public init(view: IVectorView<Int32>, iterator: IIterator<Int32>) {
        this.view = view
        this.iterator = iterator
    }

    public func First(): Result<IIterator<Int32>> {
        Result<IIterator<Int32>>.Ok(iterator)
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let _ = index
        collectionOutRetainNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func GetView(): Result<IVectorView<Int32>> {
        Result<IVectorView<Int32>>.Ok(view)
    }

    public func IndexOf(value: Int32, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        let _ = index
        collectionOutRetainNotImplemented<Bool>()
    }

    public func SetAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        collectionOutRetainNotImplemented<Unit>()
    }

    public func InsertAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        collectionOutRetainNotImplemented<Unit>()
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        collectionOutRetainNotImplemented<Unit>()
    }

    public func Append(value: Int32): Result<Unit> {
        let _ = value
        collectionOutRetainNotImplemented<Unit>()
    }

    public func RemoveAtEnd(): Result<Unit> {
        collectionOutRetainNotImplemented<Unit>()
    }

    public func Clear(): Result<Unit> {
        collectionOutRetainNotImplemented<Unit>()
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = itemsSize
        let _ = items
        collectionOutRetainNotImplemented<UInt32>()
    }

    public func ReplaceAll(itemsSize: UInt32, items: CPointer<Unit>): Result<Unit> {
        let _ = itemsSize
        let _ = items
        collectionOutRetainNotImplemented<Unit>()
    }
}

class CachedObservableVectorOutRetainTestImpl <: IObservableVector_Impl<Int32> {
    private let view: IVectorView<Int32>
    private let iterator: IIterator<Int32>

    public init(view: IVectorView<Int32>, iterator: IIterator<Int32>) {
        this.view = view
        this.iterator = iterator
    }

    public func First(): Result<IIterator<Int32>> {
        Result<IIterator<Int32>>.Ok(iterator)
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let _ = index
        collectionOutRetainNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func GetView(): Result<IVectorView<Int32>> {
        Result<IVectorView<Int32>>.Ok(view)
    }

    public func IndexOf(value: Int32, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        let _ = index
        collectionOutRetainNotImplemented<Bool>()
    }

    public func SetAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        collectionOutRetainNotImplemented<Unit>()
    }

    public func InsertAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        collectionOutRetainNotImplemented<Unit>()
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        collectionOutRetainNotImplemented<Unit>()
    }

    public func Append(value: Int32): Result<Unit> {
        let _ = value
        collectionOutRetainNotImplemented<Unit>()
    }

    public func RemoveAtEnd(): Result<Unit> {
        collectionOutRetainNotImplemented<Unit>()
    }

    public func Clear(): Result<Unit> {
        collectionOutRetainNotImplemented<Unit>()
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = itemsSize
        let _ = items
        collectionOutRetainNotImplemented<UInt32>()
    }

    public func ReplaceAll(itemsSize: UInt32, items: CPointer<Unit>): Result<Unit> {
        let _ = itemsSize
        let _ = items
        collectionOutRetainNotImplemented<Unit>()
    }

    public func VectorChanged(vhnd: InParam<VectorChangedEventHandler<Int32>>): Result<EventRegistrationToken> {
        let _ = vhnd
        collectionOutRetainNotImplemented<EventRegistrationToken>()
    }

    public func RemoveVectorChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        collectionOutRetainNotImplemented<Unit>()
    }
}

class CachedMapOutRetainTestImpl <: IMap_Impl<Int32, Int32> {
    private let view: IMapView<Int32, Int32>
    private let iterator: IIterator<IKeyValuePair<Int32, Int32>>

    public init(view: IMapView<Int32, Int32>, iterator: IIterator<IKeyValuePair<Int32, Int32>>) {
        this.view = view
        this.iterator = iterator
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        Result<IIterator<IKeyValuePair<Int32, Int32>>>.Ok(iterator)
    }

    public func Lookup(key: Int32): Result<Int32> {
        let _ = key
        collectionOutRetainNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Ok(false)
    }

    public func GetView(): Result<IMapView<Int32, Int32>> {
        Result<IMapView<Int32, Int32>>.Ok(view)
    }

    public func Insert(key: Int32, value: Int32): Result<Bool> {
        let _ = key
        let _ = value
        collectionOutRetainNotImplemented<Bool>()
    }

    public func Remove(key: Int32): Result<Unit> {
        let _ = key
        collectionOutRetainNotImplemented<Unit>()
    }

    public func Clear(): Result<Unit> {
        collectionOutRetainNotImplemented<Unit>()
    }
}

class CachedObservableMapOutRetainTestImpl <: IObservableMap_Impl<Int32, Int32> {
    private let view: IMapView<Int32, Int32>
    private let iterator: IIterator<IKeyValuePair<Int32, Int32>>

    public init(view: IMapView<Int32, Int32>, iterator: IIterator<IKeyValuePair<Int32, Int32>>) {
        this.view = view
        this.iterator = iterator
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        Result<IIterator<IKeyValuePair<Int32, Int32>>>.Ok(iterator)
    }

    public func Lookup(key: Int32): Result<Int32> {
        let _ = key
        collectionOutRetainNotImplemented<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Ok(false)
    }

    public func GetView(): Result<IMapView<Int32, Int32>> {
        Result<IMapView<Int32, Int32>>.Ok(view)
    }

    public func Insert(key: Int32, value: Int32): Result<Bool> {
        let _ = key
        let _ = value
        collectionOutRetainNotImplemented<Bool>()
    }

    public func Remove(key: Int32): Result<Unit> {
        let _ = key
        collectionOutRetainNotImplemented<Unit>()
    }

    public func Clear(): Result<Unit> {
        collectionOutRetainNotImplemented<Unit>()
    }

    public func MapChanged(vhnd: InParam<MapChangedEventHandler<Int32, Int32>>): Result<EventRegistrationToken> {
        let _ = vhnd
        collectionOutRetainNotImplemented<EventRegistrationToken>()
    }

    public func RemoveMapChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        collectionOutRetainNotImplemented<Unit>()
    }
}

@Test
func testIIterableFirstThunkRetainsReturnedCachedIterator() {
    let iterator = toIterator<Int32>([1i32])
    let impl = CachedIterableFirstRetainTestImpl(iterator)
    var firstRaw = CPointer<Unit>()
    var secondRaw = CPointer<Unit>()

    try {
        let firstHr = impl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout firstRaw))
        let secondHr = impl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout secondRaw))

        @Expect(firstHr, S_OK.value)
        @Expect(secondHr, S_OK.value)
        @Expect(firstRaw.isNotNull(), true)
        @Expect(secondRaw.isNotNull(), true)
        @Expect(iterator.isClosed(), false)
    } finally {
        closeCollectionComOut(firstRaw)
        closeCollectionComOut(secondRaw)
        iterator.close()
    }
}

@Test
func testVectorViewAndMapViewFirstThunksRetainReturnedCachedIterators() {
    let vectorIterator = toIterator<Int32>([1i32])
    let pairIterator = toIterator<IKeyValuePair<Int32, Int32>>([toKeyValuePair<Int32, Int32>(1i32, 1i32)])
    let vectorImpl = CachedVectorViewFirstRetainTestImpl(vectorIterator)
    let mapImpl = CachedMapViewFirstRetainTestImpl(pairIterator)
    var vectorRaw = CPointer<Unit>()
    var mapRaw = CPointer<Unit>()

    try {
        let vectorHr = vectorImpl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout vectorRaw))
        let mapHr = mapImpl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout mapRaw))

        @Expect(vectorHr, S_OK.value)
        @Expect(mapHr, S_OK.value)
        @Expect(vectorRaw.isNotNull(), true)
        @Expect(mapRaw.isNotNull(), true)
        @Expect(vectorIterator.isClosed(), false)
        @Expect(pairIterator.isClosed(), false)
    } finally {
        closeCollectionComOut(vectorRaw)
        closeCollectionComOut(mapRaw)
        vectorIterator.close()
        pairIterator.close()
    }
}

@Test
func testVectorAndObservableVectorThunksRetainReturnedCachedViewsAndIterators() {
    let vectorView = toVectorView([1i32, 2i32])
    let observableView = toVectorView([3i32, 4i32])
    let vectorIterator = toIterator<Int32>([1i32])
    let observableIterator = toIterator<Int32>([3i32])
    let vectorImpl = CachedVectorOutRetainTestImpl(vectorView, vectorIterator)
    let observableImpl = CachedObservableVectorOutRetainTestImpl(observableView, observableIterator)
    var vectorViewRaw = CPointer<Unit>()
    var vectorIteratorRaw = CPointer<Unit>()
    var observableViewRaw = CPointer<Unit>()
    var observableIteratorRaw = CPointer<Unit>()

    try {
        let vectorViewHr = vectorImpl.__winrtThunk_GetView(CPointer<CPointer<Unit>>(inout vectorViewRaw))
        let vectorFirstHr = vectorImpl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout vectorIteratorRaw))
        let observableViewHr = observableImpl.__winrtThunk_GetView(CPointer<CPointer<Unit>>(inout observableViewRaw))
        let observableFirstHr = observableImpl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout observableIteratorRaw))

        @Expect(vectorViewHr, S_OK.value)
        @Expect(vectorFirstHr, S_OK.value)
        @Expect(observableViewHr, S_OK.value)
        @Expect(observableFirstHr, S_OK.value)
        @Expect(vectorView.isClosed(), false)
        @Expect(vectorIterator.isClosed(), false)
        @Expect(observableView.isClosed(), false)
        @Expect(observableIterator.isClosed(), false)
    } finally {
        closeCollectionComOut(vectorViewRaw)
        closeCollectionComOut(vectorIteratorRaw)
        closeCollectionComOut(observableViewRaw)
        closeCollectionComOut(observableIteratorRaw)
        vectorView.close()
        observableView.close()
        vectorIterator.close()
        observableIterator.close()
    }
}

@Test
func testMapAndObservableMapThunksRetainReturnedCachedViewsAndIterators() {
    let mapView = toMapView([(1i32, 10i32)])
    let observableView = toMapView([(2i32, 20i32)])
    let pair = toKeyValuePair<Int32, Int32>(1i32, 10i32)
    let observablePair = toKeyValuePair<Int32, Int32>(2i32, 20i32)
    let mapIterator = toIterator<IKeyValuePair<Int32, Int32>>([pair])
    let observableIterator = toIterator<IKeyValuePair<Int32, Int32>>([observablePair])
    let mapImpl = CachedMapOutRetainTestImpl(mapView, mapIterator)
    let observableImpl = CachedObservableMapOutRetainTestImpl(observableView, observableIterator)
    var mapViewRaw = CPointer<Unit>()
    var mapIteratorRaw = CPointer<Unit>()
    var observableViewRaw = CPointer<Unit>()
    var observableIteratorRaw = CPointer<Unit>()

    try {
        let mapViewHr = mapImpl.__winrtThunk_GetView(CPointer<CPointer<Unit>>(inout mapViewRaw))
        let mapFirstHr = mapImpl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout mapIteratorRaw))
        let observableViewHr = observableImpl.__winrtThunk_GetView(CPointer<CPointer<Unit>>(inout observableViewRaw))
        let observableFirstHr = observableImpl.__winrtThunk_First(CPointer<CPointer<Unit>>(inout observableIteratorRaw))

        @Expect(mapViewHr, S_OK.value)
        @Expect(mapFirstHr, S_OK.value)
        @Expect(observableViewHr, S_OK.value)
        @Expect(observableFirstHr, S_OK.value)
        @Expect(mapView.isClosed(), false)
        @Expect(mapIterator.isClosed(), false)
        @Expect(observableView.isClosed(), false)
        @Expect(observableIterator.isClosed(), false)
    } finally {
        closeCollectionComOut(mapViewRaw)
        closeCollectionComOut(mapIteratorRaw)
        closeCollectionComOut(observableViewRaw)
        closeCollectionComOut(observableIteratorRaw)
        mapView.close()
        observableView.close()
        mapIterator.close()
        observableIterator.close()
        pair.close()
        observablePair.close()
    }
}
