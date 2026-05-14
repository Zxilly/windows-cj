package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{HString, Result, S_OK, createComObjectFromSchemas, winrtBorrowGenericIn}

class GenericBuilderUInt32HStringMapViewAbiTestImpl <: IMapView_Impl<UInt32, HString> & Resource {
    private let entries: ArrayList<(UInt32, HString)>
    private let vtblHandle: CPointerHandle<IMapViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(UInt32, HString)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IMapViewVtbl>(1, { _ => IMapViewVtbl.new<GenericBuilderUInt32HStringMapViewAbiTestImpl, UInt32, HString>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<GenericBuilderUInt32HStringMapViewAbiTestImpl, IKeyValuePair<UInt32, HString>>() }))
        }
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

    public func First(): Result<IIterator<IKeyValuePair<UInt32, HString>>> {
        Result<IIterator<IKeyValuePair<UInt32, HString>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<UInt32, HString>>(materializePairViews<UInt32, HString>(entries))
        )
    }

    public func Lookup(key: UInt32): Result<HString> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<HString>.Ok(candidateValue)
            }
        }
        Result<HString>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: UInt32): Result<Bool> {
        for ((candidateKey, _) in entries) {
            if (candidateKey == key) {
                return Result<Bool>.Ok(true)
            }
        }
        Result<Bool>.Ok(false)
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

class UInt32HStringMapAbiTestImpl <: IMap_Impl<UInt32, HString> & Resource {
    private let entries: ArrayList<(UInt32, HString)>
    private let vtblHandle: CPointerHandle<IMapVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(UInt32, HString)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IMapVtbl>(1, { _ => IMapVtbl.newUInt32HString<UInt32HStringMapAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt32HStringMapAbiTestImpl, IKeyValuePair<UInt32, HString>>() }))
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(UInt32, HString)>): UInt32HStringMapAbiTestImpl {
        UInt32HStringMapAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(UInt32, HString)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IMapVtbl>(1, { _ => IMapVtbl.new<UInt32HStringMapAbiTestImpl, UInt32, HString>() }))
            } else {
                acquireArrayRawData(Array<IMapVtbl>(1, { _ => IMapVtbl.newUInt32HString<UInt32HStringMapAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt32HStringMapAbiTestImpl, IKeyValuePair<UInt32, HString>>() }))
        }
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

    private func findIndex(key: UInt32): ?Int64 {
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

    public func First(): Result<IIterator<IKeyValuePair<UInt32, HString>>> {
        Result<IIterator<IKeyValuePair<UInt32, HString>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<UInt32, HString>>(materializePairViews<UInt32, HString>(entries))
        )
    }

    public func Lookup(key: UInt32): Result<HString> {
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

    public func HasKey(key: UInt32): Result<Bool> {
        match (findIndex(key)) {
            case Some(_) => Result<Bool>.Ok(true)
            case None => Result<Bool>.Ok(false)
        }
    }

    public func GetView(): Result<IMapView<UInt32, HString>> {
        Result<IMapView<UInt32, HString>>.Ok(createGenericBuilderUInt32HStringMapViewAbiTest(entries))
    }

    public func Insert(key: UInt32, value: HString): Result<Bool> {
        match (findIndex(key)) {
            case Some(offset) =>
                entries[offset] = (key, value)
                Result<Bool>.Ok(true)
            case None =>
                entries.add((key, value))
                Result<Bool>.Ok(false)
        }
    }

    public func Remove(key: UInt32): Result<Unit> {
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

func createGenericBuilderUInt32HStringMapViewAbiTest(entries: ArrayList<(UInt32, HString)>): IMapView<UInt32, HString> {
    let impl = GenericBuilderUInt32HStringMapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<UInt32, HString>>.descriptorSchema(), IMapView<UInt32, HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<UInt32, HString>.descriptor())
    object.close()
    result
}

func createUInt32HStringMapAbiTest(entries: ArrayList<(UInt32, HString)>): IMap<UInt32, HString> {
    let impl = UInt32HStringMapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<UInt32, HString>>.descriptorSchema(), IMap<UInt32, HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<UInt32, HString>.descriptor())
    object.close()
    result
}

func createGenericBuilderUInt32HStringMapAbiTest(entries: ArrayList<(UInt32, HString)>): IMap<UInt32, HString> {
    let impl = UInt32HStringMapAbiTestImpl.withGenericVtbl(entries)
    let schemas = [IIterable<IKeyValuePair<UInt32, HString>>.descriptorSchema(), IMap<UInt32, HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<UInt32, HString>.descriptor())
    object.close()
    result
}

