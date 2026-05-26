package windows_winui3.xaml

import std.unittest.*
import std.unittest.testmacro.*
import windows_common.Foundation.{EventRegistrationToken}
import windows_core.{E_FAIL, E_INVALIDARG, E_NOTIMPL, E_POINTER, GUID, HRESULT, IID_IUNKNOWN, IUnknownVtbl, S_OK, WindowsException, coTaskMemAlloc, coTaskMemFree}

class XamlTestFlag {
    var value = false
}

class XamlTestCounter {
    var value = 0
}

@C
struct XamlTestComObject {
    public var vtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    public var refCount: UInt32 = 1u32
    public init() {}
}

var xamlTestComVtblStorage: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
var xamlTestComReleaseCount: Int64 = 0

@C
func xamlTestComRelease(thisPtr: CPointer<Unit>): UInt32 {
    if (thisPtr.isNull()) {
        return 0u32
    }
    xamlTestComReleaseCount += 1
    let obj = CPointer<XamlTestComObject>(thisPtr)
    var value = unsafe { obj.read() }
    if (value.refCount == 0u32) {
        return 0u32
    }
    value.refCount -= 1u32
    let refCount = value.refCount
    if (refCount == 0u32) {
        unsafe { obj.write(value) }
        coTaskMemFree(thisPtr)
        return 0u32
    }
    unsafe { obj.write(value) }
    return refCount
}

func xamlTestComVtbl(): CPointer<IUnknownVtbl> {
    if (xamlTestComVtblStorage.isNotNull()) {
        return xamlTestComVtblStorage
    }
    let raw = coTaskMemAlloc(sizeOf<IUnknownVtbl>())
    if (raw.isNull()) {
        throw Exception("failed to allocate test COM vtable")
    }
    var table = IUnknownVtbl()
    table.Release = xamlTestComRelease
    let typed = CPointer<IUnknownVtbl>(raw)
    unsafe { typed.write(table) }
    xamlTestComVtblStorage = typed
    return typed
}

func xamlTestCreateComObject(): CPointer<Unit> {
    let raw = coTaskMemAlloc(sizeOf<XamlTestComObject>())
    if (raw.isNull()) {
        throw Exception("failed to allocate test COM object")
    }
    var object = XamlTestComObject()
    object.vtbl = xamlTestComVtbl()
    object.refCount = 1u32
    unsafe { CPointer<XamlTestComObject>(raw).write(object) }
    raw
}

func xamlTestCreateApplicationCallbackObject(slot: Int64): CPointer<Unit> {
    let raw = coTaskMemAlloc(sizeOf<ApplicationInitializationCallbackObject>())
    if (raw.isNull()) {
        throw Exception("failed to allocate test ApplicationInitializationCallback object")
    }
    var object = ApplicationInitializationCallbackObject()
    object.vtbl = applicationInitializationCallbackVtbl()
    object.refCount = 1u32
    object.slot = slot
    unsafe { CPointer<ApplicationInitializationCallbackObject>(raw).write(object) }
    raw
}

func xamlTestCreateRoutedEventHandlerObject(slot: Int64): CPointer<Unit> {
    let raw = coTaskMemAlloc(sizeOf<RoutedEventHandlerObject>())
    if (raw.isNull()) {
        throw Exception("failed to allocate test RoutedEventHandler object")
    }
    var object = RoutedEventHandlerObject()
    object.vtbl = routedEventHandlerVtbl()
    object.refCount = 1u32
    object.slot = slot
    unsafe { CPointer<RoutedEventHandlerObject>(raw).write(object) }
    raw
}

func xamlTestThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@Test
func testFailedWinuiOutSlotCleanupReleasesAndClearsPartialResult() {
    xamlTestComReleaseCount = 0
    var result = xamlTestCreateComObject()

    var threw = false
    try {
        releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout result))
        checkHRESULT(HRESULT(E_FAIL.value), "test failed out slot")
    } catch (_: Exception) {
        threw = true
    }

    @Expect(threw, true)
    @Expect(result.isNull(), true)
    @Expect(xamlTestComReleaseCount, 1)
}

@Test
func testCheckHRESULTThrowsWindowsExceptionWithOriginalCode() {
    var status = 0
    try {
        checkHRESULT(HRESULT(E_INVALIDARG.value), "test HRESULT")
    } catch (error: WindowsException) {
        if (error.code().value == E_INVALIDARG.value) {
            status = 1
        }
    } catch (_: Exception) {
        status = 2
    }

    @Expect(status, 1)
}

