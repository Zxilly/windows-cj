package windows_result

@When[os == "Windows"]
func comAddRefRaw<T>(raw: CPointer<T>): UInt32 where T <: CType {
    if (raw.isNull()) {
        return 0u32
    }

    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.AddRef(CPointer<Unit>(raw))
    }
}

@When[os == "Windows"]
func comReleaseRaw<T>(raw: CPointer<T>): UInt32 where T <: CType {
    if (raw.isNull()) {
        return 0u32
    }

    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.Release(CPointer<Unit>(raw))
    }
}

@When[os == "Windows"]
func comQueryInterfaceRaw<T, U>(raw: CPointer<T>, iid: GUID): Option<CPointer<U>> where T <: CType, U <: CType {
    if (raw.isNull()) {
        return None
    }

    var requestedIid = iid
    var result = CPointer<Unit>()

    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        let hr = HRESULT(
            vtbl.QueryInterface(
                CPointer<Unit>(raw),
                CPointer<GUID>(inout requestedIid),
                CPointer<CPointer<Unit>>(inout result)
            )
        )

        if (hr.succeeded() && result.isNotNull()) {
            return Some(CPointer<U>(result))
        }
    }

    None
}

@When[os == "Windows"]
class ComPtr<T> <: Resource where T <: CType {
    private var raw: CPointer<T>
    private var closed: Bool = false

    public init(raw: CPointer<T>, addRef!: Bool = false) {
        this.raw = raw
        if (addRef) {
            comAddRefRaw(raw)
        }
    }

    public static func attach(raw: CPointer<T>): ComPtr<T> {
        ComPtr<T>(raw)
    }

    public func asRaw(): CPointer<T> {
        if (closed) {
            return CPointer<T>()
        }
        raw
    }

    public func hasValue(): Bool {
        !closed && raw.isNotNull()
    }

    public func addRef(): UInt32 {
        if (closed) {
            return 0u32
        }
        comAddRefRaw(raw)
    }

    public func clonePtr(): ComPtr<T> {
        if (closed) {
            throw Exception("ComPtr.clonePtr called on a closed ComPtr")
        }
        ComPtr<T>(raw, addRef: true)
    }

    public func clone(): ComPtr<T> {
        clonePtr()
    }

    public unsafe func cast<U>(iid: GUID): Option<ComPtr<U>> where U <: CType {
        match (comQueryInterfaceRaw<T, U>(asRaw(), iid)) {
            case Some(result) => Some(ComPtr<U>.attach(result))
            case None => None
        }
    }

    public func detach(): CPointer<T> {
        if (closed) {
            return CPointer<T>()
        }

        let detached = raw
        raw = CPointer<T>()
        closed = true
        detached
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            comReleaseRaw(raw)
            raw = CPointer<T>()
            closed = true
        }
    }

    public operator func ==(other: ComPtr<T>): Bool {
        let leftRaw = asRaw()
        let rightRaw = other.asRaw()
        if (leftRaw.isNull() || rightRaw.isNull()) {
            return leftRaw.toUIntNative() == rightRaw.toUIntNative()
        }

        match (unsafe { cast<IUnknown>(IID_IUnknown) }) {
            case Some(leftIdentity) =>
                try {
                    match (unsafe { other.cast<IUnknown>(IID_IUnknown) }) {
                        case Some(rightIdentity) =>
                            try {
                                return leftIdentity.asRaw().toUIntNative() == rightIdentity.asRaw().toUIntNative()
                            } finally {
                                rightIdentity.close()
                            }
                        case None =>
                            return false
                    }
                } finally {
                    leftIdentity.close()
                }
            case None =>
                return false
        }
    }

    public func close(): Unit {
        if (!closed) {
            comReleaseRaw(raw)
            raw = CPointer<T>()
            closed = true
        }
    }
}
