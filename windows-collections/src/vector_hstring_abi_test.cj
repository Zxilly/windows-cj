package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, HString, Result, S_OK, WinError, createComObjectFromSchemas, winrtProjectGenericIn}
import windows_strings.releaseSystemHStringHandle

class HStringVectorAbiTestImpl <: IVector_Impl<HString> & Resource {
    private let items: ArrayList<HString>
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(seed: ArrayList<HString>) {
        // Take ownership of each seed handle by cloning into a private list so
        // the caller's ArrayList does not alias the impl's storage. This keeps
        // every HString slot in `items` with a unique releaser (the impl).
        this.items = ArrayList<HString>(seed.size, { i => seed[i].clone() })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new<HStringVectorAbiTestImpl, HString>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<HStringVectorAbiTestImpl, HString>())
        }
    }

    private func drainItems(): Unit {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(value) => value.close()
                case None => ()
            }
            offset += 1
        }
        items.clear()
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

    public func First(): Result<IIterator<HString>> {
        Result<IIterator<HString>>.Ok(toIterator<HString>(items))
    }

    public func GetAt(index: UInt32): Result<HString> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<HString>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<HString>.Ok(value.clone())
            case None => Result<HString>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<HString>> {
        Result<IVectorView<HString>>.Ok(toVectorView<HString>(items))
    }

    public func IndexOf(value: HString, indexSlot: CPointer<UInt32>): Result<Bool> {
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

    public func SetAt(index: UInt32, value: HString): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(previous) => previous.close()
            case None => ()
        }
        items[resolved] = value.clone()
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: HString): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved > items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items.add(value.clone(), at: resolved)
        Result<Unit>.Ok(())
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

    public func Append(value: HString): Result<Unit> {
        items.add(value.clone())
        Result<Unit>.Ok(())
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
        writeGenericManyRange<HString>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        drainItems()
        let slots = CPointer<CPointer<Unit>>(itemsBuffer)
        var index = 0
        while (index < Int64(itemsSize)) {
            let raw = unsafe { (slots + index).read() }
            items.add(winrtProjectGenericIn<HString>(raw))
            index += 1
        }
        Result<Unit>.Ok(())
    }
}

func createHStringVectorAbiTest(values: ArrayList<HString>): IVector<HString> {
    let impl = HStringVectorAbiTestImpl(values)
    let schemas = [IIterable<HString>.descriptorSchema(), IVector<HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVector<HString>.descriptor())
    object.close()
    result
}

@Test
func testHStringVectorUsesHandleAbiForMutableSlots() {
    let alpha = HString("alpha")
    let gamma = HString("gamma")
    let source = ArrayList<HString>([alpha, gamma])
    let vector = createHStringVectorAbiTest(source)

    let beta = HString("beta")
    let delta = HString("delta")
    let zeta = HString("zeta")
    unsafe { vector.SetAt(0u32, beta) }
    unsafe { vector.InsertAt(1u32, delta) }
    unsafe { vector.Append(zeta) }

    @Expect(unsafe { vector.Size() }, 4u32)
    @Expect(unsafe { vector.GetAt(0u32) }.get(), "beta")
    @Expect(unsafe { vector.GetAt(1u32) }.get(), "delta")
    @Expect(unsafe { vector.GetAt(3u32) }.get(), "zeta")

    let probe = HString("delta")
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(probe, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)

    vector.close()
    probe.close()
    zeta.close()
    delta.close()
    beta.close()
    gamma.close()
    alpha.close()
}