@Test
func testGenericUInt32HStringMapViewBuilderUsesDirectKeyAbiForSpecialization() {
    let one = HString("one")
    let two = HString("two")
    let entries = ArrayList<(UInt32, HString)>([(1u32, one), (2u32, two)])
    let view = createGenericBuilderUInt32HStringMapViewAbiTest(entries)

    let wrapperValue = unsafe { view.Lookup(2u32) }
    @Expect(wrapperValue.get(), "two")
    wrapperValue.close()

    let vtbl = unsafe { view.vtbl() }
    var directRaw = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1u32, CPointer<CPointer<Unit>>(inout directRaw)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = HString.fromSystemHandleTake(directRaw)
    @Expect(directValue.get(), "one")
    directValue.close()

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, UInt32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2u32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)

    view.close()
    one.close()
    two.close()
}

@Test
func testUInt32HStringMapUsesDirectKeyAndHStringValueAbiForMutableSlots() {
    let one = HString("one")
    let two = HString("two")
    let replacement = HString("two-updated")
    let inserted = HString("three")
    let source = ArrayList<(UInt32, HString)>([(1u32, one), (2u32, two)])
    let map = createUInt32HStringMapAbiTest(source)

    @Expect(unsafe { map.HasKey(2u32) }, true)
    let wrapperValue = unsafe { map.Lookup(1u32) }
    @Expect(wrapperValue.get(), "one")
    wrapperValue.close()
    @Expect(unsafe { map.Insert(2u32, replacement) }, true)
    let replacedValue = unsafe { map.Lookup(2u32) }
    @Expect(replacedValue.get(), "two-updated")
    replacedValue.close()
    @Expect(unsafe { map.Insert(3u32, inserted) }, false)
    unsafe { map.Remove(1u32) }
    @Expect(unsafe { map.HasKey(1u32) }, false)
    @Expect(unsafe { map.Size() }, 2u32)

    let vtbl = unsafe { map.vtbl() }
    var directRaw = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 2u32, CPointer<CPointer<Unit>>(inout directRaw)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = HString.fromSystemHandleTake(directRaw)
    @Expect(directValue.get(), "two-updated")
    directValue.close()

    var directFound = true
    let directHasKey = CFunc<(CPointer<Unit>, UInt32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(map.asRaw(), 1u32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    let four = HString("four")
    var replaced = true
    try (borrow = winrtBorrowGenericIn<HString>(four)) {
        let directInsert = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        let insertHr = unsafe { directInsert(map.asRaw(), 4u32, borrow.asRaw(), CPointer<Bool>(inout replaced)) }
        @Expect(insertHr, S_OK.value)
    }
    @Expect(replaced, false)
    let insertedValue = unsafe { map.Lookup(4u32) }
    @Expect(insertedValue.get(), "four")
    insertedValue.close()

    let directRemove = CFunc<(CPointer<Unit>, UInt32) -> Int32>(CPointer<Unit>(vtbl.Remove))
    let removeHr = unsafe { directRemove(map.asRaw(), 2u32) }
    @Expect(removeHr, S_OK.value)
    @Expect(unsafe { map.HasKey(2u32) }, false)

    map.close()
    one.close()
    two.close()
    replacement.close()
    inserted.close()
    four.close()
}

@Test
func testGenericUInt32HStringMapBuilderUsesDirectAbiForSpecialization() {
    let one = HString("one")
    let two = HString("two")
    let source = ArrayList<(UInt32, HString)>([(1u32, one), (2u32, two)])
    let map = createGenericBuilderUInt32HStringMapAbiTest(source)

    let wrapperValue = unsafe { map.Lookup(2u32) }
    @Expect(wrapperValue.get(), "two")
    wrapperValue.close()

    let vtbl = unsafe { map.vtbl() }
    let replacement = HString("updated")
    var directReplaced = false
    try (borrow = winrtBorrowGenericIn<HString>(replacement)) {
        let directInsert = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        let insertHr = unsafe { directInsert(map.asRaw(), 2u32, borrow.asRaw(), CPointer<Bool>(inout directReplaced)) }
        @Expect(insertHr, S_OK.value)
    }
    @Expect(directReplaced, true)
    let replacedValue = unsafe { map.Lookup(2u32) }
    @Expect(replacedValue.get(), "updated")
    replacedValue.close()

    var directRaw = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 1u32, CPointer<CPointer<Unit>>(inout directRaw)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = HString.fromSystemHandleTake(directRaw)
    @Expect(directValue.get(), "one")
    directValue.close()

    map.close()
    one.close()
    two.close()
    replacement.close()
}
