package windows_strings

public struct PWSTR <: Equatable<PWSTR> {
    public var Value: CPointer<UInt16> = CPointer<UInt16>()

    public init() {}

    public init(ptr: CPointer<UInt16>) {
        Value = ptr
    }

    public static func fromRaw(ptr: CPointer<UInt16>): PWSTR {
        PWSTR(ptr)
    }

    public static func null(): PWSTR {
        PWSTR()
    }

    public static func default(): PWSTR {
        PWSTR()
    }

    public func asPtr(): CPointer<UInt16> {
        Value
    }

    public func isNull(): Bool {
        Value.isNull()
    }

    public func toPCWSTR(): PCWSTR {
        PCWSTR.fromRaw(Value)
    }

    public unsafe func length(): Int64 {
        widePointerLength(Value)
    }

    public unsafe func isEmpty(): Bool {
        length() == 0
    }

    public unsafe func toArray(): Array<UInt16> {
        copyWideFromPointer(Value, length())
    }

    /// Snapshot the UTF-16 units pointed to by this string.
    ///
    /// Rust exposes a borrowed wide slice here. Cangjie does not provide an
    /// equivalent lifetime-tracked slice for this FFI pointer, so this returns
    /// the same copied snapshot as `toArray()`.
    public unsafe func asWide(): Array<UInt16> {
        toArray()
    }

    public unsafe func asSlice(): PointerSliceView<UInt16> {
        PointerSliceView<UInt16>(Value, length())
    }

    public unsafe func toStringLossy(): String {
        decodeWideFromPointer(Value, length: length())
    }

    public unsafe func tryToString(): Option<String> {
        toString()
    }

    /// Decode the UTF-16 string pointed to by this pointer.
    /// Unsafe: the pointer must be valid and null-terminated.
    /// Returns None when the UTF-16 sequence is invalid.
    public unsafe func toString(): Option<String> {
        tryDecodeWideFromPointer(Value, length: length())
    }

    public unsafe func toHString(): HString {
        HString.fromWide(toArray())
    }

    public unsafe func display(): StringDisplay {
        StringDisplay(toStringLossy())
    }

    // Equatable<PWSTR> — pointer identity equality (matches Rust PartialEq).
    public operator func ==(other: PWSTR): Bool {
        Value.toUIntNative() == other.Value.toUIntNative()
    }

    public operator func !=(other: PWSTR): Bool {
        Value.toUIntNative() != other.Value.toUIntNative()
    }
}
