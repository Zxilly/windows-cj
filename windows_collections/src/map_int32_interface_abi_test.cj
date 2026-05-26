package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}
import windows_interface.IInspectable

func cloneInt32InterfaceMapEntries(entries: ArrayList<(Int32, IInspectable)>): ArrayList<(Int32, IInspectable)> {
    ArrayList<(Int32, IInspectable)>(entries.size, { index =>
        let (key, value) = entries[index]
        (key, mustRetainInterfaceVectorElement(value))
    })
}

func closeInt32InterfaceMapEntries(entries: ArrayList<(Int32, IInspectable)>): Unit {
    var offset = 0
    while (offset < entries.size) {
        match (entries.get(offset)) {
            case Some((_, value)) => value.close()
            case None => ()
        }
        offset += 1
    }
    entries.clear()
}

func findInt32InterfaceMapEntry(entries: ArrayList<(Int32, IInspectable)>, key: Int32): ?Int64 {
    var offset = 0
    while (offset < entries.size) {
        match (entries.get(offset)) {
            case Some((candidateKey, _)) =>
                if (candidateKey == key) {
                    return Some(offset)
                }
            case None => ()
        }
        offset += 1
    }
    None
}

class Int32InterfaceMapViewAbiTestImpl <: IMapView_Impl<Int32, IInspectable> & Resource {
    private let entries: ArrayList<(Int32, IInspectable)>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, IInspectable)>) {
        this.entries = cloneInt32InterfaceMapEntries(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<Int32InterfaceMapViewAbiTestImpl, Int32, IInspectable>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32InterfaceMapViewAbiTestImpl, IKeyValuePair<Int32, IInspectable>>())
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
        closeInt32InterfaceMapEntries(entries)
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, IInspectable>>> {
        Result<IIterator<IKeyValuePair<Int32, IInspectable>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, IInspectable>>(materializePairViews<Int32, IInspectable>(entries))
        )
    }

    public func Lookup(key: Int32): Result<IInspectable> {
        match (findInt32InterfaceMapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => retainInterfaceVectorElement(value)
                    case None => Result<IInspectable>.Err(stockBoundsError())
                }
            case None => Result<IInspectable>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        match (findInt32InterfaceMapEntry(entries, key)) {
            case Some(_) => Result<Bool>.Ok(true)
            case None => Result<Bool>.Ok(false)
        }
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        if (first.isNotNull()) {
            unsafe { first.write(CPointer<Unit>()) }
        }
        if (second.isNotNull()) {
            unsafe { second.write(CPointer<Unit>()) }
        }
        Result<Unit>.Ok(())
    }
}

func createInt32InterfaceMapViewAbiTest(entries: ArrayList<(Int32, IInspectable)>): IMapView<Int32, IInspectable> {
    let impl = Int32InterfaceMapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, IInspectable>>.descriptorSchema(), IMapView<Int32, IInspectable>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, IInspectable>.descriptor())
    object.close()
    result
}

class Int32InterfaceMapAbiTestImpl <: IMap_Impl<Int32, IInspectable> & Resource {
    private let entries: ArrayList<(Int32, IInspectable)>
    private let vtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, IInspectable)>) {
        this.entries = cloneInt32InterfaceMapEntries(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.new<Int32InterfaceMapAbiTestImpl, Int32, IInspectable>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32InterfaceMapAbiTestImpl, IKeyValuePair<Int32, IInspectable>>())
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
        closeInt32InterfaceMapEntries(entries)
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, IInspectable>>> {
        Result<IIterator<IKeyValuePair<Int32, IInspectable>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, IInspectable>>(materializePairViews<Int32, IInspectable>(entries))
        )
    }

    public func Lookup(key: Int32): Result<IInspectable> {
        match (findInt32InterfaceMapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => retainInterfaceVectorElement(value)
                    case None => Result<IInspectable>.Err(stockBoundsError())
                }
            case None => Result<IInspectable>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        match (findInt32InterfaceMapEntry(entries, key)) {
            case Some(_) => Result<Bool>.Ok(true)
            case None => Result<Bool>.Ok(false)
        }
    }

    public func GetView(): Result<IMapView<Int32, IInspectable>> {
        Result<IMapView<Int32, IInspectable>>.Ok(createInt32InterfaceMapViewAbiTest(entries))
    }

    public func Insert(key: Int32, value: IInspectable): Result<Bool> {
        match (findInt32InterfaceMapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, previousValue)) => previousValue.close()
                    case None => ()
                }
                entries[offset] = (key, mustRetainInterfaceVectorElement(value))
                Result<Bool>.Ok(true)
            case None =>
                entries.add((key, mustRetainInterfaceVectorElement(value)))
                Result<Bool>.Ok(false)
        }
    }

    public func Remove(key: Int32): Result<Unit> {
        match (findInt32InterfaceMapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, previousValue)) => previousValue.close()
                    case None => ()
                }
                entries.remove(at: offset)
                Result<Unit>.Ok(())
            case None =>
                Result<Unit>.Err(stockBoundsError())
        }
    }

    public func Clear(): Result<Unit> {
        closeInt32InterfaceMapEntries(entries)
        Result<Unit>.Ok(())
    }
}

