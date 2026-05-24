package windows_collections

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, InParam, WindowsException}

class CollectionDelegateNullObservation {
    public var sawNullSender = false
    public var sawNullEvent = false

    public init() {}
}

@Test
func testCollectionDelegateThunkMapsThrownWindowsExceptionToHRESULT() {
    let handler = MapChangedEventHandler<Int32, Int32>.new({
        sender: InParam<IObservableMap<Int32, Int32>>,
        event: InParam<IMapChangedEventArgs<Int32>> =>
        let _ = sender
        let _ = event
        throw WindowsException(E_FAIL)
    })

    let vtbl = unsafe { handler.vtbl() }
    let hr = unsafe { vtbl.Invoke(handler.asRaw(), CPointer<Unit>(), CPointer<Unit>()) }

    @Expect(hr, E_FAIL.value)

    handler.close()
}

@Test
func testCollectionDelegateInvokeAcceptsEmptyInParams() {
    let observed = CollectionDelegateNullObservation()
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
