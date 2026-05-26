package windows_threading

import std.unittest.*
import std.unittest.testmacro.*
import windows_common.Win32.System.Threading as Win32Threading

class IntBox {
    var value = 0
}

@When[os == "Windows"]
@Test
func testThreadIdAndSleepAreCallable() {
    @Expect(threadId() > 0u32, true)
    sleep(0u32)
}

@When[os == "Windows"]
@Test
func testPoolScopeRunsSubmittedWorkBeforeReturning() {
    let count = IntBox()
    let pool = Pool()
    pool.scope({ scope =>
        scope.submit({ => count.value += 1 })
    })
    pool.close()

    @Expect(count.value, 1)
    @Expect(pool.isClosed(), true)
}

@Test
func testThreadingAbiTypesComeFromWindowsCommon() {
    @Expect(sizeOf<TP_CALLBACK_ENVIRON_V3>(), sizeOf<Win32Threading.TP_CALLBACK_ENVIRON_V3>())
}
