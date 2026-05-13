package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

class Float32VectorAbiTestImpl <: IVector_Impl<Float32> {
    private let items: ArrayList<Float32>
    private let vtblHandle: CPointerHandle<IVectorVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Float32>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.newFloat32<Float32VectorAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Float32VectorAbiTestImpl, Float32>() }))
        }
    }

    public static func withGenericVtbl(items: ArrayList<Float32>): Float32VectorAbiTestImpl {
        Float32VectorAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<Float32>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.new<Float32VectorAbiTestImpl, Float32>() }))
            } else {
                acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.newFloat32<Float32VectorAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Float32VectorAbiTestImpl, Float32>() }))
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

    public func First(): Result<IIterator<Float32>> {
        Result<IIterator<Float32>>.Ok(toIterator<Float32>(items))
    }

    public func GetAt(index: UInt32): Result<Float32> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Float32>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Float32>.Ok(value)
            case None => Result<Float32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<Float32>> {
        Result<IVectorView<Float32>>.Ok(createGenericBuilderFloat32VectorViewAbiTest(items))
    }

    public func IndexOf(value: Float32, indexSlot: CPointer<UInt32>): Result<Bool> {
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

    public func SetAt(index: UInt32, value: Float32): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Float32): Result<Unit> {
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

    public func Append(value: Float32): Result<Unit> {
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
        writeGenericManyRange<Float32>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<Float32>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {
            items.add(unsafe { (typed + Int64(offset)).read() })
            offset += 1u32
        }
        Result<Unit>.Ok(())
    }
}

class GenericBuilderFloat32VectorViewAbiTestImpl <: IVectorView_Impl<Float32> {
    private let items: ArrayList<Float32>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Float32>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<GenericBuilderFloat32VectorViewAbiTestImpl, Float32>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<GenericBuilderFloat32VectorViewAbiTestImpl, Float32>() }))
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

    public func First(): Result<IIterator<Float32>> {
        Result<IIterator<Float32>>.Ok(toIterator<Float32>(items))
    }

    public func GetAt(index: UInt32): Result<Float32> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Float32>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Float32>.Ok(value)
            case None => Result<Float32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: Float32, indexSlot: CPointer<UInt32>): Result<Bool> {
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
        writeGenericManyRange<Float32>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createFloat32VectorAbiTest(items: ArrayList<Float32>): IVector<Float32> {
    let impl = Float32VectorAbiTestImpl(items)
    let schemas = [IIterable<Float32>.descriptorSchema(), IVector<Float32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVector<Float32>.descriptor())
}

func createGenericBuilderFloat32VectorAbiTest(items: ArrayList<Float32>): IVector<Float32> {
    let impl = Float32VectorAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<Float32>.descriptorSchema(), IVector<Float32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVector<Float32>.descriptor())
}

func createGenericBuilderFloat32VectorViewAbiTest(items: ArrayList<Float32>): IVectorView<Float32> {
    let impl = GenericBuilderFloat32VectorViewAbiTestImpl(items)
    let schemas = [IIterable<Float32>.descriptorSchema(), IVectorView<Float32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<Float32>.descriptor())
}

@Test
func testFloat32VectorUsesDirectValueAbiForMutableSlots() {
    let source = ArrayList<Float32>([4.5f32, 6.25f32])
    let vector = createFloat32VectorAbiTest(source)

    @Expect(unsafe { vector.GetAt(1u32) }, 6.25f32)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4.5f32, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6.25f32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Float32) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40.5f32) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40.5f32)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Float32) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50.5f32) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50.5f32)

    let directAppend = CFunc<(CPointer<Unit>, Float32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60.5f32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60.5f32)

    vector.close()
}

@Test
func testGenericFloat32VectorBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<Float32>([1.25f32, 2.5f32])
    let vector = createGenericBuilderFloat32VectorAbiTest(source)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        2.5f32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directAppend = CFunc<(CPointer<Unit>, Float32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 3.75f32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 3.75f32)

    vector.close()
}

@Test
func testGenericFloat32VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<Float32>([7.25f32, 9.5f32])
    let view = createGenericBuilderFloat32VectorViewAbiTest(source)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7.25f32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
