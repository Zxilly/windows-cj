package windows_sample_wmi

import windows_sample_wmi_bindings.Win32.System.Com.{Apis as ComApis}
import windows_sample_wmi_bindings.Win32.Security.{PSECURITY_DESCRIPTOR}
import windows_sample_wmi_bindings.Win32.System.Variant.{Apis as VariantApis, VARIANT}
import windows_sample_wmi_bindings.Win32.System.Wmi.{
    IWbemLocator,
    IWbemLocatorVtbl,
    IWbemServices,
    IWbemServicesVtbl,
    IEnumWbemClassObject,
    IEnumWbemClassObjectVtbl,
    IWbemClassObject,
    IWbemClassObjectVtbl
}
import windows_strings.{BSTR, encodeUtf16WithNull, decodeWideFromPointer}
import windows_core.HRESULT
import windows_interface.GUID

// ============================================================================
// wmi — behaviour-equivalent port of the reference sample.
//
// Boots the COM apartment as MTA (CoInitializeEx) and sets process-wide COM
// security (CoInitializeSecurity), then creates an IWbemLocator via
// CoCreateInstance(WbemLocator) and connects to the root\cimv2 namespace to
// obtain an IWbemServices.
//
//   • ExecQuery: runs "select Caption from Win32_LogicalDisk" and walks the
//     IEnumWbemClassObject with Next, reading the Caption property of each row
//     (an IWbemClassObject) as a VARIANT and printing it.
//   • ExecMethod: gets the Win32_Process class object, fetches its Create
//     method's in-parameter signature, spawns an instance, sets CommandLine to
//     "notepad.exe", invokes Create through ExecMethod, and prints the method's
//     ReturnValue VARIANT.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The WMI COM interfaces are projected as consuming-only Resource wrappers;
//     their methods are NOT instance methods but CFunc fields of separate @C
//     vtbl structs. We read the vtbl pointer out of the raw COM pointer and
//     invoke the CFunc fields directly inside unsafe{} — the exact ABI the
//     reference's projected methods perform (the com_uri / file_dialogs
//     pattern).
//   • CLSID_WbemLocator and IID_IWbemLocator are not re-exported as facade
//     scalars; we materialise them with GUID.parse from their documented values
//     — semantically identical to the reference's named constants.
//   • BSTR arguments are passed as the BSTR's raw UInt16 pointer reinterpreted
//     as CPointer<Unit>. An empty/None BSTR (the reference's &BSTR::new()) is a
//     null pointer, which COM treats as an empty string.
//   • There is no compile-time w! wide literal; encodeUtf16WithNull builds a
//     NUL-terminated UTF-16 buffer at run time (the behavioural twin of w!).
//   • The VARIANT input for Put("CommandLine", "notepad.exe") is built by hand
//     as a VT_BSTR VARIANT (vt = 8) whose bstrVal points at freshly allocated
//     BSTR storage, then released with VariantClear after ExecMethod.
//   • The reference's `println!("{value}")` formats a VARIANT via Display, which
//     converts it to a BSTR and debug-prints it (quoted). We mirror that by
//     converting each VARIANT to a wide string with PropSys VariantToStringAlloc
//     (the same coercion the reference's PROPVARIANT path performs) and printing
//     it quoted.
//   • COM pointer lifetimes are owned by the generated Resource wrappers
//     (takeOwnership: true); their close()/finalizer calls Release. GC manages
//     references between the Cangjie wrappers, so no manual AddRef/Release.
// ============================================================================

// CLSID_WbemLocator {4590F811-1D3A-11D0-891F-00AA004B2E24}.
let CLSID_WBEM_LOCATOR = GUID.parse("4590F811-1D3A-11D0-891F-00AA004B2E24")
// IID_IWbemLocator {DC12A687-737F-11CF-884D-00AA004B2E24}.
let IID_IWBEM_LOCATOR = GUID.parse("DC12A687-737F-11CF-884D-00AA004B2E24")

