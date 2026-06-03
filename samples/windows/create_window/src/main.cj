package windows_sample_create_window

import windows_sample_create_window_bindings.Win32.Foundation.{HWND, HINSTANCE}
import windows_sample_create_window_bindings.Win32.UI.WindowsAndMessaging.{Apis, WNDCLASSA, MSG, HMENU}
import windows_sample_create_window_bindings.Win32.Graphics.Gdi.Apis as GdiApis
import windows_sample_create_window_bindings.Win32.System.LibraryLoader.Apis as LoaderApis
import windows_strings.narrowStringFactory
import windows_polyfill.handlePointerFromInt

// ============================================================================
// create_window — behaviour-equivalent port of the reference sample.
//
// Registers a WNDCLASSA whose window procedure is a top-level @C callback,
// creates a single visible top-level overlapped window via CreateWindowExA,
// then drives the classic GetMessageA / DispatchMessageA pump until the window
// is destroyed (WM_DESTROY -> PostQuitMessage -> GetMessageA returns 0).
//
// The wndproc handles:
//   • WM_PAINT   -> prints "WM_PAINT", validates the whole client rect.
//   • WM_DESTROY -> prints "WM_DESTROY", posts the quit message.
//   • everything else -> DefWindowProcA.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The WNDPROC is a top-level `@C func`. Cangjie @C functions ARE CFunc
//     values and can be stored directly in WNDCLASSA.lpfnWndProc (a CFunc
//     field), matching the reference's `Some(wndproc)` function pointer. @C
//     funcs cannot capture, exactly like the reference's `extern "system" fn`.
//   • There is no compile-time `s!` ANSI literal. narrowStringFactory builds a
//     NUL-terminated UTF-8 buffer and pins it through `withPtr`; the class-name
//     and window-name buffers stay pinned for the ENTIRE message loop (the
//     pointers are read by the window manager for the window's whole lifetime),
//     so registration + creation + the pump all run inside the nested closures.
//   • The scalar window constants are not re-exported by the facade (it only
//     surfaces the wrapped WINDOW_STYLE / WNDCLASS_STYLES newtypes), so the
//     documented bit values are hardcoded below — semantically identical.
//   • IDC_ARROW is MAKEINTRESOURCE(32512): a pseudo-pointer whose numeric value
//     is the resource id. handlePointerFromInt fabricates that pointer from the
//     integer, the run-time analogue of the MAKEINTRESOURCE macro.
//   • HWND/HINSTANCE are @C structs whose null state is the default ctor (null
//     Value pointer) — the equivalent of the reference's `None`.
//   • GetModuleHandleA returns an HMODULE; the WNDCLASSA wants an HINSTANCE.
//     Both are @C structs wrapping a single CPointer<Unit>; copying the Value
//     pointer is the behavioural twin of the reference's `instance.into()`.
// ============================================================================

// Class styles (WNDCLASS_STYLES): CS_HREDRAW (2) | CS_VREDRAW (1).
const CS_HREDRAW: UInt32 = 0x0002
const CS_VREDRAW: UInt32 = 0x0001

// Window styles (WINDOW_STYLE): WS_OVERLAPPEDWINDOW (0x00CF0000) | WS_VISIBLE
// (0x10000000).
const WS_OVERLAPPEDWINDOW: UInt32 = 0x00CF_0000
const WS_VISIBLE: UInt32 = 0x1000_0000

// CW_USEDEFAULT lets the window manager pick the default position/size. The
// documented value is 0x80000000, which as a signed Int32 is Int32.Min.
const CW_USEDEFAULT: Int32 = -2147483648

// IDC_ARROW standard cursor resource id (MAKEINTRESOURCE(32512)).
const IDC_ARROW_ID: Int64 = 32512

