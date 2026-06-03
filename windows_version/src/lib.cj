package windows_version

import windows_common.Win32.System.SystemInformation as Win32SystemInformation
import windows_registry.*
import windows_result.Result

type OSVERSIONINFOEXW = Win32SystemInformation.OSVERSIONINFOEXW

let VER_NT_WORKSTATION: UInt8 = 1u8

func readVersionInfo(): OSVERSIONINFOEXW {
    var info = OSVERSIONINFOEXW()
    info.dwOSVersionInfoSize = UInt32(sizeOf<OSVERSIONINFOEXW>())
    let _ = Win32SystemInformation.RtlGetVersion(CPointer<OSVERSIONINFOEXW>(inout info))
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
    match (LOCAL_MACHINE.open("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")) {
        case Result<Key>.Ok(key) =>
            try {
                key.getU32("UBR").unwrapOr(0u32)
            } finally {
                key.close()
            }
        case Result<Key>.Err(_) => 0u32
    }
}
