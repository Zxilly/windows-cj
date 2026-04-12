package windows

import windows_core.*
import windows_result.Win32Exception
import windows_sys.*

// =============================================================================
// Win32 Foundation — high-level safe wrappers
// =============================================================================

// createFile — opens or creates a file, throwing Win32Exception on failure.
public func createFile(
    path: String,
    desiredAccess: FILE_ACCESS_FLAGS,
    shareMode: FILE_SHARE_MODE,
    creationDisposition: FILE_CREATION_DISPOSITION,
    flagsAndAttributes: UInt32
): HANDLE {
    let desiredAccessValue = desiredAccess.value
    let shareModeValue = shareMode.value
    let creationDispositionValue = creationDisposition.value
    let handle = withWideString(path) { p: CPointer<UInt16> =>
        unsafe {
            ffiCreateFileW(
                p,
                desiredAccessValue,
                shareModeValue,
                CPointer<SECURITY_ATTRIBUTES>(),
                creationDispositionValue,
                flagsAndAttributes,
                CPointer<Unit>()
            )
        }
    }
    if (isInvalidHandle(handle)) {
        throw Win32Exception(ffiGetLastError())
    }
    handle
}

// tryCreateFile — returns None on failure instead of throwing.
public func tryCreateFile(
    path: String,
    desiredAccess: FILE_ACCESS_FLAGS,
    shareMode: FILE_SHARE_MODE,
    creationDisposition: FILE_CREATION_DISPOSITION,
    flagsAndAttributes: UInt32
): Option<HANDLE> {
    let desiredAccessValue = desiredAccess.value
    let shareModeValue = shareMode.value
    let creationDispositionValue = creationDisposition.value
    let handle = withWideString(path) { p: CPointer<UInt16> =>
        unsafe {
            ffiCreateFileW(
                p,
                desiredAccessValue,
                shareModeValue,
                CPointer<SECURITY_ATTRIBUTES>(),
                creationDispositionValue,
                flagsAndAttributes,
                CPointer<Unit>()
            )
        }
    }
    if (isInvalidHandle(handle)) { None } else { Some(handle) }
}

// closeHandle — closes a Win32 handle, throwing on failure.
public func closeHandle(handle: HANDLE): Unit {
    let result = ffiCloseHandle(handle)
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
    // Handle closed successfully
}

// messageBox — displays a message box, returning the button ID.
public func messageBox(
    owner: HWND,
    text: String,
    caption: String,
    boxType: UInt32
): Int32 {
    let result = withWideString(text) { pText: CPointer<UInt16> =>
        withWideString(caption) { pCaption: CPointer<UInt16> =>
            unsafe {
                ffiMessageBoxW(owner, pText, pCaption, boxType)
            }
        }
    }
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
    result
}

// messageBoxSimple — convenience for OK message box with no owner.
public func messageBoxSimple(text: String, caption: String): Unit {
    messageBox(CPointer<Unit>(), text, caption, MB_OK)
}

// getModuleHandle — gets the current module handle, throwing on failure.
public func getModuleHandle(): HMODULE {
    let h = ffiGetModuleHandleW(CPointer<UInt16>())
    if (h.isNull()) {
        throw Win32Exception(ffiGetLastError())
    }
    h
}

// loadLibrary — loads a DLL, throwing on failure.
public func loadLibrary(name: String): HMODULE {
    let h = withWideString(name) { p: CPointer<UInt16> =>
        ffiLoadLibraryW(p)
    }
    if (h.isNull()) {
        throw Win32Exception(ffiGetLastError())
    }
    h
}

// createDirectory — creates a directory, throwing on failure.
public func createDirectory(path: String): Unit {
    let result = withWideString(path) { p: CPointer<UInt16> =>
        ffiCreateDirectoryW(p, CPointer<SECURITY_ATTRIBUTES>())
    }
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
}

// deleteFile — deletes a file, throwing on failure.
public func deleteFile(path: String): Unit {
    let result = withWideString(path) { p: CPointer<UInt16> =>
        ffiDeleteFileW(p)
    }
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
}

// moveFile — moves/renames a file, throwing on failure.
public func moveFile(existing: String, newPath: String): Unit {
    let result = withWideString(existing) { p1: CPointer<UInt16> =>
        withWideString(newPath) { p2: CPointer<UInt16> =>
            ffiMoveFileW(p1, p2)
        }
    }
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
}

// withWideString — executes an action with a temporary CWideString pointer.
public func withWideString<R>(s: String, action: (CPointer<UInt16>) -> R): R {
    let ws = CWideString(s)
    try {
        return unsafe { ws.withPtr(action) }
    } finally {
        ws.close()
    }
}

// withHString — executes an action with a temporary HString.
public func withHString<R>(s: String, action: (HString) -> R): R {
    let hs = HString(s)
    try {
        return action(hs)
    } finally {
        hs.close()
    }
}

// CAnsiString — utility for ANSI (single-byte) C strings.
public class CAnsiString <: Resource {
    private var data: Array<UInt8>
    private var closed: Bool = false

    public init(s: String) {
        var bytes = Array<UInt8>(s.size + 1, repeat: 0u8)
        var i: Int64 = 0
        for (b in s.toArray()) {
            bytes[i] = UInt8(b)
            i += 1
        }
        data = bytes
    }

    public static func literal(s: String): CAnsiString {
        CAnsiString(s)
    }

    public unsafe func withPtr<R>(action: (CPointer<UInt8>) -> R): R {
        let handle = acquireArrayRawData(data)
        try {
            return action(handle.pointer)
        } finally {
            releaseArrayRawData(handle)
        }
    }

    public func isClosed(): Bool { closed }

    public func close(): Unit {
        closed = true
    }
}

// withAnsiString — convenience for temporary ANSI strings.
public func withAnsiString<R>(s: String, action: (CPointer<UInt8>) -> R): R {
    let as_ = CAnsiString(s)
    try {
        return unsafe { as_.withPtr(action) }
    } finally {
        as_.close()
    }
}
