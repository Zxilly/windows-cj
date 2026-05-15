package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas, winrtProjectGenericIn}
import windows_interface.IInspectable

class InterfaceVectorAbiElement {}

func createInterfaceVectorElement(): IInspectable {
    let object = createComObjectFromSchemas(InterfaceVectorAbiElement(), [IInspectable.descriptorSchema()])
    let result = object.toInterface(IInspectable.descriptor())
    object.close()
    result
}

func sameInterfaceVectorElement(left: IInspectable, right: IInspectable): Bool {
    left.asRaw().toUIntNative() == right.asRaw().toUIntNative()
}

func retainInterfaceVectorElement(value: IInspectable): Result<IInspectable> {
    let raw = value.retainRaw()
    if (raw.isNull()) {
        return Result<IInspectable>.Err(WinError(E_POINTER))
    }
    Result<IInspectable>.Ok(IInspectable.fromAbiTake(raw))
}

func mustRetainInterfaceVectorElement(value: IInspectable): IInspectable {
    match (retainInterfaceVectorElement(value)) {
        case Result<IInspectable>.Ok(retained) => retained
        case Result<IInspectable>.Err(_) => throw Exception("expected live IInspectable")
    }
}

func closeInterfaceVectorElements(values: ArrayList<IInspectable>): Unit {
    var offset = 0
    while (offset < values.size) {
        match (values.get(offset)) {
            case Some(value) => value.close()
            case None => ()
        }
        offset += 1
    }
    values.clear()
}

class InterfaceVectorAbiTestImpl <: IVector_Impl<IInspectable> & Resource {
    private let items: ArrayList<IInspectable>
    private let vtblHandle: CPointerHandle<IVectorVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(seed: ArrayList<IInspectable>) {
        this.items = ArrayList<IInspectable>(seed.size, { i => mustRetainInterfaceVectorElement(seed[i]) })
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorVtbl>(1, { _ => IVectorVtbl.new<InterfaceVectorAbiTestImpl, IInspectable>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<InterfaceVectorAbiTestImpl, IInspectable>() }))
        }
    }

    private func drainItems(): Unit {
        closeInterfaceVectorElements(items)
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
        drainItems()
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

    public func First(): Result<IIterator<IInspectable>> {
        Result<IIterator<IInspectable>>.Ok(toIterator<IInspectable>(items))
    }

    public func GetAt(index: UInt32): Result<IInspectable> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<IInspectable>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => retainInterfaceVectorElement(value)
            case None => Result<IInspectable>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<IInspectable>> {
        Result<IVectorView<IInspectable>>.Err(stockBoundsError())
    }

    public func IndexOf(value: IInspectable, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (sameInterfaceVectorElement(candidate, value)) {
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

    public func SetAt(index: UInt32, value: IInspectable): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (retainInterfaceVectorElement(value)) {
            case Result<IInspectable>.Ok(retained) =>
                match (items.get(resolved)) {
                    case Some(previous) => previous.close()
                    case None => ()
                }
                items[resolved] = retained
                Result<Unit>.Ok(())
            case Result<IInspectable>.Err(error) =>
                Result<Unit>.Err(error)
        }
    }

    public func InsertAt(index: UInt32, value: IInspectable): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved > items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (retainInterfaceVectorElement(value)) {
            case Result<IInspectable>.Ok(retained) =>
                items.add(retained, at: resolved)
                Result<Unit>.Ok(())
            case Result<IInspectable>.Err(error) =>
                Result<Unit>.Err(error)
        }
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(previous) => previous.close()
            case None => ()
        }
        items.remove(at: resolved)
        Result<Unit>.Ok(())
    }

    public func Append(value: IInspectable): Result<Unit> {
        match (retainInterfaceVectorElement(value)) {
            case Result<IInspectable>.Ok(retained) =>
                items.add(retained)
                Result<Unit>.Ok(())
            case Result<IInspectable>.Err(error) =>
                Result<Unit>.Err(error)
        }
    }

    public func RemoveAtEnd(): Result<Unit> {
        if (items.size == 0) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (items.get(items.size - 1)) {
            case Some(previous) => previous.close()
            case None => ()
        }
        items.remove(at: items.size - 1)
        Result<Unit>.Ok(())
    }

    public func Clear(): Result<Unit> {
        drainItems()
        Result<Unit>.Ok(())
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<IInspectable>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        let replacements = ArrayList<IInspectable>()
        var completed = false
        try {
            let slots = CPointer<CPointer<Unit>>(itemsBuffer)
            var index = 0
            while (index < Int64(itemsSize)) {
                let raw = unsafe { (slots + index).read() }
                let borrowed = winrtProjectGenericIn<IInspectable>(raw)
                match (retainInterfaceVectorElement(borrowed)) {
                    case Result<IInspectable>.Ok(retained) =>
                        replacements.add(retained)
                    case Result<IInspectable>.Err(error) =>
                        return Result<Unit>.Err(error)
                }
                index += 1
            }
            completed = true
        } finally {
            if (!completed) {
                closeInterfaceVectorElements(replacements)
            }
        }
        drainItems()
        for (value in replacements) {
            items.add(value)
        }
        Result<Unit>.Ok(())
    }
}

func createInterfaceVectorAbiTest(values: ArrayList<IInspectable>): IVector<IInspectable> {
    let impl = InterfaceVectorAbiTestImpl(values)
    let schemas = [IIterable<IInspectable>.descriptorSchema(), IVector<IInspectable>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVector<IInspectable>.descriptor())
    object.close()
    result
}

