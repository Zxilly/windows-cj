package windows_foundation

import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOTIMPL, EventRegistrationTokenAbi}
import windows_interface.GUID
import windows_interface as windows_interface

func assertFoundationDefaultComOut1Cleared(
    slot: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(3u8) }
    try {
        var raw = CPointer<Unit>(sentinel)
        @Expect(unsafe { slot(CPointer<Unit>(), CPointer<CPointer<Unit>>(inout raw)) }, E_NOTIMPL.value)
        @Expect(raw.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

func assertFoundationDefaultComOut2Cleared(
    slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(4u8) }
    try {
        var raw = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { slot(CPointer<Unit>(), CPointer<Unit>(), CPointer<CPointer<Unit>>(inout raw)) },
            E_NOTIMPL.value
        )
        @Expect(raw.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

func assertFoundationDefaultComOut3Cleared(
    slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(5u8) }
    try {
        var raw = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { slot(CPointer<Unit>(), CPointer<Unit>(), CPointer<Unit>(), CPointer<CPointer<Unit>>(inout raw)) },
            E_NOTIMPL.value
        )
        @Expect(raw.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

func assertFoundationDefaultComOutWithUInt32Cleared(
    slot: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32>
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(6u8) }
    try {
        var raw = CPointer<Unit>(sentinel)
        @Expect(unsafe { slot(CPointer<Unit>(), 1u32, CPointer<CPointer<Unit>>(inout raw)) }, E_NOTIMPL.value)
        @Expect(raw.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

func assertFoundationDefaultUInt32OutCleared(slot: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32>): Unit {
    var value = 37u32
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<UInt32>(inout value)) }, E_NOTIMPL.value)
    @Expect(value, 0u32)
}

func assertFoundationDefaultInt32OutCleared(slot: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32>): Unit {
    var value = 37i32
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<Int32>(inout value)) }, E_NOTIMPL.value)
    @Expect(value, 0i32)
}

func assertFoundationDefaultBoolOut1Cleared(slot: CFunc<(CPointer<Unit>, CPointer<Bool>) -> Int32>): Unit {
    var value = true
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<Bool>(inout value)) }, E_NOTIMPL.value)
    @Expect(value, false)
}

func assertFoundationDefaultBoolOut2Cleared(
    slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Bool>) -> Int32>
): Unit {
    var value = true
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<Unit>(), CPointer<Bool>(inout value)) }, E_NOTIMPL.value)
    @Expect(value, false)
}

func assertFoundationDefaultGuidOutCleared(slot: CFunc<(CPointer<Unit>, CPointer<GUID>) -> Int32>): Unit {
    var value = GUID(1u32, 2u16, 3u16, 4u8, 5u8, 6u8, 7u8, 8u8, 9u8, 10u8, 11u8)
    @Expect(unsafe { slot(CPointer<Unit>(), CPointer<GUID>(inout value)) }, E_NOTIMPL.value)
    @Expect(value == GUID(), true)
}

func assertFoundationDefaultGuidEqualsOutCleared(
    slot: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<GUID>, CPointer<Bool>) -> Int32>
): Unit {
    var value = true
    @Expect(
        unsafe { slot(CPointer<Unit>(), CPointer<GUID>(), CPointer<GUID>(), CPointer<Bool>(inout value)) },
        E_NOTIMPL.value
    )
    @Expect(value, false)
}

func assertFoundationDefaultTokenOutCleared(
    slot: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<EventRegistrationTokenAbi>) -> Int32>
): Unit {
    var token = EventRegistrationTokenAbi()
    token.Value = 99i64
    @Expect(
        unsafe { slot(CPointer<Unit>(), CPointer<Unit>(), CPointer<EventRegistrationTokenAbi>(inout token)) },
        E_NOTIMPL.value
    )
    @Expect(token.Value, 0i64)
}

