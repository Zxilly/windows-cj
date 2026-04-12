package windows_result

import std.convert.*

// Win32 调用约定由仓颉 FFI 自动处理（Windows x64 ABI 统一）
@FastNative
foreign func GetLastError(): UInt32

// WIN32_ERROR — unsigned Win32 error code.
public struct WIN32_ERROR <: ToString & Equatable<WIN32_ERROR> & Hashable & Comparable<WIN32_ERROR> {
    public let value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    // Returns true if this is a success code (ERROR_SUCCESS = 0).
    public func isOk(): Bool {
        value == 0u32
    }

    // Returns true if this is a failure code.
    public func isErr(): Bool {
        !isOk()
    }

    // Maps this Win32 error code to an HRESULT.
    // If the value is already a negative i32 (high bit set), it is kept as-is;
    // otherwise it is encoded as FACILITY_WIN32: 0x8007xxxx.
    public func toHRESULT(): HRESULT {
        let signed = uint32ToInt32(value)
        if (signed <= 0) {
            return HRESULT(signed)
        }
        // FACILITY_WIN32 = 7, SEVERITY_ERROR bit = 0x80000000
        let bits = (value & 0x0000FFFFu32) | (7u32 << 16u32) | 0x80000000u32
        HRESULT(uint32ToInt32(bits))
    }

    public func toError(): Error {
        errorFromWin32(value)
    }

    // Returns Ok(()) on success, or Err(Error) on failure.
    public func ok(): Result<Unit> {
        toHRESULT().ok()
    }

    // Returns Some(WIN32_ERROR) if the Error originates from FACILITY_WIN32, otherwise None.
    public static func fromError(error: Error): Option<WIN32_ERROR> {
        let bits = int32ToUInt32(errorCode(error).value)
        if (((bits >> 16u32) & 0x07FFu32) == 7u32) {
            return Some(WIN32_ERROR(bits & 0x0000FFFFu32))
        }
        None
    }

    public static func from(error: Error): Option<WIN32_ERROR> {
        fromError(error)
    }

    // Returns the WIN32_ERROR from the calling thread's last error (GetLastError).
    public static func fromThread(): WIN32_ERROR {
        unsafe { WIN32_ERROR(GetLastError()) }
    }

    public operator func ==(other: WIN32_ERROR): Bool {
        value == other.value
    }

    public operator func !=(other: WIN32_ERROR): Bool {
        value != other.value
    }

    public func hashCode(): Int64 {
        Int64(value)
    }

    public func compare(other: WIN32_ERROR): Ordering {
        if (value < other.value) {
            return Ordering.LT
        }
        if (value > other.value) {
            return Ordering.GT
        }
        Ordering.EQ
    }

    public func toString(): String {
        value.toString()
    }
}
