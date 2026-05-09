package windows_version

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testOsVersionComparisonAndFormatting() {
    let base = OsVersion.new(10u32, 0u32, 0u32, 19041u32)
    let newerBuild = OsVersion.new(10u32, 0u32, 0u32, 22621u32)
    let newerMajor = OsVersion.new(11u32, 0u32, 0u32, 1u32)

    @Expect(base < newerBuild, true)
    @Expect(newerMajor > newerBuild, true)
    @Expect(base == OsVersion.new(10u32, 0u32, 0u32, 19041u32), true)
    @Expect(base.toString(), "10.0.0.19041")
    @Expect(base.hashCode(), OsVersion.new(10u32, 0u32, 0u32, 19041u32).hashCode())
}

@Test
func testOsVersionInfoAbiComesFromWindowsCommon() {
    @Expect(sizeOf<OSVERSIONINFOEXW>(), UIntNative(284))
}
