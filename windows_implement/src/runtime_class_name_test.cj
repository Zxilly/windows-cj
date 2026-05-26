package windows_implement

import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*
import windows_result.E_FAIL
import windows_strings.*

class RuntimeClassNameDummy {}

@When[os == "Windows"]
@Test
func testGetRuntimeClassNamePublishesSystemHStringHandle() {
    let runtime = ComObjectRuntime<RuntimeClassNameDummy>(
        RuntimeClassNameDummy(),
        [IID_IINSPECTABLE],
        resolveSupportedIids([IID_IINSPECTABLE])
    )
    runtime.setRuntimeType(RuntimeTypeContract("Fixture.RuntimeClass", "Fixture.RuntimeClass"))

    var raw = CPointer<Unit>()
    let hr = runtime.getRuntimeClassNameBase(CPointer<CPointer<Unit>>(inout raw))
    @Expect(hr, S_OK)
    @Expect(raw.isNotNull(), true)

    let projected = HString.fromSystemHandleTake(raw)
    @Expect(projected.get(), "Fixture.RuntimeClass")
    projected.close()

    runtime.setRuntimeType(RuntimeTypeContract("", ""))
}

@When[os == "Windows"]
@Test
func testFailedRuntimeClassNameSlotReleasesPartialSystemHandle() {
    let source = HString("implement-partial-runtime-class")
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    var raw = source.toSystemHandleCopy()

    let hr = releaseFailedRuntimeClassNameSlot(E_FAIL.value, CPointer<CPointer<Unit>>(inout raw))

    @Expect(hr, E_FAIL.value)
    @Expect(raw.isNull(), true)
    @Expect(debugObservedWindowsDeleteStringCount() - deleteBefore, 1)
    source.close()
}

@Test
func testGetTrustLevelPublishesConfiguredValue() {
    let runtime = ComObjectRuntime<RuntimeClassNameDummy>(
        RuntimeClassNameDummy(),
        [IID_IINSPECTABLE],
        resolveSupportedIids([IID_IINSPECTABLE])
    )
    runtime.setTrustLevel(2i32)
    var value = 0i32

    let hr = runtime.getTrustLevelBase(CPointer<Int32>(inout value))

    @Expect(hr, S_OK)
    @Expect(value, 2i32)
}
