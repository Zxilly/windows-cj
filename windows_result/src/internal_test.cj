package windows_result

// Test fixtures (fake COM/IErrorInfo vtables, ref-count state, BSTR helpers)
// live in internal_support_test.cj.

@When[test && os == "Windows"]
import std.unittest.*

@When[test && os == "Windows"]
import std.unittest.testmacro.*

@When[test && os == "Windows"]
@Test
class WindowsResultInternalTests {
    @TestCase
    public func basicStringCloseIsIdempotent(): Unit {
        let value = BasicString("owned BSTR")
        try {
            require(!value.isClosed(), "BasicString should start open")
            require(value.asRaw().isNotNull(), "owned BasicString should expose its raw BSTR before close")
            require(value.toString() == "owned BSTR", "BasicString should decode before close")

            value.close()
            require(value.isClosed(), "BasicString should report closed after explicit close")
            require(value.asRaw().isNull(), "BasicString should hide its raw pointer after close")
            require(value.length() == 0, "BasicString length should be zero after close")

            value.close()
            require(value.isClosed(), "BasicString close should be idempotent")
            require(value.asRaw().isNull(), "BasicString pointer should stay null after repeated close")
        } finally {
            value.close()
        }
    }

    @TestCase
    public func heapStringCloseIsIdempotent(): Unit {
        var buffer = CPointer<UInt16>()
        let size = unsafe {
            FormatMessageW(
                FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                CPointer<Unit>(),
                ERROR_INVALID_DATA.value,
                0u32,
                CPointer<CPointer<UInt16>>(inout buffer),
                0u32,
                CPointer<Unit>()
            )
        }
        let value = HeapString.fromRaw(buffer)
        try {
            require(size != 0u32, "test setup should allocate a Win32 message buffer")
            require(!value.isClosed(), "HeapString should start open")
            require(value.asRaw().isNotNull(), "owned HeapString should expose its raw pointer before close")
            require(!value.decode(length: Int64(size)).isEmpty(), "HeapString should decode before close")

            value.close()
            require(value.isClosed(), "HeapString should report closed after explicit close")
            require(value.asRaw().isNull(), "HeapString should hide its raw pointer after close")
            require(value.toWideArray(length: Int64(size)).isEmpty(), "HeapString should be empty after close")

            value.close()
            require(value.isClosed(), "HeapString close should be idempotent")
            require(value.asRaw().isNull(), "HeapString pointer should stay null after repeated close")
        } finally {
            value.close()
        }
    }

    @TestCase
    public func comHandleCloseIsIdempotentAndReleasesOnce(): Unit {
        resetIdentityState()

        var vtbl = IUnknownVtbl()
        vtbl.QueryInterface = fakeIdentityQueryInterface
        vtbl.AddRef = fakeIdentityAddRef
        vtbl.Release = fakeIdentityRelease

        var primary = FakeIdentityInterface()
        primary.lpVtbl = CPointer<IUnknownVtbl>(inout vtbl)

        let primaryPtr = CPointer<FakeIdentityInterface>(inout primary)
        fakeIdentityCanonicalPtr = CPointer<Unit>(primaryPtr)
        fakeIdentityRefCount = 1u32

        let handle = ComHandle<FakeIdentityInterface>.fromAbiTake(primaryPtr)
        try {
            require(!handle.isClosed(), "ComHandle should start open")
            require(handle.asRaw().isNotNull(), "ComHandle should expose raw pointer before close")

            handle.close()
            require(handle.isClosed(), "ComHandle should report closed after close")
            require(handle.asRaw().isNull(), "ComHandle should clear raw pointer after close")
            require(fakeIdentityReleaseCalls == 1u32, "ComHandle.close should call COM Release once")
            require(fakeIdentityRefCount == 0u32, "ComHandle.close should release the owned COM reference")

            handle.close()
            require(handle.isClosed(), "ComHandle.close should be idempotent")
            require(handle.asRaw().isNull(), "ComHandle raw pointer should stay null after repeated close")
            require(fakeIdentityReleaseCalls == 1u32, "repeated ComHandle.close should not call COM Release again")
        } finally {
            handle.close()
        }
    }

