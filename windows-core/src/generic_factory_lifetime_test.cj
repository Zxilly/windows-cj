package windows_core

import windows_interface as windows_interface
import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*

let genericFactoryReleaseCount = AtomicInt64(0)
var genericFactoryActivateHRESULT = S_OK.value
var genericFactoryPartialRaw = CPointer<Unit>()

@C
func genericFactoryActivateInstanceThunk(
    _: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    unsafe { result.write(genericFactoryPartialRaw) }
    genericFactoryActivateHRESULT
}

@C
func genericFactoryReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = genericFactoryReleaseCount.fetchAdd(1)
    UInt32(oldCount + 1)
}

func resetGenericFactoryReleaseCount(): Unit {
    genericFactoryReleaseCount.store(0)
    genericFactoryActivateHRESULT = S_OK.value
    genericFactoryPartialRaw = CPointer<Unit>()
}

func genericFactoryLifetimeVtbl(): IGenericFactoryVtbl {
    var vtbl = IGenericFactoryVtbl()
    vtbl.base_.base_.Release = genericFactoryReleaseThunk
    vtbl.ActivateInstance = genericFactoryActivateInstanceThunk
    vtbl
}

func withGenericFactoryRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IGenericFactoryVtbl>(genericFactoryLifetimeVtbl()) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IGenericFactoryVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)

    action(raw)

    unsafe {
        windows_interface.freeNativeValue(objectHandle)
        windows_interface.freeNativeValue(vtblHandle)
    }
}

@Test
func testGenericFactoryDefaultActivateInstanceClearsStaleOutPointerOnENotImpl() {
    let vtbl = IGenericFactoryVtbl()
    var result = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x1234) }

    let hr = unsafe {
        HRESULT(vtbl.ActivateInstance(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout result)))
    }

    @Expect(hr, E_NOTIMPL)
    @Expect(result.isNull(), true)
}

@Test
func testGenericFactoryBorrowedViewCannotManualRelease() {
    resetGenericFactoryReleaseCount()
    withGenericFactoryRaw({ raw: CPointer<Unit> =>
        let view = IGenericFactory.viewOf(raw)
        @Expect(view.release(), 0u32)
        @Expect(genericFactoryReleaseCount.load(), 0)

        let owned = IGenericFactory.fromAbiTake(raw)
        @Expect(owned.release(), 1u32)
        @Expect(genericFactoryReleaseCount.load(), 1)
        @Expect(owned.isClosed(), true)
        @Expect(owned.asRaw().isNull(), true)

        owned.close()
        @Expect(genericFactoryReleaseCount.load(), 1)
        @Expect(owned.release(), 0u32)
        @Expect(genericFactoryReleaseCount.load(), 1)
    })
}

@Test
func testGenericFactoryManualReleaseClosesWrapper() {
    resetGenericFactoryReleaseCount()
    withGenericFactoryRaw({ raw: CPointer<Unit> =>
        let wrapper = IGenericFactory(raw)
        @Expect(wrapper.isClosed(), false)
        @Expect(wrapper.asRaw().toUIntNative(), raw.toUIntNative())

        @Expect(wrapper.release(), 1u32)
        @Expect(genericFactoryReleaseCount.load(), 1)
        @Expect(wrapper.isClosed(), true)
        @Expect(wrapper.asRaw().isNull(), true)

        @Expect(wrapper.release(), 0u32)
        @Expect(genericFactoryReleaseCount.load(), 1)
    })
}

@Test
func testGenericFactoryActivateReleasesPartialOutputOnFailedHRESULT() {
    resetGenericFactoryReleaseCount()
    withGenericFactoryRaw({ raw: CPointer<Unit> =>
        genericFactoryPartialRaw = raw
        genericFactoryActivateHRESULT = E_FAIL.value
        let factory = IGenericFactory.viewOf(raw)
        let result = unsafe { factory.ActivateInstance<IGenericFactory>(IGenericFactory.descriptor()) }
        match (result) {
            case Result<IGenericFactory>.Ok(value) =>
                value.close()
                throw Exception("IGenericFactory.ActivateInstance unexpectedly succeeded")
            case Result<IGenericFactory>.Err(error) =>
                @Expect(error.code(), E_FAIL)
        }
        @Expect(genericFactoryReleaseCount.load(), 1)
    })
}
