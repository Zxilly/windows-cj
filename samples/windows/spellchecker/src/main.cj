package windows_sample_spellchecker

import windows_sample_spellchecker_bindings.Win32.Globalization.{
    Apis as GlobApis,
    ISpellChecker,
    ISpellCheckerFactory,
    IEnumSpellingError,
    IEnumSpellingErrorVtbl,
    ISpellingError,
    ISpellingErrorVtbl,
    ISpellCheckerFactoryVtbl,
    ISpellCheckerVtbl
}
import windows_sample_spellchecker_bindings.Win32.System.Com.{
    Apis as ComApis,
    IEnumString,
    IEnumStringVtbl
}
import windows_strings.{encodeUtf16WithNull, decodeWideFromPointer}
import windows_core.{HRESULT, S_OK}
import windows_interface.GUID

// ============================================================================
// spellchecker — behaviour-equivalent port of the reference sample.
//
// Boots the COM runtime, creates an ISpellCheckerFactory, verifies "en-US" is
// supported, makes an ISpellChecker, and runs a comprehensive spell-check over
// the command-line string. For every reported error it prints the corrective
// action and either the deletion, the single replacement, or every suggestion
// (each suggestion fetched from an IEnumString). PWSTRs handed back by the COM
// layer are released with CoTaskMemFree, exactly as the reference does.
//
// Paradigm notes (Cangjie vs the reference language):
//   • These COM interfaces are projected as consuming-only Resource wrappers;
//     their methods are NOT instance methods but fields of a separate @C vtbl
//     struct. We read the vtbl pointer out of the raw COM pointer and invoke
//     the CFunc fields directly inside unsafe{} — the same ABI the reference's
//     projected methods perform under the hood (the com_uri pattern).
//   • There is no compile-time w!/h! wide literal. encodeUtf16WithNull builds a
//     NUL-terminated UTF-16 buffer at run time; this is the behavioural twin of
//     a w!/h! literal and of HSTRING::from(&input) for an ASCII test string.
//   • CLSCTX_ALL (23), COINIT_MULTITHREADED (0) and the SpellCheckerFactory
//     CLSID / ISpellCheckerFactory IID are not re-exported as facade scalars,
//     so we pass the documented values directly — semantically identical to the
//     reference's named constants.
//   • StartIndex / Length are UTF-16 code-unit offsets into the checked string.
//     We slice the wide input buffer by those offsets, which is the precise
//     WinRT-ABI meaning and produces identical output for the ASCII inputs this
//     sample targets (the reference slices its UTF-8 String the same way).
//   • COM pointer lifetimes are owned by the generated Resource wrappers
//     (takeOwnership: true); their close()/finalizer call Release. GC manages
//     references between the Cangjie wrappers, so no manual AddRef/Release.
// ============================================================================

// CLSID_SpellCheckerFactory {7AB36653-1796-484B-BDFA-E74F1DB7C1DC}.
let CLSID_SPELL_CHECKER_FACTORY = GUID.parse("7AB36653-1796-484B-BDFA-E74F1DB7C1DC")
// IID_ISpellCheckerFactory {8E018A9D-2415-4677-BF08-794EA61F94BB}.
let IID_ISPELL_CHECKER_FACTORY = GUID.parse("8E018A9D-2415-4677-BF08-794EA61F94BB")

// CLSCTX_ALL — every activation context (INPROC_SERVER|INPROC_HANDLER|LOCAL_SERVER|REMOTE_SERVER).
const CLSCTX_ALL: UInt32 = 23
// COINIT_MULTITHREADED — the all-zero apartment model used by the reference.
const COINIT_MULTITHREADED: UInt32 = 0

// CORRECTIVE_ACTION values (Windows.Win32.Globalization.CORRECTIVE_ACTION).
const ACTION_NONE: Int32 = 0
const ACTION_GET_SUGGESTIONS: Int32 = 1
const ACTION_REPLACE: Int32 = 2
const ACTION_DELETE: Int32 = 3

