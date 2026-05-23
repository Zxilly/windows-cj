package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, S_OK}

func createGenericBuilderInt32VectorFixture(values: ArrayList<Int32>): GenericVectorAbiTestFixture<Int32> {
    makeGenericVectorFixture<Int32>(
        values,
        { => IVectorVtbl.new<GenericVectorAbiTestImpl<Int32>, Int32>() },
        { a: Int32, b: Int32 => a == b },
        { buffer: CPointer<Unit>, count: UInt32 => readDirectValueBuffer<Int32>(buffer, count) }
    )
}

func createGenericBuilderInt32VectorView(values: ArrayList<Int32>): IVectorView<Int32> {
    makeGenericVectorView<Int32>(
        values,
        { => IVectorViewVtbl.new<GenericVectorViewAbiTestImpl<Int32>, Int32>() },
        { a: Int32, b: Int32 => a == b }
    )
}

@Test
func testGenericInt32VectorBuilderUsesDirectValueAbiForSpecialization() {
    let fixture = createGenericBuilderInt32VectorFixture(ArrayList<Int32>([1i32, 3i32]))
    let vector = fixture.vector

    unsafe { vector.SetAt(0u32, 2i32) }
    unsafe { vector.InsertAt(1u32, 4i32) }
    unsafe { vector.Append(6i32) }
    @Expect(unsafe { vector.GetAt(0u32) }, 2i32)
    @Expect(unsafe { vector.GetAt(1u32) }, 4i32)
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

    let directReplaceAll = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.ReplaceAll))
    let replaceHandle = unsafe { acquireArrayRawData(Array<Int32>(3, { i => Int32(i) + 11i32 })) }
    try {
        let replaceHr = unsafe { directReplaceAll(vector.asRaw(), 3u32, CPointer<Unit>(replaceHandle.pointer)) }
        @Expect(replaceHr, S_OK.value)
    } finally {
        unsafe { releaseArrayRawData(replaceHandle) }
    }
    @Expect(unsafe { vector.Size() }, 3u32)
    @Expect(unsafe { vector.GetAt(0u32) }, 11i32)
    @Expect(unsafe { vector.GetAt(1u32) }, 12i32)
    @Expect(unsafe { vector.GetAt(2u32) }, 13i32)

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let outputHandle = unsafe { acquireArrayRawData(Array<Int32>(3, { _ => 0i32 })) }
    try {
        let output = CPointer<Int32>(outputHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(vector.asRaw(), 0u32, 3u32, CPointer<Unit>(output), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 3u32)
        @Expect(unsafe { output.read() }, 11i32)
        @Expect(unsafe { (output + 1).read() }, 12i32)
        @Expect(unsafe { (output + 2).read() }, 13i32)
    } finally {
        unsafe { releaseArrayRawData(outputHandle) }
    }

    let nullReplaceHr = unsafe { directReplaceAll(vector.asRaw(), 1u32, CPointer<Unit>()) }
    @Expect(nullReplaceHr, E_POINTER.value)

    fixture.close()
}

@Test
func testGenericInt32VectorViewBuilderUsesDirectValueAbiForSpecialization() {
    let view = createGenericBuilderInt32VectorView(ArrayList<Int32>([1i32, 3i32, 5i32]))

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(3i32, CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(view.asRaw(), 5i32, CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 2u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {
        directIndexOf(view.asRaw(), 5i32, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let outputHandle = unsafe { acquireArrayRawData(Array<Int32>(2, { _ => 0i32 })) }
    try {
        let output = CPointer<Int32>(outputHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(view.asRaw(), 1u32, 2u32, CPointer<Unit>(output), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 2u32)
        @Expect(unsafe { output.read() }, 3i32)
        @Expect(unsafe { (output + 1).read() }, 5i32)
    } finally {
        unsafe { releaseArrayRawData(outputHandle) }
    }

    view.close()
}
