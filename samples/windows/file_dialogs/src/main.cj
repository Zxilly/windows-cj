package windows_sample_file_dialogs

import windows_sample_file_dialogs_bindings.Win32.System.Com.{Apis as ComApis}
import windows_sample_file_dialogs_bindings.Win32.UI.Shell.{
    IFileSaveDialog,
    IFileSaveDialogVtbl,
    IShellItem,
    IShellItemVtbl
}
import windows_sample_file_dialogs_bindings.Win32.UI.Shell.Common.{COMDLG_FILTERSPEC}
import windows_sample_file_dialogs_bindings.Win32.Foundation.{HWND}
import windows_strings.{encodeUtf16WithNull, decodeWideFromPointer}
import windows_core.HRESULT
import windows_interface.GUID

// ============================================================================
// file_dialogs — behaviour-equivalent port of the reference sample.
//
// Boots the COM apartment with CoIncrementMTAUsage, creates an IFileSaveDialog
// via CoCreateInstance(FileSaveDialog), registers two file-type filters
// (a COMDLG_FILTERSPEC array of PCWSTR pairs), shows the modal save dialog, and
// — if the user confirms — fetches the chosen IShellItem, reads its file-system
// path with GetDisplayName(SIGDN_FILESYSPATH), prints it, and frees the PWSTR
// with CoTaskMemFree. If the user cancels, it prints "user canceled".
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no compile-time w! wide literal. encodeUtf16WithNull builds each
//     NUL-terminated UTF-16 buffer at run time; this is the behavioural twin of
//     a w! literal. The COMDLG_FILTERSPEC fields are PCWSTR pointers into those
//     buffers, which we keep pinned across the SetFileTypes call.
//   • IFileSaveDialog / IShellItem are projected as consuming-only Resource
//     wrappers; their methods are NOT instance methods but fields of separate
//     @C vtbl structs. We read the vtbl pointer out of the raw COM pointer and
//     invoke the CFunc fields directly inside unsafe{} — the exact ABI the
//     reference's projected methods perform (the com_uri / spellchecker
//     pattern). The vtbl chain is layered: IFileSaveDialogVtbl.base_ is the
//     IFileDialog vtbl (SetFileTypes, GetResult) and IFileDialog's base_ is the
//     IModalWindow vtbl (Show), so we descend through `base_` to reach them.
//   • CLSID_FileSaveDialog and IID_IFileSaveDialog are not re-exported as facade
//     scalars; we materialise them with GUID.parse from their documented values
//     — semantically identical to the reference's named constants.
//   • SIGDN_FILESYSPATH is the documented scalar -2147123200 (0x80058000); the
//     facade re-exports the SIGDN type but not the constant, so we pass the
//     value directly.
//   • CLSCTX_ALL == 23 (INPROC_SERVER|INPROC_HANDLER|LOCAL_SERVER|REMOTE_SERVER).
//   • COM pointer lifetimes are owned by the generated Resource wrappers
//     (takeOwnership: true); their close()/finalizer calls Release. GC manages
//     references between the Cangjie wrappers, so no manual AddRef/Release.
//   • Show returns S_OK on confirm and a failure HRESULT (e.g. the cancelled
//     HRESULT_FROM_WIN32(ERROR_CANCELLED)) when the user dismisses the dialog;
//     we branch on success, matching the reference's `Show(None).is_ok()`.
// ============================================================================

// CLSID_FileSaveDialog {C0B4E2F3-BA21-4773-8DBA-335EC946EB8B}.
let CLSID_FILE_SAVE_DIALOG = GUID.parse("C0B4E2F3-BA21-4773-8DBA-335EC946EB8B")
// IID_IFileSaveDialog {84BCCD23-5FDE-4CDB-AEA4-AF64B83D78AB}.
let IID_IFILE_SAVE_DIALOG = GUID.parse("84BCCD23-5FDE-4CDB-AEA4-AF64B83D78AB")

// CLSCTX_ALL — every activation context.
const CLSCTX_ALL: UInt32 = 23
// SIGDN_FILESYSPATH — the file's full file-system path (0x80058000 as Int32).
const SIGDN_FILESYSPATH: Int32 = -2147123200

// IModalWindow::Show(self, hwndOwner). hwndOwner == None -> a null HWND, which
// the @C HWND struct represents as a null inner pointer (default value). Returns
// the raw HRESULT so the caller can distinguish confirm from cancel.
func dialogShow(raw: CPointer<Unit>): Int32 {
    unsafe {
        let vtbl = CPointer<CPointer<IFileSaveDialogVtbl>>(raw).read().read()
        // IFileSaveDialogVtbl.base_ == IFileDialogVtbl, .base_.base_ == IModalWindowVtbl.
        // hwndOwner == None -> a null HWND (default-constructed @C struct).
        vtbl.base_.base_.Show(raw, HWND())
    }
}

