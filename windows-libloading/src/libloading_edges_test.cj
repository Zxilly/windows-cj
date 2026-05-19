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

@Test
func testResolveProcByOrdinalRejectsValuesOutsideOrdinalRange() {
    @Expect(testThrows({ => let _ = resolveProcByOrdinal("kernel32.dll", -1) }), true)
    @Expect(testThrows({ => let _ = resolveProcByOrdinal("kernel32.dll", 65536) }), true)
}

@Test
func testUncachedByteInputsMustBeNullTerminatedBeforeFfi() {
    @Expect(testThrows({ => let _ = loadSystemLibraryUncached([0x6Bu8]) }), true)
    @Expect(testThrows({ => let _ = loadLibraryUncached([0x6Bu8]) }), true)
    @Expect(testThrows({ => let _ = resolveProcUncached(CPointer<Unit>(), [0x47u8]) }), true)
}

@When[os == "Windows"]
@Test
func testUncachedLoadResolveAndFreeLibrary() {
    let module = loadSystemLibraryUncached(nullTerminatedUtf8("kernel32.dll"))
    let proc = resolveProcUncached(module, nullTerminatedUtf8("GetCurrentThreadId"))
    let freed = freeLibrary(module)

    @Expect(module.isNotNull(), true)
    @Expect(proc.isNotNull(), true)
    @Expect(freed != 0, true)
}

@When[os == "Windows"]
@Test
func testSearchPathResolveProcUsesExplicitApi() {
    let proc = resolveProcFromSearchPath("kernel32.dll", "GetCurrentThreadId")
    let moduleKey = searchPathModuleKey("kernel32.dll")
    let symbolKey = "${moduleKey}\nGetCurrentThreadId"

    @Expect(proc.isNotNull(), true)
    @Expect(libraryCache.contains(moduleKey), true)
    @Expect(symbolCache.contains(symbolKey), true)
}

@Test
func testSearchPathLoadFlagsPreserveAbsoluteDllDirectory() {
    @Expect(
        searchPathLoadFlags("C:\\Program Files\\WindowsAppSDK\\bootstrap.dll"),
        LOAD_LIBRARY_SEARCH_DEFAULT_DIRS + LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR
    )
    @Expect(
        searchPathLoadFlags("\\\\server\\share\\bootstrap.dll"),
        LOAD_LIBRARY_SEARCH_DEFAULT_DIRS + LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR
    )
    @Expect(searchPathLoadFlags("kernel32.dll"), LOAD_LIBRARY_SEARCH_DEFAULT_DIRS)
}

@Test
func testSystemLoadsRejectPathLikeModuleNames() {
    @Expect(testThrows({ => let _ = systemModuleKey("C:\\Temp\\kernel32.dll") }), true)
    @Expect(testThrows({ => let _ = systemModuleKey("\\\\server\\share\\kernel32.dll") }), true)
    @Expect(testThrows({ => let _ = systemModuleKey("dir/kernel32.dll") }), true)
    @Expect(testThrows({ => let _ = loadSystemLibraryUncached(nullTerminatedUtf8("C:\\Temp\\kernel32.dll")) }), true)
    @Expect(searchPathModuleKey("C:\\Temp\\kernel32.dll"), "search:c:\\temp\\kernel32.dll")
}

@Test
func testModuleCacheKeysNormalizeAsciiCaseOnly() {
    @Expect(canonicalModuleName("KERNEL32.dll"), "kernel32.dll")
    @Expect(canonicalModuleName("OLEAUT32.dll"), "oleaut32.dll")
    @Expect(canonicalModuleName("api-ms-win-core-handle-l1-1-0.dll"), "api-ms-win-core-handle-l1-1-0.dll")
}
