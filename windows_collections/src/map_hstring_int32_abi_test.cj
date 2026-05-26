package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{HString, Result, S_OK, createComObjectFromSchemas, winrtBorrowGenericIn}

func cloneHStringInt32MapEntries(entries: ArrayList<(HString, Int32)>): ArrayList<(HString, Int32)> {
    ArrayList<(HString, Int32)>(entries.size, { index =>
        let (key, value) = entries[index]
        (key.clone(), value)
    })
}

func closeHStringInt32MapEntries(entries: ArrayList<(HString, Int32)>): Unit {
    var offset = 0
    while (offset < entries.size) {
        match (entries.get(offset)) {
            case Some((key, _)) => key.close()
            case None => ()
        }
        offset += 1
    }
    entries.clear()
}

func findHStringInt32MapEntry(entries: ArrayList<(HString, Int32)>, key: HString): ?Int64 {
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

class HStringInt32MapViewAbiTestImpl <: IMapView_Impl<HString, Int32> & Resource {
    private let entries: ArrayList<(HString, Int32)>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(HString, Int32)>) {
        this.entries = cloneHStringInt32MapEntries(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<HStringInt32MapViewAbiTestImpl, HString, Int32>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<HStringInt32MapViewAbiTestImpl, IKeyValuePair<HString, Int32>>())
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
        closeHStringInt32MapEntries(entries)
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

    public func First(): Result<IIterator<IKeyValuePair<HString, Int32>>> {
        Result<IIterator<IKeyValuePair<HString, Int32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<HString, Int32>>(materializePairViews<HString, Int32>(entries))
        )
    }

    public func Lookup(key: HString): Result<Int32> {
        match (findHStringInt32MapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<Int32>.Ok(value)
                    case None => Result<Int32>.Err(stockBoundsError())
                }
            case None => Result<Int32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: HString): Result<Bool> {
        match (findHStringInt32MapEntry(entries, key)) {
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

func createHStringInt32MapViewAbiTest(entries: ArrayList<(HString, Int32)>): IMapView<HString, Int32> {
    let impl = HStringInt32MapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<HString, Int32>>.descriptorSchema(), IMapView<HString, Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<HString, Int32>.descriptor())
    object.close()
    result
}

class HStringInt32MapAbiTestImpl <: IMap_Impl<HString, Int32> & Resource {
    private let entries: ArrayList<(HString, Int32)>
    private let vtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(HString, Int32)>) {
        this.entries = cloneHStringInt32MapEntries(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.new<HStringInt32MapAbiTestImpl, HString, Int32>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<HStringInt32MapAbiTestImpl, IKeyValuePair<HString, Int32>>())
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
        closeHStringInt32MapEntries(entries)
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

    public func First(): Result<IIterator<IKeyValuePair<HString, Int32>>> {
        Result<IIterator<IKeyValuePair<HString, Int32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<HString, Int32>>(materializePairViews<HString, Int32>(entries))
        )
    }

    public func Lookup(key: HString): Result<Int32> {
        match (findHStringInt32MapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<Int32>.Ok(value)
                    case None => Result<Int32>.Err(stockBoundsError())
                }
            case None => Result<Int32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: HString): Result<Bool> {
        match (findHStringInt32MapEntry(entries, key)) {
            case Some(_) => Result<Bool>.Ok(true)
            case None => Result<Bool>.Ok(false)
        }
    }

    public func GetView(): Result<IMapView<HString, Int32>> {
        Result<IMapView<HString, Int32>>.Ok(createHStringInt32MapViewAbiTest(entries))
    }

    public func Insert(key: HString, value: Int32): Result<Bool> {
        match (findHStringInt32MapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((previousKey, _)) => previousKey.close()
                    case None => ()
                }
                entries[offset] = (key.clone(), value)
                Result<Bool>.Ok(true)
            case None =>
                entries.add((key.clone(), value))
                Result<Bool>.Ok(false)
        }
    }

    public func Remove(key: HString): Result<Unit> {
        match (findHStringInt32MapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((previousKey, _)) => previousKey.close()
                    case None => ()
                }
                entries.remove(at: offset)
                Result<Unit>.Ok(())
            case None =>
                Result<Unit>.Err(stockBoundsError())
        }
    }

    public func Clear(): Result<Unit> {
        closeHStringInt32MapEntries(entries)
        Result<Unit>.Ok(())
    }
}

