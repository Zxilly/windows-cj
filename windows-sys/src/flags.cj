package windows_sys

// --- FILE_SHARE_MODE ---
@C
public struct FILE_SHARE_MODE {
    public var value: UInt32 = 0

    public init() {}

    public init(v: UInt32) {
        value = v
    }

    public operator func |(rhs: FILE_SHARE_MODE): FILE_SHARE_MODE {
        FILE_SHARE_MODE(value | rhs.value)
    }

    public operator func &(rhs: FILE_SHARE_MODE): FILE_SHARE_MODE {
        FILE_SHARE_MODE(value & rhs.value)
    }

    public operator func ==(rhs: FILE_SHARE_MODE): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: FILE_SHARE_MODE): Bool {
        value != rhs.value
    }
}

public let FILE_SHARE_NONE: FILE_SHARE_MODE = FILE_SHARE_MODE(0)
public let FILE_SHARE_READ: FILE_SHARE_MODE = FILE_SHARE_MODE(0x00000001)
public let FILE_SHARE_WRITE: FILE_SHARE_MODE = FILE_SHARE_MODE(0x00000002)
public let FILE_SHARE_DELETE: FILE_SHARE_MODE = FILE_SHARE_MODE(0x00000004)

// --- FILE_ACCESS_FLAGS ---
@C
public struct FILE_ACCESS_FLAGS {
    public var value: UInt32 = 0

    public init() {}

    public init(v: UInt32) {
        value = v
    }

    public operator func |(rhs: FILE_ACCESS_FLAGS): FILE_ACCESS_FLAGS {
        FILE_ACCESS_FLAGS(value | rhs.value)
    }

    public operator func &(rhs: FILE_ACCESS_FLAGS): FILE_ACCESS_FLAGS {
        FILE_ACCESS_FLAGS(value & rhs.value)
    }

    public operator func ==(rhs: FILE_ACCESS_FLAGS): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: FILE_ACCESS_FLAGS): Bool {
        value != rhs.value
    }
}

public let GENERIC_READ: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x80000000)
public let GENERIC_WRITE: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x40000000)
public let GENERIC_EXECUTE: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x20000000)
public let GENERIC_ALL: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x10000000)
public let FILE_READ_DATA: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x00000001)
public let FILE_WRITE_DATA: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x00000002)
public let FILE_APPEND_DATA: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x00000004)
public let FILE_READ_ATTRIBUTES: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x00000080)
public let FILE_WRITE_ATTRIBUTES: FILE_ACCESS_FLAGS = FILE_ACCESS_FLAGS(0x00000100)

// --- FILE_CREATION_DISPOSITION ---
@C
public struct FILE_CREATION_DISPOSITION {
    public var value: UInt32 = 0

    public init() {}

    public init(v: UInt32) {
        value = v
    }

    public operator func ==(rhs: FILE_CREATION_DISPOSITION): Bool {
        value == rhs.value
    }

    public operator func !=(rhs: FILE_CREATION_DISPOSITION): Bool {
        value != rhs.value
    }
}

public let CREATE_NEW: FILE_CREATION_DISPOSITION = FILE_CREATION_DISPOSITION(1)
public let CREATE_ALWAYS: FILE_CREATION_DISPOSITION = FILE_CREATION_DISPOSITION(2)
public let OPEN_EXISTING: FILE_CREATION_DISPOSITION = FILE_CREATION_DISPOSITION(3)
public let OPEN_ALWAYS: FILE_CREATION_DISPOSITION = FILE_CREATION_DISPOSITION(4)
public let TRUNCATE_EXISTING: FILE_CREATION_DISPOSITION = FILE_CREATION_DISPOSITION(5)

// --- FILE_FLAGS_AND_ATTRIBUTES ---
public let FILE_ATTRIBUTE_READONLY: UInt32 = 0x00000001
public let FILE_ATTRIBUTE_HIDDEN: UInt32 = 0x00000002
public let FILE_ATTRIBUTE_SYSTEM: UInt32 = 0x00000004
public let FILE_ATTRIBUTE_DIRECTORY: UInt32 = 0x00000010
public let FILE_ATTRIBUTE_ARCHIVE: UInt32 = 0x00000020
public let FILE_ATTRIBUTE_NORMAL: UInt32 = 0x00000080
public let FILE_ATTRIBUTE_TEMPORARY: UInt32 = 0x00000100
public let FILE_FLAG_WRITE_THROUGH: UInt32 = 0x80000000
public let FILE_FLAG_OVERLAPPED: UInt32 = 0x40000000
public let FILE_FLAG_NO_BUFFERING: UInt32 = 0x20000000
public let FILE_FLAG_RANDOM_ACCESS: UInt32 = 0x10000000
public let FILE_FLAG_SEQUENTIAL_SCAN: UInt32 = 0x08000000
public let FILE_FLAG_DELETE_ON_CLOSE: UInt32 = 0x04000000

// --- Memory allocation constants ---
public let MEM_COMMIT: UInt32 = 0x00001000
public let MEM_RESERVE: UInt32 = 0x00002000
public let MEM_DECOMMIT: UInt32 = 0x00004000
public let MEM_RELEASE: UInt32 = 0x00008000
public let PAGE_NOACCESS: UInt32 = 0x01
public let PAGE_READONLY: UInt32 = 0x02
public let PAGE_READWRITE: UInt32 = 0x04
public let PAGE_EXECUTE: UInt32 = 0x10
public let PAGE_EXECUTE_READ: UInt32 = 0x20
public let PAGE_EXECUTE_READWRITE: UInt32 = 0x40

// --- Wait constants ---
public let WAIT_OBJECT_0: UInt32 = 0x00000000
public let WAIT_ABANDONED: UInt32 = 0x00000080
public let WAIT_TIMEOUT: UInt32 = 0x00000102
public let WAIT_FAILED: UInt32 = 0xFFFFFFFF
public let INFINITE: UInt32 = 0xFFFFFFFF

// --- Standard handle constants ---
// STD_INPUT_HANDLE = (DWORD)-10 = 0xFFFFFFF6
public let STD_INPUT_HANDLE: UInt32 = 0xFFFFFFF6
// STD_OUTPUT_HANDLE = (DWORD)-11 = 0xFFFFFFF5
public let STD_OUTPUT_HANDLE: UInt32 = 0xFFFFFFF5
// STD_ERROR_HANDLE = (DWORD)-12 = 0xFFFFFFF4
public let STD_ERROR_HANDLE: UInt32 = 0xFFFFFFF4

// --- File pointer move methods ---
public let FILE_BEGIN: UInt32 = 0
public let FILE_CURRENT: UInt32 = 1
public let FILE_END: UInt32 = 2
