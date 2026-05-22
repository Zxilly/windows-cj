package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, Result, S_OK, createComObjectFromSchemas}

func findInt32DateTimeMapEntry(entries: ArrayList<(Int32, DateTime)>, key: Int32): ?Int64 {
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

class Int32DateTimeMapViewAbiTestImpl <: IMapView_Impl<Int32, DateTime> & Resource {
    private let entries: ArrayList<(Int32, DateTime)>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, DateTime)>) {
        this.entries = ArrayList<(Int32, DateTime)>(entries.size, { index => entries[index] })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<Int32DateTimeMapViewAbiTestImpl, Int32, DateTime>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32DateTimeMapViewAbiTestImpl, IKeyValuePair<Int32, DateTime>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, DateTime>>> {
        Result<IIterator<IKeyValuePair<Int32, DateTime>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, DateTime>>(materializePairViews<Int32, DateTime>(entries))
        )
    }

    public func Lookup(key: Int32): Result<DateTime> {
        match (findInt32DateTimeMapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<DateTime>.Ok(value)
                    case None => Result<DateTime>.Err(stockBoundsError())
                }
            case None => Result<DateTime>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        match (findInt32DateTimeMapEntry(entries, key)) {
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

func createInt32DateTimeMapViewAbiTest(entries: ArrayList<(Int32, DateTime)>): IMapView<Int32, DateTime> {
    let impl = Int32DateTimeMapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, DateTime>>.descriptorSchema(), IMapView<Int32, DateTime>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, DateTime>.descriptor())
    object.close()
    result
}

class Int32DateTimeMapAbiTestImpl <: IMap_Impl<Int32, DateTime> & Resource {
    private let entries: ArrayList<(Int32, DateTime)>
    private let vtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, DateTime)>) {
        this.entries = ArrayList<(Int32, DateTime)>(entries.size, { index => entries[index] })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.new<Int32DateTimeMapAbiTestImpl, Int32, DateTime>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32DateTimeMapAbiTestImpl, IKeyValuePair<Int32, DateTime>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, DateTime>>> {
        Result<IIterator<IKeyValuePair<Int32, DateTime>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, DateTime>>(materializePairViews<Int32, DateTime>(entries))
        )
    }

    public func Lookup(key: Int32): Result<DateTime> {
        match (findInt32DateTimeMapEntry(entries, key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<DateTime>.Ok(value)
                    case None => Result<DateTime>.Err(stockBoundsError())
                }
            case None => Result<DateTime>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        match (findInt32DateTimeMapEntry(entries, key)) {
            case Some(_) => Result<Bool>.Ok(true)
            case None => Result<Bool>.Ok(false)
        }
    }

    public func GetView(): Result<IMapView<Int32, DateTime>> {
        Result<IMapView<Int32, DateTime>>.Ok(createInt32DateTimeMapViewAbiTest(entries))
    }

    public func Insert(key: Int32, value: DateTime): Result<Bool> {
        match (findInt32DateTimeMapEntry(entries, key)) {
            case Some(offset) =>
                entries[offset] = (key, value)
                Result<Bool>.Ok(true)
            case None =>
                entries.add((key, value))
                Result<Bool>.Ok(false)
        }
    }

    public func Remove(key: Int32): Result<Unit> {
        match (findInt32DateTimeMapEntry(entries, key)) {
            case Some(offset) =>
                entries.remove(at: offset)
                Result<Unit>.Ok(())
            case None =>
                Result<Unit>.Err(stockBoundsError())
        }
    }

    public func Clear(): Result<Unit> {
        entries.clear()
        Result<Unit>.Ok(())
    }
}

func createInt32DateTimeMapAbiTest(entries: ArrayList<(Int32, DateTime)>): IMap<Int32, DateTime> {
    let impl = Int32DateTimeMapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, DateTime>>.descriptorSchema(), IMap<Int32, DateTime>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, DateTime>.descriptor())
    object.close()
    result
}

func assertInt32DateTimeMapViewUsesDirectAbi(view: IMapView<Int32, DateTime>): Unit {
    @Expect(unsafe { view.Lookup(2i32) }.UniversalTime, 200i64)

    let vtbl = unsafe { view.vtbl() }
    var abiValue = DateTimeAbi()
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<DateTimeAbi>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<DateTimeAbi>(inout abiValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(DateTime.assumeInitRef(abiValue).UniversalTime, 100i64)

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)
}

