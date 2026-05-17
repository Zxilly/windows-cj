package windows_core

public func coTaskMemAlloc(cb: UIntNative): CPointer<Unit> {
    unsafe { CoTaskMemAlloc(cb) }
}

public func coTaskMemRealloc(pv: CPointer<Unit>, cb: UIntNative): CPointer<Unit> {
    unsafe { CoTaskMemRealloc(pv, cb) }
}

public func coTaskMemFree(pv: CPointer<Unit>): Unit {
    unsafe { CoTaskMemFree(pv) }
}

abstract class AbiArrayStorage<T> {
    public func len(): UInt32
    public func get(index: Int64): T
    public func set(index: Int64, value: T): Unit
    public func toArray(): Array<T>
    public func replaceWith(values: Array<T>): Unit
    public func clear(): Unit
}

class ProjectedAbiArrayStorage<T> <: AbiArrayStorage<T> {
    private var values = Array<T>()

    public init() {}

    public init(values: Array<T>) {
        this.values = cloneProjectedArray(values)
    }

    public func len(): UInt32 {
        UInt32(values.size)
    }

    public func get(index: Int64): T {
        ensureProjectedIndex(index, len())
        cloneProjectedValue(values[index])
    }

    public func set(index: Int64, value: T): Unit {
        ensureProjectedIndex(index, len())
        let cloned = cloneProjectedValue(value)
        closeProjectedElement(values[index])
        values[index] = cloned
    }

    public func toArray(): Array<T> {
        cloneProjectedArray(values)
    }

    public func replaceWith(values: Array<T>): Unit {
        let replacement = cloneProjectedArray(values)
        clear()
        this.values = replacement
    }

    public func clear(): Unit {
        closeProjectedElements(values)
        values = Array<T>()
    }
}

class NativeAbiArrayStorage<T> <: AbiArrayStorage<T> where T <: CType {
    private var data: CPointer<T> = CPointer<T>()
    private var length: UInt32 = 0u32

    public init() {}

    public init(data: CPointer<T>, length: UInt32) {
        this.data = data
        this.length = length
    }

    public static func withLen(length: Int64): NativeAbiArrayStorage<T> {
        if (length < 0) {
            throw IllegalArgumentException("AbiArray length must be non-negative")
        }
        if (length == 0) {
            return NativeAbiArrayStorage<T>()
        }

        let totalBytes = sizeOf<T>() * UIntNative(length)
        let raw = unsafe { CoTaskMemAlloc(totalBytes) }
        if (raw.isNull()) {
            throw WindowsException(E_OUTOFMEMORY)
        }

        let bytes = CPointer<UInt8>(raw)
        var index = 0
        while (index < Int64(totalBytes)) {
            unsafe { (bytes + index).write(0u8) }
            index += 1
        }

        NativeAbiArrayStorage<T>(CPointer<T>(raw), UInt32(length))
    }

    public func len(): UInt32 {
        length
    }

    public func get(index: Int64): T {
        let live = checkedElementPointer(index)
        unsafe { live.read() }
    }

    public func set(index: Int64, value: T): Unit {
        let live = checkedElementPointer(index)
        unsafe { live.write(value) }
    }

    public func toArray(): Array<T> {
        if (length == 0u32) {
            return Array<T>()
        }
        let result = Array<T>(Int64(length), { _ => get(0) })
        var index = 0
        while (index < Int64(length)) {
            result[index] = get(index)
            index += 1
        }
        result
    }

    public func replaceWith(values: Array<T>): Unit {
        clear()
        if (values.size == 0) {
            return
        }

        let replacement = NativeAbiArrayStorage<T>.withLen(values.size)
        var index = 0
        while (index < values.size) {
            replacement.set(index, values[index])
            index += 1
        }

        let (raw, len) = replacement.detach()
        data = raw
        length = len
    }

    public func clear(): Unit {
        if (data.isNotNull()) {
            unsafe { CoTaskMemFree(CPointer<Unit>(data)) }
        }
        data = CPointer<T>()
        length = 0u32
    }

    ~init() {
        if (data.isNotNull()) {
            unsafe { CoTaskMemFree(CPointer<Unit>(data)) }
            data = CPointer<T>()
            length = 0u32
        }
    }

    public func rawOrNull(): CPointer<T> {
        data
    }

