package windows_core

func nullAbiValue<A>(): A where A <: CType {
    match (CPointer<Unit>() as A) {
        case Some(value) => value
        case None =>
            throw IllegalStateException("Ref/OutRef null ABI is only supported for pointer ABI types")
    }
}

func projectAbiValue<T, A>(value: T): A where A <: CType {
    match (value) {
        case hstring: HString =>
            match (hstring.asRaw() as A) {
                case Some(abi) => return abi
                case None => ()
            }
        case _ => ()
    }

    match (value as InterfaceWrapperBase) {
        case Some(wrapper) =>
            match (wrapper.asRaw() as A) {
                case Some(abi) => return abi
                case None => ()
            }
        case None => ()
    }

    match (value as A) {
        case Some(abi) => abi
        case None =>
            throw IllegalStateException("Cannot project the requested ABI representation")
    }
}

// Ref<T> 表示 ABI 边界上的只读借用包装。
public struct Ref<T> <: Param<T> {
    private let value: ?T

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

    public func asOption(): ?T {
        value
    }

    public func as_ref(): ?T {
        value
    }

    public func get(): T {
        if (let Some(inner) <- value) {
            return inner
        }
        throw IllegalStateException("Ref is null")
    }

    public func ok(): Result<T> {
        if (let Some(inner) <- value) {
            return Result<T>.Ok(inner)
        }
        Result<T>.Err(WinError(E_POINTER))
    }

    public func unwrap(): T {
        get()
    }

    public func cloned(): ?T {
        value
    }

    public func abi(): T {
        get()
    }

    public func borrow<A>(): A where A <: CType {
        match (value) {
            case Some(inner) => projectAbiValue<T, A>(inner)
            case None => nullAbiValue<A>()
        }
    }
}

// RefParam<T> 保留旧名称，兼容现有调用点。
public struct RefParam<T> <: Param<T> {
    private let inner: Ref<T>

    public init() {
        inner = Ref<T>()
    }

    public init(value: T) {
        inner = Ref<T>(value)
    }

    public func isNull(): Bool {
        inner.isNull()
    }

    public func asOption(): ?T {
        inner.asOption()
    }

    public func as_ref(): ?T {
        inner.as_ref()
    }

    public func get(): T {
        inner.get()
    }

    public func ok(): Result<T> {
        inner.ok()
    }

    public func unwrap(): T {
        inner.unwrap()
    }

    public func cloned(): ?T {
        inner.cloned()
    }

    public func abi(): T {
        inner.abi()
    }

    public func borrow<A>(): A where A <: CType {
        inner.borrow<A>()
    }
}
