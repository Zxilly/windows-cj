package windows_core

class OutParamState<T> {
    public var value: ?T = None
    private var slot: CPointer<Unit> = CPointer<Unit>()
    private var slotSize: UIntNative = UIntNative(0)

    public init() {}

    public init(value: T) {
        this.value = Some(value)
    }

    public func borrowMut<A>(): CPointer<A> where A <: CType {
        let requiredSize = sizeOf<A>()
        if (slot.isNull() || slotSize != requiredSize) {
            closeSlot()
            slot = unsafe { CoTaskMemAlloc(requiredSize) }
            if (slot.isNull()) {
                throw WindowsException(E_OUTOFMEMORY)
            }
            slotSize = requiredSize
        }
        clearSlot()
        CPointer<A>(slot)
    }

    public func clearValue(): Unit {
        value = None
        clearSlot()
    }

    public func closeSlot(): Unit {
        if (slot.isNull()) {
            return
        }
        unsafe { CoTaskMemFree(slot) }
        slot = CPointer<Unit>()
        slotSize = UIntNative(0)
    }

    ~init() {
        if (slot.isNull()) {
            return
        }
        unsafe { CoTaskMemFree(slot) }
        slot = CPointer<Unit>()
        slotSize = UIntNative(0)
    }

    private func clearSlot(): Unit {
        if (slot.isNull()) {
            return
        }
        let bytes = CPointer<UInt8>(slot)
        var index = 0
        while (index < Int64(slotSize)) {
            unsafe { (bytes + index).write(0u8) }
            index += 1
        }
    }
}

// OutSlot<T> 表示一个真正的 ABI 输出槽位，负责管理临时缓冲与结果接管。
public class OutSlot<T> <: Resource {
    private let state: OutParamState<T>
    private var closed: Bool = false

    public init() {
        state = OutParamState<T>()
    }

    public init(value: T) {
        state = OutParamState<T>(value)
    }

    public func isNull(): Bool {
        closed
    }

    public func get(): ?T {
        if (closed) {
            return None
        }
        state.value
    }

    public func borrowMut<A>(): CPointer<A> where A <: CType {
        if (closed) {
            return nullAbiValue<CPointer<A>>()
        }
        state.borrowMut<A>()
    }

    public func write(value: T): Unit {
        if (closed) {
            throw IllegalStateException("OutSlot is closed")
        }
        state.value = Some(value)
    }

    public func clear(): Unit {
        if (closed) {
            return
        }
        state.clearValue()
    }

    public func take(): ?T {
        if (closed) {
            return None
        }
        let current = state.value
        state.value = None
        current
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        state.clearValue()
        state.closeSlot()
        closed = true
    }

    ~init() {
        close()
    }
}
