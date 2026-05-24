package windows_collections
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, EventRegistrationToken, InParam, Result, S_OK, WinError}
func nullBufferThunkError<T>(): Result<T> {
    Result<T>.Err(WinError(E_POINTER))
}

class NullBufferIteratorThunkImpl <: IIterator_Impl<Int32> {
    public var getManyCalls: Int64 = 0

    public func Current(): Result<Int32> {
        Result<Int32>.Ok(0i32)
    }

    public func HasCurrent(): Result<Bool> {
        Result<Bool>.Ok(false)
    }

    public func MoveNext(): Result<Bool> {
        Result<Bool>.Ok(false)
    }

    public func GetMany(itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = items
        getManyCalls += 1
        Result<UInt32>.Ok(itemsSize)
    }
}

class NullBufferVectorViewThunkImpl <: IVectorView_Impl<Int32> {
    public var getManyCalls: Int64 = 0
    public var indexOfCalls: Int64 = 0

    public func First(): Result<IIterator<Int32>> {
        nullBufferThunkError<IIterator<Int32>>()
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let _ = index
        nullBufferThunkError<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func IndexOf(value: Int32, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        indexOfCalls += 1
        if (index.isNotNull()) {
            unsafe { index.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = items
        getManyCalls += 1
        Result<UInt32>.Ok(itemsSize)
    }
}

class NullBufferVectorThunkImpl <: IVector_Impl<Int32> {
    public var getManyCalls: Int64 = 0
    public var indexOfCalls: Int64 = 0
    public var replaceAllCalls: Int64 = 0
    public var setAtCalls: Int64 = 0
    public var insertAtCalls: Int64 = 0
    public var appendCalls: Int64 = 0

    public func First(): Result<IIterator<Int32>> {
        nullBufferThunkError<IIterator<Int32>>()
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let _ = index
        nullBufferThunkError<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func GetView(): Result<IVectorView<Int32>> {
        nullBufferThunkError<IVectorView<Int32>>()
    }

    public func IndexOf(value: Int32, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        indexOfCalls += 1
        if (index.isNotNull()) {
            unsafe { index.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func SetAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        setAtCalls += 1
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        insertAtCalls += 1
        Result<Unit>.Ok(())
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        Result<Unit>.Ok(())
    }

    public func Append(value: Int32): Result<Unit> {
        let _ = value
        appendCalls += 1
        Result<Unit>.Ok(())
    }

    public func RemoveAtEnd(): Result<Unit> {
        Result<Unit>.Ok(())
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Ok(())
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = items
        getManyCalls += 1
        Result<UInt32>.Ok(itemsSize)
    }

    public func ReplaceAll(itemsSize: UInt32, items: CPointer<Unit>): Result<Unit> {
        let _ = itemsSize
        let _ = items
        replaceAllCalls += 1
        Result<Unit>.Ok(())
    }
}

class NullBufferObservableVectorThunkImpl <: IObservableVector_Impl<Int32> {
    public var getManyCalls: Int64 = 0
    public var indexOfCalls: Int64 = 0
    public var replaceAllCalls: Int64 = 0
    public var setAtCalls: Int64 = 0
    public var insertAtCalls: Int64 = 0
    public var appendCalls: Int64 = 0

    public func First(): Result<IIterator<Int32>> {
        nullBufferThunkError<IIterator<Int32>>()
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let _ = index
        nullBufferThunkError<Int32>()
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func GetView(): Result<IVectorView<Int32>> {
        nullBufferThunkError<IVectorView<Int32>>()
    }

    public func IndexOf(value: Int32, index: CPointer<UInt32>): Result<Bool> {
        let _ = value
        indexOfCalls += 1
        if (index.isNotNull()) {
            unsafe { index.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func SetAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        setAtCalls += 1
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        insertAtCalls += 1
        Result<Unit>.Ok(())
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        Result<Unit>.Ok(())
    }

    public func Append(value: Int32): Result<Unit> {
        let _ = value
        appendCalls += 1
        Result<Unit>.Ok(())
    }

    public func RemoveAtEnd(): Result<Unit> {
        Result<Unit>.Ok(())
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Ok(())
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        let _ = startIndex
        let _ = items
        getManyCalls += 1
        Result<UInt32>.Ok(itemsSize)
    }

    public func ReplaceAll(itemsSize: UInt32, items: CPointer<Unit>): Result<Unit> {
        let _ = itemsSize
        let _ = items
        replaceAllCalls += 1
        Result<Unit>.Ok(())
    }

    public func VectorChanged(vhnd: InParam<VectorChangedEventHandler<Int32>>): Result<EventRegistrationToken> {
        let _ = vhnd
        Result<EventRegistrationToken>.Ok(EventRegistrationToken())
    }

    public func RemoveVectorChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        Result<Unit>.Ok(())
    }
}

class NullGenericInputMapThunkImpl <: IMap_Impl<Int32, Int32> {
    public var lookupCalls: Int64 = 0
    public var hasKeyCalls: Int64 = 0
    public var insertCalls: Int64 = 0
    public var removeCalls: Int64 = 0

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        nullBufferThunkError<IIterator<IKeyValuePair<Int32, Int32>>>()
    }

    public func Lookup(key: Int32): Result<Int32> {
        let _ = key
        lookupCalls += 1
        Result<Int32>.Ok(0i32)
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        hasKeyCalls += 1
        Result<Bool>.Ok(true)
    }

    public func GetView(): Result<IMapView<Int32, Int32>> {
        nullBufferThunkError<IMapView<Int32, Int32>>()
    }

    public func Insert(key: Int32, value: Int32): Result<Bool> {
        let _ = key
        let _ = value
        insertCalls += 1
        Result<Bool>.Ok(true)
    }

    public func Remove(key: Int32): Result<Unit> {
        let _ = key
        removeCalls += 1
        Result<Unit>.Ok(())
    }

    public func Clear(): Result<Unit> {
        Result<Unit>.Ok(())
    }
}

class NullBufferMapViewThunkImpl <: IMapView_Impl<Int32, Int32> {
    public var splitCalls: Int64 = 0

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        nullBufferThunkError<IIterator<IKeyValuePair<Int32, Int32>>>()
    }

    public func Lookup(key: Int32): Result<Int32> {
        let _ = key
        Result<Int32>.Ok(0i32)
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        splitCalls += 1
        if (first.isNotNull()) {
            unsafe { first.write(CPointer<Unit>()) }
        }
        if (second.isNotNull()) {
            unsafe { second.write(CPointer<Unit>()) }
        }
        Result<Unit>.Ok(())
    }
}

@Test
func testGeneratedIteratorGetManyThunkRejectsNullBufferWithNonZeroCapacity() {
    let impl = NullBufferIteratorThunkImpl()
    var copied = 99u32

    let hr = impl.__winrtThunk_GetMany(1u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(hr, E_POINTER.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 0)

    let emptyHr = impl.__winrtThunk_GetMany(0u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(emptyHr, S_OK.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 1)
}

@Test
func testGeneratedVectorViewGetManyThunkRejectsNullBufferWithNonZeroCapacity() {
    let impl = NullBufferVectorViewThunkImpl()
    var copied = 99u32

    let hr = impl.__winrtThunk_GetMany(0u32, 1u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(hr, E_POINTER.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 0)

    let emptyHr = impl.__winrtThunk_GetMany(0u32, 0u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(emptyHr, S_OK.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 1)
}

@Test
func testGeneratedVectorViewIndexOfThunkRejectsNullIndexSlot() {
    let impl = NullBufferVectorViewThunkImpl()
    var found = true

    let hr = impl.__winrtThunk_IndexOf(CPointer<Unit>(), CPointer<UInt32>(), CPointer<Bool>(inout found))
    @Expect(hr, E_POINTER.value)
    @Expect(found, true)
    @Expect(impl.indexOfCalls, 0)
}

@Test
func testGeneratedVectorGetManyThunkRejectsNullBufferWithNonZeroCapacity() {
    let impl = NullBufferVectorThunkImpl()
    var copied = 99u32

    let hr = impl.__winrtThunk_GetMany(0u32, 1u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(hr, E_POINTER.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 0)

    let emptyHr = impl.__winrtThunk_GetMany(0u32, 0u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(emptyHr, S_OK.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 1)
}

@Test
func testGeneratedVectorIndexOfThunkRejectsNullIndexSlot() {
    let impl = NullBufferVectorThunkImpl()
    var found = true

    let hr = impl.__winrtThunk_IndexOf(CPointer<Unit>(), CPointer<UInt32>(), CPointer<Bool>(inout found))
    @Expect(hr, E_POINTER.value)
    @Expect(found, true)
    @Expect(impl.indexOfCalls, 0)
}

@Test
func testGeneratedVectorThunksTranslateNullGenericInputToEPointer() {
    let impl = NullBufferVectorThunkImpl()
    var index = 99u32
    var found = true

    let indexHr = impl.__winrtThunk_IndexOf(
        CPointer<Unit>(),
        CPointer<UInt32>(inout index),
        CPointer<Bool>(inout found)
    )
    @Expect(indexHr, E_POINTER.value)
    @Expect(index, 0u32)
    @Expect(found, false)
    @Expect(impl.indexOfCalls, 0)

    let setAtHr = impl.__winrtThunk_SetAt(0u32, CPointer<Unit>())
    @Expect(setAtHr, E_POINTER.value)
    @Expect(impl.setAtCalls, 0)

    let insertAtHr = impl.__winrtThunk_InsertAt(0u32, CPointer<Unit>())
    @Expect(insertAtHr, E_POINTER.value)
    @Expect(impl.insertAtCalls, 0)

    let appendHr = impl.__winrtThunk_Append(CPointer<Unit>())
    @Expect(appendHr, E_POINTER.value)
    @Expect(impl.appendCalls, 0)
}

@Test
func testGeneratedVectorReplaceAllThunkRejectsNullBufferWithNonZeroCapacity() {
    let impl = NullBufferVectorThunkImpl()

    let hr = impl.__winrtThunk_ReplaceAll(1u32, CPointer<Unit>())
    @Expect(hr, E_POINTER.value)
    @Expect(impl.replaceAllCalls, 0)

    let emptyHr = impl.__winrtThunk_ReplaceAll(0u32, CPointer<Unit>())
    @Expect(emptyHr, S_OK.value)
    @Expect(impl.replaceAllCalls, 1)
}

@Test
func testGeneratedObservableVectorThunkRejectsNullBuffersWithNonZeroCapacity() {
    let impl = NullBufferObservableVectorThunkImpl()
    var copied = 99u32

    let getManyHr = impl.__winrtThunk_GetMany(0u32, 1u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(getManyHr, E_POINTER.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 0)

    let replaceHr = impl.__winrtThunk_ReplaceAll(1u32, CPointer<Unit>())
    @Expect(replaceHr, E_POINTER.value)
    @Expect(impl.replaceAllCalls, 0)

    let emptyGetManyHr = impl.__winrtThunk_GetMany(0u32, 0u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(emptyGetManyHr, S_OK.value)
    @Expect(copied, 0u32)
    @Expect(impl.getManyCalls, 1)

    let emptyReplaceHr = impl.__winrtThunk_ReplaceAll(0u32, CPointer<Unit>())
    @Expect(emptyReplaceHr, S_OK.value)
    @Expect(impl.replaceAllCalls, 1)
}

@Test
func testGeneratedObservableVectorIndexOfThunkRejectsNullIndexSlot() {
    let impl = NullBufferObservableVectorThunkImpl()
    var found = true

    let hr = impl.__winrtThunk_IndexOf(CPointer<Unit>(), CPointer<UInt32>(), CPointer<Bool>(inout found))
    @Expect(hr, E_POINTER.value)
    @Expect(found, true)
    @Expect(impl.indexOfCalls, 0)
}

@Test
func testGeneratedObservableVectorThunksTranslateNullGenericInputToEPointer() {
    let impl = NullBufferObservableVectorThunkImpl()
    var index = 99u32
    var found = true

    let indexHr = impl.__winrtThunk_IndexOf(
        CPointer<Unit>(),
        CPointer<UInt32>(inout index),
        CPointer<Bool>(inout found)
    )
    @Expect(indexHr, E_POINTER.value)
    @Expect(index, 0u32)
    @Expect(found, false)
    @Expect(impl.indexOfCalls, 0)

    let setAtHr = impl.__winrtThunk_SetAt(0u32, CPointer<Unit>())
    @Expect(setAtHr, E_POINTER.value)
    @Expect(impl.setAtCalls, 0)

    let insertAtHr = impl.__winrtThunk_InsertAt(0u32, CPointer<Unit>())
    @Expect(insertAtHr, E_POINTER.value)
    @Expect(impl.insertAtCalls, 0)

    let appendHr = impl.__winrtThunk_Append(CPointer<Unit>())
    @Expect(appendHr, E_POINTER.value)
    @Expect(impl.appendCalls, 0)
}

@Test
func testGeneratedMapThunksTranslateNullGenericInputToEPointerAndClearBoolOutSlots() {
    let impl = NullGenericInputMapThunkImpl()
    var rawResult = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x1234) }

    let lookupHr = impl.__winrtThunk_Lookup(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout rawResult))
    @Expect(lookupHr, E_POINTER.value)
    @Expect(rawResult.isNull(), true)
    @Expect(impl.lookupCalls, 0)

    var exists = true
    let hasKeyHr = impl.__winrtThunk_HasKey(CPointer<Unit>(), CPointer<Bool>(inout exists))
    @Expect(hasKeyHr, E_POINTER.value)
    @Expect(exists, false)
    @Expect(impl.hasKeyCalls, 0)

    var replaced = true
    let insertNullKeyHr = impl.__winrtThunk_Insert(CPointer<Unit>(), CPointer<Unit>(), CPointer<Bool>(inout replaced))
    @Expect(insertNullKeyHr, E_POINTER.value)
    @Expect(replaced, false)
    @Expect(impl.insertCalls, 0)

    var key = 7i32
    var replacedByNullValue = true
    let insertNullValueHr = impl.__winrtThunk_Insert(
        CPointer<Unit>(CPointer<Int32>(inout key)),
        CPointer<Unit>(),
        CPointer<Bool>(inout replacedByNullValue)
    )
    @Expect(insertNullValueHr, E_POINTER.value)
    @Expect(replacedByNullValue, false)
    @Expect(impl.insertCalls, 0)

    let removeHr = impl.__winrtThunk_Remove(CPointer<Unit>())
    @Expect(removeHr, E_POINTER.value)
    @Expect(impl.removeCalls, 0)
}

@Test
func testGeneratedMapViewSplitThunkClearsSiblingOutSlotOnPointerFailure() {
    let impl = NullBufferMapViewThunkImpl()
    var firstRaw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x1234) }
    var secondRaw = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x5678) }

    let nullFirstHr = impl.__winrtThunk_Split(
        CPointer<CPointer<Unit>>(),
        CPointer<CPointer<Unit>>(inout secondRaw)
    )
    @Expect(nullFirstHr, E_POINTER.value)
    @Expect(secondRaw.isNull(), true)
    @Expect(impl.splitCalls, 0)

    let nullSecondHr = impl.__winrtThunk_Split(
        CPointer<CPointer<Unit>>(inout firstRaw),
        CPointer<CPointer<Unit>>()
    )
    @Expect(nullSecondHr, E_POINTER.value)
    @Expect(firstRaw.isNull(), true)
    @Expect(impl.splitCalls, 0)
}
