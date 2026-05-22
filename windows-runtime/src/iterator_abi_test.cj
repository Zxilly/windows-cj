package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOINTERFACE, E_POINTER, HString, Result, RuntimeType, S_OK, WindowsException, WinrtGenericType, createComObjectFromSchemas}
import windows_interface.IInspectable
import windows_strings.releaseSystemHStringHandle

let iterableFirstPartialReleaseCalls = AtomicInt64(0)
var iterableFirstPartialRaw = CPointer<Unit>()

@C
func iterableFirstPartialReleaseThunk(raw: CPointer<Unit>): UInt32 {
    let oldCount = iterableFirstPartialReleaseCalls.fetchAdd(1)
    if (raw.isNotNull()) {
        unsafe { windows_interface.freeNativeValue(CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw)) }
    }
    UInt32(oldCount + 1)
}

@C
func iterableFirstFailingPartialThunk(_: CPointer<Unit>, result: CPointer<CPointer<Unit>>): Int32 {
    if (result.isNotNull()) {
        unsafe { result.write(iterableFirstPartialRaw) }
    }
    E_FAIL.value
}

func failingIterableFirstVtbl(): IIterableVtbl {
    var vtbl = IIterableVtbl()
    vtbl.First = iterableFirstFailingPartialThunk
    vtbl
}

func iterableFirstPartialIUnknownVtbl(): windows_interface.IUnknownVtbl {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = iterableFirstPartialReleaseThunk
    vtbl
}

func withFailingIterableFirstRaw(action: (CPointer<Unit>) -> Unit): Unit {
    iterableFirstPartialReleaseCalls.store(0)
    let partialVtblHandle = unsafe {
        windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(iterableFirstPartialIUnknownVtbl())
    }
    let partialObjectHandle = unsafe {
        windows_interface.allocateNativeValue<CPointer<windows_interface.IUnknownVtbl>>(partialVtblHandle)
    }
    iterableFirstPartialRaw = CPointer<Unit>(partialObjectHandle)

    let iterableVtblHandle = unsafe { windows_interface.allocateNativeValue<IIterableVtbl>(failingIterableFirstVtbl()) }
    let iterableObjectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IIterableVtbl>>(iterableVtblHandle) }
    try {
        action(CPointer<Unit>(iterableObjectHandle))
    } finally {
        unsafe {
            windows_interface.freeNativeValue(iterableObjectHandle)
            windows_interface.freeNativeValue(iterableVtblHandle)
            if (iterableFirstPartialReleaseCalls.load() == 0) {
                windows_interface.freeNativeValue(partialObjectHandle)
            }
            windows_interface.freeNativeValue(partialVtblHandle)
        }
        iterableFirstPartialRaw = CPointer<Unit>()
    }
}

@Test
func testIIterableFirstReleasesFailedPartialIteratorOutput() {
    withFailingIterableFirstRaw({ raw: CPointer<Unit> =>
        let iterable = IIterable<IInspectable>.viewOf(raw)
        var failed = false
        try {
            let iterator = unsafe { iterable.First() }
            iterator.close()
        } catch (_: WindowsException) {
            failed = true
        }
        @Expect(failed, true)
        @Expect(iterableFirstPartialReleaseCalls.load(), 1)
    })
}

