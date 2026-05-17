package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}

func dateTimeTestValue(value: Int64): DateTime {
    var result = DateTime()
    result.UniversalTime = value
    return result
}

func sameDateTimeValue(left: DateTime, right: DateTime): Bool {
    left.UniversalTime == right.UniversalTime
}

class DateTimeVectorAbiTestImpl <: IVector_Impl<DateTime> & Resource {
    private let items: ArrayList<DateTime>
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<DateTime>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newDateTime<DateTimeVectorAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<DateTimeVectorAbiTestImpl, DateTime>())
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

    public func First(): Result<IIterator<DateTime>> {
        Result<IIterator<DateTime>>.Ok(toIterator<DateTime>(items))
    }

    public func GetAt(index: UInt32): Result<DateTime> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<DateTime>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<DateTime>.Ok(value)
            case None => Result<DateTime>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<DateTime>> {
        Result<IVectorView<DateTime>>.Ok(createDateTimeVectorViewAbiTest(items))
    }

    public func IndexOf(value: DateTime, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (sameDateTimeValue(candidate, value)) {
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

    public func SetAt(index: UInt32, value: DateTime): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: DateTime): Result<Unit> {
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

    public func Append(value: DateTime): Result<Unit> {
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
        writeGenericManyRange<DateTime>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let typed = CPointer<DateTimeAbi>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {
            items.add(DateTime.assumeInitRef(unsafe { (typed + Int64(offset)).read() }))
            offset += 1u32
        }
        Result<Unit>.Ok(())
    }
}

class DateTimeVectorViewAbiTestImpl <: IVectorView_Impl<DateTime> & Resource {
    private let items: ArrayList<DateTime>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<DateTime>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.newDateTime<DateTimeVectorViewAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<DateTimeVectorViewAbiTestImpl, DateTime>())
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

    public func First(): Result<IIterator<DateTime>> {
        Result<IIterator<DateTime>>.Ok(toIterator<DateTime>(items))
    }

    public func GetAt(index: UInt32): Result<DateTime> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<DateTime>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<DateTime>.Ok(value)
            case None => Result<DateTime>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: DateTime, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (sameDateTimeValue(candidate, value)) {
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
        writeGenericManyRange<DateTime>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createDateTimeVectorAbiTest(values: ArrayList<DateTime>): IVector<DateTime> {
    let impl = DateTimeVectorAbiTestImpl(values)
    let schemas = [IIterable<DateTime>.descriptorSchema(), IVector<DateTime>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVector<DateTime>.descriptor())
    object.close()
    result
}

func createDateTimeVectorViewAbiTest(values: ArrayList<DateTime>): IVectorView<DateTime> {
    let impl = DateTimeVectorViewAbiTestImpl(values)
    let schemas = [IIterable<DateTime>.descriptorSchema(), IVectorView<DateTime>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<DateTime>.descriptor())
    object.close()
    result
}

@Test
func testDateTimeVectorViewUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<DateTime>([dateTimeTestValue(10i64), dateTimeTestValue(20i64), dateTimeTestValue(30i64)])
    let view = createDateTimeVectorViewAbiTest(source)

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(dateTimeTestValue(20i64), CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, DateTimeAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(view.asRaw(), DateTime.projectAbi(dateTimeTestValue(30i64)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 2u32)

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let outputHandle = unsafe { acquireArrayRawData(Array<DateTimeAbi>(2, { _ => DateTimeAbi() })) }
    try {
        let output = CPointer<DateTimeAbi>(outputHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(view.asRaw(), 1u32, 2u32, CPointer<Unit>(output), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 2u32)
        @Expect(DateTime.assumeInitRef(unsafe { output.read() }).UniversalTime, 20i64)
        @Expect(DateTime.assumeInitRef(unsafe { (output + 1).read() }).UniversalTime, 30i64)
    } finally {
        unsafe { releaseArrayRawData(outputHandle) }
    }

    view.close()
}

@Test
func testDateTimeVectorUsesDirectValueAbiForMutableSlots() {
    let source = ArrayList<DateTime>([dateTimeTestValue(1i64), dateTimeTestValue(3i64)])
    let vector = createDateTimeVectorAbiTest(source)

    unsafe { vector.SetAt(0u32, dateTimeTestValue(2i64)) }
    unsafe { vector.InsertAt(1u32, dateTimeTestValue(4i64)) }
    unsafe { vector.Append(dateTimeTestValue(6i64)) }
    @Expect(unsafe { vector.GetAt(0u32) }.UniversalTime, 2i64)
    @Expect(unsafe { vector.GetAt(1u32) }.UniversalTime, 4i64)
    @Expect(unsafe { vector.GetAt(3u32) }.UniversalTime, 6i64)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, DateTimeAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(vector.asRaw(), DateTime.projectAbi(dateTimeTestValue(6i64)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 3u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, DateTimeAbi) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 2u32, DateTime.projectAbi(dateTimeTestValue(5i64))) }
    @Expect(setHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }.UniversalTime, 5i64)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, DateTimeAbi) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 2u32, DateTime.projectAbi(dateTimeTestValue(7i64))) }
    @Expect(insertHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }.UniversalTime, 7i64)

    let directAppend = CFunc<(CPointer<Unit>, DateTimeAbi) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), DateTime.projectAbi(dateTimeTestValue(8i64))) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(5u32) }.UniversalTime, 8i64)

    let directReplaceAll = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.ReplaceAll))
    let replaceHandle = unsafe {
        acquireArrayRawData(Array<DateTimeAbi>(2, { i => DateTime.projectAbi(dateTimeTestValue(Int64(i) + 21i64)) }))
    }
    try {
        let replaceHr = unsafe { directReplaceAll(vector.asRaw(), 2u32, CPointer<Unit>(replaceHandle.pointer)) }
        @Expect(replaceHr, S_OK.value)
    } finally {
        unsafe { releaseArrayRawData(replaceHandle) }
    }
    @Expect(unsafe { vector.Size() }, 2u32)
    @Expect(unsafe { vector.GetAt(0u32) }.UniversalTime, 21i64)
    @Expect(unsafe { vector.GetAt(1u32) }.UniversalTime, 22i64)

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let outputHandle = unsafe { acquireArrayRawData(Array<DateTimeAbi>(2, { _ => DateTimeAbi() })) }
    try {
        let output = CPointer<DateTimeAbi>(outputHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(vector.asRaw(), 0u32, 2u32, CPointer<Unit>(output), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 2u32)
        @Expect(DateTime.assumeInitRef(unsafe { output.read() }).UniversalTime, 21i64)
        @Expect(DateTime.assumeInitRef(unsafe { (output + 1).read() }).UniversalTime, 22i64)
    } finally {
        unsafe { releaseArrayRawData(outputHandle) }
    }

    let nullReplaceHr = unsafe { directReplaceAll(vector.asRaw(), 1u32, CPointer<Unit>()) }
    @Expect(nullReplaceHr, E_POINTER.value)

    vector.close()
}
