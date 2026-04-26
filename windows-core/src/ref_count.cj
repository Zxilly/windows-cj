package windows_core

import std.sync.*

// RefCount 封装基础的原子引用计数语义。
public struct RefCount {
    private let count: AtomicInt32

    public init() {
        count = AtomicInt32(1)
    }

    public static func new(count: UInt32): RefCount {
        let value = RefCount()
        if (count == 0u32) {
            value.count.store(0)
        } else if (count != 1u32) {
            value.count.store(Int32(count))
        }
        value
    }

    public func addRef(): Int32 {
        count.fetchAdd(1) + 1
    }

    public func release(): Int32 {
        let oldCount = count.fetchSub(1)
        if (oldCount <= 0) {
            count.fetchAdd(1)
            throw IllegalStateException("RefCount over-release")
        }
        let remaining = oldCount - 1
        if (remaining == 0) {
            let _ = count.load()
        }
        remaining
    }

    public func isOne(): Bool {
        count.load() == 1
    }
}