// The window procedure. Signature must match
// CFunc<(HWND, UInt32, UIntNative, IntNative) -> IntNative>.
@C
func wndproc(window: HWND, message: UInt32, wparam: UIntNative, lparam: IntNative): IntNative {
    // Constant patterns must be literals (a bare `const` identifier would parse
    // as a binding pattern), so the documented message ids are matched directly:
    // WM_PAINT = 0x000F, WM_DESTROY = 0x0002.
    unsafe {
        match (message) {
            case 0x000F =>
                println("WM_PAINT")
                // ValidateRect(Some(window), None): null rect validates all.
                GdiApis.ValidateRect(window, CPointer<Unit>())
                return 0
            case 0x0002 =>
                println("WM_DESTROY")
                Apis.PostQuitMessage(0)
                return 0
            case _ =>
                return Apis.DefWindowProcA(window, message, wparam, lparam)
        }
    }
}

main(): Int64 {
    // GetModuleHandleA(None): module handle of the current process image.
    let instance = unsafe { LoaderApis.GetModuleHandleA(CPointer<UInt8>()) }
    if (instance.Value.isNull()) {
        return 1
    }

    // @C structs (HWND/HINSTANCE/HMODULE) cannot be captured by a closure, so
    // the raw module pointer is hoisted as a plain CPointer<Unit> and the
    // HINSTANCE is rebuilt inside the innermost lambda (the behavioural twin of
    // the reference's `instance.into()`).
    let instancePtr = instance.Value

    // Pin the class-name and window-name UTF-8 buffers for the whole loop: the
    // window manager keeps the lpszClassName pointer alive for the window's
    // entire lifetime, so neither buffer may be freed until the pump exits.
    // Each closure yields its Int64 exit code as its trailing expression.
    return narrowStringFactory("window").withPtr { className =>
        narrowStringFactory("This is a sample window").withPtr { windowName =>
            // LoadCursorW(None, IDC_ARROW). IDC_ARROW is a resource-id pseudo
            // pointer; reinterpret it as the wide cursor-name pointer.
            let cursor = unsafe {
                Apis.LoadCursorW(HINSTANCE(), CPointer<UInt16>(handlePointerFromInt(IDC_ARROW_ID)))
            }

            // HMODULE -> HINSTANCE: copy the module pointer into a fresh
            // HINSTANCE (constructed here so it is never captured).
            var hinst = HINSTANCE()
            hinst.Value = instancePtr

            var wc = WNDCLASSA()
            wc.hCursor = cursor
            wc.hInstance = hinst
            wc.lpszClassName = className.asPtr()
            wc.style = CS_HREDRAW | CS_VREDRAW
            wc.lpfnWndProc = wndproc

            let atom = unsafe {
                let wcPtr = CPointer<Unit>(CPointer<WNDCLASSA>(inout wc))
                Apis.RegisterClassA(wcPtr)
            }

            // debug_assert!(atom != 0)
            if (atom == 0) {
                1
            } else {
                // CreateWindowExA(WINDOW_EX_STYLE::default()=0, class, title,
                // WS_OVERLAPPEDWINDOW | WS_VISIBLE, CW_USEDEFAULT*4, None, None,
                // None, None). The trailing None handles are null @C structs /
                // null pointers; HMENU is null via its field default.
                let win = unsafe {
                    Apis.CreateWindowExA(
                        0u32,
                        className.asPtr(),
                        windowName.asPtr(),
                        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                        CW_USEDEFAULT,
                        CW_USEDEFAULT,
                        CW_USEDEFAULT,
                        CW_USEDEFAULT,
                        HWND(),
                        HMENU(),
                        hinst,
                        CPointer<Unit>()
                    )
                }

                if (win.Value.isNull()) {
                    1
                } else {
                    // GetMessageA / DispatchMessageA pump. GetMessageA returns
                    // >0 while messages flow, 0 on WM_QUIT, -1 on error — loop
                    // while > 0.
                    var message = MSG()
                    unsafe {
                        let msgPtr = CPointer<Unit>(CPointer<MSG>(inout message))
                        while (Apis.GetMessageA(msgPtr, HWND(), 0, 0) > 0) {
                            Apis.DispatchMessageA(msgPtr)
                        }
                    }
                    0
                }
            }
        }
    }
}