class CopyIteratorAbiTestImpl<T> <: IIterator_Impl<T> & Resource where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let vtblHandle: CPointer<IIteratorVtbl>
    private var closed: Bool = false
    private var index: Int64 = 0

    public init(values: ArrayList<T>) {
        this.items = ArrayList<T>(values.size, { itemIndex => values[itemIndex] })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIteratorVtbl>(IIteratorVtbl.new<CopyIteratorAbiTestImpl<T>, T>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
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

    public func Current(): Result<T> {
        if (index < 0 || index >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(index)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func HasCurrent(): Result<Bool> {
        Result<Bool>.Ok(index >= 0 && index < items.size)
    }

    public func MoveNext(): Result<Bool> {
        if (index < items.size) {
            index += 1
        }
        Result<Bool>.Ok(index < items.size)
    }

    public func GetMany(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        match (writeGenericManyRange<T>(itemsSize, itemsBuffer, items, index)) {
            case Result<UInt32>.Ok(count) =>
                index += Int64(count)
                Result<UInt32>.Ok(count)
            case Result<UInt32>.Err(error) =>
                Result<UInt32>.Err(error)
        }
    }
}

func createCopyIteratorAbiTest<T>(values: ArrayList<T>): IIterator<T> where T <: RuntimeType & WinrtGenericType<T> {
    let impl = CopyIteratorAbiTestImpl<T>(values)
    let object = createComObjectFromSchemas(impl, [IIterator<T>.descriptorSchema()], impl.vtblPtr())
    let result = object.toInterface(IIterator<T>.descriptor())
    object.close()
    result
}

@Test
func testIteratorVtblNoneBranchClearsGenericOutputs() {
    let vtbl = IIteratorVtbl.new<CopyIteratorAbiTestImpl<Int32>, Int32>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IIteratorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IIteratorVtbl>>(vtblHandle) }
    let currentSentinel = unsafe { windows_interface.allocateNativeValue<Int32>(111i32) }
    var currentRaw = CPointer<Unit>(currentSentinel)
    var copied = 77u32

    try {
        let currentHr = unsafe { vtbl.Current(CPointer<Unit>(objectHandle), CPointer<CPointer<Unit>>(inout currentRaw)) }
        @Expect(currentHr, E_NOINTERFACE.value)
        @Expect(currentRaw.isNull(), true)

        let manyHr = unsafe { vtbl.GetMany(
            CPointer<Unit>(objectHandle),
            1u32,
            CPointer<Unit>(),
            CPointer<UInt32>(inout copied)
        ) }
        @Expect(manyHr, E_NOINTERFACE.value)
        @Expect(copied, 0u32)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(currentSentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

class HStringIteratorAbiTestImpl <: IIterator_Impl<HString> & Resource {
    private let items: ArrayList<HString>
    private let vtblHandle: CPointer<IIteratorVtbl>
    private var closed: Bool = false
    private var index: Int64 = 0

    public init(values: ArrayList<HString>) {
        this.items = ArrayList<HString>(values.size, { itemIndex => values[itemIndex].clone() })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIteratorVtbl>(IIteratorVtbl.new<HStringIteratorAbiTestImpl, HString>())
        }
    }

    private func drainItems(): Unit {
        var itemIndex = 0
        while (itemIndex < items.size) {
            match (items.get(itemIndex)) {
                case Some(value) => value.close()
                case None => ()
            }
            itemIndex += 1
        }
        items.clear()
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        drainItems()
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
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

    public func Current(): Result<HString> {
        if (index < 0 || index >= items.size) {
            return Result<HString>.Err(stockBoundsError())
        }
        match (items.get(index)) {
            case Some(value) => Result<HString>.Ok(value.clone())
            case None => Result<HString>.Err(stockBoundsError())
        }
    }

    public func HasCurrent(): Result<Bool> {
        Result<Bool>.Ok(index >= 0 && index < items.size)
    }

    public func MoveNext(): Result<Bool> {
        if (index < items.size) {
            index += 1
        }
        Result<Bool>.Ok(index < items.size)
    }

    public func GetMany(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        match (writeGenericManyRange<HString>(itemsSize, itemsBuffer, items, index)) {
            case Result<UInt32>.Ok(count) =>
                index += Int64(count)
                Result<UInt32>.Ok(count)
            case Result<UInt32>.Err(error) =>
                Result<UInt32>.Err(error)
        }
    }
}

func createHStringIteratorAbiTest(values: ArrayList<HString>): IIterator<HString> {
    let impl = HStringIteratorAbiTestImpl(values)
    let object = createComObjectFromSchemas(impl, [IIterator<HString>.descriptorSchema()], impl.vtblPtr())
    let result = object.toInterface(IIterator<HString>.descriptor())
    object.close()
    result
}

func closeIteratorHStringOutputSlot(slot: CPointer<CPointer<Unit>>): Unit {
    let raw = unsafe { slot.read() }
    if (raw.isNotNull()) {
        releaseSystemHStringHandle(raw)
        unsafe { slot.write(CPointer<Unit>()) }
    }
}

func takeIteratorHStringOutputSlot(slot: CPointer<CPointer<Unit>>): HString {
    let raw = unsafe { slot.read() }
    unsafe { slot.write(CPointer<Unit>()) }
    HString.fromSystemHandleTake(raw)
}

class InterfaceIteratorAbiTestImpl <: IIterator_Impl<IInspectable> & Resource {
    private let items: ArrayList<IInspectable>
    private let vtblHandle: CPointer<IIteratorVtbl>
    private var closed: Bool = false
    private var index: Int64 = 0

    public init(values: ArrayList<IInspectable>) {
        this.items = ArrayList<IInspectable>(values.size, { itemIndex => mustRetainInterfaceVectorElement(values[itemIndex]) })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIteratorVtbl>(IIteratorVtbl.new<InterfaceIteratorAbiTestImpl, IInspectable>())
        }
    }

    private func drainItems(): Unit {
        closeInterfaceVectorElements(items)
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        drainItems()
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
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

    public func Current(): Result<IInspectable> {
        if (index < 0 || index >= items.size) {
            return Result<IInspectable>.Err(stockBoundsError())
        }
        match (items.get(index)) {
            case Some(value) => retainInterfaceVectorElement(value)
            case None => Result<IInspectable>.Err(stockBoundsError())
        }
    }

    public func HasCurrent(): Result<Bool> {
        Result<Bool>.Ok(index >= 0 && index < items.size)
    }

    public func MoveNext(): Result<Bool> {
        if (index < items.size) {
            index += 1
        }
        Result<Bool>.Ok(index < items.size)
    }

    public func GetMany(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        match (writeGenericManyRange<IInspectable>(itemsSize, itemsBuffer, items, index)) {
            case Result<UInt32>.Ok(count) =>
                index += Int64(count)
                Result<UInt32>.Ok(count)
            case Result<UInt32>.Err(error) =>
                Result<UInt32>.Err(error)
        }
    }
}

func createInterfaceIteratorAbiTest(values: ArrayList<IInspectable>): IIterator<IInspectable> {
    let impl = InterfaceIteratorAbiTestImpl(values)
    let object = createComObjectFromSchemas(impl, [IIterator<IInspectable>.descriptorSchema()], impl.vtblPtr())
    let result = object.toInterface(IIterator<IInspectable>.descriptor())
    object.close()
    result
}

func closeIteratorInterfaceOutputSlot(slot: CPointer<CPointer<Unit>>): Unit {
    let raw = unsafe { slot.read() }
    if (raw.isNotNull()) {
        IInspectable.fromAbiTake(raw).close()
        unsafe { slot.write(CPointer<Unit>()) }
    }
}

func takeIteratorInterfaceOutputSlot(slot: CPointer<CPointer<Unit>>): IInspectable {
    let raw = unsafe { slot.read() }
    unsafe { slot.write(CPointer<Unit>()) }
    IInspectable.fromAbiTake(raw)
}

@Test
func testInt32IteratorUsesDirectValueAbi() {
    let iterator = createCopyIteratorAbiTest<Int32>(ArrayList<Int32>([11i32, 22i32, 33i32]))

    try {
        @Expect(unsafe { iterator.HasCurrent() }, true)
        @Expect(unsafe { iterator.Current() }, 11i32)
        @Expect(unsafe { iterator.MoveNext() }, true)
        @Expect(unsafe { iterator.Current() }, 22i32)

        let vtbl = unsafe { iterator.vtbl() }
        let directCurrent = CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Current))
        var current = 0i32
        let currentHr = unsafe { directCurrent(iterator.asRaw(), CPointer<Int32>(inout current)) }
        @Expect(currentHr, S_OK.value)
        @Expect(current, 22i32)

        let directGetMany = CFunc<(CPointer<Unit>, UInt32, CPointer<Int32>, CPointer<UInt32>) -> Int32>(
            CPointer<Unit>(vtbl.GetMany)
        )
        let manyHandle = unsafe { acquireArrayRawData(Array<Int32>(2, { _ => 0i32 })) }
        try {
            let manyValues = CPointer<Int32>(manyHandle.pointer)
            var copied = 99u32
            let manyHr = unsafe { directGetMany(iterator.asRaw(), 2u32, manyValues, CPointer<UInt32>(inout copied)) }
            @Expect(manyHr, S_OK.value)
            @Expect(copied, 2u32)
            @Expect(unsafe { manyValues.read() }, 22i32)
            @Expect(unsafe { (manyValues + 1).read() }, 33i32)
        } finally {
            unsafe { releaseArrayRawData(manyHandle) }
        }

        var invalidCopied = 99u32
        let nullBufferHr = unsafe {
            directGetMany(iterator.asRaw(), 1u32, CPointer<Int32>(), CPointer<UInt32>(inout invalidCopied))
        }
        @Expect(nullBufferHr, E_POINTER.value)
        @Expect(invalidCopied, 0u32)
    } finally {
        iterator.close()
    }
}

@Test
func testDateTimeIteratorUsesProjectedCopyStructAbi() {
    let iterator = createCopyIteratorAbiTest<DateTime>(
        ArrayList<DateTime>([dateTimeTestValue(100i64), dateTimeTestValue(200i64), dateTimeTestValue(300i64)])
    )

    try {
        @Expect(unsafe { iterator.HasCurrent() }, true)
        @Expect(unsafe { iterator.Current() }.UniversalTime, 100i64)
        @Expect(unsafe { iterator.MoveNext() }, true)
        @Expect(unsafe { iterator.Current() }.UniversalTime, 200i64)

        let vtbl = unsafe { iterator.vtbl() }
        let directCurrent = CFunc<(CPointer<Unit>, CPointer<DateTimeAbi>) -> Int32>(CPointer<Unit>(vtbl.Current))
        var current = DateTimeAbi()
        let currentHr = unsafe { directCurrent(iterator.asRaw(), CPointer<DateTimeAbi>(inout current)) }
        @Expect(currentHr, S_OK.value)
        @Expect(DateTime.assumeInitRef(current).UniversalTime, 200i64)

        let directGetMany = CFunc<(CPointer<Unit>, UInt32, CPointer<DateTimeAbi>, CPointer<UInt32>) -> Int32>(
            CPointer<Unit>(vtbl.GetMany)
        )
        let manyHandle = unsafe { acquireArrayRawData(Array<DateTimeAbi>(2, { _ => DateTimeAbi() })) }
        try {
            let manyValues = CPointer<DateTimeAbi>(manyHandle.pointer)
            var copied = 99u32
            let manyHr = unsafe { directGetMany(iterator.asRaw(), 2u32, manyValues, CPointer<UInt32>(inout copied)) }
            @Expect(manyHr, S_OK.value)
            @Expect(copied, 2u32)
            @Expect(DateTime.assumeInitRef(unsafe { manyValues.read() }).UniversalTime, 200i64)
            @Expect(DateTime.assumeInitRef(unsafe { (manyValues + 1).read() }).UniversalTime, 300i64)
        } finally {
            unsafe { releaseArrayRawData(manyHandle) }
        }
    } finally {
        iterator.close()
    }
}

@Test
func testHStringIteratorUsesHandleAbi() {
    let first = HString("first")
    let second = HString("second")
    let third = HString("third")
    let iterator = createHStringIteratorAbiTest(ArrayList<HString>([first, second, third]))

    try {
        let wrapperCurrent = unsafe { iterator.Current() }
        try {
            @Expect(wrapperCurrent.get(), "first")
        } finally {
            wrapperCurrent.close()
        }
        @Expect(unsafe { iterator.MoveNext() }, true)

        let vtbl = unsafe { iterator.vtbl() }
        let directCurrent = CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Current))
        var currentRaw = CPointer<Unit>()
        let currentHr = unsafe { directCurrent(iterator.asRaw(), CPointer<CPointer<Unit>>(inout currentRaw)) }
        @Expect(currentHr, S_OK.value)
        let current = HString.fromSystemHandleTake(currentRaw)
        try {
            @Expect(current.get(), "second")
        } finally {
            current.close()
        }

        let directGetMany = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
            CPointer<Unit>(vtbl.GetMany)
        )
        let manyHandle = unsafe { acquireArrayRawData(Array<CPointer<Unit>>(2, { _ => CPointer<Unit>() })) }
        try {
            let slots = CPointer<CPointer<Unit>>(manyHandle.pointer)
            var copied = 99u32
            let manyHr = unsafe { directGetMany(iterator.asRaw(), 2u32, CPointer<Unit>(slots), CPointer<UInt32>(inout copied)) }
            @Expect(manyHr, S_OK.value)
            @Expect(copied, 2u32)
            let firstOut = takeIteratorHStringOutputSlot(slots)
            let secondOut = takeIteratorHStringOutputSlot(unsafe { slots + 1 })
            try {
                @Expect(firstOut.get(), "second")
                @Expect(secondOut.get(), "third")
            } finally {
                firstOut.close()
                secondOut.close()
            }
        } finally {
            let slots = CPointer<CPointer<Unit>>(manyHandle.pointer)
            closeIteratorHStringOutputSlot(slots)
            closeIteratorHStringOutputSlot(unsafe { slots + 1 })
            unsafe { releaseArrayRawData(manyHandle) }
        }

        var invalidCopied = 99u32
        let nullBufferHr = unsafe {
            directGetMany(iterator.asRaw(), 1u32, CPointer<Unit>(), CPointer<UInt32>(inout invalidCopied))
        }
        @Expect(nullBufferHr, E_POINTER.value)
        @Expect(invalidCopied, 0u32)
    } finally {
        iterator.close()
        third.close()
        second.close()
        first.close()
    }
}

