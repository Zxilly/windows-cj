package windows_reactor_apps

// ============================================================================
// game_dotsweeper — a Reactor port of classic Minesweeper.
//
// Window title: "windows_reactor — dotsweeper" (set by main()).
//
// Pure game logic (Board, reveal, toggleFlag, chord, newGame) lives below in
// plain Cangjie. The view wires state to the reactor DSL via useReducer + a
// background-thread elapsed-seconds timer.
//
// Input: left-tap reveals/chords (wired via onClick — fully live), right-tap
// cycles marks, right-press on a revealed cell shows a chord preview (release
// commits, drag cancels). The right-button / pointer interactions are attached
// through the shared Modifiers PointerHandlers surface (the supported idiom);
// see the report for the framework-side note on the pointer-handler backend.
// ============================================================================

import std.collection.*
import std.overflow.*
import std.sync.*
import std.time.*
import windows_reactor.core.*

// ─── Difficulty ────────────────────────────────────────────────────────

enum DifficultyKind {
    | Beginner | Intermediate | Expert

    func tag(): Int64 {
        match (this) {
            case Beginner => 0
            case Intermediate => 1
            case Expert => 2
        }
    }

    func equalsTo(other: DifficultyKind): Bool { tag() == other.tag() }
}

struct Difficulty <: Equatable<Difficulty> {
    let kind: DifficultyKind
    let rows: Int64
    let cols: Int64
    let mines: Int64

    init(kind: DifficultyKind, rows: Int64, cols: Int64, mines: Int64) {
        this.kind = kind
        this.rows = rows
        this.cols = cols
        this.mines = mines
    }

    static func beginner(): Difficulty {
        Difficulty(DifficultyKind.Beginner, 9, 9, 10)
    }
    static func intermediate(): Difficulty {
        Difficulty(DifficultyKind.Intermediate, 16, 16, 40)
    }
    static func expert(): Difficulty {
        Difficulty(DifficultyKind.Expert, 16, 30, 99)
    }

    func displayName(): String {
        match (kind) {
            case Beginner => "Beginner"
            case Intermediate => "Intermediate"
            case Expert => "Expert"
        }
    }

    public operator func ==(other: Difficulty): Bool {
        kind.equalsTo(other.kind) && rows == other.rows &&
        cols == other.cols && mines == other.mines
    }
    public operator func !=(other: Difficulty): Bool { !(this == other) }
}

// ─── Cells & board ────────────────────────────────────────────────────

enum CellMark {
    | NoneMark | Flag | Question

    func tag(): Int64 {
        match (this) {
            case NoneMark => 0
            case Flag => 1
            case Question => 2
        }
    }
    func equalsTo(other: CellMark): Bool { tag() == other.tag() }
}

// A single board cell. Reference type so a board can be cloned by copying out
// fresh cells; value equality drives the AppState equality short-circuit.
class BoardCell {
    var isMine: Bool
    var adjacentMines: Int64
    var isRevealed: Bool
    var mark: CellMark

    init(isMine: Bool, adjacentMines: Int64, isRevealed: Bool, mark: CellMark) {
        this.isMine = isMine
        this.adjacentMines = adjacentMines
        this.isRevealed = isRevealed
        this.mark = mark
    }

    static func emptyHidden(): BoardCell {
        BoardCell(false, 0, false, CellMark.NoneMark)
    }

    func clone(): BoardCell {
        BoardCell(isMine, adjacentMines, isRevealed, mark)
    }

    func equalsTo(other: BoardCell): Bool {
        isMine == other.isMine && adjacentMines == other.adjacentMines &&
        isRevealed == other.isRevealed && mark.equalsTo(other.mark)
    }
}

enum GamePhase {
    | NotStarted | Playing | Won | Lost

    func tag(): Int64 {
        match (this) {
            case NotStarted => 0
            case Playing => 1
            case Won => 2
            case Lost => 3
        }
    }
    func equalsTo(other: GamePhase): Bool { tag() == other.tag() }
}

// Optional (row, col) coordinate. None is the absence of an exploded/preview
// cell; explicit class so it can flow through value equality.
class Coord {
    let row: Int64
    let col: Int64
    init(row: Int64, col: Int64) {
        this.row = row
        this.col = col
    }
    func equalsTo(other: Coord): Bool { row == other.row && col == other.col }
}

func coordEq(a: ?Coord, b: ?Coord): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equalsTo(y)
        case (None, None) => true
        case _ => false
    }
}

// The board. Reference type; every reducer step builds a fresh Board (mirroring
// the reference's by-value Board threading) so equality short-circuiting works.
class Board {
    var difficulty: Difficulty
    var cells: Array<BoardCell>
    var phase: GamePhase
    var explodedAt: ?Coord
    var revealedSafe: Int64
    var flagCount: Int64

    init(difficulty: Difficulty, cells: Array<BoardCell>, phase: GamePhase,
         explodedAt: ?Coord, revealedSafe: Int64, flagCount: Int64) {
        this.difficulty = difficulty
        this.cells = cells
        this.phase = phase
        this.explodedAt = explodedAt
        this.revealedSafe = revealedSafe
        this.flagCount = flagCount
    }

