package windows_strings

public struct PCSTR <: Equatable<PCSTR> {
    public var Value: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(ptr: CPointer<UInt8>) {
        Value = ptr
    }

    public static func fromRaw(ptr: CPointer<UInt8>): PCSTR {
        PCSTR(ptr)
    }

    public static func null(): PCSTR {
        PCSTR()
    }

    public static func default(): PCSTR {
        PCSTR()
    }

    public func asPtr(): CPointer<UInt8> {
        Value
    }

    public func isNull(): Bool {
        Value.isNull()
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

    // Equatable<PCSTR> — pointer identity equality (matches Rust PartialEq).
    public operator func ==(other: PCSTR): Bool {
        Value.toUIntNative() == other.Value.toUIntNative()
    }

    public operator func !=(other: PCSTR): Bool {
        Value.toUIntNative() != other.Value.toUIntNative()
    }
}
