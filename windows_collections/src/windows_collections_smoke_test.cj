package windows_collections

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Real WinRT smoke: build a stock IVectorView<Int32> as a projected COM object and
// round-trip Size/GetAt/IndexOf across the generated vtbl ABI. Exercises the actual
// projection path (createStockInterfaceMulti -> descriptor -> vtbl call), not constants.
@Test
func testStockInt32VectorViewRoundTripsThroughProjection() {
    let view = toVectorView(ArrayList<Int32>([10i32, 20i32, 30i32]))
    try {
        @Expect(unsafe { view.Size() }, 3u32)
        @Expect(unsafe { view.GetAt(0u32) }, 10i32)
        @Expect(unsafe { view.GetAt(1u32) }, 20i32)
        @Expect(unsafe { view.GetAt(2u32) }, 30i32)

        var foundIndex = 99u32
        @Expect(unsafe { view.IndexOf(20i32, CPointer<UInt32>(inout foundIndex)) }, true)
        @Expect(foundIndex, 1u32)

        var missingIndex = 99u32
        @Expect(unsafe { view.IndexOf(40i32, CPointer<UInt32>(inout missingIndex)) }, false)
        @Expect(missingIndex, 0u32)
    } finally {
        view.close()
    }
}