    static func newGame(difficulty: Difficulty): Board {
        let total = difficulty.rows * difficulty.cols
        let cells = Array<BoardCell>(total, { _ => BoardCell.emptyHidden() })
        Board(difficulty, cells, GamePhase.NotStarted, None, 0, 0)
    }

    // Deep clone: fresh BoardCell instances so a mutated clone never aliases the
    // previous render's board.
    func clone(): Board {
        let copy = Array<BoardCell>(cells.size, { i => cells[i].clone() })
        Board(difficulty, copy, phase, explodedAt, revealedSafe, flagCount)
    }

    func rows(): Int64 { difficulty.rows }
    func cols(): Int64 { difficulty.cols }
    func idx(r: Int64, c: Int64): Int64 { r * cols() + c }
    func cell(r: Int64, c: Int64): BoardCell { cells[idx(r, c)] }
    func inBounds(r: Int64, c: Int64): Bool {
        r >= 0 && c >= 0 && r < rows() && c < cols()
    }
    func minesRemaining(): Int64 { difficulty.mines - flagCount }
    func totalSafeCells(): Int64 { rows() * cols() - difficulty.mines }

    // The 8 in-bounds neighbors of (r, c).
    func neighbors(r: Int64, c: Int64): Array<Coord> {
        let out = ArrayList<Coord>()
        var dr = -1
        while (dr <= 1) {
            var dc = -1
            while (dc <= 1) {
                if (!(dr == 0 && dc == 0)) {
                    let nr = r + dr
                    let nc = c + dc
                    if (inBounds(nr, nc)) {
                        out.add(Coord(nr, nc))
                    }
                }
                dc++
            }
            dr++
        }
        out.toArray()
    }

    func equalsTo(other: Board): Bool {
        if (!(difficulty == other.difficulty)) { return false }
        if (!phase.equalsTo(other.phase)) { return false }
        if (!coordEq(explodedAt, other.explodedAt)) { return false }
        if (revealedSafe != other.revealedSafe) { return false }
        if (flagCount != other.flagCount) { return false }
        if (cells.size != other.cells.size) { return false }
        var i = 0
        while (i < cells.size) {
            if (!cells[i].equalsTo(other.cells[i])) { return false }
            i++
        }
        true
    }
}

// ─── RNG (LCG; no external dependency) ─────────────────────────────────

// Mutable LCG state. The reference threaded an &mut Lcg through reveal/chord and
// read back rng.state; here the class is mutated in place and its `state` read
// back into AppState, which is behaviour-equivalent.
class Lcg {
    var state: UInt64

    init(seed: UInt64) {
        this.state = if (seed < 1u64) { 1u64 } else { seed }
    }

    func nextU64(): UInt64 {
        state = state.wrappingMul(6364136223846793005u64).wrappingAdd(1442695040888963407u64)
        state
    }

    // Inclusive range [lo, hi].
    func range(lo: Int64, hi: Int64): Int64 {
        let span = UInt64(hi - lo + 1)
        lo + Int64(nextU64() % span)
    }
}

// Golden-ratio-derived constant used to perturb the RNG seed between games so
// successive boards do not all share the same mine layout.
let RNG_SEED_INCREMENT: UInt64 = 0x9E3779B97F4A7C15u64

// Monotonic per-process counter, mixed into each fresh seed so two boards
// created within the same nanosecond still get distinct layouts.
class SeedCounter {
    var value: UInt64 = 0
    init() {}
    func next(): UInt64 {
        value = value.wrappingAdd(1u64)
        value
    }
}
let seedCounter = SeedCounter()

func freshSeed(): UInt64 {
    // System-time-derived seed (mirrors the reference's time-based seed). The
    // sub-second nanosecond field plus the whole-second time components give a
    // well-spread value; the per-process counter guarantees distinctness.
    let dt = DateTime.nowUTC()
    let nanos = UInt64(dt.nanosecond)
    let secs = UInt64(dt.second) + UInt64(dt.minute) * 60 + UInt64(dt.hour) * 3600
    let mixed = nanos
        .wrappingMul(1000000007u64)
        .wrappingAdd(secs.wrappingMul(2654435761u64))
        .wrappingAdd(seedCounter.next().wrappingMul(RNG_SEED_INCREMENT))
    if (mixed == 0u64) { 0xCAFEBABEDEADBEEFu64 } else { mixed }
}

// ─── Pure reducer functions ───────────────────────────────────────────

// Reveal (row, col). On the first reveal of a fresh board, mines are placed
// avoiding the click and its 8 neighbors (first-click safety). Reveals cascade
// through empty (zero-adjacent) regions. Hitting a mine -> Lost; clearing the
// last safe cell -> Won. Operates on a fresh clone and returns it.
func reveal(boardIn: Board, row: Int64, col: Int64, rng: Lcg): Board {
    var board = boardIn
    if (board.phase.equalsTo(GamePhase.Won) || board.phase.equalsTo(GamePhase.Lost)) {
        return board
    }
    if (row >= board.rows() || col >= board.cols()) {
        return board
    }
    let c = board.cell(row, col)
    if (c.isRevealed || c.mark.equalsTo(CellMark.Flag)) {
        return board
    }

    if (board.phase.equalsTo(GamePhase.NotStarted)) {
        board = placeMinesAvoiding(board, row, col, rng)
    }

    if (board.cell(row, col).isMine) {
        return revealAllMines(board, row, col)
    }

    cascadeReveal(board, row, col)
}