func expectInterfaceVectorAt(vector: IVector<IInspectable>, index: UInt32, expected: IInspectable): Unit {
    let value = unsafe { vector.GetAt(index) }
    try {
        @Expect(sameInterfaceVectorElement(value, expected), true)
    } finally {
        value.close()
    }
}

func closeInterfaceOutputSlot(slot: CPointer<CPointer<Unit>>): Unit {
    let raw = unsafe { slot.read() }
    if (raw.isNotNull()) {
        IInspectable.fromAbiTake(raw).close()
        unsafe { slot.write(CPointer<Unit>()) }
    }
}

func takeInterfaceOutputSlot(slot: CPointer<CPointer<Unit>>): IInspectable {
    let raw = unsafe { slot.read() }
    unsafe { slot.write(CPointer<Unit>()) }
    IInspectable.fromAbiTake(raw)
}

@Test
func testInterfaceVectorUsesHandleAbiForMutableSlots() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let third = createInterfaceVectorElement()
    let fourth = createInterfaceVectorElement()
    let fifth = createInterfaceVectorElement()
    let source = ArrayList<IInspectable>([first, third])
    let vector = createInterfaceVectorAbiTest(source)

    unsafe { vector.SetAt(0u32, second) }
    unsafe { vector.InsertAt(1u32, fourth) }
    unsafe { vector.Append(fifth) }

    @Expect(unsafe { vector.Size() }, 4u32)
    expectInterfaceVectorAt(vector, 0u32, second)
    expectInterfaceVectorAt(vector, 1u32, fourth)
    expectInterfaceVectorAt(vector, 3u32, fifth)

    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(fourth, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)

    vector.close()
    fifth.close()
    fourth.close()
    third.close()
    second.close()
    first.close()
}

@Test
func testInterfaceVectorDirectVtableUsesHandleAbi() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let third = createInterfaceVectorElement()
    let source = ArrayList<IInspectable>([first, second, third])
    let vector = createInterfaceVectorAbiTest(source)

    let vtbl = unsafe { vector.vtbl() }

    let directIndexOf = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    var directIndex = 99u32
    var directFound = false
    let indexHr = unsafe {
        directIndexOf(
            vector.asRaw(),
            third.asRaw(),
            CPointer<UInt32>(inout directIndex),
            CPointer<Bool>(inout directFound)
        )
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 2u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 1u32, first.asRaw()) }
    @Expect(setHr, S_OK.value)
    expectInterfaceVectorAt(vector, 1u32, first)

    let directGetAt = CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.GetAt))
    var outRaw = CPointer<Unit>()
    let getHr = unsafe { directGetAt(vector.asRaw(), 0u32, CPointer<CPointer<Unit>>(inout outRaw)) }
    @Expect(getHr, S_OK.value)
    let ownedOut = IInspectable.fromAbiTake(outRaw)
    @Expect(sameInterfaceVectorElement(ownedOut, first), true)
    ownedOut.close()

    let directReplaceAll = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.ReplaceAll))
    let replaceHandle = unsafe {
        acquireArrayRawData(Array<CPointer<Unit>>(2, { i =>
            if (i == 0) { second.asRaw() } else { third.asRaw() }
        }))
    }
    try {
        let replaceHr = unsafe { directReplaceAll(vector.asRaw(), 2u32, CPointer<Unit>(replaceHandle.pointer)) }
        @Expect(replaceHr, S_OK.value)
    } finally {
        unsafe { releaseArrayRawData(replaceHandle) }
    }
    @Expect(unsafe { vector.Size() }, 2u32)
    expectInterfaceVectorAt(vector, 0u32, second)
    expectInterfaceVectorAt(vector, 1u32, third)

    let invalidReplaceHandle = unsafe {
        acquireArrayRawData(Array<CPointer<Unit>>(2, { i =>
            if (i == 0) { first.asRaw() } else { CPointer<Unit>() }
        }))
    }
    try {
        let replaceHr = unsafe { directReplaceAll(vector.asRaw(), 2u32, CPointer<Unit>(invalidReplaceHandle.pointer)) }
        @Expect(replaceHr, E_POINTER.value)
    } finally {
        unsafe { releaseArrayRawData(invalidReplaceHandle) }
    }
    @Expect(unsafe { vector.Size() }, 2u32)
    expectInterfaceVectorAt(vector, 0u32, second)
    expectInterfaceVectorAt(vector, 1u32, third)

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let getManyHandle = unsafe {
        acquireArrayRawData(Array<CPointer<Unit>>(2, { _ => CPointer<Unit>() }))
    }
    try {
        let getManySlots = CPointer<CPointer<Unit>>(getManyHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(vector.asRaw(), 0u32, 2u32, CPointer<Unit>(getManySlots), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 2u32)
        let firstOut = takeInterfaceOutputSlot(getManySlots)
        let secondOut = takeInterfaceOutputSlot(unsafe { getManySlots + 1 })
        try {
            @Expect(sameInterfaceVectorElement(firstOut, second), true)
            @Expect(sameInterfaceVectorElement(secondOut, third), true)
        } finally {
            firstOut.close()
            secondOut.close()
        }
    } finally {
        let getManySlots = CPointer<CPointer<Unit>>(getManyHandle.pointer)
        closeInterfaceOutputSlot(getManySlots)
        closeInterfaceOutputSlot(unsafe { getManySlots + 1 })
        unsafe { releaseArrayRawData(getManyHandle) }
    }

    let nullSetHr = unsafe { directSetAt(vector.asRaw(), 0u32, CPointer<Unit>()) }
    @Expect(nullSetHr, E_POINTER.value)

    vector.close()
    third.close()
    second.close()
    first.close()
}
