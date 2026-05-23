package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.S_OK

func createInt16VectorView(items: ArrayList<Int16>): IVectorView<Int16> {
    makeGenericVectorView<Int16>(
        items,
        { => IVectorViewVtbl.newInt16<GenericVectorViewAbiTestImpl<Int16>>() },
        { a: Int16, b: Int16 => a == b }
    )
}

func createGenericBuilderInt16VectorView(items: ArrayList<Int16>): IVectorView<Int16> {
    makeGenericVectorView<Int16>(
        items,
        { => IVectorViewVtbl.new<GenericVectorViewAbiTestImpl<Int16>, Int16>() },
        { a: Int16, b: Int16 => a == b }
    )
}

@Test
func testInt16VectorViewUsesDirectValueAbiForIndexOf() {
    let view = createInt16VectorView(ArrayList<Int16>([4i16, 6i16]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(4i16, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        6i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}

@Test
func testGenericInt16VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderInt16VectorView(ArrayList<Int16>([7i16, 9i16]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
