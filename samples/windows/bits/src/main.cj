package windows_sample_bits

import windows_sample_bits_bindings.Win32.System.Com.{Apis as ComApis}
import windows_sample_bits_bindings.Win32.Networking.BackgroundIntelligentTransferService.{
    Apis as BitsApis,
    IBackgroundCopyManagerVtbl,
    IBackgroundCopyJobVtbl,
    IBackgroundCopyErrorVtbl,
    IBackgroundCopyCallbackVtbl
}
import windows_core as windows_core
import windows_core.HRESULT
import windows_interface as windows_interface
import windows_interface.GUID
import windows_strings.{encodeUtf16WithNull, decodeWideFromPointer}
import std.env.{exit, getStdIn}

// ============================================================================
// bits — behaviour-equivalent port of the reference sample.
//
// Downloads a file with the Background Intelligent Transfer Service (BITS):
// boot COM (CoInitializeEx, MTA), CoCreateInstance(BackgroundCopyManager) for an
// IBackgroundCopyManager, CreateJob a download job, AddFile a (remote, local)
// pair, register a callback object that implements IBackgroundCopyCallback,
// SetNotifyFlags(JOB_TRANSFERRED | JOB_ERROR), Resume the job, print
// "downloading...", then block on stdin. When the job finishes the runtime
// calls our JobTransferred (which Completes the job, prints "done", and exits)
// or JobError (which Cancels the job, prints the description, and exits). On
// stdin input we Cancel the job and print "canceled".
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference uses #[implement(IBackgroundCopyCallback)] to expose a Rust
//     struct as a COM object. Cangjie has no such macro, but the COM ABI is the
//     same: a COM object is a pointer to a vtable whose QueryInterface / AddRef /
//     Release and method slots route back into managed code. We build that CCW
//     by hand with windows_core.ComObject — the same machinery the generated
//     WinRT delegate wrappers use. CallbackBox holds the implementation; the
//     generated @C IBackgroundCopyCallbackVtbl is filled with buildIUnknownVtbl()
//     for the IUnknown base plus three thunk closures. Each thunk recovers the
//     box from the instance pointer with asImplFromRaw<CallbackInvoker> and calls
//     the corresponding Cangjie method, translating its outcome into an HRESULT.
//   • SetNotifyInterface AddRefs the callback and holds it for the job's
//     lifetime; the ComObject and its box are kept alive in main's scope (and by
//     the runtime's COM registry) so the native reference stays valid.
//   • The callback receives the IBackgroundCopyJob / IBackgroundCopyError as
//     borrowed raw pointers (owned by the runtime for the callback's duration);
//     we invoke their methods through the vtbl without taking ownership, exactly
//     as the reference's Ref<T> borrow does.
//   • There is no compile-time w! wide literal; encodeUtf16WithNull builds a
//     NUL-terminated UTF-16 buffer at run time (the behavioural twin of w!).
//   • CLSID_BackgroundCopyManager and the interface IIDs are not re-exported as
//     facade scalars; we materialise them with GUID.parse from their documented
//     metadata values — semantically identical to the reference's named GUIDs.
//   • getchar() blocking on stdin is mirrored with std.env stdin readln().
//   • exit(0) inside a callback matches the reference's std::process::exit(0).
// ============================================================================

// CLSID_BackgroundCopyManager {4991D34B-80A1-4291-83B6-3328366B9097}.
let CLSID_BACKGROUND_COPY_MANAGER = GUID.parse("4991D34B-80A1-4291-83B6-3328366B9097")
// IID_IBackgroundCopyManager {5CE34C0D-0DC9-4C1F-897C-DAA1B78CEE7C}.
let IID_IBACKGROUND_COPY_MANAGER = GUID.parse("5CE34C0D-0DC9-4C1F-897C-DAA1B78CEE7C")
// IID_IBackgroundCopyCallback {97EA99C7-0186-4AD4-8DF9-C5B4E0ED6B22}.
let IID_IBACKGROUND_COPY_CALLBACK = GUID.parse("97EA99C7-0186-4AD4-8DF9-C5B4E0ED6B22")

// CLSCTX_LOCAL_SERVER — out-of-process server activation context (value 4).
const CLSCTX_LOCAL_SERVER: UInt32 = 4
// COINIT_MULTITHREADED — MTA apartment for CoInitializeEx (value 0).
const COINIT_MULTITHREADED: UInt32 = 0
// BG_JOB_TYPE_BG_JOB_TYPE_DOWNLOAD — download job kind (value 0).
const BG_JOB_TYPE_DOWNLOAD: Int32 = 0

// ----------------------------------------------------------------------------
// IBackgroundCopyJob method helpers, invoked through the vtbl on a raw pointer.
// ----------------------------------------------------------------------------

