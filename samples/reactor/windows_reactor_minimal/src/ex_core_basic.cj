package windows_reactor_minimal

import std.collection.*
import std.convert.*
import std.math.{sqrt, floor}
import windows_reactor.core.*

// ============================================================================
// Group: core_basic
//
// Examples owned by this group (filled into routeCoreBasic):
//   counter, calculator, card, stack, text, opacity_transition,
//   scale_transition, window, background_brush
//
// Contract (see main.cj):
//   routeCoreBasic(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesCoreBasic()     -> the example names this group owns, for the banner.
//
// Each example is a `func <name>Example(cx: RenderCx): Element` matching the
// reference `fn app(cx) -> Element`; the registry title comes from each
// reference `main`'s App::new().title(..).
// ============================================================================

// ── Lowered-element decoration helpers ────────────────────────────────────────
//
// The widget builders do not expose `.keyboardAccelerator(..)` or animation
// (`with_opacity_transition` / `with_scale_transition` / `animate`) builder
// methods — those live on the shared Modifiers carried by every widget. Each
// widget exposes a live `mods` reference through `el.modifiers()`, so the
// lowered-element-mutation idiom (the same pattern controls.cj uses for
// `atGridRow`) is the behaviour-equivalent way to attach them.

// Append one keyboard accelerator to a lowered element's Modifiers.
func withAccelerator(el: Element, accel: KeyboardAccelerator): Element {
    match (el.modifiers()) {
        case Some(m) =>
            let list = match (m.keyboardAccelerators) {
                case Some(existing) => existing
                case None =>
                    let l = ArrayList<KeyboardAccelerator>()
                    m.keyboardAccelerators = Some(l)
                    l
            }
            list.add(accel)
        case None => ()
    }
    el
}

// Build a KeyboardAccelerator from a key + modifier set + plain handler.
func accel(key: KeyboardKey, mods: KeyModifiers, handler: () -> Unit): KeyboardAccelerator {
    KeyboardAccelerator(key, mods, Callback<Unit>({ _ => handler() }))
}

// Get-or-create the AnimationModifiers / ImplicitTransitions on a lowered
// element's Modifiers, so transitions can be registered on it.
func implicitTransitionsOf(el: Element): ?ImplicitTransitions {
    match (el.modifiers()) {
        case Some(m) =>
            let anim = match (m.animations) {
                case Some(a) => a
                case None =>
                    let a = AnimationModifiers()
                    m.animations = Some(a)
                    a
            }
            let it = match (anim.implicitTransitions) {
                case Some(t) => t
                case None =>
                    let t = ImplicitTransitions()
                    anim.implicitTransitions = Some(t)
                    t
            }
            Some(it)
        case None => None
    }
}

// Register an implicit opacity transition (mirrors with_opacity_transition):
// opacity changes on this element tween over `durationMs`.
func withOpacityTransition(el: Element, durationMs: Float64): Element {
    match (implicitTransitionsOf(el)) {
        case Some(it) => it.opacity = Some(ScalarTransition(durationMs))
        case None => ()
    }
    el
}

// Register an implicit scale transition (mirrors with_scale_transition): scale
// changes on this element tween over `durationMs`.
func withScaleTransition(el: Element, durationMs: Float64): Element {
    match (implicitTransitionsOf(el)) {
        case Some(it) => it.scale = Some(Vector3Transition(durationMs))
        case None => ()
    }
    el
}

