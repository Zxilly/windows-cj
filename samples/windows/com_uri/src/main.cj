package windows_sample_com_uri

import windows_sample_com_uri_bindings.Win32.System.Com.{Apis, IUri, IUriVtbl}
import windows_strings.{encodeUtf16WithNull, BSTR}
import windows_core.HRESULT

// ============================================================================
// com_uri — behaviour-equivalent port of the reference sample.
//
// CreateUri parses an absolute URL ("http://kennykerr.ca") and hands back an
// IUri COM object. We then read two of its properties — GetDomain (a BSTR) and
// GetPort (a UInt32 / DWORD) — and print the domain (quoted, matching the
// reference's debug formatting of the BSTR) followed by the port in parens.
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no compile-time `w!` wide-literal. We build a NUL-terminated
//     UTF-16 buffer at run time with encodeUtf16WithNull and feed its raw
//     pointer to CreateUri. This is semantically identical to a `w!` literal.
//   • URI_CREATE_FLAGS::default() is the all-zero flag value, so we pass 0.
//   • The "None" reserved argument is a null pointer (CPointer<Unit>()).
//   • IUri's methods are not surfaced as instance methods on the generated
//     Resource wrapper; the generator exposes the COM vtbl as an @C struct
//     (IUriVtbl). We therefore read the vtbl pointer out of the raw COM
//     pointer and invoke GetDomain / GetPort through it directly — the exact
//     ABI the reference's projected methods perform under the hood.
//   • The returned IUri pointer's lifetime is owned by the generated IUri
//     Resource (takeOwnership: true); its finalizer / close() calls Release,
//     so no manual AddRef/Release is needed (GC manages the wrapper itself).
//   • The BSTR returned by GetDomain is owned by the caller; wrapping it in
//     windows_strings.BSTR via fromRawTake frees it with SysFreeString on
//     close, matching the reference's owned-BSTR drop.
// ============================================================================

// Invoke IUri::GetDomain through the COM vtbl. The out-parameter is a BSTR
// (a CPointer<Unit> in this projection); on success ownership transfers to us.
func getDomain(raw: CPointer<Unit>): BSTR {
    var domainRaw = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IUriVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.GetDomain(raw, CPointer<CPointer<Unit>>(inout domainRaw))
        HRESULT(hr).check()
    }
    // Reinterpret the BSTR pointer as wide-char storage and take ownership so
    // the wrapper frees it with SysFreeString.
    BSTR.fromRawTake(CPointer<UInt16>(domainRaw))
}

// Invoke IUri::GetPort through the COM vtbl. The out-parameter is a DWORD
// (UInt32) passed as a type-erased pointer in this projection.
func getPort(raw: CPointer<Unit>): UInt32 {
    var port: UInt32 = 0
    unsafe {
        let vtblPtr = CPointer<CPointer<IUriVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.GetPort(raw, CPointer<Unit>(CPointer<UInt32>(inout port)))
        HRESULT(hr).check()
    }
    port
}

main(): Int64 {
    // Build a NUL-terminated UTF-16 buffer for the URL (the run-time analogue of
    // a `w!` wide literal).
    let url = encodeUtf16WithNull("http://kennykerr.ca")

    var uriRaw = CPointer<Unit>()
    unsafe {
        let urlHandle = acquireArrayRawData(url)
        try {
            // CreateUri(pwzURI, dwFlags, dwReserved, ppURI). URI_CREATE_FLAGS
            // default == 0; reserved == null. CreateUriChecked throws on a
            // failed HRESULT, mirroring the reference's `?`.
            Apis.CreateUriChecked(
                urlHandle.pointer,
                0u32,
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout uriRaw))
            )
        } finally {
            releaseArrayRawData(urlHandle)
        }
    }

    // Take ownership of the IUri so it is Released when the wrapper is finalized.
    let uri = IUri(uriRaw, takeOwnership: true)
    try {
        let domain = getDomain(uriRaw)
        let port = getPort(uriRaw)
        // Match the reference's `{domain:?}` (quoted BSTR) and `({port})` shape.
        println("\"${domain}\" (${port})")
        domain.close()
    } finally {
        uri.close()
    }

    return 0
}
