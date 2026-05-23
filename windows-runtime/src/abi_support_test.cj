package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{
    E_POINTER,
    Result,
    RuntimeType,
    WinError,
    WindowsException,
    WinrtGenericType,
    createComObjectFromSchemas
}

// Shared, generic test harness for the WinRT IVector<T> / IVectorView<T> / IMap<K,V>
// direct-ABI tests. The per-element marshaling categories that have distinct
// ownership semantics (HSTRING, interface pointers, copy structs) keep their own
// Impls; this harness covers the plain value-semantics primitives where store/get
// is a trivial copy.

// Reads `count` trivially-copyable `T` elements out of the ABI buffer. Used by
// ReplaceAll for primitive element types whose ABI representation is `T` itself.
func readDirectValueBuffer<T>(buffer: CPointer<Unit>, count: UInt32): ArrayList<T> where T <: CType {
    let result = ArrayList<T>()
    let typed = CPointer<T>(buffer)
    var offset = 0
    while (offset < Int64(count)) {
        result.add(unsafe { (typed + offset).read() })
        offset += 1
    }
    result
}

// Optional fault-injection hooks so a single Impl can also exercise the
// exception-translation path of the generated value-ABI thunks.
public class GenericVectorAbiTestFaults {
    public var throwWindowsOnIndexOf: Bool = false
    public var throwPlainOnSetAt: Bool = false
    public var throwPlainOnInsertAt: Bool = false
    public var throwPlainOnAppend: Bool = false

    public init() {}
}