@Test
func testHStringVectorDirectVtableUsesHandleAbi() {
    let one = HString("one")
    let two = HString("two")
    let threeSeed = HString("three")
    let source = ArrayList<HString>([one, two, threeSeed])
    let vector = createHStringVectorAbiTest(source)

    let vtbl = unsafe { vector.vtbl() }

    // IndexOf takes the search value as a raw HSTRING handle.
    let directIndexOf = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let needle = HString("three")
    // The IndexOf thunk copies the input handle (HString.viewWinrtHandle uses
    // fromSystemHandleCopy) and does not take ownership of the published copy
    // we hand to it. Release the temporary copy ourselves after the call.
    let needleRaw = needle.toSystemHandleCopy()
    var directIndex = 99u32
    var directFound = false
    let indexHr = unsafe {
        directIndexOf(
            vector.asRaw(),
            needleRaw,
            CPointer<UInt32>(inout directIndex),
            CPointer<Bool>(inout directFound)
        )
    }
    releaseSystemHStringHandle(needleRaw)
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 2u32)

    // SetAt publishes the new value as a raw HSTRING handle that the thunk
    // copies into storage rather than taking ownership of.
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let replacement = HString("THREE")
    let replacementRaw = replacement.toSystemHandleCopy()
    let setHr = unsafe { directSetAt(vector.asRaw(), 2u32, replacementRaw) }
    releaseSystemHStringHandle(replacementRaw)
    @Expect(setHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }.get(), "THREE")

    // GetAt returns an HSTRING handle through an out slot.
    let directGetAt = CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.GetAt))
    var outRaw = CPointer<Unit>()
    let getHr = unsafe { directGetAt(vector.asRaw(), 0u32, CPointer<CPointer<Unit>>(inout outRaw)) }
    @Expect(getHr, S_OK.value)
    let owned = HString.fromSystemHandleTake(outRaw)
    @Expect(owned.get(), "one")
    owned.close()

    let directReplaceAll = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.ReplaceAll))
    let replaceOne = HString("replace-one")
    let replaceTwo = HString("replace-two")
    let replaceHandle = unsafe {
        acquireArrayRawData(
            Array<CPointer<Unit>>(
                2,
                { i => if (i == 0) { replaceOne.toSystemHandleCopy() } else { replaceTwo.toSystemHandleCopy() } }
            )
        )
    }
    try {
        let replaceHr = unsafe { directReplaceAll(vector.asRaw(), 2u32, CPointer<Unit>(replaceHandle.pointer)) }
        @Expect(replaceHr, S_OK.value)
    } finally {
        let replaceSlots = CPointer<CPointer<Unit>>(replaceHandle.pointer)
        releaseSystemHStringHandle(unsafe { replaceSlots.read() })
        releaseSystemHStringHandle(unsafe { (replaceSlots + 1).read() })
        unsafe { releaseArrayRawData(replaceHandle) }
    }
    @Expect(unsafe { vector.Size() }, 2u32)
    let replacedFirst = unsafe { vector.GetAt(0u32) }
    try {
        @Expect(replacedFirst.get(), "replace-one")
    } finally {
        replacedFirst.close()
    }
    let replacedSecond = unsafe { vector.GetAt(1u32) }
    try {
        @Expect(replacedSecond.get(), "replace-two")
    } finally {
        replacedSecond.close()
    }

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let getManyHandle = unsafe { acquireArrayRawData(Array<CPointer<Unit>>(2, { _ => CPointer<Unit>() })) }
    try {
        let getManySlots = CPointer<CPointer<Unit>>(getManyHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(vector.asRaw(), 0u32, 2u32, CPointer<Unit>(getManySlots), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 2u32)
        let firstOutRaw = unsafe { getManySlots.read() }
        unsafe { getManySlots.write(CPointer<Unit>()) }
        let secondOutRaw = unsafe { (getManySlots + 1).read() }
        unsafe { (getManySlots + 1).write(CPointer<Unit>()) }
        let firstOut = HString.fromSystemHandleTake(firstOutRaw)
        let secondOut = HString.fromSystemHandleTake(secondOutRaw)
        try {
            @Expect(firstOut.get(), "replace-one")
            @Expect(secondOut.get(), "replace-two")
        } finally {
            firstOut.close()
            secondOut.close()
        }
    } finally {
        let getManySlots = CPointer<CPointer<Unit>>(getManyHandle.pointer)
        releaseSystemHStringHandle(unsafe { getManySlots.read() })
        releaseSystemHStringHandle(unsafe { (getManySlots + 1).read() })
        unsafe { releaseArrayRawData(getManyHandle) }
    }

    let nullReplaceHr = unsafe { directReplaceAll(vector.asRaw(), 1u32, CPointer<Unit>()) }
    @Expect(nullReplaceHr, E_POINTER.value)

    replaceTwo.close()
    replaceOne.close()
    needle.close()
    replacement.close()
    vector.close()
    threeSeed.close()
    two.close()
    one.close()
}
