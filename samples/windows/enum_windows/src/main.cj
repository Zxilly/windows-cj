package windows_sample_enum_windows

import windows_sample_enum_windows_bindings.Win32.Foundation.{HWND, LPARAM, BOOL}
import windows_sample_enum_windows_bindings.Win32.UI.WindowsAndMessaging.{Apis, WINDOWINFO}
import windows_strings.decodeUtf16

// ============================================================================
// enum_windows — behaviour-equivalent port of the reference sample.
//
// Enumerates every top-level window via EnumWindows. For each window the
// per-window callback reads its title with GetWindowTextW into a fixed UTF-16
// buffer, queries GetWindowInfo for its style + screen rect, and prints the
// title with its top-left corner when the title is non-empty and the window
// carries WS_VISIBLE. The process then exits.
//
// Paradigm note (Cangjie vs the reference language):
//   • The WNDENUMPROC callback is a top-level `@C func`. Cangjie's @C functions
//     ARE CFunc values and can be handed to a C API expecting a function
//     pointer; they cannot capture variables, so the callback prints directly
//     instead of closing over an accumulator. This matches the reference, whose
//     `extern "system" fn` callback also captures nothing.
//   • HWND is an @C struct, LPARAM/BOOL are integer ABI aliases (IntNative /
//     Int32). There is no `null`; absence is modelled with Option<T>, but this
//     sample never needs one — the buffer is a stack/GC Array and the window
//     handle is a plain ABI value.
// ============================================================================

// WS_VISIBLE bit of the window style (WINDOW_STYLE = 0x10000000). The generated
// WINDOWINFO.dwStyle is a plain UInt32, so the visibility test is a bitmask.
const WS_VISIBLE: UInt32 = 0x1000_0000

// The WNDENUMPROC callback. Signature must match
// CFunc<(HWND, IntNative) -> Int32>: HWND handle + LPARAM, returning a BOOL
// (Int32) where non-zero continues enumeration.
@C
func enumWindow(window: HWND, _: LPARAM): BOOL {
    // 512-element UTF-16 title buffer, mirroring the reference's [u16; 512].
    let text = Array<UInt16>(512, repeat: 0u16)
    unsafe {
        let textHandle = acquireArrayRawData(text)
        try {
            let len = Apis.GetWindowTextW(window, textHandle.pointer, 512)
            let title = if (len > 0) {
                decodeUtf16(text[0..Int64(len)])
            } else {
                ""
            }

            // Query the window's style + screen rectangle. GetWindowInfo takes a
            // raw pointer; cbSize must be initialised to the struct size.
            var info = WINDOWINFO()
            info.cbSize = UInt32(sizeOf<WINDOWINFO>())
            let infoPtr = CPointer<Unit>(CPointer<WINDOWINFO>(inout info))
            Apis.GetWindowInfoChecked(window, infoPtr)

            if (!title.isEmpty() && (info.dwStyle & WS_VISIBLE) != 0u32) {
                println("${title} (${info.rcWindow.left}, ${info.rcWindow.top})")
            }
        } finally {
            releaseArrayRawData(textHandle)
        }
    }

    // BOOL true (non-zero) -> keep enumerating.
    return 1i32
}

main(): Int64 {
    // EnumWindows returns 0 on failure; treat that as a non-zero exit code so the
    // sample is self-terminating and reports its status, matching the reference's
    // Result-returning main.
    let ok = Apis.EnumWindows(enumWindow, 0)
    if (ok == 0) {
        return 1
    }
    return 0
}
