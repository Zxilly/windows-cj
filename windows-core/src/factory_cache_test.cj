package windows_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testLoadFactoryByNameReturnsResultForMissingClass() {
    let result = loadFactoryByName("Windows.Cangjie.MissingActivationClass", IUnknown.descriptor())

    @Expect(result.isErr(), true)
}
