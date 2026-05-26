package windows_foundation

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.InParam
import windows_interface.IInspectable

class EventHandlerNullObservation {
    public var sawNullSender = false
    public var intValue = 0i32

    public init() {}
}

@Test
func testEventHandlerInvokeAcceptsEmptySenderInParam() {
    let observed = EventHandlerNullObservation()
    let handler = EventHandler<Int32>.new({ sender: InParam<IInspectable>, args: Int32 =>
        observed.sawNullSender = sender.isNull()
        observed.intValue = args
    })

    unsafe { handler.Invoke(InParam<IInspectable>(), 123i32) }

    @Expect(observed.sawNullSender, true)
    @Expect(observed.intValue, 123i32)

    handler.close()
}
