package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_POINTER, EventRegistrationToken, EventRegistrationTokenAbi, HString, InParam, Result, WinError, WindowsException, createComObjectFromSchemas}
class ObservableInt32HStringMapForwardingTestImpl <: IObservableMap_Impl<Int32, HString> & Resource {
    private let entries: ArrayList<(Int32, HString)>
    private let observableVtblHandle: CPointer<IObservableMapVtbl>
    private let mapVtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false
    public var failMapChanged: Bool = false
    public var throwWindowsOnMapChanged: Bool = false
    public var throwPlainOnRemoveMapChanged: Bool = false

    public init(entries: ArrayList<(Int32, HString)>) {
        this.entries = entries
        this.observableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IObservableMapVtbl>(IObservableMapVtbl.new<ObservableInt32HStringMapForwardingTestImpl, Int32, HString>())
        }
        this.mapVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(IMapVtbl.newInt32HString<ObservableInt32HStringMapForwardingTestImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<ObservableInt32HStringMapForwardingTestImpl, IKeyValuePair<Int32, HString>>())
        }
    }

    public func observableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(observableVtblHandle)
    }

    public func mapVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(mapVtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(mapVtblHandle)
            windows_interface.freeNativeValue(observableVtblHandle)
        }
        closed = true
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
            case None => Result<Unit>.Err(stockBoundsError())
        }
    }

    public func Clear(): Result<Unit> {
        entries.clear()
        Result<Unit>.Ok(())
    }

    public func MapChanged(vhnd: InParam<MapChangedEventHandler<Int32, HString>>): Result<EventRegistrationToken> {
        let _ = vhnd
        if (throwWindowsOnMapChanged) {
            throw WindowsException(E_POINTER)
        }
        if (failMapChanged) {
            return Result<EventRegistrationToken>.Err(WinError.fromHRESULT(E_FAIL))
        }
        var token = EventRegistrationToken()
        token.Value = 11i64
        Result<EventRegistrationToken>.Ok(token)
    }

    public func RemoveMapChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
        if (throwPlainOnRemoveMapChanged) {
            throw Exception("RemoveMapChanged failure")
        }
        Result<Unit>.Ok(())
    }
}

func createObservableInt32HStringMapForwardingTest(entries: ArrayList<(Int32, HString)>): IObservableMap<Int32, HString> {
    let impl = ObservableInt32HStringMapForwardingTestImpl(entries)
    let schemas = [
        IIterable<IKeyValuePair<Int32, HString>>.descriptorSchema(),
        IMap<Int32, HString>.descriptorSchema(),
        IObservableMap<Int32, HString>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.mapVtblPtr(), impl.observableVtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let map = object.toInterface(IObservableMap<Int32, HString>.descriptor())
    object.close()
    map
}

@Test
func testObservableMapForwardsInheritedMapOperations() {
    let one = HString("one")
    let two = HString("two")
    let replacement = HString("two-updated")
    let three = HString("three")
    let source = ArrayList<(Int32, HString)>([(1i32, one), (2i32, two)])
    let map = createObservableInt32HStringMapForwardingTest(source)

    try {
        @Expect(unsafe { map.HasKey(1i32) }, true)
        let firstValue = unsafe { map.Lookup(1i32) }
        try {
            @Expect(firstValue.get(), "one")
        } finally {
            firstValue.close()
        }

        @Expect(unsafe { map.Insert(2i32, replacement) }, true)
        let replacedValue = unsafe { map.Lookup(2i32) }
        try {
            @Expect(replacedValue.get(), "two-updated")
        } finally {
            replacedValue.close()
        }

        @Expect(unsafe { map.Insert(3i32, three) }, false)
        @Expect(unsafe { map.Size() }, 3u32)
        let view = unsafe { map.GetView() }
        try {
            @Expect(unsafe { view.HasKey(3i32) }, true)
        } finally {
            view.close()
        }

        unsafe { map.Remove(1i32) }
        @Expect(unsafe { map.HasKey(1i32) }, false)
        unsafe { map.Clear() }
        @Expect(unsafe { map.Size() }, 0u32)
    } finally {
        map.close()
        one.close()
        two.close()
        replacement.close()
        three.close()
    }
}

@Test
func testObservableMapEventThunksClearTokenAndTranslateExceptions() {
    let impl = ObservableInt32HStringMapForwardingTestImpl(ArrayList<(Int32, HString)>([]))
    let schemas = [
        IIterable<IKeyValuePair<Int32, HString>>.descriptorSchema(),
        IMap<Int32, HString>.descriptorSchema(),
        IObservableMap<Int32, HString>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.mapVtblPtr(), impl.observableVtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let map = object.toInterface(IObservableMap<Int32, HString>.descriptor())
    object.close()

    try {
        let vtbl = unsafe { map.vtbl() }

        impl.failMapChanged = true
        var failToken = EventRegistrationTokenAbi()
        failToken.Value = 123i64
        let failHr = unsafe {
            vtbl.MapChanged(map.asRaw(), CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout failToken))
        }
        @Expect(failHr, E_FAIL.value)
        @Expect(failToken.Value, 0i64)
        impl.failMapChanged = false

        impl.throwWindowsOnMapChanged = true
        var throwToken = EventRegistrationTokenAbi()
        throwToken.Value = 456i64
        let throwHr = unsafe {
            vtbl.MapChanged(map.asRaw(), CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout throwToken))
        }
        @Expect(throwHr, E_POINTER.value)
        @Expect(throwToken.Value, 0i64)
        impl.throwWindowsOnMapChanged = false

        impl.throwPlainOnRemoveMapChanged = true
        var token = EventRegistrationTokenAbi()
        token.Value = 11i64
        @Expect(unsafe { vtbl.RemoveMapChanged(map.asRaw(), token) }, E_FAIL.value)
        impl.throwPlainOnRemoveMapChanged = false
    } finally {
        map.close()
    }
}
