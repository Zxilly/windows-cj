package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOINTERFACE, E_POINTER, InParam, Result, S_OK, WinError, WindowsException}
import windows_interface.{GUID, IInspectable, IUnknown}

let memoryBufferCloseForwardingQueryCalls = AtomicInt64(0)
let memoryBufferCloseForwardingAddRefCalls = AtomicInt64(0)
let memoryBufferCloseForwardingReleaseCalls = AtomicInt64(0)
let memoryBufferCloseForwardingCloseCalls = AtomicInt64(0)

class MemoryBufferReferenceEventThunkTestImpl <: IMemoryBufferReference_Impl {
    public var throwWindowsOnCapacity: Bool = false
    public var throwPlainOnCapacity: Bool = false
    public var failClosed: Bool = false
    public var throwWindowsOnClosed: Bool = false
    public var throwPlainOnClosed: Bool = false
    public var throwWindowsOnRemoveClosed: Bool = false
    public var throwPlainOnRemoveClosed: Bool = false

    public init() {}

    public func Capacity(): Result<UInt32> {
        if (throwWindowsOnCapacity) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnCapacity) {
            throw Exception("Capacity failure")
        }
        Result<UInt32>.Ok(0u32)
    }

    public func Closed(handler: InParam<TypedEventHandler<IMemoryBufferReference, IInspectable>>): Result<EventRegistrationToken> {
        let _ = handler
        if (throwWindowsOnClosed) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnClosed) {
            throw Exception("Closed failure")
        }
        if (failClosed) {
            return Result<EventRegistrationToken>.Err(WinError.fromHRESULT(E_FAIL))
        }
        var token = EventRegistrationToken()
        token.Value = 17i64
        Result<EventRegistrationToken>.Ok(token)
    }

    public func RemoveClosed(cookie: EventRegistrationToken): Result<Unit> {
        let _ = cookie
        if (throwWindowsOnRemoveClosed) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnRemoveClosed) {
            throw Exception("RemoveClosed failure")
        }
        Result<Unit>.Ok(())
    }

    public func Close(): Result<Unit> {
        Result<Unit>.Ok(())
    }
}

class MemoryBufferCreateReferenceThunkTestImpl <: IMemoryBuffer_Impl {
    public var throwWindowsOnCreateReference: Bool = false
    public var throwPlainOnCreateReference: Bool = false

    public func CreateReference(): Result<IMemoryBufferReference> {
        if (throwWindowsOnCreateReference) {
            throw WindowsException(E_POINTER)
        }
        if (throwPlainOnCreateReference) {
            throw Exception("CreateReference failure")
        }
        Result<IMemoryBufferReference>.Err(WinError.fromHRESULT(E_FAIL))
    }

    public func Close(): Result<Unit> {
        Result<Unit>.Ok(())
    }
}

