package windows_reactor_minimal

import std.collection.*
import std.sync.*
import std.time.*
import windows_reactor.core.*

// ============================================================================
// Group: hooks2
//
// Examples owned by this group (filled into routeHooks2):
//   use_resource, use_resource_retry, use_mutation, use_color_scheme,
//   async_state, context, error_boundary
//
// Contract (see main.cj):
//   routeHooks2(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesHooks2()     -> the example names this group owns, for the banner.
//
// Each example is `func <name>Example(cx: RenderCx): Element` — the root
// component body that App.render(..) drives. The framework hooks live in
// windows_reactor.core: useState / useAsyncState / useResource / useMutation /
// useColorScheme / useContext, plus the errorBoundary + provider primitives.
// ============================================================================

// ─── Equatable list wrapper ─────────────────────────────────────────────────
// useResource<T, D> requires T <: Equatable<T>. The use_resource demo's payload
// is a list of strings; wrap it in an Equatable value so the async-state cell
// can diff it.
struct StringList <: Equatable<StringList> {
    let items: Array<String>
    init(items: Array<String>) { this.items = items }

    public operator func ==(other: StringList): Bool {
        if (items.size != other.items.size) { return false }
        var i = 0
        while (i < items.size) {
            if (items[i] != other.items[i]) { return false }
            i++
        }
        true
    }
    public operator func !=(other: StringList): Bool { !(this == other) }
}

// ─── use_resource ───────────────────────────────────────────────────────────
// Fetch data on a background thread with automatic loading/error/ready states
// and dep-driven refetch: bumping `page` refetches.
func fetchPage(page: Int64): FetchResult<StringList> {
    sleep(Duration.second)
    let out = ArrayList<String>()
    var i = 0
    while (i < 5) {
        out.add("Item ${page * 5 + i + 1} (page ${page + 1})")
        i++
    }
    FetchResult<StringList>.Ok(StringList(out.toArray()))
}

func useResourceExample(cx: RenderCx): Element {
    let (page, setPage) = cx.useState<Int64>(0)

    let items = cx.useResource<StringList, Int64>({ p: Int64 => fetchPage(p) }, page)

    let next = { => setPage.call(page + 1) }
    let prev = { =>
        if (page > 0) {
            setPage.call(page - 1)
        }
    }

    let content: Element = match (items) {
        case ResLoading => ProgressRing.indeterminate().toElement()
        case ResReloading(_) => ProgressRing.indeterminate().toElement()
        case ResReady(data) =>
            let rows = ArrayList<Element>()
            for (item in data.items) {
                rows.add(text_block(item).toElement())
            }
            vstack(rows.toArray()).toElement()
        case ResError(e) => text_block("Error: ${e}").toElement()
        case _ => text_block("...").toElement()
    }

    vstack([
        text_block("Page ${page + 1}").fontSize(24.0).toElement(),
        content,
        hstack([
            button("Previous").enabled(page > 0).onClick(prev).toElement(),
            button("Next").onClick(next).toElement()
        ]).toElement()
    ]).spacing(12.0).toElement()
}

// ─── use_resource_retry ─────────────────────────────────────────────────────
// A distinct retry hook does not exist; retry semantics live inside the
// fetcher closure driven by an `attempt` dep. The fetcher simulates a flaky API
// that fails every 3rd attempt; "Retry"/"Refresh" bump `attempt`, which the
// useResource dep change re-runs.
func fetchWeather(attempt: Int64): FetchResult<String> {
    sleep(600 * Duration.millisecond)
    if (attempt % 3 == 2) {
        return FetchResult<String>.Err("Network timeout - server unreachable")
    }
    FetchResult<String>.Ok("72F Sunny (attempt #${attempt + 1})")
}

func useResourceRetryExample(cx: RenderCx): Element {
    let (attempt, setAttempt) = cx.useState<Int64>(0)

    let weather = cx.useResource<String, Int64>({ a: Int64 => fetchWeather(a) }, attempt)

    let retry = { => setAttempt.call(attempt + 1) }

    let content: Element = match (weather) {
        case ResLoading => ProgressRing.indeterminate().toElement()
        case ResReloading(_) => ProgressRing.indeterminate().toElement()
        case ResReady(data) => text_block(data).toElement()
        case ResError(e) =>
            vstack([
                text_block("Error: ${e}").toElement(),
                button("Retry").onClick(retry).toElement()
            ]).toElement()
        case _ => text_block("...").toElement()
    }

    vstack([
        text_block("Weather Service (flaky API demo)").fontSize(20.0).toElement(),
        text_block("Attempt: ${attempt + 1}").toElement(),
        content,
        button("Refresh").onClick(retry).toElement()
    ]).spacing(8.0).toElement()
}

