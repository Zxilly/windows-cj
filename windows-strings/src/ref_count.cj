package windows_strings

import std.sync.{AtomicInt32, Mutex}

foreign {
    @FastNative
    func HeapAlloc(hHeap: CPointer<Unit>, dwFlags: UInt32, dwBytes: UIntNative): CPointer<Unit>
    func HeapFree(hHeap: CPointer<Unit>, dwFlags: UInt32, lpMem: CPointer<Unit>): Int32
    func GetProcessHeap(): CPointer<Unit>
}

public let HSTRING_REFERENCE_FLAG: UInt32 = 1u32
public let HSTRING_FAST_PASS_FLAG: UInt32 = 0x10u32
public let HSTRING_REFERENCE_FLAGS: UInt32 = HSTRING_REFERENCE_FLAG | HSTRING_FAST_PASS_FLAG

public class HStringAbiException <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

@C
public struct HStringHeader {
    public var flags: UInt32 = 0u32
    public var len: UInt32 = 0u32
    public var _0: UInt32 = 0u32
    public var _1: UInt32 = 0u32
    public var data: CPointer<UInt16> = CPointer<UInt16>()
    public var count: Int32 = 0i32
    public var bufferStart: UInt16 = 0u16
    public var bufferPadding: UInt16 = 0u16

    public init() {}
}

// Global lock that serialises atomic-style access to the inline `count` field
// of every HStringHeader. Cangjie does not expose a portable intrinsic for an
// atomic load/store/CAS over a raw `CPointer<Int32>` slot, so we emulate the
// semantics with a single mutex. Refcount mutations are short critical
// sections so the contention impact is acceptable, while behaviour stays
// correct under multi-threaded access from foreign callers.
let hStringCountMutex = Mutex()
let observedHStringFreeCount = AtomicInt32(0)

public func debugObservedHStringFreeCount(): Int32 {
    observedHStringFreeCount.load()
}

func processHeap(): CPointer<Unit> {
    unsafe { GetProcessHeap() }
}

func heapAllocBytes(size: UIntNative): CPointer<Unit> {
    unsafe { HeapAlloc(processHeap(), 0u32, size) }
}

func heapFreeBytes(ptr: CPointer<Unit>): Unit {
    if (ptr.isNull()) {
        return
    }
    unsafe {
        HeapFree(processHeap(), 0u32, ptr)
    }
}

func hStringCountOffset(): Int64 {
    Int64(sizeOf<UInt32>() * 4 + sizeOf<CPointer<UInt16>>())
}

func hStringInlineBufferOffset(): Int64 {
    hStringCountOffset() + Int64(sizeOf<Int32>())
}

public func hStringHeaderFromHandle(handle: CPointer<Unit>): CPointer<HStringHeader> {
    if (handle.isNull()) {
        return CPointer<HStringHeader>()
    }
    CPointer<HStringHeader>(handle)
}

public func hStringHeaderInlineBuffer(header: CPointer<HStringHeader>): CPointer<UInt16> {
    if (header.isNull()) {
        return CPointer<UInt16>()
    }
    unsafe { CPointer<UInt16>(CPointer<UInt8>(header) + hStringInlineBufferOffset()) }
}

func hStringFlags(handle: CPointer<Unit>): UInt32 {
    if (handle.isNull()) {
        return 0u32
    }
    unsafe { hStringHeaderFromHandle(handle).read().flags }
}

func hStringCountSlot(header: CPointer<HStringHeader>): CPointer<Int32> {
    unsafe { CPointer<Int32>(CPointer<UInt8>(header) + hStringCountOffset()) }
}

// Atomically apply `delta` to the in-header refcount, returning the new value.
func adjustHStringCount(header: CPointer<HStringHeader>, delta: Int32): Int32 {
    let slot = hStringCountSlot(header)
    hStringCountMutex.lock()
    try {
        let current = unsafe { slot.read() }
        let updated = current + delta
        unsafe { slot.write(updated) }
        return updated
    } finally {
        hStringCountMutex.unlock()
    }
}

public func hStringIsReferenceBacked(handle: CPointer<Unit>): Bool {
    (hStringFlags(handle) & HSTRING_REFERENCE_FLAG) != 0u32
}