// IFileDialog::GetResult(self, out ppsi: IShellItem). On success ownership of
// the IShellItem transfers to us.
func dialogGetResult(raw: CPointer<Unit>): CPointer<Unit> {
    var itemRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IFileSaveDialogVtbl>>(raw).read().read()
        // IFileSaveDialogVtbl.base_ == IFileDialogVtbl (carries GetResult).
        let hr = vtbl.base_.GetResult(raw, CPointer<Unit>(CPointer<CPointer<Unit>>(inout itemRaw)))
        HRESULT(hr).check()
    }
    itemRaw
}

// IShellItem::GetDisplayName(self, sigdnName, out ppszName: PWSTR). The PWSTR is
// allocated by the shell and owned by the caller (freed with CoTaskMemFree).
func itemGetDisplayName(raw: CPointer<Unit>, sigdn: Int32): CPointer<UInt16> {
    var pathPtr = CPointer<UInt16>()
    unsafe {
        let vtbl = CPointer<CPointer<IShellItemVtbl>>(raw).read().read()
        let hr = vtbl.GetDisplayName(raw, sigdn, CPointer<CPointer<UInt16>>(inout pathPtr))
        HRESULT(hr).check()
    }
    pathPtr
}

main(): Int64 {
    // Ensure an MTA exists for the lifetime of the process, like the reference's
    // CoIncrementMTAUsage()?. The cookie is discarded (held by the process).
    ComApis.CoIncrementMTAUsageChecked(CPointer<Unit>())

    // CoCreateInstance(&FileSaveDialog, None, CLSCTX_ALL) -> IFileSaveDialog.
    var clsid = CLSID_FILE_SAVE_DIALOG
    var iid = IID_IFILE_SAVE_DIALOG
    var dialogRaw = CPointer<Unit>()
    unsafe {
        let hr = ComApis.CoCreateInstance(
            CPointer<Unit>(CPointer<GUID>(inout clsid)),
            CPointer<Unit>(),
            CLSCTX_ALL,
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout dialogRaw))
        )
        HRESULT(hr).check()
    }
    let dialog = IFileSaveDialog(dialogRaw, takeOwnership: true)

    try {
        // Build the two filter labels/patterns as NUL-terminated wide buffers,
        // pin them, point the COMDLG_FILTERSPEC fields at them, then call
        // SetFileTypes(2, rgFilterSpec). Every buffer stays pinned across the
        // call so the PCWSTRs remain valid.
        let txtName = encodeUtf16WithNull("Text files")
        let txtSpec = encodeUtf16WithNull("*.txt")
        let allName = encodeUtf16WithNull("All files")
        let allSpec = encodeUtf16WithNull("*.*")

        unsafe {
            let txtNameH = acquireArrayRawData(txtName)
            let txtSpecH = acquireArrayRawData(txtSpec)
            let allNameH = acquireArrayRawData(allName)
            let allSpecH = acquireArrayRawData(allSpec)
            try {
                // Indexing a value-type struct array yields a copy, so we build
                // each COMDLG_FILTERSPEC whole and assign it into the slot.
                var txtSpecStruct = COMDLG_FILTERSPEC()
                txtSpecStruct.pszName = txtNameH.pointer
                txtSpecStruct.pszSpec = txtSpecH.pointer
                var allSpecStruct = COMDLG_FILTERSPEC()
                allSpecStruct.pszName = allNameH.pointer
                allSpecStruct.pszSpec = allSpecH.pointer

                var specs = Array<COMDLG_FILTERSPEC>(2, repeat: COMDLG_FILTERSPEC())
                specs[0] = txtSpecStruct
                specs[1] = allSpecStruct

                let specsH = acquireArrayRawData(specs)
                try {
                    let vtbl = CPointer<CPointer<IFileSaveDialogVtbl>>(dialogRaw).read().read()
                    // IFileSaveDialogVtbl.base_ == IFileDialogVtbl (carries SetFileTypes).
                    let hr = vtbl.base_.SetFileTypes(dialogRaw, 2u32, CPointer<Unit>(specsH.pointer))
                    HRESULT(hr).check()
                } finally {
                    releaseArrayRawData(specsH)
                }
            } finally {
                releaseArrayRawData(txtNameH)
                releaseArrayRawData(txtSpecH)
                releaseArrayRawData(allNameH)
                releaseArrayRawData(allSpecH)
            }
        }

        // Show the modal dialog. S_OK (>= 0) means the user confirmed a path.
        let showHr = dialogShow(dialogRaw)
        if (showHr >= 0) {
            let itemRaw = dialogGetResult(dialogRaw)
            let item = IShellItem(itemRaw, takeOwnership: true)
            try {
                let pathPtr = itemGetDisplayName(itemRaw, SIGDN_FILESYSPATH)
                let path = if (pathPtr.isNull()) {
                    ""
                } else {
                    unsafe { decodeWideFromPointer(pathPtr) }
                }
                println("user picked: ${path}")
                ComApis.CoTaskMemFree(CPointer<Unit>(pathPtr))
            } finally {
                item.close()
            }
        } else {
            println("user canceled")
        }
    } finally {
        dialog.close()
    }

    return 0
}