@Test
func testInterfaceIteratorUsesHandleAbi() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let third = createInterfaceVectorElement()
    let iterator = createInterfaceIteratorAbiTest(ArrayList<IInspectable>([first, second, third]))

    try {
        let wrapperCurrent = unsafe { iterator.Current() }
        try {
            @Expect(sameInterfaceVectorElement(wrapperCurrent, first), true)
        } finally {
            wrapperCurrent.close()
        }
        @Expect(unsafe { iterator.MoveNext() }, true)

        let vtbl = unsafe { iterator.vtbl() }
        let directCurrent = CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Current))
        var currentRaw = CPointer<Unit>()
        let currentHr = unsafe { directCurrent(iterator.asRaw(), CPointer<CPointer<Unit>>(inout currentRaw)) }
        @Expect(currentHr, S_OK.value)
        let current = IInspectable.fromAbiTake(currentRaw)
        try {
            @Expect(sameInterfaceVectorElement(current, second), true)
        } finally {
            current.close()
        }

        let directGetMany = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
            CPointer<Unit>(vtbl.GetMany)
        )
        let manyHandle = unsafe { acquireArrayRawData(Array<CPointer<Unit>>(2, { _ => CPointer<Unit>() })) }
        try {
            let slots = CPointer<CPointer<Unit>>(manyHandle.pointer)
            var copied = 99u32
            let manyHr = unsafe { directGetMany(iterator.asRaw(), 2u32, CPointer<Unit>(slots), CPointer<UInt32>(inout copied)) }
            @Expect(manyHr, S_OK.value)
            @Expect(copied, 2u32)
            let firstOut = takeIteratorInterfaceOutputSlot(slots)
            let secondOut = takeIteratorInterfaceOutputSlot(unsafe { slots + 1 })
            try {
                @Expect(sameInterfaceVectorElement(firstOut, second), true)
                @Expect(sameInterfaceVectorElement(secondOut, third), true)
            } finally {
                firstOut.close()
                secondOut.close()
            }
        } finally {
            let slots = CPointer<CPointer<Unit>>(manyHandle.pointer)
            closeIteratorInterfaceOutputSlot(slots)
            closeIteratorInterfaceOutputSlot(unsafe { slots + 1 })
            unsafe { releaseArrayRawData(manyHandle) }
        }

        var invalidCopied = 99u32
        let nullBufferHr = unsafe {
            directGetMany(iterator.asRaw(), 1u32, CPointer<Unit>(), CPointer<UInt32>(inout invalidCopied))
        }
        @Expect(nullBufferHr, E_POINTER.value)
        @Expect(invalidCopied, 0u32)
    } finally {
        iterator.close()
        third.close()
        second.close()
        first.close()
    }
}
