package windows_result

@When[test]
import std.unittest.*

@When[test]
import std.unittest.testmacro.*

@When[test]
func require(condition: Bool, message: String): Unit {
    if (!condition) {
        throw Exception(message)
    }
}

@When[test]
@C
struct FakeIdentityInterface {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

@When[test]
var fakeIdentityCanonicalPtr: CPointer<Unit> = CPointer<Unit>()

@When[test]
var fakeIdentityQueryCalls: UInt32 = 0u32

@When[test]
var fakeIdentityAddRefCalls: UInt32 = 0u32

@When[test]
var fakeIdentityReleaseCalls: UInt32 = 0u32

@When[test]
var fakeIdentityRefCount: UInt32 = 0u32

@When[test]
func resetIdentityState(): Unit {
    fakeIdentityCanonicalPtr = CPointer<Unit>()
    fakeIdentityQueryCalls = 0u32
    fakeIdentityAddRefCalls = 0u32
    fakeIdentityReleaseCalls = 0u32
    fakeIdentityRefCount = 0u32
}

@When[test]
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

@When[test]
@C
func fakeIdentityAddRef(_: CPointer<Unit>): UInt32 {
    fakeIdentityAddRefCalls += 1u32
    fakeIdentityRefCount += 1u32
    fakeIdentityRefCount
}

@When[test]
@C
func fakeIdentityRelease(_: CPointer<Unit>): UInt32 {
    fakeIdentityReleaseCalls += 1u32
    if (fakeIdentityRefCount > 0u32) {
        fakeIdentityRefCount -= 1u32
    }
    fakeIdentityRefCount
}

@When[test]
@C
struct FakeErrorInfo {
    var lpVtbl: CPointer<IErrorInfoVtbl> = CPointer<IErrorInfoVtbl>()
    init() {}
}

@When[test]
@C
struct FakeRestrictedErrorInfo {
    var lpVtbl: CPointer<IRestrictedErrorInfoVtbl> = CPointer<IRestrictedErrorInfoVtbl>()
    init() {}
}

@When[test]
var fakeErrorInfoPrimaryPtr: CPointer<Unit> = CPointer<Unit>()

@When[test]
var fakeRestrictedInfoPtr: CPointer<Unit> = CPointer<Unit>()

@When[test]
var fakeErrorInfoAddRefCalls: UInt32 = 0u32

@When[test]
var fakeErrorInfoReleaseCalls: UInt32 = 0u32

@When[test]
var fakeErrorInfoRefCount: UInt32 = 0u32

@When[test]
func resetErrorInfoLifetimeState(): Unit {
    fakeErrorInfoAddRefCalls = 0u32
    fakeErrorInfoReleaseCalls = 0u32
    fakeErrorInfoRefCount = 0u32
    let _ = setErrorInfoAbi(0u32, CPointer<Unit>())
}

@When[test]
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

@When[test]
@C
func fakeErrorInfoAddRef(_: CPointer<Unit>): UInt32 {
    fakeErrorInfoAddRefCalls += 1u32
    fakeErrorInfoRefCount += 1u32
    fakeErrorInfoRefCount
}

@When[test]
@C
func fakeErrorInfoRelease(_: CPointer<Unit>): UInt32 {
    fakeErrorInfoReleaseCalls += 1u32
    if (fakeErrorInfoRefCount > 0u32) {
        fakeErrorInfoRefCount -= 1u32
    }
    fakeErrorInfoRefCount
}

@When[test]
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

@When[test]
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

@When[test]
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

@When[test]
func publishAndClearThreadError(infoPtr: CPointer<IErrorInfo>): Unit {
    let error = errorFromRawForTesting(E_FAIL, infoPtr)
    require(fakeErrorInfoRefCount == 1u32, "test setup should start with exactly one retained COM reference")
    error.intoThread()
    let _ = setErrorInfoAbi(0u32, CPointer<Unit>())
}

@When[test && os == "Windows" && slim_errors != "true"]
@Test
class WindowsResultInternalTests {
    @TestCase
    public func comHandleEqualityUsesCanonicalIUnknownIdentity(): Unit {
        resetIdentityState()

        var vtbl = IUnknownVtbl()
        vtbl.QueryInterface = fakeIdentityQueryInterface
        vtbl.AddRef = fakeIdentityAddRef
        vtbl.Release = fakeIdentityRelease

        var primary = FakeIdentityInterface()
        primary.lpVtbl = CPointer<IUnknownVtbl>(inout vtbl)
        var secondary = FakeIdentityInterface()
        secondary.lpVtbl = CPointer<IUnknownVtbl>(inout vtbl)

        let primaryPtr = CPointer<FakeIdentityInterface>(inout primary)
        let secondaryPtr = CPointer<FakeIdentityInterface>(inout secondary)
        fakeIdentityCanonicalPtr = CPointer<Unit>(primaryPtr)
        fakeIdentityRefCount = 0u32

        let left = ComHandle<FakeIdentityInterface>(primaryPtr, addRef: true)
        let right = ComHandle<FakeIdentityInterface>(secondaryPtr, addRef: true)

        try {
            require(
                left.asRaw().toUIntNative() != right.asRaw().toUIntNative(),
                "test setup should use different raw interface pointers"
            )
            require(left == right, "ComHandle equality should compare canonical IUnknown identity")
            require(fakeIdentityQueryCalls == 2u32, "ComHandle equality should query IID_IUnknown on both sides")
        } finally {
            right.close()
            left.close()
        }
    }

