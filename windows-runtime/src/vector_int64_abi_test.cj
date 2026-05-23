package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, S_OK}

func createInt64VectorFixture(items: ArrayList<Int64>): GenericVectorAbiTestFixture<Int64> {
    makeGenericVectorFixture<Int64>(
        items,
        { => IVectorVtbl.newInt64<GenericVectorAbiTestImpl<Int64>>() },
        { a: Int64, b: Int64 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Int64>(buffer, count) }
    )
}

func createGenericBuilderInt64VectorFixture(items: ArrayList<Int64>): GenericVectorAbiTestFixture<Int64> {
    makeGenericVectorFixture<Int64>(
        items,
        { => IVectorVtbl.new<GenericVectorAbiTestImpl<Int64>, Int64>() },
        { a: Int64, b: Int64 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Int64>(buffer, count) }
    )
}

@Test
func testInt64VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createInt64VectorFixture(ArrayList<Int64>([4i64, 6i64]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    @Expect(unsafe { vector.GetAt(1u32) }, 6i64)
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4i64, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i64, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Int64) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, 40i64) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, 40i64)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Int64) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 1u32, 50i64) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(1u32) }, 50i64)

    let directAppend = CFunc<(CPointer<Unit>, Int64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 60i64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(3u32) }, 60i64)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}

@Test
func testGenericInt64VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderInt64VectorFixture(ArrayList<Int64>([4i64, 6i64]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int64, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe { directIndexOf(
        vector.asRaw(),
        6i64,
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i64, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directAppend = CFunc<(CPointer<Unit>, Int64) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 7i64) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 7i64)

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}