// ─── use_mutation ───────────────────────────────────────────────────────────
// Fire async write operations with idle/loading/success/error states.
func saveData(name: String): FetchResult<String> {
    sleep(800 * Duration.millisecond)
    if (name.isEmpty()) {
        return FetchResult<String>.Err("Name cannot be empty")
    }
    FetchResult<String>.Ok("Saved '${name}' successfully")
}

func useMutationExample(cx: RenderCx): Element {
    let (name, setName) = cx.useState<String>("Hello")
    let (saveState, saveTrigger) = cx.useMutation<String>()

    let currentName = name
    let triggerSave = saveTrigger
    let onSave = { =>
        let n = currentName
        triggerSave.fire({ => saveData(n) })
    }

    let triggerEmpty = saveTrigger
    let onSaveEmpty = { =>
        triggerEmpty.fire({ => saveData("") })
    }

    let onNameChanged = { v: String => setName.call(v) }

    let status: Element = match (saveState) {
        case MutIdle => text_block("Ready to save").toElement()
        case MutLoading => ProgressRing.indeterminate().toElement()
        case MutSuccess(msg) => text_block(msg).toElement()
        case MutError(e) => text_block("Error: ${e}").toElement()
    }

    let busy = saveState.isLoading()

    vstack([
        text_block("use_mutation Demo").fontSize(24.0).toElement(),
        text_box(name).header("Name").onChanged(onNameChanged).toElement(),
        hstack([
            button("Save").enabled(!busy).onClick(onSave).toElement(),
            button("Save Empty (error)").enabled(!busy).onClick(onSaveEmpty).toElement()
        ]).toElement(),
        status
    ]).spacing(12.0).toElement()
}

// ─── use_color_scheme ───────────────────────────────────────────────────────
// Subscribe the component to theme changes so flipping the system Light/Dark
// setting re-renders the swatch labels below.
func useColorSchemeExample(cx: RenderCx): Element {
    let scheme = cx.useColorScheme()
    let isDark = match (scheme) { case Dark => true; case Light => false }

    let schemeLabel = match (scheme) {
        case Light => "Light"
        case Dark => "Dark"
    }

    let branchText = if (isDark) {
        "dark branch"
    } else {
        "light branch"
    }

    vstack([
        text_block("is_dark_theme = ${isDark}").fontSize(20.0).bold().toElement(),
        text_block("color_scheme  = ${schemeLabel}").fontSize(16.0).toElement(),
        text_block(branchText).fontSize(14.0).foregroundTheme(ThemeRef.PrimaryText).toElement()
    ]).spacing(8.0).toElement()
}

// ─── async_state ────────────────────────────────────────────────────────────
// AsyncSetState is thread-safe — call it from any thread and the value write +
// rerender are auto-marshalled back to the UI thread.
func asyncStateExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useAsyncState<Int64>(0)
    let (busy, setBusy) = cx.useAsyncState<Bool>(false)

    let setCountForThread = setCount
    let setBusyForThread = setBusy
    let current = count
    let bump = { =>
        setBusyForThread.call(true)
        let sc = setCountForThread
        let sb = setBusyForThread
        let cur = current
        let _ = spawn {
            sleep(500 * Duration.millisecond)
            sc.call(cur + 1)
            sb.call(false)
        }
    }

    let statusText = if (busy) {
        "working off the UI thread..."
    } else {
        "idle"
    }

    vstack([
        text_block("count = ${count}").fontSize(24.0).bold().toElement(),
        text_block(statusText).fontSize(12.0).opacity(0.7).toElement(),
        button("Bump (off-thread)").onClick(bump).enabled(!busy).toElement()
    ]).spacing(8.0).toElement()
}

// ─── context ────────────────────────────────────────────────────────────────
// A parent provides a value via a context provision; a nested component reads
// it via cx.useContext without prop-drilling through ancestors.
let themeContext = Context<String>("light")
let contextLeafToken = newComponentTypeToken()

