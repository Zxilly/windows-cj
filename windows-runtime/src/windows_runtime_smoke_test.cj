package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{HString, Result}
import windows_core as windows_core
import windows_interface.{IActivationFactory, IInspectable}

class MissingActivationFactorySmokeClass <: windows_core.RuntimeName {
    public static func runtimeName(): String {
        "Windows.Foundation.CangjieMissingActivationFactorySmokeClass"
    }
}

func smokePropertyValueFromInspectable(value: IInspectable): IPropertyValue {
    match (unsafe { value.query<IPropertyValue>(IPropertyValue.descriptor()) }) {
        case Some(propertyValue) => propertyValue
        case None => throw Exception("PropertyValue smoke: QueryInterface(IPropertyValue) failed")
    }
}

@Test
func testRealActivationFactoryReportsUnavailableClass() {
    match (windows_core.activationFactory<MissingActivationFactorySmokeClass>()) {
        case Result<IActivationFactory>.Ok(factory) =>
            factory.close()
            throw Exception("missing activation factory unexpectedly resolved")
        case Result<IActivationFactory>.Err(_) => ()
    }
}

@Test
func testRealPropertyValueInt32ArrayRoundTrip() {
    let boxed = unsafe { PropertyValue.CreateInt32Array([10i32, 20i32, 30i32]) }
    try {
        let propertyValue = smokePropertyValueFromInspectable(boxed)
        try {
            let values = unsafe { propertyValue.GetInt32Array() }
            @Expect(values.size, 3)
            @Expect(values[0], 10i32)
            @Expect(values[1], 20i32)
            @Expect(values[2], 30i32)
        } finally {
            propertyValue.close()
        }
    } finally {
        boxed.close()
    }
}

@Test
func testRealUriDecoderRoundTripsHStringAndCollectionProjection() {
    let uriText = HString("https://example.com/path?x=1&y=two")
    let key = HString("y")
    let uri = unsafe { Uri.CreateUri(uriText) }
    try {
        let absolute = unsafe { uri.AbsoluteUri() }
        try {
            @Expect(absolute.get(), "https://example.com/path?x=1&y=two")
        } finally {
            absolute.close()
        }

        let decoder = unsafe { uri.QueryParsed() }
        try {
            let value = unsafe { decoder.GetFirstValueByName(key) }
            try {
                @Expect(value.get(), "two")
            } finally {
                value.close()
            }

            @Expect(unsafe { decoder.Size() }, 2u32)
            let firstEntry = unsafe { decoder.GetAt(0u32) }
            try {
                let name = unsafe { firstEntry.Name() }
                let firstValue = unsafe { firstEntry.Value() }
                try {
                    @Expect(name.get(), "x")
                    @Expect(firstValue.get(), "1")
                } finally {
                    firstValue.close()
                    name.close()
                }
            } finally {
                firstEntry.close()
            }
        } finally {
            decoder.close()
        }
    } finally {
        uri.close()
        key.close()
        uriText.close()
    }
}
