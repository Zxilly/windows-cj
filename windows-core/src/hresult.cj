package windows_core

public import windows_result.{
    HRESULT,
    Result,
    BOOL,
    TRUE,
    FALSE,
    WIN32_ERROR,
    NTSTATUS,
    RPC_STATUS,
    S_OK,
    S_FALSE,
    E_FAIL,
    E_NOINTERFACE,
    E_NOTIMPL,
    E_POINTER,
    E_OUTOFMEMORY,
    E_INVALIDARG,
    E_ACCESSDENIED,
    E_UNEXPECTED,
    E_ABORT
}

public let CO_E_NOTINITIALIZED: HRESULT = HRESULT(-2147221008i32)
public let REGDB_E_CLASSNOTREG: HRESULT = HRESULT(-2147221164i32)
