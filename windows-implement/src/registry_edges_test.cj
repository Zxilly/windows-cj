package windows_implement

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testMissingRegistryEntriesRemainAbsentAfterRemove() {
    let objectKey = UIntNative(0x7001)
    let slotKey = UIntNative(0x7002)

    comRegistryRemove(objectKey)
    comSlotRegistryRemove(slotKey)
    comRegistryRemove(objectKey)
    comSlotRegistryRemove(slotKey)

    @Expect(comRegistryLookup(objectKey).isNone(), true)
    @Expect(comSlotRegistryLookup(slotKey).isNone(), true)
    @Expect(comSlotRegistryContains(slotKey), false)
}

@Test
func testComBoxHeaderPreservesSlotMetadata() {
    let vtable = unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x10) }
    let box = ComBox(
        vtable,
        rootOffset: 2,
        slotIndex: 1,
        slotCount: 3,
        rootKey: UIntNative(0xABCD)
    )

    @Expect(box.vtable.toUIntNative(), vtable.toUIntNative())
    @Expect(box.rootOffset, 2)
    @Expect(box.slotIndex, 1)
    @Expect(box.slotCount, 3)
    @Expect(box.rootKey, UIntNative(0xABCD))
}

@Test
func testRootRecoveryHandlesNullAndInvalidExplicitOffset() {
    let nullRaw = CPointer<Unit>()
    let slotKey = UIntNative(0x7777)
    let raw = unsafe { CPointer<Unit>(CPointer<UInt8>() + Int64(slotKey)) }

    @Expect(unsafe { rootRegistryKeyFromRaw(nullRaw) }, UIntNative(0))
    @Expect(unsafe { recoverRootRaw(nullRaw, slotOffset: 0).isNull() }, true)
    @Expect(unsafe { recoverRootSlotPointer(raw, slotOffset: -1).isNull() }, true)
    @Expect(unsafe { rootRegistryKeyFromRaw(raw, slotOffset: -1) }, slotKey)
}
