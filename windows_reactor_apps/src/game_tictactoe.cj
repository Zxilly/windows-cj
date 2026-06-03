package windows_reactor_apps

// ============================================================================
// game_tictactoe — Tic-tac-toe game body.
//
// Window title: "windows_reactor — tictactoe" (supplied by main()).
//
// A faithful port of the reference 3x3 tic-tac-toe sample:
//   * Cell / Player / Status model enums + a Game value (board, turn, status).
//   * Pure move/win-detection logic (detectWinner / applyMove / statusLine).
//   * A reactor render tree: a status header, a "New Game" reset button, and a
//     3x3 grid of cell buttons, each with its own click handler capturing the
//     cell index.
//
// State note: the framework's useState<T> requires T <: Equatable<T>, so Game
// is modelled as a value-equality class. applyMove always builds a FRESH Game
// (copying the board) so the existing state value is never mutated in place —
// the setter's == short-circuit and the reconciler both rely on this.
// ============================================================================

import std.collection.*
import windows_reactor.core.*

// ─── Board dimensions ────────────────────────────────────────────────────────

let SIZE: Int64 = 3
let TOTAL: Int64 = SIZE * SIZE

// ─── Cell ────────────────────────────────────────────────────────────────────

enum Cell <: Equatable<Cell> {
    | Empty
    | X
    | O

    func label(): String {
        match (this) {
            case Empty => " "
            case X => "X"
            case O => "O"
        }
    }

    func tag(): Int64 {
        match (this) {
            case Empty => 0
            case X => 1
            case O => 2
        }
    }

    public operator func ==(other: Cell): Bool { tag() == other.tag() }
    public operator func !=(other: Cell): Bool { tag() != other.tag() }
}

// ─── Player ──────────────────────────────────────────────────────────────────

enum Player <: Equatable<Player> {
    | PX
    | PO

    func cell(): Cell {
        match (this) {
            case PX => Cell.X
            case PO => Cell.O
        }
    }

    func next(): Player {
        match (this) {
            case PX => Player.PO
            case PO => Player.PX
        }
    }

    func label(): String {
        match (this) {
            case PX => "X"
            case PO => "O"
        }
    }

    func tag(): Int64 {
        match (this) {
            case PX => 0
            case PO => 1
        }
    }

    public operator func ==(other: Player): Bool { tag() == other.tag() }
    public operator func !=(other: Player): Bool { tag() != other.tag() }
}

// ─── Status ──────────────────────────────────────────────────────────────────

enum Status <: Equatable<Status> {
    | Playing
    | Won(Player)
    | Draw

    public operator func ==(other: Status): Bool {
        match ((this, other)) {
            case (Playing, Playing) => true
            case (Draw, Draw) => true
            case (Won(a), Won(b)) => a == b
            case _ => false
        }
    }

    public operator func !=(other: Status): Bool { !(this == other) }
}

// ─── Game (value-equality state) ─────────────────────────────────────────────

// Holds the board, whose turn it is, and the win/draw status. Equatable by
// value (element-wise board comparison) so it can back useState. Always treat
// instances as immutable: applyMove returns a fresh Game.
class Game <: Equatable<Game> {
    let cells: Array<Cell>
    let turn: Player
    let status: Status

    init(cells: Array<Cell>, turn: Player, status: Status) {
        this.cells = cells
        this.turn = turn
        this.status = status
    }

    static func fresh(): Game {
        Game(Array<Cell>(TOTAL, repeat: Cell.Empty), Player.PX, Status.Playing)
    }

    public operator func ==(other: Game): Bool {
        if (turn != other.turn) { return false }
        if (status != other.status) { return false }
        if (cells.size != other.cells.size) { return false }
        var i = 0
        while (i < cells.size) {
            if (cells[i] != other.cells[i]) { return false }
            i++
        }
        true
    }

    public operator func !=(other: Game): Bool { !(this == other) }
}

// ─── Win lines ───────────────────────────────────────────────────────────────

let LINES: Array<Array<Int64>> = [
    // rows
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    // columns
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    // diagonals
    [0, 4, 8],
    [2, 4, 6]
]

// ─── Pure game logic ─────────────────────────────────────────────────────────