// ---------------------------------------------------------------------------
// Vtbl helpers. Each reads the COM object's vtbl pointer and invokes a method.
// ---------------------------------------------------------------------------

// ISpellCheckerFactory::IsSupported(localeTag, out supported: BOOL). Returns the
// BOOL (non-zero == supported).
func factoryIsSupported(raw: CPointer<Unit>, locale: CPointer<UInt16>): Int32 {
    var supported: Int32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<ISpellCheckerFactoryVtbl>>(raw).read().read()
        let hr = vtbl.IsSupported(raw, locale, CPointer<Int32>(inout supported))
        HRESULT(hr).check()
    }
    supported
}

// ISpellCheckerFactory::CreateSpellChecker(localeTag, out value: ISpellChecker).
func factoryCreateSpellChecker(raw: CPointer<Unit>, locale: CPointer<UInt16>): CPointer<Unit> {
    var checkerRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<ISpellCheckerFactoryVtbl>>(raw).read().read()
        let hr = vtbl.CreateSpellChecker(
            raw, locale, CPointer<Unit>(CPointer<CPointer<Unit>>(inout checkerRaw)))
        HRESULT(hr).check()
    }
    checkerRaw
}

// ISpellChecker::ComprehensiveCheck(text, out value: IEnumSpellingError).
func checkerComprehensiveCheck(raw: CPointer<Unit>, text: CPointer<UInt16>): CPointer<Unit> {
    var errorsRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<ISpellCheckerVtbl>>(raw).read().read()
        let hr = vtbl.ComprehensiveCheck(
            raw, text, CPointer<Unit>(CPointer<CPointer<Unit>>(inout errorsRaw)))
        HRESULT(hr).check()
    }
    errorsRaw
}

// ISpellChecker::Suggest(word, out value: IEnumString).
func checkerSuggest(raw: CPointer<Unit>, word: CPointer<UInt16>): CPointer<Unit> {
    var suggestionsRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<ISpellCheckerVtbl>>(raw).read().read()
        let hr = vtbl.Suggest(
            raw, word, CPointer<Unit>(CPointer<CPointer<Unit>>(inout suggestionsRaw)))
        HRESULT(hr).check()
    }
    suggestionsRaw
}

// IEnumSpellingError::Next(out value: ISpellingError) -> HRESULT. S_OK means a
// new error was produced; anything else (e.g. S_FALSE) ends the enumeration.
func enumErrorsNext(raw: CPointer<Unit>): (HRESULT, CPointer<Unit>) {
    var errorRaw = CPointer<Unit>()
    let hr: Int32
    unsafe {
        let vtbl = CPointer<CPointer<IEnumSpellingErrorVtbl>>(raw).read().read()
        hr = vtbl.Next(raw, CPointer<Unit>(CPointer<CPointer<Unit>>(inout errorRaw)))
    }
    (HRESULT(hr), errorRaw)
}

// ISpellingError::StartIndex(out value: UInt32).
func errorStartIndex(raw: CPointer<Unit>): UInt32 {
    var value: UInt32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<ISpellingErrorVtbl>>(raw).read().read()
        let hr = vtbl.StartIndex(raw, CPointer<Unit>(CPointer<UInt32>(inout value)))
        HRESULT(hr).check()
    }
    value
}

// ISpellingError::Length(out value: UInt32).
func errorLength(raw: CPointer<Unit>): UInt32 {
    var value: UInt32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<ISpellingErrorVtbl>>(raw).read().read()
        let hr = vtbl.Length(raw, CPointer<Unit>(CPointer<UInt32>(inout value)))
        HRESULT(hr).check()
    }
    value
}

// ISpellingError::CorrectiveAction(out value: CORRECTIVE_ACTION (Int32)).
func errorCorrectiveAction(raw: CPointer<Unit>): Int32 {
    var value: Int32 = 0
    unsafe {
        let vtbl = CPointer<CPointer<ISpellingErrorVtbl>>(raw).read().read()
        let hr = vtbl.CorrectiveAction(raw, CPointer<Unit>(CPointer<Int32>(inout value)))
        HRESULT(hr).check()
    }
    value
}

