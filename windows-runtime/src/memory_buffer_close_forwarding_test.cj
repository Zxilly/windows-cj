package windows_runtime

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, E_POINTER, S_OK}
import windows_interface.{GUID, IInspectable, IUnknown}

let memoryBufferCloseForwardingQueryCalls = AtomicInt64(0)
let memoryBufferCloseForwardingAddRefCalls = AtomicInt64(0)
let memoryBufferCloseForwardingReleaseCalls = AtomicInt64(0)
let memoryBufferCloseForwardingCloseCalls = AtomicInt64(0)

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
