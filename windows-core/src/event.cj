package windows_core

import std.collection.*
import std.sync.*

let RPC_E_DISCONNECTED_EVENT = -2147417848i32
let RPC_E_SERVER_UNAVAILABLE_EVENT = -2147023174i32
let JSCRIPT_E_CANTEXECUTE_EVENT = -1996357631i32

foreign {
    func EncodePointer(ptr: CPointer<Unit>): CPointer<Unit>
}

public struct EventToken {
    public let value: Int64

    public init() {
        value = 0
    }

    public init(value: Int64) {
        this.value = value
    }
}

class EventEntry<T> where T <: ComInterface {
    public let token: EventToken
    public let direct: Option<ComPtr<T>>
    public let indirect: Option<ComPtr<IAgileReference>>

    public init(
        token: EventToken,
        direct: Option<ComPtr<T>>,
        indirect: Option<ComPtr<IAgileReference>>
    ) {
        this.token = token
        this.direct = direct
        this.indirect = indirect
    }

    public func cloneEntry(): EventEntry<T> {
        var directClone: Option<ComPtr<T>> = None
        match (direct) {
            case Some(pointer) => directClone = Some(pointer.clonePtr())
            case None => ()
        }
        var indirectClone: Option<ComPtr<IAgileReference>> = None
        match (indirect) {
            case Some(pointer) => indirectClone = Some(pointer.clonePtr())
            case None => ()
        }
        EventEntry<T>(token, directClone, indirectClone)
    }

    public func close(): Unit {
        match (direct) {
            case Some(pointer) => pointer.close()
            case None => ()
        }
        match (indirect) {
            case Some(pointer) => pointer.close()
            case None => ()
        }
    }
}

func encodeEventToken(raw: CPointer<Unit>): EventToken {
    if (raw.isNull()) {
        return EventToken()
    }
    let encoded = UInt64(unsafe { EncodePointer(raw).toUIntNative() })
    if ((encoded & 0x8000000000000000u64) == 0u64) {
        return EventToken(Int64(encoded))
    }
    if (encoded == 0x8000000000000000u64) {
        return EventToken(-9223372036854775808i64)
    }
    EventToken(-Int64((!encoded) + 1u64))
}

public class Event<T> <: Resource where T <: ComInterface {
    private let descriptor: InterfaceDescriptor<T>
    private let mutex = Mutex()
    private let entries = ArrayList<EventEntry<T>>()
    private var closed: Bool = false

    public init(descriptor: InterfaceDescriptor<T>) {
        this.descriptor = descriptor
    }

    public static func new(descriptor: InterfaceDescriptor<T>): Event<T> {
        Event<T>(descriptor)
    }

    public func add(delegate: T): Result<EventToken> {
        var rejected = false
        synchronized(mutex) {
            rejected = closed
        }
        if (rejected) {
            return Result<EventToken>.Err(WinError(E_POINTER))
        }
        let raw = delegate.asRaw()
        if (raw.isNull()) {
            return Result<EventToken>.Err(WinError(E_POINTER))
        }

        let entryResult = createEntry(delegate)
        let entry = match (entryResult) {
            case Result<EventEntry<T>>.Ok(value) => value
            case Result<EventEntry<T>>.Err(error) => return Result<EventToken>.Err(error)
        }
        var added = false
        synchronized(mutex) {
            if (closed) {
                added = false
            } else {
                entries.add(entry)
                added = true
            }
        }
        if (!added) {
            entry.close()
            return Result<EventToken>.Err(WinError(E_POINTER))
        }
        Result<EventToken>.Ok(entry.token)
    }

    public func remove(token: EventToken): Unit {
        var removed: Option<EventEntry<T>> = None
        synchronized(mutex) {
            var index = 0
            while (index < entries.size) {
                let entry = entries[index]
                if (entry.token.value == token.value) {
                    removed = Some(entry)
                    rebuildWithout(index)
                    break
                }
                index += 1
            }
        }
        match (removed) {
            case Some(entry) => entry.close()
            case None => ()
        }
    }

    public func clear(): Unit {
        let oldEntries = ArrayList<EventEntry<T>>()
        synchronized(mutex) {
            for (entry in entries) {
                oldEntries.add(entry)
            }
            entries.clear()
        }
        for (entry in oldEntries) {
            entry.close()
        }
    }

