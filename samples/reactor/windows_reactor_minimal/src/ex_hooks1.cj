package windows_reactor_minimal

import windows_reactor.core.*

// ============================================================================
// Group: hooks1
//
// Examples owned by this group (filled into routeHooks1):
//   use_state, use_effect, use_memo, use_ref, use_reducer, use_callback
//
// Contract (see main.cj):
//   routeHooks1(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesHooks1()     -> the example names this group owns, for the banner.
//
// Each <name>Example(cx) is the root component body — a faithful port of the
// reference example's `fn app(cx) -> Element`. The window title is the title
// from that example's `fn main()`.
// ============================================================================

// Equatable "no dependencies" marker. The hooks API requires deps `D <:
// Equatable<D>`; for hooks whose value must stay stable across every render
// (an empty dep list), we pass a constant EmptyDeps value. Two EmptyDeps are
// always equal, so the slot is never invalidated.
struct EmptyDeps <: Equatable<EmptyDeps> {
    init() {}
    public operator func ==(_: EmptyDeps): Bool { true }
    public operator func !=(_: EmptyDeps): Bool { false }
}

// ============================================================================
// use_state
//
// A button increments a counter held in use_state; a label reflects the value.
// ============================================================================
func useStateExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int32>(0)
    let click = { => setCount.call(count + 1) }

    vstack([
        button("Click").onClick(click).toElement(),
        text_block("count = ${count}")
            .fontSize(18.0)
            .bold()
            .toElement()
    ]).toElement()
}