@Test
func testInt32DateTimeMapViewUsesDirectCopyStructValueAbi() {
    let view = createInt32DateTimeMapViewAbiTest(
        ArrayList<(Int32, DateTime)>([(1i32, dateTimeTestValue(100i64)), (2i32, dateTimeTestValue(200i64))])
    )

    try {
        assertInt32DateTimeMapViewUsesDirectAbi(view)
    } finally {
        view.close()
    }
}

@Test
func testInt32DateTimeMapUsesDirectCopyStructValueAbiForMutableSlots() {
    let map = createInt32DateTimeMapAbiTest(
        ArrayList<(Int32, DateTime)>([(1i32, dateTimeTestValue(100i64)), (2i32, dateTimeTestValue(200i64))])
    )

    try {
        @Expect(unsafe { map.Lookup(1i32) }.UniversalTime, 100i64)
        @Expect(unsafe { map.Insert(2i32, dateTimeTestValue(220i64)) }, true)
        @Expect(unsafe { map.Lookup(2i32) }.UniversalTime, 220i64)
        @Expect(unsafe { map.Insert(3i32, dateTimeTestValue(300i64)) }, false)

        let view = unsafe { map.GetView() }
        try {
            @Expect(unsafe { view.Lookup(3i32) }.UniversalTime, 300i64)
        } finally {
            view.close()
        }

        let vtbl = unsafe { map.vtbl() }
        let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<DateTimeAbi>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        var abiValue = DateTimeAbi()
        let lookupHr = unsafe { directLookup(map.asRaw(), 2i32, CPointer<DateTimeAbi>(inout abiValue)) }
        @Expect(lookupHr, S_OK.value)
        @Expect(DateTime.assumeInitRef(abiValue).UniversalTime, 220i64)

        let directInsert = CFunc<(CPointer<Unit>, Int32, DateTimeAbi, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        var directReplaced = true
        let insertHr = unsafe {
            directInsert(map.asRaw(), 4i32, DateTime.projectAbi(dateTimeTestValue(400i64)), CPointer<Bool>(inout directReplaced))
        }
        @Expect(insertHr, S_OK.value)
        @Expect(directReplaced, false)
        @Expect(unsafe { map.Lookup(4i32) }.UniversalTime, 400i64)

        let directRemove = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Remove))
        let removeHr = unsafe { directRemove(map.asRaw(), 1i32) }
        @Expect(removeHr, S_OK.value)
        @Expect(unsafe { map.HasKey(1i32) }, false)
    } finally {
        map.close()
    }
}

@Test
func testInt32DateTimeMapViewVtblNoneBranchClearsSpecializedOutSlots() {
    let vtbl = IMapViewVtbl.new<Int32DateTimeMapViewAbiTestImpl, Int32, DateTime>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IMapViewVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IMapViewVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(654i32) }
    let raw = CPointer<Unit>(objectHandle)
    var lookupValue = DateTimeAbi()
    lookupValue.UniversalTime = 999i64
    var sizeValue = 77u32
    var foundValue = true
    var firstValue = CPointer<Unit>(sentinel)
    var secondValue = CPointer<Unit>(sentinel)

    try {
        let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<DateTimeAbi>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        let lookupHr = unsafe { directLookup(raw, 1i32, CPointer<DateTimeAbi>(inout lookupValue)) }
        @Expect(lookupHr, E_NOINTERFACE.value)
        @Expect(lookupValue.UniversalTime, 0i64)

        let sizeHr = unsafe { vtbl.Size(raw, CPointer<UInt32>(inout sizeValue)) }
        @Expect(sizeHr, E_NOINTERFACE.value)
        @Expect(sizeValue, 0u32)

        let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
        let hasKeyHr = unsafe { directHasKey(raw, 1i32, CPointer<Bool>(inout foundValue)) }
        @Expect(hasKeyHr, E_NOINTERFACE.value)
        @Expect(foundValue, false)

        let splitHr = unsafe {
            vtbl.Split(raw, CPointer<CPointer<Unit>>(inout firstValue), CPointer<CPointer<Unit>>(inout secondValue))
        }
        @Expect(splitHr, E_NOINTERFACE.value)
        @Expect(firstValue.isNull(), true)
        @Expect(secondValue.isNull(), true)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}