    @TestCase
    public func errorMessageReturnsExplicitEmptyString(): Unit {
        resetErrorInfoLifetimeState()

        var errorVtbl = IErrorInfoVtbl()
        errorVtbl.base__.QueryInterface = fakeErrorInfoQueryInterface
        errorVtbl.base__.AddRef = fakeErrorInfoAddRef
        errorVtbl.base__.Release = fakeErrorInfoRelease
        errorVtbl.GetDescription = fakeGetDescription

        var restrictedVtbl = IRestrictedErrorInfoVtbl()
        restrictedVtbl.base__.QueryInterface = fakeErrorInfoQueryInterface
        restrictedVtbl.base__.AddRef = fakeErrorInfoAddRef
        restrictedVtbl.base__.Release = fakeErrorInfoRelease
        restrictedVtbl.GetErrorDetails = fakeGetErrorDetails
        restrictedVtbl.GetReference = fakeGetReference

        var info = FakeErrorInfo()
        info.lpVtbl = CPointer<IErrorInfoVtbl>(inout errorVtbl)
        var restricted = FakeRestrictedErrorInfo()
        restricted.lpVtbl = CPointer<IRestrictedErrorInfoVtbl>(inout restrictedVtbl)

        fakeErrorInfoPrimaryPtr = CPointer<Unit>(CPointer<FakeErrorInfo>(inout info))
        fakeRestrictedInfoPtr = CPointer<Unit>(CPointer<FakeRestrictedErrorInfo>(inout restricted))

        let error = errorFromRawForTesting(E_FAIL, CPointer<IErrorInfo>(fakeErrorInfoPrimaryPtr))
        require(error.message() == "", "Error.message() should preserve an explicit empty COM message")
    }

    @TestCase
    public func errorFromHRESULTCapturesThreadErrorInfo(): Unit {
        let threadError = errorNewForTesting(E_FAIL, "thread HRESULT failure")
        threadError.intoThread()

        let captured = errorFromHRESULT(E_FAIL)
        require(captured.asPtr().isNotNull(), "errorFromHRESULT should keep thread IErrorInfo")
        require(captured.message() == "thread HRESULT failure", "errorFromHRESULT should recover thread error text")
    }

    @TestCase
    public func errorFromWin32CapturesThreadErrorInfo(): Unit {
        let code = 5u32
        let threadError = errorNewForTesting(HRESULT.fromWin32(code), "thread Win32 failure")
        threadError.intoThread()

        let captured = errorFromWin32(code)
        require(captured.asPtr().isNotNull(), "errorFromWin32 should keep thread IErrorInfo")
        require(captured.message() == "thread Win32 failure", "errorFromWin32 should recover thread error text")
    }

    @TestCase
    public func errorIntoThreadDoesNotLeakAnExtraReference(): Unit {
        resetErrorInfoLifetimeState()

        var errorVtbl = IErrorInfoVtbl()
        errorVtbl.base__.QueryInterface = fakeErrorInfoQueryInterface
        errorVtbl.base__.AddRef = fakeErrorInfoAddRef
        errorVtbl.base__.Release = fakeErrorInfoRelease
        errorVtbl.GetDescription = fakeGetDescription

        var info = FakeErrorInfo()
        info.lpVtbl = CPointer<IErrorInfoVtbl>(inout errorVtbl)

        fakeErrorInfoPrimaryPtr = CPointer<Unit>(CPointer<FakeErrorInfo>(inout info))
        fakeRestrictedInfoPtr = CPointer<Unit>()

        publishAndClearThreadError(CPointer<IErrorInfo>(fakeErrorInfoPrimaryPtr))

        require(
            fakeErrorInfoAddRefCalls == 2u32,
            "Error.intoThread should not add an extra COM reference before calling SetErrorInfo"
        )
    }

    @TestCase
    public func ntBitMessagesFallBackToSystemText(): Unit {
        let code = HRESULT(268435461i32) // FACILITY_NT_BIT | 5u32
        let expected = E_ACCESSDENIED.message()
        require(!expected.isEmpty(), "test setup requires a non-empty system fallback message")
        require(
            code.message() == expected,
            "FACILITY_NT_BIT HRESULTs should fall back to the system message table when ntdll formatting fails"
        )
    }
}

@When[test && slim_errors == "true"]
@Test
class WindowsResultSlimErrorTests {
    @TestCase
    public func newIgnoresCustomMessageWhenSlimErrorsEnabled(): Unit {
        require(slimErrorsEnabledForTesting(), "slim test should compile against the slim_errors branch")
        let error = errorNewForTesting(E_FAIL, "custom failure")
        require(error.asPtr().isNull(), "slim errors should not capture IErrorInfo")
        require(
            error.message() == E_FAIL.message(),
            "slim errors should fall back to HRESULT.message() instead of storing custom text"
        )
    }
}