// Cycle the mark on a hidden cell: None -> Flag -> Question -> None.
func toggleFlag(boardIn: Board, row: Int64, col: Int64): Board {
    if (boardIn.phase.equalsTo(GamePhase.Won) || boardIn.phase.equalsTo(GamePhase.Lost)) {
        return boardIn
    }
    if (row >= boardIn.rows() || col >= boardIn.cols()) {
        return boardIn
    }
    let board = boardIn.clone()
    let idx = board.idx(row, col)
    let cell = board.cells[idx]
    if (cell.isRevealed) {
        return board
    }

    let nextMark = match (cell.mark) {
        case NoneMark => CellMark.Flag
        case Flag => CellMark.Question
        case Question => CellMark.NoneMark
    }

    let wasFlag = if (cell.mark.equalsTo(CellMark.Flag)) { 1 } else { 0 }
    let willFlag = if (nextMark.equalsTo(CellMark.Flag)) { 1 } else { 0 }
    let flagDelta = willFlag - wasFlag
    board.cells[idx].mark = nextMark
    var nextCount = board.flagCount + flagDelta
    if (nextCount < 0) { nextCount = 0 }
    board.flagCount = nextCount
    board
}

// Chord reveal at a revealed numbered cell: if the count of flagged neighbors
// equals the cell's adjacentMines, reveal every non-flagged neighbor.
func chord(boardIn: Board, row: Int64, col: Int64, rng: Lcg): Board {
    var board = boardIn
    if (!board.phase.equalsTo(GamePhase.Playing)) {
        return board
    }
    if (row >= board.rows() || col >= board.cols()) {
        return board
    }
    let cell = board.cell(row, col)
    if (!cell.isRevealed || cell.isMine || cell.adjacentMines == 0) {
        return board
    }

    var adjFlags = 0
    for (n in board.neighbors(row, col)) {
        if (board.cell(n.row, n.col).mark.equalsTo(CellMark.Flag)) {
            adjFlags++
        }
    }
    if (adjFlags != cell.adjacentMines) {
        return board
    }

    let targets = ArrayList<Coord>()
    for (n in board.neighbors(row, col)) {
        let nc = board.cell(n.row, n.col)
        if (!nc.isRevealed && !nc.mark.equalsTo(CellMark.Flag)) {
            targets.add(n)
        }
    }
    for (t in targets) {
        board = reveal(board, t.row, t.col, rng)
        if (board.phase.equalsTo(GamePhase.Lost)) {
            return board
        }
    }
    board
}

func placeMinesAvoiding(boardIn: Board, safeRow: Int64, safeCol: Int64, rng: Lcg): Board {
    let board = boardIn.clone()
    let total = board.rows() * board.cols()
    let forbidden = Array<Bool>(total, { _ => false })
    var dr = -1
    while (dr <= 1) {
        var dc = -1
        while (dc <= 1) {
            let r = safeRow + dr
            let c = safeCol + dc
            if (board.inBounds(r, c)) {
                forbidden[r * board.cols() + c] = true
            }
            dc++
        }
        dr++
    }

    let candidates = ArrayList<Int64>()
    var i = 0
    while (i < total) {
        if (!forbidden[i]) {
            candidates.add(i)
        }
        i++
    }
    var picks = board.difficulty.mines
    if (picks > candidates.size) {
        picks = candidates.size
    }

    // Partial Fisher–Yates: shuffle the first `picks` slots.
    var k = 0
    while (k < picks) {
        let j = rng.range(k, candidates.size - 1)
        let tmp = candidates[k]
        candidates[k] = candidates[j]
        candidates[j] = tmp
        k++
    }

    let cols = board.cols()
    // Preserve any pre-first-click marks; only set mine bits and recompute counts.
    let cells = board.cells
    for (cell in cells) {
        cell.isMine = false
        cell.adjacentMines = 0
    }
    var p = 0
    while (p < picks) {
        cells[candidates[p]].isMine = true
        p++
    }

    // Adjacency counts.
    var r = 0
    while (r < board.rows()) {
        var c = 0
        while (c < cols) {
            let ci = r * cols + c
            if (!cells[ci].isMine) {
                var count = 0
                var ddr = -1
                while (ddr <= 1) {
                    var ddc = -1
                    while (ddc <= 1) {
                        if (!(ddr == 0 && ddc == 0)) {
                            let nr = r + ddr
                            let nc = c + ddc
                            if (nr >= 0 && nc >= 0 && nr < board.rows() && nc < cols
                                && cells[nr * cols + nc].isMine) {
                                count++
                            }
                        }
                        ddc++
                    }
                    ddr++
                }
                cells[ci].adjacentMines = count
            }
            c++
        }
        r++
    }

    board.phase = GamePhase.Playing
    board
}