@Test
func testFailedWinuiOutSlotCleanupReleasesBothCreateInstanceOutputs() {
    xamlTestComReleaseCount = 0
    var inner = xamlTestCreateComObject()
    var result = xamlTestCreateComObject()
    let hr = HRESULT(E_FAIL.value)

    var threw = false
    try {
        if (hr.failed()) {
            releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout inner))
            releaseFailedWinuiOutSlot(CPointer<CPointer<Unit>>(inout result))
        }
        checkHRESULT(hr, "test failed two out slots")
    } catch (_: Exception) {
        threw = true
    }

    @Expect(threw, true)
    @Expect(inner.isNull(), true)
    @Expect(result.isNull(), true)
    @Expect(xamlTestComReleaseCount, 2)
}

@Test
func testApplicationCallbackStateNoThrowReleasesAndClearsSlot() {
    let counter = XamlTestCounter()
    let slot = addApplicationInitializationCallbackSlot({ => counter.value += 1 })
    let raw = xamlTestCreateApplicationCallbackObject(slot)

    let (nextRaw, nextSlot, nextClosed) = closeApplicationCallbackStateNoThrow(raw, slot, false)
    @Expect(nextRaw.isNull(), true)
    @Expect(nextSlot, -1)
    @Expect(nextClosed, true)
    @Expect(invokeApplicationInitializationCallbackSlot(slot), false)
    @Expect(counter.value, 0)

    let (againRaw, againSlot, againClosed) = closeApplicationCallbackStateNoThrow(nextRaw, nextSlot, nextClosed)
    @Expect(againRaw.isNull(), true)
    @Expect(againSlot, -1)
    @Expect(againClosed, true)
}

@Test
func testApplicationCallbackFinalizerStateOnlyDropsLocalSlot() {
    let counter = XamlTestCounter()
    let slot = addApplicationInitializationCallbackSlot({ => counter.value += 1 })

    try {
        let (nextRaw, nextSlot, nextClosed) = finalizeApplicationCallbackStateNoThrow()
        @Expect(nextRaw.isNull(), true)
        @Expect(nextSlot, -1)
        @Expect(nextClosed, true)
        @Expect(invokeApplicationInitializationCallbackSlot(slot), true)
        @Expect(counter.value, 1)
    } finally {
        clearApplicationInitializationCallbackSlot(slot)
    }
}

@Test
func testApplicationCallbackInvokesAndClearsHandler() {
    let flag = XamlTestFlag()
    let callback = ApplicationCallback({ => flag.value = true })

    let invokeResult = unsafe { applicationInitializationCallbackInvoke(callback.asRaw(), CPointer<Unit>()) }
    @Expect(invokeResult, S_OK.value)
    @Expect(flag.value, true)

    var queried = CPointer<Unit>()
    var iid = IID_APPLICATION_INITIALIZATION_CALLBACK
    let queryResult = unsafe {
        applicationInitializationCallbackQueryInterface(
            callback.asRaw(),
            CPointer<GUID>(inout iid),
            CPointer<CPointer<Unit>>(inout queried)
        )
    }
    @Expect(queryResult, S_OK.value)
    @Expect(queried.toUIntNative(), callback.asRaw().toUIntNative())
    let releaseResult = unsafe { applicationInitializationCallbackRelease(queried) }
    @Expect(releaseResult, 1u32)

    var retained = CPointer<Unit>()
    var retainedIid = IID_IUNKNOWN
    let retainedQueryResult = unsafe {
        applicationInitializationCallbackQueryInterface(
            callback.asRaw(),
            CPointer<GUID>(inout retainedIid),
            CPointer<CPointer<Unit>>(inout retained)
        )
    }
    @Expect(retainedQueryResult, S_OK.value)

    flag.value = false
    callback.close()
    let closedInvokeResult = unsafe { applicationInitializationCallbackInvoke(callback.asRaw(), CPointer<Unit>()) }
    @Expect(closedInvokeResult, E_POINTER.value)
    @Expect(flag.value, false)
    @Expect(callback.isClosed(), true)
    @Expect(callback.asRaw().isNull(), true)

    let retainedInvokeResult = unsafe { applicationInitializationCallbackInvoke(retained, CPointer<Unit>()) }
    @Expect(retainedInvokeResult, E_POINTER.value)
    @Expect(flag.value, false)
    let retainedReleaseResult = unsafe { applicationInitializationCallbackRelease(retained) }
    @Expect(retainedReleaseResult, 0u32)
}

@Test
func testApplicationCallbackQueryInterfaceClearsResultOnPointerFailure() {
    let callback = ApplicationCallback({ => () })
    var stale = callback.asRaw()
    var iid = IID_APPLICATION_INITIALIZATION_CALLBACK

    let nullIidResult = unsafe {
        applicationInitializationCallbackQueryInterface(
            callback.asRaw(),
            CPointer<GUID>(),
            CPointer<CPointer<Unit>>(inout stale)
        )
    }
    @Expect(nullIidResult, E_POINTER.value)
    @Expect(stale.isNull(), true)

    stale = callback.asRaw()
    let nullThisResult = unsafe {
        applicationInitializationCallbackQueryInterface(
            CPointer<Unit>(),
            CPointer<GUID>(inout iid),
            CPointer<CPointer<Unit>>(inout stale)
        )
    }
    @Expect(nullThisResult, E_POINTER.value)
    @Expect(stale.isNull(), true)

    callback.close()
}

