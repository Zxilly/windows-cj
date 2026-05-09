package windows_strings

import std.sync.AtomicInt32
import windows_libloading as windows_libloading

class BStrAllocationException <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

class BStrAbiException <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

func oleaut32Proc(name: String): CPointer<Unit> {
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw BStrAbiException("failed to resolve OleAut32 BSTR ABI")
    }
}

// Cached proc pointers for oleaut32 functions.
var cachedSysAllocStringLen: CPointer<Unit> = CPointer<Unit>()
var cachedSysFreeString: CPointer<Unit> = CPointer<Unit>()
var cachedSysStringLen: CPointer<Unit> = CPointer<Unit>()
var cachedSysStringByteLen: CPointer<Unit> = CPointer<Unit>()
let observedSysFreeStringCount = AtomicInt32(0)

public func debugObservedSysFreeStringCount(): Int32 {
    observedSysFreeStringCount.load()
}

func getSysAllocStringLen(): CPointer<Unit> {
    if (cachedSysAllocStringLen.isNotNull()) {
        return cachedSysAllocStringLen
    }
    let proc = oleaut32Proc("SysAllocStringLen")
    cachedSysAllocStringLen = proc
    proc
}

func getSysFreeString(): CPointer<Unit> {
    if (cachedSysFreeString.isNotNull()) {
        return cachedSysFreeString
    }
    let proc = oleaut32Proc("SysFreeString")
    cachedSysFreeString = proc
    proc
}

func getSysStringLen(): CPointer<Unit> {
    if (cachedSysStringLen.isNotNull()) {
        return cachedSysStringLen
    }
    let proc = oleaut32Proc("SysStringLen")
    cachedSysStringLen = proc
    proc
}

func getSysStringByteLen(): CPointer<Unit> {
    if (cachedSysStringByteLen.isNotNull()) {
        return cachedSysStringByteLen
    }
    let proc = oleaut32Proc("SysStringByteLen")
    cachedSysStringByteLen = proc
    proc
}

func sysAllocStringLen(ptr: CPointer<UInt16>, unitLength: UInt32): CPointer<UInt16> {
    let alloc = CFunc<(CPointer<UInt16>, UInt32) -> CPointer<UInt16>>(getSysAllocStringLen())
    unsafe {
        alloc(ptr, unitLength)
    }
}

func sysFreeString(ptr: CPointer<UInt16>): Unit {
    let freeFn = CFunc<(CPointer<UInt16>) -> Unit>(getSysFreeString())
    unsafe {
        freeFn(ptr)
    }
    observedSysFreeStringCount.fetchAdd(1)
}

func sysStringLen(ptr: CPointer<UInt16>): UInt32 {
    let lenFn = CFunc<(CPointer<UInt16>) -> UInt32>(getSysStringLen())
    unsafe {
        lenFn(ptr)
    }
}

func sysStringByteLen(ptr: CPointer<UInt16>): UInt32 {
    let lenFn = CFunc<(CPointer<UInt16>) -> UInt32>(getSysStringByteLen())
    unsafe {
        lenFn(ptr)
    }
}

