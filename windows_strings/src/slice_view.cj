package windows_strings

import std.collection.*

class PointerSliceIterator<T> <: Iterator<T> where T <: CType {
    private let ptr: CPointer<T>
    private let length: Int64
    private var index: Int64 = 0

    public init(ptr: CPointer<T>, length: Int64) {
        this.ptr = ptr
        this.length = length
    }

    public func next(): Option<T> {
        if (index >= length) {
            return None
        }
        let current = unsafe { (ptr + index).read() }
        index += 1
        Some(current)
    }
}

/// A read-only view over a contiguous region of memory owned by an external resource.
///
/// **Borrow lifetime:** The view is valid only while the resource that produced it
/// (e.g. the `HString` or `HStringBuilder` passed as `owner`) remains alive and
/// not closed. Do not retain a `PointerSliceView` beyond the lifetime of its owner.
public class PointerSliceView<T> <: ReadOnlyList<T> where T <: CType {
    private let ptr: CPointer<T>
    private let length: Int64
    private let owner: Option<Any>

    public init(ptr: CPointer<T>, length: Int64, owner!: Option<Any> = None) {
        this.ptr = ptr
        this.length = if (length < 0) { 0 } else { length }
        this.owner = owner
    }

    public prop size: Int64 {
        get() {
            length
        }
    }

    public func isEmpty(): Bool {
        length == 0
    }

    public func iterator(): Iterator<T> {
        PointerSliceIterator<T>(ptr, length)
    }

    public prop first: Option<T> {
        get() {
            get(0)
        }
    }

    public prop last: Option<T> {
        get() {
            get(length - 1)
        }
    }

    public func get(index: Int64): Option<T> {
        if (ptr.isNull() || index < 0 || index >= length) {
            return None
        }
        Some(unsafe { (ptr + index).read() })
    }

    public operator func [](index: Int64): T {
        match (get(index)) {
            case Some(value) => value
            case None => throw IndexOutOfBoundsException("PointerSliceView index out of bounds")
        }
    }

    public func asPtr(): CPointer<T> {
        ptr
    }
}