// CLSCTX_INPROC_SERVER — in-process activation context.
const CLSCTX_INPROC_SERVER: UInt32 = 1
// COINIT_MULTITHREADED — apartment model for CoInitializeEx (value 0).
const COINIT_MULTITHREADED: UInt32 = 0
// RPC_C_AUTHN_LEVEL_DEFAULT — let the system negotiate the authentication level.
const RPC_C_AUTHN_LEVEL_DEFAULT: UInt32 = 0
// RPC_C_IMP_LEVEL_IMPERSONATE — allow the server to impersonate the client.
const RPC_C_IMP_LEVEL_IMPERSONATE: UInt32 = 3
// EOAC_NONE — no extra authentication capabilities.
const EOAC_NONE: UInt32 = 0

// WBEM_FLAG_FORWARD_ONLY (32) | WBEM_FLAG_RETURN_IMMEDIATELY (16) == 48.
const WBEM_QUERY_FLAGS: Int32 = 48
// WBEM_INFINITE — block indefinitely for the next row.
const WBEM_INFINITE: Int32 = -1
// VT_BSTR — VARIANT type tag for a BSTR payload.
const VT_BSTR: UInt16 = 8

// Build a VT_BSTR VARIANT whose bstrVal points at the supplied BSTR storage.
// The returned VARIANT owns the BSTR; the caller must VariantClear it.
func bstrVariant(bstrRaw: CPointer<Unit>): VARIANT {
    var result = VARIANT()
    var outer = result.Anonymous
    var payload = outer.Anonymous
    payload.vt = VT_BSTR
    var value = payload.Anonymous
    value.bstrVal = bstrRaw
    payload.Anonymous = value
    outer.Anonymous = payload
    result.Anonymous = outer
    return result
}

// Convert a VARIANT to its string form via PropSys VariantToStringAlloc — the
// same coercion the reference's VARIANT Display performs — and return it quoted
// to match the reference's debug-formatted BSTR ({:?}).
func formatVariant(value: VARIANT): String {
    var v = value
    var bufPtr = CPointer<UInt16>()
    let text = unsafe {
        let hr = VariantApis.VariantToStringAlloc(
            CPointer<Unit>(CPointer<VARIANT>(inout v)),
            CPointer<CPointer<UInt16>>(inout bufPtr)
        )
        HRESULT(hr).check()
        let s = if (bufPtr.isNull()) {
            ""
        } else {
            decodeWideFromPointer(bufPtr)
        }
        if (bufPtr.isNotNull()) {
            ComApis.CoTaskMemFree(CPointer<Unit>(bufPtr))
        }
        s
    }
    return "\"${text}\""
}

// IWbemLocator::ConnectServer. Connects to the named WMI namespace and returns a
// raw IWbemServices pointer (ownership transfers to the caller).
func connectServer(locatorRaw: CPointer<Unit>, namespaceRaw: CPointer<Unit>): CPointer<Unit> {
    var serverRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IWbemLocatorVtbl>>(locatorRaw).read().read()
        // ConnectServer(this, strNetworkResource, strUser, strPassword,
        //   strLocale, lSecurityFlags, strAuthority, pCtx, ppNamespace).
        // Empty BSTRs (the reference's &BSTR::new()) are null pointers; pCtx is
        // None (null).
        let hr = vtbl.ConnectServer(
            locatorRaw,
            namespaceRaw,
            CPointer<Unit>(),
            CPointer<Unit>(),
            CPointer<Unit>(),
            0i32,
            CPointer<Unit>(),
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout serverRaw))
        )
        HRESULT(hr).check()
    }
    return serverRaw
}

