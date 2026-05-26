package windows_polyfill

import std.sync.Mutex

// Thread-safe lazy-initialisation cache.
// The factory closure is called exactly once on the first get(); every
// subsequent call returns the cached value without acquiring the lock
// (double-checked-locking pattern).
public class FactoryCache<T> {
    private let mtx: Mutex = Mutex()
    private var cached: ?T = None
    private let factory: () -> T

    public init(factory: () -> T) {
        this.factory = factory
    }

    public func get(): T {
        // Fast path: already initialised — no lock needed.
        match (cached) {
            case Some(v) => return v
            case None => ()
        }
        // Slow path: acquire lock and initialise once.
        synchronized(mtx) {
            match (cached) {
                case Some(v) => return v
                case None =>
                    let v = factory()
                    cached = Some(v)
                    return v
            }
        }
    }
}
