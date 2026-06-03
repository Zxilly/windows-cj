package windows_sample_shell

import windows_sample_shell_bindings.Win32.System.Com.{Apis as ComApis, IServiceProviderVtbl, IDispatchVtbl}
import windows_sample_shell_bindings.Win32.UI.Shell.{
    Apis as ShellApis,
    IShellWindowsVtbl,
    IShellBrowserVtbl,
    IShellViewVtbl,
    IShellFolderViewDualVtbl,
    IShellDispatch2Vtbl
}
import windows_sample_shell_bindings.Win32.System.Variant.VARIANT as BindingsVariant
import windows_core.HRESULT
import windows_strings.BSTR
import windows_variant.{VARIANT, Variant, variantFromI4, variantFromString, emptyVariant}
import windows_interface.{GUID, IUnknownVtbl}

// ============================================================================
// shell — behaviour-equivalent port of the reference sample.
//
// COM automation against the live desktop Explorer window. The flow mirrors
// the two old-new-thing blog posts the reference cites:
//
//   1. CoCreateInstance(ShellWindows) -> IShellWindows.
//   2. IShellWindows.FindWindowSW(CSIDL_DESKTOP, default, SWC_DESKTOP,
//      &handle, SWFO_NEEDDISPATCH) -> the desktop IDispatch.
//   3. desktop.cast::<IServiceProvider>()
//      -> QueryService(SID_STopLevelBrowser) -> IShellBrowser
//      -> QueryActiveShellView() -> IShellView.
//   4. view.GetItemObject(SVGIO_BACKGROUND) -> background IDispatch
//      -> cast IShellFolderViewDual
//      -> Application() -> cast IShellDispatch2.
//   5. shell.ShellExecute(BSTR url, VARIANT args/dir/op, VARIANT show)
//      fires the default browser at the URL, then the process exits.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The generated COM projection wraps each interface only as a raw-pointer
//     Resource; its methods live on a separate @C vtbl struct. We therefore
//     read the vtbl pointer out of the raw COM pointer and invoke the CFunc
//     fields directly — the exact ABI the reference's projected methods run
//     under the hood. `cast()` is just QueryInterface, which lives at the head
//     of every COM vtbl (IUnknown), so we reinterpret any raw pointer's vtbl
//     as IUnknownVtbl to perform it.
//   • There is no compile-time GUID literal. CLSIDs / IIDs are built at run
//     time with GUID.from_values; the byte triplets are the canonical GUID
//     hex split into data1/data2/data3 + the 8 trailing bytes. The shell SID
//     (SID_STopLevelBrowser) is a generated symbol, so we call it directly.
//   • Scalar Win32 enum constants are not surfaced on the facade; their
//     documented integer values are inlined:
//       CLSCTX_ALL = 23, CSIDL_DESKTOP = 0, SWC_DESKTOP = 8,
//       SWFO_NEEDDISPATCH = 1, SVGIO_BACKGROUND = 0, SW_SHOWNORMAL = 1.
//   • windows_variant builds VARIANTs over windows_common's VARIANT struct;
//     the bindings declare their own identically-laid-out (24-byte @C) VARIANT.
//     We reinterpret one as the other through a pointer copy when feeding the
//     vtbl CFunc fields — pure ABI passthrough, no value change.
//   • Each raw COM pointer is owned by a CPointer; we Release every interface
//     in reverse acquisition order via the IUnknown vtbl, matching the
//     reference's owned-handle drops.
// ============================================================================

// --- documented scalar constants (facade does not re-export these) ---
const CLSCTX_ALL: UInt32 = 23
const CSIDL_DESKTOP: Int32 = 0
const SWC_DESKTOP: Int32 = 8
const SWFO_NEEDDISPATCH: Int32 = 1
const SVGIO_BACKGROUND: UInt32 = 0
const SW_SHOWNORMAL: Int32 = 1

// --- well-known GUIDs (canonical hex split into the from_values fields) ---
func clsidShellWindows(): GUID {
    // 9BA05972-F6A8-11CF-A442-00A0C90A8F39
    GUID.from_values(2610977138u32, 63144u16, 4559u16, 164u8, 66u8, 0u8, 160u8, 201u8, 10u8, 143u8, 57u8)
}

func iidIShellWindows(): GUID {
    // 85CB6900-4D95-11CF-960C-0080C7F4EE85
    GUID.from_values(2244700416u32, 19861u16, 4559u16, 150u8, 12u8, 0u8, 128u8, 199u8, 244u8, 238u8, 133u8)
}

func iidIServiceProvider(): GUID {
    // 6D5140C1-7436-11CE-8034-00AA006009FA
    GUID.from_values(1834041537u32, 29750u16, 4558u16, 128u8, 52u8, 0u8, 170u8, 0u8, 96u8, 9u8, 250u8)
}

