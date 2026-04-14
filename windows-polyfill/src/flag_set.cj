package windows_polyfill

// FlagSet polyfill: bitwise flag wrappers for Win32 flag enums.
// Provides |, &, ! (bitwise NOT), and contains() for the four integer
// widths used by Win32/WinRT flag enums: U32, U64, I32, I64.
//
// NOTE: operator func !() performs bitwise complement (like Rust's ! on integers),
// NOT boolean NOT. This matches Win32 flag semantics.

// ---------------------------------------------------------------------------
// FlagSetU32
// ---------------------------------------------------------------------------

public struct FlagSetU32 {
    public let value: UInt32

    public init(v: UInt32) {
        this.value = v
    }

    public operator func |(o: FlagSetU32): FlagSetU32 {
        return FlagSetU32(this.value | o.value)
    }

    public operator func &(o: FlagSetU32): FlagSetU32 {
        return FlagSetU32(this.value & o.value)
    }

    // Bitwise complement (all bits flipped), not boolean NOT.
    public operator func !(): FlagSetU32 {
        return FlagSetU32(!this.value)
    }

    // Returns true if all bits in `other` are set in `this`.
    public func contains(other: FlagSetU32): Bool {
        return (this.value & other.value) == other.value
    }
}

// ---------------------------------------------------------------------------
// FlagSetU64
// ---------------------------------------------------------------------------

public struct FlagSetU64 {
    public let value: UInt64

    public init(v: UInt64) {
        this.value = v
    }

    public operator func |(o: FlagSetU64): FlagSetU64 {
        return FlagSetU64(this.value | o.value)
    }

    public operator func &(o: FlagSetU64): FlagSetU64 {
        return FlagSetU64(this.value & o.value)
    }

    // Bitwise complement (all bits flipped), not boolean NOT.
    public operator func !(): FlagSetU64 {
        return FlagSetU64(!this.value)
    }

    // Returns true if all bits in `other` are set in `this`.
    public func contains(other: FlagSetU64): Bool {
        return (this.value & other.value) == other.value
    }
}

// ---------------------------------------------------------------------------
// FlagSetI32
// ---------------------------------------------------------------------------

public struct FlagSetI32 {
    public let value: Int32

    public init(v: Int32) {
        this.value = v
    }

    public operator func |(o: FlagSetI32): FlagSetI32 {
        return FlagSetI32(this.value | o.value)
    }

    public operator func &(o: FlagSetI32): FlagSetI32 {
        return FlagSetI32(this.value & o.value)
    }

    // Bitwise complement (all bits flipped), not boolean NOT.
    public operator func !(): FlagSetI32 {
        return FlagSetI32(!this.value)
    }

    // Returns true if all bits in `other` are set in `this`.
    public func contains(other: FlagSetI32): Bool {
        return (this.value & other.value) == other.value
    }
}

// ---------------------------------------------------------------------------
// FlagSetI64
// ---------------------------------------------------------------------------

public struct FlagSetI64 {
    public let value: Int64

    public init(v: Int64) {
        this.value = v
    }

    public operator func |(o: FlagSetI64): FlagSetI64 {
        return FlagSetI64(this.value | o.value)
    }

    public operator func &(o: FlagSetI64): FlagSetI64 {
        return FlagSetI64(this.value & o.value)
    }

    // Bitwise complement (all bits flipped), not boolean NOT.
    public operator func !(): FlagSetI64 {
        return FlagSetI64(!this.value)
    }

    // Returns true if all bits in `other` are set in `this`.
    public func contains(other: FlagSetI64): Bool {
        return (this.value & other.value) == other.value
    }
}