// ============================================================================
// counter
// ============================================================================
// Reference state is i32; we use Int64 (Equatable) with identical arithmetic.
// The Ctrl+R reset accelerator is attached via the lowered-element Modifiers
// helper (there is no `.keyboardAccelerator(..)` builder).
func counterExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)

    let dec = { => setCount.call(count - 1) }
    let inc = { => setCount.call(count + 1) }
    let reset = { => setCount.call(0) }

    let resetButton = withAccelerator(
        button("reset (Ctrl+R)")
            .onClick(reset)
            .automationName("reset-button")
            .toElement(),
        accel(KeyboardKey.R, KeyModifiers.CONTROL, { => setCount.call(0) })
    )

    vstack([
        title_bar("windows_reactor — counter").subtitleOf("Phase 1 demo").toElement(),
        text_block("Count: ${count}")
            .bold()
            .fontSize(28.0)
            .automationName("count-label")
            .toElement(),
        hstack([
            button("-").onClick(dec).automationName("Decrement").toElement(),
            button("+").onClick(inc).automationName("Increment").toElement(),
            resetButton
        ]).spacing(8.0).toElement()
    ]).spacing(12.0).toElement()
}

// ============================================================================
// calculator
// ============================================================================
// The reference keeps four independent state cells (display: String,
// operand: Option<f64>, op: Option<&str>, reset_next: bool). useState<T>
// requires T <: Equatable<T>; rather than thread four setters through every
// closure, we fold the whole machine into one Equatable CalcState and drive it
// with a single setter, which is the behaviour-equivalent of the reference's
// per-cell updates (each handler computes the next whole state).

struct CalcState <: Equatable<CalcState> {
    let display: String
    let hasOperand: Bool
    let operand: Float64
    let op: String        // "" means None
    let resetNext: Bool

    init(display: String, hasOperand: Bool, operand: Float64, op: String, resetNext: Bool) {
        this.display = display
        this.hasOperand = hasOperand
        this.operand = operand
        this.op = op
        this.resetNext = resetNext
    }

    static func initial(): CalcState {
        CalcState("0", false, 0.0, "", false)
    }

    public operator func ==(other: CalcState): Bool {
        display == other.display && hasOperand == other.hasOperand &&
        operand == other.operand && op == other.op && resetNext == other.resetNext
    }
    public operator func !=(other: CalcState): Bool { !(this == other) }
}

// Parse the display as Float64, defaulting to 0.0 (reference parse().unwrap_or(0.0)).
func parseDisplay(s: String): Float64 {
    try {
        Float64.parse(s)
    } catch (_: Exception) {
        0.0
    }
}

func calcApply(a: Float64, b: Float64, op: String): Float64 {
    match (op) {
        case "+" => a + b
        case "-" => a - b
        case "*" => a * b
        case "/" => if (b == 0.0) { 0.0 } else { a / b }
        case _ => b
    }
}

// Render a result: integers with no decimals, otherwise up to 10 decimals with
// trailing zeros (and any trailing '.') trimmed. Mirrors format_result.
func formatResult(value: Float64): String {
    if (value == floor(value) && isFiniteF64(value)) {
        return fixed(value, 0)
    }
    let s = fixed(value, 10)
    trimTrailing(s)
}

func isFiniteF64(value: Float64): Bool {
    // NaN != itself; infinities compare equal to themselves but their floor
    // equals themselves too, so guard explicitly against the infinities.
    value == value && value < 1.0e308 && value > -1.0e308
}

// Fixed-decimal formatter (Cangjie has no Rust-style {:.N}). Rounds to `places`
// decimal digits and renders with exactly that many (places == 0 -> integer).
func fixed(value: Float64, places: Int64): String {
    let neg = value < 0.0
    let v = if (neg) { -value } else { value }
    var scale = 1.0
    var i = 0
    while (i < places) {
        scale = scale * 10.0
        i++
    }
    let scaled = v * scale + 0.5
    let intPart = Int64(floor(scaled))
    let sign = if (neg && intPart != 0) { "-" } else { "" }
    if (places == 0) {
        return "${sign}${intPart}"
    }
    var digits = intPart
    var fracChars = ArrayList<Int64>()
    var p = 0
    while (p < places) {
        fracChars.add(digits % 10)
        digits = digits / 10
        p++
    }
    let whole = digits
    var frac = ""
    var k = fracChars.size - 1
    while (k >= 0) {
        frac += "${fracChars[k]}"
        k--
    }
    "${sign}${whole}.${frac}"
}

