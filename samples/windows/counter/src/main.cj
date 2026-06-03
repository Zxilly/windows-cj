package windows_sample_counter

import windows_sample_counter_bindings.Win32.System.Performance.{Apis, PDH_HQUERY, PDH_HCOUNTER, PDH_FMT_COUNTERVALUE}
import windows_strings.encodeUtf16WithNull
import std.convert.Formattable

// ============================================================================
// counter — behaviour-equivalent port of the reference sample.
//
// Uses the Performance Data Helper (PDH) API to sample the processor's
// "% Processor Time" for processor 0 once a second and print it with two
// decimals:
//
//   • PdhOpenQueryW       — open an empty PDH query.
//   • PdhAddCounterW      — add the "\\Processor(0)\\% Processor Time" counter.
//   • loop, every second:
//       PdhCollectQueryData          — sample all counters in the query.
//       PdhGetFormattedCounterValue  — read the counter as a PDH_FMT_DOUBLE.
//       print the doubleValue (the union's Float64 member) to two decimals.
//
// This is an intentional infinite loop and never self-terminates, matching the
// reference, whose `loop {}` runs forever.
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no compile-time `w!` wide-literal. The counter path is built at
//     run time as a NUL-terminated UTF-16 buffer via encodeUtf16WithNull and
//     its raw pointer handed to PdhAddCounterW — semantically identical to a
//     `w!` literal. (The Cangjie source uses a single backslash; the wide
//     string passed to PDH is "\Processor(0)\% Processor Time", the same path
//     the reference's escaped literal "\\Processor(0)\\% Processor Time"
//     denotes at run time.)
//   • The reference's `None` szDataSource is a null wide pointer; the `0`
//     dwUserData arguments are typed here as CPointer<Unit> (the ABI is a
//     pointer-sized field), so they become null pointers.
//   • Out-parameters (query/counter handles, the formatted value) are passed by
//     taking the address of a stack value with CPointer<Unit>(CPointer<T>(inout v)).
//   • PDH_FMT_COUNTERVALUE carries an anonymous union; the projection exposes
//     its members as properties, so the doubleValue field is read as
//     value.Anonymous.doubleValue, mirroring the reference's
//     value.Anonymous.doubleValue.
//   • PdhOpenQueryW/PdhAddCounterW return PDH status codes which the reference
//     discards (no `?`); we discard them too. Only the per-iteration
//     PdhGetFormattedCounterValue result is tested against ERROR_SUCCESS (0),
//     exactly as the reference checks `0 == ...`.
// ============================================================================

// PDH_FMT_DOUBLE selects the double-precision formatted value. PDH_FMT is a
// flag wrapper whose PDH_FMT_DOUBLE value is 0x00000200 (512); the facade does
// not re-export the scalar, so the documented value is used directly.
const PDH_FMT_DOUBLE: UInt32 = 512

// ERROR_SUCCESS — PdhGetFormattedCounterValue returns this on success.
const ERROR_SUCCESS: UInt32 = 0

main(): Int64 {
    // Open an empty query. szDataSource = null (live data), dwUserData = 0.
    var query = PDH_HQUERY()
    Apis.PdhOpenQueryW(
        CPointer<UInt16>(),
        CPointer<Unit>(),
        CPointer<Unit>(CPointer<PDH_HQUERY>(inout query))
    )

    // Add the processor-time counter for processor 0.
    let path = encodeUtf16WithNull("\\Processor(0)\\% Processor Time")
    var counter = PDH_HCOUNTER()
    unsafe {
        let pathHandle = acquireArrayRawData(path)
        try {
            Apis.PdhAddCounterW(
                query,
                pathHandle.pointer,
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<PDH_HCOUNTER>(inout counter))
            )
        } finally {
            releaseArrayRawData(pathHandle)
        }
    }

    // Sample and print the counter once a second, forever.
    while (true) {
        sleep(Duration.second)
        Apis.PdhCollectQueryData(query)

        var value = PDH_FMT_COUNTERVALUE()
        let status = Apis.PdhGetFormattedCounterValue(
            counter,
            PDH_FMT_DOUBLE,
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<PDH_FMT_COUNTERVALUE>(inout value))
        )
        if (status == ERROR_SUCCESS) {
            // print(.., flush: true) writes the line and flushes immediately, so
            // each per-second sample appears as it is produced (line-buffered
            // terminal behaviour), matching the reference's println output.
            print(value.Anonymous.doubleValue.format(".2") + "\n", flush: true)
        }
    }

    return 0
}
