package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

class BoolVectorAbiTestImpl <: IVector_Impl<Bool> {
    private let items: ArrayList<Bool>
    private let vtblHandle: CPointerHandle<IVectorVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Bool>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.newBool<BoolVectorAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<BoolVectorAbiTestImpl, Bool>() }))
        }
    }

    public static func withGenericVtbl(items: ArrayList<Bool>): BoolVectorAbiTestImpl {
        BoolVectorAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<Bool>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.new<BoolVectorAbiTestImpl, Bool>() }))
            } else {
                acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.newBool<BoolVectorAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<BoolVectorAbiTestImpl, Bool>() }))
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

    public func First(): Result<IIterator<Bool>> {
        Result<IIterator<Bool>>.Ok(toIterator<Bool>(items))
    }

    public func GetAt(index: UInt32): Result<Bool> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Bool>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Bool>.Ok(value)
            case None => Result<Bool>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<Bool>> {
        Result<IVectorView<Bool>>.Ok(createGenericBuilderBoolVectorViewAbiTest(items))
    }

    public func IndexOf(value: Bool, indexSlot: CPointer<UInt32>): Result<Bool> {
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

    public func SetAt(index: UInt32, value: Bool): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: Bool): Result<Unit> {
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

    public func Append(value: Bool): Result<Unit> {
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
        writeGenericManyRange<Bool>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<Bool>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {
            items.add(unsafe { (typed + Int64(offset)).read() })
            offset += 1u32
        }
        Result<Unit>.Ok(())
    }
}

class GenericBuilderBoolVectorViewAbiTestImpl <: IVectorView_Impl<Bool> {
    private let items: ArrayList<Bool>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Bool>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<GenericBuilderBoolVectorViewAbiTestImpl, Bool>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<GenericBuilderBoolVectorViewAbiTestImpl, Bool>() }))
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

    public func First(): Result<IIterator<Bool>> {
        Result<IIterator<Bool>>.Ok(toIterator<Bool>(items))
    }

    public func GetAt(index: UInt32): Result<Bool> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Bool>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<Bool>.Ok(value)
            case None => Result<Bool>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: Bool, indexSlot: CPointer<UInt32>): Result<Bool> {
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
        writeGenericManyRange<Bool>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createBoolVectorAbiTest(items: ArrayList<Bool>): IVector<Bool> {
    let impl = BoolVectorAbiTestImpl(items)
    let schemas = [IIterable<Bool>.descriptorSchema(), IVector<Bool>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVector<Bool>.descriptor())
}

func createGenericBuilderBoolVectorAbiTest(items: ArrayList<Bool>): IVector<Bool> {
    let impl = BoolVectorAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<Bool>.descriptorSchema(), IVector<Bool>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVector<Bool>.descriptor())
}

func createGenericBuilderBoolVectorViewAbiTest(items: ArrayList<Bool>): IVectorView<Bool> {
    let impl = GenericBuilderBoolVectorViewAbiTestImpl(items)
    let schemas = [IIterable<Bool>.descriptorSchema(), IVectorView<Bool>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IVectorView<Bool>.descriptor())
}

@Test
func testBoolVectorUsesDirectValueAbiForMutableSlots() {
    let vector = createBoolVectorAbiTest(ArrayList<Bool>([true, false]))

    @Expect(unsafe { vector.GetAt(0u32) }, true)
    @Expect(unsafe { vector.GetAt(1u32) }, false)
    unsafe { vector.SetAt(1u32, true) }
    @Expect(unsafe { vector.GetAt(1u32) }, true)
    unsafe { vector.InsertAt(1u32, false) }
    @Expect(unsafe { vector.GetAt(1u32) }, false)
    unsafe { vector.Append(true) }
    @Expect(unsafe { vector.Size() }, 4u32)

    var index = 99u32
    @Expect(unsafe { vector.IndexOf(false, CPointer<UInt32>(inout index)) }, true)
    @Expect(index, 1u32)

    let vtbl = unsafe { vector.vtbl() }
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Bool) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, false) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, false)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Bool) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 0u32, true) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, true)

    let directAppend = CFunc<(CPointer<Unit>, Bool) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), false) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(unsafe { vector.Size() } - 1u32) }, false)

    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Bool, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let indexOfHr = unsafe { directIndexOf(vector.asRaw(), false, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound)) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    vector.close()
}

@Test
func testGenericBoolVectorBuilderUsesDirectValueAbiForSpecialization() {
    let vector = createGenericBuilderBoolVectorAbiTest(ArrayList<Bool>([false]))

    unsafe { vector.Append(true) }
    @Expect(unsafe { vector.GetAt(1u32) }, true)

    let vtbl = unsafe { vector.vtbl() }
    let directAppend = CFunc<(CPointer<Unit>, Bool) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), false) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, false)

    vector.close()
}

@Test
func testGenericBoolVectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderBoolVectorViewAbiTest(ArrayList<Bool>([true, false]))

    var directIndex = 99u32
    var directFound = false
    let vtbl = unsafe { view.vtbl() }
    let directIndexOf = CFunc<(CPointer<Unit>, Bool, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let indexOfHr = unsafe { directIndexOf(view.asRaw(), false, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound)) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}
