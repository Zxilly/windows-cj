package windows_interface

import std.collection.{HashMap, ArrayList}
import std.sync.Mutex

var scopedInterfaceRegistryMutex = Mutex()
var scopedInterfaceRegistry = HashMap<UIntNative, Object>()
var scopedInterfaceTargetIdentityMutex = Mutex()
var scopedInterfaceTargetIdentities = ArrayList<ScopedTargetIdentityEntry>()
var nextScopedInterfaceTargetIdentity: UIntNative = UIntNative(1)

class ScopedTargetIdentityEntry {
    public let key: UIntNative
    public let target: Object
    public var refCount: Int64

    public init(key: UIntNative, target: Object) {
        this.key = key
        this.target = target
        this.refCount = 1
    }
}

func scopedInterfaceRegistryInsert(raw: CPointer<Unit>, target: Object): Unit {
    synchronized(scopedInterfaceRegistryMutex) {
        scopedInterfaceRegistry.add(raw.toUIntNative(), target)
    }
}

func scopedInterfaceRegistryRemove(raw: CPointer<Unit>): Unit {
    synchronized(scopedInterfaceRegistryMutex) {
        scopedInterfaceRegistry.remove(raw.toUIntNative())
    }
}

public func lookupScopedInterfaceTarget<T>(raw: CPointer<Unit>): Option<T> {
    if (raw.isNull()) {
        return None
    }
    let key = raw.toUIntNative()
    let entry = synchronized(scopedInterfaceRegistryMutex) {
        scopedInterfaceRegistry.get(key)
    }
    match (entry) {
        case Some(value) =>
            match (value) {
                case resolved: T => Some(resolved)
                case _ => None
            }
        case None => None
    }
}

func acquireScopedTargetIdentity(target: Object): UIntNative {
    synchronized(scopedInterfaceTargetIdentityMutex) {
        var index: Int64 = 0
        while (index < scopedInterfaceTargetIdentities.size) {
            let entry = scopedInterfaceTargetIdentities[index]
            if (refEq(entry.target, target)) {
                entry.refCount += 1
                return entry.key
            }
            index += 1
        }

        let key = nextScopedInterfaceTargetIdentity
        nextScopedInterfaceTargetIdentity += UIntNative(1)
        scopedInterfaceTargetIdentities.add(ScopedTargetIdentityEntry(key, target))
        key
    }
}

func releaseScopedTargetIdentity(key: UIntNative): Unit {
    synchronized(scopedInterfaceTargetIdentityMutex) {
        var index: Int64 = 0
        while (index < scopedInterfaceTargetIdentities.size) {
            let entry = scopedInterfaceTargetIdentities[index]
            if (entry.key == key) {
                entry.refCount -= 1
                if (entry.refCount <= 0) {
                    scopedInterfaceTargetIdentities.remove(at: index)
                }
                return
            }
            index += 1
        }
    }
}

public struct ScopedHeap {
    public var vtable: UIntNative = UIntNative(0)
    public var this_: UIntNative = UIntNative(0)

    public init() {}

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            return
        }
        unsafe {
            let vtablePtr = CPointer<CPointer<Unit>>(raw).read()
            vtable = vtablePtr.toUIntNative()
            this_ = raw.toUIntNative()
        }
    }

    public mut prop this_ptr: UIntNative {
        get() {
            this_
        }
        set(value) {
            this_ = value
        }
    }
}

class ScopedInterfaceState<T> {
    public let descriptor: AbiReferenceDescriptorBase<T>
    public var raw: CPointer<Unit> = CPointer<Unit>()
    public var heap: ScopedHeap = ScopedHeap()
    public var closed: Bool = false
    public let releaseOnClose: Bool
    public let onClose: Option<() -> Unit>

    public init(
        raw: CPointer<Unit>,
        descriptor: AbiReferenceDescriptorBase<T>,
        addRef!: Bool = false,
        releaseOnClose!: Bool = true,
        heapThisPtr!: Option<UIntNative> = None,
        onClose!: Option<() -> Unit> = None
    ) {
        this.descriptor = descriptor
        this.releaseOnClose = releaseOnClose
        this.onClose = onClose
        if (!raw.isNull()) {
            if (addRef) {
                descriptor.addRefPointer(raw)
            }
            this.raw = raw
            this.heap = ScopedHeap(raw)
            match (heapThisPtr) {
                case Some(value) =>
                    this.heap.this_ptr = value
                case None => ()
            }
        }
    }
}

public struct ScopedInterface<T> <: Resource {
    private let state: ScopedInterfaceState<T>

    public init(
        raw: CPointer<Unit>,
        descriptor: AbiReferenceDescriptorBase<T>,
        addRef!: Bool = false,
        releaseOnClose!: Bool = true,
        heapThisPtr!: Option<UIntNative> = None,
        onClose!: Option<() -> Unit> = None
    ) {
        state = ScopedInterfaceState<T>(
            raw,
            descriptor,
            addRef: addRef,
            releaseOnClose: releaseOnClose,
            heapThisPtr: heapThisPtr,
            onClose: onClose
        )
    }

    public static func new<U>(
        value: U,
        descriptor: AbiReferenceDescriptorBase<U>
    ): ScopedInterface<U> where U <: ComInterface {
        ScopedInterface<U>(value.asRaw(), descriptor, addRef: true)
    }

    public func isClosed(): Bool {
        state.closed || state.raw.isNull()
    }

    public func heap(): ScopedHeap {
        state.heap
    }

    public func asRaw(): CPointer<Unit> {
        if (isClosed()) {
            return CPointer<Unit>()
        }
        state.raw
    }

    public func value(): T {
        let raw = asRaw()
        if (raw.isNull()) {
            throw IllegalStateException("ScopedInterface is closed")
        }
        state.descriptor.wrapBorrowed(raw)
    }

    public func close(): Unit {
        if (state.closed) {
            return
        }
        if (state.releaseOnClose && !state.raw.isNull()) {
            state.descriptor.releasePointer(state.raw)
        }
        state.raw = CPointer<Unit>()
        state.heap = ScopedHeap()
        state.closed = true
        match (state.onClose) {
            case Some(callback) => callback()
            case None => ()
        }
    }
}

public unsafe func createScopedInterface<T>(
    descriptor: AbiReferenceDescriptorBase<T>,
    raw: CPointer<Unit>,
    addRef!: Bool = false
): ScopedInterface<T> {
    ScopedInterface<T>(raw, descriptor, addRef: addRef)
}

public unsafe func createScopedInterfaceFromTarget<T, U>(
    descriptor: AbiReferenceDescriptorBase<T>,
    target: U,
    vtablePtr: CPointer<Unit>
): ScopedInterface<T> where U <: Object {
    let slots = Array<CPointer<Unit>>(1, { _ => vtablePtr })
    let handle = acquireArrayRawData(slots)
    let raw = CPointer<Unit>(handle.pointer)
    let targetIdentity = acquireScopedTargetIdentity(target)
    scopedInterfaceRegistryInsert(raw, target)
    ScopedInterface<T>(
        raw,
        descriptor,
        releaseOnClose: false,
        heapThisPtr: Some(targetIdentity),
        onClose: Some({ =>
            scopedInterfaceRegistryRemove(raw)
            releaseScopedTargetIdentity(targetIdentity)
            unsafe { releaseArrayRawData(handle) }
        })
    )
}
