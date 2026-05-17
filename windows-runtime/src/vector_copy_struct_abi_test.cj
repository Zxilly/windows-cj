package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, GuidValue, Result, S_OK, RuntimeType, WinError, WinrtGenericType, createComObjectFromSchemas}
import windows_interface.GUID

func timeSpanTestValue(value: Int64): TimeSpan {
    var result = TimeSpan()
    result.Duration = value
    return result
}

func pointTestValue(x: Float32, y: Float32): Point {
    var result = Point()
    result.X = x
    result.Y = y
    return result
}

func sizeTestValue(width: Float32, height: Float32): Size {
    var result = Size()
    result.Width = width
    result.Height = height
    return result
}

func rectTestValue(x: Float32, y: Float32, width: Float32, height: Float32): Rect {
    var result = Rect()
    result.X = x
    result.Y = y
    result.Width = width
    result.Height = height
    return result
}

func guidTestValue(value: UInt32): GuidValue {
    GuidValue.from_values(value, 0x4455u16, 0x6677u16, 0x88u8, 0x99u8, 0xAAu8, 0xBBu8, 0xCCu8, 0xDDu8, 0xEEu8, 0xFFu8)
}

func sameTimeSpanValue(left: TimeSpan, right: TimeSpan): Bool {
    left.Duration == right.Duration
}

func samePointValue(left: Point, right: Point): Bool {
    left.X == right.X && left.Y == right.Y
}

func sameSizeValue(left: Size, right: Size): Bool {
    left.Width == right.Width && left.Height == right.Height
}

func sameRectValue(left: Rect, right: Rect): Bool {
    left.X == right.X && left.Y == right.Y && left.Width == right.Width && left.Height == right.Height
}

func sameGuidValue(left: GuidValue, right: GuidValue): Bool {
    left == right
}

