package result_smoke_public_app

import windows_result.*
import windows_result.Error as WinError

foreign func SetLastError(dwErrCode: UInt32): Unit

func expect(condition: Bool, message: String): Unit {
    if (!condition) {
        throw Exception(message)
    }
}

main(): Unit {
    let loadFlags: LOAD_LIBRARY_FLAGS = LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
    expect(loadFlags == LOAD_LIBRARY_SEARCH_DEFAULT_DIRS, "LOAD_LIBRARY_FLAGS should be public")

    let accessDenied = HRESULT.fromWin32(5u32)
    expect(accessDenied == E_ACCESSDENIED, "HRESULT.fromWin32 should preserve public HRESULT behavior")

    let boolFalse = BOOL(false)
    unsafe { SetLastError(5u32) }
    let boolResult = boolFalse.ok()
    expect(boolResult.isErr(), "BOOL.ok() should produce Err on FALSE")

    let win32 = WIN32_ERROR(5u32)
    expect(win32.toHRESULT() == accessDenied, "WIN32_ERROR.toHRESULT should remain public")
    expect(WinError.from(win32).code() == accessDenied, "Error.from(WIN32_ERROR) should remain public")

    let nt = NTSTATUS(-1073741819i32)
    expect(nt.toHRESULT().message() != "", "NTSTATUS-backed HRESULT.message() should still resolve system text")

    let rpc = RPC_STATUS(5i32)
    expect(rpc.toHRESULT() == accessDenied, "RPC_STATUS should map through FACILITY_WIN32")

    let customError = WinError.new(E_FAIL, "public custom failure")
    expect(customError.code() == E_FAIL, "Error.new should preserve HRESULT")
    expect(customError.message() == "public custom failure", "Error.new should surface custom text in full mode")

    customError.intoThread()
    let roundTripped = WinError.fromHRESULTWithInfo(E_FAIL)
    expect(roundTripped.as_ptr().isNotNull(), "Error.fromHRESULTWithInfo should keep COM error info in full mode")
    expect(roundTripped.message() == "public custom failure", "Error.fromHRESULTWithInfo should recover thread error info")

    let okResult = Result<Int32>.Ok(7i32)
    let errResult = Result<Int32>.Err(WinError.fromHRESULT(E_FAIL))
    expect(okResult.unwrap() == 7i32, "Result.unwrap() should return the success value")
    expect(errResult.unwrapErr().code() == E_FAIL, "Result.unwrapErr() should return the stored Error")
}