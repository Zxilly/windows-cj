package windows_core

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testProjectedAbiArrayCopiesAndCloses() {
    let values = [1i32, 2i32, 3i32]
    let array = AbiArray<Int32>.fromSlice(values)

    values[0] = 99i32
    @Expect(array.len(), 3)
    @Expect(array.get(0), 1i32)

    array.set(1, 7i32)
    let copied = array.toArray()
    @Expect(copied[0], 1i32)
    @Expect(copied[1], 7i32)
    @Expect(copied[2], 3i32)

    array.close()
    @Expect(array.isClosed(), true)
    @Expect(array.toArray().size, 0)
}

@Test
func testNativeAbiArrayIntoAbiTransfersOwnership() {
    let array = AbiArray<Int32>.withLen(2)
    array.set(0, 11i32)
    array.set(1, 22i32)

    let (raw, len) = array.intoAbi()
    @Expect(len, 2u32)
    @Expect(array.isClosed(), true)
    @Expect(raw.isNotNull(), true)
    unsafe {
        @Expect(raw.read(), 11i32)
        @Expect((raw + 1).read(), 22i32)
        CoTaskMemFree(CPointer<Unit>(raw))
    }
}

@Test
func testPublicCoTaskMemHelpersAllocateAndFree() {
    let raw = coTaskMemAlloc(UIntNative(1))
    @Expect(raw.isNotNull(), true)
    coTaskMemFree(raw)
}
