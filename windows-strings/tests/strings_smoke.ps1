$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$stringsPath = ($packageRoot -replace '\\', '/')
$workspaceRoot = Join-Path $env:TEMP ("windows-strings-smoke-" + [guid]::NewGuid().ToString())
$runnerRoot = Join-Path $workspaceRoot "runner"
$srcRoot = Join-Path $runnerRoot "src"

if (Test-Path $workspaceRoot) {
    Remove-Item -Recurse -Force $workspaceRoot
}
New-Item -ItemType Directory -Force $srcRoot | Out-Null

@'
[package]
  name = "windows_strings_smoke"
  version = "0.1.0"
  description = "Smoke test for windows_strings"
  output-type = "executable"
  cjc-version = "1.1.0"

[dependencies]
  windows_strings = { path = "$stringsPath" }
'@ | Set-Content -NoNewline (Join-Path $runnerRoot "cjpm.toml")

@'
package windows_strings_smoke

import windows_strings.*

public class SmokeFailure <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

func fail(msg: String): Unit {
    throw SmokeFailure(msg)
}

func expect(cond: Bool, msg: String): Unit {
    if (!cond) {
        fail(msg)
    }
}

func expectWideUnits(actual: Array<UInt16>, expected: Array<UInt16>, msg: String): Unit {
    if (actual.size != expected.size) {
        fail("${msg}: size ${actual.size} != ${expected.size}")
    }
    var i: Int64 = 0
    while (i < actual.size) {
        if (actual[i] != expected[i]) {
            fail("${msg}: mismatch at ${i}, ${actual[i]} != ${expected[i]}")
        }
        i += 1
    }
}

func expectAnsiUnits(actual: Array<UInt8>, expected: Array<UInt8>, msg: String): Unit {
    if (actual.size != expected.size) {
        fail("${msg}: size ${actual.size} != ${expected.size}")
    }
    var i: Int64 = 0
    while (i < actual.size) {
        if (actual[i] != expected[i]) {
            fail("${msg}: mismatch at ${i}, ${actual[i]} != ${expected[i]}")
        }
        i += 1
    }
}

foreign {
    @FastNative
    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>
    func LoadLibraryW(lpLibFileName: CPointer<UInt16>): CPointer<Unit>
}

func expectString(actual: String, expected: String, msg: String): Unit {
    expect(actual == expected, "${msg}: `${actual}` != `${expected}`")
}

func expectSomeString(actual: Option<String>, expected: String, msg: String): Unit {
    match (actual) {
        case Some(value) => expectString(value, expected, msg)
        case None => fail("${msg}: expected Some, got None")
    }
}

func expectNoneString(actual: Option<String>, msg: String): Unit {
    if (actual.isSome()) {
        fail("${msg}: expected None")
    }
}

func requireHashable<T>(value: T): Int64 where T <: Hashable {
    value.hashCode()
}

func requireComparable<T>(left: T, right: T): Ordering where T <: Comparable<T> {
    left.compare(right)
}

func loadLibrary(name: String): CPointer<Unit> {
    let wide = CWideString(name)
    try {
        let handle = wide.withPtr { ptr: CPointer<UInt16> =>
            unsafe { LoadLibraryW(ptr) }
        }
        expect(!handle.isNull(), "LoadLibraryW failed for ${name}")
        handle
    } finally {
        wide.close()
    }
}

