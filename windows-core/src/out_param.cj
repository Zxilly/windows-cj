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

// OutParam<T> 在仓颉侧保存 ABI 输出结果。
public struct OutParam<T> {
    private let state: OutParamState<T>

    public init() {
        state = OutParamState<T>()
    }

    public init(value: T) {
        state = OutParamState<T>(value)
    }

    public func borrow(): OutRef<T> {
        OutRef<T>(state)
    }

    public func get(): ?T {
        state.value
    }

    public func set(v: T): Unit {
        state.value = Some(v)
    }

    public func clear(): Unit {
        state.clearValue()
    }

    public func take(): ?T {
        let current = state.value
        state.value = None
        current
    }
}

// OutRef<T> 表示一个真正的 ABI 输出槽位。
public struct OutRef<T> {
    private let state: ?OutParamState<T>

    init() {
        state = None
    }

    init(state: OutParamState<T>) {
        this.state = Some(state)
    }

    public static func none(): OutRef<T> {
        OutRef<T>()
    }

    public func isNull(): Bool {
        match (state) {
            case Some(_) => false
            case None => true
        }
    }

    public func get(): ?T {
        match (state) {
            case Some(target) => target.value
            case None => Option<T>.None
        }
    }

    public func borrowMut<A>(): CPointer<A> where A <: CType {
        if (let Some(target) <- state) {
            return target.borrowMut<A>()
        }
        nullAbiValue<CPointer<A>>()
    }

    public func write(value: T): Unit {
        if (let Some(target) <- state) {
            target.value = Some(value)
            return
        }
        throw IllegalStateException("OutRef target is null")
    }

    public func clear(): Unit {
        if (let Some(target) <- state) {
            target.clearValue()
            return
        }
        throw IllegalStateException("OutRef target is null")
    }
}
