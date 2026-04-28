package windows_appsdk

import std.sync.*
import windows_core.{E_FAIL, HRESULT, Result, WinError}
import windows_libloading

let runtimeMutex = Mutex()
var runtimeLoaded = false
var loadedBootstrapDllPath = ""

func bootstrapDllName(bootstrapDllPath: String): String {
    if (bootstrapDllPath.isEmpty()) {
        WINDOWS_APPSDK_BOOTSTRAP_DLL
    } else {
        bootstrapDllPath
    }
}

func runtimeFailure(message: String): WinError {
    WinError(E_FAIL, message)
}

func initializeRuntime(
    bootstrapDllPath: String,
    majorMinorVersion: UInt32,
    versionTag: Array<UInt16>,
    minVersion: UInt64,
    options: UInt32
): HRESULT {
    let proc = windows_libloading.resolveProc(bootstrapDllName(bootstrapDllPath), "MddBootstrapInitialize2")
    let call = CFunc<(UInt32, CPointer<UInt16>, UInt64, UInt32) -> Int32>(proc)
    let raw = unsafe {
        let versionTagHandle = acquireArrayRawData(versionTag)
        try {
            call(majorMinorVersion, versionTagHandle.pointer, minVersion, options)
        } finally {
            releaseArrayRawData(versionTagHandle)
        }
    }
    HRESULT(raw)
}

func shutdownRuntime(): Unit {
    let proc = windows_libloading.resolveProc(bootstrapDllName(loadedBootstrapDllPath), "MddBootstrapShutdown")
    let call = CFunc<() -> Unit>(proc)
    unsafe { call() }
}

func initializeWithVersion(
    bootstrapDllPath: String,
    majorMinorVersion: UInt32,
    versionTag: Array<UInt16>,
    minVersion: UInt64,
    options: UInt32
): Result<Unit> {
    synchronized(runtimeMutex) {
        if (runtimeLoaded) {
            return Result<Unit>.Ok(())
        }

        try {
            let hr = initializeRuntime(bootstrapDllPath, majorMinorVersion, versionTag, minVersion, options)
            match (hr.ok()) {
                case Result<Unit>.Ok(_) =>
                    runtimeLoaded = true
                    loadedBootstrapDllPath = bootstrapDllPath
                    return Result<Unit>.Ok(())
                case Result<Unit>.Err(error) =>
                    return Result<Unit>.Err(error)
            }
        } catch (e: Exception) {
            return Result<Unit>.Err(runtimeFailure("Windows App SDK bootstrap initialization failed: ${e.message}"))
        }
    }
}

public func initialize(bootstrapDllPath!: String = ""): Result<Unit> {
    initializeWithVersion(
        bootstrapDllPath,
        WINDOWS_APPSDK_RELEASE_MAJORMINOR,
        WINDOWS_APPSDK_RELEASE_VERSION_TAG_WIDE,
        WINDOWS_APPSDK_RUNTIME_VERSION,
        MDD_BOOTSTRAP_INITIALIZE_OPTIONS_NONE
    )
}

public func shutdown(): Unit {
    synchronized(runtimeMutex) {
        if (!runtimeLoaded) {
            return
        }

        shutdownRuntime()
        runtimeLoaded = false
        loadedBootstrapDllPath = ""
    }
}

public func isRuntimeLoaded(): Bool {
    synchronized(runtimeMutex) {
        runtimeLoaded
    }
}
