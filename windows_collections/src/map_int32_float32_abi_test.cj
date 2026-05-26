package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class Int32Float32MapViewAbiTestImpl <: IMapView_Impl<Int32, Float32> & Resource {
    private let entries: ArrayList<(Int32, Float32)>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, Float32)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32Float32<Int32Float32MapViewAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32Float32MapViewAbiTestImpl, IKeyValuePair<Int32, Float32>>())
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(Int32, Float32)>): Int32Float32MapViewAbiTestImpl {
        Int32Float32MapViewAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(Int32, Float32)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<Int32Float32MapViewAbiTestImpl, Int32, Float32>())
            } else {
                windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32Float32<Int32Float32MapViewAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32Float32MapViewAbiTestImpl, IKeyValuePair<Int32, Float32>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, Float32>>> {
        Result<IIterator<IKeyValuePair<Int32, Float32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, Float32>>(materializePairViews<Int32, Float32>(entries))
        )
    }

    public func Lookup(key: Int32): Result<Float32> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<Float32>.Ok(candidateValue)
            }
        }
        Result<Float32>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
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

func createInt32Float32MapViewAbiTest(entries: ArrayList<(Int32, Float32)>): IMapView<Int32, Float32> {
    let impl = Int32Float32MapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, Float32>>.descriptorSchema(), IMapView<Int32, Float32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, Float32>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32Float32MapViewAbiTest(entries: ArrayList<(Int32, Float32)>): IMapView<Int32, Float32> {
    let impl = Int32Float32MapViewAbiTestImpl.withGenericVtbl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, Float32>>.descriptorSchema(), IMapView<Int32, Float32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, Float32>.descriptor())
    object.close()
    result
}

func assertInt32Float32MapViewUsesDirectAbi(view: IMapView<Int32, Float32>): Unit {
    @Expect(unsafe { view.Lookup(2i32) }, 2.25f32)

    let vtbl = unsafe { view.vtbl() }
    var directValue = 0.0f32
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Float32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<Float32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 1.5f32)

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)
}

@Test
func testInt32Float32MapViewUsesDirectValueAbi() {
    let entries = ArrayList<(Int32, Float32)>([(1i32, 1.5f32), (2i32, 2.25f32)])
    let view = createInt32Float32MapViewAbiTest(entries)

    assertInt32Float32MapViewUsesDirectAbi(view)

    view.close()
}

@Test
func testGenericInt32Float32MapViewBuilderUsesDirectValueAbiForSpecialization() {
    let entries = ArrayList<(Int32, Float32)>([(1i32, 1.5f32), (2i32, 2.25f32)])
    let view = createGenericBuilderInt32Float32MapViewAbiTest(entries)

    assertInt32Float32MapViewUsesDirectAbi(view)

    view.close()
}

class Int32Float32MapAbiTestImpl <: IMap_Impl<Int32, Float32> & Resource {
    private let entries: ArrayList<(Int32, Float32)>
    private let vtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, Float32)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.newInt32Float32<Int32Float32MapAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32Float32MapAbiTestImpl, IKeyValuePair<Int32, Float32>>())
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(Int32, Float32)>): Int32Float32MapAbiTestImpl {
        Int32Float32MapAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(Int32, Float32)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.new<Int32Float32MapAbiTestImpl, Int32, Float32>())
            } else {
                windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.newInt32Float32<Int32Float32MapAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32Float32MapAbiTestImpl, IKeyValuePair<Int32, Float32>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, Float32>>> {
        Result<IIterator<IKeyValuePair<Int32, Float32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, Float32>>(materializePairViews<Int32, Float32>(entries))
        )
    }

    public func Lookup(key: Int32): Result<Float32> {
        match (findIndex(key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<Float32>.Ok(value)
                    case None => Result<Float32>.Err(stockBoundsError())
                }
            case None => Result<Float32>.Err(stockBoundsError())
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

    public func GetView(): Result<IMapView<Int32, Float32>> {
        Result<IMapView<Int32, Float32>>.Ok(createInt32Float32MapViewAbiTest(entries))
    }

    public func Insert(key: Int32, value: Float32): Result<Bool> {
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

func createInt32Float32MapAbiTest(entries: ArrayList<(Int32, Float32)>): IMap<Int32, Float32> {
    let impl = Int32Float32MapAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, Float32>>.descriptorSchema(), IMap<Int32, Float32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, Float32>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32Float32MapAbiTest(entries: ArrayList<(Int32, Float32)>): IMap<Int32, Float32> {
    let impl = Int32Float32MapAbiTestImpl.withGenericVtbl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, Float32>>.descriptorSchema(), IMap<Int32, Float32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<Int32, Float32>.descriptor())
    object.close()
    result
}

func assertInt32Float32MapUsesDirectAbi(map: IMap<Int32, Float32>): Unit {
    @Expect(unsafe { map.HasKey(2i32) }, true)
    @Expect(unsafe { map.Lookup(1i32) }, 1.5f32)
    @Expect(unsafe { map.Insert(2i32, 2.5f32) }, true)
    @Expect(unsafe { map.Lookup(2i32) }, 2.5f32)
    @Expect(unsafe { map.Insert(3i32, 3.5f32) }, false)
    unsafe { map.Remove(1i32) }
    @Expect(unsafe { map.HasKey(1i32) }, false)
    @Expect(unsafe { map.Size() }, 2u32)

    let vtbl = unsafe { map.vtbl() }
    var directValue = 0.0f32
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Float32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 2i32, CPointer<Float32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 2.5f32)

    var directFound = true
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(map.asRaw(), 1i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    var replaced = false
    let directInsert = CFunc<(CPointer<Unit>, Int32, Float32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
    let insertHr = unsafe { directInsert(map.asRaw(), 4i32, 4.5f32, CPointer<Bool>(inout replaced)) }
    @Expect(insertHr, S_OK.value)
    @Expect(replaced, false)
    @Expect(unsafe { map.Lookup(4i32) }, 4.5f32)

    let directRemove = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Remove))
    let removeHr = unsafe { directRemove(map.asRaw(), 2i32) }
    @Expect(removeHr, S_OK.value)
    @Expect(unsafe { map.HasKey(2i32) }, false)
}

@Test
func testInt32Float32MapUsesDirectValueAbiForMutableSlots() {
    let source = ArrayList<(Int32, Float32)>([(1i32, 1.5f32), (2i32, 2.25f32)])
    let map = createInt32Float32MapAbiTest(source)

    assertInt32Float32MapUsesDirectAbi(map)

    map.close()
}

@Test
func testGenericInt32Float32MapBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<(Int32, Float32)>([(1i32, 1.5f32), (2i32, 2.25f32)])
    let map = createGenericBuilderInt32Float32MapAbiTest(source)

    assertInt32Float32MapUsesDirectAbi(map)

    map.close()
}
