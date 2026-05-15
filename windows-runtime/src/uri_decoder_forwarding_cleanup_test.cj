package windows_runtime

import std.sync.AtomicInt64
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{E_NOINTERFACE, E_POINTER, S_OK}
import windows_core as windows_core
import windows_interface.{GUID, IInspectable, IUnknown}

let uriDecoderForwardingQueryCalls = AtomicInt64(0)
let uriDecoderForwardingAddRefCalls = AtomicInt64(0)
let uriDecoderForwardingReleaseCalls = AtomicInt64(0)
let uriDecoderForwardingToStringCalls = AtomicInt64(0)
let uriDecoderForwardingAbsoluteUriCalls = AtomicInt64(0)
let uriDecoderForwardingSizeCalls = AtomicInt64(0)
let uriDecoderForwardingFirstCalls = AtomicInt64(0)
let uriDecoderForwardingEntryNameCalls = AtomicInt64(0)
let uriDecoderForwardingGetFirstValueCalls = AtomicInt64(0)

@C
func uriDecoderForwardingQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (iid.isNull() || result.isNull()) {
        return E_POINTER.value
    }
    let target = unsafe { iid.read() }
    if (
        target == IStringable.iid() ||
        target == IUriRuntimeClass.iid() ||
        target == IWwwFormUrlDecoderEntry.iid() ||
        target == IWwwFormUrlDecoderRuntimeClass.iid() ||
        target == IIterable<IWwwFormUrlDecoderEntry>.iid() ||
        target == IVectorView<IWwwFormUrlDecoderEntry>.iid() ||
        target == IInspectable.iid() ||
        target == IUnknown.iid()
    ) {
        uriDecoderForwardingQueryCalls.fetchAdd(1)
        unsafe { uriDecoderForwardingAddRefThunk(instanceRaw) }
        unsafe { result.write(instanceRaw) }
        return S_OK.value
    }
    unsafe { result.write(CPointer<Unit>()) }
    E_NOINTERFACE.value
}

@C
func uriDecoderForwardingAddRefThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = uriDecoderForwardingAddRefCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func uriDecoderForwardingReleaseThunk(_: CPointer<Unit>): UInt32 {
    let oldCount = uriDecoderForwardingReleaseCalls.fetchAdd(1)
    UInt32(oldCount + 1)
}

@C
func uriDecoderForwardingToStringThunk(
    _: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    let text = windows_core.HString("uri-string")
    let handle = text.toSystemHandleCopy()
    text.close()
    unsafe { result.write(handle) }
    uriDecoderForwardingToStringCalls.fetchAdd(1)
    S_OK.value
}

@C
func uriDecoderForwardingAbsoluteUriThunk(
    _: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    let text = windows_core.HString("absolute-uri")
    let handle = text.toSystemHandleCopy()
    text.close()
    unsafe { result.write(handle) }
    uriDecoderForwardingAbsoluteUriCalls.fetchAdd(1)
    S_OK.value
}

@C
func uriDecoderForwardingSizeThunk(
    _: CPointer<Unit>,
    result: CPointer<UInt32>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    unsafe { result.write(4u32) }
    uriDecoderForwardingSizeCalls.fetchAdd(1)
    S_OK.value
}

@C
func uriDecoderForwardingEntryNameThunk(
    _: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    let text = windows_core.HString("entry-name")
    let handle = text.toSystemHandleCopy()
    text.close()
    unsafe { result.write(handle) }
    uriDecoderForwardingEntryNameCalls.fetchAdd(1)
    S_OK.value
}

@C
func uriDecoderForwardingGetFirstValueByNameThunk(
    _: CPointer<Unit>,
    _: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    let text = windows_core.HString("first-value")
    let handle = text.toSystemHandleCopy()
    text.close()
    unsafe { result.write(handle) }
    uriDecoderForwardingGetFirstValueCalls.fetchAdd(1)
    S_OK.value
}

@C
func uriDecoderForwardingFirstThunk(
    instanceRaw: CPointer<Unit>,
    result: CPointer<CPointer<Unit>>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    uriDecoderForwardingFirstCalls.fetchAdd(1)
    unsafe { uriDecoderForwardingAddRefThunk(instanceRaw) }
    unsafe { result.write(instanceRaw) }
    S_OK.value
}

func uriDecoderForwardingStringableVtbl(): IStringableVtbl {
    var vtbl = IStringableVtbl()
    vtbl.base_.base_.QueryInterface = uriDecoderForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = uriDecoderForwardingAddRefThunk
    vtbl.base_.base_.Release = uriDecoderForwardingReleaseThunk
    vtbl.ToString = uriDecoderForwardingToStringThunk
    vtbl
}

