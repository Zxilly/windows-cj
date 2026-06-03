package windows_sample_uiautomation

import windows_sample_uiautomation_bindings.Win32.System.Com.Apis as ComApis
import windows_sample_uiautomation_bindings.Win32.UI.WindowsAndMessaging.Apis as WinApis
import windows_sample_uiautomation_bindings.Win32.UI.Accessibility.{
    IUIAutomation,
    IUIAutomationVtbl,
    IUIAutomationElement,
    IUIAutomationElementVtbl
}
import windows_sample_uiautomation_bindings.Win32.Foundation.HWND
import windows_sample_uiautomation_bindings.UI.UIAutomation.AutomationElement
import windows_strings.{narrowStringFactory, BSTR}
import windows_core.{HRESULT, queryInterfaceAs}
import windows_interface.GUID

// ============================================================================
// uiautomation — behaviour-equivalent port of the reference sample.
//
// Locates the "Calculator" top-level window with FindWindowA, boots the COM
// runtime, creates the CUIAutomation COM server (the IUIAutomation root), and
// asks it for the IUIAutomationElement that backs that window. We read the
// element's classic-COM CurrentName property (a BSTR) and print it, then cast
// the same element to the WinRT AutomationElement projection (a QueryInterface
// for IAutomationElement) and, when that succeeds, read its WinRT
// ExecutableFileName property and print it. The process then exits.
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no compile-time `s!` ANSI literal. narrowStringFactory builds a
//     NUL-terminated UTF-8 buffer at run time and pins it through withPtr for the
//     duration of the FindWindowA call — the behavioural twin of `s!("Calculator")`.
//     The `None` class-name argument is a null CPointer<UInt8>.
//   • FindWindowA returns a bare HWND (no Result). A null HWND.Value means the
//     window was not found; the reference's `?` would propagate that as an error,
//     so we treat it as a non-zero exit and report which window was missing.
//   • CLSCTX_ALL (23) and COINIT_MULTITHREADED (0) are documented scalars the
//     facade does not re-export, so we pass the values directly — semantically
//     identical to the reference's named constants. The CUIAutomation CLSID and
//     IUIAutomation IID likewise come from the metadata's GuidAttribute.
//   • IUIAutomation / IUIAutomationElement are projected as consuming-only
//     Resource wrappers; their methods are NOT instance methods but CFunc fields
//     of a separate @C vtbl struct. We read the vtbl pointer out of the raw COM
//     pointer and invoke ElementFromHandle / CurrentName through it directly —
//     the exact ABI the reference's projected methods perform under the hood
//     (the com_uri / spellchecker pattern).
//   • CurrentName hands back a BSTR the caller owns. windows_strings.BSTR wraps it
//     with fromRawTake so SysFreeString runs on close, matching the reference's
//     owned-BSTR drop. We print it quoted to mirror the reference's `{name:?}`.
//   • The reference's `element.cast::<AutomationElement>()` is a QueryInterface for
//     the WinRT IAutomationElement interface. queryInterfaceAs runs exactly that
//     QI using AutomationElement's projected descriptor and, on success, hands
//     back an owned AutomationElement wrapper (Released on close). Its
//     ExecutableFileName property runs the WinRT ABI call and returns an HString,
//     which we print quoted to mirror the reference's `{:?}`. On older Windows the
//     QI fails (None); we then skip the WinRT step, exactly as the reference's
//     `if let Ok(element)` does.
//   • COM pointer lifetimes are owned by the generated Resource wrappers
//     (takeOwnership: true) and the BSTR/AutomationElement wrappers; their
//     close()/finalizer call Release / SysFreeString. GC owns the wrappers, so no
//     manual AddRef/Release is needed.
// ============================================================================

// CLSID_CUIAutomation {FF48DBA4-60EF-4201-AA87-54103EEF594E}.
let CLSID_CUIAUTOMATION = GUID.parse("FF48DBA4-60EF-4201-AA87-54103EEF594E")
// IID_IUIAutomation {30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}.
let IID_IUIAUTOMATION = GUID.parse("30CBE57D-D9D0-452A-AB13-7AC5AC4825EE")