    public func call(callback: (T) -> Result<Unit>): Unit {
        let snapshot = ArrayList<EventEntry<T>>()
        synchronized(mutex) {
            for (entry in entries) {
                snapshot.add(entry.cloneEntry())
            }
        }

        for (entry in snapshot) {
            try {
                match (invokeEntry(entry, callback)) {
                    case Result<Unit>.Ok(_) =>
                        ()
                    case Result<Unit>.Err(error) =>
                        if (shouldAutoRemove(error)) {
                            remove(entry.token)
                        }
                }
            } finally {
                entry.close()
            }
        }
    }

    public func isClosed(): Bool {
        synchronized(mutex) {
            closed
        }
    }

    public func close(): Unit {
        let oldEntries = ArrayList<EventEntry<T>>()
        synchronized(mutex) {
            if (closed) {
                return
            }
            closed = true
            for (entry in entries) {
                oldEntries.add(entry)
            }
            entries.clear()
        }
        for (entry in oldEntries) {
            entry.close()
        }
    }

    private func rebuildWithout(skipIndex: Int64): Unit {
        let replacement = ArrayList<EventEntry<T>>()
        var index = 0
        while (index < entries.size) {
            if (index != skipIndex) {
                replacement.add(entries[index])
            }
            index += 1
        }
        entries.clear()
        for (entry in replacement) {
            entries.add(entry)
        }
    }

    private func createEntry(delegate: T): Result<EventEntry<T>> {
        match (delegate as InterfaceWrapperBase) {
            case Some(wrapper) =>
                match (unsafe { wrapper.query(IAgileObject.descriptor()) }) {
                    case Some(agile) =>
                        agile.close()
                        let pointer = ComPtr<T>.fromInterface(delegate, descriptor)
                        return Result<EventEntry<T>>.Ok(
                            EventEntry<T>(encodeEventToken(pointer.asRaw()), Some(pointer), None)
                        )
                    case None =>
                        ()
                }
            case None =>
                let pointer = ComPtr<T>.fromInterface(delegate, descriptor)
                return Result<EventEntry<T>>.Ok(
                    EventEntry<T>(encodeEventToken(pointer.asRaw()), Some(pointer), None)
                )
        }

        var iid = descriptor.iid
        var raw = CPointer<Unit>()
        let hr = unsafe {
            HRESULT(
                RoGetAgileReference(
                    AgileReferenceOptions.DEFAULT.value,
                    CPointer<GUID>(inout iid),
                    delegate.asRaw(),
                    CPointer<CPointer<Unit>>(inout raw)
                )
            )
        }
        if (hr.failed()) {
            return Result<EventEntry<T>>.Err(WinError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<EventEntry<T>>.Err(WinError(E_POINTER))
        }
        let pointer = ComPtr<IAgileReference>.attach(raw, IAgileReference.descriptor())
        Result<EventEntry<T>>.Ok(
            EventEntry<T>(encodeEventToken(pointer.asRaw()), None, Some(pointer))
        )
    }

    private func invokeEntry(
        entry: EventEntry<T>,
        callback: (T) -> Result<Unit>
    ): Result<Unit> {
        match (entry.direct) {
            case Some(pointer) =>
                let view = pointer.value()
                return callback(view)
            case None =>
                ()
        }

        match (entry.indirect) {
            case Some(pointer) =>
                let reference = pointer.value()
                match (unsafe { reference.resolve(descriptor) }) {
                    case Result<T>.Ok(resolved) =>
                        try {
                            callback(resolved)
                        } finally {
                            match (resolved as InterfaceWrapperBase) {
                                case Some(wrapper) => wrapper.close()
                                case None => ()
                            }
                        }
                    case Result<T>.Err(error) =>
                        Result<Unit>.Err(error)
                }
            case None =>
                Result<Unit>.Ok(())
        }
    }

    private func shouldAutoRemove(error: WinError): Bool {
        let code = error.code().value
        code == RPC_E_DISCONNECTED_EVENT ||
            code == RPC_E_SERVER_UNAVAILABLE_EVENT ||
            code == JSCRIPT_E_CANTEXECUTE_EVENT
    }
}