class CopyStructVectorAbiTestImpl<T> <: IVector_Impl<T> & Resource where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let equals: (T, T) -> Bool
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<T>, equals: (T, T) -> Bool) {
        this.items = items
        this.equals = equals
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(copyStructVectorVtbl<T>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<CopyStructVectorAbiTestImpl<T>, T>())
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

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(toIterator<T>(items))
    }

    public func GetAt(index: UInt32): Result<T> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<T>> {
        Result<IVectorView<T>>.Ok(createCopyStructVectorViewAbiTest<T>(items, equals))
    }

    public func IndexOf(value: T, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (this.equals(candidate, value)) {
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

    public func SetAt(index: UInt32, value: T): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: T): Result<Unit> {
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

    public func Append(value: T): Result<Unit> {
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
        writeGenericManyRange<T>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        Result<Unit>.Ok(())
    }
}

class CopyStructVectorViewAbiTestImpl<T> <: IVectorView_Impl<T> & Resource where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let equals: (T, T) -> Bool
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<T>, equals: (T, T) -> Bool) {
        this.items = items
        this.equals = equals
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(copyStructVectorViewVtbl<T>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<CopyStructVectorViewAbiTestImpl<T>, T>())
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

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(toIterator<T>(items))
    }

    public func GetAt(index: UInt32): Result<T> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: T, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (this.equals(candidate, value)) {
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
        writeGenericManyRange<T>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createCopyStructVectorAbiTest<T>(
    values: ArrayList<T>,
    equals: (T, T) -> Bool
): IVector<T> where T <: RuntimeType & WinrtGenericType<T> {
    let impl = CopyStructVectorAbiTestImpl<T>(values, equals)
    let schemas = [IIterable<T>.descriptorSchema(), IVector<T>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVector<T>.descriptor())
    object.close()
    result
}

func createCopyStructVectorViewAbiTest<T>(
    values: ArrayList<T>,
    equals: (T, T) -> Bool
): IVectorView<T> where T <: RuntimeType & WinrtGenericType<T> {
    let impl = CopyStructVectorViewAbiTestImpl<T>(values, equals)
    let schemas = [IIterable<T>.descriptorSchema(), IVectorView<T>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<T>.descriptor())
    object.close()
    result
}

func copyStructVectorVtbl<T>(): IVectorVtbl where T <: RuntimeType & WinrtGenericType<T> {
    match (TimeSpan() as T) {
        case Some(_) => return IVectorVtbl.newTimeSpan<CopyStructVectorAbiTestImpl<TimeSpan>>()
        case None => ()
    }
    match (GuidValue() as T) {
        case Some(_) => return IVectorVtbl.newGuidValue<CopyStructVectorAbiTestImpl<GuidValue>>()
        case None => ()
    }
    match (Point() as T) {
        case Some(_) => return IVectorVtbl.newPoint<CopyStructVectorAbiTestImpl<Point>>()
        case None => ()
    }
    match (Size() as T) {
        case Some(_) => return IVectorVtbl.newSize<CopyStructVectorAbiTestImpl<Size>>()
        case None => ()
    }
    match (Rect() as T) {
        case Some(_) => return IVectorVtbl.newRect<CopyStructVectorAbiTestImpl<Rect>>()
        case None => ()
    }
    throw IllegalArgumentException("unsupported copy struct vector test type")
}

func copyStructVectorViewVtbl<T>(): IVectorViewVtbl where T <: RuntimeType & WinrtGenericType<T> {
    match (TimeSpan() as T) {
        case Some(_) => return IVectorViewVtbl.newTimeSpan<CopyStructVectorViewAbiTestImpl<TimeSpan>>()
        case None => ()
    }
    match (GuidValue() as T) {
        case Some(_) => return IVectorViewVtbl.newGuidValue<CopyStructVectorViewAbiTestImpl<GuidValue>>()
        case None => ()
    }
    match (Point() as T) {
        case Some(_) => return IVectorViewVtbl.newPoint<CopyStructVectorViewAbiTestImpl<Point>>()
        case None => ()
    }
    match (Size() as T) {
        case Some(_) => return IVectorViewVtbl.newSize<CopyStructVectorViewAbiTestImpl<Size>>()
        case None => ()
    }
    match (Rect() as T) {
        case Some(_) => return IVectorViewVtbl.newRect<CopyStructVectorViewAbiTestImpl<Rect>>()
        case None => ()
    }
    throw IllegalArgumentException("unsupported copy struct vector-view test type")
}

func verifyTimeSpanVectorViewDirectAbi(): Unit {
    let view = createCopyStructVectorViewAbiTest<TimeSpan>(
        ArrayList<TimeSpan>([timeSpanTestValue(10i64), timeSpanTestValue(20i64)]),
        sameTimeSpanValue
    )
    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, TimeSpanAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let hr = unsafe {
        directIndexOf(view.asRaw(), TimeSpan.projectAbi(timeSpanTestValue(20i64)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(hr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)
    view.close()
}

func verifyGuidVectorViewDirectAbi(): Unit {
    let view = createCopyStructVectorViewAbiTest<GuidValue>(
        ArrayList<GuidValue>([guidTestValue(1u32), guidTestValue(2u32)]),
        sameGuidValue
    )
    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, GUID, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let hr = unsafe {
        directIndexOf(view.asRaw(), GuidValue.projectAbi(guidTestValue(2u32)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(hr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)
    view.close()
}

func verifyPointVectorViewDirectAbi(): Unit {
    let view = createCopyStructVectorViewAbiTest<Point>(
        ArrayList<Point>([pointTestValue(1.0f32, 2.0f32), pointTestValue(3.0f32, 4.0f32)]),
        samePointValue
    )
    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, PointAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let hr = unsafe {
        directIndexOf(view.asRaw(), Point.projectAbi(pointTestValue(3.0f32, 4.0f32)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(hr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)
    view.close()
}

func verifySizeVectorViewDirectAbi(): Unit {
    let view = createCopyStructVectorViewAbiTest<Size>(
        ArrayList<Size>([sizeTestValue(1.0f32, 2.0f32), sizeTestValue(3.0f32, 4.0f32)]),
        sameSizeValue
    )
    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, SizeAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let hr = unsafe {
        directIndexOf(view.asRaw(), Size.projectAbi(sizeTestValue(3.0f32, 4.0f32)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(hr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)
    view.close()
}

func verifyRectVectorViewDirectAbi(): Unit {
    let view = createCopyStructVectorViewAbiTest<Rect>(
        ArrayList<Rect>([rectTestValue(1.0f32, 2.0f32, 3.0f32, 4.0f32), rectTestValue(5.0f32, 6.0f32, 7.0f32, 8.0f32)]),
        sameRectValue
    )
    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, RectAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let hr = unsafe {
        directIndexOf(view.asRaw(), Rect.projectAbi(rectTestValue(5.0f32, 6.0f32, 7.0f32, 8.0f32)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(hr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)
    view.close()
}

func verifyTimeSpanVectorDirectMutableAbi(): Unit {
    let vector = createCopyStructVectorAbiTest<TimeSpan>(
        ArrayList<TimeSpan>([timeSpanTestValue(1i64), timeSpanTestValue(3i64)]),
        sameTimeSpanValue
    )
    let vtbl = unsafe { vector.vtbl() }
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, TimeSpanAbi) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 0u32, TimeSpan.projectAbi(timeSpanTestValue(2i64))) }
    @Expect(setHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }.Duration, 2i64)
    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, TimeSpanAbi) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 1u32, TimeSpan.projectAbi(timeSpanTestValue(4i64))) }
    @Expect(insertHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }.Duration, 4i64)
    let directAppend = CFunc<(CPointer<Unit>, TimeSpanAbi) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), TimeSpan.projectAbi(timeSpanTestValue(6i64))) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }.Duration, 6i64)
    vector.close()
}

func verifyGuidVectorDirectMutableAbi(): Unit {
    let vector = createCopyStructVectorAbiTest<GuidValue>(
        ArrayList<GuidValue>([guidTestValue(1u32), guidTestValue(3u32)]),
        sameGuidValue
    )
    let vtbl = unsafe { vector.vtbl() }
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, GUID) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 0u32, GuidValue.projectAbi(guidTestValue(2u32))) }
    @Expect(setHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) } == guidTestValue(2u32), true)
    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, GUID) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 1u32, GuidValue.projectAbi(guidTestValue(4u32))) }
    @Expect(insertHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) } == guidTestValue(4u32), true)
    let directAppend = CFunc<(CPointer<Unit>, GUID) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), GuidValue.projectAbi(guidTestValue(6u32))) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) } == guidTestValue(6u32), true)
    vector.close()
}