@C
func memoryBufferCloseForwardingQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (iid.isNull() || result.isNull()) {
        return E_POINTER.value
    }
    let target = unsafe { iid.read() }
    if (
        target == IClosable.iid() ||
        target == IMemoryBuffer.iid() ||
        target == IMemoryBufferReference.iid() ||
        target == IInspectable.iid() ||
        target == IUnknown.iid()
    ) {
        memoryBufferCloseForwardingQueryCalls.fetchAdd(1)
        unsafe { memoryBufferCloseForwardingAddRefThunk(instanceRaw) }
        unsafe { result.write(instanceRaw) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    E_NOINTERFACE.value
}

@C
func memoryBufferCloseForwardingAddRefThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = memoryBufferCloseForwardingAddRefCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func memoryBufferCloseForwardingReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = memoryBufferCloseForwardingReleaseCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func memoryBufferCloseForwardingCloseThunk(_: CPointer<Unit>): Int32 {
    memoryBufferCloseForwardingCloseCalls.fetchAdd(1)
    S_OK.value
}

func memoryBufferCloseForwardingClosableVtbl(): IClosableVtbl {
    var vtbl = IClosableVtbl()
    vtbl.base_.base_.QueryInterface = memoryBufferCloseForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = memoryBufferCloseForwardingAddRefThunk
    vtbl.base_.base_.Release = memoryBufferCloseForwardingReleaseThunk
    vtbl.Close = memoryBufferCloseForwardingCloseThunk
    vtbl
}

func resetMemoryBufferCloseForwardingCounters(): Unit {
    memoryBufferCloseForwardingQueryCalls.store(0)
    memoryBufferCloseForwardingAddRefCalls.store(0)
    memoryBufferCloseForwardingReleaseCalls.store(0)
    memoryBufferCloseForwardingCloseCalls.store(0)
}

func withMemoryBufferCloseForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IClosableVtbl>(memoryBufferCloseForwardingClosableVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IClosableVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)
    try {
        action(raw)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

@Test
func testIMemoryBufferReferenceEventThunksClearTokenAndTranslateExceptions() {
    let impl = MemoryBufferReferenceEventThunkTestImpl()

    impl.throwWindowsOnCapacity = true
    var windowsCapacity = 123u32
    @Expect(impl.__winrtThunk_Capacity(CPointer<UInt32>(inout windowsCapacity)), E_POINTER.value)
    @Expect(windowsCapacity, 0u32)
    impl.throwWindowsOnCapacity = false

    impl.throwPlainOnCapacity = true
    var plainCapacity = 456u32
    @Expect(impl.__winrtThunk_Capacity(CPointer<UInt32>(inout plainCapacity)), E_FAIL.value)
    @Expect(plainCapacity, 0u32)
    impl.throwPlainOnCapacity = false

    impl.failClosed = true
    var failToken = EventRegistrationTokenAbi()
    failToken.Value = 123i64
    let failHr = impl.__winrtThunk_Closed(CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout failToken))
    @Expect(failHr, E_FAIL.value)
    @Expect(failToken.Value, 0i64)
    impl.failClosed = false

    impl.throwWindowsOnClosed = true
    var windowsToken = EventRegistrationTokenAbi()
    windowsToken.Value = 456i64
    let windowsHr = impl.__winrtThunk_Closed(CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout windowsToken))
    @Expect(windowsHr, E_POINTER.value)
    @Expect(windowsToken.Value, 0i64)
    impl.throwWindowsOnClosed = false

    impl.throwPlainOnClosed = true
    var plainToken = EventRegistrationTokenAbi()
    plainToken.Value = 789i64
    let plainHr = impl.__winrtThunk_Closed(CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout plainToken))
    @Expect(plainHr, E_FAIL.value)
    @Expect(plainToken.Value, 0i64)
    impl.throwPlainOnClosed = false

    var token = EventRegistrationTokenAbi()
    token.Value = 17i64
    impl.throwWindowsOnRemoveClosed = true
    @Expect(impl.__winrtThunk_RemoveClosed(token), E_POINTER.value)
    impl.throwWindowsOnRemoveClosed = false

    impl.throwPlainOnRemoveClosed = true
    @Expect(impl.__winrtThunk_RemoveClosed(token), E_FAIL.value)
    impl.throwPlainOnRemoveClosed = false
}

@Test
func testIMemoryBufferCreateReferenceThunkClearsOutputAndTranslatesExceptions() {
    let impl = MemoryBufferCreateReferenceThunkTestImpl()
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(987i32) }
    try {
        impl.throwWindowsOnCreateReference = true
        var windowsRaw = CPointer<Unit>(sentinel)
        @Expect(
            impl.__winrtThunk_CreateReference(CPointer<CPointer<Unit>>(inout windowsRaw)),
            E_POINTER.value
        )
        @Expect(windowsRaw.isNull(), true)
        impl.throwWindowsOnCreateReference = false

        impl.throwPlainOnCreateReference = true
        var plainRaw = CPointer<Unit>(sentinel)
        @Expect(
            impl.__winrtThunk_CreateReference(CPointer<CPointer<Unit>>(inout plainRaw)),
            E_FAIL.value
        )
        @Expect(plainRaw.isNull(), true)
        impl.throwPlainOnCreateReference = false
    } finally {
        impl.throwWindowsOnCreateReference = false
        impl.throwPlainOnCreateReference = false
        unsafe { windows_interface.freeNativeValue(sentinel) }
    }
}

@Test
func testIMemoryBufferForwardsCloseThroughIClosable() {
    resetMemoryBufferCloseForwardingCounters()
    withMemoryBufferCloseForwardingRaw({ raw: CPointer<Unit> =>
        let buffer = IMemoryBuffer.viewOf(raw)

        unsafe { buffer.Close() }

        @Expect(memoryBufferCloseForwardingCloseCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingQueryCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingAddRefCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testIMemoryBufferReferenceForwardsCloseThroughIClosable() {
    resetMemoryBufferCloseForwardingCounters()
    withMemoryBufferCloseForwardingRaw({ raw: CPointer<Unit> =>
        let reference = IMemoryBufferReference.viewOf(raw)

        unsafe { reference.Close() }

        @Expect(memoryBufferCloseForwardingCloseCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingQueryCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingAddRefCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testMemoryBufferRuntimeForwardsCloseThroughIClosable() {
    resetMemoryBufferCloseForwardingCounters()
    withMemoryBufferCloseForwardingRaw({ raw: CPointer<Unit> =>
        let buffer = MemoryBuffer.viewOf(raw)

        unsafe { buffer.Close() }

        @Expect(memoryBufferCloseForwardingCloseCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingQueryCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingAddRefCalls.load(), 1)
        @Expect(memoryBufferCloseForwardingReleaseCalls.load(), 1)
    })
}
