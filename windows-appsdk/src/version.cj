package windows_appsdk

public let WINDOWS_APPSDK_BOOTSTRAP_DLL = "Microsoft.WindowsAppRuntime.Bootstrap.dll"
public let WINDOWS_APPSDK_RELEASE_MAJORMINOR = UInt32(65544)
public let WINDOWS_APPSDK_RELEASE_VERSION_TAG = ""
public let WINDOWS_APPSDK_RELEASE_VERSION_TAG_WIDE: Array<UInt16> = [0u16]
public let WINDOWS_APPSDK_RUNTIME_VERSION = UInt64(2251803404419006464)
public let WINDOWS_APPSDK_RUNTIME_VERSION_STRING = "8000.836.2153.0"
public let MDD_BOOTSTRAP_INITIALIZE_OPTIONS_NONE = 0u32

public func packageVersion(major: UInt16, minor: UInt16, build: UInt16, revision: UInt16): UInt64 {
    (UInt64(major) << 48u64) |
        (UInt64(minor) << 32u64) |
        (UInt64(build) << 16u64) |
        UInt64(revision)
}
