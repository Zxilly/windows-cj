package windows_services

import std.unittest.*
import std.unittest.testmacro.*

class CommandProbe {
    var startCount = 0
    var stopCount = 0
    var pauseCount = 0
    var resumeCount = 0
    var extendedCount = 0
    var extendedControl = 0u32
    var extendedType = 0u32
    var extendedData: CPointer<Unit> = CPointer<Unit>()
}

func recordCommand(probe: CommandProbe, command: Command): Unit {
    match (command) {
        case Command.Start => probe.startCount += 1
        case Command.Stop => probe.stopCount += 1
        case Command.Pause => probe.pauseCount += 1
        case Command.Resume => probe.resumeCount += 1
        case Command.Extended(value) =>
            probe.extendedCount += 1
            probe.extendedControl = value.control
            probe.extendedType = value.ty
            probe.extendedData = value.data
    }
}

@Test
func testServiceHandlerStateTransitionsAndIgnoredPauseResume() {
    let service = Service.new()
    let probe = CommandProbe()
    let runResult = service.canFallback({ _ => () }).run({ _, command => recordCommand(probe, command) })

    @Expect(runResult.isOk(), true)
    @Expect(probe.startCount, 1)
    @Expect(probe.stopCount, 1)
    @Expect(service.state() == State.Stopped, true)

    let pauseWhileStopped = service.handler(2u32, 0u32, CPointer<Unit>())
    @Expect(pauseWhileStopped, 0u32)
    @Expect(probe.pauseCount, 0)
    @Expect(probe.extendedCount, 1)
    @Expect(probe.extendedControl, 2u32)

    service.setState(State.Running)
    @Expect(service.handler(2u32, 0u32, CPointer<Unit>()), 0u32)
    @Expect(probe.pauseCount, 1)
    @Expect(service.state() == State.Paused, true)

    @Expect(service.handler(3u32, 0u32, CPointer<Unit>()), 0u32)
    @Expect(probe.resumeCount, 1)
    @Expect(service.state() == State.Running, true)
}

@Test
func testServiceExtendedCommandPreservesEventPayload() {
    let service = Service.new()
    let probe = CommandProbe()
    let payload = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x1234) }
    let runResult = service.canFallback({ _ => () }).run({ _, command => recordCommand(probe, command) })

    @Expect(runResult.isOk(), true)
    @Expect(service.handler(128u32, 99u32, payload), 0u32)
    @Expect(probe.extendedCount, 1)
    @Expect(probe.extendedControl, 128u32)
    @Expect(probe.extendedType, 99u32)
    @Expect(probe.extendedData.toUIntNative(), payload.toUIntNative())
}
