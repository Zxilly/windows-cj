package windows_threading

import std.sync.Mutex
import std.unittest.*
import std.unittest.testmacro.*

class ThreadingCounter {
    let mutex = Mutex()
    var value = 0

    func add(delta: Int64): Unit {
        synchronized(mutex) {
            value += delta
        }
    }

    func get(): Int64 {
        synchronized(mutex) {
            value
        }
    }
}

func actionThrows(action: () -> Unit): Bool {
    try {
        action()
    } catch (_: Exception) {
        return true
    }
    false
}

@When[os == "Windows"]
@Test
func testForEachWaitsForAllSubmittedItems() {
    let counter = ThreadingCounter()

    forEach<Int64>([1, 2, 3, 4], { value =>
        counter.add(value)
    })

    @Expect(counter.get(), 10)
}

@When[os == "Windows"]
@Test
func testWithScopeReturnsBodyValueAfterJoiningWork() {
    let counter = ThreadingCounter()
    let result = Pool.withScope<Int64> { scope =>
        scope.submit({ => counter.add(4) })
        scope.submit({ => counter.add(6) })
        42
    }

    @Expect(result, 42)
    @Expect(counter.get(), 10)
}

@When[os == "Windows"]
@Test
func testPoolRejectsSubmitAfterClose() {
    let pool = Pool()
    pool.close()

    @Expect(pool.isClosed(), true)
    @Expect(actionThrows({ => pool.submit({ => () }) }), true)
}