@Test
func testApplicationCallbackInvokePreservesWindowsExceptionHRESULT() {
    let callback = ApplicationCallback({ => throw WindowsException(E_INVALIDARG) })

    let result = unsafe { applicationInitializationCallbackInvoke(callback.asRaw(), CPointer<Unit>()) }
    @Expect(result, E_INVALIDARG.value)

    callback.close()
}

@Test
func testRawHandleCloseStateReleasesOnce() {
    xamlTestComReleaseCount = 0
    let raw = xamlTestCreateComObject()
    let (nextRaw, nextClosed) = closeWinuiRawStateNoThrow(raw, false)
    @Expect(nextRaw.isNull(), true)
    @Expect(nextClosed, true)
    @Expect(xamlTestComReleaseCount, 1)

    let (againRaw, againClosed) = closeWinuiRawStateNoThrow(nextRaw, nextClosed)
    @Expect(againRaw.isNull(), true)
    @Expect(againClosed, true)
    @Expect(xamlTestComReleaseCount, 1)
}

@Test
func testRawHandleFinalizerStateDoesNotReleaseNativePointer() {
    xamlTestComReleaseCount = 0
    let raw = xamlTestCreateComObject()

    try {
        let (nextRaw, nextClosed) = finalizeWinuiRawStateNoThrow()
        @Expect(nextRaw.isNull(), true)
        @Expect(nextClosed, true)
        @Expect(xamlTestComReleaseCount, 0)
    } finally {
        releaseRaw(raw)
    }

    @Expect(xamlTestComReleaseCount, 1)
}

@Test
func testRawHandleWrappersCloseReleaseOnce() {
    xamlTestComReleaseCount = 0

    let window = WindowHandle(xamlTestCreateComObject())
    window.close()
    window.close()
    @Expect(window.isClosed(), true)
    @Expect(xamlTestThrows({ => let _ = window.value() }), true)

    let element = UIElementHandle(xamlTestCreateComObject())
    element.close()
    element.close()
    @Expect(element.isClosed(), true)
    @Expect(xamlTestThrows({ => let _ = element.value() }), true)

    let xamlObject = XamlObjectHandle(xamlTestCreateComObject())
    xamlObject.close()
    xamlObject.close()
    @Expect(xamlObject.isClosed(), true)
    @Expect(xamlObject.asRaw().isNull(), true)

    let button = ButtonBaseHandle(xamlTestCreateComObject())
    button.close()
    button.close()
    @Expect(button.isClosed(), true)
    @Expect(button.asRaw().isNull(), true)

    @Expect(xamlTestComReleaseCount, 4)
}

@Test
func testHandleConstructorsRejectNullPointers() {
    @Expect(xamlTestThrows({ => let _ = WindowHandle(CPointer<Unit>()) }), true)
    @Expect(xamlTestThrows({ => let _ = UIElementHandle(CPointer<Unit>()) }), true)
    @Expect(xamlTestThrows({ => let _ = XamlObjectHandle(CPointer<Unit>()) }), true)
    @Expect(xamlTestThrows({ => let _ = ButtonBaseHandle(CPointer<Unit>()) }), true)
}

@Test
func testDefaultWinuiVtablesClearOutSlotsBeforeNotImpl() {
    var button = ButtonBaseVtbl()
    var token: EventRegistrationToken = 123
    @Expect(
        unsafe { button.AddClick(CPointer<Unit>(), CPointer<Unit>(), CPointer<EventRegistrationToken>(inout token)) },
        E_NOTIMPL.value
    )
    @Expect(token, 0)

    let sentinel = coTaskMemAlloc(sizeOf<UInt8>())
    if (sentinel.isNull()) {
        throw Exception("failed to allocate default vtable sentinel")
    }
    try {
        var routed = RoutedEventHandlerVtbl()
        var result = sentinel
        @Expect(
            unsafe { routed.QueryInterface(CPointer<Unit>(), CPointer<GUID>(), CPointer<CPointer<Unit>>(inout result)) },
            E_NOTIMPL.value
        )
        @Expect(result.isNull(), true)
    } finally {
        coTaskMemFree(sentinel)
    }
}

