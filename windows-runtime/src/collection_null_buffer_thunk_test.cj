package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, InParam, Result, S_OK, WinError}

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
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        Result<Unit>.Ok(())
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        Result<Unit>.Ok(())
    }

    public func Append(value: Int32): Result<Unit> {
        let _ = value
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
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Int32): Result<Unit> {
        let _ = index
        let _ = value
        Result<Unit>.Ok(())
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let _ = index
        Result<Unit>.Ok(())
    }

    public func Append(value: Int32): Result<Unit> {
        let _ = value
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

@Test
func testGeneratedIteratorGetManyThunkRejectsNullBufferWithNonZeroCapacity() {
    let impl = NullBufferIteratorThunkImpl()
    var copied = 99u32

    let hr = impl.__winrtThunk_GetMany(1u32, CPointer<Unit>(), CPointer<UInt32>(inout copied))
    @Expect(hr, E_POINTER.value)
    @Expect(copied, 99u32)
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
    @Expect(copied, 99u32)
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
    @Expect(copied, 99u32)
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
    @Expect(copied, 99u32)
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