func cascadeReveal(boardIn: Board, startRow: Int64, startCol: Int64): Board {
    let board = boardIn.clone()
    var newReveals = 0
    let queue = ArrayList<Coord>()
    queue.add(Coord(startRow, startCol))
    var head = 0

    while (head < queue.size) {
        let cur = queue[head]
        head++
        let idx = board.idx(cur.row, cur.col)
        let cell = board.cells[idx]
        if (cell.isRevealed || cell.mark.equalsTo(CellMark.Flag) || cell.isMine) {
            continue
        }
        cell.isRevealed = true
        cell.mark = CellMark.NoneMark
        newReveals++

        if (cell.adjacentMines == 0) {
            for (n in board.neighbors(cur.row, cur.col)) {
                queue.add(n)
            }
        }
    }

    board.revealedSafe = board.revealedSafe + newReveals
    if (board.revealedSafe >= board.totalSafeCells()) {
        board.phase = GamePhase.Won
        // Auto-flag remaining mines so the mines-remaining display reads 0.
        for (cell in board.cells) {
            if (cell.isMine && !cell.mark.equalsTo(CellMark.Flag)) {
                cell.mark = CellMark.Flag
                board.flagCount = board.flagCount + 1
            }
        }
    } else {
        board.phase = GamePhase.Playing
    }
    board
}

func revealAllMines(boardIn: Board, explodedRow: Int64, explodedCol: Int64): Board {
    let board = boardIn.clone()
    for (cell in board.cells) {
        if (cell.isMine && !cell.mark.equalsTo(CellMark.Flag)) {
            cell.isRevealed = true
        }
    }
    board.phase = GamePhase.Lost
    board.explodedAt = Some(Coord(explodedRow, explodedCol))
    board
}

// ─── App state ─────────────────────────────────────────────────────────

// useReducer requires AppState <: Equatable<AppState>. Class with deep value
// equality; the updater only re-renders when the next state differs.
class AppState <: Equatable<AppState> {
    var board: Board
    var elapsedSeconds: Int64
    // Center cell of an in-flight chord preview, set on right-press of a
    // revealed numbered cell, cleared on release / pointer-exit. Drives the
    // CoveredPreview skin on the 8 neighbors.
    var chordPreview: ?Coord
    var rngSeed: UInt64

    init(board: Board, elapsedSeconds: Int64, chordPreview: ?Coord, rngSeed: UInt64) {
        this.board = board
        this.elapsedSeconds = elapsedSeconds
        this.chordPreview = chordPreview
        this.rngSeed = rngSeed
    }

    static func initial(difficulty: Difficulty, seed: UInt64): AppState {
        AppState(Board.newGame(difficulty), 0, None, seed)
    }

    public operator func ==(other: AppState): Bool {
        elapsedSeconds == other.elapsedSeconds &&
        rngSeed == other.rngSeed &&
        coordEq(chordPreview, other.chordPreview) &&
        board.equalsTo(other.board)
    }
    public operator func !=(other: AppState): Bool { !(this == other) }
}

// ─── Cell visuals ──────────────────────────────────────────────────────

enum CellSkin {
    | Covered
    // Non-flagged covered cell rendered lighter while the user right-presses the
    // central revealed numbered cell of a chord (see AppState.chordPreview).
    | CoveredPreview
    | RevealedSkin
    | ExplodedMine
    | RevealedMine
    | WrongFlag

    func tag(): Int64 {
        match (this) {
            case Covered => 0
            case CoveredPreview => 1
            case RevealedSkin => 2
            case ExplodedMine => 3
            case RevealedMine => 4
            case WrongFlag => 5
        }
    }
    func equalsTo(other: CellSkin): Bool { tag() == other.tag() }
}

func computeSkin(cell: BoardCell, isLost: Bool, isExploded: Bool, isPreview: Bool): CellSkin {
    if (isLost) {
        if (cell.isMine && isExploded) {
            return CellSkin.ExplodedMine
        }
        if (cell.isMine && cell.isRevealed && !cell.mark.equalsTo(CellMark.Flag)) {
            return CellSkin.RevealedMine
        }
        if (!cell.isMine && cell.mark.equalsTo(CellMark.Flag)) {
            return CellSkin.WrongFlag
        }
    }
    if (cell.isRevealed) {
        CellSkin.RevealedSkin
    } else if (isPreview && !cell.mark.equalsTo(CellMark.Flag)) {
        CellSkin.CoveredPreview
    } else {
        CellSkin.Covered
    }
}

func cellGlyph(skin: CellSkin, cell: BoardCell): String {
    match (skin) {
        case ExplodedMine => "\u{1F4A3}"
        case RevealedMine => "\u{1F4A3}"
        case WrongFlag => "\u{2717}"
        case RevealedSkin =>
            if (cell.adjacentMines > 0) {
                "${cell.adjacentMines}"
            } else {
                ""
            }
        case CoveredPreview =>
            coveredGlyph(cell)
        case Covered =>
            coveredGlyph(cell)
    }
}

func coveredGlyph(cell: BoardCell): String {
    match (cell.mark) {
        case Flag => "\u{1F6A9}"
        case Question => "?"
        case NoneMark => ""
    }
}

