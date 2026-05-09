package windows_libloading

import std.unittest.*
import std.unittest.testmacro.*

func testThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@When[os == "Windows"]
@Test
func testLoadLibraryAndResolveProcCacheStablePointers() {
    let firstModule = loadLibrary("kernel32.dll")
    let secondModule = loadLibrary("kernel32.dll")
    let firstProc = resolveProc("kernel32.dll", "GetCurrentThreadId")
    let secondProc = resolveProc("kernel32.dll", "GetCurrentThreadId")

    @Expect(firstModule.isNotNull(), true)
    @Expect(firstModule.toUIntNative(), secondModule.toUIntNative())
    @Expect(firstProc.isNotNull(), true)
    @Expect(firstProc.toUIntNative(), secondProc.toUIntNative())
}

@When[os == "Windows"]
@Test
func testResolveProcReportsMissingSymbol() {
    @Expect(testThrows({ => let _ = resolveProc("kernel32.dll", "__missing_windows_cj_symbol__") }), true)
}