func iidIShellBrowser(): GUID {
    // 000214E2-0000-0000-C000-000000000046
    GUID.from_values(136418u32, 0u16, 0u16, 192u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 70u8)
}

func iidIShellView(): GUID {
    // 000214E3-0000-0000-C000-000000000046
    GUID.from_values(136419u32, 0u16, 0u16, 192u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 70u8)
}

func iidIDispatch(): GUID {
    // 00020400-0000-0000-C000-000000000046
    GUID.from_values(132096u32, 0u16, 0u16, 192u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 70u8)
}

func iidIShellFolderViewDual(): GUID {
    // E7A1AF80-4D96-11CF-960C-0080C7F4EE85
    GUID.from_values(3886133120u32, 19862u16, 4559u16, 150u8, 12u8, 0u8, 128u8, 199u8, 244u8, 238u8, 133u8)
}

func iidIShellDispatch2(): GUID {
    // A4C6892C-3BA9-11D2-9DEA-00C04FB16162
    GUID.from_values(2764474668u32, 15273u16, 4562u16, 157u8, 234u8, 0u8, 192u8, 79u8, 177u8, 97u8, 98u8)
}

// Reinterpret a windows_variant VARIANT (windows_common layout) as the
// bindings' own identically-laid-out VARIANT for the vtbl CFunc call. Pure
// 24-byte ABI passthrough.
func toBindingsVariant(value: VARIANT): BindingsVariant {
    var src = value
    unsafe {
        let p = CPointer<BindingsVariant>(CPointer<VARIANT>(inout src))
        p.read()
    }
}

// QueryInterface ("cast") on any live COM pointer. The IUnknown vtbl sits at
// the head of every COM vtbl, so we reinterpret the object's vtbl as
// IUnknownVtbl and invoke QueryInterface(iid, &out). Returns a fresh,
// AddRef'd raw pointer (caller owns it).
func queryInterface(raw: CPointer<Unit>, iid: GUID): CPointer<Unit> {
    var iidVar = iid
    var out = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.QueryInterface(
            raw,
            CPointer<GUID>(inout iidVar),
            CPointer<CPointer<Unit>>(inout out)
        )
        HRESULT(hr).check()
    }
    out
}

// Release a COM pointer via its IUnknown vtbl (no-op on null).
func releaseCom(raw: CPointer<Unit>): Unit {
    if (raw.isNull()) {
        return
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        let _ = vtbl.Release(raw)
    }
}

// IShellWindows::FindWindowSW. pvarLoc / pvarLocRoot are *const VARIANT
// (passed by pointer); swClass / swfwOptions are i32; pHwnd is *mut i32;
// ppdispOut receives the desktop IDispatch.
func findWindowSW(shellWindows: CPointer<Unit>): CPointer<Unit> {
    var loc = toBindingsVariant(variantFromI4(CSIDL_DESKTOP))
    var locRoot = toBindingsVariant(emptyVariant())
    var handle: Int32 = 0
    var out = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IShellWindowsVtbl>>(shellWindows).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.FindWindowSW(
            shellWindows,
            CPointer<Unit>(CPointer<BindingsVariant>(inout loc)),
            CPointer<Unit>(CPointer<BindingsVariant>(inout locRoot)),
            SWC_DESKTOP,
            CPointer<Unit>(CPointer<Int32>(inout handle)),
            SWFO_NEEDDISPATCH,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout out))
        )
        HRESULT(hr).check()
    }
    out
}

// IServiceProvider::QueryService(guidService, riid, &out).
func queryService(provider: CPointer<Unit>, service: GUID, iid: GUID): CPointer<Unit> {
    var svc = service
    var riid = iid
    var out = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IServiceProviderVtbl>>(provider).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.QueryService(
            provider,
            CPointer<Unit>(CPointer<GUID>(inout svc)),
            CPointer<Unit>(CPointer<GUID>(inout riid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout out))
        )
        HRESULT(hr).check()
    }
    out
}

// IShellBrowser::QueryActiveShellView(&out).
func queryActiveShellView(browser: CPointer<Unit>): CPointer<Unit> {
    var out = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IShellBrowserVtbl>>(browser).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.QueryActiveShellView(
            browser,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout out))
        )
        HRESULT(hr).check()
    }
    out
}

// IShellView::GetItemObject(uItem, riid, &out).
func getItemObject(view: CPointer<Unit>, item: UInt32, iid: GUID): CPointer<Unit> {
    var riid = iid
    var out = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IShellViewVtbl>>(view).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.GetItemObject(
            view,
            item,
            CPointer<Unit>(CPointer<GUID>(inout riid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout out))
        )
        HRESULT(hr).check()
    }
    out
}

