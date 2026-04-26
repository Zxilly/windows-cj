package windows

import windows_core.*
import windows_result.Win32Exception
import windows_sys.Win32.Foundation.*
import windows_sys.Win32.Security.*
import windows_sys.Win32.System.Threading.*

func threadingWithWideString<R>(s: String, action: (CPointer<UInt16>) -> R): R {
    let ws = CWideString(s)
    try {
        return unsafe { ws.withPtr(action) }
    } finally {
        ws.close()
    }
}

// createEvent — creates a Win32 event object.
public func createEvent(
    manualReset: Bool,
    initialState: Bool,
    name!: Option<String> = None
): HANDLE {
    let bManualReset: Int32 = if (manualReset) { 1 } else { 0 }
    let bInitialState: Int32 = if (initialState) { 1 } else { 0 }
    let h = match (name) {
        case Some(n) =>
            threadingWithWideString(n) { p: CPointer<UInt16> =>
                unsafe {
                    ffiCreateEventW(
                        CPointer<SECURITY_ATTRIBUTES>(),
                        bManualReset,
                        bInitialState,
                        p
                    )
                }
            }
        case None =>
            ffiCreateEventW(
                CPointer<SECURITY_ATTRIBUTES>(),
                bManualReset,
                bInitialState,
                CPointer<UInt16>()
            )
    }
    if (h.isNull()) {
        throw Win32Exception(ffiGetLastError())
    }
    h
}

// createMutex — creates a Win32 mutex object.
public func createMutex(
    initialOwner: Bool,
    name!: Option<String> = None
): HANDLE {
    let bInitialOwner: Int32 = if (initialOwner) { 1 } else { 0 }
    let h = match (name) {
        case Some(n) =>
            threadingWithWideString(n) { p: CPointer<UInt16> =>
                unsafe {
                    ffiCreateMutexW(
                        CPointer<SECURITY_ATTRIBUTES>(),
                        bInitialOwner,
                        p
                    )
                }
            }
        case None =>
            ffiCreateMutexW(
                CPointer<SECURITY_ATTRIBUTES>(),
                bInitialOwner,
                CPointer<UInt16>()
            )
    }
    if (h.isNull()) {
        throw Win32Exception(ffiGetLastError())
    }
    h
}

// releaseMutex — releases ownership of a mutex.
public func releaseMutex(mutex: HANDLE): Unit {
    let result = ffiReleaseMutex(mutex)
    if (result == 0) {
        throw Win32Exception(ffiGetLastError())
    }
}

// waitForSingleObject — waits for a single object to be signaled.
// Returns WAIT_OBJECT_0 if signaled, WAIT_TIMEOUT if timeout, or throws on error.
public func waitForSingleObject(handle: HANDLE, milliseconds: UInt32): WAIT_EVENT {
    let result = ffiWaitForSingleObject(handle, milliseconds)
    if (result == WAIT_FAILED) {
        throw Win32Exception(ffiGetLastError())
    }
    result
}

// waitForMultipleObjects — waits for multiple objects.
// Returns WAIT_OBJECT_0 + index if waitAll=false and one is signaled,
// or 0 if waitAll=true and all are signaled, WAIT_TIMEOUT on timeout, or throws on error.
public func waitForMultipleObjects(
    handles: Array<HANDLE>,
    waitAll: Bool,
    milliseconds: UInt32
): WAIT_EVENT {
    let bWaitAll: Int32 = if (waitAll) { 1 } else { 0 }
    let count = UInt32(handles.size)
    let rawData = unsafe { acquireArrayRawData(handles) }
    let result: WAIT_EVENT
    try {
        result = ffiWaitForMultipleObjects(count, rawData.pointer, bWaitAll, milliseconds)
    } finally {
        unsafe { releaseArrayRawData(rawData) }
    }
    if (result == WAIT_FAILED) {
        throw Win32Exception(ffiGetLastError())
    }
    result
}

// sleepMs — suspends the current thread for the specified milliseconds.
public func sleepMs(milliseconds: UInt32): Unit {
    ffiSleep(milliseconds)
}

// CriticalSectionGuard — RAII wrapper for Win32 CRITICAL_SECTION.
@When[Windows_Win32_System_Kernel == "on"]
public class CriticalSectionGuard <: Resource {
    private var cs: CPointer<CRITICAL_SECTION>
    private var closed: Bool = false

    public init(cs: CPointer<CRITICAL_SECTION>) {
        this.cs = cs
        ffiEnterCriticalSection(cs)
    }

    public func isClosed(): Bool { closed }

    public func close(): Unit {
        if (!closed) {
            ffiLeaveCriticalSection(cs)
            closed = true
        }
    }
}
