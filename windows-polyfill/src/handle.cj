package windows_polyfill

// Handle polyfill: validity helpers for Win32 handle values.
//
// Win32 handles are represented at the C ABI level as pointer-sized integers.
// In generated code, a handle is either:
//   - a `@C struct { public var value: IntNative }` (bindgen newtype), or
//   - a plain `IntNative` type alias.
//
// Two distinct "invalid" conventions exist in Win32:
//   - NULL (0)          — used by most kernel handles (HKEY, SC_HANDLE, …)
//   - INVALID_HANDLE_VALUE (-1) — used by file/pipe/console handles
//
// Callers pick the appropriate helper for the handle type.

// INVALID_HANDLE_VALUE as returned by CreateFile and similar APIs.
public let INVALID_HANDLE_VALUE_RAW: IntNative = IntNative(-1)

// handleIsInvalidRaw returns true for both NULL and INVALID_HANDLE_VALUE.
// Use for HANDLE (file, pipe, event, thread, process, …).
public func handleIsInvalidRaw(v: IntNative): Bool {
    return v == IntNative(0) || v == INVALID_HANDLE_VALUE_RAW
}

// handleIsNullRaw returns true only when the value is NULL (0).
// Use for handle types where only 0 means invalid (HKEY, HMODULE, HWND, …).
public func handleIsNullRaw(v: IntNative): Bool {
    return v == IntNative(0)
}

// handleIsMinusOneRaw returns true only when the value is -1.
// Rarely needed directly; prefer handleIsInvalidRaw for file handles.
public func handleIsMinusOneRaw(v: IntNative): Bool {
    return v == INVALID_HANDLE_VALUE_RAW
}
