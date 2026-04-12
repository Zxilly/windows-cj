package windows_sys

// Handle type aliases — CPointer<Unit> represents opaque Win32 handles
public type HANDLE = CPointer<Unit>
public type HWND = CPointer<Unit>
public type HINSTANCE = CPointer<Unit>
public type HMODULE = CPointer<Unit>
public type HICON = CPointer<Unit>
public type HCURSOR = CPointer<Unit>
public type HBRUSH = CPointer<Unit>
public type HMENU = CPointer<Unit>
public type HDC = CPointer<Unit>
public type HGDIOBJ = CPointer<Unit>

// Basic constants
public let TRUE: Int32 = 1
public let FALSE: Int32 = 0
public let MAX_PATH: Int64 = 260
public let NULL_HANDLE: HANDLE = CPointer<Unit>()

// INVALID_HANDLE_VALUE check — Win32 INVALID_HANDLE_VALUE is (HANDLE)(LONG_PTR)-1.
// Since CPointer cannot be directly constructed from an integer, we provide a
// comparison helper instead.
public func isInvalidHandle(h: HANDLE): Bool {
    h.toUIntNative() == !UIntNative(0)
}

// BOOL wrapper — mirrors Win32 BOOL (Int32)
@C
public struct BOOL {
    public var value: Int32 = 0

    public init() {}

    public init(v: Int32) {
        value = v
    }

    public func toBool(): Bool {
        value != 0
    }

    public operator func ==(rhs: BOOL): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: BOOL): Bool {
        value != rhs.value
    }
}

// LRESULT — signed pointer-sized integer for window procedure return
@C
public struct LRESULT {
    public var value: IntNative = 0

    public init() {}

    public init(v: IntNative) {
        value = v
    }

    public init(v: Int64) {
        value = IntNative(v)
    }

    public operator func ==(rhs: LRESULT): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: LRESULT): Bool {
        value != rhs.value
    }
}

// WPARAM — unsigned pointer-sized integer for message parameters
@C
public struct WPARAM {
    public var value: UIntNative = 0

    public init() {}

    public init(v: UIntNative) {
        value = v
    }

    public init(v: UInt64) {
        value = UIntNative(v)
    }

    public operator func ==(rhs: WPARAM): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: WPARAM): Bool {
        value != rhs.value
    }
}

// LPARAM — signed pointer-sized integer for message parameters
@C
public struct LPARAM {
    public var value: IntNative = 0

    public init() {}

    public init(v: IntNative) {
        value = v
    }

    public init(v: Int64) {
        value = IntNative(v)
    }

    public operator func ==(rhs: LPARAM): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: LPARAM): Bool {
        value != rhs.value
    }
}

// ATOM — 16-bit atom identifier returned by RegisterClass
@C
public struct ATOM {
    public var value: UInt16 = 0

    public init() {}

    public init(v: UInt16) {
        value = v
    }

    public operator func ==(rhs: ATOM): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: ATOM): Bool {
        value != rhs.value
    }
}
