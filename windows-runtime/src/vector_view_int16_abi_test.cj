package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class Int16VectorViewAbiTestImpl <: IVectorView_Impl<Int16> {
    private let items: ArrayList<Int16>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Int16>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newInt16<Int16VectorViewAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Int16VectorViewAbiTestImpl, Int16>() }))
        }
    }

    public static func withGenericVtbl(items: ArrayList<Int16>): Int16VectorViewAbiTestImpl {
        Int16VectorViewAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<Int16>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<Int16VectorViewAbiTestImpl, Int16>() }))
            } else {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newInt16<Int16VectorViewAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Int16VectorViewAbiTestImpl, Int16>() }))
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

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<Int16>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createInt16VectorViewAbiTest(items: ArrayList<Int16>): IVectorView<Int16> {
    let impl = Int16VectorViewAbiTestImpl(items)
    let schemas = [IIterable<Int16>.descriptorSchema(), IVectorView<Int16>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<Int16>.descriptor())
}

func createGenericBuilderInt16VectorViewAbiTest(items: ArrayList<Int16>): IVectorView<Int16> {
    let impl = Int16VectorViewAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<Int16>.descriptorSchema(), IVectorView<Int16>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<Int16>.descriptor())
}

@Test
func testInt16VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createInt16VectorViewAbiTest(ArrayList<Int16>([4i16, 6i16]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4i16, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericInt16VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderInt16VectorViewAbiTest(ArrayList<Int16>([7i16, 9i16]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
