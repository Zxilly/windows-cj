package windows_winui3.appsdk

import windows_core.{HRESULT, S_OK}
import windows_common.Native.AppRuntime as AppRuntime

public let WINDOWS_APPSDK_RELEASE_MAJORMINOR = UInt32(65544)
public let WINDOWS_APPSDK_RUNTIME_VERSION = UInt64(2251803404419006464)
public let MDD_BOOTSTRAP_INITIALIZE_OPTIONS_NONE = 0u32

let DEFAULT_BOOTSTRAP_DLL = "Microsoft.WindowsAppRuntime.Bootstrap.dll"

var runtimeLoaded = false
var loadedBootstrapDllPath = ""

func bootstrapDllPath(path: String): String {
    if (path.isEmpty()) {
        return DEFAULT_BOOTSTRAP_DLL
    }
    path
}

func initializeRuntime(
    path: String,
    majorMinorVersion: UInt32,
    versionTag: Array<UInt16>,
    minVersion: UInt64,
    options: UInt32
): HRESULT {
    let raw = unsafe {
        let versionTagHandle = acquireArrayRawData(versionTag)
        try {
            AppRuntime.MddBootstrapInitialize2(
                bootstrapDllPath(path),
                majorMinorVersion,
                versionTagHandle.pointer,
                minVersion,
                options
            )
        } finally {
            releaseArrayRawData(versionTagHandle)
        }
    }
    HRESULT(raw)
}

func shutdownRuntime(path: String): Unit {
    AppRuntime.MddBootstrapShutdown(bootstrapDllPath(path))
}

public func initialize(bootstrapDllPath!: String = ""): HRESULT {
    if (runtimeLoaded) {
        return S_OK
    }
    let hr = initializeRuntime(
        bootstrapDllPath,
        WINDOWS_APPSDK_RELEASE_MAJORMINOR,
        [0u16],
        WINDOWS_APPSDK_RUNTIME_VERSION,
        MDD_BOOTSTRAP_INITIALIZE_OPTIONS_NONE
    )
    if (hr.succeeded()) {
        runtimeLoaded = true
        loadedBootstrapDllPath = bootstrapDllPath
    }
    hr
}

public func initializeOrThrow(bootstrapDllPath!: String = ""): Unit {
    let hr = initialize(bootstrapDllPath: bootstrapDllPath)
    if (hr.failed()) {
        throw Exception("Windows App SDK bootstrap initialization failed: ${hr}")
    }
}

public func shutdown(): Unit {
    if (!runtimeLoaded) {
        return
    }
    shutdownRuntime(loadedBootstrapDllPath)
    runtimeLoaded = false
    loadedBootstrapDllPath = ""
}

public func isRuntimeLoaded(): Bool {
    runtimeLoaded
}
