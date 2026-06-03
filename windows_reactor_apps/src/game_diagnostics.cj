package windows_reactor_apps

// ============================================================================
// game_diagnostics — Diagnostics demo body.
//
// Reference: apps/examples/diagnostics_demo.rs
// Window title: "Diagnostics Demo" (supplied by main()'s GAMES table).
//
// Demonstrates the panic hook and crash-log behavior. The root component shows
// a status line driven by use_state and two buttons: one that deliberately
// crashes the process, one that proves the UI is still responsive.
//
// ── Paradigm note ───────────────────────────────────────────────────────────
// The reference's "trigger panic" button calls `panic!(..)`. Cangjie is a GC
// language with no `panic!`; the reactor framework deliberately maps panic ->
// thrown Exception (see core/error_boundary.cj: panic_message payload sniffing
// is mirrored by reading Exception.message). The behaviour-equivalent action is
// therefore `throw Exception("..")` from the click handler — an uncaught
// Exception escaping the event dispatch terminates the process exactly as the
// reference's deliberate panic does. The trailing text_blocks describing the
// post-crash artifacts (backtrace / crash log / exit code) are ported verbatim.
// ============================================================================

import windows_reactor.core.*

public func diagnosticsApp(cx: RenderCx): Element {
    let (status, setStatus) = cx.useState<String>("Ready")

    vstack([
        text_block("Diagnostics Demo").fontSize(28.0).bold().toElement(),
        text_block("Demonstrates the panic hook and crash-log behavior.")
            .opacity(0.7)
            .toElement(),
        text_block("Status: ${status}").toElement(),
        button("Trigger panic (process will exit)")
            .onClick({ => throw Exception("Deliberate panic — diagnostics demo") })
            .toElement(),
        button("Increment counter")
            .onClick({ => setStatus.call("Button clicked — app is responsive") })
            .toElement(),
        text_block("After the panic, check:").bold().toElement(),
        text_block("  • stderr for the full backtrace").toElement(),
        text_block("  • %TEMP%/windows-reactor-crash-{pid}.log").toElement(),
        text_block("  • Exit code 101 (echo %ERRORLEVEL%)").toElement()
    ])
        .spacing(8.0)
        .padding(Thickness.uniform(24.0))
        .toElement()
}
