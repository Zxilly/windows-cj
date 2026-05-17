package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{HString, Result, S_OK, createComObjectFromSchemas, winrtBorrowGenericIn}

class Int32HStringMapAbiTestImpl <: IMap_Impl<Int32, HString> & Resource {
    private let entries: ArrayList<(Int32, HString)>
    private let vtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, HString)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.newInt32HString<Int32HStringMapAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32HStringMapAbiTestImpl, IKeyValuePair<Int32, HString>>())
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(Int32, HString)>): Int32HStringMapAbiTestImpl {
        Int32HStringMapAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(Int32, HString)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.new<Int32HStringMapAbiTestImpl, Int32, HString>())
            } else {
                windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.newInt32HString<Int32HStringMapAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32HStringMapAbiTestImpl, IKeyValuePair<Int32, HString>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, HString>>(materializePairViews<Int32, HString>(entries))
        )
    }

    public func Lookup(key: Int32): Result<HString> {
        match (findIndex(key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<HString>.Ok(value)
                    case None => Result<HString>.Err(stockBoundsError())
                }
            case None => Result<HString>.Err(stockBoundsError())
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

    public func GetView(): Result<IMapView<Int32, HString>> {
        Result<IMapView<Int32, HString>>.Ok(toMapView(entries))
    }

    public func Insert(key: Int32, value: HString): Result<Bool> {
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

func createInt32HStringMapAbiTest(entries: ArrayList<(Int32, HString)>): IMap<Int32, HString> {
    let impl = Int32HStringMapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, HString>>.descriptorSchema(), IMap<Int32, HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, HString>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32HStringMapAbiTest(entries: ArrayList<(Int32, HString)>): IMap<Int32, HString> {
    let impl = Int32HStringMapAbiTestImpl.withGenericVtbl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, HString>>.descriptorSchema(), IMap<Int32, HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, HString>.descriptor())
    object.close()
    result
}

@Test
func testInt32HStringMapUsesDirectKeyAndHStringValueAbiForMutableSlots() {
    let one = HString("one")
    let two = HString("two")
    let replacement = HString("two-updated")
    let inserted = HString("three")
    let source = ArrayList<(Int32, HString)>([(1i32, one), (2i32, two)])
    let map = createInt32HStringMapAbiTest(source)

    @Expect(unsafe { map.HasKey(2i32) }, true)
    let wrapperValue = unsafe { map.Lookup(1i32) }
    @Expect(wrapperValue.get(), "one")
    wrapperValue.close()
    @Expect(unsafe { map.Insert(2i32, replacement) }, true)
    let replacedValue = unsafe { map.Lookup(2i32) }
    @Expect(replacedValue.get(), "two-updated")
    replacedValue.close()
    @Expect(unsafe { map.Insert(3i32, inserted) }, false)
    unsafe { map.Remove(1i32) }
    @Expect(unsafe { map.HasKey(1i32) }, false)
    @Expect(unsafe { map.Size() }, 2u32)

    let vtbl = unsafe { map.vtbl() }
    var directRaw = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 2i32, CPointer<CPointer<Unit>>(inout directRaw)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = HString.fromSystemHandleTake(directRaw)
    @Expect(directValue.get(), "two-updated")
    directValue.close()

    var directFound = true
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(map.asRaw(), 1i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    let four = HString("four")
    var replaced = true
    try (borrow = winrtBorrowGenericIn<HString>(four)) {
        let directInsert = CFunc<(CPointer<Unit>, Int32, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        let insertHr = unsafe { directInsert(map.asRaw(), 4i32, borrow.asRaw(), CPointer<Bool>(inout replaced)) }
        @Expect(insertHr, S_OK.value)
    }
    @Expect(replaced, false)
    let insertedValue = unsafe { map.Lookup(4i32) }
    @Expect(insertedValue.get(), "four")
    insertedValue.close()

    let directRemove = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Remove))
    let removeHr = unsafe { directRemove(map.asRaw(), 2i32) }
    @Expect(removeHr, S_OK.value)
    @Expect(unsafe { map.HasKey(2i32) }, false)

    map.close()
    one.close()
    two.close()
    replacement.close()
    inserted.close()
    four.close()
}

@Test
func testGenericInt32HStringMapBuilderUsesDirectAbiForSpecialization() {
    let one = HString("one")
    let two = HString("two")
    let source = ArrayList<(Int32, HString)>([(1i32, one), (2i32, two)])
    let map = createGenericBuilderInt32HStringMapAbiTest(source)

    let wrapperValue = unsafe { map.Lookup(2i32) }
    @Expect(wrapperValue.get(), "two")
    wrapperValue.close()

    let vtbl = unsafe { map.vtbl() }
    let replacement = HString("updated")
    var directReplaced = false
    try (borrow = winrtBorrowGenericIn<HString>(replacement)) {
        let directInsert = CFunc<(CPointer<Unit>, Int32, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        let insertHr = unsafe { directInsert(map.asRaw(), 2i32, borrow.asRaw(), CPointer<Bool>(inout directReplaced)) }
        @Expect(insertHr, S_OK.value)
    }
    @Expect(directReplaced, true)
    let replacedValue = unsafe { map.Lookup(2i32) }
    @Expect(replacedValue.get(), "updated")
    replacedValue.close()

    var directRaw = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 1i32, CPointer<CPointer<Unit>>(inout directRaw)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = HString.fromSystemHandleTake(directRaw)
    @Expect(directValue.get(), "one")
    directValue.close()

    map.close()
    one.close()
    two.close()
    replacement.close()
}
