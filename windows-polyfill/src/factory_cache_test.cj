package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*
import std.sync.*
import std.collection.*
import std.time.*

// Test: factory is called exactly once across 10 sequential get() calls.
@Test
func testFactoryCacheCallsFactoryOnce() {
    let callCount = AtomicInt64(0)
    let cache = FactoryCache<String>({ =>
        callCount.fetchAdd(1)
        "hello"
    })
    for (_ in 0..10) {
        let v = cache.get()
        @Expect(v, "hello")
    }
    @Expect(callCount.load(), 1i64)
}

// Test: returned value has the correct type and content.
@Test
func testFactoryCacheReturnType() {
    let cache = FactoryCache<Int64>({ => 42i64 })
    let v = cache.get()
    @Expect(v, 42i64)
}

// Test: factory returning a class instance is cached (same value on repeat calls).
@Test
func testFactoryCacheClassInstance() {
    let created = AtomicInt64(0)
    let cache = FactoryCache<Box<Int64>>({ =>
        created.fetchAdd(1)
        Box<Int64>(99)
    })
    let a = cache.get()
    let b = cache.get()
    @Expect(created.load(), 1i64)
    @Expect(a.value, 99i64)
    @Expect(b.value, 99i64)
}

// Test: concurrent get() from 10 threads — factory must be called exactly once.
@Test
func testFactoryCacheConcurrent() {
    let callCount = AtomicInt64(0)
    let cache = FactoryCache<String>({ =>
        callCount.fetchAdd(1)
        // Small delay so racing threads are more likely to overlap.
        sleep(5 * Duration.millisecond)
        "result"
    })

    let futures = ArrayList<Future<String>>()
    for (_ in 0..10) {
        let fut = spawn { => cache.get() }
        futures.add(fut)
    }

    for (f in futures) {
        let v = f.get()
        @Expect(v, "result")
    }

    @Expect(callCount.load(), 1i64)
}
