package windows_result

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testHResultAndWin32ErrorConversions() {
    @Expect(S_OK.isOk(), true)
    @Expect(E_FAIL.isErr(), true)
    @Expect(HRESULT.fromWin32(5u32), E_ACCESSDENIED)
    @Expect(E_ACCESSDENIED.toString(), "0x80070005")
    @Expect(WIN32_ERROR(0u32).isOk(), true)
    @Expect(WIN32_ERROR(5u32).toHRESULT(), E_ACCESSDENIED)
}

@Test
func testResultCombinatorsPreserveOkAndErr() {
    let ok = Result<Int64>.Ok(2)
    let mapped = ok.map({ value => value + 3 })
    let chained = ok.andThen({ value => Result<String>.Ok("${value}") })
    let err = Result<Int64>.Err(errorFromHRESULT(E_FAIL))

    @Expect(mapped.unwrap(), 5)
    @Expect(chained.unwrap(), "2")
    @Expect(err.isErr(), true)
    @Expect(err.unwrapOr(9), 9)
}
