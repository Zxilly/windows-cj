package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, HString, Result, S_OK, createComObjectFromSchemas}
import windows_strings.releaseSystemHStringHandle

class HStringVectorViewAbiTestImpl <: IVectorView_Impl<HString> & Resource {
    private let items: ArrayList<HString>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(seed: ArrayList<HString>) {
        this.items = ArrayList<HString>(seed.size, { index => seed[index].clone() })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.new<HStringVectorViewAbiTestImpl, HString>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<HStringVectorViewAbiTestImpl, HString>())
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

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<HString>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createHStringVectorViewAbiTest(values: ArrayList<HString>): IVectorView<HString> {
    let impl = HStringVectorViewAbiTestImpl(values)
    let schemas = [IIterable<HString>.descriptorSchema(), IVectorView<HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<HString>.descriptor())
    object.close()
    result
}

func closeHStringOutputSlot(slot: CPointer<CPointer<Unit>>): Unit {
    let raw = unsafe { slot.read() }
    if (raw.isNotNull()) {
        releaseSystemHStringHandle(raw)
        unsafe { slot.write(CPointer<Unit>()) }
    }
}

func takeHStringOutputSlot(slot: CPointer<CPointer<Unit>>): HString {
    let raw = unsafe { slot.read() }
    unsafe { slot.write(CPointer<Unit>()) }
    HString.fromSystemHandleTake(raw)
}

@Test
func testHStringVectorViewUsesHandleAbiForReadSlots() {
    let first = HString("first")
    let second = HString("second")
    let third = HString("third")
    let view = createHStringVectorViewAbiTest(ArrayList<HString>([first, second, third]))
    let probe = HString("second")

    try {
        @Expect(unsafe { view.Size() }, 3u32)
        let atOne = unsafe { view.GetAt(1u32) }
        try {
            @Expect(atOne.get(), "second")
        } finally {
            atOne.close()
        }

        var wrapperIndex = 99u32
        @Expect(unsafe { view.IndexOf(probe, CPointer<UInt32>(inout wrapperIndex)) }, true)
        @Expect(wrapperIndex, 1u32)

        let bufferHandle = unsafe {
            acquireArrayRawData(Array<CPointer<Unit>>(2, { _ => CPointer<Unit>() }))
        }
        try {
            let slots = CPointer<CPointer<Unit>>(bufferHandle.pointer)
            let copied = unsafe { view.GetMany(1u32, 2u32, CPointer<Unit>(slots)) }
            @Expect(copied, 2u32)
            let firstOut = takeHStringOutputSlot(slots)
            let secondOut = takeHStringOutputSlot(unsafe { slots + 1 })
            try {
                @Expect(firstOut.get(), "second")
                @Expect(secondOut.get(), "third")
            } finally {
                firstOut.close()
                secondOut.close()
            }
        } finally {
            let slots = CPointer<CPointer<Unit>>(bufferHandle.pointer)
            closeHStringOutputSlot(slots)
            closeHStringOutputSlot(unsafe { slots + 1 })
            unsafe { releaseArrayRawData(bufferHandle) }
        }
    } finally {
        probe.close()
        view.close()
        third.close()
        second.close()
        first.close()
    }
}

@Test
func testHStringVectorViewDirectVtableUsesHandleAbi() {
    let one = HString("one")
    let two = HString("two")
    let three = HString("three")
    let view = createHStringVectorViewAbiTest(ArrayList<HString>([one, two, three]))
    let needle = HString("three")

    try {
        let vtbl = unsafe { view.vtbl() }

        let directIndexOf = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
            CPointer<Unit>(vtbl.IndexOf)
        )
        let needleRaw = needle.toSystemHandleCopy()
        var directIndex = 99u32
        var directFound = false
        let indexHr = unsafe {
            directIndexOf(
                view.asRaw(),
                needleRaw,
                CPointer<UInt32>(inout directIndex),
                CPointer<Bool>(inout directFound)
            )
        }
        releaseSystemHStringHandle(needleRaw)
        @Expect(indexHr, S_OK.value)
        @Expect(directFound, true)
        @Expect(directIndex, 2u32)

        let directGetAt = CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.GetAt))
        var outRaw = CPointer<Unit>()
        let getHr = unsafe { directGetAt(view.asRaw(), 0u32, CPointer<CPointer<Unit>>(inout outRaw)) }
        @Expect(getHr, S_OK.value)
        let owned = HString.fromSystemHandleTake(outRaw)
        try {
            @Expect(owned.get(), "one")
        } finally {
            owned.close()
        }

        let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
            CPointer<Unit>(vtbl.GetMany)
        )
        let getManyHandle = unsafe {
            acquireArrayRawData(Array<CPointer<Unit>>(2, { _ => CPointer<Unit>() }))
        }
        try {
            let slots = CPointer<CPointer<Unit>>(getManyHandle.pointer)
            var copied = 99u32
            let getManyHr = unsafe {
                directGetMany(view.asRaw(), 1u32, 2u32, CPointer<Unit>(slots), CPointer<UInt32>(inout copied))
            }
            @Expect(getManyHr, S_OK.value)
            @Expect(copied, 2u32)
            let firstOut = takeHStringOutputSlot(slots)
            let secondOut = takeHStringOutputSlot(unsafe { slots + 1 })
            try {
                @Expect(firstOut.get(), "two")
                @Expect(secondOut.get(), "three")
            } finally {
                firstOut.close()
                secondOut.close()
            }
        } finally {
            let slots = CPointer<CPointer<Unit>>(getManyHandle.pointer)
            closeHStringOutputSlot(slots)
            closeHStringOutputSlot(unsafe { slots + 1 })
            unsafe { releaseArrayRawData(getManyHandle) }
        }

        var invalidCopied = 99u32
        let nullBufferHr = unsafe {
            directGetMany(view.asRaw(), 0u32, 1u32, CPointer<Unit>(), CPointer<UInt32>(inout invalidCopied))
        }
        @Expect(nullBufferHr, E_POINTER.value)
    } finally {
        needle.close()
        view.close()
        three.close()
        two.close()
        one.close()
    }
}