// ============================================================================
// use_effect
//
// Copies `count` into a use_ref cell when its dep changes. Toggling an
// unrelated flag rerenders without running the effect again.
// ============================================================================
func useEffectExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int32>(0)
    let (flag, setFlag) = cx.useState<Bool>(false)

    let lastSeen = cx.useRef<Int32>(0)

    cx.useEffect<Int32>(count, { =>
        lastSeen.value = count
    })

    let dec = { => setCount.call(count - 1) }
    let inc = { => setCount.call(count + 1) }
    let toggle = { => setFlag.call(!flag) }

    vstack([
        text_block("count = ${count}")
            .fontSize(24.0)
            .bold()
            .toElement(),
        text_block("use_effect last observed: ${lastSeen.value}").toElement(),
        hstack([
            button("-").onClick(dec).toElement(),
            button("+").onClick(inc).toElement(),
            // Rerenders without changing effect deps.
            button("toggle unrelated state").onClick(toggle).toElement()
        ]).spacing(8.0).toElement(),
        text_block("unrelated flag = ${flag}")
            .fontSize(12.0)
            .opacity(0.7)
            .toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// use_memo
//
// Memoizes factorial(n) so toggling unrelated state re-renders without
// recomputing. A recompute counter makes the caching visible.
// ============================================================================
func useMemoExample(cx: RenderCx): Element {
    let (n, setN) = cx.useState<Int32>(3)
    let (showHint, setHint) = cx.useState<Bool>(false)

    let recomputes = cx.useRef<Int64>(0)

    let factorial = cx.useMemo<Int64, Int32>(n, { =>
        recomputes.value = recomputes.value + 1
        var product: Int64 = 1
        var i: Int64 = 1
        let upper = Int64(n)
        while (i <= upper) {
            product = product * i
            i = i + 1
        }
        product
    })

    let dec = {
        =>
        let next = n - 1
        setN.call(if (next < 0) { 0 } else { next })
    }
    let inc = {
        =>
        // 20! fits in i64; 21! overflows.
        let next = n + 1
        setN.call(if (next > 20) { 20 } else { next })
    }
    let toggleHint = { => setHint.call(!showHint) }

    let hint = if (showHint) {
        text_block(
            "Toggling this state rerenders, but the memo was skipped — same deps.")
            .opacity(0.7)
            .toElement()
    } else {
        group(Array<Element>())
    }

    vstack([
        text_block("n = ${n},  factorial(n) = ${factorial}").fontSize(18.0).toElement(),
        text_block("memo factory ran ${recomputes.value} time(s) so far")
            .fontSize(12.0)
            .opacity(0.7)
            .toElement(),
        hstack([
            button("-").onClick(dec).toElement(),
            button("+").onClick(inc).toElement(),
            // Rerenders without changing memo deps.
            button("toggle unrelated state").onClick(toggleHint).toElement()
        ]).spacing(8.0).toElement(),
        hint
    ]).spacing(8.0).toElement()
}

// ============================================================================
// use_ref
//
// use_ref holds mutable state that never triggers a rerender on its own.
// Here we count renders without causing an infinite loop.
// ============================================================================
func useRefExample(cx: RenderCx): Element {
    let (clicks, setClicks) = cx.useState<UInt32>(0)

    let renderCount = cx.useRef<UInt64>(0)
    renderCount.value = renderCount.value + 1
    let renders = renderCount.value

    let bump = { => setClicks.call(clicks + 1) }

    vstack([
        text_block("clicks (use_state) = ${clicks}").fontSize(18.0).toElement(),
        text_block("renders (use_ref)  = ${renders}").fontSize(18.0).toElement(),
        button("Click me").onClick(bump).toElement(),
        text_block(
            "The ref counter increments every render; the state counter only on " +
            "button click. Ref mutation never schedules a rerender.")
            .fontSize(12.0)
            .opacity(0.7)
            .toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// use_reducer
//
// A counter driven by a reducer over an Action enum, via use_reducer_fn.
// ============================================================================

// Equatable reducer state (use_reducer_fn requires S <: Equatable<S>).
struct CounterState <: Equatable<CounterState> {
    let count: Int32
    init(count: Int32) { this.count = count }
    public operator func ==(other: CounterState): Bool { count == other.count }
    public operator func !=(other: CounterState): Bool { count != other.count }
}

func counterStateDefault(): CounterState { CounterState(0) }

enum CounterAction {
    | Increment | Decrement | Reset
}

func counterReducer(state: CounterState, action: CounterAction): CounterState {
    match (action) {
        case Increment => CounterState(state.count + 1)
        case Decrement => CounterState(state.count - 1)
        case Reset => counterStateDefault()
    }
}

func useReducerExample(cx: RenderCx): Element {
    let (state, dispatch) = cx.useReducerFn<CounterState, CounterAction>(
        counterReducer, counterStateDefault())

    let inc = { => dispatch.call(CounterAction.Increment) }
    let dec = { => dispatch.call(CounterAction.Decrement) }
    let reset = { => dispatch.call(CounterAction.Reset) }

    vstack([
        text_block("count = ${state.count}")
            .fontSize(24.0)
            .bold()
            .toElement(),
        hstack([
            button("-").onClick(dec).toElement(),
            button("+").onClick(inc).toElement(),
            button("reset").onClick(reset).toElement()
        ]).spacing(8.0).toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// use_callback
//
// Returns a Callback with stable identity across renders for the same deps.
// Both buttons share the same underlying handler.
// ============================================================================
func useCallbackExample(cx: RenderCx): Element {
    let (rerenders, setRerenders) = cx.useState<UInt32>(0)

    let fires = cx.useRef<UInt32>(0)

    let onFire: Callback<Unit> = cx.useCallback<Unit, EmptyDeps>(EmptyDeps(), { _ =>
        fires.value = fires.value + 1
    })

    let fireA = { => onFire.invoke(()) }
    let fireB = { => onFire.invoke(()) }
    let rerender = { => setRerenders.call(rerenders + 1) }

    vstack([
        text_block("callback fired ${fires.value} time(s)").fontSize(18.0).toElement(),
        text_block("forced rerenders = ${rerenders}")
            .fontSize(12.0)
            .opacity(0.7)
            .toElement(),
        hstack([
            button("Fire (A)").onClick(fireA).toElement(),
            button("Fire (B)").onClick(fireB).toElement(),
            // Rerenders without changing callback deps.
            button("Force rerender").onClick(rerender).toElement()
        ]).spacing(8.0).toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// Dispatch
// ============================================================================
func routeHooks1(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "use_state" => Some(("sample", useStateExample))
        case "use_effect" => Some(("use_effect", useEffectExample))
        case "use_memo" => Some(("use_memo", useMemoExample))
        case "use_ref" => Some(("use_ref", useRefExample))
        case "use_reducer" => Some(("use_reducer", useReducerExample))
        case "use_callback" => Some(("use_callback", useCallbackExample))
        case _ => None
    }
}

func namesHooks1(): Array<String> {
    ["use_state", "use_effect", "use_memo", "use_ref", "use_reducer", "use_callback"]
}