// IWbemServices::ExecQuery. Returns a raw IEnumWbemClassObject pointer.
func execQuery(serverRaw: CPointer<Unit>, languageRaw: CPointer<Unit>, queryRaw: CPointer<Unit>): CPointer<Unit> {
    var enumRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IWbemServicesVtbl>>(serverRaw).read().read()
        // ExecQuery(this, strQueryLanguage, strQuery, lFlags, pCtx, ppEnum).
        let hr = vtbl.ExecQuery(
            serverRaw,
            languageRaw,
            queryRaw,
            WBEM_QUERY_FLAGS,
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout enumRaw))
        )
        HRESULT(hr).check()
    }
    return enumRaw
}

// IEnumWbemClassObject::Next. Reads at most one row into rowSlot. Returns the
// number of rows actually returned. The HRESULT is checked (S_FALSE == 1 is
// success with zero rows, which `.ok()` in the reference also accepts).
func enumNext(enumRaw: CPointer<Unit>, rowSlot: CPointer<CPointer<Unit>>): UInt32 {
    var returned: UInt32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<IEnumWbemClassObjectVtbl>>(enumRaw).read().read()
        // Next(this, lTimeout, uCount, apObjects, puReturned).
        let hr = vtbl.Next(
            enumRaw,
            WBEM_INFINITE,
            1u32,
            CPointer<Unit>(rowSlot),
            CPointer<Unit>(CPointer<UInt32>(inout returned))
        )
        HRESULT(hr).check()
    }
    return returned
}

// IWbemClassObject::Get. Reads the named property into a VARIANT (initialised
// empty). The wide name buffer must stay pinned across the call.
func objectGet(objectRaw: CPointer<Unit>, name: Array<UInt16>): VARIANT {
    var value = VARIANT()
    unsafe {
        let nameHandle = acquireArrayRawData(name)
        try {
            let vtbl = CPointer<CPointer<IWbemClassObjectVtbl>>(objectRaw).read().read()
            // Get(this, wszName, lFlags, pVal, pType, plFlavor).
            let hr = vtbl.Get(
                objectRaw,
                nameHandle.pointer,
                0i32,
                CPointer<Unit>(CPointer<VARIANT>(inout value)),
                CPointer<Unit>(),
                CPointer<Unit>()
            )
            HRESULT(hr).check()
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }
    return value
}

// IWbemServices::GetObject. Returns the named class object (raw IWbemClassObject).
func servicesGetObject(serverRaw: CPointer<Unit>, classNameRaw: CPointer<Unit>): CPointer<Unit> {
    var classRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IWbemServicesVtbl>>(serverRaw).read().read()
        // GetObject(this, strObjectPath, lFlags, pCtx, ppObject, ppCallResult).
        let hr = vtbl.GetObject(
            serverRaw,
            classNameRaw,
            0i32,
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout classRaw)),
            CPointer<Unit>()
        )
        HRESULT(hr).check()
    }
    return classRaw
}

// IWbemClassObject::GetMethod. Returns the in-parameter signature object (raw
// IWbemClassObject). The wide method name buffer must stay pinned.
func objectGetMethod(classRaw: CPointer<Unit>, name: Array<UInt16>): CPointer<Unit> {
    var inputRaw = CPointer<Unit>()
    unsafe {
        let nameHandle = acquireArrayRawData(name)
        try {
            let vtbl = CPointer<CPointer<IWbemClassObjectVtbl>>(classRaw).read().read()
            // GetMethod(this, wszName, lFlags, ppInSignature, ppOutSignature).
            let hr = vtbl.GetMethod(
                classRaw,
                nameHandle.pointer,
                0i32,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout inputRaw)),
                CPointer<Unit>()
            )
            HRESULT(hr).check()
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }
    return inputRaw
}

// IWbemClassObject::SpawnInstance. Returns a new instance (raw IWbemClassObject).
func objectSpawnInstance(inputRaw: CPointer<Unit>): CPointer<Unit> {
    var objectRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IWbemClassObjectVtbl>>(inputRaw).read().read()
        // SpawnInstance(this, lFlags, ppNewInstance).
        let hr = vtbl.SpawnInstance(
            inputRaw,
            0i32,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout objectRaw))
        )
        HRESULT(hr).check()
    }
    return objectRaw
}

