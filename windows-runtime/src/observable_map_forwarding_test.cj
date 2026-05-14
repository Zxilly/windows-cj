package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{HString, InParam, Result, createComObjectFromSchemas}

class ObservableInt32HStringMapForwardingTestImpl <: IObservableMap_Impl<Int32, HString> {
    private let entries: ArrayList<(Int32, HString)>
    private let observableVtblHandle: CPointerHandle<IObservableMapVtbl>
    private let mapVtblHandle: CPointerHandle<IMapVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, HString)>) {
        this.entries = entries
        this.observableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IObservableMapVtbl>(
                    1,
                    { _ => IObservableMapVtbl.new<ObservableInt32HStringMapForwardingTestImpl, Int32, HString>() }
                )
            )
        }
        this.mapVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IMapVtbl>(1, { _ => IMapVtbl.newInt32HString<ObservableInt32HStringMapForwardingTestImpl>() })
            )
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<ObservableInt32HStringMapForwardingTestImpl, IKeyValuePair<Int32, HString>>() })
            )
        }
    }

    public func observableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(observableVtblHandle.pointer)
    }

    public func mapVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(mapVtblHandle.pointer)
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
            releaseArrayRawData(mapVtblHandle)
            releaseArrayRawData(observableVtblHandle)
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
        var token = EventRegistrationToken()
        token.Value = 11i64
        Result<EventRegistrationToken>.Ok(token)
    }

    public func RemoveMapChanged(token: EventRegistrationToken): Result<Unit> {
        let _ = token
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
    object.toInterface(IObservableMap<Int32, HString>.descriptor())
}

@Test
func testObservableMapForwardsInheritedMapOperations() {
    let one = HString("one")
    let two = HString("two")
    let replacement = HString("two-updated")
    let three = HString("three")
    let source = ArrayList<(Int32, HString)>([(1i32, one), (2i32, two)])
    let map = createObservableInt32HStringMapForwardingTest(source)

    @Expect(unsafe { map.HasKey(1i32) }, true)
    let firstValue = unsafe { map.Lookup(1i32) }
    @Expect(firstValue.get(), "one")
    firstValue.close()

    @Expect(unsafe { map.Insert(2i32, replacement) }, true)
    let replacedValue = unsafe { map.Lookup(2i32) }
    @Expect(replacedValue.get(), "two-updated")
    replacedValue.close()

    @Expect(unsafe { map.Insert(3i32, three) }, false)
    @Expect(unsafe { map.Size() }, 3u32)
    let view = unsafe { map.GetView() }
    @Expect(unsafe { view.HasKey(3i32) }, true)
    view.close()

    unsafe { map.Remove(1i32) }
    @Expect(unsafe { map.HasKey(1i32) }, false)
    unsafe { map.Clear() }
    @Expect(unsafe { map.Size() }, 0u32)

    map.close()
    one.close()
    two.close()
    replacement.close()
    three.close()
}
