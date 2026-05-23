package windows_result

// Shared test fixtures for the windows-result internal test suite:
// fake COM identity / IErrorInfo vtable backends, ref-count bookkeeping,
// BSTR allocation helpers, and stale-pointer factories. Kept in one place so
// the behavior tests in internal_test.cj read as intent, not scaffolding.

@When[test && os == "Windows"]
import std.fs.*

@When[test && os == "Windows"]
func require(condition: Bool, message: String): Unit {
    if (!condition) {
        throw Exception(message)
    }
}

@When[test && os == "Windows"]
@C
struct FakeIdentityInterface {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

@When[test && os == "Windows"]
var fakeIdentityCanonicalPtr: CPointer<Unit> = CPointer<Unit>()

@When[test && os == "Windows"]
var fakeIdentityQueryCalls: UInt32 = 0u32

@When[test && os == "Windows"]
var fakeIdentityAddRefCalls: UInt32 = 0u32

@When[test && os == "Windows"]
var fakeIdentityReleaseCalls: UInt32 = 0u32

@When[test && os == "Windows"]
var fakeIdentityRefCount: UInt32 = 0u32

@When[test && os == "Windows"]
func resetIdentityState(): Unit {
    fakeIdentityCanonicalPtr = CPointer<Unit>()
    fakeIdentityQueryCalls = 0u32
    fakeIdentityAddRefCalls = 0u32
    fakeIdentityReleaseCalls = 0u32
    fakeIdentityRefCount = 0u32
}

@When[test && os == "Windows"]
func readComSourceForTesting(): String {
    try {
        return String.fromUtf8(File.readFrom("windows-result/src/com.cj"))
    } catch (_: Exception) {
        return String.fromUtf8(File.readFrom("src/com.cj"))
    }
}

@When[test && os == "Windows"]
@C
func fakeIdentityQueryInterface(
    _: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultPtr: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        fakeIdentityQueryCalls += 1u32
        if (iid.isNull() || resultPtr.isNull()) {
            return E_POINTER.value
        }

        let requested = iid.read()
        if (requested == IID_IUnknown) {
            resultPtr.write(fakeIdentityCanonicalPtr)
            fakeIdentityRefCount = fakeIdentityAddRef(fakeIdentityCanonicalPtr)
            return S_OK.value
        }

        resultPtr.write(CPointer<Unit>())
        E_NOINTERFACE.value
    }
}

@When[test && os == "Windows"]
@C
func fakeIdentityFailingPartialQueryInterface(
    _: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultPtr: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        fakeIdentityQueryCalls += 1u32
        if (iid.isNull() || resultPtr.isNull()) {
            return E_POINTER.value
        }

        resultPtr.write(fakeIdentityCanonicalPtr)
        fakeIdentityRefCount = fakeIdentityAddRef(fakeIdentityCanonicalPtr)
        E_FAIL.value
    }
}

@When[test && os == "Windows"]
@C
func fakeIdentityAddRef(_: CPointer<Unit>): UInt32 {
    fakeIdentityAddRefCalls += 1u32
    fakeIdentityRefCount += 1u32
    fakeIdentityRefCount
}

@When[test && os == "Windows"]
@C
func fakeIdentityRelease(_: CPointer<Unit>): UInt32 {
    fakeIdentityReleaseCalls += 1u32
    if (fakeIdentityRefCount > 0u32) {
        fakeIdentityRefCount -= 1u32
    }
    fakeIdentityRefCount
}

@When[test && os == "Windows"]
@C
struct FakeErrorInfo {
    var lpVtbl: CPointer<IErrorInfoVtbl> = CPointer<IErrorInfoVtbl>()
    init() {}
}

@When[test && os == "Windows"]
@C
struct FakeRestrictedErrorInfo {
    var lpVtbl: CPointer<IRestrictedErrorInfoVtbl> = CPointer<IRestrictedErrorInfoVtbl>()
    init() {}
}

@When[test && os == "Windows"]
var fakeErrorInfoPrimaryPtr: CPointer<Unit> = CPointer<Unit>()

@When[test && os == "Windows"]
var fakeRestrictedInfoPtr: CPointer<Unit> = CPointer<Unit>()

@When[test && os == "Windows"]
var fakeErrorInfoAddRefCalls: UInt32 = 0u32

@When[test && os == "Windows"]
var fakeErrorInfoReleaseCalls: UInt32 = 0u32

@When[test && os == "Windows"]
var fakeErrorInfoRefCount: UInt32 = 0u32

@When[test && os == "Windows"]
func resetErrorInfoLifetimeState(): Unit {
    fakeErrorInfoAddRefCalls = 0u32
    fakeErrorInfoReleaseCalls = 0u32
    fakeErrorInfoRefCount = 0u32
    let _ = setErrorInfoAbi(0u32, CPointer<Unit>())
}