// CLSCTX_ALL — every activation context (INPROC_SERVER|INPROC_HANDLER|LOCAL_SERVER|REMOTE_SERVER).
const CLSCTX_ALL: UInt32 = 23
// COINIT_MULTITHREADED — the all-zero apartment model the reference initializes.
const COINIT_MULTITHREADED: UInt32 = 0

// IUIAutomation::ElementFromHandle(this, hwnd, out element) through the COM vtbl.
// Returns the raw IUIAutomationElement pointer (caller owns one reference).
func elementFromHandle(automationRaw: CPointer<Unit>, window: HWND): CPointer<Unit> {
    var elementRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IUIAutomationVtbl>>(automationRaw).read().read()
        let hr = vtbl.ElementFromHandle(
            automationRaw, window, CPointer<Unit>(CPointer<CPointer<Unit>>(inout elementRaw)))
        HRESULT(hr).check()
    }
    elementRaw
}

// IUIAutomationElement::get_CurrentName(this, out BSTR) through the COM vtbl. The
// returned BSTR is caller-owned; we wrap it so SysFreeString runs on close.
func currentName(elementRaw: CPointer<Unit>): BSTR {
    var nameRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IUIAutomationElementVtbl>>(elementRaw).read().read()
        let hr = vtbl.CurrentName(
            elementRaw, CPointer<CPointer<Unit>>(inout nameRaw))
        HRESULT(hr).check()
    }
    BSTR.fromRawTake(CPointer<UInt16>(nameRaw))
}

main(): Int64 {
    // Initialize the COM runtime for this thread (CoInitializeEx(None, MTA)?).
    ComApis.CoInitializeExChecked(CPointer<Unit>(), COINIT_MULTITHREADED)

    // FindWindowA(None, s!("Calculator")). The class-name argument is null; the
    // window-name buffer is pinned for the call by withPtr.
    let window = narrowStringFactory("Calculator").withPtr { name =>
        WinApis.FindWindowA(CPointer<UInt8>(), name.asPtr())
    }
    if (window.Value.isNull()) {
        eprintln("Calculator window not found (start calc.exe first)")
        return 1
    }

    // Create the CUIAutomation COM server, typed as IUIAutomation.
    var clsid = CLSID_CUIAUTOMATION
    var iid = IID_IUIAUTOMATION
    var automationRaw = CPointer<Unit>()
    unsafe {
        let hr = ComApis.CoCreateInstance(
            CPointer<Unit>(CPointer<GUID>(inout clsid)),
            CPointer<Unit>(),
            CLSCTX_ALL,
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout automationRaw))
        )
        HRESULT(hr).check()
    }
    let automation = IUIAutomation(automationRaw, takeOwnership: true)

    try {
        // Ask the automation root for the element backing the window handle.
        let elementRaw = elementFromHandle(automationRaw, window)
        let element = IUIAutomationElement(elementRaw, takeOwnership: true)
        try {
            // Use the COM API: read CurrentName and print it (matching {name:?}).
            let name = currentName(elementRaw)
            try {
                println("window name: \"${name}\"")
            } finally {
                name.close()
            }

            // Query for the WinRT API (fails on earlier versions of Windows). This
            // is the reference's `let element: Result<AutomationElement> = element.cast()`.
            match (unsafe { queryInterfaceAs(elementRaw, AutomationElement.descriptor()) }) {
                case Some(winrtElement) =>
                    try {
                        // Use the WinRT API: read ExecutableFileName (matching {:?}).
                        println("file name: \"${winrtElement.ExecutableFileName}\"")
                    } finally {
                        winrtElement.close()
                    }
                case None =>
                    // The cast failed (older Windows); skip the WinRT step exactly
                    // as the reference's `if let Ok(element)` does.
                    ()
            }
        } finally {
            element.close()
        }
    } finally {
        automation.close()
    }

    return 0
}
