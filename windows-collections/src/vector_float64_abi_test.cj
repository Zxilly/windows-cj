package windows_collections
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.S_OK

func createFloat64VectorFixture(items: ArrayList<Float64>): GenericVectorAbiTestFixture<Float64> {
    makeGenericVectorFixture<Float64>(
        items,
        { => IVectorVtbl.newFloat64<GenericVectorAbiTestImpl<Float64>>() },
        { a: Float64, b: Float64 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Float64>(buffer, count) }
    )
}

func createGenericBuilderFloat64VectorFixture(items: ArrayList<Float64>): GenericVectorAbiTestFixture<Float64> {
    makeGenericVectorFixture<Float64>(
        items,
        { => IVectorVtbl.new<GenericVectorAbiTestImpl<Float64>, Float64>() },
        { a: Float64, b: Float64 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Float64>(buffer, count) }
    )
}

func createGenericBuilderFloat64VectorView(items: ArrayList<Float64>): IVectorView<Float64> {
    makeGenericVectorView<Float64>(
        items,
        { => IVectorViewVtbl.new<GenericVectorViewAbiTestImpl<Float64>, Float64>() },
        { a: Float64, b: Float64 => a == b }
    )
}

@Test
func testFloat64VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createFloat64VectorFixture(ArrayList<Float64>([4.5f64, 6.25f64]))
    let vector = fixture.vector

    @Expect(unsafe { vector.GetAt(1u32) }, 6.25f64)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4.5f64, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6.25f64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Float64) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40.5f64) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40.5f64)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Float64) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50.5f64) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50.5f64)

    let directAppend = CFunc<(CPointer<Unit>, Float64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60.5f64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60.5f64)

    fixture.close()
}

@Test
func testGenericFloat64VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderFloat64VectorFixture(ArrayList<Float64>([1.25f64, 2.5f64]))
    let vector = fixture.vector

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        2.5f64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directAppend = CFunc<(CPointer<Unit>, Float64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 3.75f64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 3.75f64)

    fixture.close()
}

@Test
func testGenericFloat64VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderFloat64VectorView(ArrayList<Float64>([7.25f64, 9.5f64]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7.25f64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