func getProcAddress(module: CPointer<Unit>, name: Array<UInt8>): CPointer<Unit> {
    unsafe {
        let handle = acquireArrayRawData(name)
        try {
            let proc = GetProcAddress(module, handle.pointer)
            expect(!proc.isNull(), "GetProcAddress failed")
            proc
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func oleaut32Module(): CPointer<Unit> {
    loadLibrary("oleaut32.dll")
}

func combaseModule(): CPointer<Unit> {
    loadLibrary("combase.dll")
}

func sysAllocStringLenRaw(data: Array<UInt16>): CPointer<UInt16> {
    let module = oleaut32Module()
    let proc = getProcAddress(module, [
        0x53u8, 0x79u8, 0x73u8, 0x41u8, 0x6Cu8, 0x6Cu8, 0x6Fu8, 0x63u8,
        0x53u8, 0x74u8, 0x72u8, 0x69u8, 0x6Eu8, 0x67u8, 0x4Cu8, 0x65u8,
        0x6Eu8, 0x00u8
    ])
    let alloc = CFunc<(CPointer<UInt16>, UInt32) -> CPointer<UInt16>>(proc)
    if (data.isEmpty()) {
        unsafe {
            return alloc(CPointer<UInt16>(), 0u32)
        }
    }
    unsafe {
        let handle = acquireArrayRawData(data)
        try {
            alloc(handle.pointer, UInt32(data.size))
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func sysFreeStringRaw(value: CPointer<UInt16>): Unit {
    let module = oleaut32Module()
    let proc = getProcAddress(module, [
        0x53u8, 0x79u8, 0x73u8, 0x46u8, 0x72u8, 0x65u8, 0x65u8, 0x53u8,
        0x74u8, 0x72u8, 0x69u8, 0x6Eu8, 0x67u8, 0x00u8
    ])
    let freeFn = CFunc<(CPointer<UInt16>) -> Unit>(proc)
    unsafe {
        freeFn(value)
    }
}

func sysStringLenRaw(value: CPointer<UInt16>): UInt32 {
    let module = oleaut32Module()
    let proc = getProcAddress(module, [
        0x53u8, 0x79u8, 0x73u8, 0x53u8, 0x74u8, 0x72u8, 0x69u8, 0x6Eu8,
        0x67u8, 0x4Cu8, 0x65u8, 0x6Eu8, 0x00u8
    ])
    let lenFn = CFunc<(CPointer<UInt16>) -> UInt32>(proc)
    unsafe {
        lenFn(value)
    }
}

func sysStringByteLenRaw(value: CPointer<UInt16>): UInt32 {
    let module = oleaut32Module()
    let proc = getProcAddress(module, [
        0x53u8, 0x79u8, 0x73u8, 0x53u8, 0x74u8, 0x72u8, 0x69u8, 0x6Eu8,
        0x67u8, 0x42u8, 0x79u8, 0x74u8, 0x65u8, 0x4Cu8, 0x65u8, 0x6Eu8,
        0x00u8
    ])
    let lenFn = CFunc<(CPointer<UInt16>) -> UInt32>(proc)
    unsafe {
        lenFn(value)
    }
}

func windowsGetStringLenRaw(value: CPointer<Unit>): UInt32 {
    let module = combaseModule()
    let proc = getProcAddress(module, [
        0x57u8, 0x69u8, 0x6Eu8, 0x64u8, 0x6Fu8, 0x77u8, 0x73u8, 0x47u8,
        0x65u8, 0x74u8, 0x53u8, 0x74u8, 0x72u8, 0x69u8, 0x6Eu8, 0x67u8,
        0x4Cu8, 0x65u8, 0x6Eu8, 0x00u8
    ])
    let lenFn = CFunc<(CPointer<Unit>) -> UInt32>(proc)
    unsafe {
        lenFn(value)
    }
}

func windowsGetStringRawBufferRaw(value: CPointer<Unit>, length: CPointer<UInt32>): CPointer<UInt16> {
    let module = combaseModule()
    let proc = getProcAddress(module, [
        0x57u8, 0x69u8, 0x6Eu8, 0x64u8, 0x6Fu8, 0x77u8, 0x73u8, 0x47u8,
        0x65u8, 0x74u8, 0x53u8, 0x74u8, 0x72u8, 0x69u8, 0x6Eu8, 0x67u8,
        0x52u8, 0x61u8, 0x77u8, 0x42u8, 0x75u8, 0x66u8, 0x66u8, 0x65u8,
        0x72u8, 0x00u8
    ])
    let rawFn = CFunc<(CPointer<Unit>, CPointer<UInt32>) -> CPointer<UInt16>>(proc)
    unsafe {
        rawFn(value, length)
    }
}

func runBstrIntoRawAbiCase(): Unit {
    let units: Array<UInt16> = [0x0042u16, 0x0000u16, 0x4E2Du16, 0x0044u16]
    let value = BSTR.fromWide(units)
    let raw = value.intoRaw()
    expect(!raw.isNull(), "intoRaw should preserve non-empty raw pointer")
    expect(sysStringLenRaw(raw) == 4u32, "SysStringLen should read intoRaw payload")
    expect(sysStringByteLenRaw(raw) == 8u32, "SysStringByteLen should read intoRaw payload")
    sysFreeStringRaw(raw)
}

func runBstrAttachAbiCase(): Unit {
    let units: Array<UInt16> = [0x0041u16, 0x0000u16, 0x4E2Du16, 0x0042u16]
    let raw = sysAllocStringLenRaw(units)
    expect(!raw.isNull(), "SysAllocStringLen should allocate embedded-NUL payload")
    let value = unsafe { BSTR.unsafeAttach(raw) }
    expect(value.ownsStorage(), "attach should manage ABI BSTR storage")
    expect(value.length() == 4, "attach length mismatch")
    expect(value.byteLength() == 8u32, "attach byte length mismatch")
    expectWideUnits(value.toWideArray(), units, "attach wide units mismatch")
    expectString(value.get(), String.fromUtf8([0x41u8, 0x00u8, 0xE4u8, 0xB8u8, 0xADu8, 0x42u8]), "attach decode mismatch")
    value.close()
    expect(value.isClosed(), "attach close should mark closed")
}

func runHStringBuilderChecks(): Unit {
    let builder = HStringBuilder(3)
    let bytes = builder.asBytesMut()
    expect(bytes.length() == 6, "HStringBuilder.asBytesMut length mismatch")
    bytes.set(0, 0x48u8)
    bytes.set(1, 0u8)
    bytes.set(2, 0x69u8)
    bytes.set(3, 0u8)
    bytes.set(4, 0u8)
    bytes.set(5, 0u8)
    expect(builder.length() == 3, "HStringBuilder initial logical length mismatch")
    expect(builder.get(0) == 0x0048u16, "HStringBuilder first unit mismatch")
    expect(builder.get(1) == 0x0069u16, "HStringBuilder second unit mismatch")
    builder.trimEnd()
    expect(builder.length() == 2, "HStringBuilder trimEnd mismatch")
    let trimmedBytes = builder.asBytesMut()
    expect(trimmedBytes.length() == 4, "HStringBuilder.asBytesMut should respect logical length")
    expect(trimmedBytes.get(0) == 0x48u8, "HStringBuilder trimmed bytes[0] mismatch")
    expect(trimmedBytes.get(1) == 0u8, "HStringBuilder trimmed bytes[1] mismatch")
    expect(trimmedBytes.get(2) == 0x69u8, "HStringBuilder trimmed bytes[2] mismatch")
    expect(trimmedBytes.get(3) == 0u8, "HStringBuilder trimmed bytes[3] mismatch")
    expectWideUnits(builder.asWide(), [0x0048u16, 0x0069u16], "HStringBuilder.asWide should respect logical length")
    expectWideUnits(builder.asArray(), [0x0048u16, 0x0069u16], "HStringBuilder.asArray should respect logical length")
    let sealed = builder.intoHString()
    expect(sealed.get() == "Hi", "HStringBuilder.intoHString mismatch")
    expect(sealed.toStringLossy() == "Hi", "HStringBuilder sealed toStringLossy mismatch")
}

func runHStringFactoryManagedCase(): Unit {
    let factoryText = String.fromUtf8([0x46u8, 0x61u8, 0x63u8, 0x74u8, 0x6Fu8, 0x72u8, 0x79u8, 0xE4u8, 0xB8u8, 0xADu8])
    let hFactory = hStringFactory(factoryText)
    let factoryValue = hFactory.value()
    expect(factoryValue.get() == factoryText, "hStringFactory value mismatch")
    expect(!factoryValue.isReferenceBacked(), "hStringFactory value should manage its allocation")
    factoryValue.close()
    expect(factoryValue.isClosed(), "hStringFactory value should close cleanly")
}

func runBstrCloseIdempotentCase(): Unit {
    let baseline = debugObservedSysFreeStringCount()
    let value = BSTR("GC")
    expect(value.ownsStorage(), "BSTR close fixture should manage storage")
    value.close()
    value.close()
    expect(debugObservedSysFreeStringCount() == baseline + 1, "BSTR close should free managed storage at most once")
}

func runHStringCloseIdempotentCase(): Unit {
    let baseline = debugObservedHStringFreeCount()
    let value = HString("GC")
    expect(!value.isReferenceBacked(), "HString close fixture should manage storage")
    value.close()
    value.close()
    expect(debugObservedHStringFreeCount() == baseline + 1, "HString close should free managed storage at most once")
}

func runHStringBuilderCloseIdempotentCase(): Unit {
    let baseline = debugObservedHStringFreeCount()
    let builder = HStringBuilder(4)
    expect(builder.length() == 4, "HStringBuilder close fixture length mismatch")
    builder.close()
    builder.close()
    expect(debugObservedHStringFreeCount() == baseline + 1, "HStringBuilder close should free managed storage at most once")
}

func runUtf16TrailingHighSurrogateCase(): Unit {
    let trailingHighSurrogateUtf16 = decodeUtf16([0x0041u16, 0xD800u16])
    expect(trailingHighSurrogateUtf16 == "A\u{FFFD}", "decodeUtf16 trailing high surrogate replacement mismatch")
}

unsafe func expectAnsiPointerViews(pcstr: PCSTR, pstr: PSTR): Unit {
    expect(pcstr.length() == 2, "PCSTR length mismatch")
    expect(!pcstr.isEmpty(), "PCSTR should not be empty")
    expectAnsiUnits(pcstr.asBytes(), [0x48u8, 0x69u8], "PCSTR asBytes mismatch")
    expectAnsiUnits(pcstr.toArray(), [0x48u8, 0x69u8], "PCSTR bytes mismatch")
    expect(pcstr.toStringLossy() == "Hi", "PCSTR toStringLossy mismatch")
    expectSomeString(pcstr.toString(), "Hi", "PCSTR toString mismatch")
    expectSomeString(pcstr.tryToString(), "Hi", "PCSTR tryToString mismatch")
    expect("${pcstr.display()}" == "Hi", "PCSTR display mismatch")
    expect(PCSTR.default().isNull(), "PCSTR.default should be null")

    expect(pstr.length() == 2, "PSTR length mismatch")
    expect(!pstr.isEmpty(), "PSTR should not be empty")
    expectAnsiUnits(pstr.asBytes(), [0x48u8, 0x69u8], "PSTR asBytes mismatch")
    expectAnsiUnits(pstr.toArray(), [0x48u8, 0x69u8], "PSTR bytes mismatch")
    expect(pstr.toStringLossy() == "Hi", "PSTR toStringLossy mismatch")
    expectSomeString(pstr.toString(), "Hi", "PSTR toString mismatch")
    expectSomeString(pstr.tryToString(), "Hi", "PSTR tryToString mismatch")
    expect("${pstr.display()}" == "Hi", "PSTR display mismatch")
    expectSomeString(pstr.toPCSTR().toString(), "Hi", "PSTR toPCSTR mismatch")
    expect(PSTR.default().isNull(), "PSTR.default should be null")
}

unsafe func expectWidePointerViews(pcwstr: PCWSTR, pwstr: PWSTR): Unit {
    expect(pcwstr.length() == 2, "PCWSTR length mismatch")
    expect(!pcwstr.isEmpty(), "PCWSTR should not be empty")
    expectWideUnits(pcwstr.asWide(), [0x0048u16, 0x0069u16], "PCWSTR asWide mismatch")
    expectWideUnits(pcwstr.toArray(), [0x0048u16, 0x0069u16], "PCWSTR units mismatch")
    expect(pcwstr.toStringLossy() == "Hi", "PCWSTR toStringLossy mismatch")
    expectSomeString(pcwstr.toString(), "Hi", "PCWSTR toString mismatch")
    expectSomeString(pcwstr.tryToString(), "Hi", "PCWSTR tryToString mismatch")
    expect("${pcwstr.display()}" == "Hi", "PCWSTR display mismatch")
    expect(unsafe { pcwstr.toHString().toStringLossy() } == "Hi", "PCWSTR toHString mismatch")
    expect(PCWSTR.default().isNull(), "PCWSTR.default should be null")

    expect(pwstr.length() == 2, "PWSTR length mismatch")
    expect(!pwstr.isEmpty(), "PWSTR should not be empty")
    expectWideUnits(pwstr.asWide(), [0x0048u16, 0x0069u16], "PWSTR asWide mismatch")
    expectWideUnits(pwstr.toArray(), [0x0048u16, 0x0069u16], "PWSTR units mismatch")
    expect(pwstr.toStringLossy() == "Hi", "PWSTR toStringLossy mismatch")
    expectSomeString(pwstr.toString(), "Hi", "PWSTR toString mismatch")
    expectSomeString(pwstr.tryToString(), "Hi", "PWSTR tryToString mismatch")
    expect("${pwstr.display()}" == "Hi", "PWSTR display mismatch")
    expect(unsafe { pwstr.toHString().toStringLossy() } == "Hi", "PWSTR toHString mismatch")
    expectSomeString(pwstr.toPCWSTR().toString(), "Hi", "PWSTR toPCWSTR mismatch")
    expect(PWSTR.default().isNull(), "PWSTR.default should be null")
}

func runMainChecks(): Unit {
    let sample = String.fromUtf8([0x41u8, 0xE4u8, 0xB8u8, 0xADu8, 0x42u8])
    let sampleWide: Array<UInt16> = [0x0041u16, 0x4E2Du16, 0x0042u16]
    let embeddedNulWide: Array<UInt16> = [0x0041u16, 0x0000u16, 0x4E2Du16, 0x0042u16]
    let embeddedNulString = String.fromUtf8([0x41u8, 0x00u8, 0xE4u8, 0xB8u8, 0xADu8, 0x42u8])

    let wide = CWideString(sample)
    expect(wide.length() == 3, "CWideString length mismatch: ${wide.length()}")
    let roundtrip = wide.withPtr { ptr: CPointer<UInt16> =>
        CWideString.fromPointer(ptr)
    }
    expect(roundtrip == sample, "CWideString pointer roundtrip mismatch")

    let empty = CWideString("")
    expect(empty.length() == 0, "CWideString empty length mismatch")
    let emptyRoundtrip = empty.withPtr { ptr: CPointer<UInt16> =>
        CWideString.fromPointer(ptr)
    }
    expect(emptyRoundtrip == "", "CWideString empty roundtrip mismatch")

    let literal = CWideString.literal("Literal")
    expect(literal.withPtr { ptr: CPointer<UInt16> => CWideString.fromPointer(ptr) } == "Literal", "CWideString literal helper mismatch")

    match (decodeUtf8Char([0xCEu8, 0xB1u8], 0)) {
        case Some(decoded) =>
            let (codePoint, nextPos) = decoded
            expect(codePoint == 0x03B1u32, "decodeUtf8Char code point mismatch")
            expect(nextPos == 2, "decodeUtf8Char next position mismatch")
        case None =>
            fail("decodeUtf8Char should be publicly callable from dependents")
    }

    let wideFactory = wideStringFactory("Factory")
    expect(wideFactory.length() == 7, "wideStringFactory length mismatch")
    let wideFactoryRoundtrip = wideFactory.withPtr { pointerView: PCWSTR =>
        unsafe { pointerView.toString() }
    }
    expectSomeString(wideFactoryRoundtrip, "Factory", "wideStringFactory pointer decode mismatch")

    let narrowText = String.fromUtf8([0x46u8, 0x61u8, 0x63u8, 0x74u8, 0x6Fu8, 0x72u8, 0x79u8, 0xE4u8, 0xB8u8, 0xADu8])
    let narrowFactory = narrowStringFactory(narrowText)
    expect(narrowFactory.length() == 10, "narrowStringFactory byte length mismatch")
    let narrowFactoryRoundtrip = narrowFactory.withPtr { pointerView: PCSTR =>
        unsafe {
            expectAnsiUnits(pointerView.asBytes(), [0x46u8, 0x61u8, 0x63u8, 0x74u8, 0x6Fu8, 0x72u8, 0x79u8, 0xE4u8, 0xB8u8, 0xADu8], "narrowStringFactory bytes mismatch")
            pointerView.toString()
        }
    }
    expectSomeString(narrowFactoryRoundtrip, narrowText, "narrowStringFactory pointer decode mismatch")

    let narrowLiteral = pcstrLiteral("Literal")
    let narrowLiteralRoundtrip = narrowLiteral.withPtr { pointerView: PCSTR =>
        unsafe { pointerView.toString() }
    }
    expectSomeString(narrowLiteralRoundtrip, "Literal", "pcstrLiteral helper mismatch")

    let hstring = HString(sample)
    expect(hstring.get() == sample, "HString get mismatch")
    expect(hstring.toStringLossy() == sample, "HString toStringLossy mismatch")
    expectSomeString(hstring.tryToString(), sample, "HString tryToString mismatch")
    expect(hstring == sample, "HString == String mismatch")
    expectWideUnits(hstring.toWideArray(), sampleWide, "HString asSlice mismatch")
    expect("${hstring.display()}" == sample, "HString display mismatch")
    expect(!hstring.isClosed(), "HString should start open")
    expect(hstring.length() == 3, "HString length mismatch")
    expect(!hstring.isReferenceBacked(), "managed HString should not report reference-backed")
    expect(requireComparable(HString("A"), HString("B")) == Ordering.LT, "HString compare mismatch")
    expect(HString("A") < HString("B"), "HString ordering operator mismatch")
    expect(requireHashable(HString("Hash")) == requireHashable(HString("Hash")), "HString hashCode should be stable")
    expect(windowsGetStringLenRaw(hstring.asRaw()) == 3u32, "WindowsGetStringLen should read managed HString")
    var hstringRawLength = 0u32
    let hstringRawPtr = windowsGetStringRawBufferRaw(hstring.asRaw(), CPointer<UInt32>(inout hstringRawLength))
    expect(hstringRawLength == 3u32, "WindowsGetStringRawBuffer should report managed HString length")
    unsafe {
        expect((hstringRawPtr + 0).read() == 0x0041u16, "managed HString raw ptr[0] mismatch")
        expect((hstringRawPtr + 1).read() == 0x4E2Du16, "managed HString raw ptr[1] mismatch")
        expect((hstringRawPtr + 2).read() == 0x0042u16, "managed HString raw ptr[2] mismatch")
        expect((hstringRawPtr + 3).read() == 0u16, "managed HString raw terminator mismatch")
    }
    expect(hStringLiteral(sample).get() == sample, "HString literal helper mismatch")
    hstring.close()
    expect(hstring.isClosed(), "HString close did not mark closed")

    let emptyH = HString("")
    expect(emptyH.get() == "", "Empty HString get mismatch")
    expect(emptyH.length() == 0, "Empty HString length mismatch")
    expect(HString.default().isEmpty(), "HString.default should be empty")
    emptyH.close()

    let embedded = HString.fromWide(embeddedNulWide)
    expect(embedded.length() == 4, "Embedded-NUL HString logical length mismatch")
    expect(embedded.get() == embeddedNulString, "Embedded-NUL HString decode mismatch")
    expectSomeString(embedded.tryToString(), embeddedNulString, "Embedded-NUL HString tryToString mismatch")
    expectWideUnits(embedded.toWideArray(), embeddedNulWide, "Embedded-NUL HString asSlice mismatch")
    expectWideUnits(embedded.toWideArray(), embeddedNulWide, "Embedded-NUL HString units mismatch")
    expect(windowsGetStringLenRaw(embedded.asRaw()) == 4u32, "WindowsGetStringLen should read embedded-NUL HString")
    embedded.withPtr { ptr: CPointer<UInt16> =>
        unsafe {
            expect((ptr + 0).read() == 0x0041u16, "Embedded-NUL HString ptr[0] mismatch")
            expect((ptr + 1).read() == 0x0000u16, "Embedded-NUL HString ptr[1] mismatch")
            expect((ptr + 2).read() == 0x4E2Du16, "Embedded-NUL HString ptr[2] mismatch")
            expect((ptr + 3).read() == 0x0042u16, "Embedded-NUL HString ptr[3] mismatch")
            expect((ptr + 4).read() == 0u16, "Embedded-NUL HString terminator mismatch")
        }
    }

    let factoryText = String.fromUtf8([0x46u8, 0x61u8, 0x63u8, 0x74u8, 0x6Fu8, 0x72u8, 0x79u8, 0xE4u8, 0xB8u8, 0xADu8])
    let hFactory = hStringFactory(factoryText)
    let factoryValue = hFactory.value()
    expect(factoryValue.get() == factoryText, "hStringFactory value mismatch")
    expect("${factoryValue.display()}" == factoryText, "hStringFactory display mismatch")
    expect(!factoryValue.isReferenceBacked(), "hStringFactory value should manage its allocation")
    expectWideUnits(factoryValue.toWideArray(), [0x0046u16, 0x0061u16, 0x0063u16, 0x0074u16, 0x006Fu16, 0x0072u16, 0x0079u16, 0x4E2Du16], "hStringFactory asSlice mismatch")
    expect(windowsGetStringLenRaw(factoryValue.asRaw()) == 8u32, "WindowsGetStringLen should read factory-managed HString")
    hFactory.withPtr { pointerView: PCWSTR =>
        expect(unsafe { pointerView.toHString().get() } == factoryText, "hStringFactory pointer view mismatch")
    }

    let invalidHString = HString.fromWide([0xD800u16, 0x0041u16])
    expectNoneString(invalidHString.tryToString(), "Invalid HString tryToString should fail")

    let bstrText = String.fromUtf8([0x42u8, 0xE4u8, 0xB8u8, 0xADu8])
    let bstrSample = BSTR(bstrText)
    expect(bstrSample.length() == 2, "BSTR length mismatch")
    expect(bstrSample.byteLength() == 4u32, "BSTR byte length mismatch")
    expect(bstrSample.get() == bstrText, "BSTR get mismatch")
    expectSomeString(bstrSample.tryToString(), bstrText, "BSTR tryToString mismatch")
    expect("${bstrSample.display()}" == bstrText, "BSTR display mismatch")
    expect(bstrSample == bstrText, "BSTR == String mismatch")
    expectWideUnits(bstrSample.toWideArray(), [0x0042u16, 0x4E2Du16], "BSTR asSlice mismatch")
    expect(bstrSample.ownsStorage(), "BSTR constructed value should manage storage")
    expect(sysStringLenRaw(bstrSample.asPtr()) == 2u32, "SysStringLen should read constructed BSTR")
    expect(sysStringByteLenRaw(bstrSample.asPtr()) == 4u32, "SysStringByteLen should read constructed BSTR")
    let bstrRaw = bstrSample.intoRaw()
    expect(!bstrRaw.isNull(), "BSTR intoRaw returned null")
    expect(sysStringLenRaw(bstrRaw) == 2u32, "SysStringLen should read intoRaw BSTR")
    let managedFromRaw = unsafe { BSTR.unsafeFromRaw(bstrRaw) }
    expect(managedFromRaw.ownsStorage(), "BSTR.fromRaw should take storage management")
    expect(managedFromRaw.length() == 2, "Managed BSTR length mismatch")
    expect(managedFromRaw.get() == bstrText, "Managed BSTR get mismatch")
    managedFromRaw.close()
    expect(managedFromRaw.isClosed(), "Managed BSTR close mismatch")

    let viewRaw = sysAllocStringLenRaw([0x0042u16, 0x4E2Du16])
    expect(!viewRaw.isNull(), "SysAllocStringLen should allocate BSTR view payload")
    let viewBstr = unsafe { BSTR.unsafeFromRawView(viewRaw) }
    expect(!viewBstr.ownsStorage(), "BSTR.fromRawView should not manage storage")
    expect(viewBstr.length() == 2, "View BSTR length mismatch")
    expect(viewBstr.get() == bstrText, "View BSTR get mismatch")
    sysFreeStringRaw(viewRaw)

    let emptyBstr = BSTR("")
    expect(emptyBstr.isEmpty(), "Empty BSTR should report empty")
    expect(emptyBstr.length() == 0, "Empty BSTR length mismatch")
    expect(emptyBstr.byteLength() == 0u32, "Empty BSTR byte length mismatch")
    expect(emptyBstr.asPtr().isNull(), "Empty BSTR should use null raw pointer")
    expect(emptyBstr.intoRaw().isNull(), "Empty BSTR intoRaw should keep null pointer")

    let embeddedBstr = BSTR.fromWide(embeddedNulWide)
    expect(embeddedBstr.length() == 4, "Embedded-NUL BSTR length mismatch")
    expect(embeddedBstr.byteLength() == 8u32, "Embedded-NUL BSTR byte length mismatch")
    expectString(embeddedBstr.get(), embeddedNulString, "Embedded-NUL BSTR decode mismatch")
    expectSomeString(embeddedBstr.tryToString(), embeddedNulString, "Embedded-NUL BSTR tryToString mismatch")
    expectWideUnits(embeddedBstr.toWideArray(), embeddedNulWide, "Embedded-NUL BSTR asSlice mismatch")
    expectWideUnits(embeddedBstr.toWideArray(), embeddedNulWide, "Embedded-NUL BSTR units mismatch")
    expect(sysStringLenRaw(embeddedBstr.asPtr()) == 4u32, "Embedded-NUL SysStringLen mismatch")
    expect(sysStringByteLenRaw(embeddedBstr.asPtr()) == 8u32, "Embedded-NUL SysStringByteLen mismatch")

    let invalidBstr = BSTR.fromWide([0xD800u16, 0x0041u16])
    expectNoneString(invalidBstr.tryToString(), "Invalid BSTR tryToString should fail")

    let attachLiveRaw = sysAllocStringLenRaw([0x0041u16, 0x0042u16])
    let attachLive = unsafe { BSTR.unsafeAttach(attachLiveRaw) }
    unsafe {
        (attachLiveRaw + 1).write(0x4E2Du16)
    }
    let attachLiveText = String.fromUtf8([0x41u8, 0xE4u8, 0xB8u8, 0xADu8])
    expectString(attachLive.get(), attachLiveText, "BSTR.attach should read live pointer contents")
    expectSomeString(attachLive.tryToString(), attachLiveText, "BSTR.attach tryToString should read live pointer contents")
    let attachLiveSlice = attachLive.asSlice()
    expect(attachLiveSlice.size == 2, "BSTR.attach asSlice size mismatch")
    expect(attachLiveSlice[0] == 0x0041u16, "BSTR.attach asSlice first unit mismatch")
    expect(attachLiveSlice[1] == 0x4E2Du16, "BSTR.attach asSlice should read live pointer contents")
    expect("${attachLive.display()}" == attachLiveText, "BSTR.attach display should read live pointer contents")
    attachLive.close()

    let fromRawLiveRaw = sysAllocStringLenRaw([0x0042u16, 0x0043u16])
    let fromRawLive = unsafe { BSTR.unsafeFromRaw(fromRawLiveRaw) }
    unsafe {
        (fromRawLiveRaw + 0).write(0x4E2Du16)
    }
    let fromRawLiveText = String.fromUtf8([0xE4u8, 0xB8u8, 0xADu8, 0x43u8])
    expectString(fromRawLive.get(), fromRawLiveText, "BSTR.fromRaw should read live pointer contents")
    expectSomeString(fromRawLive.tryToString(), fromRawLiveText, "BSTR.fromRaw tryToString should read live pointer contents")
    let fromRawLiveSlice = fromRawLive.asSlice()
    expect(fromRawLiveSlice.size == 2, "BSTR.fromRaw asSlice size mismatch")
    expect(fromRawLiveSlice[0] == 0x4E2Du16, "BSTR.fromRaw asSlice first unit mismatch")
    expect(fromRawLiveSlice[1] == 0x0043u16, "BSTR.fromRaw asSlice should read live pointer contents")
    fromRawLive.close()

    let invalidUtf16 = decodeUtf16([0xD800u16, 0x0041u16, 0xDC00u16])
    expect(invalidUtf16 == "\u{FFFD}A\u{FFFD}", "decodeUtf16 invalid surrogate replacement mismatch")
    let invalidUtf8 = decodeUtf8Lossy([0x66u8, 0x80u8, 0x67u8])
    expect(invalidUtf8 == "f\u{FFFD}g", "decodeUtf8Lossy invalid sequence mismatch")
    let invalidUtf8ConsumedContinuation = decodeUtf8Lossy([0xE0u8, 0xA0u8, 0x41u8])
    expect(invalidUtf8ConsumedContinuation == "\u{FFFD}A", "decodeUtf8Lossy should not replace consumed continuation bytes twice")
    let invalidUtf8ConsumedTwoContinuations = decodeUtf8Lossy([0xF0u8, 0x90u8, 0x80u8, 0x41u8])
    expect(invalidUtf8ConsumedTwoContinuations == "\u{FFFD}A", "decodeUtf8Lossy should advance past validated continuation bytes on failure")
    let truncatedUtf8 = decodeUtf8Lossy([0x66u8, 0xE4u8, 0xB8u8])
    expect(truncatedUtf8 == "f", "decodeUtf8Lossy should stop at trailing incomplete sequence")
    expectNoneString(tryDecodeUtf8([0x66u8, 0x80u8, 0x67u8]), "tryDecodeUtf8 should reject invalid UTF-8")
    expect(utf16Len([0x31u8, 0x32u8, 0x33u8]) == 3, "utf16Len ASCII mismatch")
    expect(utf16Len([0xCEu8, 0xB1u8, 0x20u8, 0x26u8, 0x20u8, 0xCFu8, 0x89u8]) == 5, "utf16Len multibyte mismatch")

    let invalidAnsiBytes: Array<UInt8> = [0x66u8, 0x80u8, 0x67u8, 0x00u8]
    unsafe {
        let invalidAnsiHandle = acquireArrayRawData(invalidAnsiBytes)
        try {
            let invalidPcstr = PCSTR.fromRaw(invalidAnsiHandle.pointer)
            let invalidPstr = PSTR.fromRaw(invalidAnsiHandle.pointer)
            expectNoneString(invalidPcstr.tryToString(), "PCSTR tryToString should reject invalid UTF-8")
            expectNoneString(invalidPstr.tryToString(), "PSTR tryToString should reject invalid UTF-8")
        } finally {
            releaseArrayRawData(invalidAnsiHandle)
        }
    }

    let invalidWideBytes: Array<UInt16> = [0xD800u16, 0x0041u16, 0x0000u16]
    unsafe {
        let invalidWideHandle = acquireArrayRawData(invalidWideBytes)
        try {
            let invalidPcwstr = PCWSTR.fromRaw(invalidWideHandle.pointer)
            let invalidPwstr = PWSTR.fromRaw(invalidWideHandle.pointer)
            expectNoneString(invalidPcwstr.tryToString(), "PCWSTR tryToString should reject invalid UTF-16")
            expectNoneString(invalidPwstr.tryToString(), "PWSTR tryToString should reject invalid UTF-16")
        } finally {
            releaseArrayRawData(invalidWideHandle)
        }
    }

    let ansiBytes: Array<UInt8> = [0x48u8, 0x69u8, 0x00u8, 0x58u8]
    let wideBytes: Array<UInt16> = [0x0048u16, 0x0069u16, 0x0000u16, 0x0058u16]
    unsafe {
        let ansiHandle = acquireArrayRawData(ansiBytes)
        let wideHandle = acquireArrayRawData(wideBytes)
        try {
            let pcstr = PCSTR.fromRaw(ansiHandle.pointer)
            let pstr = PSTR.fromRaw(ansiHandle.pointer)
            let pcwstr = PCWSTR.fromRaw(wideHandle.pointer)
            let pwstr = PWSTR.fromRaw(wideHandle.pointer)
            expectAnsiPointerViews(pcstr, pstr)
            expectWidePointerViews(pcwstr, pwstr)
        } finally {
            releaseArrayRawData(ansiHandle)
            releaseArrayRawData(wideHandle)
        }
    }

    runHStringBuilderChecks()
}

main(args: Array<String>) {
    if (!args.isEmpty()) {
        if (args[0] == "bstr-into-raw-abi") {
            runBstrIntoRawAbiCase()
            return
        }
        if (args[0] == "bstr-attach-abi") {
            runBstrAttachAbiCase()
            return
        }
        if (args[0] == "hstring-factory-managed") {
            runHStringFactoryManagedCase()
            return
        }
        if (args[0] == "bstr-close-idempotent") {
            runBstrCloseIdempotentCase()
            return
        }
        if (args[0] == "hstring-close-idempotent") {
            runHStringCloseIdempotentCase()
            return
        }
        if (args[0] == "hstring-builder-close-idempotent") {
            runHStringBuilderCloseIdempotentCase()
            return
        }
        if (args[0] == "utf16-trailing-high-surrogate") {
            runUtf16TrailingHighSurrogateCase()
            return
        }
    }

    runMainChecks()
}
'@ | Set-Content -NoNewline (Join-Path $srcRoot "main.cj")

$bstrSource = Get-Content -Raw (Join-Path $packageRoot "src/bstr.cj")
if (([regex]::Matches($bstrSource, "~init\(\)")).Count -lt 1) {
    throw "bstr.cj is missing ~init()"
}

$hstringSource = Get-Content -Raw (Join-Path $packageRoot "src/hstring.cj")
if (([regex]::Matches($hstringSource, "~init\(\)")).Count -lt 2) {
    throw "hstring.cj should define ~init() for both HString and HStringBuilder"
}

Push-Location $runnerRoot
try {
    cjpm build | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm build failed with exit code $LASTEXITCODE"
    }
    cjpm run -- bstr-into-raw-abi | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run bstr-into-raw-abi failed with exit code $LASTEXITCODE"
    }
    cjpm run -- bstr-attach-abi | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run bstr-attach-abi failed with exit code $LASTEXITCODE"
    }
    cjpm run -- hstring-factory-managed | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run hstring-factory-managed failed with exit code $LASTEXITCODE"
    }
    cjpm run -- bstr-close-idempotent | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run bstr-close-idempotent failed with exit code $LASTEXITCODE"
    }
    cjpm run -- hstring-close-idempotent | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run hstring-close-idempotent failed with exit code $LASTEXITCODE"
    }
    cjpm run -- hstring-builder-close-idempotent | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run hstring-builder-close-idempotent failed with exit code $LASTEXITCODE"
    }
    cjpm run -- utf16-trailing-high-surrogate | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run utf16-trailing-high-surrogate failed with exit code $LASTEXITCODE"
    }
    cjpm run | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm run failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
    if (Test-Path $workspaceRoot) {
        Remove-Item -Recurse -Force $workspaceRoot
    }
}

Write-Host "windows-strings smoke test passed."
