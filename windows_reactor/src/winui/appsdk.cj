package windows_reactor.winui

import windows_core.{HRESULT, S_OK}
import windows_common.Native.AppRuntime as AppRuntime
import windows_libloading as windows_libloading

// ============================================================================
// Windows App SDK runtime initialization. Self-contained bundles load the local
// runtime DLL directly; installed framework packages use the Mdd* bootstrap.
// ============================================================================

public let WINDOWS_APPSDK_RELEASE_MAJORMINOR = UInt32(131072)
public let WINDOWS_APPSDK_RUNTIME_VERSION = UInt64(562949953486848)
public let MDD_BOOTSTRAP_INITIALIZE_OPTIONS_NONE = 0u32
public let MDD_BOOTSTRAP_INITIALIZE_OPTIONS_ON_NO_MATCH_SHOW_UI = 8u32
public let MDD_BOOTSTRAP_INITIALIZE_OPTIONS_ON_PACKAGE_IDENTITY_NOOP = 16u32
public let MDD_BOOTSTRAP_INITIALIZE_OPTIONS_DEFAULT = MDD_BOOTSTRAP_INITIALIZE_OPTIONS_ON_PACKAGE_IDENTITY_NOOP

let DEFAULT_BOOTSTRAP_DLL = "Microsoft.WindowsAppRuntime.Bootstrap.dll"
let SELF_CONTAINED_RUNTIME_DLL = "Microsoft.WindowsAppRuntime.dll"
let WINDOWS_APP_RUNTIME_ENSURE_IS_LOADED = "WindowsAppRuntime_EnsureIsLoaded"

var runtimeLoaded = false
var runtimeLoadedByBootstrap = false
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

func tryInitializeSelfContainedRuntime(): ?HRESULT {
    try {
        let address = windows_libloading.resolveProcFromSearchPath(
            SELF_CONTAINED_RUNTIME_DLL,
            WINDOWS_APP_RUNTIME_ENSURE_IS_LOADED
        )
        let ensureIsLoaded = CFunc<() -> Int32>(address)
        let raw = unsafe { ensureIsLoaded() }
        Some(HRESULT(raw))
    } catch (_: Exception) {
        None
    }
}

public func appSdkInitialize(bootstrapDllPath!: String = ""): HRESULT {
    appSdkInitializeWithVersion(
        bootstrapDllPath: bootstrapDllPath,
        majorMinorVersion: WINDOWS_APPSDK_RELEASE_MAJORMINOR,
        minVersion: WINDOWS_APPSDK_RUNTIME_VERSION
    )
}

public func appSdkInitializeWithVersion(
    bootstrapDllPath!: String = "",
    majorMinorVersion!: UInt32,
    minVersion!: UInt64
): HRESULT {
    if (runtimeLoaded) {
        return S_OK
    }

    match (tryInitializeSelfContainedRuntime()) {
        case Some(localHr) =>
            if (localHr.succeeded()) {
                runtimeLoaded = true
                runtimeLoadedByBootstrap = false
                loadedBootstrapDllPath = ""
            }
            return localHr
        case None => ()
    }

    let bootstrapHr = initializeRuntime(
        bootstrapDllPath,
        majorMinorVersion,
        [0u16],
        minVersion,
        MDD_BOOTSTRAP_INITIALIZE_OPTIONS_DEFAULT
    )
    if (bootstrapHr.succeeded()) {
        runtimeLoaded = true
        runtimeLoadedByBootstrap = true
        loadedBootstrapDllPath = bootstrapDllPath
    }
    bootstrapHr
}

public func appSdkInitializeOrThrow(bootstrapDllPath!: String = ""): Unit {
    let hr = appSdkInitialize(bootstrapDllPath: bootstrapDllPath)
    if (hr.failed()) {
        throw Exception("Windows App SDK bootstrap initialization failed: ${hr}")
    }
}

public func appSdkShutdown(): Unit {
    if (!runtimeLoaded) {
        return
    }
    if (runtimeLoadedByBootstrap) {
        shutdownRuntime(loadedBootstrapDllPath)
    }
    runtimeLoaded = false
    runtimeLoadedByBootstrap = false
    loadedBootstrapDllPath = ""
}

public func appSdkIsRuntimeLoaded(): Bool {
    runtimeLoaded
}
