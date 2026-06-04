package windows_canvas

import windows_core.HRESULT

// Well-known HRESULT values that indicate a GPU device has been lost.
// These scalar HRESULTs are not surfaced by the facade, so the documented
// MSDN values are recorded here as constants (the high-bit values are written
// as signed Int32, the value an `HRESULT` wraps).
const DXGI_ERROR_DEVICE_REMOVED: Int32 = -2005270523        // 0x887A0005
const DXGI_ERROR_DEVICE_HUNG: Int32 = -2005270522           // 0x887A0006
const DXGI_ERROR_DEVICE_RESET: Int32 = -2005270521          // 0x887A0007
const DXGI_ERROR_DRIVER_INTERNAL_ERROR: Int32 = -2005270496 // 0x887A0020
const D2DERR_RECREATE_TARGET: Int32 = -2003238900           // 0x8899000C

// Returns `true` if the given HRESULT indicates the GPU device was lost.
//
// Cangjie paradigm note (equivalent): the reference uses a `matches!` over the
// HRESULT constants. A bare const identifier used as a `match` pattern parses
// as a wildcard binding in Cangjie, so the equivalent comparison is written as
// an explicit value check against the documented codes.
func isDeviceLost(hr: HRESULT): Bool {
    let v = hr.value
    return v == DXGI_ERROR_DEVICE_REMOVED ||
        v == DXGI_ERROR_DEVICE_RESET ||
        v == DXGI_ERROR_DEVICE_HUNG ||
        v == DXGI_ERROR_DRIVER_INTERNAL_ERROR ||
        v == D2DERR_RECREATE_TARGET
}