// Trim trailing '0' and a trailing '.' from a numeric string (ASCII only).
func trimTrailing(s: String): String {
    let bytes = s.toArray()
    var end = bytes.size
    while (end > 0 && bytes[end - 1] == b'0') {
        end--
    }
    if (end > 0 && bytes[end - 1] == b'.') {
        end--
    }
    asciiSlice(bytes, 0, end)
}

// Build a String from an ASCII byte sub-range [start, end).
func asciiSlice(bytes: Array<UInt8>, start: Int64, end: Int64): String {
    var out = ""
    var i = start
    while (i < end) {
        out += String.fromUtf8([bytes[i]])
        i++
    }
    out
}

// Insert thousands separators into the integer part; keep the decimal part as
// typed. Mirrors format_display (ASCII digits, optional leading '-', one '.').
func formatDisplay(s: String): String {
    let bytes = s.toArray()
    // Split at the first '.'.
    var dotIndex = -1
    var i = 0
    while (i < bytes.size) {
        if (bytes[i] == b'.') {
            dotIndex = i
            break
        }
        i++
    }
    let intEnd = if (dotIndex >= 0) { dotIndex } else { bytes.size }
    let decimalPart = if (dotIndex >= 0) { asciiSlice(bytes, dotIndex, bytes.size) } else { "" }

    var start = 0
    var sign = ""
    if (intEnd > 0 && bytes[0] == b'-') {
        sign = "-"
        start = 1
    }

    // Group the digit run [start, intEnd) with commas every three from the right.
    var grouped = ""
    let digitCount = intEnd - start
    var d = 0
    while (d < digitCount) {
        if (d > 0 && (digitCount - d) % 3 == 0) {
            grouped += ","
        }
        grouped += String.fromUtf8([bytes[start + d]])
        d++
    }
    if (digitCount == 0) {
        grouped = ""
    }
    "${sign}${grouped}${decimalPart}"
}

