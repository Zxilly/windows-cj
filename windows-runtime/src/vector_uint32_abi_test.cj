package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

class UInt32VectorAbiTestImpl <: IVector_Impl<UInt32> & Resource {
    private let items: ArrayList<UInt32>
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<UInt32>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newUInt32<UInt32VectorAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<UInt32VectorAbiTestImpl, UInt32>())
        }
    }

    public static func withGenericVtbl(items: ArrayList<UInt32>): UInt32VectorAbiTestImpl {
        UInt32VectorAbiTestImpl(items, genericVtbl: true)
    }

    private init(items: ArrayList<UInt32>, genericVtbl!: Bool) {
        this.items = items
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new<UInt32VectorAbiTestImpl, UInt32>())
            } else {
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newUInt32<UInt32VectorAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<UInt32VectorAbiTestImpl, UInt32>())
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

    public func First(): Result<IIterator<UInt32>> {
        Result<IIterator<UInt32>>.Ok(toIterator<UInt32>(items))
    }

    public func GetAt(index: UInt32): Result<UInt32> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<UInt32>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<UInt32>.Ok(value)
            case None => Result<UInt32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<UInt32>> {
        Result<IVectorView<UInt32>>.Ok(createGenericBuilderUInt32VectorViewAbiTest(items))
    }

    public func IndexOf(value: UInt32, indexSlot: CPointer<UInt32>): Result<Bool> {
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

    public func SetAt(index: UInt32, value: UInt32): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: UInt32): Result<Unit> {
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

    public func Append(value: UInt32): Result<Unit> {
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
        writeGenericManyRange<UInt32>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<UInt32>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {
            items.add(unsafe { (typed + Int64(offset)).read() })
            offset += 1u32
        }
        Result<Unit>.Ok(())
    }
}

class GenericBuilderUInt32VectorViewAbiTestImpl <: IVectorView_Impl<UInt32> & Resource {
    private let items: ArrayList<UInt32>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<UInt32>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.new<GenericBuilderUInt32VectorViewAbiTestImpl, UInt32>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<GenericBuilderUInt32VectorViewAbiTestImpl, UInt32>())
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

    public func First(): Result<IIterator<UInt32>> {
        Result<IIterator<UInt32>>.Ok(toIterator<UInt32>(items))
    }

    public func GetAt(index: UInt32): Result<UInt32> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<UInt32>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<UInt32>.Ok(value)
            case None => Result<UInt32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: UInt32, indexSlot: CPointer<UInt32>): Result<Bool> {
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
        writeGenericManyRange<UInt32>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createUInt32VectorAbiTest(items: ArrayList<UInt32>): IVector<UInt32> {
    let impl = UInt32VectorAbiTestImpl(items)
    let schemas = [IIterable<UInt32>.descriptorSchema(), IVector<UInt32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVector<UInt32>.descriptor())
    object.close()
    result
}

func createGenericBuilderUInt32VectorAbiTest(items: ArrayList<UInt32>): IVector<UInt32> {
    let impl = UInt32VectorAbiTestImpl.withGenericVtbl(items)
    let schemas = [IIterable<UInt32>.descriptorSchema(), IVector<UInt32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVector<UInt32>.descriptor())
    object.close()
    result
}

func createGenericBuilderUInt32VectorViewAbiTest(items: ArrayList<UInt32>): IVectorView<UInt32> {
    let impl = GenericBuilderUInt32VectorViewAbiTestImpl(items)
    let schemas = [IIterable<UInt32>.descriptorSchema(), IVectorView<UInt32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<UInt32>.descriptor())
    object.close()
    result
}

@Test
func testUInt32VectorUsesDirectValueAbiForMutableSlots() {
    let source = ArrayList<UInt32>([4u32, 6u32])
    let vector = createUInt32VectorAbiTest(source)

    @Expect(unsafe { vector.GetAt(1u32) }, 6u32)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4u32, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6u32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, UInt32) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40u32) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40u32)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, UInt32) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50u32) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50u32)

    let directAppend = CFunc<(CPointer<Unit>, UInt32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60u32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60u32)

    vector.close()
}

@Test
func testGenericUInt32VectorBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<UInt32>([1u32, 2u32])
    let vector = createGenericBuilderUInt32VectorAbiTest(source)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        2u32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directAppend = CFunc<(CPointer<Unit>, UInt32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 3u32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 3u32)

    vector.close()
}

@Test
func testGenericVectorVtblNoneBranchClearsOutSlots() {
    let vtbl = IVectorVtbl.new<UInt32VectorAbiTestImpl, UInt32>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(789i32) }
    let raw = CPointer<Unit>(objectHandle)
    var getAtResult = CPointer<Unit>(sentinel)
    var sizeResult = 77u32
    var getViewResult = CPointer<Unit>(sentinel)
    var indexResult = 66u32
    var foundResult = true
    var copiedResult = 88u32

    try {
        let getAtHr = unsafe { vtbl.GetAt(raw, 0u32, CPointer<CPointer<Unit>>(inout getAtResult)) }
        @Expect(getAtHr, E_NOINTERFACE.value)
        @Expect(getAtResult.isNull(), true)

        let sizeHr = unsafe { vtbl.Size(raw, CPointer<UInt32>(inout sizeResult)) }
        @Expect(sizeHr, E_NOINTERFACE.value)
        @Expect(sizeResult, 0u32)

        let getViewHr = unsafe { vtbl.GetView(raw, CPointer<CPointer<Unit>>(inout getViewResult)) }
        @Expect(getViewHr, E_NOINTERFACE.value)
        @Expect(getViewResult.isNull(), true)

        let directIndexOf = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
            CPointer<Unit>(vtbl.IndexOf)
        )
        let indexOfHr = unsafe {
            directIndexOf(raw, 99u32, CPointer<UInt32>(inout indexResult), CPointer<Bool>(inout foundResult))
        }
        @Expect(indexOfHr, E_NOINTERFACE.value)
        @Expect(indexResult, 0u32)
        @Expect(foundResult, false)

        let getManyHr = unsafe {
            vtbl.GetMany(raw, 0u32, 0u32, CPointer<Unit>(), CPointer<UInt32>(inout copiedResult))
        }
        @Expect(getManyHr, E_NOINTERFACE.value)
        @Expect(copiedResult, 0u32)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

@Test
func testUInt32VectorViewVtblNoneBranchClearsIndexOfSlots() {
    let vtbl = IVectorViewVtbl.newUInt32<GenericBuilderUInt32VectorViewAbiTestImpl>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorViewVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorViewVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)
    var indexResult = 55u32
    var foundResult = true

    try {
        let directIndexOf = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
            CPointer<Unit>(vtbl.IndexOf)
        )
        let indexOfHr = unsafe {
            directIndexOf(raw, 9u32, CPointer<UInt32>(inout indexResult), CPointer<Bool>(inout foundResult))
        }
        @Expect(indexOfHr, E_NOINTERFACE.value)
        @Expect(indexResult, 0u32)
        @Expect(foundResult, false)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

@Test
func testGenericUInt32VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<UInt32>([7u32, 9u32])
    let view = createGenericBuilderUInt32VectorViewAbiTest(source)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7u32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
