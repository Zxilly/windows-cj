package windows_interface

class OutRefState {
    public let slots: Array<CPointer<Unit>>
    public let handle: CPointerHandle<CPointer<Unit>>
    public var released: Bool = false

    public init() {
        slots = Array<CPointer<Unit>>(1, { _ => CPointer<Unit>() })
        handle = unsafe { acquireArrayRawData(slots) }
    }

    public func borrow(): CPointer<Unit> {
        if (released) {
            return CPointer<Unit>()
        }
        slots[0]
    }

    public func borrowMut(): CPointer<CPointer<Unit>> {
        if (released) {
            throw IllegalStateException("OutRef storage has already been consumed")
        }
        slots[0] = CPointer<Unit>()
        handle.pointer
    }

    public func clear(): Unit {
        if (released) {
            return
        }
        slots[0] = CPointer<Unit>()
    }

    public func takeRaw(): CPointer<Unit> {
        if (released) {
            return CPointer<Unit>()
        }
        let current = slots[0]
        slots[0] = CPointer<Unit>()
        released = true
        unsafe { releaseArrayRawData(handle) }
        current
    }
}

public struct Ref<T> where T <: AbiPointerBacked {
    private let value: Option<T>

    public init() {
        value = None
    }

    public init(value: T) {
        this.value = Some(value)
    }

    public func isNull(): Bool {
        match (value) {
            case Some(_) => false
            case None => true
        }
    }

    public func asOption(): Option<T> {
        value
    }

    public func get(): T {
        if (let Some(inner) <- value) {
            return inner
        }
        throw IllegalStateException("Ref is null")
    }

    public func borrow(): CPointer<Unit> {
        if (let Some(inner) <- value) {
            return inner.asAbiPointer()
        }
        CPointer<Unit>()
    }
}

public struct OutRef<T> {
    private let state: OutRefState

    public init() {
        state = OutRefState()
    }

    public static func none(): OutRef<T> {
        OutRef<T>()
    }

    public func isNull(): Bool {
        state.borrow().isNull()
    }

    public func borrow(): CPointer<Unit> {
        state.borrow()
    }

    public func borrowMut(): CPointer<CPointer<Unit>> {
        state.borrowMut()
    }

    public func clear(): Unit {
        state.clear()
    }

    public func take(descriptor: AbiReferenceDescriptorBase<T>): Option<T> {
        let current = state.takeRaw()
        if (current.isNull()) {
            return None
        }
        Some(descriptor.wrapOwned(current))
    }
}
