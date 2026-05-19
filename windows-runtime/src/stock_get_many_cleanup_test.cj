package windows_runtime

import std.collection.*
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, Result}
import windows_core as windows_core
import windows_interface.IInspectable
import windows_interface as windows_interface

let stockGetManyCleanupAddRefCalls = AtomicInt64(0)
let stockGetManyCleanupReleaseCalls = AtomicInt64(0)

@C
func stockGetManyCleanupAddRefThunk(raw: CPointer<Unit>): UInt32 {
    let _ = raw
    let oldCount = stockGetManyCleanupAddRefCalls.fetchAdd(1)
    UInt32(oldCount + 2)
}

@C
func stockGetManyCleanupReleaseThunk(raw: CPointer<Unit>): UInt32 {
    let _ = raw
    let oldCount = stockGetManyCleanupReleaseCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

func stockGetManyCleanupObject(vtbl: CPointer<windows_interface.IUnknownVtbl>): CPointer<Unit> {
    let raw = windows_core.coTaskMemAlloc(sizeOf<CPointer<windows_interface.IUnknownVtbl>>())
    if (raw.isNull()) {
        return CPointer<Unit>()
    }
    unsafe { CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw).write(vtbl) }
    raw
}

@Test
func testWriteGenericManyRangeReleasesHandleSlotsOnPartialFailure() {
    stockGetManyCleanupAddRefCalls.store(0)
    stockGetManyCleanupReleaseCalls.store(0)

    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.AddRef = stockGetManyCleanupAddRefThunk
    vtbl.Release = stockGetManyCleanupReleaseThunk
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(vtbl) }
    let objectRaw = stockGetManyCleanupObject(vtblHandle)
    let buffer = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>() * UIntNative(2))
    let slots = CPointer<CPointer<Unit>>(buffer)
    unsafe {
        slots.write(CPointer<Unit>())
        (slots + 1).write(CPointer<Unit>())
    }

    try {
        let values = ArrayList<IInspectable>()
        values.add(IInspectable.viewOf(objectRaw))
        values.add(IInspectable.viewOf(CPointer<Unit>()))

        match (writeGenericManyRange<IInspectable>(2u32, buffer, values, 0)) {
            case Result<UInt32>.Ok(count) =>
                let _ = count
                throw Exception("expected partial GetMany failure")
            case Result<UInt32>.Err(error) =>
                @Expect(error.code().value, E_POINTER.value)
        }

        @Expect(stockGetManyCleanupAddRefCalls.load(), 1)
        @Expect(stockGetManyCleanupReleaseCalls.load(), 1)
        @Expect(unsafe { slots.read() }.isNull(), true)
    } finally {
        let remaining = unsafe { slots.read() }
        if (remaining.isNotNull()) {
            let _ = unsafe { stockGetManyCleanupReleaseThunk(remaining) }
            unsafe { slots.write(CPointer<Unit>()) }
        }
        windows_core.coTaskMemFree(buffer)
        windows_core.coTaskMemFree(objectRaw)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
    }
}
