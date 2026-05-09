package windows_libloading

import std.unittest.*
import std.unittest.testmacro.*

@When[os == "Windows"]
@Test
func testLoadLibraryReportsMissingModule() {
    @Expect(testThrows({ => let _ = loadLibrary("__missing_windows_cj_module__.dll") }), true)
}

@When[os == "Windows"]
@Test
func testResolveProcByOrdinalReportsMissingOrdinal() {
    @Expect(testThrows({ => let _ = resolveProcByOrdinal("kernel32.dll", 65535) }), true)
}
