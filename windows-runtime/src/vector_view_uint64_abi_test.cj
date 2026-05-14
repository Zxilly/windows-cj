package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class UInt64VectorViewAbiTestImpl <: IVectorView_Impl<UInt64> & Resource {
    private let items: ArrayList<UInt64>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<UInt64>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newUInt64<UInt64VectorViewAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt64VectorViewAbiTestImpl, UInt64>() }))
        }
    }

    public static func withGenericVtbl(items: ArrayList<UInt64>): UInt64VectorViewAbiTestImpl {
        UInt64VectorViewAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<UInt64>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<UInt64VectorViewAbiTestImpl, UInt64>() }))
            } else {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newUInt64<UInt64VectorViewAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt64VectorViewAbiTestImpl, UInt64>() }))
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle.pointer)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe {
            releaseArrayRawData(iterableVtblHandle)
            releaseArrayRawData(vtblHandle)
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
        unsafe {
            releaseArrayRawData(iterableVtblHandle)
            releaseArrayRawData(vtblHandle)
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

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<UInt64>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createUInt64VectorViewAbiTest(items: ArrayList<UInt64>): IVectorView<UInt64> {
    let impl = UInt64VectorViewAbiTestImpl(items)
    let schemas = [IIterable<UInt64>.descriptorSchema(), IVectorView<UInt64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<UInt64>.descriptor())
    object.close()
    result
}

func createGenericBuilderUInt64VectorViewAbiTest(items: ArrayList<UInt64>): IVectorView<UInt64> {
    let impl = UInt64VectorViewAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<UInt64>.descriptorSchema(), IVectorView<UInt64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<UInt64>.descriptor())
    object.close()
    result
}

@Test
func testUInt64VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createUInt64VectorViewAbiTest(ArrayList<UInt64>([4u64, 6u64]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4u64, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6u64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericUInt64VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderUInt64VectorViewAbiTest(ArrayList<UInt64>([7u64, 9u64]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7u64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
