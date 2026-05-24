package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.E_NOINTERFACE

// Verifies the no-interface (None) branch of the generated value-ABI vtbl
// thunks clears every out slot before returning E_NOINTERFACE. The element
// type is irrelevant here (the impl is never instantiated; only the vtbl
// factory's Identity binding matters), so the harness Impl type stands in for
// the previously per-type copies.

@Test
func testGenericVectorVtblNoneBranchClearsOutSlots() {
    let vtbl = IVectorVtbl.new<GenericVectorAbiTestImpl<Int32>, Int32>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorVtbl>>(vtblHandle) }
    let sentinel = unsafe { windows_interface.allocateNativeValue<Int32>(789i32) }
    let raw = CPointer<Unit>(objectHandle)
    var getAtResult = CPointer<Unit>(sentinel)
    var sizeResult = 77u32
    var getViewResult = CPointer<Unit>(sentinel)
    var indexResult = 66u32
    var foundResult = true
    var copiedResult = 88u32

    try {
        let getAtHr = unsafe { vtbl.GetAt(raw, 0u32, CPointer<CPointer<Unit>>(inout getAtResult)) }
        @Expect(getAtHr, E_NOINTERFACE.value)
        @Expect(getAtResult.isNull(), true)

        let sizeHr = unsafe { vtbl.Size(raw, CPointer<UInt32>(inout sizeResult)) }
        @Expect(sizeHr, E_NOINTERFACE.value)
        @Expect(sizeResult, 0u32)

        let getViewHr = unsafe { vtbl.GetView(raw, CPointer<CPointer<Unit>>(inout getViewResult)) }
        @Expect(getViewHr, E_NOINTERFACE.value)
        @Expect(getViewResult.isNull(), true)

        let directIndexOf = CFunc<(CPointer<Unit>, Int32, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
            CPointer<Unit>(vtbl.IndexOf)
        )
        let indexOfHr = unsafe {
            directIndexOf(raw, 99i32, CPointer<UInt32>(inout indexResult), CPointer<Bool>(inout foundResult))
        }
        @Expect(indexOfHr, E_NOINTERFACE.value)
        @Expect(indexResult, 0u32)
        @Expect(foundResult, false)

        let getManyHr = unsafe {
            vtbl.GetMany(raw, 0u32, 0u32, CPointer<Unit>(), CPointer<UInt32>(inout copiedResult))
        }
        @Expect(getManyHr, E_NOINTERFACE.value)
        @Expect(copiedResult, 0u32)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(sentinel)
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}

@Test
func testVectorViewVtblNoneBranchClearsIndexOfSlots() {
    let vtbl = IVectorViewVtbl.newUInt8<GenericVectorViewAbiTestImpl<UInt8>>()
    let vtblHandle = unsafe { windows_interface.allocateNativeValue<IVectorViewVtbl>(vtbl) }
    let objectHandle = unsafe { windows_interface.allocateNativeValue<CPointer<IVectorViewVtbl>>(vtblHandle) }
    let raw = CPointer<Unit>(objectHandle)
    var indexResult = 55u32
    var foundResult = true

    try {
        let directIndexOf = CFunc<(CPointer<Unit>, UInt8, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
            CPointer<Unit>(vtbl.IndexOf)
        )
        let indexOfHr = unsafe {
            directIndexOf(raw, 9u8, CPointer<UInt32>(inout indexResult), CPointer<Bool>(inout foundResult))
        }
        @Expect(indexOfHr, E_NOINTERFACE.value)
        @Expect(indexResult, 0u32)
        @Expect(foundResult, false)
    } finally {
        unsafe {
            windows_interface.freeNativeValue(objectHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
    }
}
