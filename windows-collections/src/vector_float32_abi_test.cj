package windows_collections
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.S_OK

func createFloat32VectorFixture(items: ArrayList<Float32>): GenericVectorAbiTestFixture<Float32> {
    makeGenericVectorFixture<Float32>(
        items,
        { => IVectorVtbl.newFloat32<GenericVectorAbiTestImpl<Float32>>() },
        { a: Float32, b: Float32 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Float32>(buffer, count) }
    )
}

func createGenericBuilderFloat32VectorFixture(items: ArrayList<Float32>): GenericVectorAbiTestFixture<Float32> {
    makeGenericVectorFixture<Float32>(
        items,
        { => IVectorVtbl.new<GenericVectorAbiTestImpl<Float32>, Float32>() },
        { a: Float32, b: Float32 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Float32>(buffer, count) }
    )
}

func createGenericBuilderFloat32VectorView(items: ArrayList<Float32>): IVectorView<Float32> {
    makeGenericVectorView<Float32>(
        items,
        { => IVectorViewVtbl.new<GenericVectorViewAbiTestImpl<Float32>, Float32>() },
        { a: Float32, b: Float32 => a == b }
    )
}

@Test
func testFloat32VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createFloat32VectorFixture(ArrayList<Float32>([4.5f32, 6.25f32]))
    let vector = fixture.vector

    @Expect(unsafe { vector.GetAt(1u32) }, 6.25f32)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4.5f32, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6.25f32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Float32) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40.5f32) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40.5f32)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Float32) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50.5f32) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50.5f32)

    let directAppend = CFunc<(CPointer<Unit>, Float32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60.5f32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60.5f32)

    fixture.close()
}

@Test
func testGenericFloat32VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderFloat32VectorFixture(ArrayList<Float32>([1.25f32, 2.5f32]))
    let vector = fixture.vector

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        2.5f32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    let directAppend = CFunc<(CPointer<Unit>, Float32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 3.75f32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 3.75f32)

    fixture.close()
}

@Test
func testGenericFloat32VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderFloat32VectorView(ArrayList<Float32>([7.25f32, 9.5f32]))

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Float32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        view.asRaw(),
        7.25f32,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 0u32)

    view.close()
}
