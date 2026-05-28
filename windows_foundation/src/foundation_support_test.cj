package windows_foundation

import windows_core.{E_FAIL, E_NOTIMPL, Result, WinError}

func foundationTestNotImplemented<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_NOTIMPL))
}

func foundationTestFail<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_FAIL))
}
