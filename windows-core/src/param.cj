package windows_core

// Param<T> marks values that can provide a T-shaped argument at an ABI boundary.
// Cangjie has no lifetimes, so explicit wrappers model call-scoped access.
public interface Param<T> {
    func abi(): T
}

// ParamValue<T> owns the argument value and exposes its ABI form on demand.
public struct ParamValue<T> <: Param<T> {
    private let value: T

    public init(value: T) {
        this.value = value
    }

    public func abi(): T {
        value
    }

    public func borrow(): InParam<T> {
        InParam<T>(value)
    }
}

public func paramFromInterface<T, U>(
    value: U,
    target: InterfaceDescriptor<T>
): Result<ParamValue<T>> where T <: ComInterface & Interface<T>, U <: ComInterface & Interface<U> {
    match (coerceInterfaceValue(value, target)) {
        case Result<T>.Ok(resolved) =>
            Result<ParamValue<T>>.Ok(ParamValue<T>(resolved))
        case Result<T>.Err(error) =>
            Result<ParamValue<T>>.Err(error)
    }
}
