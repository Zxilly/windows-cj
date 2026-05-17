package windows_implement

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*

class ComObjectLifetimeDummy {}

let asInterfaceTakeFromAbiCount = AtomicInt64(0)

func resetAsInterfaceTakeFromAbiCount(): Unit {
    asInterfaceTakeFromAbiCount.store(0)
}

func trackingIUnknownTakeFromAbi(raw: CPointer<Unit>): IUnknown {
    asInterfaceTakeFromAbiCount.fetchAdd(1)
    IUnknown.fromAbiTake(raw)
}

func trackingIUnknownViewOf(raw: CPointer<Unit>): IUnknown {
    IUnknown.viewOf(raw)
}

func expectLifetimeCast(raw: CPointer<Unit>): ComObject<ComObjectLifetimeDummy> {
    match (ComObject<ComObjectLifetimeDummy>.castFromRaw(raw)) {
        case Some(value) => return value
        case None => throw Exception("expected ComObject cast to succeed")
    }
}

func lifetimeActionThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@Test
func testComObjectCastFromRawRetainsAndCloseReleasesOnce() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    @Expect(owner.runtime.isReferenceCountOne(), true)

    let casted = expectLifetimeCast(owner.asRaw())
    @Expect(owner.runtime.isReferenceCountOne(), false)

    casted.close()
    @Expect(owner.runtime.isReferenceCountOne(), true)
    casted.close()
    @Expect(owner.runtime.isReferenceCountOne(), true)

    let _ = owner.releaseBase()
}

@Test
func testComObjectCloseRemovesRegistryAndIsIdempotent() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    let raw = owner.asRaw()
    let key = unsafe { rootRegistryKeyFromRaw(raw) }
    @Expect(comRegistryLookup(key).isSome(), true)

    owner.close()
    @Expect(owner.asRaw().isNull(), true)
    @Expect(comRegistryLookup(key).isNone(), true)

    owner.close()
    @Expect(owner.asRaw().isNull(), true)
}

@Test
func testComObjectObservesExternalVtableReleaseToZero() {
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])
    let raw = owner.asRaw()
    var result = CPointer<Unit>()

    let releaseCount = unsafe { iunknownReleaseThunk(raw) }
    @Expect(releaseCount, 0u32)
    @Expect(owner.isClosed(), true)
    @Expect(owner.asRaw().isNull(), true)
    @Expect(owner.queryInterfaceBase(IID_IUNKNOWN, CPointer<CPointer<Unit>>(inout result)), E_NOINTERFACE)
    @Expect(result.isNull(), true)
    @Expect(lifetimeActionThrows({ => owner.close() }), false)
    @Expect(lifetimeActionThrows({ => let _ = owner.releaseBase() }), false)
}

@Test
func testComObjectAsInterfaceUsesBorrowedViewWithoutOwningWrapper() {
    resetAsInterfaceTakeFromAbiCount()
    let descriptor = InterfaceDescriptor<IUnknown>(
        "IUnknown",
        IID_IUNKNOWN,
        trackingIUnknownTakeFromAbi,
        trackingIUnknownViewOf
    )
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])

    let view = owner.asInterface(descriptor)

    @Expect(asInterfaceTakeFromAbiCount.load(), 0)
    @Expect(view.release(), 0u32)
    @Expect(owner.runtime.isReferenceCountOne(), true)
    owner.close()
}

@Test
func testComObjectIntoInterfaceKeepsOwnedQueryInterfaceReference() {
    resetAsInterfaceTakeFromAbiCount()
    let descriptor = InterfaceDescriptor<IUnknown>(
        "IUnknown",
        IID_IUNKNOWN,
        trackingIUnknownTakeFromAbi,
        trackingIUnknownViewOf
    )
    let owner = createComObject(ComObjectLifetimeDummy(), [IID_IUNKNOWN])

    let owned = owner.intoInterface(descriptor)

    @Expect(asInterfaceTakeFromAbiCount.load(), 1)
    @Expect(owner.isClosed(), true)
    @Expect(owner.runtime.isReferenceCountOne(), true)
    @Expect(owned.release(), 0u32)
    @Expect(owner.runtime.isDestroyed(), true)
    owner.close()
}