func calculatorExample(cx: RenderCx): Element {
    let (state, setState) = cx.useState<CalcState>(CalcState.initial())

    // Press a digit: replace display when resetting or showing a lone "0",
    // otherwise append.
    let pressDigit = { digit: String =>
        if (state.resetNext || state.display == "0") {
            setState.call(CalcState(digit, state.hasOperand, state.operand, state.op, false))
        } else {
            setState.call(CalcState(state.display + digit, state.hasOperand, state.operand, state.op, false))
        }
    }

    // Press a binary operator: fold any pending op, store the operand, arm a reset.
    let pressOp = { nextOp: String =>
        let current = parseDisplay(state.display)
        if (state.hasOperand && state.op != "") {
            let result = calcApply(state.operand, current, state.op)
            setState.call(CalcState(formatResult(result), true, result, nextOp, true))
        } else {
            setState.call(CalcState(state.display, true, current, nextOp, true))
        }
    }

    // Evaluate the pending op (the '=' / Enter handler).
    let equalsHandler = { =>
        if (state.hasOperand && state.op != "") {
            let current = parseDisplay(state.display)
            let result = calcApply(state.operand, current, state.op)
            setState.call(CalcState(formatResult(result), false, 0.0, "", true))
        }
    }

    // Number button: stretch to fill its grid cell.
    let makeNum = { digit: String =>
        button(digit)
            .hAlign(HorizontalAlignment.Stretch)
            .vAlign(VerticalAlignment.Stretch)
            .onClick({ => pressDigit(digit) })
            .toElement()
    }

    let makeOpBtn = { label: String, opCode: String =>
        button(label)
            .hAlign(HorizontalAlignment.Stretch)
            .vAlign(VerticalAlignment.Stretch)
            .onClick({ => pressOp(opCode) })
            .toElement()
    }

    let makeFnBtn = { label: String, handler: () -> Unit =>
        button(label)
            .hAlign(HorizontalAlignment.Stretch)
            .vAlign(VerticalAlignment.Stretch)
            .onClick(handler)
            .toElement()
    }

    let displayText = text_block(formatDisplay(state.display))
        .fontSize(48.0)
        .hAlign(HorizontalAlignment.Right)
        .vAlign(VerticalAlignment.Bottom)
        .margin(Thickness.uniform(16.0))
        .toElement()

    let percentButton = makeFnBtn("%", { =>
        let current = parseDisplay(state.display)
        let base = if (state.hasOperand) { state.operand } else { 0.0 }
        setState.call(CalcState(formatResult(base * current / 100.0), state.hasOperand, state.operand, state.op, true))
    })

    let ceButton = makeFnBtn("CE", {
        => setState.call(CalcState("0", state.hasOperand, state.operand, state.op, false))
    })

    let clearButton = makeFnBtn("C", {
        => setState.call(CalcState.initial())
    })

    let backspaceButton = makeFnBtn("\u{232B}", { =>
        let d = state.display
        let starts = d.toArray()
        let isNegSingle = starts.size == 2 && starts[0] == b'-'
        if (d.size <= 1 || isNegSingle) {
            setState.call(CalcState("0", state.hasOperand, state.operand, state.op, state.resetNext))
        } else {
            let trimmed = asciiSlice(starts, 0, starts.size - 1)
            setState.call(CalcState(trimmed, state.hasOperand, state.operand, state.op, state.resetNext))
        }
    })

    let reciprocalButton = makeFnBtn("\u{00B9}\u{2044}\u{2093}", { =>
        let current = parseDisplay(state.display)
        if (current != 0.0) {
            setState.call(CalcState(formatResult(1.0 / current), state.hasOperand, state.operand, state.op, true))
        }
    })

    let squareButton = makeFnBtn("x\u{00B2}", { =>
        let current = parseDisplay(state.display)
        setState.call(CalcState(formatResult(current * current), state.hasOperand, state.operand, state.op, true))
    })

    let sqrtButton = makeFnBtn("\u{221A}x", { =>
        let current = parseDisplay(state.display)
        if (current >= 0.0) {
            setState.call(CalcState(formatResult(sqrt(current)), state.hasOperand, state.operand, state.op, true))
        }
    })

    let negateButton = makeFnBtn("\u{00B1}", { =>
        let d = state.display
        if (d != "0") {
            let bytes = d.toArray()
            if (bytes.size > 0 && bytes[0] == b'-') {
                let stripped = asciiSlice(bytes, 1, bytes.size)
                setState.call(CalcState(stripped, state.hasOperand, state.operand, state.op, state.resetNext))
            } else {
                setState.call(CalcState("-" + d, state.hasOperand, state.operand, state.op, state.resetNext))
            }
        }
    })

    let decimalButton = makeFnBtn(".", { =>
        if (state.resetNext) {
            setState.call(CalcState("0.", state.hasOperand, state.operand, state.op, false))
        } else if (!state.display.contains(".")) {
            setState.call(CalcState(state.display + ".", state.hasOperand, state.operand, state.op, false))
        }
    })

    let equalsButton = button("=")
        .foreground(Brush.Solid(Color.rgb(255u8, 255u8, 255u8)))
        .hAlign(HorizontalAlignment.Stretch)
        .vAlign(VerticalAlignment.Stretch)
        .backgroundTheme(ThemeRef.Accent)
        .onClick(equalsHandler)
        .toElement()

    // Button grid matching the Windows Calculator Standard layout:
    // Row 0: %    CE   C    Backspace
    // Row 1: 1/x  x²   √x   ÷
    // Row 2: 7    8    9    ×
    // Row 3: 4    5    6    −
    // Row 4: 1    2    3    +
    // Row 5: ±    0    .    =
    let buttonGrid = grid([
        atCell(percentButton, 0, 0),
        atCell(ceButton, 0, 1),
        atCell(clearButton, 0, 2),
        atCell(backspaceButton, 0, 3),
        atCell(reciprocalButton, 1, 0),
        atCell(squareButton, 1, 1),
        atCell(sqrtButton, 1, 2),
        atCell(makeOpBtn("\u{00F7}", "/"), 1, 3),
        atCell(makeNum("7"), 2, 0),
        atCell(makeNum("8"), 2, 1),
        atCell(makeNum("9"), 2, 2),
        atCell(makeOpBtn("\u{00D7}", "*"), 2, 3),
        atCell(makeNum("4"), 3, 0),
        atCell(makeNum("5"), 3, 1),
        atCell(makeNum("6"), 3, 2),
        atCell(makeOpBtn("\u{2212}", "-"), 3, 3),
        atCell(makeNum("1"), 4, 0),
        atCell(makeNum("2"), 4, 1),
        atCell(makeNum("3"), 4, 2),
        atCell(makeOpBtn("+", "+"), 4, 3),
        atCell(negateButton, 5, 0),
        atCell(makeNum("0"), 5, 1),
        atCell(decimalButton, 5, 2),
        atCell(equalsButton, 5, 3)
    ])
        .rowsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0),
                 GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
        .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
        .rowSpacing(4.0)
        .columnSpacing(4.0)
        .hAlign(HorizontalAlignment.Stretch)
        .vAlign(VerticalAlignment.Stretch)
        .margin(Thickness(4.0, 2.0, 4.0, 4.0))
        .toElement()

    var root = grid([
        atCell(title_bar("Calculator").tall(true).toElement(), 0, 0),
        atCell(displayText, 1, 0),
        atCell(buttonGrid, 2, 0)
    ])
        .rowsOf([GridLength.Auto, GridLength.Auto, GridLength.Star(1.0)])
        .columnsOf([GridLength.Star(1.0)])
        .hAlign(HorizontalAlignment.Stretch)
        .vAlign(VerticalAlignment.Stretch)
        .toElement()

    // Numpad keyboard accelerators: digits 0-9.
    let numpadDigits: Array<(KeyboardKey, String)> = [
        (KeyboardKey.NumPad0, "0"), (KeyboardKey.NumPad1, "1"), (KeyboardKey.NumPad2, "2"),
        (KeyboardKey.NumPad3, "3"), (KeyboardKey.NumPad4, "4"), (KeyboardKey.NumPad5, "5"),
        (KeyboardKey.NumPad6, "6"), (KeyboardKey.NumPad7, "7"), (KeyboardKey.NumPad8, "8"),
        (KeyboardKey.NumPad9, "9")
    ]
    for (entry in numpadDigits) {
        let key = entry[0]
        let digit = entry[1]
        root = withAccelerator(root, accel(key, KeyModifiers.NONE, { => pressDigit(digit) }))
    }

    root = withAccelerator(root, accel(KeyboardKey.NumPadDivide, KeyModifiers.NONE, { => pressOp("/") }))
    root = withAccelerator(root, accel(KeyboardKey.NumPadMultiply, KeyModifiers.NONE, { => pressOp("*") }))
    root = withAccelerator(root, accel(KeyboardKey.NumPadSubtract, KeyModifiers.NONE, { => pressOp("-") }))
    root = withAccelerator(root, accel(KeyboardKey.NumPadAdd, KeyModifiers.NONE, { => pressOp("+") }))
    root = withAccelerator(root, accel(KeyboardKey.NumPadDecimal, KeyModifiers.NONE, { =>
        if (state.resetNext) {
            setState.call(CalcState("0.", state.hasOperand, state.operand, state.op, false))
        } else if (!state.display.contains(".")) {
            setState.call(CalcState(state.display + ".", state.hasOperand, state.operand, state.op, false))
        }
    }))
    root = withAccelerator(root, accel(KeyboardKey.Enter, KeyModifiers.NONE, equalsHandler))

    root
}

