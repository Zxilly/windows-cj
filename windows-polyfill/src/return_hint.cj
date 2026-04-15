package windows_polyfill

import std.convert.*

// HRESULT is a 32-bit signed integer used by Win32 and COM APIs to signal
// success or failure.  The high bit being set (i.e., value < 0) means failure.
public type HRESULT = Int32

// S_OK — the most common success code (0).
public let S_OK: HRESULT = 0i32

// hrSucceeded returns true when hr indicates success.
// Matches the Win32 SUCCEEDED macro: high bit is 0 ↔ value >= 0.
// S_FALSE (1) is also a success value.
public func hrSucceeded(hr: HRESULT): Bool {
    return hr >= 0i32
}

// hrFailed returns true when hr indicates failure.
// Matches the Win32 FAILED macro: high bit is 1 ↔ value < 0.
public func hrFailed(hr: HRESULT): Bool {
    return hr < 0i32
}

// uint32Hex formats an HRESULT as an 8-digit lowercase hex string.
// HRESULT failure codes have the high bit set, so they are negative as Int32.
// We sign-extend to Int64, mask to 32 bits (result is always 0..4294967295),
// then step through UInt64 → UInt32 — both casts are safe, no overflow.
func uint32Hex(v: HRESULT): String {
    let masked: Int64 = Int64(v) & 0xFFFFFFFFi64
    let u = UInt32(UInt64(masked))
    let hex = u.toString(radix: 16)
    // Pad to exactly 8 hex digits with leading zeros.
    let pad = 8 - hex.size
    var prefix = ""
    var i = 0
    while (i < pad) {
        prefix = prefix + "0"
        i++
    }
    return prefix + hex
}

// HResultException is thrown when a Win32 / COM call returns a failure HRESULT.
public class HResultException <: Exception {
    public let code: HRESULT

    public init(c: HRESULT) {
        super("HRESULT failure: 0x${uint32Hex(c)}")
        this.code = c
    }
}

// hrResultVoid checks hr and throws HResultException on failure.
// Use this when the Win32 function has no out-parameter to return.
public func hrResultVoid(hr: HRESULT): Unit {
    if (hrFailed(hr)) {
        throw HResultException(hr)
    }
}

// hrResultValue checks hr, throws on failure, and returns value on success.
// Use this to combine HRESULT checking with out-parameter propagation:
//   let obj = hrResultValue(SomeApi(&raw), raw)
public func hrResultValue<T>(hr: HRESULT, value: T): T {
    hrResultVoid(hr)
    return value
}

// E_NOINTERFACE (0x80004002) — QueryInterface returns this when the requested
// interface is not implemented. Treat as "not found" rather than an error.
public let E_NOINTERFACE: HRESULT = -2147467262i32

// hrQueryOptional bridges QueryInterface results: returns None on E_NOINTERFACE,
// throws on any other failure, returns Some(value) on success.
public func hrQueryOptional<T>(hr: HRESULT, value: T): Option<T> {
    if (hr == E_NOINTERFACE) {
        return None<T>
    }
    if (hrFailed(hr)) {
        throw HResultException(hr)
    }
    return Some(value)
}
