package windows_implement

import std.unittest.*
import std.unittest.testmacro.*

class DummyObject {}

func optionUIntNativeEquals(value: Option<UIntNative>, expected: UIntNative): Bool {
    match (value) {
        case Some(actual) => actual == expected
        case None => false
    }
}

@Test
func testComRegistryAndSlotRegistryRoundTrip() {
    let objectKey = UIntNative(0x1234)
    let slotKey = UIntNative(0x5678)
    let rootKey = UIntNative(0x9ABC)

    comRegistryRemove(objectKey)
    comSlotRegistryRemove(slotKey)

    comRegistryInsert(objectKey, DummyObject())
    comSlotRegistryInsert(slotKey, rootKey)

    @Expect(comRegistryLookup(objectKey).isSome(), true)
    @Expect(comSlotRegistryContains(slotKey), true)
    @Expect(optionUIntNativeEquals(comSlotRegistryLookup(slotKey), rootKey), true)

    comRegistryRemove(objectKey)
    comSlotRegistryRemove(slotKey)

    @Expect(comRegistryLookup(objectKey).isNone(), true)
    @Expect(comSlotRegistryContains(slotKey), false)
}

@Test
func testRootRegistryKeyFromRawUsesSlotRegistryFallback() {
    let slotKey = UIntNative(0x2222)
    let rootKey = UIntNative(0x3333)
    comSlotRegistryInsert(slotKey, rootKey)

    let raw = unsafe { CPointer<Unit>(CPointer<UInt8>() + Int64(slotKey)) }
    @Expect(unsafe { rootRegistryKeyFromRaw(raw) }, rootKey)

    comSlotRegistryRemove(slotKey)
    @Expect(unsafe { rootRegistryKeyFromRaw(raw) }, slotKey)
}
