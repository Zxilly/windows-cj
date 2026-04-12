package windows_result

import std.convert.*

// NTSTATUS — status code returned by NT kernel and driver functions.
public struct NTSTATUS <: ToString & Equatable<NTSTATUS> & Hashable & Comparable<NTSTATUS> {
    public let value: Int32

    public init(value: Int32) {
        this.value = value
    }

    // Returns true if this is a success or informational code (value >= 0).
    public func isOk(): Bool {
        value >= 0
    }

    // Returns true if this is a warning or error code (value < 0).
    public func isErr(): Bool {
        value < 0
    }

    // Maps this NTSTATUS to an HRESULT.
    // Success codes are passed through unchanged; failure codes have the
    // FACILITY_NT_BIT (0x10000000) set to mark them as NT status codes.
    public func toHRESULT(): HRESULT {
        if (value >= 0) {
            HRESULT(value)
        } else {
            HRESULT(value | 0x10000000i32)
        }
    }

    public func toError(): Error {
        errorFromHRESULT(toHRESULT())
    }

    // Returns Ok(()) on success, or Err(Error) on failure.
    public func ok(): Result<Unit> {
        toHRESULT().ok()
    }

    // Throws Exception on failure; returns normally on success.
    public func unwrap(): Unit {
        ok().unwrap()
    }

    public operator func ==(other: NTSTATUS): Bool {
        value == other.value
    }

    public operator func !=(other: NTSTATUS): Bool {
        value != other.value
    }

    public func hashCode(): Int64 {
        Int64(value)
    }

    public func compare(other: NTSTATUS): Ordering {
        if (value < other.value) {
            return Ordering.LT
        }
        if (value > other.value) {
            return Ordering.GT
        }
        Ordering.EQ
    }

    public func toString(): String {
        let unsigned = int32ToUInt32(value)
        "0x${unsigned.format("08X")}"
    }
}