// IShellFolderViewDual::get_Application(&out) -> the Shell IDispatch.
func folderApplication(folder: CPointer<Unit>): CPointer<Unit> {
    var out = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IShellFolderViewDualVtbl>>(folder).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.Application(
            folder,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout out))
        )
        HRESULT(hr).check()
    }
    out
}

// IShellDispatch2::ShellExecute(BSTR File, VARIANT args, VARIANT dir,
// VARIANT operation, VARIANT show). The BSTR is passed by value (its pointer),
// the four VARIANTs by value.
func shellExecute(
    shell: CPointer<Unit>,
    file: CPointer<Unit>,
    args: BindingsVariant,
    dir: BindingsVariant,
    operation: BindingsVariant,
    show: BindingsVariant
): Unit {
    unsafe {
        let vtblPtr = CPointer<CPointer<IShellDispatch2Vtbl>>(shell).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.ShellExecute(shell, file, args, dir, operation, show)
        HRESULT(hr).check()
    }
}

// Resolve the desktop IShellView through the service-provider chain, returning
// a fresh IShellView raw pointer the caller owns.
func findDesktopFolderView(): CPointer<Unit> {
    // CoCreateInstance(ShellWindows, nullptr, CLSCTX_ALL, IID_IShellWindows).
    var clsid = clsidShellWindows()
    var iidWindows = iidIShellWindows()
    var shellWindows = CPointer<Unit>()
    unsafe {
        let hr = ComApis.CoCreateInstance(
            CPointer<Unit>(CPointer<GUID>(inout clsid)),
            CPointer<Unit>(),
            CLSCTX_ALL,
            CPointer<Unit>(CPointer<GUID>(inout iidWindows)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout shellWindows))
        )
        HRESULT(hr).check()
    }

    var desktop = CPointer<Unit>()
    var provider = CPointer<Unit>()
    var browser = CPointer<Unit>()
    var view = CPointer<Unit>()
    try {
        desktop = findWindowSW(shellWindows)
        provider = queryInterface(desktop, iidIServiceProvider())
        browser = queryService(provider, ShellApis.SID_STopLevelBrowser(), iidIShellBrowser())
        let activeView = queryActiveShellView(browser)
        // view = activeView.cast::<IShellView>(); QueryActiveShellView already
        // returns IShellView, so the cast is an identity QI that hands back a
        // freshly AddRef'd pointer. Release the original afterwards.
        try {
            view = queryInterface(activeView, iidIShellView())
        } finally {
            releaseCom(activeView)
        }
    } finally {
        releaseCom(browser)
        releaseCom(provider)
        releaseCom(desktop)
        releaseCom(shellWindows)
    }
    view
}

func shellExecuteFromExplorer(file: String, args: String, directory: String, operation: String, show: Int32): Unit {
    let view = findDesktopFolderView()
    var background = CPointer<Unit>()
    var folder = CPointer<Unit>()
    var application = CPointer<Unit>()
    var shell = CPointer<Unit>()

    // VARIANT arguments for ShellExecute. The three VT_BSTR VARIANTs own
    // SysAllocString'd storage; wrapping them in owning Variant resources frees
    // that storage via VariantClear on close (matching the reference's owned
    // VARIANT drops). The VT_I4 show VARIANT carries no heap payload. The file
    // is a separately-owned BSTR. ShellExecute treats every argument as [in],
    // so the caller retains ownership of all of them.
    let argsV = Variant(variantFromString(args))
    let dirV = Variant(variantFromString(directory))
    let opV = Variant(variantFromString(operation))
    let showV = variantFromI4(show)
    let fileBstr = BSTR(file)

    try {
        background = getItemObject(view, SVGIO_BACKGROUND, iidIDispatch())
        folder = queryInterface(background, iidIShellFolderViewDual())
        application = folderApplication(folder)
        shell = queryInterface(application, iidIShellDispatch2())

        shellExecute(
            shell,
            unsafe { CPointer<Unit>(fileBstr.asPtr()) },
            toBindingsVariant(argsV.get()),
            toBindingsVariant(dirV.get()),
            toBindingsVariant(opV.get()),
            toBindingsVariant(showV)
        )
    } finally {
        releaseCom(shell)
        releaseCom(application)
        releaseCom(folder)
        releaseCom(background)
        releaseCom(view)
        argsV.close()
        dirV.close()
        opV.close()
        fileBstr.close()
    }
}

main(): Int64 {
    // CoInitialize before any COM use (CoInitializeChecked throws on failure,
    // mirroring the reference's `.ok()?`).
    ComApis.CoInitializeChecked(CPointer<Unit>())

    shellExecuteFromExplorer(
        "https://github.com/microsoft/windows-rs",
        "",
        "",
        "",
        SW_SHOWNORMAL
    )
    return 0
}
