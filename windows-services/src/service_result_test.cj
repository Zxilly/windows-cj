package windows_services

import std.unittest.*
import std.unittest.testmacro.*
import windows_common.Win32.System.Services as Win32Services

class BoolBox {
    var value = false
}

func serviceTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@Test
func testServiceResultAndStateHelpers() {
    let ok = ServiceResult<Int64>.Ok(42)
    let err = ServiceResult<Int64>.Err("failed")

    @Expect(ok.isOk(), true)
    @Expect(ok.unwrap(), 42)
    @Expect(err.isErr(), true)
    @Expect(serviceTestThrows({ => let _ = err.unwrap() }), true)
    @Expect(State.Running == State.Running, true)
    @Expect(State.Running != State.Stopped, true)
}

@Test
func testServiceStateAndFallbackPath() {
    let fallbackRan = BoolBox()
    let service = Service.new().canStop().canPause().canFallback({ _ => fallbackRan.value = true })

    @Expect(service.state() == State.Stopped, true)
    service.setState(State.Running)
    @Expect(service.state() == State.Running, true)

    let result = service.run({ _, _ => () })
    @Expect(result.isOk(), true)
    @Expect(fallbackRan.value, true)
    @Expect(service.state() == State.Stopped, true)
}

@Test
func testServiceAbiTypesComeFromWindowsCommon() {
    @Expect(sizeOf<SERVICE_STATUS>(), sizeOf<Win32Services.SERVICE_STATUS>())
    @Expect(sizeOf<SERVICE_TABLE_ENTRYW>(), sizeOf<Win32Services.SERVICE_TABLE_ENTRYW>())
}

@When[os == "Windows"]
@Test
func testServiceRunWithoutFallbackReportsDispatcherFailureSmoke() {
    let service = Service.new()
    let result = service.run({ _, _ => () })

    @Expect(result.isErr(), true)
}
