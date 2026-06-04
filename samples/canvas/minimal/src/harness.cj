package windows_canvas_minimal

import windows_canvas.{DrawContext, animatedCanvas}
import windows_reactor.core.{RenderCx, Element}
import windows_reactor.winui.{App, Backdrop}

// ============================================================================
// Shared window harness for the canvas minimal examples.
//
// The reference ships one standalone executable per example, each calling
// `canvas_minimal::run(title, draw)` to open a window with `animated_canvas`
// filling the full client area; the example provides only the draw callback.
//
// Here (mirroring the cj reactor_minimal layout) all the examples are collapsed
// into ONE executable: each example is a `(DrawContext) -> Unit` draw closure,
// and main() selects one by command-line arg, then runs it through `runCanvas`.
//
// runCanvas builds the reactor app exactly like the reference `run`:
//   App::new().title(title).backdrop(Backdrop::Mica).render(|cx| animated_canvas(draw).into())
// ============================================================================

// Run a canvas draw closure in a full-client-area reactor window. Mirrors the
// reference canvas_minimal::run.
public func runCanvas(title: String, draw: (DrawContext) -> Unit): Unit {
    App.new()
        .title(title)
        .backdrop(Backdrop.Mica)
        .render({ _cx: RenderCx =>
            animatedCanvas(draw).toElement()
        })
}