func contextLeaf(_: NoProps, cx: RenderCx): Element {
    let theme = cx.useContext<String>(themeContext)
    let (bg, fg) = match (theme) {
        case "dark" => (Color.rgb(30u8, 30u8, 30u8), Color.rgb(255u8, 255u8, 255u8))
        case "neon" => (Color.rgb(50u8, 200u8, 150u8), Color.rgb(0u8, 0u8, 0u8))
        case _ => (Color.rgb(240u8, 240u8, 240u8), Color.rgb(0u8, 0u8, 0u8))
    }
    border(
        text_block("Leaf sees theme = ${theme}")
            .fontSize(16.0)
            .foreground(Brush.Solid(fg))
            .padding(Thickness.uniform(16.0))
            .toElement()
    )
        .background(Brush.Solid(bg))
        .toElement()
}

func contextExample(cx: RenderCx): Element {
    let (theme, setTheme) = cx.useState<String>("light")

    let pick = { name: String =>
        let setter = setTheme
        let chosen = name
        button(name).onClick({ => setter.call(chosen) }).toElement()
    }

    let tree = vstack([
        text_block("Pick a theme; the leaf below reads it via cx.useContext.").fontSize(12.0).toElement(),
        hstack([pick("light"), pick("dark"), pick("neon")]).spacing(8.0).toElement(),
        border(component<NoProps>(contextLeaf, NoProps(), contextLeafToken))
            .padding(Thickness.uniform(8.0))
            .toElement()
    ])
        .spacing(12.0)
        .padding(Thickness.uniform(16.0))
        .toElement()

    provider(provideContextEq<String>(themeContext, theme), tree)
}

// ─── error_boundary ─────────────────────────────────────────────────────────
// Wraps a subtree and renders a fallback if a descendant throws during render
// (Cangjie maps the reference panic-during-render to a thrown Exception caught
// by the boundary).
struct PanicMaybeProps <: Equatable<PanicMaybeProps> {
    let shouldPanic: Bool
    init(shouldPanic: Bool) { this.shouldPanic = shouldPanic }

    public operator func ==(other: PanicMaybeProps): Bool { shouldPanic == other.shouldPanic }
    public operator func !=(other: PanicMaybeProps): Bool { shouldPanic != other.shouldPanic }
}

let panicMaybeToken = newComponentTypeToken()

func panicMaybe(props: PanicMaybeProps, _: RenderCx): Element {
    if (props.shouldPanic) {
        throw Exception("intentional render failure for the error-boundary demo")
    }
    text_block("Healthy child renders normally.").fontSize(14.0).toElement()
}

func errorBoundaryExample(cx: RenderCx): Element {
    let (shouldPanic, setShouldPanic) = cx.useState<Bool>(false)

    let current = shouldPanic
    let toggle = { => setShouldPanic.call(!current) }

    let boundary = errorBoundary(
        component<PanicMaybeProps>(panicMaybe, PanicMaybeProps(shouldPanic), panicMaybeToken),
        { msg: String =>
            text_block("Fallback UI - child panicked with: ${msg}").fontSize(13.0).toElement()
        }
    )

    let buttonLabel = if (shouldPanic) {
        "Recover (stop panicking)"
    } else {
        "Trigger panic"
    }

    vstack([
        TitleBar("windows_reactor - error_boundary").toElement(),
        text_block(
            "Toggle to make the child panic. The boundary shows a fallback; toggle again to recover."
        ).toElement(),
        button(buttonLabel).onClick(toggle).toElement(),
        boundary
    ]).spacing(12.0).padding(Thickness.uniform(16.0)).toElement()
}

// ─── Registry ────────────────────────────────────────────────────────────────

func routeHooks2(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "use_resource" => Some(("use_resource", useResourceExample))
        case "use_resource_retry" => Some(("use_resource_retry", useResourceRetryExample))
        case "use_mutation" => Some(("use_mutation", useMutationExample))
        case "use_color_scheme" => Some(("use_color_scheme", useColorSchemeExample))
        case "async_state" => Some(("async_state", asyncStateExample))
        case "context" => Some(("Sample", contextExample))
        case "error_boundary" => Some(("windows_reactor - error_boundary", errorBoundaryExample))
        case _ => None
    }
}

func namesHooks2(): Array<String> {
    ["use_resource", "use_resource_retry", "use_mutation", "use_color_scheme",
     "async_state", "context", "error_boundary"]
}
