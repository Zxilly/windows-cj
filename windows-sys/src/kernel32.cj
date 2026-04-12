package windows_sys

// --- Kernel32 @C structs ---

@C
public struct OVERLAPPED {
    public var internal: UIntNative = 0
    public var internalHigh: UIntNative = 0
    public var offset: UInt32 = 0
    public var offsetHigh: UInt32 = 0
    public var hEvent: HANDLE = CPointer<Unit>()

    public init() {}
}

@C
public struct CRITICAL_SECTION {
    public var debugInfo: CPointer<Unit> = CPointer<Unit>()
    public var lockCount: Int32 = 0
    public var recursionCount: Int32 = 0
    public var owningThread: HANDLE = CPointer<Unit>()
    public var lockSemaphore: HANDLE = CPointer<Unit>()
    public var spinCount: UIntNative = 0

    public init() {}
}

@C
public struct WIN32_FIND_DATAW {
    public var dwFileAttributes: UInt32 = 0
    public var ftCreationTime: FILETIME = FILETIME()
    public var ftLastAccessTime: FILETIME = FILETIME()
    public var ftLastWriteTime: FILETIME = FILETIME()
    public var nFileSizeHigh: UInt32 = 0
    public var nFileSizeLow: UInt32 = 0
    public var dwReserved0: UInt32 = 0
    public var dwReserved1: UInt32 = 0
    public var cFileName: VArray<UInt16, $260> = VArray<UInt16, $260>(repeat: 0)
    public var cAlternateFileName: VArray<UInt16, $14> = VArray<UInt16, $14>(repeat: 0)

    public init() {}
}

@C
public struct STARTUPINFOW {
    public var cb: UInt32 = 0
    public var lpReserved: CPointer<UInt16> = CPointer<UInt16>()
    public var lpDesktop: CPointer<UInt16> = CPointer<UInt16>()
    public var lpTitle: CPointer<UInt16> = CPointer<UInt16>()
    public var dwX: UInt32 = 0
    public var dwY: UInt32 = 0
    public var dwXSize: UInt32 = 0
    public var dwYSize: UInt32 = 0
    public var dwXCountChars: UInt32 = 0
    public var dwYCountChars: UInt32 = 0
    public var dwFillAttribute: UInt32 = 0
    public var dwFlags: UInt32 = 0
    public var wShowWindow: UInt16 = 0
    public var cbReserved2: UInt16 = 0
    public var lpReserved2: CPointer<UInt8> = CPointer<UInt8>()
    public var hStdInput: HANDLE = CPointer<Unit>()
    public var hStdOutput: HANDLE = CPointer<Unit>()
    public var hStdError: HANDLE = CPointer<Unit>()

    public init() {}
}

@C
public struct PROCESS_INFORMATION {
    public var hProcess: HANDLE = CPointer<Unit>()
    public var hThread: HANDLE = CPointer<Unit>()
    public var dwProcessId: UInt32 = 0
    public var dwThreadId: UInt32 = 0

    public init() {}
}

// Common processor architecture values returned by SYSTEM_INFO.
public let PROCESSOR_ARCHITECTURE_INTEL: UInt16 = 0
public let PROCESSOR_ARCHITECTURE_ARM: UInt16 = 5
public let PROCESSOR_ARCHITECTURE_IA64: UInt16 = 6
public let PROCESSOR_ARCHITECTURE_AMD64: UInt16 = 9
public let PROCESSOR_ARCHITECTURE_ARM64: UInt16 = 12
public let PROCESSOR_ARCHITECTURE_UNKNOWN: UInt16 = 65535

@C
public struct SYSTEM_INFO {
    // The native Windows definition starts with an anonymous union.
    // Representing the common architecture view keeps the ABI-compatible 4-byte prefix.
    public var wProcessorArchitecture: UInt16 = 0
    public var wReserved: UInt16 = 0
    public var dwPageSize: UInt32 = 0
    public var lpMinimumApplicationAddress: CPointer<Unit> = CPointer<Unit>()
    public var lpMaximumApplicationAddress: CPointer<Unit> = CPointer<Unit>()
    public var dwActiveProcessorMask: UIntNative = 0
    public var dwNumberOfProcessors: UInt32 = 0
    public var dwProcessorType: UInt32 = 0
    public var dwAllocationGranularity: UInt32 = 0
    public var wProcessorLevel: UInt16 = 0
    public var wProcessorRevision: UInt16 = 0

    public init() {}
}

// --- Kernel32 foreign functions ---

