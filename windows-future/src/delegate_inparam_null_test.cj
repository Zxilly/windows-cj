package windows_future

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, InParam, S_OK, WindowsException}
import windows_interface.{IAgileObject, IInspectable, IMarshal}

class DelegateNullObservation {
    public var sawNullInfo = false
    public var status = AsyncStatus_Started
    public var intValue = 0i32

    public init() {}
}

func delegateAsIInspectableThrows(handler: AsyncActionCompletedHandler): Bool {
    try {
        let inspectable = handler.asIInspectable()
        inspectable.close()
    } catch (_: Exception) {
        return true
    }
    false
}

@Test
func testDelegateThunkMapsThrownWindowsExceptionToHRESULT() {
    let handler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        let _ = info
        let _ = status
        throw WindowsException(E_FAIL)
    })

    let vtbl = unsafe { handler.vtbl() }
    let hr = unsafe { vtbl.Invoke(handler.asRaw(), CPointer<Unit>(), AsyncStatus.projectAbi(AsyncStatus_Completed)) }

    @Expect(hr, E_FAIL.value)

    handler.close()
}

@Test
func testDelegateThunkMapsPlainExceptionToEFail() {
    let handler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        let _ = info
        let _ = status
        throw Exception("delegate failure")
    })

    let vtbl = unsafe { handler.vtbl() }
    let hr = unsafe { vtbl.Invoke(handler.asRaw(), CPointer<Unit>(), AsyncStatus.projectAbi(AsyncStatus_Completed)) }

    @Expect(hr, E_FAIL.value)

    handler.close()
}

@Test
func testAsyncActionCompletedHandlerNullInfoProjectsToEmptyInParam() {
    let observed = DelegateNullObservation()
    let handler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        observed.sawNullInfo = info.isNull()
        observed.status = status
    })

    let vtbl = unsafe { handler.vtbl() }
    let hr = unsafe { vtbl.Invoke(handler.asRaw(), CPointer<Unit>(), AsyncStatus.projectAbi(AsyncStatus_Completed)) }

    @Expect(hr, S_OK.value)
    @Expect(observed.sawNullInfo, true)
    @Expect(observed.status == AsyncStatus_Completed, true)

    handler.close()
}

@Test
func testAsyncActionCompletedHandlerInvokeAcceptsEmptyInfoInParam() {
    let observed = DelegateNullObservation()
    let handler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        observed.sawNullInfo = info.isNull()
        observed.status = status
    })

    unsafe { handler.Invoke(InParam<IAsyncAction>(), AsyncStatus_Completed) }

    @Expect(observed.sawNullInfo, true)
    @Expect(observed.status == AsyncStatus_Completed, true)

    handler.close()
}

@Test
func testDelegateBoxKeepsAgileInterfacesWithIUnknownBase() {
    let handler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        ()
    })

    let agile = unsafe { handler.query(IAgileObject.descriptor()) }
    @Expect(agile.isSome(), true)
    if (let Some(value) <- agile) {
        value.close()
    }

    let marshaler = unsafe { handler.query(IMarshal.descriptor()) }
    @Expect(marshaler.isSome(), true)
    if (let Some(value) <- marshaler) {
        value.close()
    }

    handler.close()
}

@Test
func testDelegateBoxDoesNotExposeSyntheticIInspectableView() {
    let handler = AsyncActionCompletedHandler.new({ info: InParam<IAsyncAction>, status: AsyncStatus =>
        ()
    })

    let inspectable = unsafe { handler.query(IInspectable.descriptor()) }
    @Expect(inspectable.isNone(), true)
    @Expect(delegateAsIInspectableThrows(handler), true)

    handler.close()
}
