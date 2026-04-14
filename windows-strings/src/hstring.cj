package windows_strings

func closeHStringState(handle: CPointer<Unit>, closed: Bool): (CPointer<Unit>, Bool) {
    if (!closed && handle.isNotNull()) {
        // Reference-backed (fast-pass) strings are not heap-managed here; skip free.
        if (!hStringIsReferenceBacked(handle)) {
            if (hStringRelease(handle) == 0u32) {
                hStringFree(hStringHeaderFromHandle(handle))
            }
        }
    }
    (CPointer<Unit>(), true)
}

func closeHStringBuilderState(
    header: CPointer<HStringHeader>,
    closed: Bool
): (CPointer<HStringHeader>, Int64, Bool) {
    if (!closed && header.isNotNull()) {
        hStringFree(header)
    }
    (CPointer<HStringHeader>(), 0, true)
}

/// An HSTRING backed by an ABI-compatible header and UTF-16 payload.
///
/// Empty strings are represented as a null handle. Non-empty strings store the
/// header and UTF-16 buffer in a single heap allocation.
public class HString <: Resource & Equatable<HString> & ToString & Hashable & Comparable<HString> {
    private var handle: CPointer<Unit> = CPointer<Unit>()
    private var closed: Bool = false

    public init() {}

    public init(s: String) {
        handle = CPointer<Unit>(hStringAllocFromWide(encodeUtf16Units(s)))
    }

    init(handle: CPointer<Unit>) {
        this.handle = handle
    }

    public static func default(): HString {
        HString()
    }

    public static func fromWide(data: Array<UInt16>, length!: Int64 = -1): HString {
        HString(CPointer<Unit>(hStringAllocFromWide(data, length: length)))
    }

    static func fromReferenceWide(data: Array<UInt16>, length!: Int64 = -1): HString {
        // Cangjie arrays do not provide a stable static UTF-16 backing store,
        // so this helper must keep heap-managed allocation semantics.
        HString(CPointer<Unit>(hStringAllocFromWide(data, length: length)))
    }

    static func fromOwnedHeader(header: CPointer<HStringHeader>): HString {
        HString(CPointer<Unit>(header))
    }

    func currentLengthValue(): UInt32 {
        if (closed) {
            return 0u32
        }
        hStringLength(handle)
    }

    func currentBuffer(): CPointer<UInt16> {
        if (closed) {
            return CPointer<UInt16>()
        }
        hStringBuffer(handle)
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        handle
    }

    public func get(): String {
        toStringLossy()
    }

    public func toStringLossy(): String {
        if (closed) {
            return ""
        }
        decodeWideFromPointer(currentBuffer(), length: Int64(currentLengthValue()))
    }

    public func tryToString(): Option<String> {
        if (closed) {
            return Some("")
        }
        tryDecodeWideFromPointer(currentBuffer(), length: Int64(currentLengthValue()))
    }

    public func length(): Int64 {
        Int64(currentLengthValue())
    }

    public func isEmpty(): Bool {
        length() == 0
    }

    /// Returns a view over the UTF-16 units of this string.
    /// The view is valid only while this HString is alive and not closed.
    public func asSlice(): PointerSliceView<UInt16> {
        if (closed) {
            return PointerSliceView<UInt16>(CPointer<UInt16>(), 0)
        }
        PointerSliceView<UInt16>(currentBuffer(), Int64(currentLengthValue()), owner: Some(this))
    }

    public func toWideArray(): Array<UInt16> {
        if (closed) {
            return Array<UInt16>()
        }
        copyWideFromPointer(currentBuffer(), Int64(currentLengthValue()))
    }

    public func withPtr<R>(action: (CPointer<UInt16>) -> R): R {
        action(currentBuffer())
    }

    public func withPCWSTR<R>(action: (PCWSTR) -> R): R {
        action(PCWSTR.fromRaw(currentBuffer()))
    }

    public func display(): StringDisplay {
        StringDisplay(toStringLossy())
    }

    public func clone(): HString {
        if (closed || handle.isNull()) {
            return HString()
        }
        HString(hStringDuplicate(handle))
    }

