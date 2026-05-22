package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

class Int16VectorAbiTestImpl <: IVector_Impl<Int16> & Resource {
    private let items: ArrayList<Int16>
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Int16>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newInt16<Int16VectorAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int16VectorAbiTestImpl, Int16>())
        }
    }

    public static func withGenericVtbl(items: ArrayList<Int16>): Int16VectorAbiTestImpl {
        Int16VectorAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<Int16>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new<Int16VectorAbiTestImpl, Int16>())
            } else {
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newInt16<Int16VectorAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int16VectorAbiTestImpl, Int16>())
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

    public func First(): Result<IIterator<Int16>> {
        Result<IIterator<Int16>>.Ok(toIterator<Int16>(items))
    }

    public func GetAt(index: UInt32): Result<Int16> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Int16>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Int16>.Ok(value)
            case None => Result<Int16>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<Int16>> {
        Result<IVectorView<Int16>>.Ok(createInt16VectorViewAbiTest(items))
    }

    public func IndexOf(value: Int16, indexSlot: CPointer<UInt32>): Result<Bool> {
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

    public func SetAt(index: UInt32, value: Int16): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Int16): Result<Unit> {
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

    public func Append(value: Int16): Result<Unit> {
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
        writeGenericManyRange<Int16>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<Int16>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {
            items.add(unsafe { (typed + Int64(offset)).read() })
            offset += 1u32
        }
        Result<Unit>.Ok(())
    }
}

class Int16VectorAbiTestFixture <: Resource {
    public let vector: IVector<Int16>
    private let impl: Int16VectorAbiTestImpl
    private var closed: Bool = false

    public init(items: ArrayList<Int16>, useGenericVtbl!: Bool = false) {
        impl = if (useGenericVtbl) {
            Int16VectorAbiTestImpl.withGenericVtbl(items)
        } else {
            Int16VectorAbiTestImpl(items)
        }

        let schemas = [IIterable<Int16>.descriptorSchema(), IVector<Int16>.descriptorSchema()]
        let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
        let object = createComObjectFromSchemas(impl, schemas, vtbls)
        vector = object.toInterface(IVector<Int16>.descriptor())
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

func createInt16VectorAbiTest(items: ArrayList<Int16>): Int16VectorAbiTestFixture {
    Int16VectorAbiTestFixture(items)
}

func createGenericBuilderInt16VectorAbiTest(items: ArrayList<Int16>): Int16VectorAbiTestFixture {
    Int16VectorAbiTestFixture(items, useGenericVtbl: true)
}

@Test
func testInt16VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createInt16VectorAbiTest(ArrayList<Int16>([4i16, 6i16]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    @Expect(unsafe { vector.GetAt(1u32) }, 6i16)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4i16, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i16, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Int16) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40i16) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40i16)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Int16) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50i16) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50i16)

    let directAppend = CFunc<(CPointer<Unit>, Int16) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60i16) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60i16)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}

@Test
func testGenericInt16VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderInt16VectorAbiTest(ArrayList<Int16>([4i16, 6i16]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i16, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directAppend = CFunc<(CPointer<Unit>, Int16) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 7i16) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 7i16)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}
