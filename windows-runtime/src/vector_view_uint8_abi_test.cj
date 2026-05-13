package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class UInt8VectorViewAbiTestImpl <: IVectorView_Impl<UInt8> {
    private let items: ArrayList<UInt8>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<UInt8>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newUInt8<UInt8VectorViewAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt8VectorViewAbiTestImpl, UInt8>() }))
        }
    }

    public static func withGenericVtbl(items: ArrayList<UInt8>): UInt8VectorViewAbiTestImpl {
        UInt8VectorViewAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<UInt8>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<UInt8VectorViewAbiTestImpl, UInt8>() }))
            } else {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newUInt8<UInt8VectorViewAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt8VectorViewAbiTestImpl, UInt8>() }))
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

    public func First(): Result<IIterator<UInt8>> {
        Result<IIterator<UInt8>>.Ok(toIterator<UInt8>(items))
    }

    public func GetAt(index: UInt32): Result<UInt8> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<UInt8>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<UInt8>.Ok(value)
            case None => Result<UInt8>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: UInt8, indexSlot: CPointer<UInt32>): Result<Bool> {
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
        writeGenericManyRange<UInt8>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createUInt8VectorViewAbiTest(items: ArrayList<UInt8>): IVectorView<UInt8> {
    let impl = UInt8VectorViewAbiTestImpl(items)
    let schemas = [IIterable<UInt8>.descriptorSchema(), IVectorView<UInt8>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<UInt8>.descriptor())
}

func createGenericBuilderUInt8VectorViewAbiTest(items: ArrayList<UInt8>): IVectorView<UInt8> {
    let impl = UInt8VectorViewAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<UInt8>.descriptorSchema(), IVectorView<UInt8>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<UInt8>.descriptor())
}

@Test
func testUInt8VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createUInt8VectorViewAbiTest(ArrayList<UInt8>([4u8, 6u8]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4u8, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt8, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6u8,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericUInt8VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderUInt8VectorViewAbiTest(ArrayList<UInt8>([7u8, 9u8]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt8, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7u8,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
