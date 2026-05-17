package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class Int64VectorViewAbiTestImpl <: IVectorView_Impl<Int64> & Resource {
    private let items: ArrayList<Int64>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Int64>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.newInt64<Int64VectorViewAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int64VectorViewAbiTestImpl, Int64>())
        }
    }

    public static func withGenericVtbl(items: ArrayList<Int64>): Int64VectorViewAbiTestImpl {
        Int64VectorViewAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<Int64>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.new<Int64VectorViewAbiTestImpl, Int64>())
            } else {
                windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.newInt64<Int64VectorViewAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int64VectorViewAbiTestImpl, Int64>())
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

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<Int64>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createInt64VectorViewAbiTest(items: ArrayList<Int64>): IVectorView<Int64> {
    let impl = Int64VectorViewAbiTestImpl(items)
    let schemas = [IIterable<Int64>.descriptorSchema(), IVectorView<Int64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<Int64>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt64VectorViewAbiTest(items: ArrayList<Int64>): IVectorView<Int64> {
    let impl = Int64VectorViewAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<Int64>.descriptorSchema(), IVectorView<Int64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<Int64>.descriptor())
    object.close()
    result
}

@Test
func testInt64VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createInt64VectorViewAbiTest(ArrayList<Int64>([4i64, 6i64]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4i64, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericInt64VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderInt64VectorViewAbiTest(ArrayList<Int64>([7i64, 9i64]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
