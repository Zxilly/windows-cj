package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class Int32UInt64MapViewAbiTestImpl <: IMapView_Impl<Int32, UInt64> & Resource {
    private let entries: ArrayList<(Int32, UInt64)>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, UInt64)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32UInt64<Int32UInt64MapViewAbiTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32UInt64MapViewAbiTestImpl, IKeyValuePair<Int32, UInt64>>())
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(Int32, UInt64)>): Int32UInt64MapViewAbiTestImpl {
        Int32UInt64MapViewAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(Int32, UInt64)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<Int32UInt64MapViewAbiTestImpl, Int32, UInt64>())
            } else {
                windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32UInt64<Int32UInt64MapViewAbiTestImpl>())
            }
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<Int32UInt64MapViewAbiTestImpl, IKeyValuePair<Int32, UInt64>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, UInt64>>> {
        Result<IIterator<IKeyValuePair<Int32, UInt64>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, UInt64>>(materializePairViews<Int32, UInt64>(entries))
        )
    }

    public func Lookup(key: Int32): Result<UInt64> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<UInt64>.Ok(candidateValue)
            }
        }
        Result<UInt64>.Err(stockBoundsError())
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

func createInt32UInt64MapViewAbiTest(entries: ArrayList<(Int32, UInt64)>): IMapView<Int32, UInt64> {
    let impl = Int32UInt64MapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, UInt64>>.descriptorSchema(), IMapView<Int32, UInt64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, UInt64>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32UInt64MapViewAbiTest(entries: ArrayList<(Int32, UInt64)>): IMapView<Int32, UInt64> {
    let impl = Int32UInt64MapViewAbiTestImpl.withGenericVtbl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, UInt64>>.descriptorSchema(), IMapView<Int32, UInt64>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, UInt64>.descriptor())
    object.close()
    result
}

func assertInt32UInt64MapViewUsesDirectAbi(view: IMapView<Int32, UInt64>): Unit {
    @Expect(unsafe { view.Lookup(2i32) }, 20u64)

    let vtbl = unsafe { view.vtbl() }
    var directValue = 0u64
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<UInt64>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<UInt64>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 10u64)

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)
}

@Test
func testInt32UInt64MapViewUsesDirectValueAbi() {
    let entries = ArrayList<(Int32, UInt64)>([(1i32, 10u64), (2i32, 20u64)])
    let view = createInt32UInt64MapViewAbiTest(entries)

    assertInt32UInt64MapViewUsesDirectAbi(view)

    view.close()
}

@Test
func testGenericInt32UInt64MapViewBuilderUsesDirectValueAbiForSpecialization() {
    let entries = ArrayList<(Int32, UInt64)>([(1i32, 10u64), (2i32, 20u64)])
    let view = createGenericBuilderInt32UInt64MapViewAbiTest(entries)

    assertInt32UInt64MapViewUsesDirectAbi(view)

    view.close()
}

@Test
func testStockInt32UInt64MapViewUsesDirectValueAbi() {
    let entries = ArrayList<(Int32, UInt64)>([(1i32, 10u64), (2i32, 20u64)])
    let view = toMapView(entries)

    assertInt32UInt64MapViewUsesDirectAbi(view)

    view.close()
}
