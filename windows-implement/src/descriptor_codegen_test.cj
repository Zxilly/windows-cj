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

    @Expect(source.contains("let hr = v.Create(asRaw(), CPointer<CPointer<Unit>>(inout result))\n        if (windows_result.HRESULT(hr).failed() && result.isNotNull()) {\n            let _ = Fixture_IOutput.descriptor().releasePointer(result)\n            result = CPointer<Unit>()\n        }\n        windows_result.HRESULT(hr).check()\n        return Fixture_IOutput.fromAbiTake(result)"), true)
    @Expect(source.contains("if (result__.isNull()) {\n        return E_POINTER\n    }\n    unsafe { result__.write(CPointer<Unit>()) }"), true)
}