// IWbemClassObject::Put. Sets the named property to the supplied VARIANT. The
// wide name buffer must stay pinned across the call.
func objectPut(objectRaw: CPointer<Unit>, name: Array<UInt16>, value: VARIANT): Unit {
    var v = value
    unsafe {
        let nameHandle = acquireArrayRawData(name)
        try {
            let vtbl = CPointer<CPointer<IWbemClassObjectVtbl>>(objectRaw).read().read()
            // Put(this, wszName, lFlags, pVal, Type).
            let hr = vtbl.Put(
                objectRaw,
                nameHandle.pointer,
                0i32,
                CPointer<Unit>(CPointer<VARIANT>(inout v)),
                0i32
            )
            HRESULT(hr).check()
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }
}

// IWbemServices::ExecMethod. Invokes the named method on the named object with
// the supplied in-parameters instance, returning the out-parameters object.
func servicesExecMethod(
    serverRaw: CPointer<Unit>,
    classNameRaw: CPointer<Unit>,
    methodNameRaw: CPointer<Unit>,
    inParamsRaw: CPointer<Unit>
): CPointer<Unit> {
    var outputRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IWbemServicesVtbl>>(serverRaw).read().read()
        // ExecMethod(this, strObjectPath, strMethodName, lFlags, pCtx,
        //   pInParams, ppOutParams, ppCallResult).
        let hr = vtbl.ExecMethod(
            serverRaw,
            classNameRaw,
            methodNameRaw,
            0i32,
            CPointer<Unit>(),
            inParamsRaw,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outputRaw)),
            CPointer<Unit>()
        )
        HRESULT(hr).check()
    }
    return outputRaw
}

