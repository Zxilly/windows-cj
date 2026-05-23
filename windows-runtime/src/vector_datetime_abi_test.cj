package windows_runtime

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_POINTER, S_OK}

func dateTimeTestValue(value: Int64): DateTime {
    var result = DateTime()
    result.UniversalTime = value
    return result
}

func sameDateTimeValue(left: DateTime, right: DateTime): Bool {
    left.UniversalTime == right.UniversalTime
}

func readDateTimeAbiBuffer(buffer: CPointer<Unit>, count: UInt32): ArrayList<DateTime> {
    let result = ArrayList<DateTime>()
    let typed = CPointer<DateTimeAbi>(buffer)
    var offset = 0u32
    while (offset < count) {
        result.add(DateTime.assumeInitRef(unsafe { (typed + Int64(offset)).read() }))
        offset += 1u32
    }
    result
}

func createDateTimeVectorFixture(items: ArrayList<DateTime>): GenericVectorAbiTestFixture<DateTime> {
    makeGenericVectorFixture<DateTime>(
        items,
        { => IVectorVtbl.newDateTime<GenericVectorAbiTestImpl<DateTime>>() },
        sameDateTimeValue,
        readDateTimeAbiBuffer
    )
}

func createDateTimeVectorView(items: ArrayList<DateTime>): IVectorView<DateTime> {
    makeGenericVectorView<DateTime>(
        items,
        { => IVectorViewVtbl.newDateTime<GenericVectorViewAbiTestImpl<DateTime>>() },
        sameDateTimeValue
    )
}

@Test
func testDateTimeVectorViewUsesDirectValueAbiForSpecialization() {
    let view = createDateTimeVectorView(
        ArrayList<DateTime>([dateTimeTestValue(10i64), dateTimeTestValue(20i64), dateTimeTestValue(30i64)])
    )

    var wrapperIndex = 99u32
    @Expect(unsafe { view.IndexOf(dateTimeTestValue(20i64), CPointer<UInt32>(inout wrapperIndex)) }, true)
    @Expect(wrapperIndex, 1u32)

    let vtbl = unsafe { view.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, DateTimeAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(view.asRaw(), DateTime.projectAbi(dateTimeTestValue(30i64)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 2u32)

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let outputHandle = unsafe { acquireArrayRawData(Array<DateTimeAbi>(2, { _ => DateTimeAbi() })) }
    try {
        let output = CPointer<DateTimeAbi>(outputHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(view.asRaw(), 1u32, 2u32, CPointer<Unit>(output), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 2u32)
        @Expect(DateTime.assumeInitRef(unsafe { output.read() }).UniversalTime, 20i64)
        @Expect(DateTime.assumeInitRef(unsafe { (output + 1).read() }).UniversalTime, 30i64)
    } finally {
        unsafe { releaseArrayRawData(outputHandle) }
    }

    view.close()
}

@Test
func testDateTimeVectorUsesDirectValueAbiForMutableSlots() {
    let fixture = createDateTimeVectorFixture(
        ArrayList<DateTime>([dateTimeTestValue(1i64), dateTimeTestValue(3i64)])
    )
    let vector = fixture.vector

    unsafe { vector.SetAt(0u32, dateTimeTestValue(2i64)) }
    unsafe { vector.InsertAt(1u32, dateTimeTestValue(4i64)) }
    unsafe { vector.Append(dateTimeTestValue(6i64)) }
    @Expect(unsafe { vector.GetAt(0u32) }.UniversalTime, 2i64)
    @Expect(unsafe { vector.GetAt(1u32) }.UniversalTime, 4i64)
    @Expect(unsafe { vector.GetAt(3u32) }.UniversalTime, 6i64)

    let vtbl = unsafe { vector.vtbl() }
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, DateTimeAbi, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexHr = unsafe {
        directIndexOf(vector.asRaw(), DateTime.projectAbi(dateTimeTestValue(6i64)), CPointer<UInt32>(inout directIndex), CPointer<Bool>(inout directFound))
    }
    @Expect(indexHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 3u32)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, DateTimeAbi) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setHr = unsafe { directSetAt(vector.asRaw(), 2u32, DateTime.projectAbi(dateTimeTestValue(5i64))) }
    @Expect(setHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }.UniversalTime, 5i64)

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, DateTimeAbi) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertHr = unsafe { directInsertAt(vector.asRaw(), 2u32, DateTime.projectAbi(dateTimeTestValue(7i64))) }
    @Expect(insertHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(2u32) }.UniversalTime, 7i64)

    let directAppend = CFunc<(CPointer<Unit>, DateTimeAbi) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe { directAppend(vector.asRaw(), DateTime.projectAbi(dateTimeTestValue(8i64))) }
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe { vector.GetAt(5u32) }.UniversalTime, 8i64)

    let directReplaceAll = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(vtbl.ReplaceAll))
    let replaceHandle = unsafe {
        acquireArrayRawData(Array<DateTimeAbi>(2, { i => DateTime.projectAbi(dateTimeTestValue(Int64(i) + 21i64)) }))
    }
    try {
        let replaceHr = unsafe { directReplaceAll(vector.asRaw(), 2u32, CPointer<Unit>(replaceHandle.pointer)) }
        @Expect(replaceHr, S_OK.value)
    } finally {
        unsafe { releaseArrayRawData(replaceHandle) }
    }
    @Expect(unsafe { vector.Size() }, 2u32)
    @Expect(unsafe { vector.GetAt(0u32) }.UniversalTime, 21i64)
    @Expect(unsafe { vector.GetAt(1u32) }.UniversalTime, 22i64)

    let directGetMany = CFunc<(CPointer<Unit>, UInt32, UInt32, CPointer<Unit>, CPointer<UInt32>) -> Int32>(
        CPointer<Unit>(vtbl.GetMany)
    )
    let outputHandle = unsafe { acquireArrayRawData(Array<DateTimeAbi>(2, { _ => DateTimeAbi() })) }
    try {
        let output = CPointer<DateTimeAbi>(outputHandle.pointer)
        var copied = 99u32
        let getManyHr = unsafe {
            directGetMany(vector.asRaw(), 0u32, 2u32, CPointer<Unit>(output), CPointer<UInt32>(inout copied))
        }
        @Expect(getManyHr, S_OK.value)
        @Expect(copied, 2u32)
        @Expect(DateTime.assumeInitRef(unsafe { output.read() }).UniversalTime, 21i64)
        @Expect(DateTime.assumeInitRef(unsafe { (output + 1).read() }).UniversalTime, 22i64)
    } finally {
        unsafe { releaseArrayRawData(outputHandle) }
    }

    let nullReplaceHr = unsafe { directReplaceAll(vector.asRaw(), 1u32, CPointer<Unit>()) }
    @Expect(nullReplaceHr, E_POINTER.value)

    fixture.close()
}
