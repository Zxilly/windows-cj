package windows_result

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testResultOkAndErrOptionHelpers() {
    let ok = Result<Int64>.Ok(7)
    let err = Result<Int64>.Err(errorFromHRESULT(E_POINTER))

    @Expect(ok.ok(), Some(7))
    @Expect(ok.err(), None)
    @Expect(err.ok(), None)
    @Expect(err.err().isSome(), true)
    @Expect(err.unwrapErr().code(), E_POINTER)
}

@Test
func testResultErrMappingAndRecoveryHelpers() {
    let original = Result<Int64>.Err(errorFromHRESULT(E_FAIL))
    let mapped = original.mapErr({ _ => errorFromHRESULT(E_INVALIDARG) })
    let recovered = mapped.orElse({ error =>
        @Expect(error.code(), E_INVALIDARG)
        Result<Int64>.Ok(11)
    })

    @Expect(mapped.unwrapErr().code(), E_INVALIDARG)
    @Expect(recovered.unwrap(), 11)
    @Expect(Result<Int64>.Ok(3).unwrapOrElse({ _ => 99 }), 3)
    @Expect(original.unwrapOrElse({ error =>
        @Expect(error.code(), E_FAIL)
        99
    }), 99)
}

@Test
func testHResultAndWin32RoundTripHelpers() {
    let win32Error = WIN32_ERROR(5u32)
    let error = win32Error.toError()

    @Expect(HRESULT.from(Result<Int64>.Ok(1)), S_OK)
    @Expect(HRESULT.from(Result<Int64>.Err(error)), E_ACCESSDENIED)
    @Expect(errorCode(error), E_ACCESSDENIED)
    @Expect(errorToHRESULT(error), E_ACCESSDENIED)

    match (WIN32_ERROR.from(error)) {
        case Some(code) => @Expect(code.value, win32Error.value)
        case None => @Fail("expected WIN32_ERROR.from(error) to recover the original code")
    }

    @Expect(WIN32_ERROR.from(errorFromHRESULT(E_FAIL)).isNone(), true)
}