func allocateBstr(units: Array<UInt16>): CPointer<UInt16> {
    if (units.isEmpty()) {
        return CPointer<UInt16>()
    }

    unsafe {
        let handle = acquireArrayRawData(units)
        try {
            let value = sysAllocStringLen(handle.pointer, UInt32(units.size))
            if (value.isNull()) {
                throw BStrAllocationException("failed to allocate BSTR storage")
            }
            value
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func closeBstrState(
    ptr: CPointer<UInt16>,
    ownsStorage: Bool,
    closed: Bool
): (CPointer<UInt16>, Bool, Bool) {
    if (!closed && ownsStorage && ptr.isNotNull()) {
        sysFreeString(ptr)
    }
    (CPointer<UInt16>(), false, true)
}

/// BSTR owns an optional length-prefixed UTF-16 allocation.
public class BSTR <: Resource & Equatable<BSTR> & ToString {
    private var ptr: CPointer<UInt16> = CPointer<UInt16>()
    private var storageOwned: Bool = false
    private var closed: Bool = false

    public init() {}

    public init(s: String) {
        let units = encodeUtf16Units(s)
        ptr = allocateBstr(units)
        storageOwned = ptr.isNotNull()
    }

    init(ptr: CPointer<UInt16>, ownsStorage: Bool) {
        this.ptr = ptr
        this.storageOwned = ownsStorage
    }

    func currentLength(): Int64 {
        if (closed || ptr.isNull()) {
            return 0
        }
        Int64(sysStringLen(ptr))
    }

    func currentByteLength(): UInt32 {
        if (closed || ptr.isNull()) {
            return 0u32
        }
        sysStringByteLen(ptr)
    }

    public static func fromWide(data: Array<UInt16>, length!: Int64 = -1): BSTR {
        let units = copyWideArray(data, length: length)
        if (units.isEmpty()) {
            return BSTR()
        }
        BSTR(allocateBstr(units), true)
    }

    /// Unsafe: caller must guarantee `ptr` is a live BSTR allocation whose ownership
    /// is transferred to the returned wrapper.
    public static func unsafeFromRaw(ptr: CPointer<UInt16>): BSTR {
        BSTR(ptr, ptr.isNotNull())
    }

    /// Unsafe: caller must guarantee `ptr` remains valid for all uses of the returned wrapper.
    public static func unsafeFromRawView(ptr: CPointer<UInt16>): BSTR {
        BSTR(ptr, false)
    }

    /// Unsafe: caller must guarantee `ptr` is a live BSTR allocation whose ownership
    /// is transferred to the returned wrapper.
    public static func unsafeAttach(ptr: CPointer<UInt16>): BSTR {
        BSTR(ptr, ptr.isNotNull())
    }

/// Create an independent copy of this BSTR.
    public func clone(): BSTR {
        if (closed || ptr.isNull()) {
            return BSTR()
        }
        BSTR.fromWide(toWideArray())
    }

    public func get(): String {
        if (closed) {
            return ""
        }
        decodeWideFromPointer(ptr, length: currentLength())
    }

    /// Attempt a lossless decode of the BSTR content.
    /// Returns Some(string) if the content is valid UTF-16, or None if it contains invalid surrogate pairs.
    public func tryToString(): Option<String> {
        if (closed) {
            return Some("")
        }
        tryDecodeWideFromPointer(ptr, length: currentLength())
    }

    public func length(): Int64 {
        currentLength()
    }

    public func byteLength(): UInt32 {
        currentByteLength()
    }

    public func isEmpty(): Bool {
        length() == 0
    }

    public func ownsStorage(): Bool {
        storageOwned && !closed
    }

    public func asPtr(): CPointer<UInt16> {
        if (closed) {
            return CPointer<UInt16>()
        }
        ptr
    }

    public func toWideArray(): Array<UInt16> {
        if (closed) {
            return Array<UInt16>(0, repeat: 0u16)
        }
        copyWideFromPointer(ptr, currentLength())
    }

    public func asSlice(): PointerSliceView<UInt16> {
        if (closed) {
            return PointerSliceView<UInt16>(CPointer<UInt16>(), 0)
        }
        PointerSliceView<UInt16>(ptr, currentLength(), owner: Some(this))
    }

    public func withPtr<R>(action: (CPointer<UInt16>) -> R): R {
        action(asPtr())
    }

    /// Transfer ownership of the raw BSTR pointer to the caller.
    /// The caller is responsible for freeing it with SysFreeString.
    /// After this call the BSTR instance is invalidated.
    public func intoRaw(): CPointer<UInt16> {
        let raw = asPtr()
        storageOwned = false
        ptr = CPointer<UInt16>()
        closed = true
        raw
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        let (nextPtr, nextOwnsStorage, nextClosed) = closeBstrState(ptr, storageOwned, closed)
        ptr = nextPtr
        storageOwned = nextOwnsStorage
        closed = nextClosed
    }

    public func display(): StringDisplay {
        StringDisplay(get())
    }

    public func close(): Unit {
        let (nextPtr, nextOwnsStorage, nextClosed) = closeBstrState(ptr, storageOwned, closed)
        ptr = nextPtr
        storageOwned = nextOwnsStorage
        closed = nextClosed
    }

    // Equatable<BSTR>
    public operator func ==(other: BSTR): Bool {
        compareWideUnits(toWideArray(), other.toWideArray()) == Ordering.EQ
    }

    public operator func ==(rhs: String): Bool {
        compareWideUnits(toWideArray(), encodeUtf16Units(rhs)) == Ordering.EQ
    }

    public operator func !=(other: BSTR): Bool {
        !(this == other)
    }

    public operator func !=(rhs: String): Bool {
        !(this == rhs)
    }

    // ToString — displays the UTF-16 content as a Cangjie String.
    public func toString(): String {
        get()
    }
}
