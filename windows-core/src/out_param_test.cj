package windows_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testOutSlotCloseIsIdempotentAfterAbiBorrow() {
    let slot = OutSlot<Int32>()
    let raw = slot.borrowMut<Int32>()
    @Expect(raw.isNotNull(), true)
    unsafe { raw.write(7i32) }

    match (slot.takeAbi<Int32>()) {
        case Some(value) => @Expect(value, 7i32)
        case None => throw Exception("OutSlot did not publish ABI value")
    }

    slot.close()
    slot.close()

    @Expect(slot.isClosed(), true)
    @Expect(slot.isNull(), true)
    @Expect(slot.get().isNone(), true)
    @Expect(slot.takeAbi<Int32>().isNone(), true)
}

@Test
func testOutSlotTakeAbiConsumesTemporarySlot() {
    let slot = OutSlot<Int32>()
    let rawFirst = slot.borrowMut<Int32>()
    @Expect(rawFirst.isNotNull(), true)
    unsafe { rawFirst.write(9i32) }

    match (slot.takeAbi<Int32>()) {
        case Some(value) => @Expect(value, 9i32)
        case None => throw Exception("OutSlot did not publish first ABI value")
    }
    @Expect(slot.takeAbi<Int32>().isNone(), true)

    let rawSecond = slot.borrowMut<Int32>()
    @Expect(rawSecond.isNotNull(), true)
    unsafe { rawSecond.write(11i32) }
    match (slot.takeAbi<Int32>()) {
        case Some(value) => @Expect(value, 11i32)
        case None => throw Exception("OutSlot did not publish second ABI value")
    }

    slot.close()
}