foreign {
    // Fast native functions (short, non-blocking, no callback into Cangjie)
    @FastNative
    func GetTickCount(): UInt32
    @FastNative
    func GetLastError(): UInt32
    @FastNative
    func SetLastError(dwErrCode: UInt32): Unit
    @FastNative
    func CloseHandle(hObject: HANDLE): Int32
    @FastNative
    func GetCurrentProcess(): HANDLE
    @FastNative
    func GetCurrentThread(): HANDLE
    @FastNative
    func GetCurrentProcessId(): UInt32
    @FastNative
    func GetCurrentThreadId(): UInt32

    // Environment / system information
    func GetEnvironmentVariableW(
        lpName: CPointer<UInt16>,
        lpBuffer: CPointer<UInt16>,
        nSize: UInt32
    ): UInt32
    func SetEnvironmentVariableW(
        lpName: CPointer<UInt16>,
        lpValue: CPointer<UInt16>
    ): Int32
    func GetSystemInfo(lpSystemInfo: CPointer<SYSTEM_INFO>): Unit

    // Event / synchronization
    func CreateEventW(
        lpEventAttributes: CPointer<SECURITY_ATTRIBUTES>,
        bManualReset: Int32,
        bInitialState: Int32,
        lpName: CPointer<UInt16>
    ): HANDLE

    // File I/O
    func CreateFileW(
        lpFileName: CPointer<UInt16>,
        dwDesiredAccess: UInt32,
        dwShareMode: UInt32,
        lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>,
        dwCreationDisposition: UInt32,
        dwFlagsAndAttributes: UInt32,
        hTemplateFile: HANDLE
    ): HANDLE

    func ReadFile(
        hFile: HANDLE,
        lpBuffer: CPointer<UInt8>,
        nNumberOfBytesToRead: UInt32,
        lpNumberOfBytesRead: CPointer<UInt32>,
        lpOverlapped: CPointer<OVERLAPPED>
    ): Int32

    func WriteFile(
        hFile: HANDLE,
        lpBuffer: CPointer<UInt8>,
        nNumberOfBytesToWrite: UInt32,
        lpNumberOfBytesWritten: CPointer<UInt32>,
        lpOverlapped: CPointer<OVERLAPPED>
    ): Int32

    // Wait functions
    func WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: UInt32): UInt32
    func WaitForMultipleObjects(
        nCount: UInt32,
        lpHandles: CPointer<HANDLE>,
        bWaitAll: Int32,
        dwMilliseconds: UInt32
    ): UInt32

    // Mutex
    func CreateMutexW(
        lpMutexAttributes: CPointer<SECURITY_ATTRIBUTES>,
        bInitialOwner: Int32,
        lpName: CPointer<UInt16>
    ): HANDLE
    func ReleaseMutex(hMutex: HANDLE): Int32

    // Misc
    func Sleep(dwMilliseconds: UInt32): Unit

    // Module / library
    func GetModuleHandleW(lpModuleName: CPointer<UInt16>): HMODULE
    func GetProcAddress(hModule: HMODULE, lpProcName: CPointer<UInt8>): CPointer<Unit>
    func LoadLibraryW(lpLibFileName: CPointer<UInt16>): HMODULE
    func FreeLibrary(hLibModule: HMODULE): Int32

    // Thread
    // IMPORTANT: lpStartAddress callback must be defined with @CallingConv[STDCALL]
    func CreateThread(
        lpThreadAttributes: CPointer<SECURITY_ATTRIBUTES>,
        dwStackSize: UIntNative,
        lpStartAddress: CFunc<(CPointer<Unit>) -> UInt32>,
        lpParameter: CPointer<Unit>,
        dwCreationFlags: UInt32,
        lpThreadId: CPointer<UInt32>
    ): HANDLE
    func ExitThread(dwExitCode: UInt32): Unit

    // Virtual memory
    func VirtualAlloc(
        lpAddress: CPointer<Unit>,
        dwSize: UIntNative,
        flAllocationType: UInt32,
        flProtect: UInt32
    ): CPointer<Unit>
    func VirtualFree(
        lpAddress: CPointer<Unit>,
        dwSize: UIntNative,
        dwFreeType: UInt32
    ): Int32

    // Heap
    func HeapAlloc(hHeap: HANDLE, dwFlags: UInt32, dwBytes: UIntNative): CPointer<Unit>
    func HeapFree(hHeap: HANDLE, dwFlags: UInt32, lpMem: CPointer<Unit>): Int32
    func GetProcessHeap(): HANDLE

    // File search
    func FindFirstFileW(
        lpFileName: CPointer<UInt16>,
        lpFindFileData: CPointer<WIN32_FIND_DATAW>
    ): HANDLE
    func FindNextFileW(
        hFindFile: HANDLE,
        lpFindFileData: CPointer<WIN32_FIND_DATAW>
    ): Int32
    func FindClose(hFindFile: HANDLE): Int32

    // File operations
    func GetFileSize(hFile: HANDLE, lpFileSizeHigh: CPointer<UInt32>): UInt32
    func SetFilePointer(
        hFile: HANDLE,
        lDistanceToMove: Int32,
        lpDistanceToMoveHigh: CPointer<Int32>,
        dwMoveMethod: UInt32
    ): UInt32
    func FlushFileBuffers(hFile: HANDLE): Int32

    // Directory operations
    func CreateDirectoryW(
        lpPathName: CPointer<UInt16>,
        lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
    ): Int32
    func RemoveDirectoryW(lpPathName: CPointer<UInt16>): Int32
    func DeleteFileW(lpFileName: CPointer<UInt16>): Int32
    func MoveFileW(
        lpExistingFileName: CPointer<UInt16>,
        lpNewFileName: CPointer<UInt16>
    ): Int32

    // Temp path
    func GetTempPathW(nBufferLength: UInt32, lpBuffer: CPointer<UInt16>): UInt32

    // Performance counter
    func QueryPerformanceCounter(lpPerformanceCount: CPointer<Int64>): Int32
    func QueryPerformanceFrequency(lpFrequency: CPointer<Int64>): Int32

    // Critical section
    func InitializeCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit
    func EnterCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit
    func LeaveCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit
    func DeleteCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit
}

