package windows_core

import windows_interface.GUID as RawGUID
public import windows_interface.{GUID, GUID_ZERO, UInt128}

public struct GuidValue {
    public var raw: RawGUID = RawGUID()

    public init() {}

    public init(raw: RawGUID) {
        this.raw = raw
    }

    public static func zeroed(): GuidValue {
        GuidValue()
    }

    public static func fromRaw(raw: RawGUID): GuidValue {
        GuidValue(raw)
    }

    public func toRaw(): RawGUID {
        raw
    }

    public static func from_values(
        data1: UInt32,
        data2: UInt16,
        data3: UInt16,
        data4_0: UInt8,
        data4_1: UInt8,
        data4_2: UInt8,
        data4_3: UInt8,
        data4_4: UInt8,
        data4_5: UInt8,
        data4_6: UInt8,
        data4_7: UInt8
    ): GuidValue {
        GuidValue(RawGUID.from_values(
            data1,
            data2,
            data3,
            data4_0,
            data4_1,
            data4_2,
            data4_3,
            data4_4,
            data4_5,
            data4_6,
            data4_7
        ))
    }

    public static func from_u128(value: UInt128): GuidValue {
        GuidValue(RawGUID.from_u128(value))
    }

    public static func generate(): GuidValue {
        GuidValue(RawGUID.generate())
    }

    public static func new(): Result<GuidValue> {
        match (RawGUID.new()) {
            case Result<RawGUID>.Ok(value) => Result<GuidValue>.Ok(GuidValue(value))
            case Result<RawGUID>.Err(error) => Result<GuidValue>.Err(error)
        }
    }

    public static func from_signature(signature: String): GuidValue {
        GuidValue(RawGUID.from_signature(signature))
    }

    public static func fromString(source: String): Option<GuidValue> {
        match (RawGUID.fromString(source)) {
            case Some(value) => Some(GuidValue(value))
            case None => None
        }
    }

    public static func parse(source: String): GuidValue {
        GuidValue(RawGUID.parse(source))
    }

    public static func tryFrom(source: String): Result<GuidValue> {
        match (RawGUID.tryFrom(source)) {
            case Result<RawGUID>.Ok(value) => Result<GuidValue>.Ok(GuidValue(value))
            case Result<RawGUID>.Err(error) => Result<GuidValue>.Err(error)
        }
    }

    public operator func ==(other: GuidValue): Bool {
        raw == other.raw
    }

    public operator func !=(other: GuidValue): Bool {
        !(this == other)
    }

    public func isZero(): Bool {
        raw.isZero()
    }

    public func hashCode(): Int64 {
        raw.hashCode()
    }

    public func toString(): String {
        raw.toString()
    }

    public func to_u128(): UInt128 {
        raw.to_u128()
    }
}

extend GuidValue <: CopyType & RuntimeType & Type<GuidValue, RawGUID, GuidValue> & WinrtGenericType<GuidValue> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "GUID" }
    public static func projectAbi(value: GuidValue): RawGUID { value.raw }
    public static func signature(): String { GUID_RUNTIME_SIGNATURE }
    public static func assumeInitRef(abi: RawGUID): GuidValue { GuidValue(abi) }
    public static func fromAbi(abi: RawGUID): Result<GuidValue> { Result<GuidValue>.Ok(GuidValue(abi)) }
    public static func fromDefault(defaultValue: GuidValue): Result<GuidValue> { Result<GuidValue>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<GuidValue> {
        ProjectedCopyWinrtOutputBridge<GuidValue, RawGUID, GuidValue>()
    }
}
