package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_POINTER, EventRegistrationToken, EventRegistrationTokenAbi, InParam, Result, WinError, WindowsException, createComObjectFromSchemas}
class ObservableInt32VectorForwardingTestImpl <: IObservableVector_Impl<Int32> & Resource {
    private let items: ArrayList<Int32>
    private let observableVtblHandle: CPointer<IObservableVectorVtbl>
    private let vectorVtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false
    public var failVectorChanged: Bool = false
    public var throwWindowsOnVectorChanged: Bool = false
    public var throwPlainOnRemoveVectorChanged: Bool = false

    public init(items: ArrayList<Int32>) {
        this.items = items
        this.observableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IObservableVectorVtbl>(IObservableVectorVtbl.new<ObservableInt32VectorForwardingTestImpl, Int32>())
        }
        this.vectorVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.newInt32<ObservableInt32VectorForwardingTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<ObservableInt32VectorForwardingTestImpl, Int32>())
        }
    }

    public func observableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(observableVtblHandle)
    }

    public func vectorVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vectorVtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vectorVtblHandle)
            windows_interface.freeNativeValue(observableVtblHandle)
        }
        closed = true
    }

    ~init() {
        if (closed) {
            return
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

    public func VectorChanged(vhnd: InParam<VectorChangedEventHandler<Int32>>): Result<EventRegistrationToken> {
        let _ = vhnd
        if (throwWindowsOnVectorChanged) {
            throw WindowsException(E_POINTER)
        }
        if (failVectorChanged) {
            return Result<EventRegistrationToken>.Err(WinError.fromHRESULT(E_FAIL))
        }
        var token = EventRegistrationToken()
        token.Value = 7i64
        Result<EventRegistrationToken>.Ok(token)
    }

    public func RemoveVectorChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        if (throwPlainOnRemoveVectorChanged) {
            throw Exception("RemoveVectorChanged failure")
        }
        Result<Unit>.Ok(())
    }
}

func createObservableInt32VectorForwardingTest(values: ArrayList<Int32>): IObservableVector<Int32> {
    let impl = ObservableInt32VectorForwardingTestImpl(values)
    let schemas = [
        IIterable<Int32>.descriptorSchema(),
        IVector<Int32>.descriptorSchema(),
        IObservableVector<Int32>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vectorVtblPtr(), impl.observableVtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let vector = object.toInterface(IObservableVector<Int32>.descriptor())
    object.close()
    vector
}

@Test
func testObservableVectorForwardsInheritedVectorOperations() {
    let source = ArrayList<Int32>([2i32, 4i32])
    let vector = createObservableInt32VectorForwardingTest(source)

    try {
        unsafe { vector.Append(6i32) }
        unsafe { vector.InsertAt(1u32, 3i32) }
        unsafe { vector.SetAt(0u32, 1i32) }
        @Expect(unsafe { vector.GetAt(0u32) }, 1i32)
        @Expect(unsafe { vector.GetAt(1u32) }, 3i32)
        @Expect(unsafe { vector.GetAt(3u32) }, 6i32)
        @Expect(unsafe { vector.Size() }, 4u32)

        var index = 99u32
        @Expect(unsafe { vector.IndexOf(6i32, CPointer<UInt32>(inout index)) }, true)
        @Expect(index, 3u32)

        unsafe { vector.RemoveAt(1u32) }
        unsafe { vector.RemoveAtEnd() }
        @Expect(unsafe { vector.Size() }, 2u32)

        unsafe { vector.Clear() }
        @Expect(unsafe { vector.Size() }, 0u32)
    } finally {
        vector.close()
    }
}

@Test
func testObservableVectorEventThunksClearTokenAndTranslateExceptions() {
    let impl = ObservableInt32VectorForwardingTestImpl(ArrayList<Int32>([]))
    let schemas = [
        IIterable<Int32>.descriptorSchema(),
        IVector<Int32>.descriptorSchema(),
        IObservableVector<Int32>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vectorVtblPtr(), impl.observableVtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let vector = object.toInterface(IObservableVector<Int32>.descriptor())
    object.close()

    try {
        let vtbl = unsafe { vector.vtbl() }

        impl.failVectorChanged = true
        var failToken = EventRegistrationTokenAbi()
        failToken.Value = 123i64
        let failHr = unsafe {
            vtbl.VectorChanged(vector.asRaw(), CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout failToken))
        }
        @Expect(failHr, E_FAIL.value)
        @Expect(failToken.Value, 0i64)
        impl.failVectorChanged = false

        impl.throwWindowsOnVectorChanged = true
        var throwToken = EventRegistrationTokenAbi()
        throwToken.Value = 456i64
        let throwHr = unsafe {
            vtbl.VectorChanged(vector.asRaw(), CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout throwToken))
        }
        @Expect(throwHr, E_POINTER.value)
        @Expect(throwToken.Value, 0i64)
        impl.throwWindowsOnVectorChanged = false

        impl.throwPlainOnRemoveVectorChanged = true
        var token = EventRegistrationTokenAbi()
        token.Value = 7i64
        @Expect(unsafe { vtbl.RemoveVectorChanged(vector.asRaw(), token) }, E_FAIL.value)
        impl.throwPlainOnRemoveVectorChanged = false
    } finally {
        vector.close()
    }
}