// ISpellingError::Replacement(out value: PWSTR). Caller owns the PWSTR.
func errorReplacement(raw: CPointer<Unit>): CPointer<UInt16> {
    var value = CPointer<UInt16>()
    unsafe {
        let vtbl = CPointer<CPointer<ISpellingErrorVtbl>>(raw).read().read()
        let hr = vtbl.Replacement(raw, CPointer<CPointer<UInt16>>(inout value))
        HRESULT(hr).check()
    }
    value
}

// IEnumString::Next(1, out rgelt[1], None). Returns the single PWSTR fetched
// (null when the enumeration is exhausted). Caller owns a non-null PWSTR.
func enumStringNext(raw: CPointer<Unit>): CPointer<UInt16> {
    let slot = Array<CPointer<UInt16>>(1, repeat: CPointer<UInt16>())
    unsafe {
        let handle = acquireArrayRawData(slot)
        try {
            let vtbl = CPointer<CPointer<IEnumStringVtbl>>(raw).read().read()
            // pceltFetched == None (null pointer), matching the reference.
            vtbl.Next(raw, 1u32, handle.pointer, CPointer<Unit>())
        } finally {
            releaseArrayRawData(handle)
        }
    }
    slot[0]
}

// Decode a [start, start+length) code-unit slice of the wide input into a
// String. StartIndex / Length are UTF-16 offsets, so this is the exact ABI
// meaning of the reference's substring.
func decodeWideFromPointerSlice(input: Array<UInt16>, start: Int64, length: Int64): String {
    var s = ""
    var i = start
    let end = start + length
    while (i < end && i < input.size) {
        s += "${Rune(UInt32(input[i]))}"
        i += 1
    }
    s
}

main(args: Array<String>): Int64 {
    if (args.size < 1) {
        eprintln("Expected one command line argument for text to be spell-corrected")
        return 1
    }
    let input = args[0]

    // Initialize the COM runtime for this thread.
    ComApis.CoInitializeExChecked(CPointer<Unit>(), COINIT_MULTITHREADED)

    // Create ISpellCheckerFactory via CoCreateInstance(SpellCheckerFactory).
    var clsid = CLSID_SPELL_CHECKER_FACTORY
    var iid = IID_ISPELL_CHECKER_FACTORY
    var factoryRaw = CPointer<Unit>()
    unsafe {
        let hr = ComApis.CoCreateInstance(
            CPointer<Unit>(CPointer<GUID>(inout clsid)),
            CPointer<Unit>(),
            CLSCTX_ALL,
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout factoryRaw))
        )
        HRESULT(hr).check()
    }
    let factory = ISpellCheckerFactory(factoryRaw, takeOwnership: true)

    var exitCode: Int64 = 0
    try {
        // The "en-US" locale tag, as a NUL-terminated wide buffer.
        let localeBuf = encodeUtf16WithNull("en-US")
        // The checked text as a NUL-terminated wide buffer (the analogue of
        // HSTRING::from(&input)); also sliced for error substrings.
        let inputBuf = encodeUtf16WithNull(input)

        unsafe {
            let localeHandle = acquireArrayRawData(localeBuf)
            try {
                // Make sure that "en-US" is supported.
                let supported = factoryIsSupported(factoryRaw, localeHandle.pointer)
                if (supported == 0) {
                    eprintln("en-US is supported")
                    exitCode = 1
                    return exitCode
                }

                // Create an ISpellChecker for "en-US".
                let checkerRaw = factoryCreateSpellChecker(factoryRaw, localeHandle.pointer)
                let checker = ISpellChecker(checkerRaw, takeOwnership: true)
                try {
                    println("Checking the text: '${input}'")
                    runCheck(checkerRaw, inputBuf)
                } finally {
                    checker.close()
                }
            } finally {
                releaseArrayRawData(localeHandle)
            }
        }
    } finally {
        factory.close()
    }

    return exitCode
}

