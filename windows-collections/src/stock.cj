package windows_collections

import std.collection.*
import std.sync.AtomicInt64
import windows_core.{
    ComInterface,
    HandleWinrtType,
    HRESULT,
    Result,
    RuntimeType,
    WinrtGenericType,
    WinError,
    createComObjectFromSchemas,
    winrtStoreGenericOut,
    winrtStoreGenericOutAt
}
import windows_interface.{InterfaceDescriptor, InterfaceDescriptorSchema}

let STOCK_E_BOUNDS = HRESULT(-2147483637i32)

func stockBoundsError(): WinError {
    WinError(STOCK_E_BOUNDS)
}

func snapshotList<T>(source: Iterable<T>): ArrayList<T> {
    collectArrayList<T>(source)
}

func createStockInterface<Inner, I>(
    inner: Inner,
    schema: InterfaceDescriptorSchema,
    descriptor: InterfaceDescriptor<I>,
    vtblPtr: CPointer<Unit>
): I where I <: ComInterface {
    let schemas = Array<InterfaceDescriptorSchema>(1, { _ => schema })
    let object = createComObjectFromSchemas(inner, schemas, vtblPtr)
    object.toInterface(descriptor)
}

// Multi-schema variant: register N schemas and N vtbls (one per schema, in matching order).
// Each schema's resolved slotIndex maps to vtbls[index] (slot 1 -> vtbls[0], slot 2 -> vtbls[1]).
// Used for stock objects that expose required-ancestor interfaces (e.g. IVectorView<T> expects
// QueryInterface(IID_IIterable<T>) to return an independent IIterable vtbl).
func createStockInterfaceMulti<Inner, I>(
    inner: Inner,
    schemas: Array<InterfaceDescriptorSchema>,
    descriptor: InterfaceDescriptor<I>,
    vtblPtrs: Array<CPointer<Unit>>
): I where I <: ComInterface {
    let object = createComObjectFromSchemas(inner, schemas, vtblPtrs)
    object.toInterface(descriptor)
}

func createStockIterator<T>(items: ArrayList<T>): IIterator<T> where T <: RuntimeType & WinrtGenericType<T> {
    let impl = StockIteratorImpl<T>(items)
    createStockInterface<StockIteratorImpl<T>, IIterator<T>>(
        impl,
        IIterator<T>.descriptorSchema(),
        IIterator<T>.descriptor(),
        impl.vtblPtr()
    )
}

func createStockKeyValuePair<K, V>(key: K, value: V): IKeyValuePair<K, V>
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    let impl = StockKeyValuePairImpl<K, V>(key, value)
    createStockInterface<StockKeyValuePairImpl<K, V>, IKeyValuePair<K, V>>(
        impl,
        IKeyValuePair<K, V>.descriptorSchema(),
        IKeyValuePair<K, V>.descriptor(),
        impl.vtblPtr()
    )
}

func materializePairViews<K, V>(entries: ArrayList<(K, V)>): ArrayList<IKeyValuePair<K, V>>
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    let result = ArrayList<IKeyValuePair<K, V>>()
    for ((key, value) in entries) {
        result.add(createStockKeyValuePair<K, V>(key, value))
    }
    result
}

func writeIndexSlot(indexSlot: CPointer<UInt32>, value: UInt32): Unit {
    if (indexSlot.isNotNull()) {
        unsafe { indexSlot.write(value) }
    }
}