@When[test && os == "Windows"]
@C
func fakeErrorInfoQueryInterface(
    _: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultPtr: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (iid.isNull() || resultPtr.isNull()) {
            return E_POINTER.value
        }

        let requested = iid.read()
        if (requested == IID_IUnknown || requested == IID_IErrorInfo) {
            resultPtr.write(fakeErrorInfoPrimaryPtr)
            return S_OK.value
        }
        if (requested == IID_IRestrictedErrorInfo) {
            resultPtr.write(fakeRestrictedInfoPtr)
            return S_OK.value
        }

        resultPtr.write(CPointer<Unit>())
        E_NOINTERFACE.value
    }
}

@When[test && os == "Windows"]
@C
func fakeErrorInfoAddRef(_: CPointer<Unit>): UInt32 {
    fakeErrorInfoAddRefCalls += 1u32
    fakeErrorInfoRefCount += 1u32
    fakeErrorInfoRefCount
}

@When[test && os == "Windows"]
@C
func fakeErrorInfoRelease(_: CPointer<Unit>): UInt32 {
    fakeErrorInfoReleaseCalls += 1u32
    if (fakeErrorInfoRefCount > 0u32) {
        fakeErrorInfoRefCount -= 1u32
    }
    fakeErrorInfoRefCount
}

@When[test && os == "Windows"]
@C
func fakeGetDescription(
    _: CPointer<Unit>,
    description: CPointer<CPointer<UInt16>>
): Int32 {
    unsafe {
        if (description.isNotNull()) {
            description.write(CPointer<UInt16>())
        }
    }
    S_OK.value
}

@When[test && os == "Windows"]
func allocateTestBstr(text: String): CPointer<UInt16> {
    let units = encodeUtf16Units(text)
    if (units.isEmpty()) {
        return CPointer<UInt16>()
    }
    unsafe {
        let handle = acquireArrayRawData(units)
        try {
            sysAllocStringLenAbi(handle.pointer, UInt32(units.size))
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

@When[test && os == "Windows"]
func staleDefaultUnitPointerForTesting(): CPointer<Unit> {
    unsafe { CPointer<Unit>(CPointer<UInt8>() + 0x1234) }
}

@When[test && os == "Windows"]
func staleDefaultBstrPointerForTesting(): CPointer<UInt16> {
    unsafe { CPointer<UInt16>(CPointer<UInt8>() + 0x1234) }
}

@When[test && os == "Windows"]
@C
func fakeGetDescriptionFailingPartial(
    _: CPointer<Unit>,
    description: CPointer<CPointer<UInt16>>
): Int32 {
    unsafe {
        if (description.isNotNull()) {
            description.write(allocateTestBstr("partial description"))
        }
    }
    E_FAIL.value
}

@When[test && os == "Windows"]
@C
func fakeGetErrorDetails(
    _: CPointer<Unit>,
    fallback: CPointer<CPointer<UInt16>>,
    errorCode: CPointer<Int32>,
    description: CPointer<CPointer<UInt16>>,
    reference: CPointer<CPointer<UInt16>>
): Int32 {
    unsafe {
        if (fallback.isNotNull()) {
            fallback.write(CPointer<UInt16>())
        }
        if (errorCode.isNotNull()) {
            errorCode.write(E_FAIL.value)
        }
        if (description.isNotNull()) {
            description.write(CPointer<UInt16>())
        }
        if (reference.isNotNull()) {
            reference.write(CPointer<UInt16>())
        }
    }
    S_OK.value
}

@When[test && os == "Windows"]
@C
func fakeGetErrorDetailsFailingPartial(
    _: CPointer<Unit>,
    fallback: CPointer<CPointer<UInt16>>,
    errorCode: CPointer<Int32>,
    description: CPointer<CPointer<UInt16>>,
    reference: CPointer<CPointer<UInt16>>
): Int32 {
    unsafe {
        if (fallback.isNotNull()) {
            fallback.write(allocateTestBstr("partial fallback"))
        }
        if (errorCode.isNotNull()) {
            errorCode.write(E_FAIL.value)
        }
        if (description.isNotNull()) {
            description.write(allocateTestBstr("partial description"))
        }
        if (reference.isNotNull()) {
            reference.write(allocateTestBstr("partial reference"))
        }
    }
    E_FAIL.value
}

@When[test && os == "Windows"]
@C
func fakeGetReference(
    _: CPointer<Unit>,
    reference: CPointer<CPointer<UInt16>>
): Int32 {
    unsafe {
        if (reference.isNotNull()) {
            reference.write(CPointer<UInt16>())
        }
    }
    S_OK.value
}

@When[test && os == "Windows"]
func publishAndClearThreadError(infoPtr: CPointer<IErrorInfo>): Unit {
    let error = errorFromRawForTesting(E_FAIL, infoPtr)
    require(fakeErrorInfoRefCount == 1u32, "test setup should start with exactly one retained COM reference")
    error.intoThread()
    let _ = setErrorInfoAbi(0u32, CPointer<Unit>())
}
