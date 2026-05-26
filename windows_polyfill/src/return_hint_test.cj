package windows_polyfill

import std.unittest.*
import std.unittest.testmacro.*

// ---------------------------------------------------------------------------
// hrSucceeded tests
// ---------------------------------------------------------------------------

// S_OK (0) is a success
@Test
func testHrSucceededSok() {
    @Expect(hrSucceeded(0i32), true)
}

// S_FALSE (1) is also a success (high bit clear)
@Test
func testHrSucceededSFalse() {
    @Expect(hrSucceeded(1i32), true)
}

// E_FAIL (0x80004005 = -2147467259 as Int32) is a failure
@Test
func testHrSucceededEFail() {
    @Expect(hrSucceeded(-2147467259i32), false)
}

// hrFailed is the complement of hrSucceeded
@Test
func testHrFailedEFail() {
    @Expect(hrFailed(-2147467259i32), true)
}

@Test
func testHrFailedSok() {
    @Expect(hrFailed(0i32), false)
}

// ---------------------------------------------------------------------------
// hrResultValue tests
// ---------------------------------------------------------------------------

// On success the wrapped value is returned unchanged
@Test
func testHrResultValueSuccess() {
    let result = hrResultValue(0i32, 42)
    @Expect(result, 42)
}

// String values are also passed through
@Test
func testHrResultValueSuccessString() {
    let result = hrResultValue(1i32, "hello")
    @Expect(result, "hello")
}

// ---------------------------------------------------------------------------
// hrResultVoid exception tests
// ---------------------------------------------------------------------------

// hrResultVoid throws HResultException on failure
@Test
func testHrResultVoidThrowsOnFailure() {
    var threw = false
    try {
        hrResultVoid(-1i32)
    } catch (e: HResultException) {
        threw = true
        // The stored code must equal the HRESULT we passed in
        @Expect(e.code, -1i32)
    }
    @Expect(threw, true)
}

// hrResultValue throws on failure
@Test
func testHrResultValueThrowsOnFailure() {
    var threw = false
    try {
        let _ = hrResultValue(-2147467259i32, 99)
    } catch (e: HResultException) {
        threw = true
        @Expect(e.code, -2147467259i32)
    }
    @Expect(threw, true)
}

// ---------------------------------------------------------------------------
// HResultException message format test
// ---------------------------------------------------------------------------

// E_FAIL should appear as 0x80004005 in the message
@Test
func testHrExceptionMessageHex() {
    var msg = ""
    try {
        hrResultVoid(-2147467259i32)
    } catch (e: HResultException) {
        msg = e.message
    }
    @Expect(msg, "HRESULT failure: 0x80004005")
}

// -1 (0xFFFFFFFF) should appear as ffffffff
@Test
func testHrExceptionMessageMinusOne() {
    var msg = ""
    try {
        hrResultVoid(-1i32)
    } catch (e: HResultException) {
        msg = e.message
    }
    @Expect(msg, "HRESULT failure: 0xffffffff")
}
