package windows_reactor.winui

import windows_core.HRESULT
import windows_sys.Win32.System.Com as Win32Com
import windows_libloading as windows_libloading

// ============================================================================
// Process startup primitives: STA apartment init, per-monitor DPI awareness,
// and cwd fixup. Behaviour-equivalent to the runtime-only WinUI support code.
// ============================================================================

public let COINIT_APARTMENTTHREADED: Int32 = 2
let DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2: IntNative = IntNative(-4)
let MAX_MODULE_PATH: Int64 = 32768
let WINDOWS_APP_RUNTIME_BASE_DIRECTORY_ENV = "MICROSOFT_WINDOWSAPPRUNTIME_BASE_DIRECTORY"
let WINDOWS_APP_RUNTIME_DLL = "Microsoft.WindowsAppRuntime.dll"
let APPLICATION_MANIFEST = "main.exe.manifest"
let INVALID_FILE_ATTRIBUTES: UInt32 = 0xFFFFFFFFu32

@C
struct ACTCTXW {
    public var cbSize: UInt32 = 0u32
    public var dwFlags: UInt32 = 0u32
    public var lpSource: CPointer<UInt16> = CPointer<UInt16>()
    public var wProcessorArchitecture: UInt16 = 0u16
    public var wLangId: UInt16 = 0u16
    public var lpAssemblyDirectory: CPointer<UInt16> = CPointer<UInt16>()
    public var lpResourceName: CPointer<UInt16> = CPointer<UInt16>()
    public var lpApplicationName: CPointer<UInt16> = CPointer<UInt16>()
    public var hModule: CPointer<Unit> = CPointer<Unit>()
    public init() {}
}

var applicationActivationContext: CPointer<Unit> = CPointer<Unit>()

public func CoInitializeEx(coInit: Int32): HRESULT {
    HRESULT(Win32Com.CoInitializeEx(coInit))
}

public func CoUninitialize(): Unit {
    Win32Com.CoUninitialize()
}

public func initializeApartmentThreaded(): HRESULT {
    CoInitializeEx(COINIT_APARTMENTTHREADED)
}

public func uninitializeApartment(): Unit {
    CoUninitialize()
}

public func setProcessDpiAwarenessPerMonitorV2(): Bool {
    let setProcessDpiAwarenessContext = CFunc<(IntNative) -> Int32>(
        windows_libloading.resolveProc("user32.dll", "SetProcessDpiAwarenessContext")
    )
    unsafe { setProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) != 0 }
}

public func setCurrentDirectoryToExecutableDirectory(): Bool {
    let getModuleFileNameW = CFunc<(CPointer<Unit>, CPointer<UInt16>, UInt32) -> UInt32>(
        windows_libloading.resolveProc("kernel32.dll", "GetModuleFileNameW")
    )
    let getCurrentDirectoryW = CFunc<(UInt32, CPointer<UInt16>) -> UInt32>(
        windows_libloading.resolveProc("kernel32.dll", "GetCurrentDirectoryW")
    )
    let setCurrentDirectoryW = CFunc<(CPointer<UInt16>) -> Int32>(
        windows_libloading.resolveProc("kernel32.dll", "SetCurrentDirectoryW")
    )
    let setDllDirectoryW = CFunc<(CPointer<UInt16>) -> Int32>(
        windows_libloading.resolveProc("kernel32.dll", "SetDllDirectoryW")
    )
    let addDllDirectory = CFunc<(CPointer<UInt16>) -> CPointer<Unit>>(
        windows_libloading.resolveProc("kernel32.dll", "AddDllDirectory")
    )
    let setEnvironmentVariableW = CFunc<(CPointer<UInt16>, CPointer<UInt16>) -> Int32>(
        windows_libloading.resolveProc("kernel32.dll", "SetEnvironmentVariableW")
    )

    let buffer = Array<UInt16>(MAX_MODULE_PATH, { _ => 0u16 })
    let baseDirectoryEnvName = nullTerminatedUtf16Ascii(WINDOWS_APP_RUNTIME_BASE_DIRECTORY_ENV)
    unsafe {
        let bufferHandle = acquireArrayRawData(buffer)
        try {
            let envNameHandle = acquireArrayRawData(baseDirectoryEnvName)
            try {
                let directoryReady = if (currentDirectoryHasRuntimeDll()) {
                    loadCurrentDirectoryIntoBuffer(getCurrentDirectoryW, bufferHandle.pointer)
                } else {
                    loadExecutableDirectoryIntoBuffer(getModuleFileNameW, bufferHandle.pointer)
                }
                if (!directoryReady) {
                    return false
                }

                let currentDirectorySet = setCurrentDirectoryW(bufferHandle.pointer) != 0
                let dllDirectorySet = setDllDirectoryW(bufferHandle.pointer) != 0
                let directoryCookie = addDllDirectory(bufferHandle.pointer)
                let baseDirectorySet = setEnvironmentVariableW(envNameHandle.pointer, bufferHandle.pointer) != 0
                let manifestActivated = activateApplicationManifestForCurrentThread()
                return currentDirectorySet && dllDirectorySet && directoryCookie.isNotNull() && baseDirectorySet && manifestActivated
            } finally {
                releaseArrayRawData(envNameHandle)
            }
        } finally {
            releaseArrayRawData(bufferHandle)
        }
    }
}

