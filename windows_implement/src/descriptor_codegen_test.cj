package windows_implement

import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*

@Test
func testGeneratedWrapperViewOfDisablesManualRelease() {
    let schema = InterfaceDescriptorSchema(
        "Fixture.IView",
        GUID.parse("12121212-3434-5656-7878-909090909090"),
        IUnknown.descriptorSchema(),
        "Fixture_IViewVtbl",
        "Fixture_IView",
        "Fixture_IView_Impl",
        []
    )

    let source = renderDescriptor(resolveSchema(schema))

    @Expect(source.contains("private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {\n        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)\n    }"), true)
    @Expect(source.contains("public static func viewOf(raw: CPointer<Unit>): Fixture_IView {\n        Fixture_IView(raw, takeOwnership: false, allowManualRelease: false)\n    }"), true)
    @Expect(source.contains("public static func fromAbiTake(raw: CPointer<Unit>): Fixture_IView {\n        Fixture_IView(raw, takeOwnership: true, allowManualRelease: false)\n    }"), true)
    @Expect(source.contains("public static func viewOf(raw: CPointer<Unit>): Fixture_IView {\n        Fixture_IView(raw)\n    }"), false)
    @Expect(source.contains("public func asIUnknown(): IUnknown {\n        IUnknown.viewOf(asRaw())\n    }"), true)
    @Expect(source.contains("public func asIUnknown(): IUnknown {\n        IUnknown(asRaw())\n    }"), false)
}

@Test
func testGeneratedThunkProjectsInParamBeforeDispatch() {
    let schema = InterfaceDescriptorSchema(
        "Fixture.IInput",
        GUID.parse("22222222-3434-5656-7878-909090909090"),
        IUnknown.descriptorSchema(),
        "Fixture_IInputVtbl",
        "Fixture_IInput",
        "Fixture_IInput_Impl",
        [
            InterfaceMethodSchema(
                "Input",
                3,
                [
                    InterfaceParameterSchema(
                        "input",
                        "CPointer<Unit>",
                        "InParam<Fixture_IInput>",
                        InterfaceParameterBridgeKind.InParam
                    ),
                    InterfaceParameterSchema(
                        "result",
                        "CPointer<Int32>",
                        "OutSlot<Int32>",
                        InterfaceParameterBridgeKind.OutSlot
                    )
                ],
                "Int32"
            ),
            InterfaceMethodSchema(
                "InputStatus",
                4,
                [
                    InterfaceParameterSchema(
                        "status",
                        "Fixture_StatusAbi",
                        "InParam<Fixture_Status>",
                        InterfaceParameterBridgeKind.InParam
                    ),
                    InterfaceParameterSchema(
                        "result",
                        "CPointer<Int32>",
                        "OutSlot<Int32>",
                        InterfaceParameterBridgeKind.OutSlot
                    )
                ],
                "Int32"
            ),
            InterfaceMethodSchema(
                "InputString",
                5,
                [
                    InterfaceParameterSchema(
                        "text",
                        "CPointer<Unit>",
                        "InParam<windows_core.HString>",
                        InterfaceParameterBridgeKind.InParam
                    ),
                    InterfaceParameterSchema(
                        "result",
                        "CPointer<Int32>",
                        "OutSlot<Int32>",
                        InterfaceParameterBridgeKind.OutSlot
                    )
                ],
                "Int32"
            ),
            InterfaceMethodSchema(
                "InputStringPair",
                6,
                [
                    InterfaceParameterSchema(
                        "left",
                        "CPointer<Unit>",
                        "InParam<windows_core.HString>",
                        InterfaceParameterBridgeKind.InParam
                    ),
                    InterfaceParameterSchema(
                        "right",
                        "CPointer<Unit>",
                        "InParam<windows_core.HString>",
                        InterfaceParameterBridgeKind.InParam
                    ),
                    InterfaceParameterSchema(
                        "result",
                        "CPointer<Int32>",
                        "OutSlot<Int32>",
                        InterfaceParameterBridgeKind.OutSlot
                    )
                ],
                "Int32"
            )
        ]
    )

    let source = renderDescriptor(resolveSchema(schema))

    @Expect(source.contains("qualifiedImpl.Input(input)"), false)
    @Expect(source.contains("qualifiedImpl.Input(if (input.isNull()) { InParam<Fixture_IInput>() } else { InParam<Fixture_IInput>(Fixture_IInput.viewOf(input)) })"), true)
    @Expect(source.contains("qualifiedImpl.InputStatus(status)"), false)
    @Expect(source.contains("qualifiedImpl.InputStatus(InParam<Fixture_Status>(windows_core.assumeInitTypedAbi(status, windows_core.typeMarker<Fixture_Status>())))"), true)
    @Expect(source.contains("qualifiedImpl.InputString(InParam<windows_core.HString>(windows_core.HString.fromSystemHandleCopy(text)))"), false)
    @Expect(source.contains("windows_core.withHStringInParam(text, { text__inParam =>"), true)
    @Expect(source.contains("qualifiedImpl.InputString(text__inParam)"), true)
    @Expect(source.contains("windows_core.withHStringInParam(left, { left__inParam =>"), true)
    @Expect(source.contains("windows_core.withHStringInParam(right, { right__inParam =>"), true)
    @Expect(source.contains("qualifiedImpl.InputStringPair(left__inParam, right__inParam)"), true)
}

