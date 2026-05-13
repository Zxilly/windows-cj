package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{HString, Result, S_OK, createComObjectFromSchemas}

class GenericBuilderInt32MapViewAbiTestImpl <: IMapView_Impl<Int32, Int32> {
    private let entries: ArrayList<(Int32, Int32)>
    private let vtblHandle: CPointerHandle<IMapViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, Int32)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            acquireArrayRawData(
                Array<IMapViewVtbl>(1, { _ => IMapViewVtbl.new<GenericBuilderInt32MapViewAbiTestImpl, Int32, Int32>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(
                    1,
                    { _ => IIterableVtbl.new<GenericBuilderInt32MapViewAbiTestImpl, IKeyValuePair<Int32, Int32>>() }
                )
            )
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle.pointer)
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        Result<IIterator<IKeyValuePair<Int32, Int32>>>.Ok(
            createStockIterator<IKeyValuePair<Int32, Int32>>(materializePairViews<Int32, Int32>(entries))
        )
    }

    public func Lookup(key: Int32): Result<Int32> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<Int32>.Ok(candidateValue)
            }
        }
        Result<Int32>.Err(stockBoundsError())
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

class GenericBuilderInt32HStringMapViewAbiTestImpl <: IMapView_Impl<Int32, HString> {
    private let entries: ArrayList<(Int32, HString)>
    private let vtblHandle: CPointerHandle<IMapViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, HString)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            acquireArrayRawData(
                Array<IMapViewVtbl>(
                    1,
                    { _ => IMapViewVtbl.new<GenericBuilderInt32HStringMapViewAbiTestImpl, Int32, HString>() }
                )
            )
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(
                    1,
                    { _ => IIterableVtbl.new<GenericBuilderInt32HStringMapViewAbiTestImpl, IKeyValuePair<Int32, HString>>() }
                )
            )
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle.pointer)
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Ok(
            createStockIterator<IKeyValuePair<Int32, HString>>(materializePairViews<Int32, HString>(entries))
        )
    }

    public func Lookup(key: Int32): Result<HString> {
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

func createGenericBuilderInt32MapViewAbiTest(entries: ArrayList<(Int32, Int32)>): IMapView<Int32, Int32> {
    let impl = GenericBuilderInt32MapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, Int32>>.descriptorSchema(), IMapView<Int32, Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IMapView<Int32, Int32>.descriptor())
}

func createGenericBuilderInt32HStringMapViewAbiTest(entries: ArrayList<(Int32, HString)>): IMapView<Int32, HString> {
    let impl = GenericBuilderInt32HStringMapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, HString>>.descriptorSchema(), IMapView<Int32, HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    object.toInterface(IMapView<Int32, HString>.descriptor())
}

@Test
func testGenericInt32MapViewBuilderUsesDirectValueAbiForSpecialization() {
    let entries = ArrayList<(Int32, Int32)>([(1i32, 10i32), (2i32, 20i32)])
    let view = createGenericBuilderInt32MapViewAbiTest(entries)

    @Expect(unsafe { view.Lookup(2i32) }, 20i32)

    let vtbl = unsafe { view.vtbl() }
    var directValue = 0i32
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<Int32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 10i32)

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)

    view.close()
}

@Test
func testGenericInt32HStringMapViewBuilderUsesDirectKeyAbiForSpecialization() {
    let one = HString("one")
    let two = HString("two")
    let entries = ArrayList<(Int32, HString)>([(1i32, one), (2i32, two)])
    let view = createGenericBuilderInt32HStringMapViewAbiTest(entries)

    let wrapperValue = unsafe { view.Lookup(2i32) }
    @Expect(wrapperValue.get(), "two")
    wrapperValue.close()

    let vtbl = unsafe { view.vtbl() }
    var directRaw = CPointer<Unit>()
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(view.asRaw(), 1i32, CPointer<CPointer<Unit>>(inout directRaw)) }
    @Expect(lookupHr, S_OK.value)
    let directValue = HString.fromSystemHandleTake(directRaw)
    @Expect(directValue.get(), "one")
    directValue.close()

    var directFound = false
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(view.asRaw(), 2i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, true)

    view.close()
    one.close()
    two.close()
}
