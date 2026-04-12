package windows_core

func comPtrAddRefRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.AddRef(raw)
    }
}

func comPtrReleaseRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.Release(raw)
    }
}

// ComPtr<T> is a small owning COM smart pointer over an interface wrapper.
public class ComPtr<T> <: Resource {
    private let descriptor: InterfaceDescriptor<T>
    private var raw: CPointer<Unit>
    private var closed: Bool = false

    public init(raw: CPointer<Unit>, descriptor: InterfaceDescriptor<T>, addRef!: Bool = false) {
        this.raw = raw
        this.descriptor = descriptor
        if (addRef) {
            comPtrAddRefRaw(raw)
        }
    }

    public static func attach(raw: CPointer<Unit>, descriptor: InterfaceDescriptor<T>): ComPtr<T> {
        ComPtr<T>(raw, descriptor)
    }

    public static func fromInterface(source: ComInterface, descriptor: InterfaceDescriptor<T>): ComPtr<T> {
        ComPtr<T>(source.asRaw(), descriptor, addRef: true)
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        raw
    }

    public func hasValue(): Bool {
        !closed && !raw.isNull()
    }

    public func value(): T {
        descriptor.wrapBorrowed(asRaw())
    }

    public func addRef(): UInt32 {
        if (closed) {
            return 0u32
        }
        comPtrAddRefRaw(raw)
    }

    public func clonePtr(): ComPtr<T> {
        if (closed) {
            throw Exception("ComPtr.clonePtr called on a closed ComPtr")
        }
        ComPtr<T>(raw, descriptor, addRef: true)
    }

    public unsafe func query<U>(target: InterfaceDescriptor<U>): Option<ComPtr<U>> where U <: ComInterface {
        match (queryInterfaceRaw(asRaw(), target.iid)) {
            case Some(raw) => Some(ComPtr<U>.attach(raw, target))
            case None => Option<ComPtr<U>>.None
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func detach(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        let detached = raw
        raw = CPointer<Unit>()
        closed = true
        detached
    }

    public func close(): Unit {
        if (!closed) {
            comPtrReleaseRaw(raw)
            raw = CPointer<Unit>()
            closed = true
        }
    }
}