// IBackgroundCopyJob::Complete — finalise a successfully transferred job.
func jobComplete(jobRaw: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IBackgroundCopyJobVtbl>>(jobRaw).read().read()
        HRESULT(vtbl.Complete(jobRaw)).check()
    }
}

// IBackgroundCopyJob::Cancel — abort the job and remove it from the queue.
func jobCancel(jobRaw: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IBackgroundCopyJobVtbl>>(jobRaw).read().read()
        HRESULT(vtbl.Cancel(jobRaw)).check()
    }
}

// IBackgroundCopyJob::Resume — start (or restart) the transfer.
func jobResume(jobRaw: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IBackgroundCopyJobVtbl>>(jobRaw).read().read()
        HRESULT(vtbl.Resume(jobRaw)).check()
    }
}

// IBackgroundCopyJob::AddFile — queue one (remote URL, local path) pair. The
// wide-string buffers must stay pinned across the call.
func jobAddFile(jobRaw: CPointer<Unit>, remote: Array<UInt16>, local: Array<UInt16>): Unit {
    unsafe {
        let remoteHandle = acquireArrayRawData(remote)
        let localHandle = acquireArrayRawData(local)
        try {
            let vtbl = CPointer<CPointer<IBackgroundCopyJobVtbl>>(jobRaw).read().read()
            HRESULT(vtbl.AddFile(jobRaw, remoteHandle.pointer, localHandle.pointer)).check()
        } finally {
            releaseArrayRawData(remoteHandle)
            releaseArrayRawData(localHandle)
        }
    }
}

// IBackgroundCopyJob::SetNotifyInterface — register the callback object.
func jobSetNotifyInterface(jobRaw: CPointer<Unit>, callbackRaw: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IBackgroundCopyJobVtbl>>(jobRaw).read().read()
        HRESULT(vtbl.SetNotifyInterface(jobRaw, callbackRaw)).check()
    }
}

// IBackgroundCopyJob::SetNotifyFlags — choose which events fire the callback.
func jobSetNotifyFlags(jobRaw: CPointer<Unit>, flags: UInt32): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IBackgroundCopyJobVtbl>>(jobRaw).read().read()
        HRESULT(vtbl.SetNotifyFlags(jobRaw, flags)).check()
    }
}

// IBackgroundCopyError::GetErrorDescription — fetch the localised message. The
// returned wide string is COM-allocated; we copy it and free it with CoTaskMemFree.
func errorDescription(errorRaw: CPointer<Unit>, languageId: UInt32): String {
    var descRaw = CPointer<UInt16>()
    unsafe {
        let vtbl = CPointer<CPointer<IBackgroundCopyErrorVtbl>>(errorRaw).read().read()
        HRESULT(vtbl.GetErrorDescription(errorRaw, languageId, CPointer<CPointer<UInt16>>(inout descRaw))).check()
        let text = if (descRaw.isNull()) {
            ""
        } else {
            decodeWideFromPointer(descRaw)
        }
        if (descRaw.isNotNull()) {
            ComApis.CoTaskMemFree(CPointer<Unit>(descRaw))
        }
        return text
    }
}

// ----------------------------------------------------------------------------
// CCW for IBackgroundCopyCallback.
//
// CallbackInvoker is the erased surface the vtbl thunks dispatch through;
// CallbackBox implements it and owns the native vtbl storage. asImplFromRaw
// recovers the box from the COM instance pointer at call time.
// ----------------------------------------------------------------------------

interface CallbackInvoker {
    func onJobTransferred(jobRaw: CPointer<Unit>): Int32
    func onJobError(jobRaw: CPointer<Unit>, errorRaw: CPointer<Unit>): Int32
    func onJobModification(jobRaw: CPointer<Unit>, reserved: UInt32): Int32
}

class CallbackBox <: CallbackInvoker & Resource {
    private let vtblHandle: CPointer<IBackgroundCopyCallbackVtbl>
    private var closed: Bool = false

