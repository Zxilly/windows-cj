package windows_core

public enum TypeKind {
    | Interface
    | Clone
    | Copy
}

public interface InterfaceType {
    static func typeKind(): TypeKind {
        TypeKind.Interface
    }
}

public interface CloneType {
    static func typeKind(): TypeKind {
        TypeKind.Clone
    }
}

public interface CopyType {
    static func typeKind(): TypeKind {
        TypeKind.Copy
    }
}

// 仓颉只支持顶层类型别名，无法用一元别名表达关联类型映射。
// 因此 Type<TProjected, TAbi, TDefault> 本身就是 ABI/Default 的权威来源。
public interface Type<TProjected, TAbi, TDefault> <: WindowsType {
    static func typeKind(): TypeKind

    static func isNullAbi(abi: TAbi): Bool {
        let _ = abi
        false
    }

    static func assumeInitRef(abi: TAbi): TProjected

    static func fromAbi(abi: TAbi): Result<TProjected>

    static func fromDefault(defaultValue: TDefault): Result<TProjected>
}

func cloneProjectedValue<T>(value: T): T {
    match (value) {
        case hstring: HString =>
            match (hstring.clone() as T) {
                case Some(cloned) => cloned
                case None => value
            }
        case _ =>
            value
    }
}

func cloneInterfaceValue<T>(value: T): Result<T> where T <: ComInterface & Interface<T> {
    match (value as InterfaceWrapperBase) {
        case Some(wrapper) =>
            let raw = wrapper.asRaw()
            if (raw.isNull()) {
                return Result<T>.Err(WinError(E_POINTER))
            }
            wrapper.addRef()
            Result<T>.Ok(T.fromAbiTake(raw))
        case None =>
            Result<T>.Ok(value)
    }
}

public func isNullAbi<T, A, D>(abi: A): Bool where T <: Type<T, A, D> {
    T.isNullAbi(abi)
}

public func assumeInitRef<T, A, D>(abi: A): T where T <: Type<T, A, D> {
    T.assumeInitRef(abi)
}

public func fromAbi<T, A, D>(abi: A): Result<T> where T <: Type<T, A, D> {
    T.fromAbi(abi)
}

public func fromDefault<T, A, D>(defaultValue: D): Result<T> where T <: Type<T, A, D> {
    T.fromDefault(defaultValue)
}

public func assumeInitCopy<T>(abi: T): T where T <: CopyType {
    abi
}