// Classic-palette number color, tuned to read against LayerFill in both light
// and dark themes. adjacentMines is at most 8 on a standard board.
func numberColor(n: Int64): Color {
    match (n) {
        case 1 => Color.rgb(0x42u8, 0x9Bu8, 0xE6u8)
        case 2 => Color.rgb(0x4Cu8, 0xAFu8, 0x50u8)
        case 3 => Color.rgb(0xE5u8, 0x57u8, 0x4Bu8)
        case 4 => Color.rgb(0x7Eu8, 0x57u8, 0xC2u8)
        case 5 => Color.rgb(0xABu8, 0x47u8, 0xBCu8)
        case 6 => Color.rgb(0x26u8, 0xA6u8, 0xA4u8)
        case 7 => Color.rgb(0x9Eu8, 0x9Eu8, 0x9Eu8)
        case _ => Color.rgb(0xBDu8, 0xBDu8, 0xBDu8)
    }
}

func explosionRed(): Color { Color.rgb(0xD3u8, 0x2Fu8, 0x2Fu8) }
func coveredFill(): Color { Color.rgb(0xB0u8, 0xB0u8, 0xB0u8) }
func coveredPreviewFill(): Color { Color.rgb(0xD8u8, 0xD8u8, 0xD8u8) }

func cellSize(difficulty: Difficulty): Float64 {
    match (difficulty.kind) {
        case Beginner => 36.0
        case Intermediate => 30.0
        case Expert => 26.0
    }
}

func smiley(phase: GamePhase): String {
    match (phase) {
        case Won => "\u{1F60E}"
        case Lost => "\u{1F635}"
        case _ => "\u{1F642}"
    }
}

// ─── Lowered-element decoration helpers ─────────────────────────────────
//
// The widget builders expose onClick but not the per-element pointer / tap
// surface (onTapped / onRightTapped / onPointerPressed / onPointerReleased /
// onPointerExited). Those live on the shared Modifiers every widget carries
// (Modifiers.pointerHandlers), wired by the reconciler + backend. The
// lowered-element-mutation idiom (same pattern as atCell / withAccelerator in
// the minimal examples) is the supported way to attach them.

func pointerHandlersOf(el: Element): ?PointerHandlers {
    match (el.modifiers()) {
        case Some(m) =>
            match (m.pointerHandlers) {
                case Some(ph) => Some(ph)
                case None =>
                    let ph = PointerHandlers()
                    m.pointerHandlers = Some(ph)
                    Some(ph)
            }
        case None => None
    }
}

func withRightTapped(el: Element, handler: () -> Unit): Element {
    match (pointerHandlersOf(el)) {
        case Some(ph) => ph.onRightTapped = Some(Callback<Unit>({ _ => handler() }))
        case None => ()
    }
    el
}

func withPointerPressed(el: Element, handler: (PointerEventInfo) -> Unit): Element {
    match (pointerHandlersOf(el)) {
        case Some(ph) => ph.onPointerPressed = Some(Callback<PointerEventInfo>(handler))
        case None => ()
    }
    el
}

func withPointerReleased(el: Element, handler: (PointerEventInfo) -> Unit): Element {
    match (pointerHandlersOf(el)) {
        case Some(ph) => ph.onPointerReleased = Some(Callback<PointerEventInfo>(handler))
        case None => ()
    }
    el
}

func withPointerExited(el: Element, handler: () -> Unit): Element {
    match (pointerHandlersOf(el)) {
        case Some(ph) => ph.onPointerExited = Some(Callback<Unit>({ _ => handler() }))
        case None => ()
    }
    el
}

// ─── View helpers ───────────────────────────────────────────────────────

// Per-cell input handlers, passed down so the cell view can wire its pointer
// events without owning the reducer.
class CellHandlers {
    let onReveal: (Int64, Int64) -> Unit
    let onFlag: (Int64, Int64) -> Unit
    let onChord: (Int64, Int64) -> Unit
    let onBeginChordPreview: (Int64, Int64) -> Unit
    let onEndChordPreview: (Bool) -> Unit

    init(onReveal: (Int64, Int64) -> Unit, onFlag: (Int64, Int64) -> Unit,
         onChord: (Int64, Int64) -> Unit, onBeginChordPreview: (Int64, Int64) -> Unit,
         onEndChordPreview: (Bool) -> Unit) {
        this.onReveal = onReveal
        this.onFlag = onFlag
        this.onChord = onChord
        this.onBeginChordPreview = onBeginChordPreview
        this.onEndChordPreview = onEndChordPreview
    }
}