func currentDirectoryHasRuntimeDll(): Bool {
    fileExistsAscii(WINDOWS_APP_RUNTIME_DLL)
}

func fileExistsAscii(fileName: String): Bool {
    let getFileAttributesW = CFunc<(CPointer<UInt16>) -> UInt32>(
        windows_libloading.resolveProc("kernel32.dll", "GetFileAttributesW")
    )
    let wideName = nullTerminatedUtf16Ascii(fileName)
    unsafe {
        let wideNameHandle = acquireArrayRawData(wideName)
        try {
            getFileAttributesW(wideNameHandle.pointer) != INVALID_FILE_ATTRIBUTES
        } finally {
            releaseArrayRawData(wideNameHandle)
        }
    }
}

public func activateApplicationManifestForCurrentThread(): Bool {
    if (!fileExistsAscii(APPLICATION_MANIFEST)) {
        return true
    }

    let activateActCtx = CFunc<(CPointer<Unit>, CPointer<UIntNative>) -> Int32>(
        windows_libloading.resolveProc("kernel32.dll", "ActivateActCtx")
    )
    if (applicationActivationContext.isNull() && !createApplicationActivationContext()) {
        return false
    }

    var cookie: UIntNative = 0
    unsafe { activateActCtx(applicationActivationContext, CPointer<UIntNative>(inout cookie)) != 0 }
}

func createApplicationActivationContext(): Bool {
    let createActCtxW = CFunc<(CPointer<ACTCTXW>) -> CPointer<Unit>>(
        windows_libloading.resolveProc("kernel32.dll", "CreateActCtxW")
    )
    let activateActCtx = CFunc<(CPointer<Unit>, CPointer<UIntNative>) -> Int32>(
        windows_libloading.resolveProc("kernel32.dll", "ActivateActCtx")
    )
    let manifestPath = nullTerminatedUtf16Ascii(APPLICATION_MANIFEST)
    unsafe {
        let manifestPathHandle = acquireArrayRawData(manifestPath)
        try {
            var actctx = ACTCTXW()
            actctx.cbSize = UInt32(sizeOf<ACTCTXW>())
            actctx.lpSource = manifestPathHandle.pointer
            let handle = createActCtxW(CPointer<ACTCTXW>(inout actctx))
            if (handle.isNull()) {
                return false
            }

            var cookie: UIntNative = 0
            if (activateActCtx(handle, CPointer<UIntNative>(inout cookie)) == 0) {
                return false
            }
            applicationActivationContext = handle
            return true
        } finally {
            releaseArrayRawData(manifestPathHandle)
        }
    }
}

func loadCurrentDirectoryIntoBuffer(
    getCurrentDirectoryW: CFunc<(UInt32, CPointer<UInt16>) -> UInt32>,
    buffer: CPointer<UInt16>
): Bool {
    let written = unsafe { getCurrentDirectoryW(UInt32(MAX_MODULE_PATH), buffer) }
    if (written == 0u32 || written >= UInt32(MAX_MODULE_PATH - 1)) {
        return false
    }
    ensureTrailingSlash(buffer, Int64(written))
}

func loadExecutableDirectoryIntoBuffer(
    getModuleFileNameW: CFunc<(CPointer<Unit>, CPointer<UInt16>, UInt32) -> UInt32>,
    buffer: CPointer<UInt16>
): Bool {
    let written = unsafe { getModuleFileNameW(CPointer<Unit>(), buffer, UInt32(MAX_MODULE_PATH)) }
    if (written == 0u32) {
        return false
    }

    var length = Int64(written)
    if (length >= MAX_MODULE_PATH) {
        length = MAX_MODULE_PATH - 1
    }

    var lastSeparator: Int64 = -1
    var index: Int64 = 0
    while (index < length) {
        let codeUnit = unsafe { (buffer + index).read() }
        if (codeUnit == 92u16 || codeUnit == 47u16) {
            lastSeparator = index
        }
        index += 1
    }
    if (lastSeparator < 0) {
        return false
    }

    let terminator = lastSeparator + 1
    unsafe { (buffer + terminator).write(0u16) }
    true
}

func ensureTrailingSlash(buffer: CPointer<UInt16>, length: Int64): Bool {
    if (length <= 0 || length >= MAX_MODULE_PATH - 1) {
        return false
    }
    let last = unsafe { (buffer + length - 1).read() }
    if (last == 92u16 || last == 47u16) {
        unsafe { (buffer + length).write(0u16) }
        return true
    }
    unsafe {
        (buffer + length).write(92u16)
        (buffer + length + 1).write(0u16)
    }
    true
}

func nullTerminatedUtf16Ascii(value: String): Array<UInt16> {
    let bytes = value.toArray()
    let length = Int64(bytes.size)
    Array<UInt16>(length + 1, { index =>
        if (index < length) {
            UInt16(bytes[index])
        } else {
            0u16
        }
    })
}
