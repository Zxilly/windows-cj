package windows_sample_consent

import windows_sample_consent_bindings.Security.Credentials.UI.{UserConsentVerifier, IUserConsentVerifierStatics}
import windows_sample_consent_bindings.Win32.System.WinRT.IUserConsentVerifierInteropVtbl
import windows_sample_consent_bindings.Win32.Foundation.HWND
import windows_strings.HString
import windows_core.{HRESULT, GUID, WindowsException, E_NOINTERFACE, queryInterfaceRaw, factory}
import windows_interface.IInspectableVtbl
import std.time.*

// ============================================================================
// consent — behaviour-equivalent port of the reference sample.
//
// Activates the UserConsentVerifier runtime class, queries its activation
// factory for the Win32 interop interface IUserConsentVerifierInterop, then
// calls RequestVerificationForWindowAsync(HWND, message) — handing it the
// PIID of IAsyncOperation<UserConsentVerificationResult> so the system returns
// the async operation already typed as that interface. We then block on the
// returned IAsyncOperation until it reaches a terminal status and read the
// UserConsentVerificationResult out of GetResults, printing the enum variant.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference's `factory::<UserConsentVerifier, IUserConsentVerifierInterop>()`
//     activates the runtime class and casts the factory to the interop
//     interface in one helper. The generated projection exposes the runtime
//     class's typed statics interface (IUserConsentVerifierStatics) but models
//     IUserConsentVerifierInterop as a Win32 synthetic interface that is NOT a
//     projected COM `Interface<I>`, so the generic `factory<C, I>` cannot return
//     it directly. We do the same two steps explicitly: obtain the activation
//     factory as IUserConsentVerifierStatics, then QueryInterface its raw
//     pointer for the interop IID — the exact ABI the reference's cast performs.
//   • There is no compile-time `h!` HSTRING literal. windows_strings.HString
//     builds a real WinRT HSTRING at run time; its raw handle is the same ABI
//     value an `h!` literal yields.
//   • IUserConsentVerifierInterop's methods are not surfaced as instance
//     methods; the generator emits its COM vtbl as an @C struct
//     (IUserConsentVerifierInteropVtbl). We read the vtbl pointer out of the raw
//     pointer and invoke RequestVerificationForWindowAsync through the CFunc
//     field directly — the com_uri / memory_buffer interop pattern.
//   • RequestVerificationForWindowAsync's 4th parameter is the REFIID of the
//     IAsyncOperation<UserConsentVerificationResult> the caller wants back. The
//     generated UserConsentVerificationResult is a bare value enum without the
//     full WinRT generic-type projection, so the generic IAsyncOperation<T>
//     wrapper (and its windows_future `.join()`) cannot be instantiated with it.
//     We instead compute that interface's parameterized v5 IID from its WinRT
//     type signature (the identical hash the typed projection performs under the
//     hood) and drive the returned IAsyncOperation directly through its COM
//     vtbl: QueryInterface IAsyncInfo to wait for a terminal status, then call
//     GetResults to read the 4-byte result enum. This is the same ABI the
//     reference's `operation.join()?` performs.
//   • The result enum value is printed with the same {:?}-style variant name the
//     reference prints.
//   • COM pointer lifetimes are released via the IUnknown::Release vtbl slot in
//     the cleanup paths; the Cangjie wrappers / GC own the rest.
// ============================================================================

// IUserConsentVerifierInterop IID {39E050C3-4E74-441A-8DC0-B81104DF949C}, taken
// from the Win32 metadata's GuidAttribute on the interop interface (the value
// the reference's typed `cast::<IUserConsentVerifierInterop>()` queries under
// the hood). Not re-exported as a binding constant for synthetic interop types.
const IID_IUSERCONSENTVERIFIERINTEROP: String = "39E050C3-4E74-441A-8DC0-B81104DF949C"

// IAsyncInfo IID {00000036-0000-0000-C000-000000000046}. IAsyncOperation<T>
// derives from IInspectable, not IAsyncInfo, so polling the operation's status
// requires QueryInterface for this interface (matching what windows_future does).
const IID_IASYNCINFO: String = "00000036-0000-0000-C000-000000000046"