func buildCell(board: Board, chordPreviewCenter: ?Coord, r: Int64, c: Int64,
               size: Float64, handlers: CellHandlers): Element {
    let cell = board.cell(r, c)
    let isExploded = match (board.explodedAt) {
        case Some(co) => co.row == r && co.col == c
        case None => false
    }
    let isLost = board.phase.equalsTo(GamePhase.Lost)
    let isWon = board.phase.equalsTo(GamePhase.Won)
    let isPreview = match (chordPreviewCenter) {
        case Some(p) =>
            absDiff(r, p.row) <= 1 && absDiff(c, p.col) <= 1
        case None => false
    }
    let skin = computeSkin(cell, isLost, isExploded, isPreview)
    let glyph = cellGlyph(skin, cell)

    let chordableHere = cell.isRevealed && cell.adjacentMines > 0
    let coveredHere = !cell.isRevealed && !cell.mark.equalsTo(CellMark.Flag)

    var btn = button(glyph)
        .keyOf("cell-${r}-${c}")
        .width(size)
        .height(size)
        .hAlign(HorizontalAlignment.Stretch)
        .vAlign(VerticalAlignment.Stretch)

    // Foreground: literal colors for the mine / wrong-flag / number skins
    // (these are literal in the reference too); theme references for the
    // question-mark accent and the default primary text (matching the
    // reference ThemeRef::Accent / ThemeRef::PrimaryText).
    btn = applyCellForeground(btn, skin, cell)
    // Background: literal grays for covered cells + explosion red; theme
    // resources (SubtleFill / LayerFill) for the revealed / dead skins.
    btn = applyCellBackground(btn, skin)

    // Left-tap: chord shortcut on revealed numbers, otherwise reveal. Wired to
    // onClick (the live button-click event) so the core game is playable.
    let onReveal = handlers.onReveal
    let onChord = handlers.onChord
    let tapHandler = { =>
        if (isLost || isWon) {
            return
        }
        if (chordableHere) {
            onChord(r, c)
        } else if (!cell.isRevealed) {
            onReveal(r, c)
        }
    }

    var el = btn.onClick(tapHandler).gridRow(Int32(r)).gridColumn(Int32(c)).toElement()

    // The left-tap reveal/chord is carried by onClick above (the live Button
    // Click event), so we do NOT also attach onTapped — that would double-fire
    // the left action once the pointer-handler backend is implemented. The
    // remaining pointer surface (distinct from Click) wires the right-button
    // interactions: right-tap cycles the mark, right-press begins a chord
    // preview, release commits it, pointer-exit cancels it.
    let onFlag = handlers.onFlag
    let rtapHandler = { =>
        if (isLost || isWon || chordableHere) {
            return
        }
        if (coveredHere || cell.mark.equalsTo(CellMark.Flag) || cell.mark.equalsTo(CellMark.Question)) {
            onFlag(r, c)
        }
    }
    el = withRightTapped(el, rtapHandler)

    let onBegin = handlers.onBeginChordPreview
    el = withPointerPressed(el, { info: PointerEventInfo =>
        if (isLost || isWon) {
            return
        }
        if (info.isRightButtonPressed && chordableHere) {
            onBegin(r, c)
        }
    })

    let onEnd = handlers.onEndChordPreview
    el = withPointerReleased(el, { info: PointerEventInfo =>
        if (isLost || isWon) {
            return
        }
        if (!info.isRightButtonPressed) {
            onEnd(true)
        }
    })

    el = withPointerExited(el, { => onEnd(false) })

    el
}

// Apply the per-skin foreground, mirroring the reference:
//   ExplodedMine            -> literal white
//   WrongFlag               -> literal explosion red
//   Revealed with a number  -> literal classic number color
//   Covered question mark    -> ThemeRef::Accent
//   everything else          -> ThemeRef::PrimaryText
func applyCellForeground(b: Button, skin: CellSkin, cell: BoardCell): Button {
    if (skin.equalsTo(CellSkin.ExplodedMine)) {
        return b.foreground(Brush.Solid(Color.rgb(0xFFu8, 0xFFu8, 0xFFu8)))
    }
    if (skin.equalsTo(CellSkin.WrongFlag)) {
        return b.foreground(Brush.Solid(explosionRed()))
    }
    if (skin.equalsTo(CellSkin.RevealedSkin) && cell.adjacentMines > 0) {
        return b.foreground(Brush.Solid(numberColor(cell.adjacentMines)))
    }
    let isCovered = skin.equalsTo(CellSkin.Covered) || skin.equalsTo(CellSkin.CoveredPreview)
    if (isCovered && cell.mark.equalsTo(CellMark.Question)) {
        return b.foregroundTheme(ThemeRef.Accent)
    }
    b.foregroundTheme(ThemeRef.PrimaryText)
}

// Apply the per-skin background. ExplodedMine uses literal explosion red; the
// other skins map onto theme resources where the reference used ThemeRef, and
// the two covered skins use literal grays.
func applyCellBackground(b: Button, skin: CellSkin): Button {
    match (skin) {
        case ExplodedMine => b.background(Brush.Solid(explosionRed()))
        case RevealedMine => b.backgroundTheme(ThemeRef.SubtleFill)
        case WrongFlag => b.backgroundTheme(ThemeRef.SubtleFill)
        case RevealedSkin => b.backgroundTheme(ThemeRef.LayerFill)
        case CoveredPreview => b.background(Brush.Solid(coveredPreviewFill()))
        case Covered => b.background(Brush.Solid(coveredFill()))
    }
}

func absDiff(a: Int64, b: Int64): Int64 {
    if (a >= b) { a - b } else { b - a }
}

