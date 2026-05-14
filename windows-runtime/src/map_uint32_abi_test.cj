package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class GenericBuilderUInt32MapViewAbiTestImpl <: IMapView_Impl<UInt32, UInt32> & Resource {
    private let entries: ArrayList<(UInt32, UInt32)>
    private let vtblHandle: CPointerHandle<IMapViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(UInt32, UInt32)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IMapViewVtbl>(1, { _ => IMapViewVtbl.new<GenericBuilderUInt32MapViewAbiTestImpl, UInt32, UInt32>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<GenericBuilderUInt32MapViewAbiTestImpl, IKeyValuePair<UInt32, UInt32>>() }))
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

    public func First(): Result<IIterator<IKeyValuePair<UInt32, UInt32>>> {
        Result<IIterator<IKeyValuePair<UInt32, UInt32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<UInt32, UInt32>>(materializePairViews<UInt32, UInt32>(entries))
        )
    }

    public func Lookup(key: UInt32): Result<UInt32> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<UInt32>.Ok(candidateValue)
            }
        }
        Result<UInt32>.Err(stockBoundsError())
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

class UInt32MapAbiTestImpl <: IMap_Impl<UInt32, UInt32> & Resource {
    private let entries: ArrayList<(UInt32, UInt32)>
    private let vtblHandle: CPointerHandle<IMapVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(UInt32, UInt32)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IMapVtbl>(1, { _ => IMapVtbl.newUInt32UInt32<UInt32MapAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt32MapAbiTestImpl, IKeyValuePair<UInt32, UInt32>>() }))
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(UInt32, UInt32)>): UInt32MapAbiTestImpl {
        UInt32MapAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(UInt32, UInt32)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(Array<IMapVtbl>(1, { _ => IMapVtbl.new<UInt32MapAbiTestImpl, UInt32, UInt32>() }))
            } else {
                acquireArrayRawData(Array<IMapVtbl>(1, { _ => IMapVtbl.newUInt32UInt32<UInt32MapAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<UInt32MapAbiTestImpl, IKeyValuePair<UInt32, UInt32>>() }))
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

    public func First(): Result<IIterator<IKeyValuePair<UInt32, UInt32>>> {
        Result<IIterator<IKeyValuePair<UInt32, UInt32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<UInt32, UInt32>>(materializePairViews<UInt32, UInt32>(entries))
        )
    }

    public func Lookup(key: UInt32): Result<UInt32> {
        match (findIndex(key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<UInt32>.Ok(value)
                    case None => Result<UInt32>.Err(stockBoundsError())
                }
            case None => Result<UInt32>.Err(stockBoundsError())
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

    public func GetView(): Result<IMapView<UInt32, UInt32>> {
        Result<IMapView<UInt32, UInt32>>.Ok(createGenericBuilderUInt32MapViewAbiTest(entries))
    }

    public func Insert(key: UInt32, value: UInt32): Result<Bool> {
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

func createGenericBuilderUInt32MapViewAbiTest(entries: ArrayList<(UInt32, UInt32)>): IMapView<UInt32, UInt32> {
    let impl = GenericBuilderUInt32MapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<UInt32, UInt32>>.descriptorSchema(), IMapView<UInt32, UInt32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<UInt32, UInt32>.descriptor())
    object.close()
    result
}

func createUInt32MapAbiTest(entries: ArrayList<(UInt32, UInt32)>): IMap<UInt32, UInt32> {
    let impl = UInt32MapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<UInt32, UInt32>>.descriptorSchema(), IMap<UInt32, UInt32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<UInt32, UInt32>.descriptor())
    object.close()
    result
}

func createGenericBuilderUInt32MapAbiTest(entries: ArrayList<(UInt32, UInt32)>): IMap<UInt32, UInt32> {
    let impl = UInt32MapAbiTestImpl.withGenericVtbl(entries)
    let schemas = [IIterable<IKeyValuePair<UInt32, UInt32>>.descriptorSchema(), IMap<UInt32, UInt32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<UInt32, UInt32>.descriptor())
    object.close()
    result
}

@Test
func testGenericUInt32MapViewBuilderUsesDirectValueAbiForSpecialization() {
    let entries = ArrayList<(UInt32, UInt32)>([(1u32, 10u32), (2u32, 20u32)])
    let view = createGenericBuilderUInt32MapViewAbiTest(entries)

    @Expect(unsafe { view.Lookup(2u32) }, 20u32)

    let vtbl = unsafe { view.vtbl() }
    var directValue = 0u32
    let directLookup = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1u32, CPointer<UInt32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 10u32)

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, UInt32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2u32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)

    view.close()
}

@Test
func testUInt32MapUsesDirectValueAbiForMutableSlots() {
    let source = ArrayList<(UInt32, UInt32)>([(1u32, 10u32), (2u32, 20u32)])
    let map = createUInt32MapAbiTest(source)

    @Expect(unsafe { map.HasKey(2u32) }, true)
    @Expect(unsafe { map.Lookup(1u32) }, 10u32)
    @Expect(unsafe { map.Insert(2u32, 22u32) }, true)
    @Expect(unsafe { map.Lookup(2u32) }, 22u32)
    @Expect(unsafe { map.Insert(3u32, 30u32) }, false)
    unsafe { map.Remove(1u32) }
    @Expect(unsafe { map.HasKey(1u32) }, false)
    @Expect(unsafe { map.Size() }, 2u32)

    let vtbl = unsafe { map.vtbl() }
    var directValue = 0u32
    let directLookup = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 2u32, CPointer<UInt32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 22u32)

    var directFound = true
    let directHasKey = CFunc<(CPointer<Unit>, UInt32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(map.asRaw(), 1u32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    var replaced = false
    let directInsert = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
    let insertHr = unsafe { directInsert(map.asRaw(), 4u32, 40u32, CPointer<Bool>(inout replaced)) }
    @Expect(insertHr, S_OK.value)
    @Expect(replaced, false)
    @Expect(unsafe { map.Lookup(4u32) }, 40u32)

    let directRemove = CFunc<(CPointer<Unit>, UInt32) -> Int32>(CPointer<Unit>(vtbl.Remove))
    let removeHr = unsafe { directRemove(map.asRaw(), 2u32) }
    @Expect(removeHr, S_OK.value)
    @Expect(unsafe { map.HasKey(2u32) }, false)

    map.close()
}

@Test
func testGenericUInt32MapBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<(UInt32, UInt32)>([(7u32, 70u32)])
    let map = createGenericBuilderUInt32MapAbiTest(source)

    @Expect(unsafe { map.Lookup(7u32) }, 70u32)

    let vtbl = unsafe { map.vtbl() }
    var directValue = 0u32
    let directLookup = CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 7u32, CPointer<UInt32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 70u32)

    var replaced = false
    let directInsert = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
    let insertHr = unsafe { directInsert(map.asRaw(), 7u32, 77u32, CPointer<Bool>(inout replaced)) }
    @Expect(insertHr, S_OK.value)
    @Expect(replaced, true)
    @Expect(unsafe { map.Lookup(7u32) }, 77u32)

    map.close()
}
