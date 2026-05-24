package windows_collections
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, S_OK}

func createUInt8VectorFixture(items: ArrayList<UInt8>): GenericVectorAbiTestFixture<UInt8> {
    makeGenericVectorFixture<UInt8>(
        items,
        { => IVectorVtbl.newUInt8<GenericVectorAbiTestImpl<UInt8>>() },
        { a: UInt8, b: UInt8 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<UInt8>(buffer, count) }
    )
}

func createGenericBuilderUInt8VectorFixture(items: ArrayList<UInt8>): GenericVectorAbiTestFixture<UInt8> {
    makeGenericVectorFixture<UInt8>(
        items,
        { => IVectorVtbl.new<GenericVectorAbiTestImpl<UInt8>, UInt8>() },
        { a: UInt8, b: UInt8 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<UInt8>(buffer, count) }
    )
}

@Test
func testUInt8VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createUInt8VectorFixture(ArrayList<UInt8>([4u8, 6u8]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    @Expect(unsafe { vector.GetAt(1u32) }, 6u8)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4u8, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt8, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6u8,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6u8, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, UInt8) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40u8) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40u8)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, UInt8) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50u8) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50u8)

    let directAppend = CFunc<(CPointer<Unit>, UInt8) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60u8) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60u8)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}

@Test
func testGenericUInt8VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderUInt8VectorFixture(ArrayList<UInt8>([4u8, 6u8]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, UInt8, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6u8,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6u8, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directAppend = CFunc<(CPointer<Unit>, UInt8) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 7u8) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 7u8)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}
