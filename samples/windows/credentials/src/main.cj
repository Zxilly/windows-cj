package windows_sample_credentials

import windows_sample_credentials_bindings.Win32.Security.Credentials.{Apis, CREDENTIALW}
import windows_strings.decodeWideFromPointer
import windows_core.WindowsException

// ============================================================================
// credentials — behaviour-equivalent port of the reference sample.
//
// CredEnumerateW returns an array of pointers to CREDENTIALW records describing
// every stored credential for the current logon session. For each record we
// print its credential Type and, when present, its TargetName and UserName,
// then release the whole block with CredFree. The process then exits.
//
// Paradigm notes (Cangjie vs the reference language):
//   • CredEnumerateW's out-parameters are modelled as `CPointer<Unit>` taken
//     over a local `var`: `CPointer<Unit>(CPointer<T>(inout v))`. The reference
//     passes `&mut count` / `&mut credentials_ptr`; this is the ABI-equivalent.
//   • `credentials_ptr` is, as in the reference, a pointer to an array of
//     pointers — `CPointer<CPointer<CREDENTIALW>>`. We read element `i` to get
//     the i-th `CPointer<CREDENTIALW>`, then `.read()` it for the record value.
//   • CREDENTIALW is an `@C struct`; `.Type` is a plain UInt32 (the generator
//     emits the CRED_TYPE enum value as its underlying integer, matching the
//     reference's `{:?}` debug print of the numeric type tag), and TargetName /
//     UserName are `CPointer<UInt16>` wide-string pointers. We turn each into a
//     String with `decodeWideFromPointer`, which walks to the NUL terminator —
//     the equivalent of the reference's `PCWSTR::display()`.
//   • There is no `null`: a null wide pointer is `CPointer<UInt16>()` and is
//     tested with `.isNull()`, mirroring the reference's `is_null()` guards.
//   • The fallible CredEnumerateW maps to the throwing `CredEnumerateWChecked`
//     twin; on failure it raises a `windows_core.WindowsException`, which we
//     surface as a non-zero exit code — the analogue of the reference's
//     `Result`-returning main propagating the error with `?`.
// ============================================================================

// CRED_ENUMERATE_ALL_CREDENTIALS. The generated facade does not re-export this
// scalar flag constant, so we encode its documented value (1) directly. The
// CredEnumerateW Flags parameter is a plain UInt32 in the generated binding.
const CRED_ENUMERATE_ALL_CREDENTIALS: UInt32 = 1

main(): Int64 {
    var count: UInt32 = 0
    var credentialsPtr: CPointer<CPointer<CREDENTIALW>> = CPointer<CPointer<CREDENTIALW>>()

    try {
        unsafe {
            // Filter = None -> a null wide-string pointer.
            let filter = CPointer<UInt16>()
            let countPtr = CPointer<Unit>(CPointer<UInt32>(inout count))
            let outPtr = CPointer<Unit>(CPointer<CPointer<CREDENTIALW>>(inout credentialsPtr))

            Apis.CredEnumerateWChecked(filter, CRED_ENUMERATE_ALL_CREDENTIALS, countPtr, outPtr)

            var i: Int64 = 0
            while (i < Int64(count)) {
                // The block is an array of CREDENTIALW pointers; read the i-th
                // pointer, then dereference it to obtain the record value.
                let recordPtr = credentialsPtr.read(i)
                let credential = recordPtr.read()

                println("/* CREDENTIALW */")
                println("Type: ${credential.Type}")
                if (!credential.TargetName.isNull()) {
                    println("Target: ${decodeWideFromPointer(credential.TargetName)}")
                }
                if (!credential.UserName.isNull()) {
                    println("User name: ${decodeWideFromPointer(credential.UserName)}")
                }
                println("")

                i += 1
            }

            // Free the whole block. The reference reinterprets the
            // `*mut *mut _` as a `*const c_void`; here we cast the array-base
            // pointer to `CPointer<Unit>` for CredFree.
            Apis.CredFree(CPointer<Unit>(credentialsPtr))
        }
    } catch (e: WindowsException) {
        // Mirror the reference's error propagation out of main as a failing
        // exit status.
        eprintln("CredEnumerateW failed: ${e}")
        return 1
    }

    return 0
}