/// Write up to `min(itemsSize, source.size - startIndex)` elements from `source`
/// starting at `source[startIndex]` into the ABI buffer `items`.
/// Returns the number of elements actually written. Matches the WinRT
/// IIterator::GetMany / IVectorView::GetMany batch semantics.
func writeGenericManyRange<T>(
    itemsSize: UInt32,
    items: CPointer<Unit>,
    source: ArrayList<T>,
    startIndex: Int64
): Result<UInt32>
where T <: RuntimeType & WinrtGenericType<T> {
    if (itemsSize == 0u32 || items.isNull()) {
        return Result<UInt32>.Ok(0u32)
    }
    if (startIndex < 0 || startIndex >= source.size) {
        return Result<UInt32>.Ok(0u32)
    }
    let remaining = source.size - startIndex
    let capacity = Int64(itemsSize)
    let actual = if (remaining < capacity) { remaining } else { capacity }
    var written = 0
    while (written < actual) {
        match (source.get(startIndex + written)) {
            case Some(value) =>
                let hr = HRESULT(winrtStoreGenericOutAt<T>(items, written, value))
                if (hr.failed()) {
                    return Result<UInt32>.Err(WinError(hr))
                }
            case None =>
                break
        }
        written += 1
    }
    Result<UInt32>.Ok(UInt32(written))
}

public class StockIteratorImpl<T> <: IIterator_Impl<T> where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let vtblHandle: CPointerHandle<IIteratorVtbl>
    private let index = AtomicInt64(0)

    public init(items: ArrayList<T>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IIteratorVtbl>(1, { _ => IIteratorVtbl.new<StockIteratorImpl<T>, T>() }))
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func Current(): Result<T> {
        let current = index.load()
        if (current < 0 || current >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(current)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func HasCurrent(): Result<Bool> {
        let current = index.load()
        Result<Bool>.Ok(current >= 0 && current < items.size)
    }

    public func MoveNext(): Result<Bool> {
        let current = index.load()
        if (current < items.size) {
            index.fetchAdd(1)
        }
        Result<Bool>.Ok(current + 1 < items.size)
    }

    public func GetMany(itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        // IIterator::GetMany contract: copy up to `itemsSize` elements starting
        // from the current cursor, advance by the number written, and return that count.
        let current = index.load()
        match (writeGenericManyRange<T>(itemsSize, items, this.items, current)) {
            case Result<UInt32>.Ok(count) =>
                index.fetchAdd(Int64(count))
                Result<UInt32>.Ok(count)
            case Result<UInt32>.Err(error) =>
                Result<UInt32>.Err(error)
        }
    }
}

public class StockIterableImpl<T> <: IIterable_Impl<T> where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let vtblHandle: CPointerHandle<IIterableVtbl>

    public init(items: ArrayList<T>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<StockIterableImpl<T>, T>() }))
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(createStockIterator<T>(items))
    }
}

public class StockVectorViewImpl<T> <: IVectorView_Impl<T>
where T <: RuntimeType & HandleWinrtType<T> & Equatable<T> {
    private let items: ArrayList<T>
    private let vtblHandle: CPointerHandle<IVectorViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>

    public init(items: ArrayList<T>) {
        this.items = items
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => IVectorViewVtbl.new<StockVectorViewImpl<T>, T>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<StockVectorViewImpl<T>, T>() }))
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle.pointer)
    }

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(createStockIterator<T>(items))
    }

    public func GetAt(index: UInt32): Result<T> {
        let resolvedIndex = Int64(index)
        if (resolvedIndex < 0 || resolvedIndex >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(resolvedIndex)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: T, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (candidate == value) {
                        writeIndexSlot(indexSlot, UInt32(offset))
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        // WinRT IVectorView::IndexOf contract: when value is not present,
        // out-param `index` MUST be 0.
        writeIndexSlot(indexSlot, 0u32)
        Result<Bool>.Ok(false)
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        // IVectorView::GetMany: copy up to `itemsSize` elements starting at
        // `startIndex`. The view does not have a cursor so nothing advances.
        writeGenericManyRange<T>(itemsSize, itemsBuffer, this.items, Int64(startIndex))
    }
}

public class StockKeyValuePairImpl<K, V> <: IKeyValuePair_Impl<K, V>
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    private let key_: K
    private let value_: V
    private let vtblHandle: CPointerHandle<IKeyValuePairVtbl>

    public init(key: K, value: V) {
        this.key_ = key
        this.value_ = value
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IKeyValuePairVtbl>(1, { _ => IKeyValuePairVtbl.new<StockKeyValuePairImpl<K, V>, K, V>() }))
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func Key(): Result<K> {
        Result<K>.Ok(key_)
    }

    public func Value(): Result<V> {
        Result<V>.Ok(value_)
    }
}

