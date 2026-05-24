package windows_collections
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, S_OK}

func createInt16VectorFixture(items: ArrayList<Int16>): GenericVectorAbiTestFixture<Int16> {
    makeGenericVectorFixture<Int16>(
        items,
        { => IVectorVtbl.newInt16<GenericVectorAbiTestImpl<Int16>>() },
        { a: Int16, b: Int16 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Int16>(buffer, count) }
    )
}

func createGenericBuilderInt16VectorFixture(items: ArrayList<Int16>): GenericVectorAbiTestFixture<Int16> {
    makeGenericVectorFixture<Int16>(
        items,
        { => IVectorVtbl.new<GenericVectorAbiTestImpl<Int16>, Int16>() },
        { a: Int16, b: Int16 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Int16>(buffer, count) }
    )
}

@Test
func testInt16VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createInt16VectorFixture(ArrayList<Int16>([4i16, 6i16]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    @Expect(unsafe { vector.GetAt(1u32) }, 6i16)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4i16, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i16, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Int16) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40i16) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40i16)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Int16) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50i16) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50i16)

    let directAppend = CFunc<(CPointer<Unit>, Int16) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60i16) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60i16)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}

@Test
func testGenericInt16VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderInt16VectorFixture(ArrayList<Int16>([4i16, 6i16]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int16, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6i16,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i16, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directAppend = CFunc<(CPointer<Unit>, Int16) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 7i16) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 7i16)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}
