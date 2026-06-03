package windows_reactor_minimal

import std.collection.ArrayList
import std.env.getCommandLine
import windows_reactor.core.{RenderCx, Element}
import windows_reactor.winui.{App, reexecWithUiStackIfNeeded}

// ============================================================================
// windows_reactor_minimal — single-binary runner for the minimal example set.
//
// The reference ships one standalone executable per example
// (`fn app(cx) -> Element` + `fn main() { App::new().title(..).render(app) }`).
// Here we collapse all 93 examples into ONE executable: each example is a
// function `(RenderCx) -> Element`, and main() selects ONE of them by the first
// command-line argument, then runs it through `App`.
//
//   minimal counter        -> runs the "counter" example
//   minimal use_state      -> runs the "use_state" example
//   minimal                -> defaults to "counter"
//
// ── Registry contract (what each group file fills in) ───────────────────────
//
// Examples are partitioned into 11 groups. Each group lives in its own file
// `ex_<group>.cj` and exposes ONE dispatch function:
//
//     func route<Group>(name: String): ?(String, (RenderCx) -> Element)
//
//   • `name` is the example name from the command line (e.g. "counter").
//   • On a hit it returns `Some((windowTitle, componentBody))`:
//       - windowTitle    -> passed to App.new().title(windowTitle)
//       - componentBody  -> the `(RenderCx) -> Element` root, passed to .render(..)
//   • On a miss it returns `None`, letting main() fall through to the next group.
//
// Each group also exposes `names<Group>(): Array<String>` listing the example
// names it owns, so main() can print a usage banner when nothing matches.
//
// main() walks the groups in a fixed order; the first `Some(..)` wins. If no
// group claims the name, main prints the usage banner and returns 1.
// ============================================================================

// The group dispatchers, tried in order. Each is a
// `(String) -> ?(String, (RenderCx) -> Element)`. Declared before any use.
let GROUP_ROUTES: Array<(String) -> ?(String, (RenderCx) -> Element)> = [
    routeCoreBasic,
    routeHooks1,
    routeHooks2,
    routeComponents,
    routeButtons,
    routeInput,
    routeTextEdit,
    routeLayout,
    routeCollections,
    routeNavMenus,
    routeStatusMediaPickers
]

// Name-source functions, one per group, parallel to GROUP_ROUTES. Declared
// before any use.
let GROUP_NAME_SOURCES: Array<() -> Array<String>> = [
    namesCoreBasic,
    namesHooks1,
    namesHooks2,
    namesComponents,
    namesButtons,
    namesInput,
    namesTextEdit,
    namesLayout,
    namesCollections,
    namesNavMenus,
    namesStatusMediaPickers
]

// Resolve an example name to its (title, body) by trying each group in order.
func resolve(name: String): ?(String, (RenderCx) -> Element) {
    for (route in GROUP_ROUTES) {
        match (route(name)) {
            case Some(entry) => return Some(entry)
            case None => ()
        }
    }
    None
}

// Gather the example names every group reports it owns.
func collectNames(): ArrayList<String> {
    let all = ArrayList<String>()
    for (group in GROUP_NAME_SOURCES) {
        for (n in group()) {
            all.add(n)
        }
    }
    all
}

// Print the usage banner: how to invoke plus every registered example name.
func printAvailable(): Unit {
    println("usage: windows_reactor_minimal <example-name>")
    println("")
    println("Unknown or missing example name. Available examples:")
    let names = collectNames()
    if (names.isEmpty()) {
        println("  (none registered yet)")
    } else {
        for (n in names) {
            println("  ${n}")
        }
    }
}

main(): Int64 {
    // Self-bootstrap a large UI cjthread stack when launched without cjStackSize.
    match (reexecWithUiStackIfNeeded()) {
        case Some(code) => return code
        case None => ()
    }

    // getCommandLine() returns the full command line; on Windows element 0 is
    // the program path and the first user argument (the example name) is at
    // index 1. Default to "counter" when no example name is supplied.
    let argv = getCommandLine()
    let name = if (argv.size > 1) {
        argv[1]
    } else {
        "counter"
    }

    match (resolve(name)) {
        case Some((title, body)) =>
            App.new().title(title).render(body)
            0
        case None =>
            printAvailable()
            1
    }
}