func buildBoard(board: Board, chordPreviewCenter: ?Coord, handlers: CellHandlers): Element {
    let size = cellSize(board.difficulty)
    let rows = board.rows()
    let cols = board.cols()

    let children = ArrayList<Element>()
    var pos = 0
    let total = rows * cols
    while (pos < total) {
        let r = pos / cols
        let c = pos % cols
        children.add(buildCell(board, chordPreviewCenter, r, c, size, handlers))
        pos++
    }

    let rowTracks = Array<GridLength>(rows, { _ => GridLength.Pixel(size) })
    let colTracks = Array<GridLength>(cols, { _ => GridLength.Pixel(size) })

    let g = grid(children.toArray())
        .rowsOf(rowTracks)
        .columnsOf(colTracks)
        .toElement()

    border(g)
        .backgroundTheme(ThemeRef.LayerFill)
        .padding(Thickness.uniform(1.0))
        .hAlign(HorizontalAlignment.Center)
        .toElement()
}

// Red-on-black three-digit LED-style display. Negative values render as -NN
// (sign + 2 digits) to fit the 3-character slot.
func ledDisplay(value: Int64): Element {
    var clamped = value
    if (clamped < -99) { clamped = -99 }
    if (clamped > 999) { clamped = 999 }
    let text = if (clamped < 0) {
        "-${padZeros(-clamped, 2)}"
    } else {
        padZeros(clamped, 3)
    }
    border(
        text_block(text)
            .fontSize(22.0)
            .bold()
            .foreground(Brush.Solid(Color.rgb(0xFFu8, 0x3Bu8, 0x30u8)))
            .hAlign(HorizontalAlignment.Center)
            .vAlign(VerticalAlignment.Center)
            .toElement()
    )
        .background(Brush.Solid(Color.rgb(0x1Au8, 0x00u8, 0x00u8)))
        .padding(Thickness.xy(8.0, 2.0))
        .minWidth(64.0)
        .toElement()
}

// Left-pad a non-negative integer to `width` digits with leading zeros.
func padZeros(value: Int64, width: Int64): String {
    "${value}".padStart(width, padding: "0")
}

func statusSubtitle(state: AppState): String {
    match (state.board.phase) {
        case Won => "You won in ${state.elapsedSeconds}s!"
        case Lost => "Boom! Press \u{1F642} to try again."
        case Playing => "${state.board.difficulty.displayName()} — ${state.elapsedSeconds}s"
        case NotStarted => state.board.difficulty.displayName()
    }
}

// ─── Timer cancellation cell ────────────────────────────────────────────

// Shared flag the timer effect's cleanup flips to stop the background tick loop
// (replaces dropping the reference DispatcherTimer). A class so the spawned
// thread and the cleanup closure share one mutable instance.
class TimerCancel {
    var cancelled: Bool = false
    init() {}
}

// Equatable dep wrapper for the timer effect (it must re-run only when the
// should-tick flag changes).
struct TickDep <: Equatable<TickDep> {
    let shouldTick: Bool
    init(shouldTick: Bool) { this.shouldTick = shouldTick }
    public operator func ==(other: TickDep): Bool { shouldTick == other.shouldTick }
    public operator func !=(other: TickDep): Bool { shouldTick != other.shouldTick }
}

// ─── The component ──────────────────────────────────────────────────────

