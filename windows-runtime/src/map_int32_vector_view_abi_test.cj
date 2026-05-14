package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{Result, S_OK, createComObjectFromSchemas}

class Int32VectorViewMapViewAbiTestImpl <: IMapView_Impl<Int32, IVectorView<Int32>> & Resource {
    private let entries: ArrayList<(Int32, IVectorView<Int32>)>
    private let vtblHandle: CPointerHandle<IMapViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, IVectorView<Int32>)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            acquireArrayRawData(
                Array<IMapViewVtbl>(1, { _ => IMapViewVtbl.newInt32VectorViewInt32<Int32VectorViewMapViewAbiTestImpl>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Int32VectorViewMapViewAbiTestImpl, IKeyValuePair<Int32, IVectorView<Int32>>>() }))
        }
    }

    public static func withGenericVtbl(entries: ArrayList<(Int32, IVectorView<Int32>)>): Int32VectorViewMapViewAbiTestImpl {
        Int32VectorViewMapViewAbiTestImpl(entries, genericVtbl: true)
    }

    private init(entries: ArrayList<(Int32, IVectorView<Int32>)>, genericVtbl!: Bool) {
        this.entries = entries
        this.vtblHandle = unsafe {
            if (genericVtbl) {
                acquireArrayRawData(
                    Array<IMapViewVtbl>(1, { _ => IMapViewVtbl.new<Int32VectorViewMapViewAbiTestImpl, Int32, IVectorView<Int32>>() }))
            } else {
                acquireArrayRawData(
                    Array<IMapViewVtbl>(1, { _ => IMapViewVtbl.newInt32VectorViewInt32<Int32VectorViewMapViewAbiTestImpl>() }))
            }
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<Int32VectorViewMapViewAbiTestImpl, IKeyValuePair<Int32, IVectorView<Int32>>>() }))
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, IVectorView<Int32>>>> {
        Result<IIterator<IKeyValuePair<Int32, IVectorView<Int32>>>>.Ok(
            createStockIterator<IKeyValuePair<Int32, IVectorView<Int32>>>(
                materializePairViews<Int32, IVectorView<Int32>>(entries)
            )
        )
    }

    public func Lookup(key: Int32): Result<IVectorView<Int32>> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<IVectorView<Int32>>.Ok(candidateValue)
            }
        }
        Result<IVectorView<Int32>>.Err(stockBoundsError())
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

func createInt32VectorViewMapViewAbiTest(entries: ArrayList<(Int32, IVectorView<Int32>)>): IMapView<Int32, IVectorView<Int32>> {
    let impl = Int32VectorViewMapViewAbiTestImpl(entries)
    let schemas = [
        IIterable<IKeyValuePair<Int32, IVectorView<Int32>>>.descriptorSchema(),
        IMapView<Int32, IVectorView<Int32>>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, IVectorView<Int32>>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32VectorViewMapViewAbiTest(entries: ArrayList<(Int32, IVectorView<Int32>)>): IMapView<Int32, IVectorView<Int32>> {
    let impl = Int32VectorViewMapViewAbiTestImpl.withGenericVtbl(entries)
    let schemas = [
        IIterable<IKeyValuePair<Int32, IVectorView<Int32>>>.descriptorSchema(),
        IMapView<Int32, IVectorView<Int32>>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, IVectorView<Int32>>.descriptor())
    object.close()
    result
}

func makeInt32VectorViewMapViewEntries(): ArrayList<(Int32, IVectorView<Int32>)> {
    let first = toVectorView([1i32, 2i32, 3i32])
    let second = toVectorView([4i32, 5i32, 6i32])
    ArrayList<(Int32, IVectorView<Int32>)>([(1i32, first), (2i32, second)])
}

func assertInt32VectorViewMapViewUsesDirectAbi(view: IMapView<Int32, IVectorView<Int32>>): Unit {
    let wrapperValue = unsafe { view.Lookup(2i32) }
    @Expect(unsafe { wrapperValue.Size() }, 3u32)
    @Expect(unsafe { wrapperValue.GetAt(0u32) }, 4i32)
    @Expect(unsafe { wrapperValue.GetAt(2u32) }, 6i32)
    wrapperValue.close()

    let vtbl = unsafe { view.vtbl() }
    var rawValue = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<CPointer<Unit>>(inout rawValue)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = IVectorView<Int32>.fromAbiTake(rawValue)
    @Expect(unsafe { directValue.Size() }, 3u32)
    @Expect(unsafe { directValue.GetAt(0u32) }, 1i32)
    @Expect(unsafe { directValue.GetAt(2u32) }, 3i32)
    directValue.close()

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)
}

@Test
func testInt32VectorViewMapViewUsesDirectKeyAbi() {
    let entries = makeInt32VectorViewMapViewEntries()
    let view = createInt32VectorViewMapViewAbiTest(entries)

    assertInt32VectorViewMapViewUsesDirectAbi(view)

    view.close()
}

@Test
func testGenericInt32VectorViewMapViewBuilderUsesDirectKeyAbiForSpecialization() {
    let entries = makeInt32VectorViewMapViewEntries()
    let view = createGenericBuilderInt32VectorViewMapViewAbiTest(entries)

    assertInt32VectorViewMapViewUsesDirectAbi(view)

    view.close()
}

@Test
func testStockInt32VectorViewMapViewUsesDirectKeyAbi() {
    let entries = makeInt32VectorViewMapViewEntries()
    let view = toMapView(entries)

    assertInt32VectorViewMapViewUsesDirectAbi(view)

    view.close()
}
