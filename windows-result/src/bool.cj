package windows_result

// BOOL — Win32-style boolean wrapper used by lower-level interop.
public struct BOOL <: Equatable<BOOL> {
    public let value: Int32

    public init(value: Int32) {
        this.value = value
    }

    public init(value: Bool) {
        this.value = if (value) { 1i32 } else { 0i32 }
    }

    // Constructs a BOOL from a Bool value.
    public static func fromBool(value: Bool): BOOL {
        BOOL(value)
    }

    public static func from(value: Bool): BOOL {
        BOOL(value)
    }

    // Returns true if the BOOL represents a non-zero (truthy) value.
    public func as_bool(): Bool {
        value != 0
    }

    // Returns Ok(()) if truthy, or Err(errorFromThread()) if zero (FALSE).
    public func ok(): Result<Unit> {
        if (as_bool()) {
            return Result<Unit>.Ok(())
        }
        Result<Unit>.Err(errorFromThread())
    }

    // Throws Exception on failure (calls GetLastError for the error code).
    public func unwrap(): Unit {
        if (!as_bool()) {
            panic("BOOL false: ${errorFromThread()}")
        }
    }

    // Throws with a custom message prefix on failure.
    public func expect(message: String): Unit {
        if (!as_bool()) {
            panic("${message}: ${errorFromThread()}")
        }
    }

    // Logical NOT: returns the opposite BOOL value.
    public operator func !(): BOOL {
        if (as_bool()) { BOOL(0i32) } else { BOOL(1i32) }
    }

    public operator func ==(other: BOOL): Bool {
        value == other.value
    }

    public operator func ==(other: Bool): Bool {
        as_bool() == other
    }

    public operator func !=(other: Bool): Bool {
        as_bool() != other
    }
}

public let TRUE: BOOL = BOOL(1i32)
public let FALSE: BOOL = BOOL(0i32)
