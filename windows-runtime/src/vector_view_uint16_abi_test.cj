package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class UInt16VectorViewAbiTestImpl <: IVectorView_Impl<UInt16> {
    private let items: ArrayList<UInt16>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<UInt16>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newUInt16<UInt16VectorViewAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt16VectorViewAbiTestImpl, UInt16>() }))
        }
    }

    public static func withGenericVtbl(items: ArrayList<UInt16>): UInt16VectorViewAbiTestImpl {
        UInt16VectorViewAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<UInt16>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<UInt16VectorViewAbiTestImpl, UInt16>() }))
            } else {
                acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.newUInt16<UInt16VectorViewAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt16VectorViewAbiTestImpl, UInt16>() }))
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

    public func First(): Result<IIterator<UInt16>> {
        Result<IIterator<UInt16>>.Ok(toIterator<UInt16>(items))
    }

    public func GetAt(index: UInt32): Result<UInt16> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<UInt16>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<UInt16>.Ok(value)
            case None => Result<UInt16>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: UInt16, indexSlot: CPointer<UInt32>): Result<Bool> {
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
        writeGenericManyRange<UInt16>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createUInt16VectorViewAbiTest(items: ArrayList<UInt16>): IVectorView<UInt16> {
    let impl = UInt16VectorViewAbiTestImpl(items)
    let schemas = [IIterable<UInt16>.descriptorSchema(), IVectorView<UInt16>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<UInt16>.descriptor())
}

func createGenericBuilderUInt16VectorViewAbiTest(items: ArrayList<UInt16>): IVectorView<UInt16> {
    let impl = UInt16VectorViewAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<UInt16>.descriptorSchema(), IVectorView<UInt16>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<UInt16>.descriptor())
}

@Test
func testUInt16VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createUInt16VectorViewAbiTest(ArrayList<UInt16>([4u16, 6u16]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4u16, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6u16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericUInt16VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderUInt16VectorViewAbiTest(ArrayList<UInt16>([7u16, 9u16]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7u16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