func detectWinner(cells: Array<Cell>): ?Player {
    for (line in LINES) {
        let a = cells[line[0]]
        if (a == Cell.Empty) {
            continue
        }
        if (a == cells[line[1]] && a == cells[line[2]]) {
            return match (a) {
                case X => Some(Player.PX)
                case O => Some(Player.PO)
                // Unreachable: filtered out by the Cell.Empty check above.
                case Empty => None
            }
        }
    }
    None
}

func allFilled(cells: Array<Cell>): Bool {
    for (c in cells) {
        if (c == Cell.Empty) {
            return false
        }
    }
    true
}

func applyMove(game: Game, pos: Int64): ?Game {
    if (pos < 0 || pos >= TOTAL) {
        return None
    }
    if (game.status != Status.Playing) {
        return None
    }
    if (game.cells[pos] != Cell.Empty) {
        return None
    }

    // Build a fresh board so the existing Game value is never mutated.
    let cells = Array<Cell>(TOTAL, repeat: Cell.Empty)
    var i = 0
    while (i < TOTAL) {
        cells[i] = game.cells[i]
        i++
    }
    cells[pos] = game.turn.cell()

    let status = match (detectWinner(cells)) {
        case Some(winner) => Status.Won(winner)
        case None => if (allFilled(cells)) { Status.Draw } else { Status.Playing }
    }

    let turn = if (status == Status.Playing) {
        game.turn.next()
    } else {
        game.turn
    }

    Some(Game(cells, turn, status))
}

func statusLine(game: Game): String {
    match (game.status) {
        case Playing => "Turn: ${game.turn.label()}"
        case Won(p) => "🎉 ${p.label()} wins!"
        case Draw => "It's a draw"
    }
}

// ─── Render ──────────────────────────────────────────────────────────────────

func buildCells(game: Game, set: SetState<Game>): Array<Element> {
    let gameOver = game.status != Status.Playing
    let out = ArrayList<Element>()
    var pos = 0
    while (pos < TOTAL) {
        let cell = game.cells[pos]
        let row = Int32(pos / SIZE)
        let col = Int32(pos % SIZE)

        // Capture the index + a snapshot of the current game for this handler.
        let here = pos
        let snapshot = game
        let setter = set
        let onClick = {
            =>
            match (applyMove(snapshot, here)) {
                case Some(next) => setter.call(next)
                case None => ()
            }
        }

        let disabled = gameOver || cell != Cell.Empty
        out.add(
            button(cell.label())
                .onClick(onClick)
                .backgroundTheme(ThemeRef.SubtleFill)
                .foregroundTheme(ThemeRef.PrimaryText)
                .keyOf("cell-${pos}")
                .hAlign(HorizontalAlignment.Stretch)
                .vAlign(VerticalAlignment.Stretch)
                .enabled(!disabled)
                .gridRow(row)
                .gridColumn(col)
                .toElement()
        )
        pos++
    }
    out.toArray()
}

func buildBoard(game: Game, set: SetState<Game>): Element {
    let rows = Array<GridLength>(SIZE, repeat: GridLength.Star(1.0))
    let cols = Array<GridLength>(SIZE, repeat: GridLength.Star(1.0))
    grid(buildCells(game, set))
        .rowsOf(rows)
        .columnsOf(cols)
        .rowSpacing(4.0)
        .columnSpacing(4.0)
        .width(360.0)
        .height(360.0)
        .hAlign(HorizontalAlignment.Center)
        .toElement()
}

public func tictactoeApp(cx: RenderCx): Element {
    let (game, setGame) = cx.useState<Game>(Game.fresh())

    let resetSetter = setGame
    let onReset = { => resetSetter.call(Game.fresh()) }

    let header = vstack([
        text_block(statusLine(game))
            .bold()
            .fontSize(24.0)
            .hAlign(HorizontalAlignment.Center)
            .toElement(),
        button("New Game")
            .onClick(onReset)
            .hAlign(HorizontalAlignment.Center)
            .toElement()
    ])
        .spacing(8.0)
        .margin(Thickness(0.0, 12.0, 0.0, 4.0))
        .toElement()

    let board = buildBoard(game, setGame)

    let titleBar = TitleBar("windows_reactor — tictactoe").toElement()

    vstack([
        titleBar,
        vstack([header, board]).spacing(12.0).toElement()
    ]).toElement()
}