@Test
func testRoutedEventHandlerStateNoThrowReleasesAndClearsSlot() {
    let counter = XamlTestCounter()
    let slot = addRoutedEventHandlerSlot({ => counter.value += 1 })
    let raw = xamlTestCreateRoutedEventHandlerObject(slot)

    let (nextRaw, nextSlot, nextClosed) = closeRoutedEventHandlerStateNoThrow(raw, slot, false)
    @Expect(nextRaw.isNull(), true)
    @Expect(nextSlot, -1)
    @Expect(nextClosed, true)
    @Expect(invokeRoutedEventHandlerSlot(slot), false)
    @Expect(counter.value, 0)

    let (againRaw, againSlot, againClosed) = closeRoutedEventHandlerStateNoThrow(nextRaw, nextSlot, nextClosed)
    @Expect(againRaw.isNull(), true)
    @Expect(againSlot, -1)
    @Expect(againClosed, true)
}

@Test
func testRoutedEventHandlerFinalizerStateOnlyDropsLocalSlot() {
    let counter = XamlTestCounter()
    let slot = addRoutedEventHandlerSlot({ => counter.value += 1 })

    try {
        let (nextRaw, nextSlot, nextClosed) = finalizeRoutedEventHandlerStateNoThrow()
        @Expect(nextRaw.isNull(), true)
        @Expect(nextSlot, -1)
        @Expect(nextClosed, true)
        @Expect(invokeRoutedEventHandlerSlot(slot), true)
        @Expect(counter.value, 1)
    } finally {
        clearRoutedEventHandlerSlot(slot)
    }
}

@Test
func testRoutedEventHandlerObjectDispatchAndClose() {
    let counter = XamlTestCounter()
    let handle = RoutedEventHandlerHandle({ => counter.value += 1 })

    try {
        @Expect(handle.asRaw().isNotNull(), true)
        let invokeResult = unsafe { routedEventHandlerInvoke(handle.asRaw(), CPointer<Unit>(), CPointer<Unit>()) }
        @Expect(invokeResult, S_OK.value)
        @Expect(counter.value, 1)

        var queried = CPointer<Unit>()
        var iid = IID_IUNKNOWN
        let queryResult = unsafe {
            routedEventHandlerQueryInterface(
                handle.asRaw(),
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout queried)
            )
        }
        @Expect(
            queryResult,
            S_OK.value
        )
        @Expect(queried.toUIntNative(), handle.asRaw().toUIntNative())
        let releaseResult = unsafe { routedEventHandlerRelease(queried) }
        @Expect(releaseResult, 1u32)

        var retained = CPointer<Unit>()
        var retainedIid = IID_IUNKNOWN
        let retainedQueryResult = unsafe {
            routedEventHandlerQueryInterface(
                handle.asRaw(),
                CPointer<GUID>(inout retainedIid),
                CPointer<CPointer<Unit>>(inout retained)
            )
        }
        @Expect(retainedQueryResult, S_OK.value)
        handle.close()
        let retainedInvokeResult = unsafe { routedEventHandlerInvoke(retained, CPointer<Unit>(), CPointer<Unit>()) }
        @Expect(retainedInvokeResult, E_POINTER.value)
        @Expect(counter.value, 1)
        let retainedReleaseResult = unsafe { routedEventHandlerRelease(retained) }
        @Expect(retainedReleaseResult, 0u32)
    } finally {
        handle.close()
    }

    @Expect(handle.isClosed(), true)
    @Expect(handle.asRaw().isNull(), true)
}

@Test
func testRoutedEventHandlerQueryInterfaceClearsResultOnPointerFailure() {
    let handle = RoutedEventHandlerHandle({ => () })
    var stale = handle.asRaw()
    var iid = IID_ROUTED_EVENT_HANDLER

    let nullIidResult = unsafe {
        routedEventHandlerQueryInterface(
            handle.asRaw(),
            CPointer<GUID>(),
            CPointer<CPointer<Unit>>(inout stale)
        )
    }
    @Expect(nullIidResult, E_POINTER.value)
    @Expect(stale.isNull(), true)

    stale = handle.asRaw()
    let nullThisResult = unsafe {
        routedEventHandlerQueryInterface(
            CPointer<Unit>(),
            CPointer<GUID>(inout iid),
            CPointer<CPointer<Unit>>(inout stale)
        )
    }
    @Expect(nullThisResult, E_POINTER.value)
    @Expect(stale.isNull(), true)

    handle.close()
}

@Test
func testRoutedEventHandlerInvokePreservesWindowsExceptionHRESULT() {
    let handle = RoutedEventHandlerHandle({ => throw WindowsException(E_INVALIDARG) })

    let result = unsafe { routedEventHandlerInvoke(handle.asRaw(), CPointer<Unit>(), CPointer<Unit>()) }
    @Expect(result, E_INVALIDARG.value)

    handle.close()
}
