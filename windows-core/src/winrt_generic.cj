package windows_core

import windows_interface.*
import windows_strings.*

public interface WinrtGenericType<T> {
    static func winrtOutputBridge(): WinrtOutputBridge<T>
}

public interface CopyWinrtType<T> <: WinrtGenericType<T> where T <: CType {
    static func winrtOutputBridge(): WinrtOutputBridge<T> {
        CopyWinrtOutputBridge<T>()
    }
}

public interface HandleWinrtType<T> <: WinrtGenericType<T> where T <: HandleWinrtType<T> {
    static func intoWinrtHandle(value: T): CPointer<Unit>
    static func fromAbiTakeWinrtHandle(raw: CPointer<Unit>): T
    static func viewWinrtHandle(raw: CPointer<Unit>): T

    static func allowNullWinrtHandle(): Bool {
        false
    }

    static func winrtOutputBridge(): WinrtOutputBridge<T> {
        HandleWinrtOutputBridge<T>()
    }
}

public interface WinrtInputBorrow <: Resource {
    func asRaw(): CPointer<Unit>
}

class StagedWinrtInputBorrow<A> <: WinrtInputBorrow where A <: CType {
    private let slot: OutSlot<A>
    private var raw: CPointer<Unit> = CPointer<Unit>()
    private var closed: Bool = false

    public init(value: A) {
        slot = OutSlot<A>()
        let staged = slot.borrowMut<A>()
        unsafe { staged.write(value) }
        raw = CPointer<Unit>(staged)
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        raw
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        raw = CPointer<Unit>()
        slot.close()
        closed = true
    }
}

class HandleWinrtInputBorrow <: WinrtInputBorrow {
    private var raw: CPointer<Unit> = CPointer<Unit>()
    private var closed: Bool = false

    public init(raw: CPointer<Unit>) {
        this.raw = raw
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        raw
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        raw = CPointer<Unit>()
        closed = true
    }
}

func ownedWinrtOutHandle<T>(value: T): CPointer<Unit> where T <: HandleWinrtType<T> {
    match (value) {
        case hstring: HString =>
            hstring.clone().intoRaw()
        case wrapper: InterfaceWrapperBase =>
            wrapper.retainRaw()
        case _ =>
            T.intoWinrtHandle(value)
    }
}

public open class WinrtOutputBridge<T> {
    public init() {}

    public open func borrowInput(
        value: T
    ): WinrtInputBorrow {
        let _ = value
        throw IllegalStateException("WinrtOutputBridge.borrowInput is not implemented")
    }

    public open func projectInput(
        inputRaw: CPointer<Unit>
    ): T {
        let _ = inputRaw
        throw IllegalStateException("WinrtOutputBridge.projectInput is not implemented")
    }

    public open func callOut(
        slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>
    ): T {
        let _ = slot
        let _ = instanceRaw
        throw IllegalStateException("WinrtOutputBridge.callOut is not implemented")
    }

    public open func callOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32
    ): T {
        let _ = slot
        let _ = instanceRaw
        let _ = arg0
        throw IllegalStateException("WinrtOutputBridge.callOutAfterUInt32 is not implemented")
    }

    public open func callOutFromHandleInput(
        slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        inputRaw: CPointer<Unit>
    ): T {
        let _ = slot
        let _ = instanceRaw
        let _ = inputRaw
        throw IllegalStateException("WinrtOutputBridge.callOutFromHandleInput is not implemented")
    }

    public open func callArrayOut(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        let _ = slot
        let _ = instanceRaw
        let _ = size
        let _ = items
        throw IllegalStateException("WinrtOutputBridge.callArrayOut is not implemented")
    }

    public open func callArrayOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        let _ = slot
        let _ = instanceRaw
        let _ = arg0
        let _ = size
        let _ = items
        throw IllegalStateException("WinrtOutputBridge.callArrayOutAfterUInt32 is not implemented")
    }

    public open func storeOut(
        result__: CPointer<CPointer<Unit>>,
        value: T
    ): Int32 {
        let _ = result__
        let _ = value
        throw IllegalStateException("WinrtOutputBridge.storeOut is not implemented")
    }

    /// Store one element into a multi-slot ABI buffer at the given index.
    /// Used by IIterator/IVectorView/IMapView GetMany batch transfers, where
    /// the caller passes a buffer of `capacity` slots of T's ABI type. The
    /// pointer stride is determined per-bridge based on its actual ABI type.
    public open func storeOutAt(
        buffer: CPointer<Unit>,
        index: Int64,
        value: T
    ): Int32 {
        let _ = buffer
        let _ = index
        let _ = value
        throw IllegalStateException("WinrtOutputBridge.storeOutAt is not implemented")
    }

    public open func eraseOut(
        action: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        let _ = action
        throw IllegalStateException("WinrtOutputBridge.eraseOut is not implemented")
    }

    public open func eraseOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> {
        let _ = action
        throw IllegalStateException("WinrtOutputBridge.eraseOutAfterUInt32 is not implemented")
    }

    public open func eraseOutFromHandleInput(
        action: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        let _ = action
        throw IllegalStateException("WinrtOutputBridge.eraseOutFromHandleInput is not implemented")
    }

    public open func eraseArrayOut(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        let _ = action
        throw IllegalStateException("WinrtOutputBridge.eraseArrayOut is not implemented")
    }

    public open func eraseArrayOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        let _ = action
        throw IllegalStateException("WinrtOutputBridge.eraseArrayOutAfterUInt32 is not implemented")
    }
}

