package windows_foundation

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_NOINTERFACE, E_NOTIMPL, InParam, Result, WindowsException}
import windows_core as windows_core
import windows_interface as windows_interface
import windows_interface.IInspectable

class ActivationFactoryThunkCleanupImpl <: IGetActivationFactory_Impl {
    public var observedClassId: String = ""
    public var throwWindows: Bool = false
    public var throwPlain: Bool = false

    public func GetActivationFactory(activatableClassId: InParam<windows_core.HString>): Result<IInspectable> {
        observedClassId = activatableClassId.get().get()
        if (throwWindows) {
            throw WindowsException(E_NOTIMPL)
        }
        if (throwPlain) {
            throw Exception("activation factory thunk failure")
        }
        foundationTestNotImplemented<IInspectable>()
    }
}

@Test
func testGetActivationFactoryThunkClosesTemporaryClassIdHString() {
    let impl = ActivationFactoryThunkCleanupImpl()
    let source = windows_core.HString("Windows.Test.Activation")
    let classIdRaw = source.toSystemHandleCopy()
    var result = CPointer<Unit>()
    let freeBefore = windows_core.debugObservedHStringFreeCount()

    try {
        let hr = impl.__winrtThunk_GetActivationFactory(classIdRaw, CPointer<CPointer<Unit>>(inout result))

        @Expect(hr, E_NOTIMPL.value)
        @Expect(impl.observedClassId, "Windows.Test.Activation")
        @Expect(windows_core.debugObservedHStringFreeCount() - freeBefore, 1)
        @Expect(result.isNull(), true)
    } finally {
        windows_core.releaseSystemHStringHandle(classIdRaw)
        source.close()
    }
}

@Test
func testGetActivationFactoryThunkTranslatesThrownExceptionsAndClearsOutput() {
    let impl = ActivationFactoryThunkCleanupImpl()
    let source = windows_core.HString("Windows.Test.Activation")
    let classIdRaw = source.toSystemHandleCopy()
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(123i32) }
    var result = CPointer<Unit>(sentinel)

    try {
        impl.throwWindows = true
        let windowsHr = impl.__winrtThunk_GetActivationFactory(classIdRaw, CPointer<CPointer<Unit>>(inout result))
        @Expect(windowsHr, E_NOTIMPL.value)
        @Expect(result.isNull(), true)

        impl.throwWindows = false
        impl.throwPlain = true
        result = CPointer<Unit>(sentinel)
        let plainHr = impl.__winrtThunk_GetActivationFactory(classIdRaw, CPointer<CPointer<Unit>>(inout result))
        @Expect(plainHr, E_FAIL.value)
        @Expect(result.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue(sentinel) }
        windows_core.releaseSystemHStringHandle(classIdRaw)
        source.close()
    }
}

@Test
func testGetActivationFactoryVtblNoneBranchClearsOutput() {
    let vtbl = IGetActivationFactoryVtbl.new<ActivationFactoryThunkCleanupImpl>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IGetActivationFactoryVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IGetActivationFactoryVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(456i32) }
    let source = windows_core.HString("Windows.Test.Activation")
    let classIdRaw = source.toSystemHandleCopy()
    var result = CPointer<Unit>(sentinel)

    try {
        let hr = unsafe { vtbl.GetActivationFactory(
            CPointer<Unit>(objectHandle),
            classIdRaw,
            CPointer<CPointer<Unit>>(inout result)
        ) }

        @Expect(hr, E_NOINTERFACE.value)
        @Expect(result.isNull(), true)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        windows_core.releaseSystemHStringHandle(classIdRaw)
        source.close()
    }
}