    @TestCase
    public func comHandleReleaseIsIdempotentAndReleasesOnce(): Unit {
        resetIdentityState()

        var vtbl = IUnknownVtbl()
        vtbl.QueryInterface = fakeIdentityQueryInterface
        vtbl.AddRef = fakeIdentityAddRef
        vtbl.Release = fakeIdentityRelease

        var primary = FakeIdentityInterface()
        primary.lpVtbl = CPointer<IUnknownVtbl>(inout vtbl)

        let primaryPtr = CPointer<FakeIdentityInterface>(inout primary)
        fakeIdentityCanonicalPtr = CPointer<Unit>(primaryPtr)
        fakeIdentityRefCount = 1u32

        let handle = ComHandle<FakeIdentityInterface>.fromAbiTake(primaryPtr)
        try {
            let remaining = handle.release()
            require(remaining == 0u32, "ComHandle.release should return the COM Release result")
            require(handle.isClosed(), "ComHandle.release should close the handle")
            require(handle.asRaw().isNull(), "ComHandle.release should clear raw pointer")
            require(fakeIdentityReleaseCalls == 1u32, "ComHandle.release should call COM Release once")

            let repeated = handle.release()
            require(repeated == 0u32, "repeated ComHandle.release should return zero")
            require(fakeIdentityReleaseCalls == 1u32, "repeated ComHandle.release should not call COM Release again")
        } finally {
            handle.close()
        }
    }

    @TestCase
    public func comHandleFinalizerBodyReleasesOwnedComReference(): Unit {
        let source = readComSourceForTesting()
        let expectedLfBody = "~init() {\n        if (!closed) {\n            let released = raw\n            raw = CPointer<T>()\n            closed = true\n            let _ = comReleaseRaw(released)\n        }\n    }"
        let expectedCrLfBody = "~init() {\r\n        if (!closed) {\r\n            let released = raw\r\n            raw = CPointer<T>()\r\n            closed = true\r\n            let _ = comReleaseRaw(released)\r\n        }\r\n    }"

        require(
            source.contains(expectedLfBody) || source.contains(expectedCrLfBody),
            "ComHandle finalizer should release an owned COM reference exactly once"
        )
    }

