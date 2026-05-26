package windows_collections
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_FAIL, E_POINTER, S_OK}

func createInt32VectorFixture(items: ArrayList<Int32>): GenericVectorAbiTestFixture<Int32> {
    makeGenericVectorFixture<Int32>(
        items,
        { => IVectorVtbl.newInt32<GenericVectorAbiTestImpl<Int32>>() },
        { a: Int32, b: Int32 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Int32>(buffer, count) }
    )
}

@Test
func testInt32VectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createInt32VectorFixture(ArrayList<Int32>([1i32, 3i32]))
    let vector = fixture.vector

    unsafe { vector.SetAt(0u32, 2i32) }
    unsafe { vector.InsertAt(1u32, 4i32) }
    unsafe { vector.Append(6i32) }
    var wrapperIndex = 99u32
    @Expect(unsafe { vector.IndexOf(4i32, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)
    @Expect(unsafe { vector.Size() }, 4u32)
    @Expect(unsafe { vector.GetAt(0u32) }, 2i32)
    @Expect(unsafe { vector.GetAt(3u32) }, 6i32)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i32, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 3u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(vector.asRaw(), 6i32, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Int32) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 2u32, 5i32) }
    @Expect(setHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 5i32)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Int32) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 2u32, 7i32) }
    @Expect(insertHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, 7i32)

    let directAppend = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), 8i32) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(5u32) }, 8i32)

    fixture.close()
}

@Test
func testInt32VectorDirectValueVtableTranslatesThrownExceptions() {
    let fixture = createInt32VectorFixture(ArrayList<Int32>([1i32]))
    let vector = fixture.vector
    let faults = fixture.faults

    let vtbl = unsafe { vector.vtbl() }
    let directIndexOf = CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Int32) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Int32) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let directAppend = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Append))

    faults.throwWindowsOnIndexOf = true
    var directIndex = 123u32
    var directFound = true
    let indexHr = unsafe {
        directIndexOf(vector.asRaw(), 1i32, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, E_POINTER.value)
    @Expect(directIndex, 0u32)
    @Expect(directFound, false)
    faults.throwWindowsOnIndexOf = false

    faults.throwPlainOnSetAt = true
    @Expect(unsafe { directSetAt(vector.asRaw(), 0u32, 2i32) }, E_FAIL.value)
    faults.throwPlainOnSetAt = false

    faults.throwPlainOnInsertAt = true
    @Expect(unsafe { directInsertAt(vector.asRaw(), 0u32, 2i32) }, E_FAIL.value)
    faults.throwPlainOnInsertAt = false

    faults.throwPlainOnAppend = true
    @Expect(unsafe { directAppend(vector.asRaw(), 2i32) }, E_FAIL.value)
    faults.throwPlainOnAppend = false

    fixture.close()
}
