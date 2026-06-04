package windows_sample_core_app

import windows_sample_core_app_bindings.ApplicationModel.Core.CoreApplication
import windows_sample_core_app_bindings.ApplicationModel.Package
import windows_sample_core_app_bindings.UI.Core.CoreWindow
import windows_sample_core_app_bindings.Win32.System.Com.Apis as ComApis
import windows_sample_core_app_bindings.Win32.UI.WindowsAndMessaging.Apis as WamApis
import windows_sample_core_app_bindings.Win32.Foundation.HWND
import windows_sample_core_app_bindings.impl.{
    Windows_ApplicationModel_Core_IFrameworkView,
    Windows_ApplicationModel_Core_IFrameworkView_Impl,
    Windows_ApplicationModel_Core_IFrameworkViewSource,
    Windows_ApplicationModel_Core_IFrameworkViewSource_Impl,
    Windows_UI_Core_CoreProcessEventsOption_ProcessUntilQuit,
    Windows_Win32_System_Com_COINIT_COINIT_MULTITHREADED,
    Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_OK,
    Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_ICONSTOP
}
import windows_interface.macros.Implement
import windows_core as windows_core
import windows_core.WindowsException
import windows_strings.encodeUtf16WithNull

// ============================================================================
// core_app — behaviour-equivalent port of the reference sample.
//
// A CoreApplication bootstrap. We implement two WinRT interfaces as COM
// callable wrappers (CCWs): IFrameworkViewSource (one method, CreateView) and
// IFrameworkView (Initialize / SetWindow / Load / Run / Uninitialize). After
// CoInitializeEx and a Package.Current registration gate, we hand the view
// source to CoreApplication.Run, which drives the framework view: Run() fetches
// the thread's CoreWindow, activates it, and pumps its dispatcher until quit.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference uses an #[implement(IFoo)] attribute macro that turns a
//     struct into a COM object; here the generated bindings expose the same
//     machinery through @Implement[IFoo]. Decorating a class with
//     @Implement[IFrameworkView] makes the class satisfy the raw-ABI
//     IFrameworkView_Impl interface (each method takes the COM ABI arguments
//     and returns an Int32 HRESULT) and synthesises a .toComObject() that wraps
//     the Cangjie object behind a generated vtbl thunk. The runtime calls each
//     vtbl slot, which routes back into these methods — the identical ABI to
//     the reference's projected *_Impl trait methods.
//   • The reference's high-level methods (CoreWindow::GetForCurrentThread,
//     Activate, Dispatcher, ProcessEvents) return Result and use `?`; the
//     Cangjie projections .check() the HRESULT internally and throw a
//     WindowsException, which is the analogue of `?`. An uncaught throw aborts
//     with a non-zero exit; the happy path falls through to `return 0`.
//   • The reference returns Ok(CoreAppView().into()) from CreateView, i.e. it
//     hands back a brand-new IFrameworkView COM pointer with ownership
//     transferred to the caller. We build a fresh CoreAppView CCW, project it to
//     IFrameworkView, and write that raw pointer into the out slot WITHOUT
//     releasing it — the WinRT runtime now owns that reference (the +1 from
//     creating the CCW is exactly the reference the caller expects).
//   • COINIT_MULTITHREADED, the MB_* styles, and ProcessUntilQuit are plain
//     metadata constants; the generated value-level lets carry the same numeric
//     ABI values the reference's enum constants do.
//   • CoreApplication.Run takes the projected IFrameworkViewSource. We create
//     the CoreApp CCW and project it with intoInterface; the projected handle
//     keeps the Cangjie object (and thus its vtbl) alive for the duration of the
//     call, exactly like the reference's `let app: IFrameworkViewSource = ...`.
// ============================================================================

// IFrameworkView CCW. Initialize / Load / SetWindow / Uninitialize are no-ops
// returning S_OK (0); Run drives the CoreWindow message loop.
@Implement[Windows_ApplicationModel_Core_IFrameworkView]
public class CoreAppView {
    public func Initialize(_: CPointer<Unit>): Int32 {
        0
    }

    public func SetWindow(_: CPointer<Unit>): Int32 {
        0
    }

    public func Load(_: CPointer<Unit>): Int32 {
        0
    }

    public func Run(): Int32 {
        // Mirror the reference: get this thread's CoreWindow, activate it, then
        // pump its dispatcher until the app quits. Each projected call .check()s
        // its HRESULT and throws on failure; translate any throw into the
        // failing HRESULT for the vtbl thunk.
        try {
            let window = CoreWindow.GetForCurrentThread()
            window.Activate()
            let dispatcher = window.Dispatcher
            dispatcher.ProcessEvents(Windows_UI_Core_CoreProcessEventsOption_ProcessUntilQuit)
            0
        } catch (error: WindowsException) {
            error.code().value
        }
    }

    public func Uninitialize(): Int32 {
        0
    }
}

// IFrameworkViewSource CCW. CreateView builds a fresh IFrameworkView CCW and
// transfers ownership of its COM pointer to the caller via the out slot.
@Implement[Windows_ApplicationModel_Core_IFrameworkViewSource]
public class CoreApp {
    public func CreateView(viewProvider: CPointer<CPointer<Unit>>): Int32 {
        if (viewProvider.isNull()) {
            return -2147467261 // E_POINTER
        }
        // Build the view CCW and project it to IFrameworkView. intoInterface
        // hands us an owned reference; we move that reference into the out slot
        // (the WinRT runtime takes ownership), so we must NOT release it here.
        let view = CoreAppView().toComObject().intoInterface(Windows_ApplicationModel_Core_IFrameworkView.descriptor())
        unsafe { viewProvider.write(view.asRaw()) }
        0
    }
}

main(): Int64 {
    // Initialise COM for this thread (multithreaded apartment), mirroring the
    // reference's CoInitializeEx(None, COINIT_MULTITHREADED).
    unsafe {
        ComApis.CoInitializeExChecked(
            CPointer<Unit>(),
            UInt32(Windows_Win32_System_Com_COINIT_COINIT_MULTITHREADED)
        )
    }

    // Registration gate: a CoreApplication app must run from an installed app
    // package. Package.Current() throws when there is no package identity (e.g.
    // a plain console launch). The reference shows a blocking MessageBox and
    // returns the error; we do the same, then exit non-zero.
    try {
        Package.Current()
    } catch (error: WindowsException) {
        let text = encodeUtf16WithNull(
            "This sample must be registered (via register.cmd) and launched from Start."
        )
        let caption = encodeUtf16WithNull("Error")
        unsafe {
            let textHandle = acquireArrayRawData(text)
            let captionHandle = acquireArrayRawData(caption)
            try {
                let style = Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_ICONSTOP |
                    Windows_Win32_UI_WindowsAndMessaging_MESSAGEBOX_STYLE_MB_OK
                WamApis.MessageBoxW(HWND(), textHandle.pointer, captionHandle.pointer, style.value)
            } finally {
                releaseArrayRawData(textHandle)
                releaseArrayRawData(captionHandle)
            }
        }
        return Int64(error.code().value)
    }

    // Hand the view source CCW to CoreApplication.Run, which drives the
    // framework view lifecycle. Run() .check()s its HRESULT internally; an
    // uncaught throw aborts with a non-zero exit.
    let app = CoreApp().toComObject().intoInterface(Windows_ApplicationModel_Core_IFrameworkViewSource.descriptor())
    CoreApplication.Run(app)
    return 0
}