    @TestCase
    public func comHandleEqualityUsesCanonicalIUnknownIdentity(): Unit {
        if (slimErrorsEnabledForTesting()) {
            return
        }
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
    public func failedComQueryInterfaceReleasesPartialOutput(): Unit {
        resetIdentityState()

        var vtbl = IUnknownVtbl()
        vtbl.QueryInterface = fakeIdentityFailingPartialQueryInterface
        vtbl.AddRef = fakeIdentityAddRef
        vtbl.Release = fakeIdentityRelease

        var primary = FakeIdentityInterface()
        primary.lpVtbl = CPointer<IUnknownVtbl>(inout vtbl)

        let primaryPtr = CPointer<FakeIdentityInterface>(inout primary)
        fakeIdentityCanonicalPtr = CPointer<Unit>(primaryPtr)
        fakeIdentityRefCount = 1u32

        let result = comQueryInterfaceRaw<FakeIdentityInterface, IUnknown>(primaryPtr, IID_IUnknown)

        match (result) {
            case Some(_) => throw Exception("failing QueryInterface should not return a partial raw pointer")
            case None => ()
        }
        require(fakeIdentityQueryCalls == 1u32, "test should call QueryInterface once")
        require(fakeIdentityAddRefCalls == 1u32, "fake QueryInterface should publish one partial reference")
        require(fakeIdentityReleaseCalls == 1u32, "failed partial QueryInterface output should be released")
        require(fakeIdentityRefCount == 1u32, "partial release should restore the original reference count")
    }

    @TestCase
    public func defaultErrorInfoVtablesClearFailedOutSlots(): Unit {
        var unknownVtbl = IUnknownVtbl()
        var queryIid = IID_IErrorInfo
        var queryResult = staleDefaultUnitPointerForTesting()

        let nullQueryHr = unsafe {
            HRESULT(unknownVtbl.QueryInterface(CPointer<Unit>(), CPointer<GUID>(inout queryIid), CPointer<CPointer<Unit>>()))
        }
        require(nullQueryHr == E_POINTER, "default IUnknownVtbl.QueryInterface should reject null result slots")

        let unsupportedQueryHr = unsafe {
            HRESULT(unknownVtbl.QueryInterface(CPointer<Unit>(), CPointer<GUID>(inout queryIid), CPointer<CPointer<Unit>>(inout queryResult)))
        }
        require(unsupportedQueryHr == E_NOINTERFACE, "default IUnknownVtbl.QueryInterface should return E_NOINTERFACE")
        require(queryResult.isNull(), "default IUnknownVtbl.QueryInterface should clear stale result slots")

        var errorInfoVtbl = IErrorInfoVtbl()
        var guidResult = IID_IErrorInfo
        let guidHr = unsafe { HRESULT(errorInfoVtbl.GetGUID(CPointer<Unit>(), CPointer<GUID>(inout guidResult))) }
        require(guidHr == E_NOTIMPL, "default IErrorInfoVtbl.GetGUID should return E_NOTIMPL")
        require(guidResult == GUID.zeroed(), "default IErrorInfoVtbl.GetGUID should clear stale GUID slots")

        var sourceResult = staleDefaultBstrPointerForTesting()
        let sourceHr = unsafe {
            HRESULT(errorInfoVtbl.GetSource(CPointer<Unit>(), CPointer<CPointer<UInt16>>(inout sourceResult)))
        }
        require(sourceHr == E_NOTIMPL, "default IErrorInfoVtbl.GetSource should return E_NOTIMPL")
        require(sourceResult.isNull(), "default IErrorInfoVtbl.GetSource should clear stale BSTR slots")

        var descriptionResult = staleDefaultBstrPointerForTesting()
        let descriptionHr = unsafe {
            HRESULT(errorInfoVtbl.GetDescription(CPointer<Unit>(), CPointer<CPointer<UInt16>>(inout descriptionResult)))
        }
        require(descriptionHr == E_NOTIMPL, "default IErrorInfoVtbl.GetDescription should return E_NOTIMPL")
        require(descriptionResult.isNull(), "default IErrorInfoVtbl.GetDescription should clear stale BSTR slots")

        var helpFileResult = staleDefaultBstrPointerForTesting()
        let helpFileHr = unsafe {
            HRESULT(errorInfoVtbl.GetHelpFile(CPointer<Unit>(), CPointer<CPointer<UInt16>>(inout helpFileResult)))
        }
        require(helpFileHr == E_NOTIMPL, "default IErrorInfoVtbl.GetHelpFile should return E_NOTIMPL")
        require(helpFileResult.isNull(), "default IErrorInfoVtbl.GetHelpFile should clear stale BSTR slots")

        var helpContextResult = 123u32
        let helpContextHr = unsafe {
            HRESULT(errorInfoVtbl.GetHelpContext(CPointer<Unit>(), CPointer<UInt32>(inout helpContextResult)))
        }
        require(helpContextHr == E_NOTIMPL, "default IErrorInfoVtbl.GetHelpContext should return E_NOTIMPL")
        require(helpContextResult == 0u32, "default IErrorInfoVtbl.GetHelpContext should clear stale context slots")

        var restrictedVtbl = IRestrictedErrorInfoVtbl()
        var fallbackResult = staleDefaultBstrPointerForTesting()
        var errorCodeResult = E_FAIL.value
        var restrictedDescriptionResult = staleDefaultBstrPointerForTesting()
        var referenceResult = staleDefaultBstrPointerForTesting()
        let detailsHr = unsafe {
            HRESULT(restrictedVtbl.GetErrorDetails(
                CPointer<Unit>(),
                CPointer<CPointer<UInt16>>(inout fallbackResult),
                CPointer<Int32>(inout errorCodeResult),
                CPointer<CPointer<UInt16>>(inout restrictedDescriptionResult),
                CPointer<CPointer<UInt16>>(inout referenceResult)
            ))
        }
        require(detailsHr == E_NOTIMPL, "default IRestrictedErrorInfoVtbl.GetErrorDetails should return E_NOTIMPL")
        require(fallbackResult.isNull(), "default IRestrictedErrorInfoVtbl.GetErrorDetails should clear fallback")
        require(errorCodeResult == 0i32, "default IRestrictedErrorInfoVtbl.GetErrorDetails should clear error code")
        require(restrictedDescriptionResult.isNull(), "default IRestrictedErrorInfoVtbl.GetErrorDetails should clear description")
        require(referenceResult.isNull(), "default IRestrictedErrorInfoVtbl.GetErrorDetails should clear reference")

        var restrictedReferenceResult = staleDefaultBstrPointerForTesting()
        let referenceHr = unsafe {
            HRESULT(restrictedVtbl.GetReference(CPointer<Unit>(), CPointer<CPointer<UInt16>>(inout restrictedReferenceResult)))
        }
        require(referenceHr == E_NOTIMPL, "default IRestrictedErrorInfoVtbl.GetReference should return E_NOTIMPL")
        require(restrictedReferenceResult.isNull(), "default IRestrictedErrorInfoVtbl.GetReference should clear reference")
    }

    @TestCase
    public func errorMessageReturnsExplicitEmptyString(): Unit {
        if (slimErrorsEnabledForTesting()) {
            return
        }
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
    public func failedErrorDescriptionReleasesPartialBstr(): Unit {
        if (slimErrorsEnabledForTesting()) {
            return
        }
        resetErrorInfoLifetimeState()

        var errorVtbl = IErrorInfoVtbl()
        errorVtbl.base__.QueryInterface = fakeErrorInfoQueryInterface
        errorVtbl.base__.AddRef = fakeErrorInfoAddRef
        errorVtbl.base__.Release = fakeErrorInfoRelease
        errorVtbl.GetDescription = fakeGetDescriptionFailingPartial

        var info = FakeErrorInfo()
        info.lpVtbl = CPointer<IErrorInfoVtbl>(inout errorVtbl)
        let before = debugObservedSysFreeStringCount()

        let result = captureDescription(CPointer<IErrorInfo>(CPointer<FakeErrorInfo>(inout info)))

        match (result) {
            case Some(_) => throw Exception("failing GetDescription should not return a partial message")
            case None => ()
        }
        require(
            debugObservedSysFreeStringCount() - before == 1i32,
            "failed GetDescription partial BSTR should be freed once"
        )
    }

    @TestCase
    public func failedRestrictedErrorDetailsReleasesPartialBstrs(): Unit {
        if (slimErrorsEnabledForTesting()) {
            return
        }
        resetErrorInfoLifetimeState()

        var restrictedVtbl = IRestrictedErrorInfoVtbl()
        restrictedVtbl.base__.QueryInterface = fakeErrorInfoQueryInterface
        restrictedVtbl.base__.AddRef = fakeErrorInfoAddRef
        restrictedVtbl.base__.Release = fakeErrorInfoRelease
        restrictedVtbl.GetErrorDetails = fakeGetErrorDetailsFailingPartial
        restrictedVtbl.GetReference = fakeGetReference

        var restricted = FakeRestrictedErrorInfo()
        restricted.lpVtbl = CPointer<IRestrictedErrorInfoVtbl>(inout restrictedVtbl)
        let before = debugObservedSysFreeStringCount()

        let result = captureRestrictedDescription(CPointer<IRestrictedErrorInfo>(CPointer<FakeRestrictedErrorInfo>(inout restricted)))

        match (result) {
            case Some(_) => throw Exception("failing GetErrorDetails should not return a partial message")
            case None => ()
        }
        require(
            debugObservedSysFreeStringCount() - before == 3i32,
            "failed GetErrorDetails partial BSTR outputs should be freed once each"
        )
    }

    @TestCase
    public func errorFromHRESULTCapturesThreadErrorInfo(): Unit {
        if (slimErrorsEnabledForTesting()) {
            return
        }
        let threadError = errorNewForTesting(E_FAIL, "thread HRESULT failure")
        threadError.intoThread()

        let captured = errorFromHRESULT(E_FAIL)
        require(captured.asPtr().isNotNull(), "errorFromHRESULT should keep thread IErrorInfo")
        require(captured.message() == "thread HRESULT failure", "errorFromHRESULT should recover thread error text")
    }

    @TestCase
    public func errorFromWin32CapturesThreadErrorInfo(): Unit {
        if (slimErrorsEnabledForTesting()) {
            return
        }
        let code = 5u32
        let threadError = errorNewForTesting(HRESULT.fromWin32(code), "thread Win32 failure")
        threadError.intoThread()

        let captured = errorFromWin32(code)
        require(captured.asPtr().isNotNull(), "errorFromWin32 should keep thread IErrorInfo")
        require(captured.message() == "thread Win32 failure", "errorFromWin32 should recover thread error text")
    }

    @TestCase
    public func errorIntoThreadDoesNotLeakAnExtraReference(): Unit {
        if (slimErrorsEnabledForTesting()) {
            return
        }
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

@When[test && os == "Windows"]
@Test
class WindowsResultSlimErrorTests {
    @TestCase
    public func newIgnoresCustomMessageWhenSlimErrorsEnabled(): Unit {
        if (!slimErrorsEnabledForTesting()) {
            return
        }
        let error = errorNewForTesting(E_FAIL, "custom failure")
        require(error.asPtr().isNull(), "slim errors should not capture IErrorInfo")
        require(
            error.message() == E_FAIL.message(),
            "slim errors should fall back to HRESULT.message() instead of storing custom text"
        )
    }
}
