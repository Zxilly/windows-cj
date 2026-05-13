package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

class Int64VectorAbiTestImpl <: IVector_Impl<Int64> {
    private let items: ArrayList<Int64>
    private let vtblHandle: CPointerHandle<IVectorVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Int64>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.newInt64<Int64VectorAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Int64VectorAbiTestImpl, Int64>() }))
        }
    }

    public static func withGenericVtbl(items: ArrayList<Int64>): Int64VectorAbiTestImpl {
        Int64VectorAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<Int64>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.new<Int64VectorAbiTestImpl, Int64>() }))
            } else {
                acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.newInt64<Int64VectorAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Int64VectorAbiTestImpl, Int64>() }))
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle.pointer)
    }

    ~init() {
        if (closed) {
            return
        }
        unsafe {
            releaseArrayRawData(iterableVtblHandle)
            releaseArrayRawData(vtblHandle)
        }
        closed = true
    }

    public func First(): Result<IIterator<Int64>> {
        Result<IIterator<Int64>>.Ok(toIterator<Int64>(items))
    }

    public func GetAt(index: UInt32): Result<Int64> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Int64>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Int64>.Ok(value)
            case None => Result<Int64>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<Int64>> {
        Result<IVectorView<Int64>>.Ok(createInt64VectorViewAbiTest(items))
    }

    public func IndexOf(value: Int64, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (candidate == value) {
                        if (indexSlot.isNotNull()) {
                            unsafe { indexSlot.write(UInt32(offset)) }
                        }
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        if (indexSlot.isNotNull()) {
            unsafe { indexSlot.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func SetAt(index: UInt32, value: Int64): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Int64): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved > items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items.add(value, at: resolved)
        Result<Unit>.Ok(())
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items.remove(at: resolved)
        Result<Unit>.Ok(())
    }

    public func Append(value: Int64): Result<Unit> {
        items.add(value)
        Result<Unit>.Ok(())
    }

    public func RemoveAtEnd(): Result<Unit> {
        if (items.size == 0) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items.remove(at: items.size - 1)
        Result<Unit>.Ok(())
    }

    public func Clear(): Result<Unit> {
        items.clear()
        Result<Unit>.Ok(())
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<Int64>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<Int64>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {
            items.add(unsafe { (typed + Int64(offset)).read() })
            offset += 1u32
        }
        Result<Unit>.Ok(())
    }
}

func createInt64VectorAbiTest(items: ArrayList<Int64>): IVector<Int64> {
    let impl = Int64VectorAbiTestImpl(items)
    let schemas = [IIterable<Int64>.descriptorSchema(), IVector<Int64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVector<Int64>.descriptor())
}

func createGenericBuilderInt64VectorAbiTest(items: ArrayList<Int64>): IVector<Int64> {
    let impl = Int64VectorAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<Int64>.descriptorSchema(), IVector<Int64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVector<Int64>.descriptor())
}

@Test
func testInt64VectorUsesDirectValueAbiForMutableSlots() {
    let vector = createInt64VectorAbiTest(ArrayList<Int64>([4i64, 6i64]))

    @Expect(unsafe { vector.GetAt(1u32) }, 6i64)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4i64, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Int64) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40i64) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40i64)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Int64) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50i64) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50i64)

    let directAppend = CFunc<(CPointer<Unit>, Int64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60i64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60i64)

    vector.close()
}

@Test
func testGenericInt64VectorBuilderUsesDirectValueAbiForSpecialization() {
    let vector = createGenericBuilderInt64VectorAbiTest(ArrayList<Int64>([1i64, 2i64]))

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        2i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directAppend = CFunc<(CPointer<Unit>, Int64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 3i64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 3i64)

    vector.close()
}