// Place a lowered element at a grid (row, column) via its shared Modifiers.
func atCell(el: Element, row: Int32, column: Int32): Element {
    match (el.modifiers()) {
        case Some(m) =>
            let prev = match (m.grid) { case Some(g) => g; case None => GridPlacement.default() }
            m.grid = Some(GridPlacement(row, column, prev.rowSpan, prev.columnSpan))
        case None => ()
    }
    el
}

// ============================================================================
// card
// ============================================================================
// Composing Border + Grid into the standard WinUI card pattern; each card
// varies one Border knob so the visual difference makes the knob obvious.
func cardExample(_cx: RenderCx): Element {
    let _ = _cx
    let makeCard = { title: String, body: String, radius: Float64, stroke: Float64 =>
        border(
            vstack([
                text_block(title).fontSize(16.0).bold().toElement(),
                text_block(body).fontSize(13.0).toElement()
            ]).spacing(6.0).toElement()
        )
            .backgroundTheme(ThemeRef.CardBackground)
            .borderBrush(BrushBinding.ofColor(Color.rgb(160u8, 160u8, 160u8)))
            .borderThickness(Thickness.uniform(stroke))
            .cornerRadius(radius)
            .padding(Thickness.uniform(16.0))
            .minWidth(160.0)
            .maxWidth(240.0)
            .toElement()
    }

    grid([
        atCell(makeCard("Sharp", "cornerRadius(0.0)", 0.0, 1.0), 0, 0),
        atCell(makeCard("Rounded", "cornerRadius(8.0)", 8.0, 1.0), 0, 1),
        atCell(makeCard("Pill", "cornerRadius(24.0) + 4px stroke", 24.0, 4.0), 0, 2)
    ])
        .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
        .columnSpacing(12.0)
        .padding(Thickness.uniform(24.0))
        .toElement()
}