class CopyWinrtOutputBridge<T> <: WinrtOutputBridge<T> where T <: CType {
    public init() {}

    public override func borrowInput(
        value: T
    ): WinrtInputBorrow {
        StagedWinrtInputBorrow<T>(value)
    }

    public override func projectInput(
        inputRaw: CPointer<Unit>
    ): T {
        if (inputRaw.isNull()) {
            throw WindowsException(E_POINTER)
        }
        return unsafe { CPointer<T>(inputRaw).read() }
    }

    public override func callOut(
        slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let method = CFunc<(CPointer<Unit>, CPointer<T>) -> Int32>(CPointer<Unit>(slot))
            let hr = unsafe { method(instanceRaw, result__.borrowMut<T>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<T>()) {
                case Some(raw) => value__ = Some(raw)
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let method = CFunc<(CPointer<Unit>, UInt32, CPointer<T>) -> Int32>(CPointer<Unit>(slot))
            let hr = unsafe { method(instanceRaw, arg0, result__.borrowMut<T>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<T>()) {
                case Some(raw) => value__ = Some(raw)
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callOutFromHandleInput(
        slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        inputRaw: CPointer<Unit>
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let method = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<T>) -> Int32>(CPointer<Unit>(slot))
            let hr = unsafe { method(instanceRaw, inputRaw, result__.borrowMut<T>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<T>()) {
                case Some(raw) => value__ = Some(raw)
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callArrayOut(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        var result = 0u32
        let method = CFunc<(CPointer<Unit>, UInt32, CPointer<T>, CPointer<UInt32>) -> Int32>(CPointer<Unit>(slot))
        let hr = unsafe { method(instanceRaw, size, CPointer<T>(items), CPointer<UInt32>(inout result)) }
        HRESULT(hr).ok()
        result
    }

    public override func callArrayOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        var result = 0u32
        let method = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<T>, CPointer<UInt32>) -> Int32>(CPointer<Unit>(slot))
        let hr = unsafe { method(instanceRaw, arg0, size, CPointer<T>(items), CPointer<UInt32>(inout result)) }
        HRESULT(hr).ok()
        result
    }

    public override func storeOut(
        result__: CPointer<CPointer<Unit>>,
        value: T
    ): Int32 {
        if (result__.isNull()) {
            return E_POINTER.value
        }
        unsafe { CPointer<T>(result__).write(value) }
        S_OK.value
    }

    public override func storeOutAt(
        buffer: CPointer<Unit>,
        index: Int64,
        value: T
    ): Int32 {
        if (buffer.isNull()) {
            return E_POINTER.value
        }
        let typed = CPointer<T>(buffer)
        unsafe { (typed + index).write(value) }
        S_OK.value
    }

    public override func eraseOut(
        action: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseOutFromHandleInput(
        action: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseArrayOut(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        action
    }

    public override func eraseArrayOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        action
    }
}

public class ProjectedCopyWinrtOutputBridge<T, A, D> <: WinrtOutputBridge<T> where T <: Type<T, A, D>, A <: CType {
    public init() {}

    public override func borrowInput(
        value: T
    ): WinrtInputBorrow {
        StagedWinrtInputBorrow<A>(T.projectAbi(value))
    }

    public override func projectInput(
        inputRaw: CPointer<Unit>
    ): T {
        if (inputRaw.isNull()) {
            throw WindowsException(E_POINTER)
        }
        return T.assumeInitRef(unsafe { CPointer<A>(inputRaw).read() })
    }

    public override func callOut(
        slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let method = CFunc<(CPointer<Unit>, CPointer<A>) -> Int32>(CPointer<Unit>(slot))
            let hr = unsafe { method(instanceRaw, result__.borrowMut<A>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<A>()) {
                case Some(raw) => value__ = Some(T.assumeInitRef(raw))
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let method = CFunc<(CPointer<Unit>, UInt32, CPointer<A>) -> Int32>(CPointer<Unit>(slot))
            let hr = unsafe { method(instanceRaw, arg0, result__.borrowMut<A>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<A>()) {
                case Some(raw) => value__ = Some(T.assumeInitRef(raw))
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callOutFromHandleInput(
        slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        inputRaw: CPointer<Unit>
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let method = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<A>) -> Int32>(CPointer<Unit>(slot))
            let hr = unsafe { method(instanceRaw, inputRaw, result__.borrowMut<A>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<A>()) {
                case Some(raw) => value__ = Some(T.assumeInitRef(raw))
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callArrayOut(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        var result = 0u32
        let method = CFunc<(CPointer<Unit>, UInt32, CPointer<A>, CPointer<UInt32>) -> Int32>(CPointer<Unit>(slot))
        let hr = unsafe { method(instanceRaw, size, CPointer<A>(items), CPointer<UInt32>(inout result)) }
        HRESULT(hr).ok()
        result
    }

    public override func callArrayOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        var result = 0u32
        let method = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<A>, CPointer<UInt32>) -> Int32>(CPointer<Unit>(slot))
        let hr = unsafe { method(instanceRaw, arg0, size, CPointer<A>(items), CPointer<UInt32>(inout result)) }
        HRESULT(hr).ok()
        result
    }

    public override func storeOut(
        result__: CPointer<CPointer<Unit>>,
        value: T
    ): Int32 {
        if (result__.isNull()) {
            return E_POINTER.value
        }
        unsafe { CPointer<A>(result__).write(T.projectAbi(value)) }
        S_OK.value
    }

    public override func storeOutAt(
        buffer: CPointer<Unit>,
        index: Int64,
        value: T
    ): Int32 {
        if (buffer.isNull()) {
            return E_POINTER.value
        }
        let typed = CPointer<A>(buffer)
        unsafe { (typed + index).write(T.projectAbi(value)) }
        S_OK.value
    }

    public override func eraseOut(
        action: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseOutFromHandleInput(
        action: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseArrayOut(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        action
    }

    public override func eraseArrayOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        action
    }
}

class HandleWinrtOutputBridge<T> <: WinrtOutputBridge<T> where T <: HandleWinrtType<T> {
    public init() {}

    public override func borrowInput(
        value: T
    ): WinrtInputBorrow {
        HandleWinrtInputBorrow(T.intoWinrtHandle(value))
    }

    public override func projectInput(
        inputRaw: CPointer<Unit>
    ): T {
        return T.viewWinrtHandle(inputRaw)
    }

    public override func callOut(
        slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let hr = unsafe { slot(instanceRaw, result__.borrowMut<CPointer<Unit>>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<CPointer<Unit>>()) {
                case Some(raw) => value__ = Some(T.fromAbiTakeWinrtHandle(raw))
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let hr = unsafe { slot(instanceRaw, arg0, result__.borrowMut<CPointer<Unit>>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<CPointer<Unit>>()) {
                case Some(raw) => value__ = Some(T.fromAbiTakeWinrtHandle(raw))
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callOutFromHandleInput(
        slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        inputRaw: CPointer<Unit>
    ): T {
        var value__: ?T = None
        try (result__ = OutSlot<T>()) {
            let hr = unsafe { slot(instanceRaw, inputRaw, result__.borrowMut<CPointer<Unit>>()) }
            HRESULT(hr).ok()
            match (result__.takeAbi<CPointer<Unit>>()) {
                case Some(raw) => value__ = Some(T.fromAbiTakeWinrtHandle(raw))
                case None => throw WindowsException(E_POINTER)
            }
        }
        match (value__) {
            case Some(value) => value
            case None => throw WindowsException(E_POINTER)
        }
    }

    public override func callArrayOut(
        slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        var result = 0u32
        let hr = unsafe { slot(instanceRaw, size, CPointer<CPointer<Unit>>(items), CPointer<UInt32>(inout result)) }
        HRESULT(hr).ok()
        result
    }

    public override func callArrayOutAfterUInt32(
        slot: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
        instanceRaw: CPointer<Unit>,
        arg0: UInt32,
        size: UInt32,
        items: CPointer<Unit>
    ): UInt32 {
        var result = 0u32
        let hr = unsafe { slot(instanceRaw, arg0, size, CPointer<CPointer<Unit>>(items), CPointer<UInt32>(inout result)) }
        HRESULT(hr).ok()
        result
    }

    public override func storeOut(
        result__: CPointer<CPointer<Unit>>,
        value: T
    ): Int32 {
        if (result__.isNull()) {
            return E_POINTER.value
        }
        let raw = ownedWinrtOutHandle(value)
        if (raw.isNull() && !T.allowNullWinrtHandle()) {
            return E_POINTER.value
        }
        unsafe { result__.write(raw) }
        S_OK.value
    }

    public override func storeOutAt(
        buffer: CPointer<Unit>,
        index: Int64,
        value: T
    ): Int32 {
        if (buffer.isNull()) {
            return E_POINTER.value
        }
        let raw = ownedWinrtOutHandle(value)
        if (raw.isNull() && !T.allowNullWinrtHandle()) {
            return E_POINTER.value
        }
        let typed = CPointer<CPointer<Unit>>(buffer)
        unsafe { (typed + index).write(raw) }
        S_OK.value
    }

    public override func eraseOut(
        action: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseOutFromHandleInput(
        action: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
    ): CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> {
        action
    }

    public override func eraseArrayOut(
        action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        action
    }

    public override func eraseArrayOutAfterUInt32(
        action: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
    ): CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> {
        action
    }
}

public func winrtCallGenericOut<T>(
    slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
    instanceRaw: CPointer<Unit>
): T where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().callOut(slot, instanceRaw)
}

public func winrtCallGenericOutAfterUInt32<T>(
    slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    arg0: UInt32
): T where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().callOutAfterUInt32(slot, instanceRaw, arg0)
}

public func winrtCallGenericOutFromHandleInput<T>(
    slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    inputRaw: CPointer<Unit>
): T where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().callOutFromHandleInput(slot, instanceRaw, inputRaw)
}

public func winrtCallGenericArrayOut<T>(
    slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    size: UInt32,
    items: CPointer<Unit>
): UInt32 where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().callArrayOut(slot, instanceRaw, size, items)
}

public func winrtCallGenericArrayOutAfterUInt32<T>(
    slot: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    arg0: UInt32,
    size: UInt32,
    items: CPointer<Unit>
): UInt32 where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().callArrayOutAfterUInt32(slot, instanceRaw, arg0, size, items)
}

public func winrtBorrowGenericIn<T>(
    value: T
): WinrtInputBorrow where T <: WinrtGenericType<T> {
    return T.winrtOutputBridge().borrowInput(value)
}

public func winrtProjectGenericIn<T>(
    inputRaw: CPointer<Unit>
): T where T <: WinrtGenericType<T> {
    return T.winrtOutputBridge().projectInput(inputRaw)
}

public func winrtCallGenericOutFromGenericInput<T, U>(
    slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    input: U
): T where T <: WinrtGenericType<T>, U <: WinrtGenericType<U> {
    var value__: ?T = None
    try (inputBorrow = winrtBorrowGenericIn<U>(input)) {
        value__ = Some(T.winrtOutputBridge().callOutFromHandleInput(slot, instanceRaw, inputBorrow.asRaw()))
    }
    match (value__) {
        case Some(value) => value
        case None => throw IllegalStateException("winrtCallGenericOutFromGenericInput did not produce a result")
    }
}

public func winrtStoreGenericOut<T>(
    result__: CPointer<CPointer<Unit>>,
    value: T
): Int32 where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().storeOut(result__, value)
}

/// Store one element into a multi-slot ABI buffer at the given index.
/// The buffer is treated as `T_abi[capacity]`. Caller is responsible for
/// staying within `capacity`. Used by IIterator/IVectorView/IMapView GetMany
/// to write `min(capacity, remaining)` elements per batch.
public func winrtStoreGenericOutAt<T>(
    buffer: CPointer<Unit>,
    index: Int64,
    value: T
): Int32 where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().storeOutAt(buffer, index, value)
}

public func winrtEraseGenericOut<T>(
    action: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
): CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().eraseOut(action)
}

public func winrtEraseGenericOutAfterUInt32<T>(
    action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>
): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().eraseOutAfterUInt32(action)
}

public func winrtEraseGenericOutFromHandleInput<T>(
    action: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
): CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().eraseOutFromHandleInput(action)
}

public func winrtEraseGenericArrayOut<T>(
    action: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
): CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().eraseArrayOut(action)
}

public func winrtEraseGenericArrayOutAfterUInt32<T>(
    action: CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32>
): CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<Unit>>, CPointer<UInt32>) -> Int32> where T <: WinrtGenericType<T> {
    T.winrtOutputBridge().eraseArrayOutAfterUInt32(action)
}