public class GenericVectorAbiTestImpl<T> <: IVector_Impl<T> & Resource
        where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let equals: (T, T) -> Bool
    private let readBuffer: (CPointer<Unit>, UInt32) -> ArrayList<T>
    public let faults: GenericVectorAbiTestFaults
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(
        items: ArrayList<T>,
        vtblFactory: () -> IVectorVtbl,
        equals: (T, T) -> Bool,
        readBuffer: (CPointer<Unit>, UInt32) -> ArrayList<T>,
        faults: GenericVectorAbiTestFaults
    ) {
        this.items = items
        this.equals = equals
        this.readBuffer = readBuffer
        this.faults = faults
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(vtblFactory())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<GenericVectorAbiTestImpl<T>, T>())
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

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(toIterator<T>(items))
    }

    public func GetAt(index: UInt32): Result<T> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    // GetView is not exercised by the direct-ABI tests for plain value element
    // types; returning the stock bounds error keeps the Impl fully generic
    // without depending on the stricter HandleWinrtType bound that the generic
    // toVectorView<T> requires.
    public func GetView(): Result<IVectorView<T>> {
        Result<IVectorView<T>>.Err(stockBoundsError())
    }

    public func IndexOf(value: T, indexSlot: CPointer<UInt32>): Result<Bool> {
        if (faults.throwWindowsOnIndexOf) {
            throw WindowsException(E_POINTER)
        }
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (this.equals(candidate, value)) {
                        if (indexSlot.isNotNull()) {
                            unsafe { indexSlot.write(UInt32(offset)) }
                        }
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        if (indexSlot.isNotNull()) {
            unsafe { indexSlot.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func SetAt(index: UInt32, value: T): Result<Unit> {
        if (faults.throwPlainOnSetAt) {
            throw Exception("SetAt failure")
        }
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items[resolved] = value
        Result<Unit>.Ok(())
    }

    public func InsertAt(index: UInt32, value: T): Result<Unit> {
        if (faults.throwPlainOnInsertAt) {
            throw Exception("InsertAt failure")
        }
        let resolved = Int64(index)
        if (resolved < 0 || resolved > items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items.add(value, at: resolved)
        Result<Unit>.Ok(())
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items.remove(at: resolved)
        Result<Unit>.Ok(())
    }

    public func Append(value: T): Result<Unit> {
        if (faults.throwPlainOnAppend) {
            throw Exception("Append failure")
        }
        items.add(value)
        Result<Unit>.Ok(())
    }

    public func RemoveAtEnd(): Result<Unit> {
        if (items.size == 0) {
            return Result<Unit>.Err(stockBoundsError())
        }
        items.remove(at: items.size - 1)
        Result<Unit>.Ok(())
    }

    public func Clear(): Result<Unit> {
        items.clear()
        Result<Unit>.Ok(())
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<T>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        items.clear()
        let decoded = (this.readBuffer)(itemsBuffer, itemsSize)
        for (value in decoded) {
            items.add(value)
        }
        Result<Unit>.Ok(())
    }
}

public class GenericVectorViewAbiTestImpl<T> <: IVectorView_Impl<T> & Resource
        where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let equals: (T, T) -> Bool
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<T>, vtblFactory: () -> IVectorViewVtbl, equals: (T, T) -> Bool) {
        this.items = items
        this.equals = equals
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(vtblFactory())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<GenericVectorViewAbiTestImpl<T>, T>())
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

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(toIterator<T>(items))
    }

    public func GetAt(index: UInt32): Result<T> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
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
                    if (this.equals(candidate, value)) {
                        if (indexSlot.isNotNull()) {
                            unsafe { indexSlot.write(UInt32(offset)) }
                        }
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        if (indexSlot.isNotNull()) {
            unsafe { indexSlot.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<T>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

// Wraps the COM object so tests can assert inner-Impl lifecycle (innerClosed).
public class GenericVectorAbiTestFixture<T> <: Resource where T <: RuntimeType & WinrtGenericType<T> {
    public let vector: IVector<T>
    public let faults: GenericVectorAbiTestFaults
    private let impl: GenericVectorAbiTestImpl<T>
    private var closed: Bool = false

    public init(impl: GenericVectorAbiTestImpl<T>) {
        this.impl = impl
        this.faults = impl.faults
        let schemas = [IIterable<T>.descriptorSchema(), IVector<T>.descriptorSchema()]
        let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
        let object = createComObjectFromSchemas(impl, schemas, vtbls)
        vector = object.toInterface(IVector<T>.descriptor())
        object.close()
    }

    public func innerClosed(): Bool {
        impl.isClosed()
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (!closed) {
            vector.close()
            closed = true
        }
    }
}

// Builds a vector fixture. `specializedVtbl` selects the per-type specialized
// thunk (e.g. IVectorVtbl.newInt16); pass the generic `IVectorVtbl.new<Impl,T>`
// path to exercise the generic builder specialization.
func makeGenericVectorFixture<T>(
    items: ArrayList<T>,
    vtblFactory: () -> IVectorVtbl,
    equals: (T, T) -> Bool,
    readBuffer: (CPointer<Unit>, UInt32) -> ArrayList<T>
): GenericVectorAbiTestFixture<T> where T <: RuntimeType & WinrtGenericType<T> {
    let impl = GenericVectorAbiTestImpl<T>(items, vtblFactory, equals, readBuffer, GenericVectorAbiTestFaults())
    GenericVectorAbiTestFixture<T>(impl)
}

func makeGenericVectorView<T>(
    items: ArrayList<T>,
    vtblFactory: () -> IVectorViewVtbl,
    equals: (T, T) -> Bool
): IVectorView<T> where T <: RuntimeType & WinrtGenericType<T> {
    let impl = GenericVectorViewAbiTestImpl<T>(items, vtblFactory, equals)
    let schemas = [IIterable<T>.descriptorSchema(), IVectorView<T>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IVectorView<T>.descriptor())
    object.close()
    result
}

// ============================ Map harness ============================

// Generic IMap<K,V> harness for the plain value-semantics key/value combos
// (trivially-copyable K and V). Maps whose value carries ownership (HSTRING,
// interface, vector-view) keep their dedicated Impls.
public class GenericMapAbiTestImpl<K, V> <: IMap_Impl<K, V> & Resource
        where K <: RuntimeType & WinrtGenericType<K> & Equatable<K>, V <: RuntimeType & WinrtGenericType<V> {
    private let entries: ArrayList<(K, V)>
    private let vtblHandle: CPointer<IMapVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(K, V)>, vtblFactory: () -> IMapVtbl) {
        this.entries = entries
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapVtbl>(vtblFactory())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<GenericMapAbiTestImpl<K, V>, IKeyValuePair<K, V>>())
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

    private func findIndex(key: K): ?Int64 {
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

    public func First(): Result<IIterator<IKeyValuePair<K, V>>> {
        Result<IIterator<IKeyValuePair<K, V>>>.Ok(
            createStockIteratorFromOwnedList<IKeyValuePair<K, V>>(materializePairViews<K, V>(entries))
        )
    }

    public func Lookup(key: K): Result<V> {
        match (findIndex(key)) {
            case Some(offset) =>
                match (entries.get(offset)) {
                    case Some((_, value)) => Result<V>.Ok(value)
                    case None => Result<V>.Err(stockBoundsError())
                }
            case None => Result<V>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: K): Result<Bool> {
        match (findIndex(key)) {
            case Some(_) => Result<Bool>.Ok(true)
            case None => Result<Bool>.Ok(false)
        }
    }

    // GetView is not exercised by the direct-ABI map tests; returning the stock
    // bounds error keeps the Impl generic across value-semantics key types
    // without requiring the stricter HandleWinrtType bound that the generic
    // toMapView<K, V> imposes (value-type keys like Int32 are not handle types).
    public func GetView(): Result<IMapView<K, V>> {
        Result<IMapView<K, V>>.Err(stockBoundsError())
    }

    public func Insert(key: K, value: V): Result<Bool> {
        match (findIndex(key)) {
            case Some(offset) =>
                entries[offset] = (key, value)
                Result<Bool>.Ok(true)
            case None =>
                entries.add((key, value))
                Result<Bool>.Ok(false)
        }
    }

    public func Remove(key: K): Result<Unit> {
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

func makeGenericMap<K, V>(
    entries: ArrayList<(K, V)>,
    vtblFactory: () -> IMapVtbl
): IMap<K, V> where K <: RuntimeType & WinrtGenericType<K> & Equatable<K>, V <: RuntimeType & WinrtGenericType<V> {
    let impl = GenericMapAbiTestImpl<K, V>(entries, vtblFactory)
    let schemas = [IIterable<IKeyValuePair<K, V>>.descriptorSchema(), IMap<K, V>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    let result = object.toInterface(IMap<K, V>.descriptor())
    object.close()
    result
}
