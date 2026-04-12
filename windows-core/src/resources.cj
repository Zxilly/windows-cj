package windows_core

public interface CloneResource<T> {
    func clone(): T
}

// Free 表示值可以主动释放其持有的底层资源。
public interface Free {
    func free(): Unit
}

// Owned<T> 提供一个简单的所有权包装，析构时自动释放资源。
public class Owned<T> <: Resource where T <: Free & CloneResource<T> {
    private var inner: ?T

    private init(value: T) {
        inner = Some(value)
    }

    public unsafe static func new(value: T): Owned<T> {
        Owned<T>(value)
    }

    public func get(): T {
        if (let Some(value) <- inner) {
            return value
        }
        throw IllegalStateException("Owned value has already been released")
    }

    public func isClosed(): Bool {
        match (inner) {
            case Some(_) => false
            case None => true
        }
    }

    public func close(): Unit {
        drop()
    }

    public func intoRaw(): T {
        if (let Some(value) <- inner) {
            inner = None
            return value
        }
        throw IllegalStateException("Owned value has already been released")
    }

    public func drop(): Unit {
        if (let Some(value) <- inner) {
            value.free()
            inner = None
        }
    }

    ~init() {
        if (let Some(value) <- inner) {
            value.free()
            inner = None
        }
    }
}
