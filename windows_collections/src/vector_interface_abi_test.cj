package windows_collections
import windows_interface as windows_interface
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
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(seed: ArrayList<IInspectable>) {
        this.items = ArrayList<IInspectable>(seed.size, { i => mustRetainInterfaceVectorElement(seed[i]) })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new<InterfaceVectorAbiTestImpl, IInspectable>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<InterfaceVectorAbiTestImpl, IInspectable>())
        }
    }

    private func drainItems(): Unit {
        closeInterfaceVectorElements(items)
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
        drainItems()
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

@Test
func testStockInspectableVectorReturnsVectorViewSnapshot() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let source = ArrayList<IInspectable>([first, second])
    let vector = toInspectableVector(source)
    let view = unsafe { vector.GetView() }

    try {
        @Expect(unsafe { view.Size() }, 2u32)
        expectInterfaceVectorAt(vector, 0u32, first)
        let viewValue = unsafe { view.GetAt(1u32) }
        try {
            @Expect(sameInterfaceVectorElement(viewValue, second), true)
        } finally {
            viewValue.close()
        }
    } finally {
        view.close()
        vector.close()
        second.close()
        first.close()
    }
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

func requireRawInterface(value: Option<CPointer<Unit>>, message: String): CPointer<Unit> {
    match (value) {
        case Some(raw) => raw
        case None => throw Exception(message)
    }
}

func closeRawInterface(raw: CPointer<Unit>): Unit {
    if (raw.isNotNull()) {
        IInspectable.fromAbiTake(raw).close()
    }
}

@Test
func testStockInspectableVectorExposesBindableInterfacesForXamlItemsSource() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let third = createInterfaceVectorElement()
    let source = ArrayList<IInspectable>([first, second])
    let vector = toInspectableVector(source)

    var bindableVectorRaw = CPointer<Unit>()
    var bindableIterableRaw = CPointer<Unit>()
    var bindableViewRaw = CPointer<Unit>()
    var bindableIteratorRaw = CPointer<Unit>()
    var currentRaw = CPointer<Unit>()
    var getAtRaw = CPointer<Unit>()
    var appendedRaw = CPointer<Unit>()

    try {
        bindableVectorRaw = requireRawInterface(
            unsafe { windows_interface.queryInterfaceRaw(vector.asRaw(), IID_BINDABLE_VECTOR) },
            "expected IBindableVector"
        )
        bindableIterableRaw = requireRawInterface(
            unsafe { windows_interface.queryInterfaceRaw(vector.asRaw(), IID_BINDABLE_ITERABLE) },
            "expected IBindableIterable"
        )

        let bindableVectorVtbl = unsafe { CPointer<CPointer<IBindableVectorVtbl>>(bindableVectorRaw).read().read() }
        var bindableSize = 0u32
        @Expect(unsafe { bindableVectorVtbl.Size(bindableVectorRaw, CPointer<UInt32>(inout bindableSize)) }, S_OK.value)
        @Expect(bindableSize, 2u32)

        @Expect(
            unsafe { bindableVectorVtbl.GetAt(bindableVectorRaw, 1u32, CPointer<CPointer<Unit>>(inout getAtRaw)) },
            S_OK.value
        )
        let getAtValue = IInspectable.fromAbiTake(getAtRaw)
        getAtRaw = CPointer<Unit>()
        try {
            @Expect(sameInterfaceVectorElement(getAtValue, second), true)
        } finally {
            getAtValue.close()
        }

        var foundIndex = 99u32
        var foundValue = false
        @Expect(
            unsafe {
                bindableVectorVtbl.IndexOf(
                    bindableVectorRaw,
                    second.asRaw(),
                    CPointer<UInt32>(inout foundIndex),
                    CPointer<Bool>(inout foundValue)
                )
            },
            S_OK.value
        )
        @Expect(foundValue, true)
        @Expect(foundIndex, 1u32)

        @Expect(unsafe { bindableVectorVtbl.Append(bindableVectorRaw, third.asRaw()) }, S_OK.value)
        var appendedSize = 0u32
        @Expect(unsafe { bindableVectorVtbl.Size(bindableVectorRaw, CPointer<UInt32>(inout appendedSize)) }, S_OK.value)
        @Expect(appendedSize, 3u32)
        @Expect(
            unsafe { bindableVectorVtbl.GetAt(bindableVectorRaw, 2u32, CPointer<CPointer<Unit>>(inout appendedRaw)) },
            S_OK.value
        )
        let appendedValue = IInspectable.fromAbiTake(appendedRaw)
        appendedRaw = CPointer<Unit>()
        try {
            @Expect(sameInterfaceVectorElement(appendedValue, third), true)
        } finally {
            appendedValue.close()
        }

        @Expect(
            unsafe { bindableVectorVtbl.GetView(bindableVectorRaw, CPointer<CPointer<Unit>>(inout bindableViewRaw)) },
            S_OK.value
        )
        let bindableViewVtbl = unsafe { CPointer<CPointer<IBindableVectorViewVtbl>>(bindableViewRaw).read().read() }
        var viewSize = 0u32
        @Expect(unsafe { bindableViewVtbl.Size(bindableViewRaw, CPointer<UInt32>(inout viewSize)) }, S_OK.value)
        @Expect(viewSize, 3u32)

        let bindableIterableVtbl = unsafe { CPointer<CPointer<IBindableIterableVtbl>>(bindableIterableRaw).read().read() }
        @Expect(
            unsafe { bindableIterableVtbl.First(bindableIterableRaw, CPointer<CPointer<Unit>>(inout bindableIteratorRaw)) },
            S_OK.value
        )
        let bindableIteratorVtbl = unsafe { CPointer<CPointer<IBindableIteratorVtbl>>(bindableIteratorRaw).read().read() }
        var hasCurrent = false
        @Expect(unsafe { bindableIteratorVtbl.HasCurrent(bindableIteratorRaw, CPointer<Bool>(inout hasCurrent)) }, S_OK.value)
        @Expect(hasCurrent, true)
        @Expect(
            unsafe { bindableIteratorVtbl.Current(bindableIteratorRaw, CPointer<CPointer<Unit>>(inout currentRaw)) },
            S_OK.value
        )
        let currentValue = IInspectable.fromAbiTake(currentRaw)
        currentRaw = CPointer<Unit>()
        try {
            @Expect(sameInterfaceVectorElement(currentValue, first), true)
        } finally {
            currentValue.close()
        }
        var moved = false
        @Expect(unsafe { bindableIteratorVtbl.MoveNext(bindableIteratorRaw, CPointer<Bool>(inout moved)) }, S_OK.value)
        @Expect(moved, true)
    } finally {
        closeRawInterface(currentRaw)
        closeRawInterface(appendedRaw)
        closeRawInterface(getAtRaw)
        closeRawInterface(bindableIteratorRaw)
        closeRawInterface(bindableViewRaw)
        closeRawInterface(bindableIterableRaw)
        closeRawInterface(bindableVectorRaw)
        vector.close()
        third.close()
        second.close()
        first.close()
    }
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
