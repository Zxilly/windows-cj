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