// The WinRT type signature of UserConsentVerificationResult — a value enum with
// an Int32 underlying type — and of IAsyncOperation<T> (its fixed parameterized
// GUID). Hashing the composed parameterized signature with the v5 algorithm
// yields the exact IID the system assigns IAsyncOperation<UserConsentVerificationResult>.
const SIG_USERCONSENTVERIFICATIONRESULT: String =
    "enum(Windows.Security.Credentials.UI.UserConsentVerificationResult;i4)"
const PINTERFACE_IASYNCOPERATION_GUID: String = "9fc2b0bb-e446-44e2-aa61-9cab8f636af2"

// AsyncStatus terminal values (Windows.Foundation.AsyncStatus). Started==0 means
// "not yet terminal"; anything else ends the wait.
const ASYNC_STATUS_STARTED: Int32 = 0
const ASYNC_STATUS_COMPLETED: Int32 = 1
const ASYNC_STATUS_CANCELED: Int32 = 2
const ASYNC_STATUS_ERROR: Int32 = 3

// ---------------------------------------------------------------------------
// Custom COM vtbls for the IAsyncOperation / IAsyncInfo ABI. The generated
// IAsyncOperation`1 vtbl omits put_Completed / get_Completed (so its GetResults
// slot is mis-positioned) and no IAsyncInfo vtbl struct is emitted; we therefore
// declare the real WinRT method layout ourselves. Each derives from IInspectable
// (6 base slots), then its own methods in metadata order.
// ---------------------------------------------------------------------------

// IAsyncOperation<TResult>: put_Completed(handler), get_Completed(out handler),
// GetResults(out TResult). The result here is a 4-byte enum, so GetResults takes
// a CPointer<Int32> out-parameter.
@C
struct AsyncOperationVtbl {
    var base_: IInspectableVtbl = IInspectableVtbl()
    var PutCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> =
        CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32>(CPointer<Unit>())
    var GetCompleted: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> =
        CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(CPointer<Unit>())
    var GetResults: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> =
        CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32>(CPointer<Unit>())
    init() {}
}

// IAsyncInfo: get_Id(out u32), get_Status(out i32), get_ErrorCode(out i32),
// Cancel(), Close().
@C
struct AsyncInfoVtbl {
    var base_: IInspectableVtbl = IInspectableVtbl()
    var GetId: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> =
        CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32>(CPointer<Unit>())
    var GetStatus: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> =
        CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32>(CPointer<Unit>())
    var GetErrorCode: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> =
        CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32>(CPointer<Unit>())
    var Cancel: CFunc<(CPointer<Unit>) -> Int32> = CFunc<(CPointer<Unit>) -> Int32>(CPointer<Unit>())
    var Close: CFunc<(CPointer<Unit>) -> Int32> = CFunc<(CPointer<Unit>) -> Int32>(CPointer<Unit>())
    init() {}
}

// Release a raw COM pointer through its IUnknown::Release slot (vtbl index 2).
func releaseRaw(raw: CPointer<Unit>): Unit {
    if (raw.isNull()) {
        return
    }
    unsafe {
        let vtbl = CPointer<CPointer<IInspectableVtbl>>(raw).read().read()
        let _ = vtbl.base_.Release(raw)
    }
}

// Read the IAsyncInfo status (vtbl GetStatus slot) of an async operation that has
// been QI'd to IAsyncInfo.
func readStatus(infoRaw: CPointer<Unit>): Int32 {
    var status: Int32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<AsyncInfoVtbl>>(infoRaw).read().read()
        let hr = vtbl.GetStatus(infoRaw, CPointer<Int32>(inout status))
        HRESULT(hr).check()
    }
    status
}

// Read the IAsyncInfo error code (HRESULT) of a faulted async operation.
func readErrorCode(infoRaw: CPointer<Unit>): Int32 {
    var code: Int32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<AsyncInfoVtbl>>(infoRaw).read().read()
        let _ = vtbl.GetErrorCode(infoRaw, CPointer<Int32>(inout code))
    }
    code
}

// Read the UserConsentVerificationResult enum out of a completed IAsyncOperation
// via its GetResults vtbl slot.
func readResult(operationRaw: CPointer<Unit>): Int32 {
    var result: Int32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<AsyncOperationVtbl>>(operationRaw).read().read()
        let hr = vtbl.GetResults(operationRaw, CPointer<Int32>(inout result))
        HRESULT(hr).check()
    }
    result
}