    public init() {
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IBackgroundCopyCallbackVtbl>(buildCallbackVtbl())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    // JobTransferred: the file finished. Complete the job, announce, and exit.
    public func onJobTransferred(jobRaw: CPointer<Unit>): Int32 {
        jobComplete(jobRaw)
        println("done")
        exit(0)
    }

    // JobError: the transfer failed. Cancel the job, print the description, exit.
    public func onJobError(jobRaw: CPointer<Unit>, errorRaw: CPointer<Unit>): Int32 {
        jobCancel(jobRaw)
        println(errorDescription(errorRaw, 0u32))
        exit(0)
    }

    // JobModification: progress updates; we do not subscribe to these but
    // implement the slot for completeness (returns S_OK).
    public func onJobModification(_: CPointer<Unit>, _: UInt32): Int32 {
        windows_core.S_OK.value
    }
}

// Build the IBackgroundCopyCallback vtbl: IUnknown base from buildIUnknownVtbl()
// plus the three callback thunks. Each thunk recovers the CallbackBox from the
// instance pointer and forwards to it, mapping a thrown WindowsException to its
// HRESULT and any other failure to E_FAIL.
func buildCallbackVtbl(): IBackgroundCopyCallbackVtbl {
    var vtbl = IBackgroundCopyCallbackVtbl()
    vtbl.base_ = windows_core.buildIUnknownVtbl()
    vtbl.JobTransferred = { instanceRaw: CPointer<Unit>, jobRaw: CPointer<Unit> =>
        dispatch(instanceRaw, { box => box.onJobTransferred(jobRaw) })
    }
    vtbl.JobError = { instanceRaw: CPointer<Unit>, jobRaw: CPointer<Unit>, errorRaw: CPointer<Unit> =>
        dispatch(instanceRaw, { box => box.onJobError(jobRaw, errorRaw) })
    }
    vtbl.JobModification = { instanceRaw: CPointer<Unit>, jobRaw: CPointer<Unit>, reserved: UInt32 =>
        dispatch(instanceRaw, { box => box.onJobModification(jobRaw, reserved) })
    }
    return vtbl
}

// Recover the CallbackBox behind a COM instance pointer and run a method,
// translating its outcome into an HRESULT for the native caller.
func dispatch(instanceRaw: CPointer<Unit>, body: (CallbackInvoker) -> Int32): Int32 {
    match (unsafe { windows_core.asImplFromRaw<CallbackInvoker>(instanceRaw) }) {
        case Some(box) =>
            try {
                body(box)
            } catch (error: windows_core.WindowsException) {
                error.code().value
            } catch (_: Exception) {
                windows_core.E_FAIL.value
            }
        case None =>
            windows_core.E_NOTIMPL.value
    }
}

main(): Int64 {
    // CoInitializeEx(None, COINIT_MULTITHREADED).ok()?
    ComApis.CoInitializeExChecked(CPointer<Unit>(), COINIT_MULTITHREADED)

    // CoCreateInstance(&BackgroundCopyManager, None, CLSCTX_LOCAL_SERVER)
    //   -> IBackgroundCopyManager.
    var clsid = CLSID_BACKGROUND_COPY_MANAGER
    var managerIid = IID_IBACKGROUND_COPY_MANAGER
    var managerRaw = CPointer<Unit>()
    unsafe {
        let hr = ComApis.CoCreateInstance(
            CPointer<Unit>(CPointer<GUID>(inout clsid)),
            CPointer<Unit>(),
            CLSCTX_LOCAL_SERVER,
            CPointer<Unit>(CPointer<GUID>(inout managerIid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout managerRaw))
        )
        HRESULT(hr).check()
    }

    // manager.CreateJob(w!("sample"), BG_JOB_TYPE_DOWNLOAD, &mut jobId, &mut job).
    let displayName = encodeUtf16WithNull("sample")
    var jobId = GUID.parse("00000000-0000-0000-0000-000000000000")
    var jobRaw = CPointer<Unit>()
    unsafe {
        let nameHandle = acquireArrayRawData(displayName)
        try {
            let vtbl = CPointer<CPointer<IBackgroundCopyManagerVtbl>>(managerRaw).read().read()
            let hr = vtbl.CreateJob(
                managerRaw,
                nameHandle.pointer,
                BG_JOB_TYPE_DOWNLOAD,
                CPointer<Unit>(CPointer<GUID>(inout jobId)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout jobRaw))
            )
            HRESULT(hr).check()
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }

    // job.AddFile(w!("https://kennykerr.ca/favicon.svg"), w!("D:\\rust.svg")).
    let remote = encodeUtf16WithNull("https://kennykerr.ca/favicon.svg")
    let local = encodeUtf16WithNull("D:\\sample.svg")
    jobAddFile(jobRaw, remote, local)

    // let callback: IBackgroundCopyCallback = Callback.into();
    // job.SetNotifyInterface(&callback)?
    let box = CallbackBox()
    let callbackObject = windows_core.ComObject<CallbackBox>.new(
        box,
        [IID_IBACKGROUND_COPY_CALLBACK],
        box.vtblPtr()
    )
    jobSetNotifyInterface(jobRaw, callbackObject.asRaw())

    // job.SetNotifyFlags(BG_NOTIFY_JOB_TRANSFERRED | BG_NOTIFY_JOB_ERROR).
    jobSetNotifyFlags(jobRaw, BitsApis.BG_NOTIFY_JOB_TRANSFERRED | BitsApis.BG_NOTIFY_JOB_ERROR)

    // job.Resume()?; println!("downloading...");
    jobResume(jobRaw)
    println("downloading...")

    // getchar(); job.Cancel()?; println!("canceled");
    let _ = getStdIn().readln()
    jobCancel(jobRaw)
    println("canceled")

    // Keep the callback CCW alive until we are done blocking, mirroring the
    // reference's `callback` binding living to the end of main.
    callbackObject.close()
    box.close()

    return 0
}
