package windows_core

func closeOwnedState<T>(value: ?T, closed: Bool): (?T, Bool) where T <: Free & CloneResource<T> {
    if (!closed) {
        match (value) {
            case Some(resource) =>
                resource.free()
            case None =>
                ()
        }
    }
    (None, true)
}

public interface CloneResource<T> {
    func clone(): T
}

public interface Free {
    func free(): Unit
}

// Owned<T> gives deterministic close semantics to raw resources without
// importing foreign ownership models into the projected API surface.
public class Owned<T> <: Resource where T <: Free & CloneResource<T> {
    private var inner: ?T
    private var closed: Bool = false

    public init(value: T) {
        this.inner = Some(value)
    }

    public static func new(value: T): Owned<T> {
        Owned<T>(value)
    }

    public func isClosed(): Bool {
        closed
    }

    public func hasValue(): Bool {
        if (closed) {
            return false
        }
        match (inner) {
            case Some(_) => true
            case None => false
        }
    }

    public func value(): T {
        if (closed) {
            throw IllegalStateException("Owned resource is closed")
        }
        match (inner) {
            case Some(resource) => resource
            case None => throw IllegalStateException("Owned resource is closed")
        }
    }

    public func intoRaw(): T {
        if (closed) {
            throw IllegalStateException("Owned.intoRaw called on a closed resource")
        }

        match (inner) {
            case Some(resource) =>
                inner = None
                closed = true
                resource
            case None =>
                throw IllegalStateException("Owned.intoRaw requires a live resource")
        }
    }

    ~init() {
        let (nextValue, nextClosed) = closeOwnedState(inner, closed)
        inner = nextValue
        closed = nextClosed
    }

    public func close(): Unit {
        let (nextValue, nextClosed) = closeOwnedState(inner, closed)
        inner = nextValue
        closed = nextClosed
    }
}
