package windows_sample_task_dialog

import windows_sample_task_dialog_bindings.Win32.UI.Controls.{Apis, TASKDIALOGCONFIG, TASKDIALOG_BUTTON}
import windows_sample_task_dialog_bindings.Win32.Foundation.HWND
import windows_strings.encodeUtf16WithNull

// ============================================================================
// task_dialog — behaviour-equivalent port of the reference sample.
//
// Fills a TASKDIALOGCONFIG (a @C struct) describing a modal task dialog with a
// title, a main instruction, content text, and a single custom command-link
// button ("Let's do it", id 123). It installs a top-level @C callback that
// prints "button clicked" on TDN_BUTTON_CLICKED, then calls TaskDialogIndirect.
// On return it prints "custom button" when the chosen button matches the custom
// id — exactly the reference's behaviour.
//
// Paradigm notes (Cangjie vs the reference language):
//   • pfCallback is a top-level `@C func`. Cangjie @C functions ARE CFunc values
//     and are accepted by a C API expecting a function pointer; they cannot
//     capture variables, which matches the reference's `extern "system" fn`
//     callback (also capture-free). Its signature mirrors the generated
//     pfCallback field type: (HWND, UInt32 notification, UIntNative wparam,
//     IntNative lparam, CPointer<Unit> refData) -> Int32 (HRESULT).
//   • There is no compile-time `w!` wide literal. Each wide string is built at
//     run time with encodeUtf16WithNull (a NUL-terminated UTF-16 Array<UInt16>)
//     and pinned with acquireArrayRawData for the duration of the modal call —
//     the run-time analogue of a `w!` literal whose storage lives for the call.
//   • The facade does not re-export the scalar TDF_*/TDN_* constants, so their
//     documented numeric values are inlined:
//        TDN_BUTTON_CLICKED            = 2
//        TDF_ALLOW_DIALOG_CANCELLATION = 8
//        TDF_USE_COMMAND_LINKS         = 16
//     dwFlags therefore is 16 | 8 = 24, matching the reference's flag OR.
//   • pButtons is a type-erased CPointer<Unit>; we hand it the raw pointer to
//     the first element of an Array<TASKDIALOG_BUTTON>, pinned for the call.
//   • The out "selection" parameter is an Int32 addressed via
//     CPointer<Unit>(CPointer<Int32>(inout selection)); the reserved
//     pnRadioButton / pfVerificationFlagChecked args are null pointers (the
//     reference's two `None`s).
//   • TaskDialogIndirectChecked throws on a failed HRESULT, mirroring the
//     reference's `?`. main() returns the exit code as Int64.
// ============================================================================

// Notification id for a button click (TDN_BUTTON_CLICKED). The callback's
// notification arg is a plain UInt32 in this projection, so the test is numeric.
const TDN_BUTTON_CLICKED: UInt32 = 2

// dwFlags = TDF_USE_COMMAND_LINKS (16) | TDF_ALLOW_DIALOG_CANCELLATION (8).
const TDF_FLAGS: Int32 = 16 | 8

// The custom command-link button id, matching the reference's nButtonID.
const CUSTOM_BUTTON_ID: Int32 = 123

// The TASKDIALOG callback. Signature must match the generated pfCallback field:
// CFunc<(HWND, UInt32, UIntNative, IntNative, CPointer<Unit>) -> Int32>.
// Prints "button clicked" on a button-clicked notification and returns S_OK.
@C
func taskDialogCallback(
    _: HWND,
    notification: UInt32,
    _: UIntNative,
    _: IntNative,
    _: CPointer<Unit>
): Int32 {
    if (notification == TDN_BUTTON_CLICKED) {
        println("button clicked")
    }
    // HRESULT(0) == S_OK.
    return 0i32
}

main(): Int64 {
    // Build NUL-terminated UTF-16 buffers for every wide string (run-time `w!`).
    let title = encodeUtf16WithNull("Window title")
    let instruction = encodeUtf16WithNull("Main instruction")
    let content = encodeUtf16WithNull("Content")
    let buttonText = encodeUtf16WithNull("Let's do it")

    // The custom command-link button array (a single entry, mirroring the
    // reference). pszButtonText is filled in once the text buffer is pinned.
    var buttons = Array<TASKDIALOG_BUTTON>(1, repeat: TASKDIALOG_BUTTON())

    var selection: Int32 = 0

    unsafe {
        // Pin every buffer for the whole modal call. acquireArrayRawData yields
        // a pointer to the first element; the handles are released in `finally`.
        let titleH = acquireArrayRawData(title)
        let instructionH = acquireArrayRawData(instruction)
        let contentH = acquireArrayRawData(content)
        let buttonTextH = acquireArrayRawData(buttonText)

        // Fill the button entry now that its text buffer is pinned. The array
        // subscript getter returns a value copy (TASKDIALOG_BUTTON is a value
        // struct), so we mutate a local and assign it back through the setter.
        var button = TASKDIALOG_BUTTON()
        button.nButtonID = CUSTOM_BUTTON_ID
        button.pszButtonText = buttonTextH.pointer
        buttons[0] = button

        let buttonsH = acquireArrayRawData(buttons)
        try {
            var config = TASKDIALOGCONFIG()
            config.cbSize = UInt32(sizeOf<TASKDIALOGCONFIG>())
            config.pszWindowTitle = titleH.pointer
            config.pszMainInstruction = instructionH.pointer
            config.pszContent = contentH.pointer
            config.pButtons = CPointer<Unit>(buttonsH.pointer)
            config.cButtons = UInt32(buttons.size)
            config.pfCallback = taskDialogCallback
            config.dwFlags = TDF_FLAGS

            // TaskDialogIndirect(pTaskConfig, pnButton, pnRadioButton,
            //                    pfVerificationFlagChecked). pnButton receives
            //  the chosen button id; the last two are reserved (null), matching
            // the reference's two `None`s. The Checked twin throws on failure.
            let configPtr = CPointer<Unit>(CPointer<TASKDIALOGCONFIG>(inout config))
            let selectionPtr = CPointer<Unit>(CPointer<Int32>(inout selection))
            Apis.TaskDialogIndirectChecked(
                configPtr,
                selectionPtr,
                CPointer<Unit>(),
                CPointer<Int32>()
            )
        } finally {
            releaseArrayRawData(buttonsH)
            releaseArrayRawData(buttonTextH)
            releaseArrayRawData(contentH)
            releaseArrayRawData(instructionH)
            releaseArrayRawData(titleH)
        }
    }

    if (selection == CUSTOM_BUTTON_ID) {
        println("custom button")
    }

    return 0
}