func createInt32InterfaceMapAbiTest(entries: ArrayList<(Int32, IInspectable)>): IMap<Int32, IInspectable> {
    let impl = Int32InterfaceMapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, IInspectable>>.descriptorSchema(), IMap<Int32, IInspectable>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, IInspectable>.descriptor())
    object.close()
    result
}

func assertInt32InterfaceMapViewUsesDirectAbi(view: IMapView<Int32, IInspectable>, first: IInspectable, second: IInspectable): Unit {
    let wrapperValue = unsafe { view.Lookup(2i32) }
    try {
        @Expect(sameInterfaceVectorElement(wrapperValue, second), true)
    } finally {
        wrapperValue.close()
    }

    let vtbl = unsafe { view.vtbl() }
    var rawValue = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<CPointer<Unit>>(inout rawValue)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = IInspectable.fromAbiTake(rawValue)
    try {
        @Expect(sameInterfaceVectorElement(directValue, first), true)
    } finally {
        directValue.close()
    }

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)
}

@Test
func testInt32InterfaceMapViewUsesHandleValueAbi() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let view = createInt32InterfaceMapViewAbiTest(ArrayList<(Int32, IInspectable)>([(1i32, first), (2i32, second)]))

    try {
        assertInt32InterfaceMapViewUsesDirectAbi(view, first, second)
    } finally {
        view.close()
        second.close()
        first.close()
    }
}

@Test
func testInt32InterfaceMapUsesHandleValueAbiForMutableSlots() {
    let first = createInterfaceVectorElement()
    let second = createInterfaceVectorElement()
    let replacement = createInterfaceVectorElement()
    let inserted = createInterfaceVectorElement()
    let directInserted = createInterfaceVectorElement()
    let map = createInt32InterfaceMapAbiTest(ArrayList<(Int32, IInspectable)>([(1i32, first), (2i32, second)]))

    try {
        let wrapperValue = unsafe { map.Lookup(1i32) }
        try {
            @Expect(sameInterfaceVectorElement(wrapperValue, first), true)
        } finally {
            wrapperValue.close()
        }
        @Expect(unsafe { map.Insert(2i32, replacement) }, true)
        let replacedValue = unsafe { map.Lookup(2i32) }
        try {
            @Expect(sameInterfaceVectorElement(replacedValue, replacement), true)
        } finally {
            replacedValue.close()
        }
        @Expect(unsafe { map.Insert(3i32, inserted) }, false)

        let view = unsafe { map.GetView() }
        try {
            assertInt32InterfaceMapViewUsesDirectAbi(view, first, replacement)
        } finally {
            view.close()
        }

        let vtbl = unsafe { map.vtbl() }
        let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        var rawValue = CPointer<Unit>()
        let lookupHr = unsafe { directLookup(map.asRaw(), 3i32, CPointer<CPointer<Unit>>(inout rawValue)) }
        @Expect(lookupHr, S_OK.value)
        let directValue = IInspectable.fromAbiTake(rawValue)
        try {
            @Expect(sameInterfaceVectorElement(directValue, inserted), true)
        } finally {
            directValue.close()
        }

        let directInsert = CFunc<(CPointer<Unit>, Int32, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        var directReplaced = true
        let insertHr = unsafe { directInsert(map.asRaw(), 4i32, directInserted.asRaw(), CPointer<Bool>(inout directReplaced)) }
        @Expect(insertHr, S_OK.value)
        @Expect(directReplaced, false)
        let directInsertedValue = unsafe { map.Lookup(4i32) }
        try {
            @Expect(sameInterfaceVectorElement(directInsertedValue, directInserted), true)
        } finally {
            directInsertedValue.close()
        }

        let directRemove = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Remove))
        let removeHr = unsafe { directRemove(map.asRaw(), 2i32) }
        @Expect(removeHr, S_OK.value)
        @Expect(unsafe { map.HasKey(2i32) }, false)
    } finally {
        map.close()
        directInserted.close()
        inserted.close()
        replacement.close()
        second.close()
        first.close()
    }
}
