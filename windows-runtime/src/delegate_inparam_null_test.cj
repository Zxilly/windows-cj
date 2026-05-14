package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{InParam, S_OK}
import windows_interface.{IAgileObject, IInspectable, IMarshal}

class DelegateNullObservation {
    public var sawNullInfo = false
    public var status = AsyncStatus_Started
    public var sawNullSender = false
    public var sawNullEvent = false
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
func testEventHandlerInvokeAcceptsEmptySenderInParam() {
    let observed = DelegateNullObservation()
    let handler = EventHandler<Int32>.new({ sender: InParam<IInspectable>, args: Int32 =>
        observed.sawNullSender = sender.isNull()
        observed.intValue = args
    })

    unsafe { handler.Invoke(InParam<IInspectable>(), 123i32) }

    @Expect(observed.sawNullSender, true)
    @Expect(observed.intValue, 123i32)

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
func testCollectionDelegateInvokeAcceptsEmptyInParams() {
    let observed = DelegateNullObservation()
    let mapHandler = MapChangedEventHandler<Int32, Int32>.new({
        sender: InParam<IObservableMap<Int32, Int32>>,
        event: InParam<IMapChangedEventArgs<Int32>> =>
        observed.sawNullSender = sender.isNull()
        observed.sawNullEvent = event.isNull()
    })

    unsafe {
        mapHandler.Invoke(
            InParam<IObservableMap<Int32, Int32>>(),
            InParam<IMapChangedEventArgs<Int32>>()
        )
    }

    @Expect(observed.sawNullSender, true)
    @Expect(observed.sawNullEvent, true)

    observed.sawNullSender = false
    observed.sawNullEvent = false
    let vectorHandler = VectorChangedEventHandler<Int32>.new({
        sender: InParam<IObservableVector<Int32>>,
        event: InParam<IVectorChangedEventArgs> =>
        observed.sawNullSender = sender.isNull()
        observed.sawNullEvent = event.isNull()
    })

    unsafe {
        vectorHandler.Invoke(
            InParam<IObservableVector<Int32>>(),
            InParam<IVectorChangedEventArgs>()
        )
    }

    @Expect(observed.sawNullSender, true)
    @Expect(observed.sawNullEvent, true)

    mapHandler.close()
    vectorHandler.close()
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