    public func isReferenceBacked(): Bool {
        !closed && hStringIsReferenceBacked(handle)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        let (nextHandle, nextClosed) = closeHStringState(handle, closed)
        handle = nextHandle
        closed = nextClosed
    }

    public func intoRaw(): CPointer<Unit> {
        let raw = handle
        handle = CPointer<Unit>()
        closed = true
        raw
    }

    public func close(): Unit {
        let (nextHandle, nextClosed) = closeHStringState(handle, closed)
        handle = nextHandle
        closed = nextClosed
    }

    public operator func ==(other: HString): Bool {
        compareWideUnits(toWideArray(), other.toWideArray()) == Ordering.EQ
    }

    public operator func ==(rhs: String): Bool {
        compareWideUnits(toWideArray(), encodeUtf16Units(rhs)) == Ordering.EQ
    }

    public operator func !=(other: HString): Bool {
        !(this == other)
    }

    public operator func !=(rhs: String): Bool {
        !(this == rhs)
    }

    public func hashCode(): Int64 {
        hashWideUnits(toWideArray())
    }

    public func compare(other: HString): Ordering {
        compareWideUnits(toWideArray(), other.toWideArray())
    }

    public func toString(): String {
        toStringLossy()
    }
}

/// Mutable byte-oriented view over a builder's UTF-16 storage.
///
/// The bytes are exposed in Windows-native little-endian order to match the
/// underlying HSTRING buffer layout.
public class HStringBuilderBytes {
    private let ptr: CPointer<UInt16>
    private let unitLength: Int64

    public init(ptr: CPointer<UInt16>, unitLength: Int64) {
        this.ptr = ptr
        this.unitLength = unitLength
    }

    public func length(): Int64 {
        unitLength * 2
    }

    public func get(index: Int64): UInt8 {
        if (index < 0 || index >= length()) {
            throw IndexOutOfBoundsException("HStringBuilderBytes index out of bounds")
        }
        let unit = UInt32(unsafe { (ptr + (index / 2)).read() })
        if ((index % 2) == 0) {
            return UInt8(unit & 0xFFu32)
        }
        UInt8((unit >> 8) & 0xFFu32)
    }

    public func set(index: Int64, value: UInt8): Unit {
        if (index < 0 || index >= length()) {
            throw IndexOutOfBoundsException("HStringBuilderBytes index out of bounds")
        }
        let unitIndex = index / 2
        let current = UInt32(unsafe { (ptr + unitIndex).read() })
        let updated = if ((index % 2) == 0) {
            UInt16((current & 0xFF00u32) | UInt32(value))
        } else {
            UInt16((current & 0x00FFu32) | (UInt32(value) << 8))
        }
        unsafe {
            (ptr + unitIndex).write(updated)
        }
    }

    /// Returns an iterator over the bytes in little-endian order.
    public func iterator(): HStringBuilderBytesIterator {
        HStringBuilderBytesIterator(this, length())
    }

    /// Copies all bytes into a new array.
    public func toArray(): Array<UInt8> {
        let byteLen = length()
        var result = Array<UInt8>(byteLen, repeat: 0u8)
        var i: Int64 = 0
        while (i < byteLen) {
            result[i] = get(i)
            i += 1
        }
        result
    }

    /// Bulk-copies `count` bytes starting at `srcOffset` into `dest` starting at `destOffset`.
    public func copyInto(dest: Array<UInt8>, destOffset: Int64, srcOffset: Int64, count: Int64): Unit {
        let byteLen = length()
        if (srcOffset < 0 || count < 0 || srcOffset + count > byteLen) {
            throw IndexOutOfBoundsException("HStringBuilderBytes.copyInto range out of bounds")
        }
        if (destOffset < 0 || destOffset + count > Int64(dest.size)) {
            throw IndexOutOfBoundsException("HStringBuilderBytes.copyInto destination range out of bounds")
        }
        var i: Int64 = 0
        while (i < count) {
            dest[destOffset + i] = get(srcOffset + i)
            i += 1
        }
    }
}

