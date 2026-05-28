package windows_future

import windows_core.{E_NOTIMPL, Result, WinError}

func futureTestNotImplemented<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_NOTIMPL))
}
