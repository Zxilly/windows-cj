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