    public func detach(): (CPointer<T>, UInt32) {
        let detachedData = data
        let detachedLength = length
        data = CPointer<T>()
        length = 0u32
        (detachedData, detachedLength)
    }

    private func checkedElementPointer(index: Int64): CPointer<T> {
        if (data.isNull()) {
            throw IllegalStateException("AbiArray storage is closed")
        }
        if (index < 0 || index >= Int64(length)) {
            throw IndexOutOfBoundsException("AbiArray index out of bounds")
        }
        unsafe { data + index }
    }
}

func closeProjectedElement<T>(value: T): Unit {
    match (value) {
        case hstring: HString =>
            hstring.close()
        case _ => ()
    }
}

func closeProjectedElements<T>(values: Array<T>): Unit {
    var index = 0
    while (index < values.size) {
        closeProjectedElement(values[index])
        index += 1
    }
}

func cloneProjectedArray<T>(values: Array<T>): Array<T> {
    if (values.size == 0) {
        return Array<T>()
    }
    let cloned = Array<T>(values.size, { index => cloneProjectedValue(values[index]) })
    cloned
}

func ensureProjectedIndex(index: Int64, length: UInt32): Unit {
    if (index < 0 || index >= Int64(length)) {
        throw IndexOutOfBoundsException("AbiArray index out of bounds")
    }
}

// WinRT ABI arrays retain the native CoTaskMem path for CType elements, while
// projected values like HString can be staged in managed storage and lowered
// to native buffers only when required.
public class AbiArray<T> <: Resource {
    var storage: AbiArrayStorage<T> = ProjectedAbiArrayStorage<T>()
    var closed: Bool = false

    public init() {}

    init(storage: AbiArrayStorage<T>) {
        this.storage = storage
    }

    public static func fromSlice(values: Array<T>): AbiArray<T> {
        AbiArray<T>(ProjectedAbiArrayStorage<T>(values))
    }

    public func len(): Int64 {
        Int64(storage.len())
    }

    public func isEmpty(): Bool {
        storage.len() == 0u32
    }

    public func isClosed(): Bool {
        closed
    }

    public func get(index: Int64): T {
        if (closed) {
            throw IllegalStateException("AbiArray storage is closed")
        }
        storage.get(index)
    }

    public func set(index: Int64, value: T): Unit {
        if (closed) {
            throw IllegalStateException("AbiArray storage is closed")
        }
        storage.set(index, value)
    }

    public func toArray(): Array<T> {
        if (closed) {
            return Array<T>()
        }
        storage.toArray()
    }

    public func replaceWith(values: Array<T>): Unit {
        let replacement = ProjectedAbiArrayStorage<T>(values)
        if (!closed) {
            storage.clear()
        }
        storage = replacement
        closed = false
    }

    public func clear(): Unit {
        if (closed) {
            return
        }
        storage.clear()
    }

    public func close(): Unit {
        if (!closed) {
            clear()
            closed = true
        }
    }

    ~init() {
        if (!closed) {
            storage.clear()
            closed = true
        }
    }
}

extend<T> AbiArray<T> where T <: CType {
    public static func withLen(length: Int64): AbiArray<T> {
        AbiArray<T>(NativeAbiArrayStorage<T>.withLen(length))
    }

    public unsafe static func fromRawParts(data: CPointer<T>, length: UInt32): AbiArray<T> {
        AbiArray<T>(NativeAbiArrayStorage<T>(data, length))
    }

    public func asRaw(): CPointer<T> {
        if (isClosed()) {
            return CPointer<T>()
        }
        match (storage) {
            case native: NativeAbiArrayStorage<T> => native.rawOrNull()
            case _ => CPointer<T>()
        }
    }

    public func intoAbi(): (CPointer<T>, UInt32) {
        if (isClosed()) {
            return (CPointer<T>(), 0u32)
        }

        let result = match (storage) {
            case native: NativeAbiArrayStorage<T> =>
                native.detach()
            case projected: ProjectedAbiArrayStorage<T> =>
                let native = NativeAbiArrayStorage<T>.withLen(Int64(projected.len()))
                let values = projected.toArray()
                var index = 0
                while (index < values.size) {
                    native.set(index, values[index])
                    index += 1
                }
                native.detach()
            case _ =>
                (CPointer<T>(), 0u32)
        }

        storage = ProjectedAbiArrayStorage<T>()
        closed = true
        result
    }
}
