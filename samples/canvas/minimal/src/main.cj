package windows_canvas_minimal

import std.env.getCommandLine
import windows_canvas.DrawContext
import windows_reactor.winui.reexecWithUiStackIfNeeded

// ============================================================================
// windows_canvas_minimal — single-binary runner for the canvas example set.
//
// Each example is a draw closure `(DrawContext) -> Unit`; main() selects ONE of
// them by the first command-line argument and runs it through the harness
// (runCanvas), which hosts it in a reactor window via animatedCanvas:
//
//   minimal hello       -> runs the "hello" example
//   minimal clock       -> runs the "clock" example
//   minimal             -> defaults to "hello"
//
// Examples (covering the full reference minimal set):
//   hello, color, lines, shapes, path, text, transform, gradient, brush,
//   bitmap, clock
// Each is registered in EXAMPLES below as (name -> (title, draw)).
// ============================================================================

// One registered example: its window title plus its draw closure factory. The
// factory is called per launch so per-example mutable render state (the frame
// counters in transform / clock, the cached stroke style in clock) is freshly
// created for that run rather than shared as a module global.
struct ExampleEntry {
    let name: String
    let title: String
    let makeDraw: () -> (DrawContext) -> Unit

    init(name: String, title: String, makeDraw: () -> (DrawContext) -> Unit) {
        this.name = name
        this.title = title
        this.makeDraw = makeDraw
    }
}

// The full example registry, in reference order.
let EXAMPLES: Array<ExampleEntry> = [
    ExampleEntry("hello", "Hello Canvas", makeHelloDraw),
    ExampleEntry("color", "Color", makeColorDraw),
    ExampleEntry("lines", "Lines", makeLinesDraw),
    ExampleEntry("shapes", "Shapes", makeShapesDraw),
    ExampleEntry("path", "Path", makePathDraw),
    ExampleEntry("text", "Text", makeTextDraw),
    ExampleEntry("transform", "Transform", makeTransformDraw),
    ExampleEntry("gradient", "Gradient", makeGradientDraw),
    ExampleEntry("brush", "Brush", makeBrushDraw),
    ExampleEntry("bitmap", "Bitmap", makeBitmapDraw),
    ExampleEntry("clock", "Clock", makeClockDraw)
]

func resolve(name: String): ?ExampleEntry {
    for (entry in EXAMPLES) {
        if (entry.name == name) {
            return Some(entry)
        }
    }
    None
}

func printAvailable(): Unit {
    println("usage: windows_canvas_minimal <example-name>")
    println("")
    println("Unknown or missing example name. Available examples:")
    for (entry in EXAMPLES) {
        println("  ${entry.name}")
    }
}

main(): Int64 {
    // Self-bootstrap a large UI cjthread stack when launched without cjStackSize
    // (same as the reactor minimal runner).
    match (reexecWithUiStackIfNeeded()) {
        case Some(code) => return code
        case None => ()
    }

    // getCommandLine()[0] is the program path; the first user argument (the
    // example name) is at index 1. Default to "hello" when none is supplied.
    let argv = getCommandLine()
    let name = if (argv.size > 1) {
        argv[1]
    } else {
        "hello"
    }

    match (resolve(name)) {
        case Some(entry) =>
            runCanvas(entry.title, (entry.makeDraw)())
            0
        case None =>
            printAvailable()
            1
    }
}
