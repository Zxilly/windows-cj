package windows_core

import windows_interface.RuntimeTypeContract
import windows_strings.*

public interface WindowsType {
    static func abiType(): String
}

public interface RuntimeType <: WindowsType {
    static func signature(): String

    static func runtimeContract(): RuntimeTypeContract {
        let value = signature()
        RuntimeTypeContract(value, value)
    }
}

public interface RuntimeName {
    static func runtimeName(): String

    static func signature(): String {
        runtimeName()
    }

    static func runtimeType(): RuntimeTypeContract {
        let name = runtimeName()
        RuntimeTypeContract(name, signature())
    }
}

public func runtimeClassNameOf<T>(): HString where T <: RuntimeName {
    HString(T.runtimeName())
}

func copyFromAbi<T>(abi: T): Result<T> where T <: CopyType {
    Result<T>.Ok(abi)
}

func copyFromDefault<T>(defaultValue: T): Result<T> where T <: CopyType {
    Result<T>.Ok(defaultValue)
}

extend Bool <: CopyType & RuntimeType & Type<Bool, Bool, Bool> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "Bool" }
    public static func signature(): String { "b1" }
    public static func assumeInitRef(abi: Bool): Bool { abi }
    public static func fromAbi(abi: Bool): Result<Bool> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: Bool): Result<Bool> { copyFromDefault(defaultValue) }
}

extend Int8 <: CopyType & RuntimeType & Type<Int8, Int8, Int8> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "Int8" }
    public static func signature(): String { "i1" }
    public static func assumeInitRef(abi: Int8): Int8 { abi }
    public static func fromAbi(abi: Int8): Result<Int8> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: Int8): Result<Int8> { copyFromDefault(defaultValue) }
}

extend UInt8 <: CopyType & RuntimeType & Type<UInt8, UInt8, UInt8> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "UInt8" }
    public static func signature(): String { "u1" }
    public static func assumeInitRef(abi: UInt8): UInt8 { abi }
    public static func fromAbi(abi: UInt8): Result<UInt8> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: UInt8): Result<UInt8> { copyFromDefault(defaultValue) }
}

extend Int16 <: CopyType & RuntimeType & Type<Int16, Int16, Int16> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "Int16" }
    public static func signature(): String { "i2" }
    public static func assumeInitRef(abi: Int16): Int16 { abi }
    public static func fromAbi(abi: Int16): Result<Int16> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: Int16): Result<Int16> { copyFromDefault(defaultValue) }
}

extend UInt16 <: CopyType & RuntimeType & Type<UInt16, UInt16, UInt16> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "UInt16" }
    public static func signature(): String { "u2" }
    public static func assumeInitRef(abi: UInt16): UInt16 { abi }
    public static func fromAbi(abi: UInt16): Result<UInt16> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: UInt16): Result<UInt16> { copyFromDefault(defaultValue) }
}

extend Int32 <: CopyType & RuntimeType & Type<Int32, Int32, Int32> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "Int32" }
    public static func signature(): String { "i4" }
    public static func assumeInitRef(abi: Int32): Int32 { abi }
    public static func fromAbi(abi: Int32): Result<Int32> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: Int32): Result<Int32> { copyFromDefault(defaultValue) }
}

extend UInt32 <: CopyType & RuntimeType & Type<UInt32, UInt32, UInt32> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "UInt32" }
    public static func signature(): String { "u4" }
    public static func assumeInitRef(abi: UInt32): UInt32 { abi }
    public static func fromAbi(abi: UInt32): Result<UInt32> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: UInt32): Result<UInt32> { copyFromDefault(defaultValue) }
}

extend Int64 <: CopyType & RuntimeType & Type<Int64, Int64, Int64> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "Int64" }
    public static func signature(): String { "i8" }
    public static func assumeInitRef(abi: Int64): Int64 { abi }
    public static func fromAbi(abi: Int64): Result<Int64> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: Int64): Result<Int64> { copyFromDefault(defaultValue) }
}

extend UInt64 <: CopyType & RuntimeType & Type<UInt64, UInt64, UInt64> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "UInt64" }
    public static func signature(): String { "u8" }
    public static func assumeInitRef(abi: UInt64): UInt64 { abi }
    public static func fromAbi(abi: UInt64): Result<UInt64> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: UInt64): Result<UInt64> { copyFromDefault(defaultValue) }
}

extend Float32 <: CopyType & RuntimeType & Type<Float32, Float32, Float32> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "Float32" }
    public static func signature(): String { "f4" }
    public static func assumeInitRef(abi: Float32): Float32 { abi }
    public static func fromAbi(abi: Float32): Result<Float32> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: Float32): Result<Float32> { copyFromDefault(defaultValue) }
}

extend Float64 <: CopyType & RuntimeType & Type<Float64, Float64, Float64> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "Float64" }
    public static func signature(): String { "f8" }
    public static func assumeInitRef(abi: Float64): Float64 { abi }
    public static func fromAbi(abi: Float64): Result<Float64> { copyFromAbi(abi) }
    public static func fromDefault(defaultValue: Float64): Result<Float64> { copyFromDefault(defaultValue) }
}

extend HString <: CloneType & RuntimeType & Type<HString, HString, HString> {
    public static func typeKind(): TypeKind { TypeKind.Clone }
    public static func abiType(): String { "HString" }
    public static func signature(): String { "string" }
    public static func isNullAbi(abi: HString): Bool { abi.isEmpty() }
    public static func assumeInitRef(abi: HString): HString { cloneProjectedValue(abi) }
    public static func fromAbi(abi: HString): Result<HString> { Result<HString>.Ok(cloneProjectedValue(abi)) }
    public static func fromDefault(defaultValue: HString): Result<HString> { Result<HString>.Ok(cloneProjectedValue(defaultValue)) }
}

public let GUID_RUNTIME_SIGNATURE = "g16"
