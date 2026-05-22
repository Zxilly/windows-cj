package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, Result, S_OK, createComObjectFromSchemas}

class Int32MapAbiTestImpl <: IMap_Impl<Int32, Int32> & Resource {
    private let entries: ArrayList<(Int32, Int32)>
    private let vtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, Int32)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.newInt32Int32<Int32MapAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32MapAbiTestImpl, IKeyValuePair<Int32, Int32>>())
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(Int32, Int32)>): Int32MapAbiTestImpl {
        Int32MapAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(Int32, Int32)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.new<Int32MapAbiTestImpl, Int32, Int32>())
            } else {
                windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.newInt32Int32<Int32MapAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32MapAbiTestImpl, IKeyValuePair<Int32, Int32>>())
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

    private func findIndex(key: Int32): ?Int64 {
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        Result<IIterator<IKeyValuePair<Int32, Int32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, Int32>>(materializePairViews<Int32, Int32>(entries))
        )
    }

    public func Lookup(key: Int32): Result<Int32> {
        match (findIndex(key)) {
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

    public func HasKey(key: Int32): Result<Bool> {
        match (findIndex(key)) {
            case Some(_) => Result<Bool>.Ok(true)
            case None => Result<Bool>.Ok(false)
        }
    }

    public func GetView(): Result<IMapView<Int32, Int32>> {
        Result<IMapView<Int32, Int32>>.Ok(toMapView(entries))
    }

    public func Insert(key: Int32, value: Int32): Result<Bool> {
        match (findIndex(key)) {
            case Some(offset) =>
                entries[offset] = (key, value)
                Result<Bool>.Ok(true)
            case None =>
                entries.add((key, value))
                Result<Bool>.Ok(false)
        }
    }

    public func Remove(key: Int32): Result<Unit> {
        match (findIndex(key)) {
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

func createInt32MapAbiTest(entries: ArrayList<(Int32, Int32)>): IMap<Int32, Int32> {
    let impl = Int32MapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, Int32>>.descriptorSchema(), IMap<Int32, Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, Int32>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32MapAbiTest(entries: ArrayList<(Int32, Int32)>): IMap<Int32, Int32> {
    let impl = Int32MapAbiTestImpl.withGenericVtbl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, Int32>>.descriptorSchema(), IMap<Int32, Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, Int32>.descriptor())
    object.close()
    result
}

@Test
func testInt32MapUsesDirectValueAbiForMutableSlots() {
    let source = ArrayList<(Int32, Int32)>([(1i32, 10i32), (2i32, 20i32)])
    let map = createInt32MapAbiTest(source)

    @Expect(unsafe { map.HasKey(2i32) }, true)
    @Expect(unsafe { map.Lookup(1i32) }, 10i32)
    @Expect(unsafe { map.Insert(2i32, 22i32) }, true)
    @Expect(unsafe { map.Lookup(2i32) }, 22i32)
    @Expect(unsafe { map.Insert(3i32, 30i32) }, false)
    unsafe { map.Remove(1i32) }
    @Expect(unsafe { map.HasKey(1i32) }, false)
    @Expect(unsafe { map.Size() }, 2u32)

    let vtbl = unsafe { map.vtbl() }
    var directValue = 0i32
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 2i32, CPointer<Int32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 22i32)
    directValue = 99i32
    let missingLookupHr = unsafe { directLookup(map.asRaw(), 404i32, CPointer<Int32>(inout directValue)) }
    @Expect(missingLookupHr != S_OK.value, true)
    @Expect(directValue, 0i32)

    var directFound = true
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(map.asRaw(), 1i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    var replaced = false
    let directInsert = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
    let insertHr = unsafe { directInsert(map.asRaw(), 4i32, 40i32, CPointer<Bool>(inout replaced)) }
    @Expect(insertHr, S_OK.value)
    @Expect(replaced, false)
    @Expect(unsafe { map.Lookup(4i32) }, 40i32)

    let directRemove = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Remove))
    let removeHr = unsafe { directRemove(map.asRaw(), 2i32) }
    @Expect(removeHr, S_OK.value)
    @Expect(unsafe { map.HasKey(2i32) }, false)

    map.close()
}

@Test
func testGenericInt32MapBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<(Int32, Int32)>([(7i32, 70i32)])
    let map = createGenericBuilderInt32MapAbiTest(source)

    @Expect(unsafe { map.Lookup(7i32) }, 70i32)

    let vtbl = unsafe { map.vtbl() }
    var directValue = 0i32
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 7i32, CPointer<Int32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 70i32)
    directValue = 99i32
    let missingLookupHr = unsafe { directLookup(map.asRaw(), 404i32, CPointer<Int32>(inout directValue)) }
    @Expect(missingLookupHr != S_OK.value, true)
    @Expect(directValue, 0i32)

    var replaced = false
    let directInsert = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
    let insertHr = unsafe { directInsert(map.asRaw(), 7i32, 77i32, CPointer<Bool>(inout replaced)) }
    @Expect(insertHr, S_OK.value)
    @Expect(replaced, true)
    @Expect(unsafe { map.Lookup(7i32) }, 77i32)

    map.close()
}

@Test
func testInt32MapVtblNoneBranchClearsSpecializedOutSlots() {
    let vtbl = IMapVtbl.newInt32Int32<Int32MapAbiTestImpl>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IMapVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IMapVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(123i32) }
    let raw = CPointer<Unit>(objectHandle)
    var lookupValue = 99i32
    var sizeValue = 77u32
    var foundValue = true
    var viewValue = CPointer<Unit>(sentinel)
    var replacedValue = true

    try {
        let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        let lookupHr = unsafe { directLookup(raw, 1i32, CPointer<Int32>(inout lookupValue)) }
        @Expect(lookupHr, E_NOINTERFACE.value)
        @Expect(lookupValue, 0i32)

        let sizeHr = unsafe { vtbl.Size(raw, CPointer<UInt32>(inout sizeValue)) }
        @Expect(sizeHr, E_NOINTERFACE.value)
        @Expect(sizeValue, 0u32)

        let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
        let hasKeyHr = unsafe { directHasKey(raw, 1i32, CPointer<Bool>(inout foundValue)) }
        @Expect(hasKeyHr, E_NOINTERFACE.value)
        @Expect(foundValue, false)

        let getViewHr = unsafe { vtbl.GetView(raw, CPointer<CPointer<Unit>>(inout viewValue)) }
        @Expect(getViewHr, E_NOINTERFACE.value)
        @Expect(viewValue.isNull(), true)

        let directInsert = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        let insertHr = unsafe { directInsert(raw, 1i32, 2i32, CPointer<Bool>(inout replacedValue)) }
        @Expect(insertHr, E_NOINTERFACE.value)
        @Expect(replacedValue, false)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}