// Drive the comprehensive check loop over the wide input buffer.
func runCheck(checkerRaw: CPointer<Unit>, inputBuf: Array<UInt16>): Unit {
    let errorsRaw = unsafe {
        var raw = CPointer<Unit>()
        let handle = acquireArrayRawData(inputBuf)
        try {
            raw = checkerComprehensiveCheck(checkerRaw, handle.pointer)
        } finally {
            releaseArrayRawData(handle)
        }
        raw
    }
    let errors = IEnumSpellingError(errorsRaw, takeOwnership: true)
    try {
        while (true) {
            let (hr, errorRaw) = enumErrorsNext(errorsRaw)
            if (hr != S_OK) {
                break
            }
            if (errorRaw.isNull()) {
                break
            }
            let error = ISpellingError(errorRaw, takeOwnership: true)
            try {
                handleError(checkerRaw, inputBuf, errorRaw)
            } finally {
                error.close()
            }
        }
    } finally {
        errors.close()
    }
}

// Process a single spelling error: print its action and the delete / replace /
// suggestion details, freeing every caller-owned PWSTR with CoTaskMemFree.
func handleError(checkerRaw: CPointer<Unit>, inputBuf: Array<UInt16>, errorRaw: CPointer<Unit>): Unit {
    let startIndex = Int64(errorStartIndex(errorRaw))
    let length = Int64(errorLength(errorRaw))
    let substring = decodeWideFromPointerSlice(inputBuf, startIndex, length)

    let action = errorCorrectiveAction(errorRaw)
    println(correctiveActionName(action))

    match (action) {
        case d where d == ACTION_DELETE =>
            println("Delete '${substring}'")
        case r where r == ACTION_REPLACE =>
            let replacement = errorReplacement(errorRaw)
            let replacementText = if (replacement.isNull()) {
                ""
            } else {
                unsafe { decodeWideFromPointer(replacement) }
            }
            println("Replace: ${substring} with ${replacementText}")
            ComApis.CoTaskMemFree(CPointer<Unit>(replacement))
        case g where g == ACTION_GET_SUGGESTIONS =>
            emitSuggestions(checkerRaw, substring)
        case _ => ()
    }
}

// Enumerate and print every suggestion for `substring`, freeing each PWSTR.
func emitSuggestions(checkerRaw: CPointer<Unit>, substring: String): Unit {
    let wordBuf = encodeUtf16WithNull(substring)
    let suggestionsRaw = unsafe {
        var raw = CPointer<Unit>()
        let handle = acquireArrayRawData(wordBuf)
        try {
            raw = checkerSuggest(checkerRaw, handle.pointer)
        } finally {
            releaseArrayRawData(handle)
        }
        raw
    }
    let suggestions = IEnumString(suggestionsRaw, takeOwnership: true)
    try {
        while (true) {
            let suggestion = enumStringNext(suggestionsRaw)
            if (suggestion.isNull()) {
                break
            }
            let text = unsafe { decodeWideFromPointer(suggestion) }
            println("Maybe replace: ${substring} with ${text}")
            ComApis.CoTaskMemFree(CPointer<Unit>(suggestion))
        }
    } finally {
        suggestions.close()
    }
}

// Mirror the reference's `{action:?}` debug print of the enum variant.
func correctiveActionName(action: Int32): String {
    match (action) {
        case n where n == ACTION_NONE => "CORRECTIVE_ACTION_NONE"
        case g where g == ACTION_GET_SUGGESTIONS => "CORRECTIVE_ACTION_GET_SUGGESTIONS"
        case r where r == ACTION_REPLACE => "CORRECTIVE_ACTION_REPLACE"
        case d where d == ACTION_DELETE => "CORRECTIVE_ACTION_DELETE"
        case _ => "CORRECTIVE_ACTION(${action})"
    }
}
