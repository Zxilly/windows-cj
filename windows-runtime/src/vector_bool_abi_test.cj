package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.S_OK

func createBoolVectorFixture(items: ArrayList<Bool>): GenericVectorAbiTestFixture<Bool> {
    makeGenericVectorFixture<Bool>(
        items,
        { => IVectorVtbl.newBool<GenericVectorAbiTestImpl<Bool>>() },
        { a: Bool, b: Bool => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Bool>(buffer, count) }
    )
}

func createGenericBuilderBoolVectorFixture(items: ArrayList<Bool>): GenericVectorAbiTestFixture<Bool> {
    makeGenericVectorFixture<Bool>(
        items,
        { => IVectorVtbl.new<GenericVectorAbiTestImpl<Bool>, Bool>() },
        { a: Bool, b: Bool => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Bool>(buffer, count) }
    )
}

func createGenericBuilderBoolVectorView(items: ArrayList<Bool>): IVectorView<Bool> {
    makeGenericVectorView<Bool>(
        items,
        { => IVectorViewVtbl.new<GenericVectorViewAbiTestImpl<Bool>, Bool>() },
        { a: Bool, b: Bool => a == b }
    )
}

@Test
func testBoolVectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createBoolVectorFixture(ArrayList<Bool>([true, false]))
    let vector = fixture.vector

    @Expect(unsafe { vector.GetAt(0u32) }, true)
    @Expect(unsafe { vector.GetAt(1u32) }, false)
    unsafe { vector.SetAt(1u32, true) }
    @Expect(unsafe { vector.GetAt(1u32) }, true)
    unsafe { vector.InsertAt(1u32, false) }
    @Expect(unsafe { vector.GetAt(1u32) }, false)
    unsafe { vector.Append(true) }
    @Expect(unsafe { vector.Size() }, 4u32)

    var index = 99u32
    @Expect(unsafe { vector.IndexOf(false, CPointer<UInt32>(inout index)) }, true)
    @Expect(index, 1u32)

    let vtbl = unsafe { vector.vtbl() }
    let directSetAt = CFunc<(CPointer<Unit>, UInt32, Bool) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe { directSetAt(vector.asRaw(), 0u32, false) }
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, false)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, Bool) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe { directInsertAt(vector.asRaw(), 0u32, true) }
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(0u32) }, true)

    let directAppend = CFunc<(CPointer<Unit>, Bool) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), false) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(unsafe { vector.Size() } - 1u32) }, false)

    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Bool, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let indexOfHr = unsafe { directIndexOf(vector.asRaw(), false, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound)) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    fixture.close()
}

@Test
func testGenericBoolVectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderBoolVectorFixture(ArrayList<Bool>([false]))
    let vector = fixture.vector

    unsafe { vector.Append(true) }
    @Expect(unsafe { vector.GetAt(1u32) }, true)

    let vtbl = unsafe { vector.vtbl() }
    let directAppend = CFunc<(CPointer<Unit>, Bool) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), false) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }, false)

    fixture.close()
}

@Test
func testGenericBoolVectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderBoolVectorView(ArrayList<Bool>([true, false]))

    var directIndex = 99u32
    var directFound = false
    let vtbl = unsafe { view.vtbl() }
    let directIndexOf = CFunc<(CPointer<Unit>, Bool, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.IndexOf))
    let indexOfHr = unsafe { directIndexOf(view.asRaw(), false, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound)) }
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    view.close()
}
