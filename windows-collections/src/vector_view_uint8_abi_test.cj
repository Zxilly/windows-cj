package windows_collections
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.S_OK

func createUInt8VectorView(items: ArrayList<UInt8>): IVectorView<UInt8> {
    makeGenericVectorView<UInt8>(
        items,
        { => IVectorViewVtbl.newUInt8<GenericVectorViewAbiTestImpl<UInt8>>() },
        { a: UInt8, b: UInt8 => a == b }
    )
}

func createGenericBuilderUInt8VectorView(items: ArrayList<UInt8>): IVectorView<UInt8> {
    makeGenericVectorView<UInt8>(
        items,
        { => IVectorViewVtbl.new<GenericVectorViewAbiTestImpl<UInt8>, UInt8>() },
        { a: UInt8, b: UInt8 => a == b }
    )
}

@Test
func testUInt8VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createUInt8VectorView(ArrayList<UInt8>([4u8, 6u8]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4u8, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt8, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6u8,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericUInt8VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderUInt8VectorView(ArrayList<UInt8>([7u8, 9u8]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt8, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7u8,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
