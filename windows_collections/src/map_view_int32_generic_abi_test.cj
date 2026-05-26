package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_POINTER, HString, Result, S_OK, WindowsException, createComObjectFromSchemas}
import windows_core as windows_core

class GenericBuilderInt32MapViewAbiTestImpl <: IMapView_Impl<Int32, Int32> & Resource {
    private let entries: ArrayList<(Int32, Int32)>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, Int32)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<GenericBuilderInt32MapViewAbiTestImpl, Int32, Int32>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<GenericBuilderInt32MapViewAbiTestImpl, IKeyValuePair<Int32, Int32>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        Result<IIterator<IKeyValuePair<Int32, Int32>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, Int32>>(materializePairViews<Int32, Int32>(entries))
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

class GenericBuilderInt32HStringMapViewAbiTestImpl <: IMapView_Impl<Int32, HString> & Resource {
    private let entries: ArrayList<(Int32, HString)>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, HString)>) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<GenericBuilderInt32HStringMapViewAbiTestImpl, Int32, HString>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<GenericBuilderInt32HStringMapViewAbiTestImpl, IKeyValuePair<Int32, HString>>())
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<Int32, HString>>(materializePairViews<Int32, HString>(entries))
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

class ThrowingInt32HStringMapViewAbiTestImpl <: IMapView_Impl<Int32, HString> & Resource {
    private let vtblHandle: CPointer<IMapViewVtbl>
    private var closed: Bool = false
    public var throwWindows: Bool = true

    public init() {
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32HString<ThrowingInt32HStringMapViewAbiTestImpl>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
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

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Err(stockBoundsError())
    }

    public func Lookup(key: Int32): Result<HString> {
        let _ = key
        if (throwWindows) {
            throw WindowsException(E_POINTER)
        }
        throw Exception("plain Lookup failure")
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(0u32)
    }

    public func HasKey(key: Int32): Result<Bool> {
        let _ = key
        if (throwWindows) {
            throw WindowsException(E_POINTER)
        }
        throw Exception("plain HasKey failure")
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
    let result = object.toInterface(IMapView<Int32, Int32>.descriptor())
    object.close()
    result
}

func createGenericBuilderInt32HStringMapViewAbiTest(entries: ArrayList<(Int32, HString)>): IMapView<Int32, HString> {
    let impl = GenericBuilderInt32HStringMapViewAbiTestImpl(entries)
    let schemas = [IIterable<IKeyValuePair<Int32, HString>>.descriptorSchema(), IMapView<Int32, HString>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMapView<Int32, HString>.descriptor())
    object.close()
    result
}

func createThrowingInt32HStringMapViewAbiTest(
    impl: ThrowingInt32HStringMapViewAbiTestImpl
): IMapView<Int32, HString> {
    let object = createComObjectFromSchemas(impl, [IMapView<Int32, HString>.descriptorSchema()], impl.vtblPtr())
    let result = object.toInterface(IMapView<Int32, HString>.descriptor())
    object.close()
    result
}

func assertMapViewMissingHStringLookupClearsStaleSlot(view: IMapView<Int32, HString>): Unit {
    let stale = HString("stale-map-view-lookup")
    let staleRaw = stale.toSystemHandleCopy()
    stale.close()
    var directRaw = staleRaw
    try {
        let vtbl = unsafe { view.vtbl() }
        let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        let lookupHr = unsafe { directLookup(view.asRaw(), 404i32, CPointer<CPointer<Unit>>(inout directRaw)) }
        @Expect(lookupHr != S_OK.value, true)
        @Expect(directRaw.isNull(), true)
    } finally {
        if (directRaw.isNull()) {
            windows_core.releaseSystemHStringHandle(staleRaw)
        } else {
            windows_core.releaseSystemHStringHandle(directRaw)
        }
    }
}

func assertThrowingInt32HStringMapViewDirectThunks(view: IMapView<Int32, HString>, expectedHr: Int32): Unit {
    let vtbl = unsafe { view.vtbl() }
    let stale = HString("throwing-map-view-lookup")
    let staleRaw = stale.toSystemHandleCopy()
    stale.close()
    var directRaw = staleRaw
    var directFound = true
    try {
        let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        let lookupHr = unsafe { directLookup(view.asRaw(), 9i32, CPointer<CPointer<Unit>>(inout directRaw)) }
        @Expect(lookupHr, expectedHr)
        @Expect(directRaw.isNull(), true)

        let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
        let hasKeyHr = unsafe { directHasKey(view.asRaw(), 9i32, CPointer<Bool>(inout directFound)) }
        @Expect(hasKeyHr, expectedHr)
        @Expect(directFound, false)
    } finally {
        if (directRaw.isNotNull()) {
            windows_core.releaseSystemHStringHandle(directRaw)
        } else {
            windows_core.releaseSystemHStringHandle(staleRaw)
        }
    }
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
    directValue = 99i32
    let missingLookupHr = unsafe { directLookup(view.asRaw(), 404i32, CPointer<Int32>(inout directValue)) }
    @Expect(missingLookupHr != S_OK.value, true)
    @Expect(directValue, 0i32)

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
    assertMapViewMissingHStringLookupClearsStaleSlot(view)

    view.close()
    one.close()
    two.close()
}

@Test
func testInt32HStringMapViewSpecializedThunksTranslateThrownExceptions() {
    let impl = ThrowingInt32HStringMapViewAbiTestImpl()
    let view = createThrowingInt32HStringMapViewAbiTest(impl)
    try {
        impl.throwWindows = true
        assertThrowingInt32HStringMapViewDirectThunks(view, E_POINTER.value)
        impl.throwWindows = false
        assertThrowingInt32HStringMapViewDirectThunks(view, E_FAIL.value)
    } finally {
        view.close()
    }
}