func assertFoundationDefaultUnitArrayOutCleared(
    slot: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<Unit>>) -> Int32>
): Unit {
    let sentinel = unsafe { windows_interface.allocateNativeValue<UInt8>(7u8) }
    try {
        var size = 17u32
        var raw = CPointer<Unit>(sentinel)
        @Expect(
            unsafe { slot(CPointer<Unit>(), CPointer<UInt32>(inout size), CPointer<CPointer<Unit>>(inout raw)) },
            E_NOTIMPL.value
        )
        @Expect(size, 0u32)
        @Expect(raw.isNull(), true)
    } finally {
        unsafe { windows_interface.freeNativeValue<UInt8>(sentinel) }
    }
}

@Test
func testFoundationDefaultScalarFactoryAndReferenceVtablesClearOutSlotsBeforeNotImpl() {
    var activation = IGetActivationFactoryVtbl()
    assertFoundationDefaultComOut2Cleared(activation.GetActivationFactory)

    var guid = IGuidHelperStaticsVtbl()
    assertFoundationDefaultGuidOutCleared(guid.CreateNewGuid)
    assertFoundationDefaultGuidOutCleared(guid.Empty)
    assertFoundationDefaultGuidEqualsOutCleared(guid.Equals)

    var stringable = IStringableVtbl()
    assertFoundationDefaultComOut1Cleared(stringable.ToString)

    var memoryReference = IMemoryBufferReferenceVtbl()
    assertFoundationDefaultUInt32OutCleared(memoryReference.Capacity)
    assertFoundationDefaultTokenOutCleared(memoryReference.Closed)

    var reference = IReferenceVtbl()
    assertFoundationDefaultComOut1Cleared(reference.Value)

    var referenceArray = IReferenceArrayVtbl()
    assertFoundationDefaultUnitArrayOutCleared(referenceArray.Value)

    var memoryBuffer = IMemoryBufferVtbl()
    assertFoundationDefaultComOut1Cleared(memoryBuffer.CreateReference)

    var deferralFactory = IDeferralFactoryVtbl()
    assertFoundationDefaultComOut2Cleared(deferralFactory.Create)

    var memoryFactory = IMemoryBufferFactoryVtbl()
    assertFoundationDefaultComOutWithUInt32Cleared(memoryFactory.Create)
}

@Test
func testFoundationDefaultUriAndDecoderVtablesClearOutSlotsBeforeNotImpl() {
    var uriEscape = IUriEscapeStaticsVtbl()
    assertFoundationDefaultComOut2Cleared(uriEscape.UnescapeComponent)
    assertFoundationDefaultComOut2Cleared(uriEscape.EscapeComponent)

    var canonical = IUriRuntimeClassWithAbsoluteCanonicalUriVtbl()
    assertFoundationDefaultComOut1Cleared(canonical.AbsoluteCanonicalUri)
    assertFoundationDefaultComOut1Cleared(canonical.DisplayIri)

    var decoderEntry = IWwwFormUrlDecoderEntryVtbl()
    assertFoundationDefaultComOut1Cleared(decoderEntry.Name)
    assertFoundationDefaultComOut1Cleared(decoderEntry.Value)

    var decoder = IWwwFormUrlDecoderRuntimeClassVtbl()
    assertFoundationDefaultComOut2Cleared(decoder.GetFirstValueByName)

    var uri = IUriRuntimeClassVtbl()
    assertFoundationDefaultComOut1Cleared(uri.AbsoluteUri)
    assertFoundationDefaultComOut1Cleared(uri.DisplayUri)
    assertFoundationDefaultComOut1Cleared(uri.QueryParsed)
    assertFoundationDefaultInt32OutCleared(uri.Port)
    assertFoundationDefaultBoolOut1Cleared(uri.Suspicious)
    assertFoundationDefaultBoolOut2Cleared(uri.Equals)
    assertFoundationDefaultComOut2Cleared(uri.CombineUri)

    var uriFactory = IUriRuntimeClassFactoryVtbl()
    assertFoundationDefaultComOut2Cleared(uriFactory.CreateUri)
    assertFoundationDefaultComOut3Cleared(uriFactory.CreateWithRelativeUri)

    var decoderFactory = IWwwFormUrlDecoderRuntimeClassFactoryVtbl()
    assertFoundationDefaultComOut2Cleared(decoderFactory.CreateWwwFormUrlDecoder)
}