func uriDecoderForwardingUriRuntimeVtbl(): IUriRuntimeClassVtbl {
    var vtbl = IUriRuntimeClassVtbl()
    vtbl.base_.base_.QueryInterface = uriDecoderForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = uriDecoderForwardingAddRefThunk
    vtbl.base_.base_.Release = uriDecoderForwardingReleaseThunk
    vtbl.AbsoluteUri = uriDecoderForwardingAbsoluteUriThunk
    vtbl
}

func uriDecoderForwardingEntryVtbl(): IWwwFormUrlDecoderEntryVtbl {
    var vtbl = IWwwFormUrlDecoderEntryVtbl()
    vtbl.base_.base_.QueryInterface = uriDecoderForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = uriDecoderForwardingAddRefThunk
    vtbl.base_.base_.Release = uriDecoderForwardingReleaseThunk
    vtbl.Name = uriDecoderForwardingEntryNameThunk
    vtbl
}

func uriDecoderForwardingDecoderRuntimeVtbl(): IWwwFormUrlDecoderRuntimeClassVtbl {
    var vtbl = IWwwFormUrlDecoderRuntimeClassVtbl()
    vtbl.base_.base_.QueryInterface = uriDecoderForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = uriDecoderForwardingAddRefThunk
    vtbl.base_.base_.Release = uriDecoderForwardingReleaseThunk
    vtbl.GetFirstValueByName = uriDecoderForwardingGetFirstValueByNameThunk
    vtbl
}

func uriDecoderForwardingVectorViewVtbl(): IVectorViewVtbl {
    var vtbl = IVectorViewVtbl()
    vtbl.base_.base_.QueryInterface = uriDecoderForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = uriDecoderForwardingAddRefThunk
    vtbl.base_.base_.Release = uriDecoderForwardingReleaseThunk
    vtbl.Size = uriDecoderForwardingSizeThunk
    vtbl
}

func uriDecoderForwardingIterableVtbl(): IIterableVtbl {
    var vtbl = IIterableVtbl()
    vtbl.base_.base_.QueryInterface = uriDecoderForwardingQueryInterfaceThunk
    vtbl.base_.base_.AddRef = uriDecoderForwardingAddRefThunk
    vtbl.base_.base_.Release = uriDecoderForwardingReleaseThunk
    vtbl.First = uriDecoderForwardingFirstThunk
    vtbl
}

func resetUriDecoderForwardingCounters(): Unit {
    uriDecoderForwardingQueryCalls.store(0)
    uriDecoderForwardingAddRefCalls.store(0)
    uriDecoderForwardingReleaseCalls.store(0)
    uriDecoderForwardingToStringCalls.store(0)
    uriDecoderForwardingAbsoluteUriCalls.store(0)
    uriDecoderForwardingSizeCalls.store(0)
    uriDecoderForwardingFirstCalls.store(0)
    uriDecoderForwardingEntryNameCalls.store(0)
    uriDecoderForwardingGetFirstValueCalls.store(0)
}

func withUriStringableForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IStringableVtbl>(1, { _ => uriDecoderForwardingStringableVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IStringableVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

func withUriRuntimeForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IUriRuntimeClassVtbl>(1, { _ => uriDecoderForwardingUriRuntimeVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IUriRuntimeClassVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

func withDecoderEntryForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IWwwFormUrlDecoderEntryVtbl>(1, { _ => uriDecoderForwardingEntryVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IWwwFormUrlDecoderEntryVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

func withDecoderRuntimeForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IWwwFormUrlDecoderRuntimeClassVtbl>(1, { _ => uriDecoderForwardingDecoderRuntimeVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IWwwFormUrlDecoderRuntimeClassVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

func withDecoderVectorForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IVectorViewVtbl>(1, { _ => uriDecoderForwardingVectorViewVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IVectorViewVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

func withDecoderIterableForwardingRaw(action: (CPointer<Unit>) -> Unit): Unit {
    let vtblHandle = unsafe { acquireArrayRawData(Array<IIterableVtbl>(1, { _ => uriDecoderForwardingIterableVtbl() })) }
    let objectHandle = unsafe { acquireArrayRawData(Array<CPointer<IIterableVtbl>>(1, { _ => vtblHandle.pointer })) }
    let raw = CPointer<Unit>(objectHandle.pointer)
    try {
        action(raw)
    } finally {
        unsafe {
            releaseArrayRawData(objectHandle)
            releaseArrayRawData(vtblHandle)
        }
    }
}

@Test
func testUriRuntimeAbsoluteUriReleasesTemporaryDefaultInterface() {
    resetUriDecoderForwardingCounters()
    withUriRuntimeForwardingRaw({ raw: CPointer<Unit> =>
        let uri = Uri.viewOf(raw)

        let value = unsafe { uri.AbsoluteUri() }

        @Expect(value.toString(), "absolute-uri")
        @Expect(uriDecoderForwardingAbsoluteUriCalls.load(), 1)
        @Expect(uriDecoderForwardingQueryCalls.load(), 1)
        @Expect(uriDecoderForwardingAddRefCalls.load(), 1)
        @Expect(uriDecoderForwardingReleaseCalls.load(), 1)
        value.close()
    })
}

@Test
func testUriToStringReleasesTemporaryIStringable() {
    resetUriDecoderForwardingCounters()
    withUriStringableForwardingRaw({ raw: CPointer<Unit> =>
        let uri = Uri.viewOf(raw)

        let value = unsafe { uri.ToString() }

        @Expect(value.toString(), "uri-string")
        @Expect(uriDecoderForwardingToStringCalls.load(), 1)
        @Expect(uriDecoderForwardingQueryCalls.load(), 1)
        @Expect(uriDecoderForwardingAddRefCalls.load(), 1)
        @Expect(uriDecoderForwardingReleaseCalls.load(), 1)
        value.close()
    })
}

@Test
func testWwwFormUrlDecoderEntryNameReleasesTemporaryDefaultInterface() {
    resetUriDecoderForwardingCounters()
    withDecoderEntryForwardingRaw({ raw: CPointer<Unit> =>
        let entry = WwwFormUrlDecoderEntry.viewOf(raw)

        let value = unsafe { entry.Name() }

        @Expect(value.toString(), "entry-name")
        @Expect(uriDecoderForwardingEntryNameCalls.load(), 1)
        @Expect(uriDecoderForwardingQueryCalls.load(), 1)
        @Expect(uriDecoderForwardingAddRefCalls.load(), 1)
        @Expect(uriDecoderForwardingReleaseCalls.load(), 1)
        value.close()
    })
}

@Test
func testWwwFormUrlDecoderGetFirstValueReleasesTemporaryDefaultInterface() {
    resetUriDecoderForwardingCounters()
    withDecoderRuntimeForwardingRaw({ raw: CPointer<Unit> =>
        let decoder = WwwFormUrlDecoder.viewOf(raw)
        let name = windows_core.HString("name")

        let value = unsafe { decoder.GetFirstValueByName(name) }

        @Expect(value.toString(), "first-value")
        @Expect(uriDecoderForwardingGetFirstValueCalls.load(), 1)
        @Expect(uriDecoderForwardingQueryCalls.load(), 1)
        @Expect(uriDecoderForwardingAddRefCalls.load(), 1)
        @Expect(uriDecoderForwardingReleaseCalls.load(), 1)
        value.close()
        name.close()
    })
}

@Test
func testWwwFormUrlDecoderSizeReleasesTemporaryVectorView() {
    resetUriDecoderForwardingCounters()
    withDecoderVectorForwardingRaw({ raw: CPointer<Unit> =>
        let decoder = WwwFormUrlDecoder.viewOf(raw)

        let value = unsafe { decoder.Size() }

        @Expect(value, 4u32)
        @Expect(uriDecoderForwardingSizeCalls.load(), 1)
        @Expect(uriDecoderForwardingQueryCalls.load(), 1)
        @Expect(uriDecoderForwardingAddRefCalls.load(), 1)
        @Expect(uriDecoderForwardingReleaseCalls.load(), 1)
    })
}

@Test
func testWwwFormUrlDecoderFirstReleasesTemporaryIterable() {
    resetUriDecoderForwardingCounters()
    withDecoderIterableForwardingRaw({ raw: CPointer<Unit> =>
        let decoder = WwwFormUrlDecoder.viewOf(raw)

        let iterator = unsafe { decoder.First() }
        iterator.close()

        @Expect(uriDecoderForwardingFirstCalls.load(), 1)
        @Expect(uriDecoderForwardingQueryCalls.load(), 1)
        @Expect(uriDecoderForwardingAddRefCalls.load(), 2)
        @Expect(uriDecoderForwardingReleaseCalls.load(), 2)
    })
}

@Test
func testIWwwFormUrlDecoderRuntimeClassIteratorReleasesTemporaryIterable() {
    resetUriDecoderForwardingCounters()
    withDecoderIterableForwardingRaw({ raw: CPointer<Unit> =>
        let decoder = IWwwFormUrlDecoderRuntimeClass.viewOf(raw)

        let _ = decoder.intoIterator()

        @Expect(uriDecoderForwardingFirstCalls.load(), 1)
        @Expect(uriDecoderForwardingQueryCalls.load(), 1)
        @Expect(uriDecoderForwardingAddRefCalls.load(), 2)
        @Expect(uriDecoderForwardingReleaseCalls.load(), 1)
    })
}
