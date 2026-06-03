package windows_sample_message_box

import windows_sample_message_box_bindings.Win32.Foundation.{HWND, HINSTANCE}
import windows_sample_message_box_bindings.Win32.UI.WindowsAndMessaging.Apis
import windows_sample_message_box_bindings.Win32.UI.Shell.Apis as ShellApis
import windows_strings.{narrowStringFactory, wideStringFactory, hStringFactory}

// ============================================================================
// message_box — behaviour-equivalent port of the reference sample.
//
// Pops three MODAL system dialogs, each with a null parent window:
//   • MessageBoxA   — ANSI/UTF-8 text + caption, MB_OK button.
//   • MessageBoxW    — wide (UTF-16) text + caption, MB_OK button.
//   • ShellMessageBoxW — wide text + caption with an error icon
//     (SHLWAPI ordinal export, null hInstance + null hWnd).
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference's None parent handle is modelled by the default-constructed
//     @C struct HWND() (whose Value pointer is null); likewise HINSTANCE().
//   • The reference's compile-time string literals s!/w!/h! have no const-fn
//     equivalent here. The string factories from windows_strings are the
//     behavioural twin: each builds a null-terminated UTF-8 / UTF-16 buffer and
//     exposes it through `withPtr`, which keeps the backing array pinned for the
//     whole (blocking) call — exactly what a modal dialog requires.
//       - s!  -> narrowStringFactory  (PCSTR  -> CPointer<UInt8>)
//       - w!  -> wideStringFactory    (PCWSTR -> CPointer<UInt16>)
//       - h!  -> hStringFactory       (PCWSTR -> CPointer<UInt16>); the dialog
//               only ever reads the wide buffer, so a reference-backed HSTRING
//               and a wide literal are indistinguishable to MessageBoxW.
//   • MB_OK (0x0) and MB_ICONERROR (0x10) are documented MESSAGEBOX_STYLE bits.
//     The uType parameter is a plain UInt32, so the bits are passed literally;
//     the facade does not re-export the scalar constants.
//   • These functions return the dialog result code (Int32), not a fallible
//     HRESULT/BOOL, so the generator emits no `*Checked` twin — matching the
//     reference, which calls them without `?`.
// ============================================================================

// MB_OK button-only style (MESSAGEBOX_STYLE = 0x0000_0000).
const MB_OK: UInt32 = 0x0000_0000
// MB_ICONERROR — hand/stop error icon (MESSAGEBOX_STYLE = 0x0000_0010).
const MB_ICONERROR: UInt32 = 0x0000_0010

main(): Int64 {
    // HWND/HINSTANCE are @C structs and Cangjie forbids capturing them in a
    // closure, so the null parent/module handles (default ctor => null Value
    // pointer, the equivalent of the reference's None) are constructed inside
    // each innermost lambda rather than hoisted and captured.

    // MessageBoxA(None, s!("Ansi"), s!("World"), MB_OK)
    narrowStringFactory("Ansi").withPtr { text =>
        narrowStringFactory("World").withPtr { caption =>
            Apis.MessageBoxA(HWND(), text.asPtr(), caption.asPtr(), MB_OK)
        }
    }

    // MessageBoxW(None, h!("WinRT"), h!("World"), MB_OK)
    hStringFactory("WinRT").withPtr { text =>
        hStringFactory("World").withPtr { caption =>
            Apis.MessageBoxW(HWND(), text.asPtr(), caption.asPtr(), MB_OK)
        }
    }

    // ShellMessageBoxW(None, None, w!("Wide"), w!("World"), MB_ICONERROR)
    wideStringFactory("Wide").withPtr { text =>
        wideStringFactory("World").withPtr { caption =>
            ShellApis.ShellMessageBoxW(HINSTANCE(), HWND(), text.asPtr(), caption.asPtr(), MB_ICONERROR)
        }
    }

    return 0
}