func verifyPointVectorDirectMutableAbi(): Unit {
    let vector = createCopyStructVectorAbiTest<Point>(
        ArrayList<Point>([pointTestValue(1.0f32, 2.0f32), pointTestValue(3.0f32, 4.0f32)]),
        samePointValue
    )
    let vtbl = unsafe { vector.vtbl() }
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, PointAbi) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 0u32, Point.projectAbi(pointTestValue(2.0f32, 3.0f32))) }
    @Expect(setHr, S_OK.value)
    @Expect(samePointValue(unsafe { vector.GetAt(0u32) }, pointTestValue(2.0f32, 3.0f32)), true)
    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, PointAbi) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 1u32, Point.projectAbi(pointTestValue(4.0f32, 5.0f32))) }
    @Expect(insertHr, S_OK.value)
    @Expect(samePointValue(unsafe { vector.GetAt(1u32) }, pointTestValue(4.0f32, 5.0f32)), true)
    let directAppend = CFunc<(CPointer<Unit>, PointAbi) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), Point.projectAbi(pointTestValue(6.0f32, 7.0f32))) }
    @Expect(appendHr, S_OK.value)
    @Expect(samePointValue(unsafe { vector.GetAt(3u32) }, pointTestValue(6.0f32, 7.0f32)), true)
    vector.close()
}

