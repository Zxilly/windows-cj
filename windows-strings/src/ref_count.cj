package windows_strings

import std.collection.concurrent.*
import std.sync.AtomicInt32

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

class RefCountException <: Exception {
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

let hStringRefCounts = ConcurrentHashMap<UIntNative, AtomicInt32>()
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

func hStringHeaderKey(header: CPointer<HStringHeader>): UIntNative {
    CPointer<Unit>(header).toUIntNative()
}

func writeHStringCount(header: CPointer<HStringHeader>, count: Int32): Unit {
    if (header.isNull()) {
        return
    }
    unsafe {
        var snapshot = header.read()
        snapshot.count = count
        header.write(snapshot)
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
    if (!referenceBacked) {
        hStringRefCounts.add(hStringHeaderKey(header), AtomicInt32(1))
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
        hStringRefCounts.remove(hStringHeaderKey(header))
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

    match (hStringRefCounts.get(handle.toUIntNative())) {
        case Some(counter) =>
            let count = counter.fetchAdd(1) + 1
            if (count <= 0) {
                throw RefCountException("HString ref count became non-positive during addRef")
            }
            writeHStringCount(hStringHeaderFromHandle(handle), count)
            return UInt32(count)
        case None =>
            throw RefCountException("HString ref count state is missing")
    }
}

public func hStringRelease(handle: CPointer<Unit>): UInt32 {
    if (handle.isNull()) {
        return 0u32
    }
    if (hStringIsReferenceBacked(handle)) {
        return 0u32
    }

    match (hStringRefCounts.get(handle.toUIntNative())) {
        case Some(counter) =>
            let previous = counter.fetchSub(1)
            if (previous <= 0) {
                throw RefCountException("HString object has been over-released")
            }
            let remaining = previous - 1
            writeHStringCount(hStringHeaderFromHandle(handle), remaining)
            return UInt32(remaining)
        case None =>
            throw RefCountException("HString ref count state is missing")
    }
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
