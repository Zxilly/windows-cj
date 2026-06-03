package windows_reactor_apps

import std.env.getCommandLine
import windows_reactor.core.{RenderCx, Element}
import windows_reactor.winui.{App, reexecWithUiStackIfNeeded}

// ============================================================================
// windows_reactor_apps — single-binary runner for the reactor game apps.
//
// The reference ships one standalone executable per game
// (`fn app(cx) -> Element` + `fn main() { App::new().title(..).render(app) }`).
// Here we collapse all 6 games into ONE executable: each game is a top-level
// function `(RenderCx) -> Element` declared in its own `game_<name>.cj` file,
// and main() selects ONE of them by the first command-line argument, then runs
// it through `App`.
//
//   windows_reactor_apps minesweeper   -> runs the minesweeper game
//   windows_reactor_apps solitaire     -> runs the solitaire game
//   windows_reactor_apps               -> defaults to "minesweeper"
//
// ── Dispatch contract (what each game file fills in) ────────────────────────
//
// Each game file `game_<name>.cj` exposes ONE top-level function:
//
//     public func <name>App(cx: RenderCx): Element
//
// matching the `(RenderCx) -> Element` shape that `App.render(..)` expects.
// main() owns a fixed table mapping each game name to:
//       - its window title   -> passed to App.new().title(title)
//       - its body function  -> the `(RenderCx) -> Element` root, passed to .render(..)
//
// The window titles are taken verbatim from each reference app's `main()`.
// On an unknown / missing name, main() prints the 6 game names and returns 1.
// ============================================================================

// One game entry: the window title plus its `(RenderCx) -> Element` body.
struct GameEntry {
    let name: String
    let title: String
    let body: (RenderCx) -> Element

    init(name: String, title: String, body: (RenderCx) -> Element) {
        this.name = name
        this.title = title
        this.body = body
    }
}

// The full game registry. Titles match the reference `main()` of each app.
let GAMES: Array<GameEntry> = [
    GameEntry("minesweeper", "windows_reactor — minesweeper", minesweeperApp),
    GameEntry("solitaire", "Solitaire", solitaireApp),
    GameEntry("dotsweeper", "windows_reactor — dotsweeper", dotsweeperApp),
    GameEntry("tictactoe", "windows_reactor — tictactoe", tictactoeApp),
    GameEntry("notepad", "windows_reactor — notepad", notepadApp),
    GameEntry("diagnostics", "Diagnostics Demo", diagnosticsApp)
]

// Resolve a game name to its entry, or None if no game owns the name.
func resolve(name: String): ?GameEntry {
    for (g in GAMES) {
        if (g.name == name) {
            return Some(g)
        }
    }
    None
}

// Print the usage banner: how to invoke plus every registered game name.
func printAvailable(): Unit {
    println("usage: windows_reactor_apps <game-name>")
    println("")
    println("Unknown or missing game name. Available games:")
    for (g in GAMES) {
        println("  ${g.name}")
    }
}

main(): Int64 {
    // Self-bootstrap a large UI cjthread stack when launched without cjStackSize.
    match (reexecWithUiStackIfNeeded()) {
        case Some(code) => return code
        case None => ()
    }

    // getCommandLine() returns the full command line; on Windows element 0 is
    // the program path and the first user argument (the game name) is at
    // index 1. Default to "minesweeper" when no game name is supplied.
    let argv = getCommandLine()
    let name = if (argv.size > 1) {
        argv[1]
    } else {
        "minesweeper"
    }

    match (resolve(name)) {
        case Some(game) =>
            App.new().title(game.title).render(game.body)
            0
        case None =>
            printAvailable()
            1
    }
}
