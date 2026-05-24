package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, S_OK}

func createInt32Map(entries: ArrayList<(Int32, Int32)>): IMap<Int32, Int32> {
    makeGenericMap<Int32, Int32>(
        entries,
        { => IMapVtbl.newInt32Int32<GenericMapAbiTestImpl<Int32, Int32>>() }
    )
}

func createGenericBuilderInt32Map(entries: ArrayList<(Int32, Int32)>): IMap<Int32, Int32> {
    makeGenericMap<Int32, Int32>(
        entries,
        { => IMapVtbl.new<GenericMapAbiTestImpl<Int32, Int32>, Int32, Int32>() }
    )
}

@Test
func testInt32MapUsesDirectValueAbiForMutableSlots() {
    let source = ArrayList<(Int32, Int32)>([(1i32, 10i32), (2i32, 20i32)])
    let map = createInt32Map(source)

    @Expect(unsafe { map.HasKey(2i32) }, true)
    @Expect(unsafe { map.Lookup(1i32) }, 10i32)
    @Expect(unsafe { map.Insert(2i32, 22i32) }, true)
    @Expect(unsafe { map.Lookup(2i32) }, 22i32)
    @Expect(unsafe { map.Insert(3i32, 30i32) }, false)
    unsafe { map.Remove(1i32) }
    @Expect(unsafe { map.HasKey(1i32) }, false)
    @Expect(unsafe { map.Size() }, 2u32)

    let vtbl = unsafe { map.vtbl() }
    var directValue = 0i32
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 2i32, CPointer<Int32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 22i32)
    directValue = 99i32
    let missingLookupHr = unsafe { directLookup(map.asRaw(), 404i32, CPointer<Int32>(inout directValue)) }
    @Expect(missingLookupHr != S_OK.value, true)
    @Expect(directValue, 0i32)

    var directFound = true
    let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
    let hasKeyHr = unsafe { directHasKey(map.asRaw(), 1i32, CPointer<Bool>(inout directFound)) }
    @Expect(hasKeyHr, S_OK.value)
    @Expect(directFound, false)

    var replaced = false
    let directInsert = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
    let insertHr = unsafe { directInsert(map.asRaw(), 4i32, 40i32, CPointer<Bool>(inout replaced)) }
    @Expect(insertHr, S_OK.value)
    @Expect(replaced, false)
    @Expect(unsafe { map.Lookup(4i32) }, 40i32)

    let directRemove = CFunc<(CPointer<Unit>, Int32) -> Int32>(CPointer<Unit>(vtbl.Remove))
    let removeHr = unsafe { directRemove(map.asRaw(), 2i32) }
    @Expect(removeHr, S_OK.value)
    @Expect(unsafe { map.HasKey(2i32) }, false)

    map.close()
}

@Test
func testGenericInt32MapBuilderUsesDirectValueAbiForSpecialization() {
    let source = ArrayList<(Int32, Int32)>([(7i32, 70i32)])
    let map = createGenericBuilderInt32Map(source)

    @Expect(unsafe { map.Lookup(7i32) }, 70i32)

    let vtbl = unsafe { map.vtbl() }
    var directValue = 0i32
    let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
    let lookupHr = unsafe { directLookup(map.asRaw(), 7i32, CPointer<Int32>(inout directValue)) }
    @Expect(lookupHr, S_OK.value)
    @Expect(directValue, 70i32)
    directValue = 99i32
    let missingLookupHr = unsafe { directLookup(map.asRaw(), 404i32, CPointer<Int32>(inout directValue)) }
    @Expect(missingLookupHr != S_OK.value, true)
    @Expect(directValue, 0i32)

    var replaced = false
    let directInsert = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
    let insertHr = unsafe { directInsert(map.asRaw(), 7i32, 77i32, CPointer<Bool>(inout replaced)) }
    @Expect(insertHr, S_OK.value)
    @Expect(replaced, true)
    @Expect(unsafe { map.Lookup(7i32) }, 77i32)

    map.close()
}

@Test
func testInt32MapVtblNoneBranchClearsSpecializedOutSlots() {
    let vtbl = IMapVtbl.newInt32Int32<GenericMapAbiTestImpl<Int32, Int32>>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IMapVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IMapVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(123i32) }
    let raw = CPointer<Unit>(objectHandle)
    var lookupValue = 99i32
    var sizeValue = 77u32
    var foundValue = true
    var viewValue = CPointer<Unit>(sentinel)
    var replacedValue = true

    try {
        let directLookup = CFunc<(CPointer<Unit>, Int32, CPointer<Int32>) -> Int32>(CPointer<Unit>(vtbl.Lookup))
        let lookupHr = unsafe { directLookup(raw, 1i32, CPointer<Int32>(inout lookupValue)) }
        @Expect(lookupHr, E_NOINTERFACE.value)
        @Expect(lookupValue, 0i32)

        let sizeHr = unsafe { vtbl.Size(raw, CPointer<UInt32>(inout sizeValue)) }
        @Expect(sizeHr, E_NOINTERFACE.value)
        @Expect(sizeValue, 0u32)

        let directHasKey = CFunc<(CPointer<Unit>, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.HasKey))
        let hasKeyHr = unsafe { directHasKey(raw, 1i32, CPointer<Bool>(inout foundValue)) }
        @Expect(hasKeyHr, E_NOINTERFACE.value)
        @Expect(foundValue, false)

        let getViewHr = unsafe { vtbl.GetView(raw, CPointer<CPointer<Unit>>(inout viewValue)) }
        @Expect(getViewHr, E_NOINTERFACE.value)
        @Expect(viewValue.isNull(), true)

        let directInsert = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<Bool>) -> Int32>(CPointer<Unit>(vtbl.Insert))
        let insertHr = unsafe { directInsert(raw, 1i32, 2i32, CPointer<Bool>(inout replacedValue)) }
        @Expect(insertHr, E_NOINTERFACE.value)
        @Expect(replacedValue, false)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}