func createHStringInt32MapAbiTest(entries: ArrayList<(HString, Int32)>): IMap<HString, Int32> {
    let impl = HStringInt32MapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<HString, Int32>>.descriptorSchema(), IMap<HString, Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<HString, Int32>.descriptor())
    object.close()
    result
}

func assertHStringInt32MapViewUsesHandleKeyAbi(view: IMapView<HString, Int32>, first: HString, second: HString): Unit {
    @Expect(unsafe { view.Lookup(second) }, 20i32)
    @Expect(unsafe { view.HasKey(first) }, true)

    let vtbl = unsafe { view.vtbl() }
    let directLookup = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let directHasKey = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))

    var directValue = 0i32
    try (keyBorrow = winrtBorrowGenericIn<HString>(first)) {
        let lookupHr = unsafe { directLookup(view.asRaw(), keyBorrow.asRaw(), CPointer<Int32>(inout directValue)) }
        @Expect(lookupHr, S_OK.value)
    }
    @Expect(directValue, 10i32)

    var directFound = false
    try (keyBorrow = winrtBorrowGenericIn<HString>(second)) {
        let hasKeyHr = unsafe { directHasKey(view.asRaw(), keyBorrow.asRaw(), CPointer<Bool>(inout directFound)) }
        @Expect(hasKeyHr, S_OK.value)
    }
    @Expect(directFound, true)
}

@Test
func testHStringInt32MapViewUsesHandleKeyAbi() {
    let first = HString("first")
    let second = HString("second")
    let view = createHStringInt32MapViewAbiTest(ArrayList<(HString, Int32)>([(first, 10i32), (second, 20i32)]))

    try {
        assertHStringInt32MapViewUsesHandleKeyAbi(view, first, second)
    } finally {
        view.close()
        second.close()
        first.close()
    }
}

@Test
func testHStringInt32MapUsesHandleKeyAbiForMutableSlots() {
    let first = HString("first")
    let second = HString("second")
    let third = HString("third")
    let fourth = HString("fourth")
    let map = createHStringInt32MapAbiTest(ArrayList<(HString, Int32)>([(first, 10i32), (second, 20i32)]))

    try {
        @Expect(unsafe { map.HasKey(second) }, true)
        @Expect(unsafe { map.Lookup(first) }, 10i32)
        @Expect(unsafe { map.Insert(second, 22i32) }, true)
        @Expect(unsafe { map.Lookup(second) }, 22i32)
        @Expect(unsafe { map.Insert(third, 30i32) }, false)
        @Expect(unsafe { map.Size() }, 3u32)

        let view = unsafe { map.GetView() }
        try {
            @Expect(unsafe { view.Lookup(third) }, 30i32)
        } finally {
            view.close()
        }

        let vtbl = unsafe { map.vtbl() }
        let directLookup = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        let directHasKey = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
        let directInsert = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        let directRemove = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.Remove))

        var directValue = 0i32
        try (keyBorrow = winrtBorrowGenericIn<HString>(second)) {
            let lookupHr = unsafe { directLookup(map.asRaw(), keyBorrow.asRaw(), CPointer<Int32>(inout directValue)) }
            @Expect(lookupHr, S_OK.value)
        }
        @Expect(directValue, 22i32)

        var directFound = false
        try (keyBorrow = winrtBorrowGenericIn<HString>(third)) {
            let hasKeyHr = unsafe { directHasKey(map.asRaw(), keyBorrow.asRaw(), CPointer<Bool>(inout directFound)) }
            @Expect(hasKeyHr, S_OK.value)
        }
        @Expect(directFound, true)

        var directReplaced = true
        try (keyBorrow = winrtBorrowGenericIn<HString>(fourth)) {
            try (valueBorrow = winrtBorrowGenericIn<Int32>(40i32)) {
                let insertHr = unsafe {
                    directInsert(map.asRaw(), keyBorrow.asRaw(), valueBorrow.asRaw(), CPointer<Bool>(inout directReplaced))
                }
                @Expect(insertHr, S_OK.value)
            }
        }
        @Expect(directReplaced, false)
        @Expect(unsafe { map.Lookup(fourth) }, 40i32)

        try (keyBorrow = winrtBorrowGenericIn<HString>(second)) {
            let removeHr = unsafe { directRemove(map.asRaw(), keyBorrow.asRaw()) }
            @Expect(removeHr, S_OK.value)
        }
        @Expect(unsafe { map.HasKey(second) }, false)
    } finally {
        map.close()
        fourth.close()
        third.close()
        second.close()
        first.close()
    }
}