/// Iterator over the bytes of an HStringBuilderBytes view.
public class HStringBuilderBytesIterator {
    private let source: HStringBuilderBytes
    private let total: Int64
    private var index: Int64 = 0

    public init(source: HStringBuilderBytes, total: Int64) {
        this.source = source
        this.total = total
    }

    public func next(): Option<UInt8> {
        if (index >= total) {
            return None
        }
        let value = source.get(index)
        index += 1
        Some(value)
    }
}

/// A mutable HSTRING builder that allows preallocating storage and filling it
/// before sealing the result as an immutable HString.
public class HStringBuilder <: Resource {
    private var header: CPointer<HStringHeader> = CPointer<HStringHeader>()
    private var logicalLen: Int64 = 0
    private var closed: Bool = false

    public init(capacity: Int64) {
        if (capacity <= 0) {
            return
        }
        header = hStringAllocLen(capacity)
        logicalLen = capacity
    }

    public func length(): Int64 {
        logicalLen
    }

    public func get(index: Int64): UInt16 {
        ensureOpenIndex(index)
        unsafe { (hStringHeaderInlineBuffer(header) + index).read() }
    }

    public func set(index: Int64, value: UInt16): Unit {
        ensureOpenIndex(index)
        unsafe {
            (hStringHeaderInlineBuffer(header) + index).write(value)
        }
    }

    public func asBytesMut(): HStringBuilderBytes {
        if (closed || header.isNull()) {
            return HStringBuilderBytes(CPointer<UInt16>(), 0)
        }
        HStringBuilderBytes(hStringHeaderInlineBuffer(header), logicalLen)
    }

    public func asWide(): Array<UInt16> {
        if (closed || header.isNull()) {
            return Array<UInt16>()
        }
        copyWideFromPointer(hStringHeaderInlineBuffer(header), logicalLen)
    }

    public func trimEnd(): Unit {
        if (closed || header.isNull()) {
            return
        }
        let data = hStringHeaderInlineBuffer(header)
        while (logicalLen > 0 && unsafe { (data + logicalLen - 1).read() == 0u16 }) {
            logicalLen -= 1
        }
        if (logicalLen == 0) {
            hStringFree(header)
            header = CPointer<HStringHeader>()
            return
        }
        syncHeaderLength()
    }

    public func toHString(): HString {
        intoHString()
    }

    public func intoHString(): HString {
        if (closed) {
            return HString()
        }
        if (header.isNull()) {
            closed = true
            return HString()
        }
        syncHeaderLength()
        let transferred = header
        header = CPointer<HStringHeader>()
        logicalLen = 0
        closed = true
        HString.fromOwnedHeader(transferred)
    }

    public func asArray(): Array<UInt16> {
        asWide()
    }

    public func asRaw(): CPointer<Unit> {
        if (closed || header.isNull()) {
            return CPointer<Unit>()
        }
        CPointer<Unit>(header)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        let (nextHeader, nextLogicalLen, nextClosed) = closeHStringBuilderState(header, closed)
        header = nextHeader
        logicalLen = nextLogicalLen
        closed = nextClosed
    }

    public func close(): Unit {
        let (nextHeader, nextLogicalLen, nextClosed) = closeHStringBuilderState(header, closed)
        header = nextHeader
        logicalLen = nextLogicalLen
        closed = nextClosed
    }

    private func ensureOpenIndex(index: Int64): Unit {
        if (closed || header.isNull()) {
            throw IllegalStateException("HStringBuilder storage is closed")
        }
        if (index < 0 || index >= logicalLen) {
            throw IndexOutOfBoundsException("HStringBuilder index out of bounds")
        }
    }

    private func syncHeaderLength(): Unit {
        if (header.isNull()) {
            return
        }
        let data = hStringHeaderInlineBuffer(header)
        unsafe {
            var snapshot = header.read()
            snapshot.len = UInt32(logicalLen)
            header.write(snapshot)
            (data + logicalLen).write(0u16)
        }
    }
}
