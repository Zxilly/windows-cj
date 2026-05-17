package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result, S_OK, createComObjectFromSchemas}
import windows_interface.IInspectable

class InterfaceVectorViewAbiTestImpl <: IVectorView_Impl<IInspectable> & Resource {
    private let items: ArrayList<IInspectable>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(seed: ArrayList<IInspectable>) {
        this.items = ArrayList<IInspectable>(seed.size, { index => mustRetainInterfaceVectorElement(seed[index]) })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.new<InterfaceVectorViewAbiTestImpl, IInspectable>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<InterfaceVectorViewAbiTestImpl, IInspectable>())
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

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<IInspectable>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createInterfaceVectorViewAbiTest(values: ArrayList<IInspectable>): IVectorView<IInspectable> {
    let impl = InterfaceVectorViewAbiTestImpl(values)
    let schemas = [IIterable<IInspectable>.descriptorSchema(), IVectorView<IInspectable>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<IInspectable>.descriptor())
    object.close()
    result
}

func expectInterfaceVectorViewAt(view: IVectorView<IInspectable>, index: UInt32, expected: IInspectable): Unit {
    let value = unsafe { view.GetAt(index) }
    try {
        @Expect(sameInterfaceVectorElement(value, expected), true)
    } finally {
        value.close()
    }
}

@Test
func testInterfaceVectorViewUsesHandleAbiForReadSlots() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let third = createInterfaceVectorElement()
    let view = createInterfaceVectorViewAbiTest(ArrayList<IInspectable>([first, second, third]))

    try {
        @Expect(unsafe { view.Size() }, 3u32)
        expectInterfaceVectorViewAt(view, 1u32, second)

        var wrapperIndex = 99u32
        @Expect(unsafe { view.IndexOf(second, CPointer<UInt32>(inout wrapperIndex)) }, true)
        @Expect(wrapperIndex, 1u32)

        let bufferHandle = unsafe {
            acquireArrayRawData(Array<CPointer<Unit>>(2, { _ => CPointer<Unit>() }))
        }
        try {
            let slots = CPointer<CPointer<Unit>>(bufferHandle.pointer)
            let copied = unsafe { view.GetMany(1u32, 2u32, CPointer<Unit>(slots)) }
            @Expect(copied, 2u32)
            let firstOut = takeInterfaceOutputSlot(slots)
            let secondOut = takeInterfaceOutputSlot(unsafe { slots + 1 })
            try {
                @Expect(sameInterfaceVectorElement(firstOut, second), true)
                @Expect(sameInterfaceVectorElement(secondOut, third), true)
            } finally {
                firstOut.close()
                secondOut.close()
            }
        } finally {
            let slots = CPointer<CPointer<Unit>>(bufferHandle.pointer)
            closeInterfaceOutputSlot(slots)
            closeInterfaceOutputSlot(unsafe { slots + 1 })
            unsafe { releaseArrayRawData(bufferHandle) }
        }
    } finally {
        view.close()
        third.close()
        second.close()
        first.close()
    }
}

@Test
func testInterfaceVectorViewDirectVtableUsesHandleAbi() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let third = createInterfaceVectorElement()
    let view = createInterfaceVectorViewAbiTest(ArrayList<IInspectable>([first, second, third]))

    try {
        let vtbl = unsafe { view.vtbl() }

        let directIndexOf = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
            CPointer<Unit>(vtbl.IndexOf)
        )
        var directIndex = 99u32
        var directFound = false
        let indexHr = unsafe {
            directIndexOf(
                view.asRaw(),
                third.asRaw(),
                CPointer<UInt32>(inout directIndex),
                CPointer<Bool>(inout directFound)
            )
        }
        @Expect(indexHr, S_OK.value)
        @Expect(directFound, true)
        @Expect(directIndex, 2u32)

        let directGetAt = CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.GetAt))
        var outRaw = CPointer<Unit>()
        let getHr = unsafe { directGetAt(view.asRaw(), 0u32, CPointer<CPointer<Unit>>(inout outRaw)) }
        @Expect(getHr, S_OK.value)
        let ownedOut = IInspectable.fromAbiTake(outRaw)
        try {
            @Expect(sameInterfaceVectorElement(ownedOut, first), true)
        } finally {
            ownedOut.close()
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
            let firstOut = takeInterfaceOutputSlot(slots)
            let secondOut = takeInterfaceOutputSlot(unsafe { slots + 1 })
            try {
                @Expect(sameInterfaceVectorElement(firstOut, second), true)
                @Expect(sameInterfaceVectorElement(secondOut, third), true)
            } finally {
                firstOut.close()
                secondOut.close()
            }
        } finally {
            let slots = CPointer<CPointer<Unit>>(getManyHandle.pointer)
            closeInterfaceOutputSlot(slots)
            closeInterfaceOutputSlot(unsafe { slots + 1 })
            unsafe { releaseArrayRawData(getManyHandle) }
        }

        var invalidCopied = 99u32
        let nullBufferHr = unsafe {
            directGetMany(view.asRaw(), 0u32, 1u32, CPointer<Unit>(), CPointer<UInt32>(inout invalidCopied))
        }
        @Expect(nullBufferHr, E_POINTER.value)
    } finally {
        view.close()
        third.close()
        second.close()
        first.close()
    }
}
