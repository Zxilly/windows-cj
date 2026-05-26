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

@When[os == "Windows"]
@Test
func testFinalizerSafeProcUsesExplicitPreResolveStep() {
    let proc = FinalizerSafeProc("kernel32.dll", "GetCurrentThreadId")

    @Expect(proc.rawIfResolvedForFinalizer().isNull(), true)

    let resolved = proc.ensureResolved()
    let cached = proc.rawIfResolvedForFinalizer()
    let ordinary = resolveProc("kernel32.dll", "GetCurrentThreadId")

    @Expect(resolved.isNotNull(), true)
    @Expect(cached.toUIntNative(), resolved.toUIntNative())
    @Expect(cached.toUIntNative(), ordinary.toUIntNative())
    @Expect(proc.ensureResolved().toUIntNative(), resolved.toUIntNative())
}

@When[os == "Windows"]
@Test
func testFinalizerSafeProcMissDoesNotPublishRawPointer() {
    let proc = FinalizerSafeProc("kernel32.dll", "__missing_windows_cj_symbol__")

    @Expect(testThrows({ => let _ = proc.ensureResolved() }), true)
    @Expect(proc.rawIfResolvedForFinalizer().isNull(), true)
}