public func dotsweeperApp(cx: RenderCx): Element {
    let (state, update) = cx.useReducer<AppState>(
        AppState.initial(Difficulty.beginner(), freshSeed()))

    // Left-tap on a covered cell -> reveal.
    let onReveal = { r: Int64, c: Int64 =>
        update.call({ s: AppState =>
            let rng = Lcg(s.rngSeed)
            let nextBoard = reveal(s.board, r, c, rng)
            AppState(nextBoard, s.elapsedSeconds, None, rng.state)
        })
    }

    // Right-tap on a covered cell -> cycle the flag/question mark.
    let onFlag = { r: Int64, c: Int64 =>
        update.call({ s: AppState =>
            let nextBoard = toggleFlag(s.board, r, c)
            AppState(nextBoard, s.elapsedSeconds, s.chordPreview, s.rngSeed)
        })
    }

    // Left-tap on a revealed number -> chord.
    let onChord = { r: Int64, c: Int64 =>
        update.call({ s: AppState =>
            let rng = Lcg(s.rngSeed)
            let nextBoard = chord(s.board, r, c, rng)
            AppState(nextBoard, s.elapsedSeconds, None, rng.state)
        })
    }

    // Right-press on a revealed number -> start chord preview.
    let onBeginChordPreview = { r: Int64, c: Int64 =>
        update.call({ s: AppState =>
            AppState(s.board, s.elapsedSeconds, Some(Coord(r, c)), s.rngSeed)
        })
    }

    // Pointer release / exit -> commit the preview as a chord if `commit` is
    // true (release inside the cell), otherwise just cancel it.
    let onEndChordPreview = { commit: Bool =>
        update.call({ s: AppState =>
            match (s.chordPreview) {
                case Some(co) =>
                    if (commit) {
                        let rng = Lcg(s.rngSeed)
                        let nextBoard = chord(s.board, co.row, co.col, rng)
                        AppState(nextBoard, s.elapsedSeconds, None, rng.state)
                    } else {
                        AppState(s.board, s.elapsedSeconds, None, s.rngSeed)
                    }
                case None =>
                    AppState(s.board, s.elapsedSeconds, None, s.rngSeed)
            }
        })
    }

    let onReset = { =>
        update.call({ s: AppState =>
            let diff = s.board.difficulty
            AppState(Board.newGame(diff), 0, None, s.rngSeed.wrappingAdd(RNG_SEED_INCREMENT))
        })
    }

    let onNewGame = { d: Difficulty =>
        update.call({ s: AppState =>
            AppState(Board.newGame(d), 0, None, s.rngSeed.wrappingAdd(RNG_SEED_INCREMENT))
        })
    }

    // ── Timer effect ────────────────────────────────────────────────────
    // The reference used a 1s DispatcherTimer. There is no DispatcherTimer here,
    // so we approximate with a background thread that marshals a 1s tick onto the
    // UI thread (where mutating the reducer cell + requesting a rerender is safe),
    // guarded by a cancellation flag the effect cleanup flips. Behaviour-
    // equivalent: elapsed seconds advance once per second while Playing.
    let shouldTick = state.board.phase.equalsTo(GamePhase.Playing)
    let marshaller = cx.useUiMarshaller()
    let timerUpdate = update
    cx.useEffectWithCleanup<TickDep>(TickDep(shouldTick), { =>
        if (!shouldTick) {
            return Option<() -> Unit>.None
        }
        let cancel = TimerCancel()
        let m = marshaller
        let u = timerUpdate
        let _ = spawn {
            while (!cancel.cancelled) {
                sleep(Duration.second)
                if (cancel.cancelled) {
                    break
                }
                let _ = m.dispatch({ =>
                    u.call({ s: AppState =>
                        if (s.board.phase.equalsTo(GamePhase.Playing)) {
                            var secs = s.elapsedSeconds + 1
                            if (secs > 999) { secs = 999 }
                            AppState(s.board, secs, s.chordPreview, s.rngSeed)
                        } else {
                            s
                        }
                    })
                })
            }
        }
        Option<() -> Unit>.Some({ => cancel.cancelled = true })
    })

    // ── Header: mines-remaining LED · smiley · timer LED ──────────────────
    let smileyButton = button(smiley(state.board.phase))
        .onClick(onReset)
        .width(56.0)
        .height(40.0)
        .hAlign(HorizontalAlignment.Center)
        .toElement()

    let statusPanel = hstack([
        withHAlign(ledDisplay(state.board.minesRemaining()), HorizontalAlignment.Left),
        smileyButton,
        withHAlign(ledDisplay(state.elapsedSeconds), HorizontalAlignment.Right)
    ])
        .spacing(16.0)
        .padding(Thickness.xy(12.0, 8.0))
        .hAlign(HorizontalAlignment.Center)
        .toElement()

    let statusCard = border(statusPanel)
        .backgroundTheme(ThemeRef.LayerFill)
        .padding(Thickness.xy(2.0, 2.0))
        .hAlign(HorizontalAlignment.Center)
        .margin(Thickness(0.0, 12.0, 0.0, 4.0))
        .toElement()

    // ── Toolbar: difficulty buttons ───────────────────────────────────────
    let mkDiff = { label: String, d: Difficulty =>
        var b = button(label).onClick({ => onNewGame(d) })
        if (state.board.difficulty.kind.equalsTo(d.kind)) {
            b = b.foregroundTheme(ThemeRef.Accent)
        }
        b.toElement()
    }

    let toolbar = hstack([
        mkDiff("Beginner", Difficulty.beginner()),
        mkDiff("Intermediate", Difficulty.intermediate()),
        mkDiff("Expert", Difficulty.expert())
    ])
        .spacing(8.0)
        .hAlign(HorizontalAlignment.Center)
        .toElement()

    // ── Board ──────────────────────────────────────────────────────────────
    let cellHandlers = CellHandlers(onReveal, onFlag, onChord, onBeginChordPreview, onEndChordPreview)
    let boardView = buildBoard(state.board, state.chordPreview, cellHandlers)
    let boardWrapped = withMargin(boardView, Thickness(0.0, 8.0, 0.0, 12.0))

    // ── Compose ──────────────────────────────────────────────────────────
    let titleBar = title_bar("windows_reactor — dotsweeper")
        .subtitleOf(statusSubtitle(state))
        .toElement()

    vstack([
        titleBar,
        vstack([
            statusCard,
            toolbar,
            boardWrapped
        ]).spacing(8.0).toElement()
    ]).toElement()
}

// Apply a margin to a lowered element via its shared Modifiers (the
// board-wrapper margin the reference set with .margin(..)).
func withMargin(el: Element, t: Thickness): Element {
    match (el.modifiers()) {
        case Some(m) => m.margin = Some(t)
        case None => ()
    }
    el
}

// Set horizontalAlignment on a lowered element via its Modifiers (the reference
// set per-LED hAlign so the displays pin to the panel edges).
func withHAlign(el: Element, a: HorizontalAlignment): Element {
    match (el.modifiers()) {
        case Some(m) => m.horizontalAlignment = Some(a)
        case None => ()
    }
    el
}