func verifySizeVectorDirectMutableAbi(): Unit {
    let vector = createCopyStructVectorAbiTest<Size>(
        ArrayList<Size>([sizeTestValue(1.0f32, 2.0f32), sizeTestValue(3.0f32, 4.0f32)]),
        sameSizeValue
    )
    let vtbl = unsafe { vector.vtbl() }
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, SizeAbi) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 0u32, Size.projectAbi(sizeTestValue(2.0f32, 3.0f32))) }
    @Expect(setHr, S_OK.value)
    @Expect(sameSizeValue(unsafe { vector.GetAt(0u32) }, sizeTestValue(2.0f32, 3.0f32)), true)
    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, SizeAbi) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 1u32, Size.projectAbi(sizeTestValue(4.0f32, 5.0f32))) }
    @Expect(insertHr, S_OK.value)
    @Expect(sameSizeValue(unsafe { vector.GetAt(1u32) }, sizeTestValue(4.0f32, 5.0f32)), true)
    let directAppend = CFunc<(CPointer<Unit>, SizeAbi) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), Size.projectAbi(sizeTestValue(6.0f32, 7.0f32))) }
    @Expect(appendHr, S_OK.value)
    @Expect(sameSizeValue(unsafe { vector.GetAt(3u32) }, sizeTestValue(6.0f32, 7.0f32)), true)
    vector.close()
}

func verifyRectVectorDirectMutableAbi(): Unit {
    let vector = createCopyStructVectorAbiTest<Rect>(
        ArrayList<Rect>([rectTestValue(1.0f32, 2.0f32, 3.0f32, 4.0f32), rectTestValue(5.0f32, 6.0f32, 7.0f32, 8.0f32)]),
        sameRectValue
    )
    let vtbl = unsafe { vector.vtbl() }
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, RectAbi) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 0u32, Rect.projectAbi(rectTestValue(2.0f32, 3.0f32, 4.0f32, 5.0f32))) }
    @Expect(setHr, S_OK.value)
    @Expect(sameRectValue(unsafe { vector.GetAt(0u32) }, rectTestValue(2.0f32, 3.0f32, 4.0f32, 5.0f32)), true)
    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, RectAbi) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 1u32, Rect.projectAbi(rectTestValue(4.0f32, 5.0f32, 6.0f32, 7.0f32))) }
    @Expect(insertHr, S_OK.value)
    @Expect(sameRectValue(unsafe { vector.GetAt(1u32) }, rectTestValue(4.0f32, 5.0f32, 6.0f32, 7.0f32)), true)
    let directAppend = CFunc<(CPointer<Unit>, RectAbi) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), Rect.projectAbi(rectTestValue(6.0f32, 7.0f32, 8.0f32, 9.0f32))) }
    @Expect(appendHr, S_OK.value)
    @Expect(sameRectValue(unsafe { vector.GetAt(3u32) }, rectTestValue(6.0f32, 7.0f32, 8.0f32, 9.0f32)), true)
    vector.close()
}

@Test
func testRemainingCopyVectorViewsUseDirectValueAbiForSpecializations() {
    verifyTimeSpanVectorViewDirectAbi()
    verifyGuidVectorViewDirectAbi()
    verifyPointVectorViewDirectAbi()
    verifySizeVectorViewDirectAbi()
    verifyRectVectorViewDirectAbi()
}

@Test
func testRemainingCopyVectorsUseDirectValueAbiForMutableSlots() {
    verifyTimeSpanVectorDirectMutableAbi()
    verifyGuidVectorDirectMutableAbi()
    verifyPointVectorDirectMutableAbi()
    verifySizeVectorDirectMutableAbi()
    verifyRectVectorDirectMutableAbi()
}
