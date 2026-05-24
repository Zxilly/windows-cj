package windows_collections
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.S_OK

func createInt64VectorView(items: ArrayList<Int64>): IVectorView<Int64> {
    makeGenericVectorView<Int64>(
        items,
        { => IVectorViewVtbl.newInt64<GenericVectorViewAbiTestImpl<Int64>>() },
        { a: Int64, b: Int64 => a == b }
    )
}

func createGenericBuilderInt64VectorView(items: ArrayList<Int64>): IVectorView<Int64> {
    makeGenericVectorView<Int64>(
        items,
        { => IVectorViewVtbl.new<GenericVectorViewAbiTestImpl<Int64>, Int64>() },
        { a: Int64, b: Int64 => a == b }
    )
}

@Test
func testInt64VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createInt64VectorView(ArrayList<Int64>([4i64, 6i64]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4i64, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericInt64VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderInt64VectorView(ArrayList<Int64>([7i64, 9i64]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
