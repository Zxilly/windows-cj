package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOTIMPL, InParam, Result, WinError}
import windows_core as windows_core
import windows_interface.IInspectable

class ActivationFactoryThunkCleanupImpl <: IGetActivationFactory_Impl {
    public var observedClassId: String = ""

    public func GetActivationFactory(activatableClassId: InParam<windows_core.HString>): Result<IInspectable> {
        observedClassId = activatableClassId.get().get()
        Result<IInspectable>.Err(WinError.fromHRESULT(E_NOTIMPL))
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
