package windows_strings

public struct PSTR <: Equatable<PSTR> {
    public var Value: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(ptr: CPointer<UInt8>) {
        Value = ptr
    }

    public static func fromRaw(ptr: CPointer<UInt8>): PSTR {
        PSTR(ptr)
    }

    public static func null(): PSTR {
        PSTR()
    }

    public static func default(): PSTR {
        PSTR()
    }

    public func asPtr(): CPointer<UInt8> {
        Value
    }

    public func isNull(): Bool {
        Value.isNull()
    }

    public func toPCSTR(): PCSTR {
        PCSTR.fromRaw(Value)
    }

    public unsafe func length(): Int64 {
        narrowPointerLength(Value)
    }

    public unsafe func isEmpty(): Bool {
        length() == 0
    }

    public unsafe func toArray(): Array<UInt8> {
        copyAnsiFromPointer(Value, length())
    }

    /// Snapshot the bytes pointed to by this string.
    ///
    /// Rust exposes a borrowed byte slice here. Cangjie does not provide an
    /// equivalent lifetime-tracked slice for this FFI pointer, so this returns
    /// the same copied snapshot as `toArray()`.
    public unsafe func asBytes(): Array<UInt8> {
        toArray()
    }

    public unsafe func asSlice(): PointerSliceView<UInt8> {
        PointerSliceView<UInt8>(Value, length())
    }

    public unsafe func toStringLossy(): String {
        decodeAnsiFromPointer(Value, length: length())
    }

    public unsafe func tryToString(): Option<String> {
        toString()
    }

    /// Decode the ANSI/UTF-8 string pointed to by this pointer.
    /// Unsafe: the pointer must be valid and null-terminated.
    /// Returns None when the byte sequence is not valid UTF-8.
    public unsafe func toString(): Option<String> {
        tryDecodeAnsiFromPointer(Value, length: length())
    }

    public unsafe func display(): StringDisplay {
        StringDisplay(toStringLossy())
    }

    // Equatable<PSTR> — pointer identity equality (matches Rust PartialEq).
    public operator func ==(other: PSTR): Bool {
        Value.toUIntNative() == other.Value.toUIntNative()
    }

    public operator func !=(other: PSTR): Bool {
        Value.toUIntNative() != other.Value.toUIntNative()
    }
}
