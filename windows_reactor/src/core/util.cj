package windows_reactor.core

// Shared option-equality helpers used by hand-written equivalent()/equals()
// methods across the core data model. Cangjie has no derive(PartialEq); these
// keep the comparison logic terse and uniform.

func optStrEq(a: ?String, b: ?String): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

func optF64Eq(a: ?Float64, b: ?Float64): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

func optI64Eq(a: ?Int64, b: ?Int64): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

func optBoolEq(a: ?Bool, b: ?Bool): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

func optU16Eq(a: ?UInt16, b: ?UInt16): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

// Generic option equality for any Equatable payload type.
func optEq<T>(a: ?T, b: ?T): Bool where T <: Equatable<T> {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

// Compare two arrays of an Equatable element type elementwise.
func arrayEq<T>(a: Array<T>, b: Array<T>): Bool where T <: Equatable<T> {
    if (a.size != b.size) {
        return false
    }
    var i = 0
    while (i < a.size) {
        if (a[i] != b[i]) {
            return false
        }
        i++
    }
    true
}
