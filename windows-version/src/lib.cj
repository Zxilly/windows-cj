package windows_version

let HKEY_LOCAL_MACHINE: CPointer<Unit> = unsafe { CPointer<Unit>(CPointer<UInt8>() + -2147483646) }
let RRF_RT_REG_DWORD: UInt32 = 16u32
let VER_NT_WORKSTATION: UInt8 = 1u8

@C
struct OSVERSIONINFOEXW {
    var dwOSVersionInfoSize: UInt32 = 0u32
    var dwMajorVersion: UInt32 = 0u32
    var dwMinorVersion: UInt32 = 0u32
    var dwBuildNumber: UInt32 = 0u32
    var dwPlatformId: UInt32 = 0u32
    var szCSDVersion: VArray<UInt16, $128> = VArray<UInt16, $128>(repeat: 0u16)
    var wServicePackMajor: UInt16 = 0u16
    var wServicePackMinor: UInt16 = 0u16
    var wSuiteMask: UInt16 = 0u16
    var wProductType: UInt8 = 0u8
    var wReserved: UInt8 = 0u8
}

foreign {
    func RtlGetVersion(lpVersionInformation: CPointer<OSVERSIONINFOEXW>): Int32
    func RegGetValueA(
        hkey: CPointer<Unit>,
        lpsubkey: CString,
        lpvalue: CString,
        dwflags: UInt32,
        pdwtype: CPointer<UInt32>,
        pvdata: CPointer<UInt32>,
        pcbdata: CPointer<UInt32>
    ): UInt32
}

func readVersionInfo(): OSVERSIONINFOEXW {
    var info = OSVERSIONINFOEXW()
    info.dwOSVersionInfoSize = UInt32(sizeOf<OSVERSIONINFOEXW>())
    unsafe {
        let _ = RtlGetVersion(inout info)
    }
    info
}

public struct OsVersion <: ToString & Hashable {
    public OsVersion(let major: UInt32, let minor: UInt32, let pack: UInt32, let build: UInt32) {}

    public static func new(major: UInt32, minor: UInt32, pack: UInt32, build: UInt32): OsVersion {
        OsVersion(major, minor, pack, build)
    }

    public static func current(): OsVersion {
        let info = readVersionInfo()
        OsVersion(info.dwMajorVersion, info.dwMinorVersion, UInt32(info.wServicePackMajor), info.dwBuildNumber)
    }

    public func compare(other: OsVersion): Int32 {
        if (major != other.major) { return if (major < other.major) { -1i32 } else { 1i32 } }
        if (minor != other.minor) { return if (minor < other.minor) { -1i32 } else { 1i32 } }
        if (pack != other.pack) { return if (pack < other.pack) { -1i32 } else { 1i32 } }
        if (build != other.build) { return if (build < other.build) { -1i32 } else { 1i32 } }
        0i32
    }

    public operator func ==(other: OsVersion): Bool { compare(other) == 0i32 }
    public operator func !=(other: OsVersion): Bool { compare(other) != 0i32 }
    public operator func <(other: OsVersion): Bool { compare(other) < 0i32 }
    public operator func <=(other: OsVersion): Bool { compare(other) <= 0i32 }
    public operator func >(other: OsVersion): Bool { compare(other) > 0i32 }
    public operator func >=(other: OsVersion): Bool { compare(other) >= 0i32 }

    public func hashCode(): Int64 {
        let seed = ((major.hashCode() * 397) + minor.hashCode()) * 397
        ((seed + pack.hashCode()) * 397) + build.hashCode()
    }

    public func toString(): String {
        "${major}.${minor}.${pack}.${build}"
    }
}

public func is_server(): Bool {
    readVersionInfo().wProductType != VER_NT_WORKSTATION
}

public func revision(): UInt32 {
    let subKey = unsafe { LibC.mallocCString("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion") }
    let valueName = unsafe { LibC.mallocCString("UBR") }
    var value = 0u32
    var length = UInt32(sizeOf<UInt32>())
    try (subKeyResource = subKey.asResource()) {
        try (valueNameResource = valueName.asResource()) {
            let status = unsafe {
                RegGetValueA(
                    HKEY_LOCAL_MACHINE,
                    subKeyResource.value,
                    valueNameResource.value,
                    RRF_RT_REG_DWORD,
                    CPointer<UInt32>(),
                    inout value,
                    inout length
                )
            }
            if (status == 0u32 && length == UInt32(sizeOf<UInt32>())) {
                return value
            }
        }
    }
    0u32
}
