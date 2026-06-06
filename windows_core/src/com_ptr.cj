package windows_core

func interfaceHandleAddRefRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.AddRef(raw)
    }
}

func interfaceHandleReleaseRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.Release(raw)
    }
}

public func releaseFailedComOutSlot(slot: CPointer<CPointer<Unit>>): Unit {
    if (slot.isNull()) {
        return
    }
    let raw = unsafe { slot.read() }
    if (raw.isNotNull()) {
        unsafe { slot.write(CPointer<Unit>()) }
        interfaceHandleReleaseRaw(raw)
    }
}

// InterfaceHandle<T> keeps a live COM interface reference as a Resource.
public class InterfaceHandle<T> <: Resource {
    private let descriptor: InterfaceDescriptor<T>
    private var raw: CPointer<Unit>
    private var closed: Bool = false

    public init(raw: CPointer<Unit>, descriptor: InterfaceDescriptor<T>, addRef!: Bool = false) {
        this.raw = raw
        this.descriptor = descriptor
        if (addRef) {
            interfaceHandleAddRefRaw(raw)
        }
    }

    public static func fromAbiTake(raw: CPointer<Unit>, descriptor: InterfaceDescriptor<T>): InterfaceHandle<T> {
        InterfaceHandle<T>(raw, descriptor)
    }

    public static func retainInterface(source: ComInterface, descriptor: InterfaceDescriptor<T>): InterfaceHandle<T> {
        InterfaceHandle<T>(source.asRaw(), descriptor, addRef: true)
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
        descriptor.viewOf(asRaw())
    }

    public func addRef(): UInt32 {
        if (closed) {
            return 0u32
        }
        interfaceHandleAddRefRaw(raw)
    }

    public func retain(): InterfaceHandle<T> {
        if (closed) {
            throw Exception("InterfaceHandle.retain called on a closed handle")
        }
        InterfaceHandle<T>(raw, descriptor, addRef: true)
    }

    public unsafe func query<U>(target: InterfaceDescriptor<U>): Option<InterfaceHandle<U>> where U <: ComInterface {
        match (queryInterfaceRaw(asRaw(), target.iid)) {
            case Some(raw) => Some(InterfaceHandle<U>.fromAbiTake(raw, target))
            case None => Option<InterfaceHandle<U>>.None
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func intoAbi(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        let released = raw
        raw = CPointer<Unit>()
        closed = true
        released
    }

    private func closeHandleForResourceOwner(): UInt32 {
        if (closed) {
            return 0u32
        }
        let rawToRelease = raw
        raw = CPointer<Unit>()
        closed = true
        if (rawToRelease.isNull()) {
            return 0u32
        }
        interfaceHandleReleaseRaw(rawToRelease)
    }

    public func close(): Unit {
        let _ = closeHandleForResourceOwner()
    }
}