public func hStringAllocLen(length: Int64, referenceBacked!: Bool = false): CPointer<HStringHeader> {
    if (length <= 0) {
        return CPointer<HStringHeader>()
    }

    let byteCount = sizeOf<HStringHeader>() + UIntNative(length) * sizeOf<UInt16>()
    let raw = heapAllocBytes(byteCount)
    if (raw.isNull()) {
        throw HStringAbiException("failed to allocate HString header")
    }

    let header = CPointer<HStringHeader>(raw)
    let data = hStringHeaderInlineBuffer(header)
    unsafe {
        header.write(HStringHeader())
        var zeroIndex: Int64 = 0
        while (zeroIndex <= length) {
            (data + zeroIndex).write(0u16)
            zeroIndex += 1
        }

        var snapshot = header.read()
        snapshot.flags = if (referenceBacked) { HSTRING_REFERENCE_FLAGS } else { 0u32 }
        snapshot.len = UInt32(length)
        snapshot.data = data
        snapshot.count = if (referenceBacked) { 0i32 } else { 1i32 }
        header.write(snapshot)
    }
    header
}

public func hStringAllocFromWide(
    units: Array<UInt16>,
    length!: Int64 = -1,
    referenceBacked!: Bool = false
): CPointer<HStringHeader> {
    let fullLength = Int64(units.size)
    var actualLength = length
    if (actualLength < 0 || actualLength > fullLength) {
        actualLength = fullLength
    }
    if (actualLength == 0) {
        return CPointer<HStringHeader>()
    }

    let header = hStringAllocLen(actualLength, referenceBacked: referenceBacked)
    let buffer = hStringHeaderInlineBuffer(header)
    unsafe {
        var index: Int64 = 0
        while (index < actualLength) {
            (buffer + index).write(units[index])
            index += 1
        }
        (buffer + actualLength).write(0u16)
    }
    header
}

public func hStringFree(header: CPointer<HStringHeader>): Unit {
    if (header.isNotNull()) {
        observedHStringFreeCount.fetchAdd(1)
    }
    heapFreeBytes(CPointer<Unit>(header))
}

public func hStringAddRef(handle: CPointer<Unit>): UInt32 {
    if (handle.isNull()) {
        return 0u32
    }
    if (hStringIsReferenceBacked(handle)) {
        return 1u32
    }

    let header = hStringHeaderFromHandle(handle)
    let updated = adjustHStringCount(header, 1i32)
    if (updated <= 0) {
        // Wrap-around or corruption: report previous value as zero rather than
        // reinterpreting a negative count as a huge unsigned value.
        return 0u32
    }
    UInt32(updated)
}

public func hStringRelease(handle: CPointer<Unit>): UInt32 {
    if (handle.isNull()) {
        return 0u32
    }
    if (hStringIsReferenceBacked(handle)) {
        return 0u32
    }

    let header = hStringHeaderFromHandle(handle)
    let updated = adjustHStringCount(header, -1i32)
    if (updated < 0) {
        // Over-release: clamp to zero so callers do not observe a wrapped
        // value. The header is left in a non-positive state which downstream
        // free paths can detect if they want to assert.
        return 0u32
    }
    UInt32(updated)
}

public func hStringDuplicate(handle: CPointer<Unit>): CPointer<Unit> {
    if (handle.isNull()) {
        return CPointer<Unit>()
    }

    if (!hStringIsReferenceBacked(handle)) {
        hStringAddRef(handle)
        return handle
    }

    let len = Int64(hStringLength(handle))
    let copy = hStringAllocLen(len)
    let source = hStringBuffer(handle)
    let target = hStringHeaderInlineBuffer(copy)
    unsafe {
        var index: Int64 = 0
        while (index <= len) {
            (target + index).write((source + index).read())
            index += 1
        }
    }
    CPointer<Unit>(copy)
}

public func hStringLength(handle: CPointer<Unit>): UInt32 {
    if (handle.isNull()) {
        return 0u32
    }
    unsafe { hStringHeaderFromHandle(handle).read().len }
}

public func hStringBuffer(handle: CPointer<Unit>): CPointer<UInt16> {
    if (handle.isNull()) {
        return CPointer<UInt16>()
    }
    unsafe { hStringHeaderFromHandle(handle).read().data }
}