@Test
func testGeneratedResultBridgeCleansFailedPointerOutputs() {
    let schema = InterfaceDescriptorSchema(
        "Fixture.IOutput",
        GUID.parse("33333333-3434-5656-7878-909090909090"),
        IUnknown.descriptorSchema(),
        "Fixture_IOutputVtbl",
        "Fixture_IOutput",
        "Fixture_IOutput_Impl",
        [
            InterfaceMethodSchema(
                "Create",
                3,
                [
                    InterfaceParameterSchema(
                        "result",
                        "CPointer<CPointer<Unit>>",
                        "OutSlot<Fixture_IOutput>",
                        InterfaceParameterBridgeKind.OutSlot
                    )
                ],
                "Int32"
            )
        ]
    )

    let source = renderDescriptor(resolveSchema(schema))

    @Expect(source.contains("public interface Fixture_IOutput_ImplErased"), true)
    @Expect(source.contains("public interface Fixture_IOutput_Impl <: Fixture_IOutput_ImplErased"), true)
    @Expect(source.contains("Fixture_IOutput_Impl <: IUnknown_Impl"), false)
    @Expect(source.contains("let hr = v.Create(asRaw(), CPointer<CPointer<Unit>>(inout result))\n        if (windows_result.HRESULT(hr).failed() && result.isNotNull()) {\n            let _ = Fixture_IOutput.descriptor().releasePointer(result)\n            result = CPointer<Unit>()\n        }\n        windows_result.HRESULT(hr).check()\n        return Fixture_IOutput.fromAbiTake(result)"), true)
    @Expect(source.contains("if (result__.isNull()) {\n        return E_POINTER\n    }\n    unsafe { result__.write(CPointer<Unit>()) }"), true)
    @Expect(source.contains("Fixture_IOutput_CreateThunk"), true)
    @Expect(source.contains("Fixture.IOutput_CreateThunk"), false)
    @Expect(source.contains("extend Fixture_IOutput <: windows_core.Interface<Fixture_IOutput> {}"), true)
    @Expect(source.contains("windows_core.winrtStoreGenericOut<Fixture_IOutput>(result__, value)"), true)
    @Expect(source.contains("try {"), true)
    @Expect(source.contains("asImplFromRaw<"), true)
    @Expect(source.contains("catch (error: windows_result.WindowsException) {\n        unsafe { result__.write(CPointer<Unit>()) }\n        error.code().value\n    } catch (_: Exception) {\n        unsafe { result__.write(CPointer<Unit>()) }\n        windows_result.E_FAIL.value\n    }"), true)
    @Expect(source.contains("value.intoAbi()"), false)
    @Expect(source.contains("value.asAbiPointer()"), false)
}

@Test
func testGeneratedNonResultThunkTranslatesThrownExceptions() {
    let schema = InterfaceDescriptorSchema(
        "Fixture.IAction",
        GUID.parse("34343434-5656-7878-9090-111111111111"),
        IUnknown.descriptorSchema(),
        "Fixture_IActionVtbl",
        "Fixture_IAction",
        "Fixture_IAction_Impl",
        [
            InterfaceMethodSchema(
                "Invoke",
                3,
                [],
                "Int32"
            )
        ]
    )

    let source = renderDescriptor(resolveSchema(schema))

    @Expect(source.contains("public func Fixture_IAction_InvokeThunk(instanceRaw: CPointer<Unit>): Int32"), true)
    @Expect(source.contains("catch (error: windows_result.WindowsException) {\n        error.code().value\n    } catch (_: Exception) {\n        windows_result.E_FAIL.value\n    }"), true)
    @Expect(source.contains("releaseFailedComOutSlot"), false)
    @Expect(source.contains("result__.write"), false)
}

@Test
func testGeneratedDescriptorRejectsRawPointerResultBridgeForComInterfaces() {
    let schema = InterfaceDescriptorSchema(
        "Fixture.IRawOutput",
        GUID.parse("44444444-3434-5656-7878-909090909090"),
        IUnknown.descriptorSchema(),
        "Fixture_IRawOutputVtbl",
        "Fixture_IRawOutput",
        "Fixture_IRawOutput_Impl",
        [
            InterfaceMethodSchema(
                "CreateRaw",
                3,
                [
                    InterfaceParameterSchema(
                        "result",
                        "CPointer<CPointer<Unit>>",
                        "OutSlot<CPointer<Unit>>",
                        InterfaceParameterBridgeKind.OutSlot
                    )
                ],
                "Int32"
            )
        ]
    )

    var rejected = false
    try {
        let _ = renderDescriptor(resolveSchema(schema))
    } catch (e: IllegalArgumentException) {
        rejected = true
        @Expect(e.message.contains("raw pointer result bridge"), true)
    }
    @Expect(rejected, true)
}

@Test
func testGeneratedDescriptorRejectsDirectPointerReturnForComInterfaces() {
    let schema = InterfaceDescriptorSchema(
        "Fixture.IRawReturn",
        GUID.parse("55555555-3434-5656-7878-909090909090"),
        IUnknown.descriptorSchema(),
        "Fixture_IRawReturnVtbl",
        "Fixture_IRawReturn",
        "Fixture_IRawReturn_Impl",
        [
            InterfaceMethodSchema(
                "CurrentRaw",
                3,
                [],
                "CPointer<Unit>"
            )
        ]
    )

    var rejected = false
    try {
        let _ = renderDescriptor(resolveSchema(schema))
    } catch (e: IllegalArgumentException) {
        rejected = true
        @Expect(e.message.contains("directly returns CPointer<Unit>"), true)
    }
    @Expect(rejected, true)
}