// Mirror the reference's {result:?} debug print of the UserConsentVerificationResult variant.
func resultName(value: Int32): String {
    match (value) {
        case 0 => "Verified"
        case 1 => "DeviceNotPresent"
        case 2 => "NotConfiguredForUser"
        case 3 => "DisabledByPolicy"
        case 4 => "DeviceBusy"
        case 5 => "RetriesExhausted"
        case 6 => "Canceled"
        case _ => "UserConsentVerificationResult(${value})"
    }
}

main(): Int64 {
    // Activate the UserConsentVerifier runtime class and obtain its activation
    // factory as the typed statics interface. This bootstraps the WinRT runtime
    // exactly as the reference's `factory::<UserConsentVerifier, _>()` does.
    let statics = factory<UserConsentVerifier, IUserConsentVerifierStatics>().unwrap()
    var operationRaw = CPointer<Unit>()
    var exitCode: Int64 = 0
    try {
        let factoryRaw = statics.asRaw()

        // QueryInterface the factory for the Win32 interop interface (the
        // reference's cast to IUserConsentVerifierInterop).
        let interopRaw = match (unsafe { queryInterfaceRaw(factoryRaw, GUID.parse(IID_IUSERCONSENTVERIFIERINTEROP)) }) {
            case Some(raw) => raw
            case None => throw WindowsException(E_NOINTERFACE)
        }
        try {
            // The message presented in the consent dialog (the reference's
            // h!("Hello from Rust")).
            let message = HString("Hello from Cangjie")
            try {
                // The window handle. HWND::default() == null, as in the reference;
                // replace with a real app window handle in a GUI program.
                let window = HWND()

                // The parameterized IID of IAsyncOperation<UserConsentVerificationResult>,
                // hashed from its WinRT signature.
                var asyncIid = GUID.from_signature(
                    "pinterface({${PINTERFACE_IASYNCOPERATION_GUID}};${SIG_USERCONSENTVERIFICATIONRESULT})"
                )

                unsafe {
                    // RequestVerificationForWindowAsync(this, HWND, HSTRING, REFIID, ppOperation).
                    let vtbl = CPointer<CPointer<IUserConsentVerifierInteropVtbl>>(interopRaw).read().read()
                    let hr = vtbl.RequestVerificationForWindowAsync(
                        interopRaw,
                        window,
                        message.asRaw(),
                        CPointer<Unit>(CPointer<GUID>(inout asyncIid)),
                        CPointer<Unit>(CPointer<CPointer<Unit>>(inout operationRaw))
                    )
                    HRESULT(hr).check()
                }
            } finally {
                message.close()
            }
        } finally {
            // Release the interop interface AddRef'd by QueryInterface.
            releaseRaw(interopRaw)
        }

        // Block on the operation until it reaches a terminal status, then read
        // the result (the reference's `operation.join()?`).
        let infoRaw = match (unsafe { queryInterfaceRaw(operationRaw, GUID.parse(IID_IASYNCINFO)) }) {
            case Some(raw) => raw
            case None => throw WindowsException(E_NOINTERFACE)
        }
        var status = ASYNC_STATUS_STARTED
        var errorCode: Int32 = 0
        try {
            while (true) {
                status = readStatus(infoRaw)
                if (status != ASYNC_STATUS_STARTED) {
                    break
                }
                sleep(Duration.millisecond * 50)
            }
            if (status == ASYNC_STATUS_ERROR) {
                errorCode = readErrorCode(infoRaw)
            }
        } finally {
            releaseRaw(infoRaw)
        }

        match (status) {
            case s where s == ASYNC_STATUS_COMPLETED =>
                let result = readResult(operationRaw)
                println(resultName(result))
            case s where s == ASYNC_STATUS_CANCELED =>
                eprintln("verification canceled")
                exitCode = 1
            case _ =>
                eprintln("verification failed: ${HRESULT(errorCode)}")
                exitCode = 1
        }
    } catch (e: WindowsException) {
        // Mirror the reference's `?` error propagation out of main.
        eprintln("consent verification failed: ${e}")
        exitCode = 1
    } finally {
        releaseRaw(operationRaw)
        statics.close()
    }

    return exitCode
}
