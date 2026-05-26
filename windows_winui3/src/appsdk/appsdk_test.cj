package windows_winui3.appsdk

import std.unittest.*
import std.unittest.testmacro.*

func appsdkTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@Test
func testBootstrapDllPathDefaultsAndShutdownIsIdempotent() {
    shutdown()

    @Expect(isRuntimeLoaded(), false)
    @Expect(bootstrapDllPath(""), DEFAULT_BOOTSTRAP_DLL)
    @Expect(bootstrapDllPath("C:\\missing\\bootstrap.dll"), "C:\\missing\\bootstrap.dll")

    shutdown()
    @Expect(isRuntimeLoaded(), false)
}

@When[os == "Windows"]
@Test
func testInitializeWithMissingBootstrapDllDoesNotMarkRuntimeLoaded() {
    shutdown()

    @Expect(appsdkTestThrows({ => let _ = initialize(bootstrapDllPath: "Z:\\windows-cj-missing\\bootstrap.dll") }), true)
    @Expect(isRuntimeLoaded(), false)
}
