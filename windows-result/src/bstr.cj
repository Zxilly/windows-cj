package windows_result

@When[os == "Windows"]
class BasicString <: Resource & ToString & Equatable<BasicString> {
    private var ptr: CPointer<UInt16> = CPointer<UInt16>()
    private var ownsStorage: Bool = false
    private var closed: Bool = false

    public init() {}

    public init(text: String) {
        let units = encodeUtf16Units(text)
        var raw = CPointer<UInt16>()
        if (!units.isEmpty()) {
            unsafe {
                let handle = acquireArrayRawData(units)
                try {
                    raw = sysAllocStringLenAbi(handle.pointer, UInt32(units.size))
                } finally {
                    releaseArrayRawData(handle)
                }
            }
        }
        this.ptr = raw
        this.ownsStorage = raw.isNotNull()
    }

    init(ptr: CPointer<UInt16>, ownsStorage: Bool) {
        this.ptr = ptr
        this.ownsStorage = ownsStorage
    }

    public static func fromRaw(ptr: CPointer<UInt16>): BasicString {
        BasicString(ptr, ptr.isNotNull())
    }

    public static func fromRawView(ptr: CPointer<UInt16>): BasicString {
        BasicString(ptr, false)
    }

    public func asRaw(): CPointer<UInt16> {
        if (closed) {
            return CPointer<UInt16>()
        }
        ptr
    }

    public func length(): Int64 {
        let livePtr = asRaw()
        if (livePtr.isNull()) {
            return 0
        }
        Int64(sysStringLenAbi(livePtr))
    }

    public func isEmpty(): Bool {
        length() == 0
    }

    public func toWideArray(): Array<UInt16> {
        copyWideFromPointer(asRaw(), length())
    }

    public func asWide(): Array<UInt16> {
        toWideArray()
    }

    public func decode(): String {
        decodeUtf16(toWideArray())
    }

    public func tryDecode(): Option<String> {
        tryDecodeUtf16(toWideArray())
    }

    public func toString(): String {
        decode()
    }

    public operator func [](index: Int64): UInt16 {
        asWide()[index]
    }

    public operator func ==(other: BasicString): Bool {
        let left = toWideArray()
        let right = other.toWideArray()
        if (left.size != right.size) {
            return false
        }

        var index: Int64 = 0
        while (index < Int64(left.size)) {
            if (left[index] != right[index]) {
                return false
            }
            index += 1
        }
        true
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed && ownsStorage && ptr.isNotNull()) {
            sysFreeStringAbi(ptr)
        }
        ptr = CPointer<UInt16>()
        ownsStorage = false
        closed = true
    }

    public func close(): Unit {
        if (!closed && ownsStorage && ptr.isNotNull()) {
            sysFreeStringAbi(ptr)
        }
        ptr = CPointer<UInt16>()
        ownsStorage = false
        closed = true
    }
}
