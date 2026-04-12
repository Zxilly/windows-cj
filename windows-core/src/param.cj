package windows_core

// Param<T> 表示可以在 ABI 边界上提供 T 形态参数的值。
// 仓颉没有生命周期，因此这里使用显式包装代替借用约束。
public interface Param<T> {
    func abi(): T
}

// ParamValue<T> 持有实际参数值，并在需要时暴露其 ABI 形态。
public struct ParamValue<T> <: Param<T> {
    private let value: T

    public init(value: T) {
        this.value = value
    }

    public func abi(): T {
        value
    }

    public func borrow(): Ref<T> {
        Ref<T>(value)
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
