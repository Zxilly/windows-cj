package windows_core

public interface CanInto<T> {
    static func query(): Bool {
        false
    }
}

public func queryRequiredFor<T, U>(): Bool where T <: ComInterface & Interface<T>, U <: ComInterface & Interface<U> {
    if (T.iid() == U.iid()) {
        return false
    }
    !U.descriptor().matches(T.iid())
}

// Copy-like projected values never need QueryInterface-style coercion.
public func copyQueryRequiredFor<T, U>(): Bool where T <: CopyType & Type<T, T, T>, U <: CopyType & Type<U, U, U> {
    false
}

public func coerceInterfaceValue<T, U>(
    value: U,
    target: InterfaceDescriptor<T>
): Result<T> where T <: ComInterface & Interface<T>, U <: ComInterface & Interface<U> {
    let raw = value.asRaw()
    if (raw.isNull()) {
        return Result<T>.Err(WinError(E_POINTER))
    }

    if (!queryRequiredFor<T, U>()) {
        return Result<T>.Ok(target.viewOf(raw))
    }

    match (unsafe { queryInterfaceRaw(raw, target.iid) }) {
        case Some(resolved) =>
            Result<T>.Ok(target.takeFromAbi(resolved))
        case None =>
            Result<T>.Err(WinError(E_NOINTERFACE))
    }
}