main(): Int64 {
    // CoInitializeEx(None, COINIT_MULTITHREADED).ok()?
    ComApis.CoInitializeExChecked(CPointer<Unit>(), COINIT_MULTITHREADED)

    // CoInitializeSecurity(None, -1, None, None, RPC_C_AUTHN_LEVEL_DEFAULT,
    //   RPC_C_IMP_LEVEL_IMPERSONATE, None, EOAC_NONE, None).
    ComApis.CoInitializeSecurityChecked(
        PSECURITY_DESCRIPTOR(),
        -1i32,
        CPointer<Unit>(),
        CPointer<Unit>(),
        RPC_C_AUTHN_LEVEL_DEFAULT,
        RPC_C_IMP_LEVEL_IMPERSONATE,
        CPointer<Unit>(),
        EOAC_NONE,
        CPointer<Unit>()
    )

    // CoCreateInstance(&WbemLocator, None, CLSCTX_INPROC_SERVER) -> IWbemLocator.
    var clsid = CLSID_WBEM_LOCATOR
    var iid = IID_IWBEM_LOCATOR
    var locatorRaw = CPointer<Unit>()
    unsafe {
        let hr = ComApis.CoCreateInstance(
            CPointer<Unit>(CPointer<GUID>(inout clsid)),
            CPointer<Unit>(),
            CLSCTX_INPROC_SERVER,
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout locatorRaw))
        )
        HRESULT(hr).check()
    }
    let locator = IWbemLocator(locatorRaw, takeOwnership: true)

    // ConnectServer(&BSTR::from("root\\cimv2"), ...) -> IWbemServices.
    let namespaceBstr = BSTR("root\\cimv2")
    let serverRaw = unsafe {
        connectServer(locatorRaw, CPointer<Unit>(namespaceBstr.asPtr()))
    }
    namespaceBstr.close()
    let server = IWbemServices(serverRaw, takeOwnership: true)

    try {
        //
        // ExecQuery example
        //
        let languageBstr = BSTR("WQL")
        let queryBstr = BSTR("select Caption from Win32_LogicalDisk")
        let enumRaw = unsafe {
            execQuery(serverRaw, CPointer<Unit>(languageBstr.asPtr()), CPointer<Unit>(queryBstr.asPtr()))
        }
        languageBstr.close()
        queryBstr.close()
        let queryEnum = IEnumWbemClassObject(enumRaw, takeOwnership: true)

        let captionName = encodeUtf16WithNull("Caption")
        try {
            while (true) {
                // let mut row = [None; 1]; query.Next(WBEM_INFINITE, &mut row, &mut returned).
                var rowSlot = CPointer<Unit>()
                let returned = unsafe {
                    enumNext(enumRaw, CPointer<CPointer<Unit>>(inout rowSlot))
                }

                if (returned == 0u32 || rowSlot.isNull()) {
                    break
                }

                // Take ownership of the row object so it is Released on close.
                let row = IWbemClassObject(rowSlot, takeOwnership: true)
                try {
                    let value = objectGet(rowSlot, captionName)
                    println(formatVariant(value))
                    var clearable = value
                    unsafe {
                        VariantApis.VariantClear(CPointer<Unit>(CPointer<VARIANT>(inout clearable)))
                    }
                } finally {
                    row.close()
                }
            }
        } finally {
            queryEnum.close()
        }

        //
        // ExecMethod example
        //
        let classNameBstr = BSTR("Win32_Process")
        let methodNameBstr = BSTR("Create")

        // server.GetObject(&class_name, ...) -> class object.
        let classRaw = unsafe {
            servicesGetObject(serverRaw, CPointer<Unit>(classNameBstr.asPtr()))
        }
        let classObject = IWbemClassObject(classRaw, takeOwnership: true)

        try {
            // class.GetMethod(&method_name, 0, &mut input, null) -> in-params sig.
            let createName = encodeUtf16WithNull("Create")
            let inputRaw = objectGetMethod(classRaw, createName)
            let input = IWbemClassObject(inputRaw, takeOwnership: true)

            try {
                // let object = input.SpawnInstance(0)?
                let objectRaw = objectSpawnInstance(inputRaw)
                let object = IWbemClassObject(objectRaw, takeOwnership: true)

                try {
                    // object.Put(w!("CommandLine"), 0, &VARIANT::from("notepad.exe"), 0).
                    let commandLineName = encodeUtf16WithNull("CommandLine")
                    let commandLineBstr = BSTR("notepad.exe")
                    let commandLineVariant = bstrVariant(CPointer<Unit>(commandLineBstr.asPtr()))
                    objectPut(objectRaw, commandLineName, commandLineVariant)
                    // The VARIANT borrowed the BSTR storage for the Put call; the
                    // server copied the value, so we free our BSTR now.
                    commandLineBstr.close()

                    // server.ExecMethod(&class_name, &method_name, .., &object, &mut output, ..).
                    let outputRaw = servicesExecMethod(
                        serverRaw,
                        CPointer<Unit>(classNameBstr.asPtr()),
                        CPointer<Unit>(methodNameBstr.asPtr()),
                        objectRaw
                    )
                    let output = IWbemClassObject(outputRaw, takeOwnership: true)

                    try {
                        // output.Get(w!("ReturnValue"), 0, &mut value, None, None)?
                        let returnValueName = encodeUtf16WithNull("ReturnValue")
                        let value = objectGet(outputRaw, returnValueName)
                        println("`Create` method return value: ${formatVariant(value)}")
                        var clearable = value
                        unsafe {
                            VariantApis.VariantClear(CPointer<Unit>(CPointer<VARIANT>(inout clearable)))
                        }
                    } finally {
                        output.close()
                    }
                } finally {
                    object.close()
                }
            } finally {
                input.close()
            }
        } finally {
            classObject.close()
        }

        classNameBstr.close()
        methodNameBstr.close()
    } finally {
        server.close()
        locator.close()
    }

    return 0
}