public func kernel32GetLastError(): UInt32 {
    unsafe { GetLastError() }
}

public func kernel32SetLastError(dwErrCode: UInt32): Unit {
    unsafe { SetLastError(dwErrCode) }
}

public func kernel32GetEnvironmentVariableW(
    lpName: CPointer<UInt16>,
    lpBuffer: CPointer<UInt16>,
    nSize: UInt32
): UInt32 {
    unsafe { GetEnvironmentVariableW(lpName, lpBuffer, nSize) }
}

public func kernel32SetEnvironmentVariableW(
    lpName: CPointer<UInt16>,
    lpValue: CPointer<UInt16>
): Int32 {
    unsafe { SetEnvironmentVariableW(lpName, lpValue) }
}

public func kernel32GetSystemInfo(lpSystemInfo: CPointer<SYSTEM_INFO>): Unit {
    unsafe { GetSystemInfo(lpSystemInfo) }
}

public func kernel32CloseHandle(hObject: HANDLE): Int32 {
    unsafe { CloseHandle(hObject) }
}

public func kernel32CreateFileW(
    lpFileName: CPointer<UInt16>,
    dwDesiredAccess: UInt32,
    dwShareMode: UInt32,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>,
    dwCreationDisposition: UInt32,
    dwFlagsAndAttributes: UInt32,
    hTemplateFile: HANDLE
): HANDLE {
    unsafe {
        CreateFileW(
            lpFileName,
            dwDesiredAccess,
            dwShareMode,
            lpSecurityAttributes,
            dwCreationDisposition,
            dwFlagsAndAttributes,
            hTemplateFile
        )
    }
}

public func kernel32GetModuleHandleW(lpModuleName: CPointer<UInt16>): HMODULE {
    unsafe { GetModuleHandleW(lpModuleName) }
}

public func kernel32LoadLibraryW(lpLibFileName: CPointer<UInt16>): HMODULE {
    unsafe { LoadLibraryW(lpLibFileName) }
}

public func kernel32CreateDirectoryW(
    lpPathName: CPointer<UInt16>,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
): Int32 {
    unsafe { CreateDirectoryW(lpPathName, lpSecurityAttributes) }
}

public func kernel32DeleteFileW(lpFileName: CPointer<UInt16>): Int32 {
    unsafe { DeleteFileW(lpFileName) }
}

public func kernel32MoveFileW(
    lpExistingFileName: CPointer<UInt16>,
    lpNewFileName: CPointer<UInt16>
): Int32 {
    unsafe { MoveFileW(lpExistingFileName, lpNewFileName) }
}

public func kernel32CreateEventW(
    lpEventAttributes: CPointer<SECURITY_ATTRIBUTES>,
    bManualReset: Int32,
    bInitialState: Int32,
    lpName: CPointer<UInt16>
): HANDLE {
    unsafe { CreateEventW(lpEventAttributes, bManualReset, bInitialState, lpName) }
}

public func kernel32CreateMutexW(
    lpMutexAttributes: CPointer<SECURITY_ATTRIBUTES>,
    bInitialOwner: Int32,
    lpName: CPointer<UInt16>
): HANDLE {
    unsafe { CreateMutexW(lpMutexAttributes, bInitialOwner, lpName) }
}

public func kernel32ReleaseMutex(hMutex: HANDLE): Int32 {
    unsafe { ReleaseMutex(hMutex) }
}

public func kernel32WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: UInt32): UInt32 {
    unsafe { WaitForSingleObject(hHandle, dwMilliseconds) }
}

public func kernel32WaitForMultipleObjects(
    nCount: UInt32,
    lpHandles: CPointer<HANDLE>,
    bWaitAll: Int32,
    dwMilliseconds: UInt32
): UInt32 {
    unsafe { WaitForMultipleObjects(nCount, lpHandles, bWaitAll, dwMilliseconds) }
}

public func kernel32Sleep(dwMilliseconds: UInt32): Unit {
    unsafe { Sleep(dwMilliseconds) }
}

public func kernel32EnterCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit {
    unsafe { EnterCriticalSection(lpCriticalSection) }
}

public func kernel32LeaveCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit {
    unsafe { LeaveCriticalSection(lpCriticalSection) }
}
