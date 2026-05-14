package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

class GenericBuilderInt32VectorAbiTestImpl <: IVector_Impl<Int32> & Resource {
    private let items: ArrayList<Int32>
    private let vtblHandle: CPointerHandle<IVectorVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Int32>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.new<GenericBuilderInt32VectorAbiTestImpl, Int32>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<GenericBuilderInt32VectorAbiTestImpl, Int32>() }))
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

    public func First(): Result<IIterator<Int32>> {
        Result<IIterator<Int32>>.Ok(toIterator<Int32>(items))
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Int32>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Int32>.Ok(value)
            case None => Result<Int32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<Int32>> {
        Result<IVectorView<Int32>>.Ok(toVectorView(items))
    }

    public func IndexOf(value: Int32, indexSlot: CPointer<UInt32>): Result<Bool> {
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

    public func SetAt(index: UInt32, value: Int32): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Int32): Result<Unit> {
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

    public func Append(value: Int32): Result<Unit> {
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
        writeGenericManyRange<Int32>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<Int32>(itemsBuffer)
        var offset = 0
        while (offset < Int64(itemsSize)) {
            items.add(unsafe { (typed + offset).read() })
            offset += 1
        }
        Result<Unit>.Ok(())
    }
}

class GenericBuilderInt32VectorViewAbiTestImpl <: IVectorView_Impl<Int32> & Resource {
    private let items: ArrayList<Int32>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Int32>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(
                Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<GenericBuilderInt32VectorViewAbiTestImpl, Int32>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<GenericBuilderInt32VectorViewAbiTestImpl, Int32>() }))
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

    public func First(): Result<IIterator<Int32>> {
        Result<IIterator<Int32>>.Ok(toIterator<Int32>(items))
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Int32>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Int32>.Ok(value)
            case None => Result<Int32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: Int32, indexSlot: CPointer<UInt32>): Result<Bool> {
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
        writeGenericManyRange<Int32>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createGenericBuilderInt32VectorAbiTest(values: ArrayList<Int32>): IVector<Int32> {
    let impl = GenericBuilderInt32VectorAbiTestImpl(values)
    let schemas = [IIterable<Int32>.descriptorSchema(), IVector<Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVector<Int32>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32VectorViewAbiTest(values: ArrayList<Int32>): IVectorView<Int32> {
    let impl = GenericBuilderInt32VectorViewAbiTestImpl(values)
    let schemas = [IIterable<Int32>.descriptorSchema(), IVectorView<Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<Int32>.descriptor())
    object.close()
    result
}

@Test
func testGenericInt32VectorBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<Int32>([1i32, 3i32])
    let vector = createGenericBuilderInt32VectorAbiTest(source)

    unsafe { vector.SetAt(0u32, 2i32) }
    unsafe { vector.InsertAt(1u32, 4i32) }
    unsafe { vector.Append(6i32) }
    @Expect(unsafe { vector.GetAt(0u32) }, 2i32)
    @Expect(unsafe { vector.GetAt(1u32) }, 4i32)
    @Expect(unsafe { vector.GetAt(3u32) }, 6i32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i32, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 3u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Int32) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 2u32, 5i32) }
    @Expect(setHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 5i32)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Int32) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 2u32, 7i32) }
    @Expect(insertHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 7i32)

    let directAppend = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 8i32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(5u32) }, 8i32)

    vector.close()
}

@Test
func testGenericInt32VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<Int32>([1i32, 3i32, 5i32])
    let view = createGenericBuilderInt32VectorViewAbiTest(source)

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(3i32, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(view.asRaw(), 5i32, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 2u32)

    view.close()
}
