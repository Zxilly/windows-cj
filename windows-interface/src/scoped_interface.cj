package windows_interface

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex

var interfaceTargetRegistryMutex = Mutex()
var interfaceTargetRegistry = HashMap<UIntNative, Object>()
var interfaceTargetIdentityMutex = Mutex()
var interfaceTargetIdentities = ArrayList<InterfaceTargetIdentityEntry>()
var nextInterfaceTargetIdentity: UIntNative = UIntNative(1)

class InterfaceTargetIdentityEntry {
    public let key: UIntNative
    public let target: Object
    public var refCount: Int64

    public init(key: UIntNative, target: Object) {
        this.key = key
        this.target = target
        this.refCount = 1
    }
}

func interfaceTargetRegistryInsert(raw: CPointer<Unit>, target: Object): Unit {
    synchronized(interfaceTargetRegistryMutex) {
        interfaceTargetRegistry.add(raw.toUIntNative(), target)
    }
}

func interfaceTargetRegistryRemove(raw: CPointer<Unit>): Unit {
    synchronized(interfaceTargetRegistryMutex) {
        interfaceTargetRegistry.remove(raw.toUIntNative())
    }
}

public func lookupInterfaceTarget<T>(raw: CPointer<Unit>): Option<T> {
    if (raw.isNull()) {
        return None
    }
    let key = raw.toUIntNative()
    let entry = synchronized(interfaceTargetRegistryMutex) {
        interfaceTargetRegistry.get(key)
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

func acquireInterfaceTargetIdentity(target: Object): UIntNative {
    synchronized(interfaceTargetIdentityMutex) {
        var index: Int64 = 0
        while (index < interfaceTargetIdentities.size) {
            let entry = interfaceTargetIdentities[index]
            if (refEq(entry.target, target)) {
                entry.refCount += 1
                return entry.key
            }
            index += 1
        }

        let key = nextInterfaceTargetIdentity
        nextInterfaceTargetIdentity += UIntNative(1)
        interfaceTargetIdentities.add(InterfaceTargetIdentityEntry(key, target))
        key
    }
}

func releaseInterfaceTargetIdentity(key: UIntNative): Unit {
    synchronized(interfaceTargetIdentityMutex) {
        var index: Int64 = 0
        while (index < interfaceTargetIdentities.size) {
            let entry = interfaceTargetIdentities[index]
            if (entry.key == key) {
                entry.refCount -= 1
                if (entry.refCount <= 0) {
                    interfaceTargetIdentities.remove(at: index)
                }
                return
            }
            index += 1
        }
    }
}

public struct InterfaceSlotInfo {
    public var vtable: UIntNative = UIntNative(0)
    public var instanceRaw: UIntNative = UIntNative(0)

    public init() {}

    public init(raw: CPointer<Unit>) {
        if (raw.isNull()) {
            return
        }
        unsafe {
            let vtablePtr = CPointer<CPointer<Unit>>(raw).read()
            vtable = vtablePtr.toUIntNative()
            instanceRaw = raw.toUIntNative()
        }
    }

    public mut prop instancePtr: UIntNative {
        get() {
            instanceRaw
        }
        set(value) {
            instanceRaw = value
        }
    }
}

class InterfaceResourceState<T> {
    public let descriptor: AbiReferenceDescriptorBase<T>
    public var raw: CPointer<Unit> = CPointer<Unit>()
    public var slotInfo: InterfaceSlotInfo = InterfaceSlotInfo()
    public var closed: Bool = false
    public let releaseOnClose: Bool
    public let onClose: Option<() -> Unit>

    public init(
        raw: CPointer<Unit>,
        descriptor: AbiReferenceDescriptorBase<T>,
        addRef!: Bool = false,
        releaseOnClose!: Bool = true,
        heapInstancePtr!: Option<UIntNative> = None,
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
            this.slotInfo = InterfaceSlotInfo(raw)
            match (heapInstancePtr) {
                case Some(value) =>
                    this.slotInfo.instancePtr = value
                case None => ()
            }
        }
    }
}

public struct InterfaceResource<T> <: Resource {
    private let state: InterfaceResourceState<T>

    public init(
        raw: CPointer<Unit>,
        descriptor: AbiReferenceDescriptorBase<T>,
        addRef!: Bool = false,
        releaseOnClose!: Bool = true,
        heapInstancePtr!: Option<UIntNative> = None,
        onClose!: Option<() -> Unit> = None
    ) {
        state = InterfaceResourceState<T>(
            raw,
            descriptor,
            addRef: addRef,
            releaseOnClose: releaseOnClose,
            heapInstancePtr: heapInstancePtr,
            onClose: onClose
        )
    }

    public static func new<U>(
        value: U,
        descriptor: AbiReferenceDescriptorBase<U>
    ): InterfaceResource<U> where U <: ComInterface {
        InterfaceResource<U>(value.asRaw(), descriptor, addRef: true)
    }

    public func isClosed(): Bool {
        state.closed || state.raw.isNull()
    }

    public func slotInfo(): InterfaceSlotInfo {
        state.slotInfo
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
            throw IllegalStateException("InterfaceResource is closed")
        }
        state.descriptor.viewOf(raw)
    }

    public func close(): Unit {
        if (state.closed) {
            return
        }
        if (state.releaseOnClose && !state.raw.isNull()) {
            state.descriptor.releasePointer(state.raw)
        }
        state.raw = CPointer<Unit>()
        state.slotInfo = InterfaceSlotInfo()
        state.closed = true
        match (state.onClose) {
            case Some(callback) => callback()
            case None => ()
        }
    }
}

public unsafe func createInterfaceResource<T>(
    descriptor: AbiReferenceDescriptorBase<T>,
    raw: CPointer<Unit>,
    addRef!: Bool = false
): InterfaceResource<T> {
    InterfaceResource<T>(raw, descriptor, addRef: addRef)
}

public unsafe func createInterfaceResourceFromTarget<T, U>(
    descriptor: AbiReferenceDescriptorBase<T>,
    target: U,
    vtablePtr: CPointer<Unit>
): InterfaceResource<T> where U <: Object {
    let slots = Array<CPointer<Unit>>(1, { _ => vtablePtr })
    let handle = acquireArrayRawData(slots)
    let raw = CPointer<Unit>(handle.pointer)
    let targetIdentity = acquireInterfaceTargetIdentity(target)
    interfaceTargetRegistryInsert(raw, target)
    InterfaceResource<T>(
        raw,
        descriptor,
        releaseOnClose: false,
        heapInstancePtr: Some(targetIdentity),
        onClose: Some({ =>
            interfaceTargetRegistryRemove(raw)
            releaseInterfaceTargetIdentity(targetIdentity)
            unsafe { releaseArrayRawData(handle) }
        })
    )
}