public class StockMapViewImpl<K, V> <: IMapView_Impl<K, V>
where K <: RuntimeType & HandleWinrtType<K> & Equatable<K>, V <: RuntimeType & WinrtGenericType<V> {
    private let entries: ArrayList<(K, V)>
    private let pairViews: ArrayList<IKeyValuePair<K, V>>
    private let vtblHandle: CPointerHandle<IMapViewVtbl>
    private let iterableVtblHandle: CPointerHandle<IIterableVtbl>

    public init(entries: ArrayList<(K, V)>) {
        this.entries = entries
        this.pairViews = materializePairViews<K, V>(entries)
        this.vtblHandle = unsafe {
            acquireArrayRawData(Array<IMapViewVtbl>(1, { _ => IMapViewVtbl.new<StockMapViewImpl<K, V>, K, V>() }))
        }
        this.iterableVtblHandle = unsafe {
            acquireArrayRawData(
                Array<IIterableVtbl>(1, { _ => IIterableVtbl.new<StockMapViewImpl<K, V>, IKeyValuePair<K, V>>() }))
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle.pointer)
    }

    public func First(): Result<IIterator<IKeyValuePair<K, V>>> {
        Result<IIterator<IKeyValuePair<K, V>>>.Ok(
            createStockIterator<IKeyValuePair<K, V>>(pairViews)
        )
    }

    public func Lookup(key: K): Result<V> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<V>.Ok(candidateValue)
            }
        }
        Result<V>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: K): Result<Bool> {
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

public func toIterator<T>(source: Iterable<T>): IIterator<T> where T <: RuntimeType & WinrtGenericType<T> {
    let items = snapshotList<T>(source)
    createStockIterator<T>(items)
}

public func toIterable<T>(source: Iterable<T>): IIterable<T> where T <: RuntimeType & WinrtGenericType<T> {
    let items = snapshotList<T>(source)
    let impl = StockIterableImpl<T>(items)
    createStockInterface<StockIterableImpl<T>, IIterable<T>>(
        impl,
        IIterable<T>.descriptorSchema(),
        IIterable<T>.descriptor(),
        impl.vtblPtr()
    )
}

public func toVectorView<T>(source: Iterable<T>): IVectorView<T>
where T <: RuntimeType & HandleWinrtType<T> & Equatable<T> {
    let items = snapshotList<T>(source)
    let impl = StockVectorViewImpl<T>(items)
    // Register the IIterable<T> required-ancestor surface alongside IVectorView<T> so QI for
    // IID_IIterable<T> returns its own independent vtbl (slot 1) rather than the IVectorView vtbl
    // (slot 2). Each schema's slot index matches its position in the schemas array.
    let schemas = [IIterable<T>.descriptorSchema(), IVectorView<T>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockVectorViewImpl<T>, IVectorView<T>>(
        impl,
        schemas,
        IVectorView<T>.descriptor(),
        vtbls
    )
}

public func toKeyValuePair<K, V>(key: K, value: V): IKeyValuePair<K, V>
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    createStockKeyValuePair<K, V>(key, value)
}

public func toMapView<K, V>(source: Iterable<(K, V)>): IMapView<K, V>
where K <: RuntimeType & HandleWinrtType<K> & Equatable<K>, V <: RuntimeType & WinrtGenericType<V> {
    let entries = snapshotList<(K, V)>(source)
    let impl = StockMapViewImpl<K, V>(entries)
    // Register IIterable<IKeyValuePair<K, V>> as an independent slot so QI to the iterable
    // ancestor returns a distinct vtbl from the IMapView vtbl.
    let schemas = [
        IIterable<IKeyValuePair<K, V>>.descriptorSchema(),
        IMapView<K, V>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockMapViewImpl<K, V>, IMapView<K, V>>(
        impl,
        schemas,
        IMapView<K, V>.descriptor(),
        vtbls
    )
}
