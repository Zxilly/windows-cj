package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

class UInt64VectorAbiTestImpl <: IVector_Impl<UInt64> & Resource {
    private let items: ArrayList<UInt64>
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<UInt64>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newUInt64<UInt64VectorAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<UInt64VectorAbiTestImpl, UInt64>())
        }
    }

    public static func withGenericVtbl(items: ArrayList<UInt64>): UInt64VectorAbiTestImpl {
        UInt64VectorAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<UInt64>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new<UInt64VectorAbiTestImpl, UInt64>())
            } else {
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newUInt64<UInt64VectorAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<UInt64VectorAbiTestImpl, UInt64>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func First(): Result<IIterator<UInt64>> {
        Result<IIterator<UInt64>>.Ok(toIterator<UInt64>(items))
    }

    public func GetAt(index: UInt32): Result<UInt64> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<UInt64>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<UInt64>.Ok(value)
            case None => Result<UInt64>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<UInt64>> {
        Result<IVectorView<UInt64>>.Ok(createUInt64VectorViewAbiTest(items))
    }

    public func IndexOf(value: UInt64, indexSlot: CPointer<UInt32>): Result<Bool> {
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

    public func SetAt(index: UInt32, value: UInt64): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: UInt64): Result<Unit> {
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

    public func Append(value: UInt64): Result<Unit> {
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
        writeGenericManyRange<UInt64>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<UInt64>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {
            items.add(unsafe { (typed + Int64(offset)).read() })
            offset += 1u32
        }
        Result<Unit>.Ok(())
    }
}

class UInt64VectorAbiTestFixture <: Resource {
    public let vector: IVector<UInt64>
    private let impl: UInt64VectorAbiTestImpl
    private var closed: Bool = false

    public init(items: ArrayList<UInt64>, useGenericVtbl!: Bool = false) {
        impl = if (useGenericVtbl) {
            UInt64VectorAbiTestImpl.withGenericVtbl(items)
        } else {
            UInt64VectorAbiTestImpl(items)
        }

        let schemas = [IIterable<UInt64>.descriptorSchema(), IVector<UInt64>.descriptorSchema()]
        let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
        let object = createComObjectFromSchemas(impl, schemas, vtbls)
        vector = object.toInterface(IVector<UInt64>.descriptor())
        object.close()
    }

    public func innerClosed(): Bool {
        impl.isClosed()
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (!closed) {
            vector.close()
            closed = true
        }
    }
}

func createUInt64VectorAbiTest(items: ArrayList<UInt64>): UInt64VectorAbiTestFixture {
    UInt64VectorAbiTestFixture(items)
}

func createGenericBuilderUInt64VectorAbiTest(items: ArrayList<UInt64>): UInt64VectorAbiTestFixture {
    UInt64VectorAbiTestFixture(items, useGenericVtbl: true)
}

@Test
func testUInt64VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createUInt64VectorAbiTest(ArrayList<UInt64>([4u64, 6u64]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    @Expect(unsafe { vector.GetAt(1u32) }, 6u64)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4u64, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6u64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6u64, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, UInt64) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40u64) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40u64)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, UInt64) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50u64) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50u64)

    let directAppend = CFunc<(CPointer<Unit>, UInt64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60u64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60u64)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}

@Test
func testGenericUInt64VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderUInt64VectorAbiTest(ArrayList<UInt64>([4u64, 6u64]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6u64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6u64, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directAppend = CFunc<(CPointer<Unit>, UInt64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 7u64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 7u64)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}
