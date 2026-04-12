package windows_result

import std.convert.*

// RPC_STATUS — status code returned by Remote Procedure Call functions.
// Zero indicates success; non-zero values are Win32-compatible error codes.
public struct RPC_STATUS <: ToString & Equatable<RPC_STATUS> & Hashable & Comparable<RPC_STATUS> {
    public let value: Int32

    public init(value: Int32) {
        this.value = value
    }

    // Returns true if this is a success code (value == 0).
    public func isOk(): Bool {
        value == 0
    }

    // Returns true if this is a failure code.
    public func isErr(): Bool {
        !isOk()
    }

    // Maps this RPC_STATUS to an HRESULT via the WIN32 facility.
    public func toHRESULT(): HRESULT {
        WIN32_ERROR(int32ToUInt32(value)).toHRESULT()
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

    public operator func ==(other: RPC_STATUS): Bool {
        value == other.value
    }

    public operator func !=(other: RPC_STATUS): Bool {
        value != other.value
    }

    public func hashCode(): Int64 {
        Int64(value)
    }

    public func compare(other: RPC_STATUS): Ordering {
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
