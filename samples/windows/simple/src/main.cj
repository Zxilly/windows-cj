package windows_sample_simple

import windows_sample_simple_bindings.UI.{Colors, Color}
import windows_core.WindowsException

// ============================================================================
// simple — behaviour-equivalent port of the reference sample.
//
// Reads the WinRT static accessor Colors.Red(), which activates the
// Windows.UI.Colors runtime class's IColorsStatics activation factory and
// returns a Windows.UI.Color value struct, then prints that colour's four
// channels (A/R/G/B). The process then exits. This is the simplest possible
// WinRT activation-factory static call.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference writes `windows::UI::Colors::Red()`. In this projection the
//     per-namespace static accessor is a static method on the generated `Colors`
//     class — `Colors.Red()` — which is the exact analogue: it resolves the
//     IColorsStatics activation factory (the factory cache calls
//     CoIncrementMTAUsage internally, so no explicit RoInitialize is required,
//     matching the reference, which also performs no apartment init), invokes
//     the Red property getter through the factory vtbl into an out-parameter,
//     and checks the returned HRESULT.
//   • The reference's fallible call uses `?` to propagate a failed HRESULT out
//     of a `Result`-returning main. Here `Colors.Red()` is already the throwing
//     form: it performs `hr.check()` internally and raises a
//     windows_core.WindowsException on failure, which we catch and surface as a
//     non-zero exit code — the behavioural equivalent of `?` bubbling the error.
//   • Color is an `@C struct` with four UInt8 fields (A, R, G, B); it has no
//     auto-derived debug formatting (no equivalent of the reference's `{:?}`),
//     so the four channels are printed explicitly. The reference prints them as
//     the decimal values of the struct fields; this matches field-for-field.
// ============================================================================

main(): Int64 {
    try {
        let red: Color = Colors.Red()
        // The reference prints `Red: Color { A: 255, R: 255, G: 0, B: 0 }` via
        // the derived debug formatter; reproduce the same field values.
        println("Red: Color { A: ${red.A}, R: ${red.R}, G: ${red.G}, B: ${red.B} }")
    } catch (e: WindowsException) {
        // Mirror the reference propagating a failed HRESULT out of main as a
        // failing exit status.
        eprintln("Colors.Red() failed: ${e}")
        return 1
    }

    return 0
}
