package windows_collections

import windows_core.{E_NOTIMPL, Result, WinError}

func collectionTestNotImplemented<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_NOTIMPL))
}
