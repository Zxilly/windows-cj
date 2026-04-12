package windows_result

import std.convert.*

let NTDLL_MODULE_NAME: Array<UInt8> = [
    0x6Eu8,
    0x74u8,
    0x64u8,
    0x6Cu8,
    0x6Cu8,
    0x2Eu8,
    0x64u8,
    0x6Cu8,
    0x6Cu8,
    0x00u8
]

func formatWindowsMessage(code: UInt32, flags: UInt32, source!: IntPtr = IntPtr()): Option<String> {
    var buffer = CPointer<UInt16>()
    let size = unsafe {
        FormatMessageW(
            flags,
            source,
            code,
            0u32,
            CPointer<CPointer<UInt16>>(inout buffer),
            0u32,
            CPointer<Unit>()
        )
    }
    if (size == 0u32 || buffer.isNull()) {
        return None
    }

    var result: Option<String> = None
    try (message = HeapString.fromRaw(buffer)) {
        let trimmedUnits = wide_trim_end(message.toWideArray(length: Int64(size)))
        let text = decodeUtf16(trimmedUnits)
        if (!text.isEmpty()) {
            result = Some(text)
        }
    }
    result
}

// HRESULT — 32-bit result code used by COM and Win32 APIs.
public struct HRESULT <: ToString & Hashable & Comparable<HRESULT> {
    public let value: Int32

    public init(value: Int32) {
        this.value = value
    }

    public init() {
        this.value = 0
    }

    public operator func ==(other: HRESULT): Bool {
        value == other.value
    }

    public operator func !=(other: HRESULT): Bool {
        value != other.value
    }

    public func hashCode(): Int64 {
        Int64(value)
    }

    public func compare(other: HRESULT): Ordering {
        if (value < other.value) {
            return Ordering.LT
        }
        if (value > other.value) {
            return Ordering.GT
        }
        Ordering.EQ
    }

    // Returns true if this is a success code (value >= 0).
    public func isOk(): Bool {
        value >= 0
    }

    // Returns true if this is a failure code (value < 0).
    public func isErr(): Bool {
        value < 0
    }

    // Aliases matching Win32 naming conventions.
    public func succeeded(): Bool {
        isOk()
    }

    public func failed(): Bool {
        isErr()
    }

    // Returns Ok(()) on success, or Err(Error) on failure.
    public func ok(): Result<Unit> {
        if (isErr()) {
            return Result<Unit>.Err(errorFromHRESULT(this))
        }
        Result<Unit>.Ok(())
    }

    // Calls op() and wraps the result in Ok if this code is successful.
    // Returns Err(Error) without calling op() if this code is a failure.
    public func map<T>(op: () -> T): Result<T> {
        match (ok()) {
            case Result<Unit>.Ok(_) => Result<T>.Ok(op())
            case Result<Unit>.Err(error) => Result<T>.Err(error)
        }
    }

    // Calls op() if this code is successful and returns its Result.
    // Returns Err(Error) without calling op() if this code is a failure.
    public func andThen<T>(op: () -> Result<T>): Result<T> {
        match (ok()) {
            case Result<Unit>.Ok(_) => op()
            case Result<Unit>.Err(error) => Result<T>.Err(error)
        }
    }

    // Throws Exception on failure; returns normally on success.
    public func unwrap(): Unit {
        if (isErr()) {
            panic("HRESULT ${this}")
        }
    }

    // Throws with a custom message prefix on failure.
    public func expect(message: String): Unit {
        if (isErr()) {
            panic("${message}: ${this}")
        }
    }

    public static func fromWin32(code: UInt32): HRESULT {
        WIN32_ERROR(code).toHRESULT()
    }

    public static func fromThread(): HRESULT {
        WIN32_ERROR.fromThread().toHRESULT()
    }

    public static func from(error: Error): HRESULT {
        errorToHRESULT(error)
    }

    public static func from<T>(result: Result<T>): HRESULT {
        fromResult(result)
    }

    public static func fromResult<T>(result: Result<T>): HRESULT {
        match (result) {
            case Result<T>.Ok(_) => HRESULT(0i32)
            case Result<T>.Err(error) => HRESULT.from(error)
        }
    }

    public func message(): String {
        let code = int32ToUInt32(value)
        if ((code & FACILITY_NT_BIT) != 0u32) {
            let ntStatusCode = code ^ FACILITY_NT_BIT
            let module = unsafe {
                let handle = acquireArrayRawData(NTDLL_MODULE_NAME)
                try {
                    LoadLibraryExA(handle.pointer, IntPtr(), LOAD_LIBRARY_SEARCH_DEFAULT_DIRS)
                } finally {
                    releaseArrayRawData(handle)
                }
            }
            if (module.isNotNull()) {
                if (let Some(msg) <- formatWindowsMessage(
                    ntStatusCode,
                    FORMAT_MESSAGE_ALLOCATE_BUFFER |
                        FORMAT_MESSAGE_FROM_HMODULE |
                        FORMAT_MESSAGE_FROM_SYSTEM |
                        FORMAT_MESSAGE_IGNORE_INSERTS,
                    source: module
                )) {
                    return msg
                }
            }
            return ""
        }

        if (let Some(msg) <- formatWindowsMessage(
            code,
            FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS
        )) {
            return msg
        }

        ""
    }

    // Formats the value as "0x00000000" (8 uppercase hex digits).
    public func toString(): String {
        let unsigned = int32ToUInt32(value)
        "0x${unsigned.format("08X")}"
    }
}

public let S_OK = HRESULT(0i32)
public let S_FALSE = HRESULT(1i32)
public let E_FAIL = HRESULT(-2147467259i32)
public let E_NOINTERFACE = HRESULT(-2147467262i32)
public let E_NOTIMPL = HRESULT(-2147467263i32)
public let E_POINTER = HRESULT(-2147467261i32)
public let E_OUTOFMEMORY = HRESULT(-2147024882i32)
public let E_INVALIDARG = HRESULT(-2147024809i32)
public let E_ACCESSDENIED = HRESULT(-2147024891i32)
public let E_UNEXPECTED = HRESULT(-2147418113i32)
public let E_ABORT = HRESULT(-2147467260i32)

// Reinterpret the bit pattern of an Int32 as a UInt32.
func int32ToUInt32(value: Int32): UInt32 {
    if (value >= 0) {
        return UInt32(value)
    }
    UInt32(4294967296i64 + Int64(value))
}

// Reinterpret the bit pattern of a UInt32 as an Int32.
func uint32ToInt32(value: UInt32): Int32 {
    if (value <= 2147483647u32) {
        return Int32(value)
    }
    Int32(Int64(value) - 4294967296i64)
}
