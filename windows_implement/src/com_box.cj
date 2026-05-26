package windows_implement

// ComBox is the inline native slot header used by every runtime-generated COM
// pointer. The first field must remain the vtable pointer so the slot can be
// viewed directly as a COM interface pointer.
@C
public struct ComBox {
    public var vtable: CPointer<Unit> = CPointer<Unit>()
    public var rootOffset: Int64 = 0
    public var slotIndex: Int64 = 0
    public var slotCount: Int64 = 1
    public var rootKey: UIntNative = UIntNative(0)

    public init() {}

    public init(
        vtable: CPointer<Unit>,
        rootOffset!: Int64 = 0,
        slotIndex!: Int64 = 0,
        slotCount!: Int64 = 1,
        rootKey!: UIntNative = UIntNative(0)
    ) {
        this.vtable = vtable
        this.rootOffset = rootOffset
        this.slotIndex = slotIndex
        this.slotCount = slotCount
        this.rootKey = rootKey
    }
}

public unsafe func comBoxPointerFromRaw(raw: CPointer<Unit>): CPointer<ComBox> {
    CPointer<ComBox>(raw)
}

public unsafe func comBoxFromRaw(raw: CPointer<Unit>): ComBox {
    comBoxPointerFromRaw(raw).read()
}

public unsafe func recoverRootSlotPointer(raw: CPointer<Unit>): CPointer<ComBox> {
    let slot = comBoxPointerFromRaw(raw)
    let header = slot.read()
    slot - header.rootOffset
}

public unsafe func recoverRootSlotPointer(raw: CPointer<Unit>, slotOffset!: Int64 = -1): CPointer<ComBox> {
    if (raw.isNull()) {
        return CPointer<ComBox>()
    }
    if (slotOffset < 0) {
        return CPointer<ComBox>()
    }
    let slot = CPointer<CPointer<Unit>>(raw)
    CPointer<ComBox>(slot - slotOffset)
}

public unsafe func recoverRootRaw(raw: CPointer<Unit>, slotOffset!: Int64 = -1): CPointer<Unit> {
    if (raw.isNull()) {
        return CPointer<Unit>()
    }
    if (slotOffset >= 0) {
        return CPointer<Unit>(CPointer<CPointer<Unit>>(raw) - slotOffset)
    }
    raw
}

public unsafe func rootRegistryKeyFromRaw(raw: CPointer<Unit>, slotOffset!: Int64 = -1): UIntNative {
    if (raw.isNull()) {
        return UIntNative(0)
    }
    if (slotOffset >= 0) {
        return recoverRootRaw(raw, slotOffset: slotOffset).toUIntNative()
    }
    if (comSlotRegistryContains(raw.toUIntNative())) {
        match (comSlotRegistryLookup(raw.toUIntNative())) {
            case Some(rootKey) => return rootKey
            case None => ()
        }
    }
    raw.toUIntNative()
}