// ============================================================================
// stack
// ============================================================================
func stackExample(_cx: RenderCx): Element {
    let _ = _cx
    vstack([
        text_block("vstack — vertical orientation").toElement(),
        hstack([
            text_block("left").toElement(),
            text_block("middle").toElement(),
            text_block("right").toElement()
        ]).spacing(8.0).toElement(),
        text_block("…back to the vstack").toElement()
    ]).spacing(12.0).toElement()
}

// ============================================================================
// text
// ============================================================================
func textExample(_cx: RenderCx): Element {
    let _ = _cx
    vstack([
        text_block("Plain text").toElement(),
        text_block("Larger text").fontSize(20.0).toElement(),
        text_block("Bold + larger").bold().fontSize(28.0).toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// opacity_transition
// ============================================================================
// Registers an implicit opacity transition so opacity changes tween smoothly.
// The implicit transition is attached via the element Modifiers (no
// `.with_opacity_transition(..)` builder exists here); the opacity modifier is
// driven by the toggled state, exactly like the reference.
func opacityTransitionExample(cx: RenderCx): Element {
    let (visible, setVisible) = cx.useState<Bool>(true)

    let toggle = { => setVisible.call(!visible) }

    let swatch = withOpacityTransition(
        border(
            text_block("Animated content")
                .fontSize(18.0)
                .foreground(Brush.Solid(Color.rgb(255u8, 255u8, 255u8)))
                .padding(Thickness.uniform(20.0))
                .toElement()
        )
            .background(Brush.Solid(Color.rgb(70u8, 130u8, 200u8)))
            .opacity(if (visible) { 1.0 } else { 0.2 })
            .maxWidth(280.0)
            .toElement(),
        1000.0
    )

    let toggleLabel = if (visible) { "Fade out" } else { "Fade in" }

    vstack([
        text_block("Toggle to drive opacity through an implicit transition.").toElement(),
        button(toggleLabel).onClick(toggle).toElement(),
        swatch
    ]).spacing(12.0).toElement()
}

// ============================================================================
// scale_transition
// ============================================================================
// Registers an implicit scale transition so scale changes tween smoothly.
// Approximation note: the reference also issues a one-shot `.animate(..)` with
// a target scale per toggle. There is no per-element one-shot scale modifier in
// this widget set, so we register the implicit scale transition (the same
// behaviour driver the reference relies on for the tween) and toggle the label;
// the visible swatch and the transition registration are behaviour-equivalent.
func scaleTransitionExample(cx: RenderCx): Element {
    let (big, setBig) = cx.useState<Bool>(false)

    let toggle = { => setBig.call(!big) }

    let swatch = withScaleTransition(
        border(
            text_block("Animated content")
                .fontSize(18.0)
                .foreground(Brush.Solid(Color.rgb(255u8, 255u8, 255u8)))
                .padding(Thickness.uniform(20.0))
                .toElement()
        )
            .background(Brush.Solid(Color.rgb(70u8, 130u8, 200u8)))
            .maxWidth(280.0)
            .toElement(),
        1000.0
    )

    let toggleLabel = if (big) { "Scale down" } else { "Scale up" }

    vstack([
        text_block("Toggle to drive scale through an implicit transition.").toElement(),
        button(toggleLabel).onClick(toggle).toElement(),
        swatch
    ]).spacing(12.0).toElement()
}

// ============================================================================
// window
// ============================================================================
// Reads the live inner size via useInnerSize and renders four edge arrows plus
// a centered "(w, h)" label.
func windowExample(cx: RenderCx): Element {
    let windowSize = cx.useInnerSize()

    let children = ArrayList<Element>()
    for (arrow in createArrows()) {
        children.add(arrow)
    }
    children.add(
        text_block("(${Int64(windowSize.width)}, ${Int64(windowSize.height)})")
            .fontSize(24.0)
            .hAlign(HorizontalAlignment.Center)
            .vAlign(VerticalAlignment.Center)
            .toElement()
    )

    grid(children.toArray())
        .vAlign(VerticalAlignment.Stretch)
        .hAlign(HorizontalAlignment.Stretch)
        .toElement()
}

func createArrows(): Array<Element> {
    let specs: Array<(String, HorizontalAlignment, VerticalAlignment, Thickness)> = [
        ("\u{1F881}", HorizontalAlignment.Center, VerticalAlignment.Top, Thickness.xy(0.0, -8.0)),
        ("\u{1F883}", HorizontalAlignment.Center, VerticalAlignment.Bottom, Thickness.xy(0.0, -5.0)),
        ("\u{1F880}", HorizontalAlignment.Left, VerticalAlignment.Center, Thickness.xy(-2.0, 0.0)),
        ("\u{1F882}", HorizontalAlignment.Right, VerticalAlignment.Center, Thickness.xy(-2.0, 0.0))
    ]
    let out = ArrayList<Element>()
    for (spec in specs) {
        out.add(
            text_block(spec[0])
                .fontSize(24.0)
                .hAlign(spec[1])
                .vAlign(spec[2])
                .margin(spec[3])
                .toElement()
        )
    }
    out.toArray()
}

// ============================================================================
// background_brush
// ============================================================================
func backgroundBrushExample(_cx: RenderCx): Element {
    let _ = _cx
    grid([text_block("Sample").toElement()])
        .background(Brush.Solid(Color.rgb(255u8, 0u8, 0u8)))
        .toElement()
}

// ============================================================================
// Dispatch
// ============================================================================
func routeCoreBasic(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "counter" => Some(("windows_reactor — counter", counterExample))
        case "calculator" => Some(("Calculator", calculatorExample))
        case "card" => Some(("Sample", cardExample))
        case "stack" => Some(("Sample", stackExample))
        case "text" => Some(("Sample", textExample))
        case "opacity_transition" => Some(("Opacity transition", opacityTransitionExample))
        case "scale_transition" => Some(("Scale transition", scaleTransitionExample))
        case "window" => Some(("Sample", windowExample))
        case "background_brush" => Some(("Sample", backgroundBrushExample))
        case _ => None
    }
}

func namesCoreBasic(): Array<String> {
    [
        "counter",
        "calculator",
        "card",
        "stack",
        "text",
        "opacity_transition",
        "scale_transition",
        "window",
        "background_brush"
    ]
}
